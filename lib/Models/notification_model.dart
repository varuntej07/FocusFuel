import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String userId;
  final String message;
  final DateTime timestamp;
  final bool clicked;
  final String type;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.message,
    required this.timestamp,
    this.clicked = false,
    this.type = 'focus',
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      message: data['message'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      clicked: data['clicked'] ?? false,
      type: data['type'] ?? 'focus',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'clicked': clicked,
      'type': type,
    };
  }
} 