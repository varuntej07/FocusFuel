class ChatModel{
  final String text;
  final bool isUser;      // true=user, false=assistant
  final DateTime timestamp;
  final String username;
  final String? status;
  final String? errorDetails;

  ChatModel({
    required this.text,
    required this.isUser,
    required this.timestamp,
    required this.username,
    this.status,
    this.errorDetails,
  });
}
