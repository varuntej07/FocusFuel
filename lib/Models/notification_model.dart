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
    final notificationData = doc.data() as Map<String, dynamic>;

    // Handle the message field as either object or string
    String messageContent;
    final messageData = notificationData['message'];    // message is a map with title and content of notification

    if (messageData is Map<String, dynamic>) {
      messageContent = messageData['content'] ?? '';
    } else {
      messageContent = messageData?.toString() ?? '';
    }

    return NotificationModel(
      id: doc.id,
      userId: notificationData['userId'] ?? '',
      message: messageContent,
      timestamp: (notificationData['timestamp'] as Timestamp).toDate(),
      clicked: notificationData['clicked'] ?? false,
      type: notificationData['type'] ?? 'focus',
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