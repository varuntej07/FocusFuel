import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../Models/chat_model.dart';
import 'package:intl/intl.dart';
import '../../ViewModels/chat_vm.dart';

class ChatScreen extends StatefulWidget{
  const ChatScreen({super.key});

  @override
  createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>{
  final ChatViewModel chatVM = ChatViewModel(userId: 'O4e733SdzphXPpds73NXL5np1ZA2');
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      chatVM.sendMessage(text);
      _controller.clear();
      setState(() {});
    }
  }

  Widget _buildMessage(ChatMessage msg){
    final time = DateFormat.jm().format(msg.timestamp);
    final isUser = msg.isUser;

    final bgGradient = msg.isUser ? const LinearGradient(
      colors:  [Color(0xFF7F00FF), Color(0xFFE100FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ) : LinearGradient(
      colors: [Colors.grey.shade300, Colors.grey.shade200],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            // AI avatar on the left
            const CircleAvatar(radius: 16, child: Icon(Icons.android, size: 20)),
            const SizedBox(width: 8),
          ],

          Flexible(     // message bubble
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
              decoration: BoxDecoration(
                gradient: bgGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(msg.text, style: TextStyle(color: isUser ? Colors.white : Colors.black87, fontSize: 15)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(time, style: TextStyle(color: Colors.black54, fontSize: 8)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          ),
          if (isUser) const SizedBox(width: 40), // balance spacing
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: chatVM.getMessageStream(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text("Oops!! Hold on.. there's an error loading messages: ${snap.error}"));
                }
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text("Ask something to stay hard!!"));
                }

                final messages = docs.map((doc) {
                  final data = doc.data()! as Map<String, dynamic>;
                  final Timestamp? ts = data['createdAt'] as Timestamp?;
                  final DateTime dt = ts?.toDate() ?? DateTime.now();

                  return ChatMessage(
                    text: data['content'] ?? '',
                    isUser: data['role'] == 'user',
                    timestamp: dt,
                    isRead: data['isRead'] ?? true,
                  );
                }).toList();

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (ctx, i) => _buildMessage(messages[i]),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.grey),
                  onPressed: () {}, // future feature
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: const InputDecoration(
                      hintText: 'Type ya response...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.deepPurple),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}