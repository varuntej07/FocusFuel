import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../Models/chat_model.dart';
import 'package:intl/intl.dart';
import '../../ViewModels/chat_vm.dart';
import '../../ViewModels/home_vm.dart';
import '../../ViewModels/auth_vm.dart';
import '../Auth/login_page.dart';
import 'chat_history.dart';
import 'package:focus_fuel/Views/screens/subscription_page.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ChatScreen extends StatefulWidget{
  const ChatScreen({super.key});

  @override
  createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _initialized = false;

  // typing indicator animation (3 bouncing dots)
  late final AnimationController _typingAnimationController;

  @override
  void initState() {
    super.initState();
    _typingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Listen to text field changes and update ViewModel
    _controller.addListener(() {
      context.read<ChatViewModel>().updateTextFieldState(_controller.text);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatViewModel>().addListener(_onVmChanged);
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

  void _onVmChanged() {
    if (!mounted) return; // Check if widget is still mounted

    final chatVM = context.read<ChatViewModel>();

    if (chatVM.isSending && !_typingAnimationController.isAnimating) {
      _typingAnimationController.repeat();
    } else if (!chatVM.isSending && _typingAnimationController.isAnimating) {
      _typingAnimationController.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _typingAnimationController.dispose();
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
      chatVM.clearTextFieldState(); // Update ViewModel state
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }


  Widget _buildMessage(ChatModel msg){
    final time = DateFormat.jm().format(msg.timestamp);
    final isUser = msg.isUser;
    final isError = msg.status == 'error';

    // Softer violet gradient theme for user messages
    final bgGradient = isUser ? const LinearGradient(
      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)], // Softer indigo/violet gradient
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    )
        : isError ?
    LinearGradient(
      colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ) :
    LinearGradient(
      colors: [
        Theme.of(context).colorScheme.surfaceContainerHighest,
        Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7)
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    // Display full text immediately - no animation to prevent rebuild issues
    final displayText = msg.text;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            // AI avatar with softer violet theme
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],

          Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: bgGradient,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: isUser
                      ? const Color(0xFF6366F1).withValues(alpha: 0.25)
                      : Theme.of(context).shadowColor.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show warning icon for errors
                  if (isError) ...[
                    Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.orange.shade700, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Oops! Something went wrong',
                          style: TextStyle(
                            color: Colors.orange.shade900,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Use markdown rendering for AI messages, plain text for user
                  if (isUser)
                    Text(
                      displayText,
                      style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4)
                    )
                  else if (isError)
                    Text(
                      displayText,
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    )
                  else
                    MarkdownBody(
                      data: displayText,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 15,
                          height: 1.5,
                        ),
                        strong: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                        em: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontStyle: FontStyle.italic,
                        ),
                        listBullet: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        code: TextStyle(
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          color: const Color(0xFF6366F1),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),

                  if (isError) ...[
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF6366F1).withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => context.read<ChatViewModel>().retryLastMessage(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'Retry',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          color: isUser
                            ? Colors.white.withValues(alpha: 0.7)
                            : Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                          fontSize: 10
                        )
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          ),
          if (isUser) const SizedBox(width: 40),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatVM = context.watch<ChatViewModel>();
    final authVM = context.watch<AuthViewModel>();

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

    // Calculate remaining queries for free users
    final userModel = authVM.userModel;
    final subscriptionStatus = userModel?.subscriptionStatus ?? 'free';
    final isFreeUser = subscriptionStatus == 'free';
    final hasActivePlan = subscriptionStatus == 'trial' || subscriptionStatus == 'premium';
    final dailyChatQueryCount = userModel?.dailyChatQueryCount ?? 0;
    final remainingQueries = isFreeUser ? (5 - dailyChatQueryCount).clamp(0, 5) : null;

    return Scaffold(
      appBar: AppBar(
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.history, size: 30),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatHistoryScreen()));
          },
        ),
        // Only show "Get Plus" button for free users
        title: !hasActivePlan ? GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Get Plus", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.star_rounded, color: Colors.white, size: 18),
                ),
              ],
            ),
          )
        ) : null,
        centerTitle: true,
        actions: [
          if (isFreeUser && remainingQueries != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).dividerColor,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 16,
                        color: Theme.of(context).iconTheme.color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$remainingQueries/5',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Free tier usage banner
          if (isFreeUser && remainingQueries != null)
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF6366F1).withValues(alpha: 0.08),
                    Color(0xFF8B5CF6).withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Color(0xFF6366F1).withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF6366F1).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$remainingQueries ${remainingQueries == 1 ? 'query' : 'queries'} left today',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.headlineLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Upgrade for unlimited chats',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Get Plus',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.star_rounded, color: Colors.white, size: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
                  itemCount: messages.length + (chatVM.isSending ? 1 : 0),
                  itemBuilder: (ctx, index) {
                    if (index == messages.length && chatVM.isSending) {
                      return _buildTypingIndicator();
                    }
                    return _buildMessage(messages[index]);
                  },
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
                    style: TextStyle(color: Theme.of(context).textTheme.titleMedium?.color),
                    controller: _controller,
                    enabled: !chatVM.isSending,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Type ya response...',
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      hintStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Clean, minimal send button - no animation to prevent shake
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: chatVM.hasText && !chatVM.isSending ? _sendMessage : null,
                    child: Container(
                      width: 40, // Fixed width to prevent layout shift
                      height: 40, // Fixed height
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.arrow_upward_rounded,
                        color: chatVM.hasText && !chatVM.isSending
                          ? const Color(0xFF6366F1)
                          : Colors.grey.shade400,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // typing indicator three bouncing dots with violet theme
  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // AI avatar with softer violet gradient
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [_buildDot(0), _buildDot(1), _buildDot(2)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _typingAnimationController,
      builder: (context, child) {
        final t = (_typingAnimationController.value * 3 - index).clamp(0.0, 1.0);
        final v = Curves.easeInOut.transform(t) - Curves.easeInOut.transform((t - 0.5).clamp(0.0, 1.0));
        return Transform.translate(
          offset: Offset(0, -5 * v),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}