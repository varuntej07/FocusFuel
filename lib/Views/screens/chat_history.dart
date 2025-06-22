import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../Models/conversation_model.dart';
import '../../Models/notification_model.dart';
import '../../ViewModels/chat_vm.dart';
import '../../Services/chat_service.dart';

class ChatHistoryScreen extends StatelessWidget {
  const ChatHistoryScreen({super.key});

  static const Color _dividerLineColor = Color(0xFFE0E0E0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chat History"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<ConversationModel>>(
        stream: context.read<ChatViewModel>().getConversationsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error loading history: ${snapshot.error}"));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final conversations = snapshot.data ?? [];

          if (conversations.isEmpty) {
            return const Center(
              child: Text("No chat history yet. Start a conversation!"),
            );
          }

          // Group conversations by date and sort by date
          final groupedConversations = _groupConversationsByDate(conversations);

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _calculateTotalItems(groupedConversations),
            itemBuilder: (context, index) {
              return _buildListItem(context, groupedConversations, index);
            },
          );
        },
      ),
    );
  }

  Map<String, List<ConversationModel>> _groupConversationsByDate(List<ConversationModel> conversations) {
    final Map<String, List<ConversationModel>> grouped = {};
    final now = DateTime.now();

    for (var conversation in conversations) {
      final date = conversation.startedAt;
      String dateKey;

      if (_isSameDay(date, now)) {
        dateKey = 'Today';
      } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
        dateKey = 'Yesterday';
      } else {
        dateKey = DateFormat('MMMM d, y').format(date);
      }

      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(conversation);
    }

    return grouped;
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  int _calculateTotalItems(Map<String, List<ConversationModel>> groupedConversations) {
    int total = 0;
    for (var entry in groupedConversations.entries) {
      total += 1; // Date divider
      total += entry.value.length; // Conversation cards
    }
    return total;
  }

  Widget _buildListItem(BuildContext context, Map<String, List<ConversationModel>> groupedConversations, int index) {
    int currentIndex = 0;

    for (var entry in groupedConversations.entries) {
      String date = entry.key;
      List<ConversationModel> conversations = entry.value;

      // Check if this is the date divider
      if (currentIndex == index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: DateDivider(text: date),
        );
      }
      currentIndex++;

      // Check if this is one of the conversation cards for this date
      for (int i = 0; i < conversations.length; i++) {
        if (currentIndex == index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ChatHistoryCard(conversation: conversations[i]),
          );
        }
        currentIndex++;
      }
    }

    return const SizedBox.shrink();
  }
}

class _ChatHistoryCard extends StatelessWidget {
  _ChatHistoryCard({required this.conversation});

  final ConversationModel conversation;
  final ChatService _gptService = ChatService();

  @override
  Widget build(BuildContext context) {
    final time = DateFormat.jm().format(conversation.startedAt);
    final chatVM = context.read<ChatViewModel>();
    final conversationFocus = conversation.userFocus;

    return FutureBuilder<int>(
      future: _gptService.getMessageCount(conversation.id),
      builder: (context, messageCountSnapshot) {
        // Determine card color based on message count
        final hasMultipleMessages = (messageCountSnapshot.data ?? 0) > 1;
        final cardColor = hasMultipleMessages ? Colors.blue.shade50 : Colors.white;
        final borderColor = hasMultipleMessages ? Colors.blue.shade50 : Colors.grey.shade300;

        return GestureDetector(
          onTap: () {
            // Navigate to chat with this specific conversation
            chatVM.setConversation(conversation.id);
            Navigator.pop(context); // Go back to chat screen
          },
          child: Container(
            decoration: BoxDecoration(
              color: cardColor,
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(time, style: const TextStyle(fontSize: 12, color: Colors.grey)),

                        const SizedBox(height: 2),

                        FutureBuilder<NotificationModel?>(
                          future: conversation.notificationId != null
                              ? _gptService.getNotification(conversation.notificationId!)
                              : null,
                          builder: (context, snapshot) {
                            String displayText;

                            if (snapshot.connectionState == ConnectionState.waiting) {
                              displayText = 'Fetching notification...';
                            } else if (snapshot.hasData && snapshot.data != null) {
                              final chatHistoryMessage = snapshot.data!.message;
                              displayText = chatVM.trimString(chatHistoryMessage, 90);
                            } else {
                              // Fallback to userFocus or default text
                              displayText = chatVM.trimString(conversationFocus ?? 'Focus Session', 40);
                            }

                            return Text(
                              displayText,
                              style: GoogleFonts.poppins(
                                textStyle: const TextStyle(
                                  color: Colors.black, fontSize: 13, fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Focus was: ${chatVM.trimString(conversationFocus ?? 'Not set', 40)}',
                          style: GoogleFonts.poppins(
                            textStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    color: Colors.grey,
                    onPressed: () {
                      // TODO: archive/delete chat history
                    },
                    icon: const Icon(Icons.more_vert),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class DateDivider extends StatelessWidget {
  const DateDivider({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: ChatHistoryScreen._dividerLineColor, thickness: 1)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ChatHistoryScreen._dividerLineColor),
          ),
          child: Text(text, style: const TextStyle(fontSize: 13, color: Colors.black87)),
        ),
        const SizedBox(width: 6),
        const Expanded(child: Divider(color: ChatHistoryScreen._dividerLineColor, thickness: 1)),
      ],
    );
  }
}