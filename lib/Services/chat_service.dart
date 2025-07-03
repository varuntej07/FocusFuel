import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Models/chat_model.dart';
import '../Models/conversation_model.dart';
import '../Models/notification_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Returns the latest active conversationId
  Future<String?> getLatestConversationId() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return null;

    try {
      // Query for the latest active conversation for the user
      final querySnapshot = await _firestore
          .collection('Conversations')
          .where('userId', isEqualTo: userId)
          .orderBy('startedAt', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();
        // Only return if status is active, otherwise return null
        if (data['status'] == 'active') {
          return doc.id;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get all past conversations to display in chat history
  Stream<List<ConversationModel>> getPastConversations() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('Conversations')
        .where('userId', isEqualTo: userId)
        .orderBy('startedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ConversationModel.fromFirestore(doc);
      }).toList();
    });
  }

  // This is the main function for sending message to GPT
  Future<void> sendMessage(String message, String conversationId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    // Create user message document in the Messages sub-collection
    final messageRef = await _firestore
        .collection('Conversations')
        .doc(conversationId)
        .collection('Messages')
        .add({
      'content': message,
      'timestamp': FieldValue.serverTimestamp(),
      'role': 'user',
      'isFirstMessage': false,
    });

    // Update conversation's lastMessageAt
    await _firestore.collection('Conversations').doc(conversationId).update({
      'lastMessageAt': FieldValue.serverTimestamp(),
    });

   // Creating GPT request document in the /GptRequests sub-collection so that cloud function can process it
    try {
      await _firestore.collection('GptRequests')
          .add({
        'messageId': messageRef.id,
        'conversationId': conversationId,
        'content': message,
        'userId': userId,  // Includes userId for Cloud Function
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending'
      });
    } catch (e) {
      // If GPT request fails, saving the error message
      await _firestore.collection('Conversations')
          .doc(conversationId)
          .collection('Messages')
          .add({
        'content': 'Sorry bro, encountered an error. Please try again.',
        'timestamp': FieldValue.serverTimestamp(),
        'role': 'assistant',
        'isFirstMessage': false,
        'status': 'error',
        'errorDetails': e.toString(),
      });
      rethrow;
    }
  }

  // stream responsible for displaying messages in chat
  Stream<List<ChatModel>> getConversationMessages(String conversationId) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('Conversations')
        .doc(conversationId)
        .collection('Messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final convData = doc.data();
        return ChatModel(
          text: _extractNotificationContent(convData['content']),
          isUser: convData['role'] == 'user',
          timestamp: (convData['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          username: convData['role'] == 'user' ? 'user' : 'assistant',
          status: convData['status'],
          errorDetails: convData['errorDetails'],
        );
      }).toList();
    });
  }

  // Helper function to extract message content from Notification object saved in firestore
  String _extractNotificationContent(dynamic content) {
    if (content is String) {    // If content is already a string, return as-is
      return content;
    }

    if (content is Map<String, dynamic>) {
      return content['content'] ?? content.toString();
    }

    // Fallback for any other type
    return content.toString();
  }

  Future<int> getMessageCount(String conversationId) async {
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('Conversations')
          .doc(conversationId)
          .collection('Messages')
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('Error getting message count: $e');
      return 0;
    }
  }

  // Retry sending a message
  Future<void> retryMessage(String message, String conversationId) async {
    await sendMessage(message, conversationId);
  }

  // Get notification by ID for chat history title display
  Future<NotificationModel?> getNotification(String notificationId) async {
    try {
      final doc = await _firestore.collection('Notifications').doc(notificationId).get();
      if (doc.exists) {
        return NotificationModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}