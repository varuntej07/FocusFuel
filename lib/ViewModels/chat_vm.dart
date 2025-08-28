import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Models/chat_model.dart';
import '../Models/conversation_model.dart';
import '../Services/chat_service.dart';

class ChatViewModel extends ChangeNotifier {
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _disposed = false;
  bool _isLoading = false;

  // Store the last user message for retry functionality
  String? _lastUserMessage;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  String? _currentConversationId;
  bool _isSending = false;

  String get userId => _auth.currentUser?.uid ?? '';
  bool get isSending => _isSending;
  bool get isLoading => _isLoading;
  String? get currentConversationId => _currentConversationId;
  String? get lastUserMessage => _lastUserMessage;

  // Initialize with latest conversation when chat UI renders for the first time
  Future<void> initializeWithLatestConversation() async {
    try {
      _currentConversationId = await _chatService.getLatestConversationId();

      // Only notify if the widget is still mounted
      if (!_disposed) {
        notifyListeners();
      }
    } catch (error, stackTrace) {
      FirebaseCrashlytics.instance.recordError(error, stackTrace, information: ['Failed to initialize with latest conversation']);
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

    // Store the message for potential retry
    _lastUserMessage = message;

    _isSending = true;
    notifyListeners();

    try {
      _isLoading = true;
      await _chatService.sendMessage(message, _currentConversationId!);
    } catch (error, stackTrace) {
      FirebaseCrashlytics.instance.recordError(error, stackTrace, information: ['Error sending message: $message']);
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  // Retry the last message that failed
  Future<void> retryLastMessage() async {
    if (_lastUserMessage != null && _currentConversationId != null) {
      await sendMessage(_lastUserMessage!);
    }
  }

  // Retry a specific message (useful when you have the original content)
  Future<void> retryMessage(String originalMessage) async {
    if (_currentConversationId == null || originalMessage.trim().isEmpty) {
      return;
    }

    _isSending = true;
    notifyListeners();

    try {
      await _chatService.retryMessage(originalMessage, _currentConversationId!);
    } catch (e, stackTrace) {
      FirebaseCrashlytics.instance.recordError(e, stackTrace, information: ['Error retrying to send a message: $originalMessage']);
    } finally {
      _isSending = false;
      notifyListeners();
    }
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