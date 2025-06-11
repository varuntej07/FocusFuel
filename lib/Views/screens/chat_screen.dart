import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../Models/chat_model.dart';
import 'package:intl/intl.dart';
import '../../ViewModels/chat_vm.dart';
import '../../ViewModels/home_vm.dart';
import '../Auth/login_page.dart';
import 'chat_history.dart';
import 'package:focus_fuel/Views/screens/subscription_page.dart';

class ChatScreen extends StatefulWidget{
  const ChatScreen({super.key});

  @override
  createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>{
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChat();      // Initialize chat after build to get latest conversation
      _scrollToBottom();
    });
    context.read<HomeViewModel>().bumpStreakIfNeeded();
  }

  Future<void> _initializeChat() async {
    if (!_initialized) {
      await context.read<ChatViewModel>().initializeWithLatestConversation();
      _initialized = true;
      _scrollToBottom();
    }
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
      final chatVM = context.read<ChatViewModel>();

      // Check if we have an active conversation
      if (chatVM.currentConversationId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active conversation!. Start a new chat or fetch through your history.')),
        );
        return;
      }

      try {
        chatVM.sendMessage(text);
      } catch(e) {
        print("Error while sending query to GPT: $e");
      }
      _controller.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }


  Widget _buildMessage(ChatModel msg){
    final time = DateFormat.jm().format(msg.timestamp);
    final isUser = msg.isUser;
    final isError = msg.status == 'error';

    final bgGradient = isUser ? const LinearGradient(
      colors:  [Color(0xFF7F00FF), Color(0xFFE100FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    )
        : isError ?
    LinearGradient(
      colors: [Colors.red.shade300, Colors.red.shade200],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ) :
    LinearGradient(
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
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(msg.text, style: TextStyle(color: isUser ? Colors.white : Colors.black87, fontSize: 15)),

                  if (isError) ...[
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () => context.read<ChatViewModel>().retryMessage(msg.text),
                      child: const Text('Retry', style: TextStyle(color: Colors.red, fontSize: 8)),
                    ),
                  ],

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

    // Check if user is logged in before rendering chat screen
    if(chatVM.userId.isEmpty){
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Login to start hustling through chat!", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Login())),
                  child: const Text("Login", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.history, size: 30),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatHistoryScreen()));
          },
        ),
        title: GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white54,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text("Get Plus", style: TextStyle(color: Colors.deepPurple, fontSize: 20)),
                Icon(Icons.star, color: Colors.deepPurple, size: 20),
            ],
          ),
          )
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined, size: 30),
            onPressed: () {
              // TODO: Implement new chat functionality
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatModel>>(
              stream: chatVM.getMessageStream(),
              builder: (context, snap) {
                if (snap.hasError) {
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
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.black12),
                  onPressed: () {}, // future feature
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !chatVM.isSending,           // to disable if sending query
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
                  onPressed: chatVM.isSending ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}