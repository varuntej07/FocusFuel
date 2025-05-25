class ChatModel{
  final String text;
  final bool isUser;      // true=user, false=assistant
  final DateTime timestamp;
  final String username;

  ChatModel({
    required this.text,
    required this.isUser,
    required this.timestamp,
    required this.username
  });
}
