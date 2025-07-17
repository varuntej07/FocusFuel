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
    if (_scrollController.hasClients && _scrollController.position.hasContentDimensions) {
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
      try {
        chatVM.sendMessage(text);
      } catch(e) {
        debugPrint("Error while sending query to GPT: $e");
      }
      _controller.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }


  Widget _buildMessage(ChatModel msg){
    final time = DateFormat.jm().format(msg.timestamp);
    final isUser = msg.isUser;
    final isError = msg.status == 'error';

    final bgGradient = isUser ? LinearGradient(
      colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primary.withValues(alpha: 0.8)],
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
      colors: [Theme.of(context).colorScheme.surfaceContainerHighest, Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            // AI avatar on the left
            CircleAvatar(radius: 10, backgroundColor: Theme.of(context).colorScheme.primary, child: Icon(Icons.android, size: 6, color: Theme.of(context).colorScheme.onPrimary)),
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
                    color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(msg.text, style: TextStyle(color: isUser ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface, fontSize: 15)),

                  if (isError) ...[
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () => context.read<ChatViewModel>().retryMessage(msg.text),
                      child: Text('Retry', style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 8)),                    ),
                  ],

                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(time, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 8)),
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Get Plus", style: TextStyle(color: Theme.of(context).textTheme.titleMedium?.color, fontSize: 24, fontWeight: FontWeight.bold)),
                SizedBox(width: 4),
                Icon(Icons.star, color: Theme.of(context).colorScheme.primary, size: 25),
              ],
            ),
          )
        ),
        centerTitle: true,
        // actions: [
        //   IconButton(
        //     icon: Image.asset('lib/Assets/icons/new-chat.png', width: 24, height: 24),
        //     onPressed: () {
        //       // TODO: Implement new chat functionality
        //     },
        //   ),
        // ],
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

                // check hasContentDimensions before accessing maxScrollExtent
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients && _scrollController.position.hasContentDimensions) {
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
                  icon: Icon(Icons.add, color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.7)),
                  onPressed: () {}, // future feature
                ),
                Expanded(
                  child: TextField(
                    style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                    controller: _controller,
                    enabled: !chatVM.isSending,           // to disable if sending query
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Type ya response...',
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,  // removes the background fill
                      hintStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send, color: Theme.of(context).colorScheme.primary),
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