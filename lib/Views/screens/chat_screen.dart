import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../Models/chat_model.dart';
import 'package:intl/intl.dart';
import '../../ViewModels/chat_vm.dart';
import '../Auth/login_page.dart';

class ChatScreen extends StatefulWidget{
  const ChatScreen({super.key});

  @override
  createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>{
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      context.read<ChatViewModel>().sendMessage(text);
      _controller.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  Widget _buildMessage(ChatModel msg){
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
            const CircleAvatar(radius: 10, child: Icon(Icons.android, size: 6)),
            const SizedBox(width: 4),
          ],

          Flexible(     // message bubble
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
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
    final chatVM = context.watch<ChatViewModel>();

    if(chatVM.userId.isEmpty){
      return Scaffold(
        body: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Sign in or Login to start chatting!"),
              TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Login())),
                  child: const Text("Login")
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatModel>>(
              stream: chatVM.getMessageStream(),
              builder: (context, snap) {
                if (snap.hasError) {
                  final err = snap.error.toString();
                  if (err.contains('permission-denied')) {
                    return const Center(child: Text("Login First and ask something to stay hard!!"));
                  }
                  return Center(child: Text("Oops!! Hold on.. there's an error loading messages: ${snap.error}"));
                }
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snap.data ?? [];

                if (messages.isEmpty) {
                  return const Center(child: Text("Ask something to stay hard!!"));
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                  }
                });

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