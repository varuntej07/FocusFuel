import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Models/chat_model.dart';
import '../Models/conversation_model.dart';
import '../Services/chat_service.dart';

class ChatViewModel extends ChangeNotifier {
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _currentConversationId;
  bool _isSending = false;

  String get userId => _auth.currentUser?.uid ?? '';
  bool get isSending => _isSending;
  String? get currentConversationId => _currentConversationId;

  // Initialize with latest conversation when chat UI renders for the first time
  Future<void> initializeWithLatestConversation() async {
    try {
      _currentConversationId = await _chatService.getLatestConversationId();
      notifyListeners();
    } catch (e) {
      print('Error initializing conversation: $e');
    }
  }

  // Set specific conversation (for navigation from history)
  void setConversation(String conversationId) {
    _currentConversationId = conversationId;
    notifyListeners();
  }

  // Gets message stream for current conversation from ChatService
  Stream<List<ChatModel>> getMessageStream() {
    if (_currentConversationId == null) {
      return Stream.value([]);
    }
    return _chatService.getConversationMessages(_currentConversationId!);
  }

  // This is the main function for sending message to GPT
  Future<void> sendMessage(String message) async {
    if (_currentConversationId == null) {
      return;
    }

    _isSending = true;
    notifyListeners();

    try {
      await _chatService.sendMessage(message, _currentConversationId!);
    } catch (e) {
      print('Error sending message: $e');
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  // Retry message
  Future<void> retryMessage(String message) async {
    await sendMessage(message);
  }

  // Get all conversations to display in chat history
  Stream<List<ConversationModel>> getConversationsStream() {
    return _chatService.getPastConversations();
  }

  String trimString(String str, length) {
  if (str.length > length) {
    return "${str.substring(0, length)}...";
  }
  return str;
  }
}