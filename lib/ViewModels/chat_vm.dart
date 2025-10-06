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
  int _lastMessageCount = 0;
  bool _hasText = false;

  String get userId => _auth.currentUser?.uid ?? '';
  bool get isSending => _isSending;
  bool get isLoading => _isLoading;
  bool get hasText => _hasText;
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
    return _chatService.getConversationMessages(_currentConversationId!).map((messages) {
      // Auto-dismiss loading indicator when new AI message arrives
      if (_isSending && messages.length > _lastMessageCount) {
        // Check if the latest message is from assistant
        if (messages.isNotEmpty && !messages.last.isUser) {
          _isSending = false;
          if (!_disposed) {
            notifyListeners();
          }
        }
      }
      _lastMessageCount = messages.length;
      return messages;
    });
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
      await _chatService.sendMessage(message, _currentConversationId!);
      // _isSending will be set to false when AI response arrives (in getMessageStream)
    } catch (error, stackTrace) {
      FirebaseCrashlytics.instance.recordError(error, stackTrace, information: ['Error sending message: $message']);
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

  // Update text field state (for send button enable/disable)
  void updateTextFieldState(String text) {
    final hasText = text.trim().isNotEmpty;
    if (hasText != _hasText) {
      _hasText = hasText;
      notifyListeners();
    }
  }

  // Clear text field state
  void clearTextFieldState() {
    _hasText = false;
    notifyListeners();
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