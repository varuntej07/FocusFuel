import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../ViewModels/debate_vm.dart';
import '../../Models/debate_model.dart';
import 'debate_summary_view.dart';

class DebateView extends StatefulWidget {
  final String debateId;

  const DebateView({super.key, required this.debateId});

  @override
  State<DebateView> createState() => _DebateViewState();
}

class _DebateViewState extends State<DebateView> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late final AnimationController _pulseController;
  late final AnimationController _quoteController;
  int _currentQuoteIndex = 0;

  static const List<String> _loadingQuotes = [
    "The best way to predict the future is to debate it.",
    "Every decision has two sides. Let's explore both.",
    "Clarity comes from conflict of ideas, not consensus.",
    "The strongest arguments are forged in opposition.",
    "What got you here won't get you there.",
    "The obstacle is the way.",
    "Doubt is the beginning of wisdom.",
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _quoteController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _quoteController.forward();
    _startQuoteRotation();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DebateViewModel>().resumeDebate(widget.debateId);
    });
  }

  void _startQuoteRotation() {
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        _quoteController.reverse().then((_) {
          if (mounted) {
            setState(() {
              _currentQuoteIndex = (_currentQuoteIndex + 1) % _loadingQuotes.length;
            });
            _quoteController.forward();
            _startQuoteRotation();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pulseController.dispose();
    _quoteController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final debateVM = context.watch<DebateViewModel>();

    // Navigate to summary when complete
    if (debateVM.viewState == DebateViewState.complete && debateVM.currentDebate != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DebateSummaryView(debateId: widget.debateId),
          ),
        );
      });
    }

    // Scroll to bottom when new turns arrive
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(
        title: _buildProgressIndicator(debateVM),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _showCancelDialog(debateVM),
        ),
      ),
      body: Column(
        children: [
          // Dilemma banner
          _buildDilemmaBanner(debateVM),

          // Turns list
          Expanded(
            child: _buildTurnsList(debateVM),
          ),

          // Status indicator
          _buildStatusBar(debateVM),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(DebateViewModel debateVM) {
    final currentTurn = debateVM.turns.length;
    const maxTurns = 6;
    final progress = currentTurn / maxTurns;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Turn $currentTurn/$maxTurns',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 100,
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }

  Widget _buildDilemmaBanner(DebateViewModel debateVM) {
    final dilemma = debateVM.currentDebate?.dilemma ?? debateVM.dilemma;
    if (dilemma.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6366F1).withValues(alpha: 0.1),
            const Color(0xFF8B5CF6).withValues(alpha: 0.1),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF6366F1).withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.help_outline,
            color: Color(0xFF6366F1),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              dilemma,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTurnsList(DebateViewModel debateVM) {
    // Build list of turns plus any currently streaming turn
    final completedTurns = debateVM.turns;
    final totalItems = completedTurns.length;

    if (totalItems == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1 + (_pulseController.value * 0.1),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.3 + _pulseController.value * 0.2),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.psychology,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Preparing debate...',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'The agents are forming their arguments',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                    ),
              ),
              const SizedBox(height: 32),
              FadeTransition(
                opacity: _quoteController,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.format_quote,
                        color: const Color(0xFF6366F1).withValues(alpha: 0.6),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _loadingQuotes[_currentQuoteIndex],
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: totalItems,
      itemBuilder: (context, index) {
        return _buildTurnCard(debateVM, completedTurns[index]);
      },
    );
  }

  Widget _buildTurnCard(DebateViewModel debateVM, DebateTurn turn) {
    final isFixed = turn.isFixedAgent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Agent avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isFixed
                    ? [const Color(0xFFEF4444), const Color(0xFFF97316)]
                    : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isFixed ? Icons.psychology : Icons.emoji_events,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // Turn content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      turn.agentName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isFixed
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF6366F1),
                          ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        turn.phase.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isFixed
                          ? const Color(0xFFEF4444).withValues(alpha: 0.2)
                          : const Color(0xFF6366F1).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        turn.text,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              height: 1.5,
                            ),
                      ),
                      // Audio playback controls (will be added when audio is ready)
                      if (turn.audioStoragePath != null && turn.audioStoragePath!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildAudioControls(debateVM, turn),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioControls(DebateViewModel debateVM, DebateTurn turn) {
    final audioService = debateVM.audioService;
    final isCurrentTurnPlaying = audioService.currentTurnId == turn.id;

    return Row(
      children: [
        // Play/Pause button
        StreamBuilder(
          stream: audioService.playerStateStream,
          builder: (context, snapshot) {
            final isPlaying = isCurrentTurnPlaying && audioService.isPlaying;

            return InkWell(
              onTap: () async {
                if (isPlaying) {
                  await debateVM.pauseAudio();
                } else if (isCurrentTurnPlaying) {
                  await debateVM.resumeAudio();
                } else {
                  await debateVM.playTurnAudio(turn.audioStoragePath!, turn.id ?? 'turn_${turn.turnNumber}');
                }
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  size: 18,
                  color: const Color(0xFF6366F1),
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        // Audio wave indicator
        Expanded(
          child: StreamBuilder(
            stream: audioService.positionStream,
            builder: (context, positionSnapshot) {
              return StreamBuilder(
                stream: audioService.durationStream,
                builder: (context, durationSnapshot) {
                  final position = positionSnapshot.data ?? Duration.zero;
                  final duration = durationSnapshot.data ?? Duration.zero;
                  final progress = duration.inMilliseconds > 0
                      ? position.inMilliseconds / duration.inMilliseconds
                      : 0.0;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: isCurrentTurnPlaying ? progress : 0.0,
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                        borderRadius: BorderRadius.circular(2),
                        minHeight: 4,
                      ),
                      if (isCurrentTurnPlaying && duration.inSeconds > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${position.inSeconds}s / ${duration.inSeconds}s',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                              ),
                        ),
                      ],
                    ],
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        // Volume icon
        Icon(
          Icons.volume_up,
          size: 16,
          color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
        ),
      ],
    );
  }

  Widget _buildStatusBar(DebateViewModel debateVM) {
    String statusText;
    Widget? statusIcon;

    switch (debateVM.viewState) {
      case DebateViewState.connecting:
        statusText = 'Connecting...';
        statusIcon = const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
        break;
      case DebateViewState.inProgress:
        final nextAgent = debateVM.turns.length.isEven
            ? 'Ruthless Critic'
            : debateVM.currentDebate?.customAgent?.name ?? 'Your Ally';
        statusText = '$nextAgent is thinking...';
        statusIcon = const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
        break;
      case DebateViewState.summarizing:
        statusText = 'Generating summary...';
        statusIcon = const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
        break;
      case DebateViewState.error:
        statusText = debateVM.errorMessage ?? 'An error occurred';
        statusIcon = const Icon(
          Icons.error_outline,
          color: Color(0xFFEF4444),
          size: 16,
        );
        break;
      default:
        statusText = '';
    }

    if (statusText.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (statusIcon != null) ...[
            statusIcon,
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              statusText,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(DebateViewModel debateVM) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Debate?'),
        content: const Text(
          'Are you sure you want to cancel this debate? Progress will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Debate'),
          ),
          TextButton(
            onPressed: () {
              debateVM.cancelDebate();
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            child: const Text('Cancel Debate'),
          ),
        ],
      ),
    );
  }
}
