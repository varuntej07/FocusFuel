import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationModel {
  final String id;
  final String userId;
  final DateTime startedAt;
  final DateTime? lastMessageAt;
  final String? notificationId;
  final String? userFocus;
  final String? weeklyGoal;
  final String status;

  ConversationModel({
    required this.id,
    required this.userId,
    required this.startedAt,
    this.lastMessageAt,
    this.notificationId,
    this.userFocus,
    this.weeklyGoal,
    this.status = 'active',
  });

  factory ConversationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ConversationModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      startedAt: (data['startedAt'] as Timestamp).toDate(),
      lastMessageAt: data['lastMessageAt']?.toDate(),
      notificationId: data['notificationId'],
      userFocus: data['userFocus'] ?? "Not set",
      weeklyGoal: data['weeklyGoal'],
      status: data['status'] ?? 'active',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'startedAt': Timestamp.fromDate(startedAt),
      'lastMessageAt': lastMessageAt != null ? Timestamp.fromDate(lastMessageAt!) : null,
      'notificationId': notificationId,
      'userFocus': userFocus,
      'weeklyGoal': weeklyGoal,
      'status': status,
    };
  }
}

class ConversationMessageModel {
  final String id;
  final String role;
  final String content;
  final DateTime timestamp;
  final bool isFirstMessage;

  ConversationMessageModel({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.isFirstMessage = false,
  });

  factory ConversationMessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ConversationMessageModel(
      id: doc.id,
      role: data['role'] ?? '',
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isFirstMessage: data['isFirstMessage'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'role': role,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'isFirstMessage': isFirstMessage,
    };
  }
} 