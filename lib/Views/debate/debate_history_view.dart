import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../ViewModels/debate_vm.dart';
import '../../Models/debate_model.dart';
import 'debate_setup_view.dart';
import 'debate_summary_view.dart';
import 'debate_view.dart';

class DebateHistoryView extends StatelessWidget {
  const DebateHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final debateVM = context.watch<DebateViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debate History'),
        elevation: 0,
      ),
      body: StreamBuilder<List<DebateModel>>(
        stream: debateVM.getDebatesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading debates',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          }

          final debates = snapshot.data ?? [];

          if (debates.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: debates.length,
            itemBuilder: (context, index) => _buildDebateCard(context, debates[index], debateVM),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DebateSetupView()),
          );
        },
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Debate'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6366F1).withValues(alpha: 0.2),
                    const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.forum_outlined,
                size: 40,
                color: Color(0xFF6366F1),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No debates yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start your first debate to challenge your thinking and gain new perspectives.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DebateSetupView()),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Start First Debate'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebateCard(BuildContext context, DebateModel debate, DebateViewModel debateVM) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat.jm();
    final dateStr = dateFormat.format(debate.createdAt);
    final timeStr = timeFormat.format(debate.createdAt);

    return Dismissible(
      key: Key(debate.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Debate?'),
            content: const Text('This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (direction) {
        debateVM.deleteDebate(debate.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debate deleted')),
        );
      },
      child: GestureDetector(
        onTap: () => _navigateToDebate(context, debate),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getStatusColor(debate.status).withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF6366F1).withValues(alpha: 0.2),
                          const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.forum,
                      color: Color(0xFF6366F1),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildStatusChip(debate.status),
                            const Spacer(),
                            Text(
                              dateStr,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          debate.customAgent?.name ?? 'Debate',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                debate.dilemma,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    timeStr,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                        ),
                  ),
                  if (debate.totalTurns != null) ...[
                    const SizedBox(width: 16),
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 14,
                      color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${debate.totalTurns} turns',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                          ),
                    ),
                  ],
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: Colors.grey,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(DebateStatus status) {
    final color = _getStatusColor(status);
    final label = _getStatusLabel(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Color _getStatusColor(DebateStatus status) {
    switch (status) {
      case DebateStatus.pending:
      case DebateStatus.inProgress:
        return const Color(0xFFF59E0B);
      case DebateStatus.completed:
        return const Color(0xFF10B981);
      case DebateStatus.error:
      case DebateStatus.cancelled:
        return const Color(0xFFEF4444);
      case DebateStatus.limitReached:
        return const Color(0xFF6366F1);
    }
  }

  String _getStatusLabel(DebateStatus status) {
    switch (status) {
      case DebateStatus.pending:
        return 'PENDING';
      case DebateStatus.inProgress:
        return 'IN PROGRESS';
      case DebateStatus.completed:
        return 'COMPLETED';
      case DebateStatus.error:
        return 'ERROR';
      case DebateStatus.cancelled:
        return 'CANCELLED';
      case DebateStatus.limitReached:
        return 'LIMIT REACHED';
    }
  }

  void _navigateToDebate(BuildContext context, DebateModel debate) {
    if (debate.status == DebateStatus.completed) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DebateSummaryView(debateId: debate.id),
        ),
      );
    } else if (debate.isActive) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DebateView(debateId: debate.id),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DebateSummaryView(debateId: debate.id),
        ),
      );
    }
  }
}
