import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../ViewModels/debate_vm.dart';
import '../../Models/debate_model.dart';
import 'debate_setup_view.dart';

class DebateSummaryView extends StatefulWidget {
  final String debateId;

  const DebateSummaryView({super.key, required this.debateId});

  @override
  State<DebateSummaryView> createState() => _DebateSummaryViewState();
}

class _DebateSummaryViewState extends State<DebateSummaryView> {
  String? _selectedResonance;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final debateVM = context.read<DebateViewModel>();
      if (debateVM.currentDebateId != widget.debateId) {
        debateVM.viewDebateFromHistory(widget.debateId);
      }
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _saveFeedback() async {
    if (_selectedResonance == null) return;

    final debateVM = context.read<DebateViewModel>();
    await debateVM.saveFeedback(
      preferredAgent: _selectedResonance!,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Feedback saved!'),
          backgroundColor: Color(0xFF6366F1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final debateVM = context.watch<DebateViewModel>();
    final debate = debateVM.currentDebate;
    final summary = debate?.summary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debate Summary'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const DebateSetupView()),
              );
            },
            tooltip: 'Start New Debate',
          ),
        ],
      ),
      body: debateVM.viewState == DebateViewState.connecting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dilemma recap
                  _buildDilemmaRecap(debate),
                  const SizedBox(height: 24),

                  // Key insight
                  if (summary?.insight != null) ...[
                    _buildInsightCard(summary!.insight!),
                    const SizedBox(height: 24),
                  ],

                  // Critic key points
                  _buildKeyPointsSection(
                    title: 'Ruthless Critic Says',
                    points: summary?.criticKeyPoints ?? [],
                    color: const Color(0xFFEF4444),
                    icon: Icons.psychology,
                  ),
                  const SizedBox(height: 20),

                  // Custom agent key points
                  _buildKeyPointsSection(
                    title: '${debate?.customAgent?.name ?? "Your Ally"} Says',
                    points: summary?.customAgentKeyPoints ?? [],
                    color: const Color(0xFF6366F1),
                    icon: Icons.emoji_events,
                  ),
                  const SizedBox(height: 24),

                  // Suggested action
                  _buildSuggestedActionCard(summary),
                  const SizedBox(height: 32),

                  // Feedback section
                  _buildFeedbackSection(debate),
                  const SizedBox(height: 32),

                  // View turns button
                  _buildViewTurnsButton(),
                  const SizedBox(height: 16),

                  // Start new debate button
                  _buildNewDebateButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildDilemmaRecap(DebateModel? debate) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6366F1).withValues(alpha: 0.1),
            const Color(0xFF8B5CF6).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Dilemma',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF6366F1),
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            debate?.dilemma ?? '',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(String insight) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.lightbulb,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Key Insight',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  insight,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyPointsSection({
    required String title,
    required List<String> points,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...points.asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      '${entry.key + 1}',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    entry.value,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          );
        }),
        if (points.isEmpty)
          Text(
            'No key points recorded',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                ),
          ),
      ],
    );
  }

  Widget _buildSuggestedActionCard(DebateSummary? summary) {
    final action = summary?.suggestedAction ?? 'No action suggested';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.rocket_launch,
                  color: Color(0xFF10B981),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Suggested Next Step',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF10B981),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            action,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackSection(DebateModel? debate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Which perspective resonated more?',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildResonanceOption(
                label: 'Ruthless Critic',
                value: 'critic',
                color: const Color(0xFFEF4444),
                icon: Icons.psychology,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildResonanceOption(
                label: debate?.customAgent?.name ?? 'Your Ally',
                value: 'custom',
                color: const Color(0xFF6366F1),
                icon: Icons.emoji_events,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _notesController,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Any additional thoughts? (optional)',
            hintStyle: TextStyle(
              color: Theme.of(context).hintColor.withValues(alpha: 0.5),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _selectedResonance != null ? _saveFeedback : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF6366F1),
              side: BorderSide(
                color: _selectedResonance != null
                    ? const Color(0xFF6366F1)
                    : Theme.of(context).dividerColor,
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Save Feedback'),
          ),
        ),
      ],
    );
  }

  Widget _buildResonanceOption({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    final isSelected = _selectedResonance == value;

    return GestureDetector(
      onTap: () => setState(() => _selectedResonance = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Theme.of(context).dividerColor.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Theme.of(context).iconTheme.color?.withValues(alpha: 0.5), size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? color : null,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewTurnsButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showTurnsBottomSheet(),
        icon: const Icon(Icons.list),
        label: const Text('View Full Debate'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildNewDebateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DebateSetupView()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Start New Debate'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6366F1),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  void _showTurnsBottomSheet() {
    final debateVM = context.read<DebateViewModel>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Full Debate',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: debateVM.turns.length,
                itemBuilder: (context, index) {
                  final turn = debateVM.turns[index];
                  final isFixed = turn.isFixedAgent;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isFixed
                                  ? [const Color(0xFFEF4444), const Color(0xFFF97316)]
                                  : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isFixed ? Icons.psychology : Icons.emoji_events,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                turn.agentName,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isFixed ? const Color(0xFFEF4444) : const Color(0xFF6366F1),
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                turn.text,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
