class ChatMessage{
  final String text;
  final bool isUser;      // true=user, false=assistant
  final DateTime timestamp;
  final bool isRead;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    required this.isRead,
  });
}
