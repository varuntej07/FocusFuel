import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:rxdart/rxdart.dart';
import '../../Models/chat_model.dart';

class ChatViewModel with ChangeNotifier {
    String _userId;
    late StreamSubscription<User?> _authSubscription;

    ChatViewModel({required String userId}) : _userId = userId {
      // stream from Firebase that emits events whenever the user’s auth state changes,
      // subscribed to this stream, so every time an event occurs, it calls updateUser with the new user ID
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
        (user) => updateUser(user?.uid ?? ''),
      );
    }

    @override
    void dispose() {
      _authSubscription.cancel(); // Stop the listener
      super.dispose();
    }

    String get userId => _userId;

    void updateUser(String uid) {        // internal helper
      if (uid == _userId) return;
      _userId = uid;
      notifyListeners();               // rebuilds StreamBuilder
    }

    Stream<List<ChatModel>> getMessageStream() {

      if (_userId.isEmpty) return Stream.value(<ChatModel>[]);

      final assistantStream = FirebaseFirestore.instance
          .collection('Users').doc(_userId).collection('NotificationMessages')
          .orderBy('createdAt', descending: false)
          .snapshots();

      final userStream = FirebaseFirestore.instance
          .collection('Users').doc(_userId).collection('UserResponses')
          .orderBy('createdAt', descending: false)
          .snapshots();

     // Combining the streams using rxdart
      return Rx.combineLatest2(
        assistantStream, userStream, (QuerySnapshot assistantSnap, QuerySnapshot userSnap) {
          final assistantMessages = assistantSnap.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final Timestamp? ts = data['createdAt'] as Timestamp?;
            return ChatModel(
              text: data['content'] ?? '',
              isUser: false, // Assistant messages
              timestamp: ts?.toDate() ?? DateTime.now(),
              username: 'assistant',
            );
          }).toList();

        final userMessages = userSnap.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final Timestamp? ts = data['createdAt'] as Timestamp?;
          return ChatModel(
            text: data['content'] ?? '',
            isUser: true, // User messages
            timestamp: ts?.toDate() ?? DateTime.now(),
            username: 'user',
          );
        }).toList();

        // Combine and sort by timestamp
        final allMessages = [...assistantMessages, ...userMessages];

        // Sort by timestamp so newest are truly at the bottom
        allMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        return allMessages;
      },
    ).handleError((err, stack){
      if (err.toString().contains('permission-denied')) {
        return <ChatModel>[];
      }
      throw err;
    });
  }

  Future<void> sendMessage(String text) async {
    if (userId.isEmpty) {
      return;
    }
    await FirebaseFirestore.instance
        .collection('Users')
        .doc(userId)
        .collection('UserResponses')
        .add({
      'content': text,
      'createdAt': FieldValue.serverTimestamp(),
      'role': 'user',
    });
  }
}