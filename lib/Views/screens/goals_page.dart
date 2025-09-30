import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../ViewModels/goals_vm.dart';
import '../../ViewModels/home_vm.dart';

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Load history data when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final goalsVM = context.read<GoalsViewModel>();
      goalsVM.loadInitialHistoryData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Build history tab with pull-to-refresh and load more functionality
  Widget _buildHistoryTab(
      String title,
      List<Map<String, dynamic>> history,
      IconData icon,
      Color color,
      GoalsState state,
      bool hasMore,
      bool isLoadingMore,
      VoidCallback onLoadMore,
      Future<void> Function() onRefresh,
      ) {
    if (state == GoalsState.loading && history.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state == GoalsState.error && history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error loading $title',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRefresh,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (history.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No $title found',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: history.length + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          // Load more button at the end
          if (index == history.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: isLoadingMore
                    ? const CircularProgressIndicator()
                    : ElevatedButton.icon(
                  onPressed: onLoadMore,
                  icon: const Icon(Icons.arrow_downward),
                  label: const Text('Load More'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            );
          }

          final item = history[index];
          final content = item['content'] ?? 'No content';
          final timestamp = item['enteredAt'] as Timestamp?;
          final isActive = item['isActive'] ?? false;
          final wasCompleted = item['wasCompleted'] ?? false;
          final wasAchieved = item['wasAchieved'] ?? false;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: isActive ? Border.all(color: color, width: 2) : null,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(icon, color: color, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        content,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Active',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (wasCompleted || wasAchieved)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Completed',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                if (timestamp != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _formatTimestamp(timestamp),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Goals', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          tabs: const [
            Tab(text: 'Focus History'),
            Tab(text: 'Weekly Goals'),
            Tab(text: 'Tasks History'),
          ],
        ),
      ),
      body: Consumer2<HomeViewModel, GoalsViewModel>(
        builder: (context, home, goals, child) {
          // Check authentication from HomeViewModel
          if (!home.isAuthenticated) {
            return const Center(
              child: Text('Please log in to view your goals'),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              // Focus History Tab
              _buildHistoryTab(
                'Focus History',
                goals.focusHistory,
                Icons.center_focus_strong,
                Colors.blue,
                goals.state,
                goals.hasMoreFocus,
                goals.isLoadingMoreFocus,
                goals.loadMoreFocus,
                goals.loadInitialHistoryData,
              ),
              // Weekly Goals Tab
              _buildHistoryTab(
                'Weekly Goals',
                goals.goalHistory,
                Icons.flag,
                Colors.green,
                goals.state,
                goals.hasMoreGoal,
                goals.isLoadingMoreGoal,
                goals.loadMoreGoal,
                goals.loadInitialHistoryData,
              ),
              // Tasks History Tab
              _buildHistoryTab(
                'Tasks History',
                goals.taskHistory,
                Icons.task_alt,
                Colors.orange,
                goals.state,
                goals.hasMoreTask,
                goals.isLoadingMoreTask,
                goals.loadMoreTask,
                goals.loadInitialHistoryData,
              ),
            ],
          );
        },
      ),
    );
  }
}