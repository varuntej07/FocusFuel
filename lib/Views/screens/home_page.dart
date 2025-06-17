import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../ViewModels/home_vm.dart';

class HomeFeed extends StatefulWidget {
  const HomeFeed({super.key});

  @override
  createState() => _HomeFeedState();
}

class _HomeFeedState extends State<HomeFeed> {
  final List<String> suggestions = ['Master DSA', 'Job hunt', 'UI/UX', 'Body building', 'Motivation', "Other"];

  String? selectedFocus;
  double _intervalMinutes = 45;
  int _mood = 3;

  @override
  void initState(){
    super.initState();
    // Calling once, right after the first build frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<HomeViewModel>().bumpStreakIfNeeded();
      }
      context.read<HomeViewModel>().shouldPromptGoals().then((shouldPrompt) {
        if (shouldPrompt) {
          // executed after the 2-second delay
          Future.delayed(const Duration(seconds: 2), () => _promptForGoals(context));
        }
      });
    });
  }

  void _promptForGoals(BuildContext ctx) {
    String todayGoal = '';
    String weekGoal  = '';
    showDialog(
      context: ctx,
      barrierDismissible: false,  // force a decision
      builder: (_) => AlertDialog(
        title: const Text("Set your focus goals"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // today's goal input
            TextField(
              autofocus: true,
              decoration: const InputDecoration(labelText: "what's ya goal today?"),
              onChanged: (v) => todayGoal = v,
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(labelText: "Weekly goal (optional)"),
              onChanged: (v) => weekGoal = v,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Skip'),
          ),
          TextButton(
            onPressed: () {
              if (todayGoal.trim().isNotEmpty) {
                ctx.read<HomeViewModel>().setFocusGoal(todayGoal.trim());
              }
              if (weekGoal.trim().isNotEmpty || weekGoal.trim().isEmpty) {
                ctx.read<HomeViewModel>().setWeeklyGoal(weekGoal.trim());
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _handleSuggestionTap(BuildContext context ,String suggestion) {
    final homeVM = Provider.of<HomeViewModel>(context, listen: false);
    if (homeVM.currentFocus == null) {
      if (suggestion.contains("Other")) {
        _showCustomFocusDialog(context);
      } else {
        homeVM.setFocusGoal(suggestion);
      }
    }
    return;
  }

  void _showCustomFocusDialog(BuildContext context) {
    String customFocus = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Say whatchu wanna Focus'),
        content: TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: 'wanna master GenAI'),
            onChanged: (value) => customFocus = value
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
              onPressed: () {
                if (customFocus.trim().isNotEmpty) {
                  Provider.of<HomeViewModel>(context, listen: false).setFocusGoal(customFocus.trim());
                }
                Navigator.pop(context);
              },
              child: const Text('Save')
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final homeVM = Provider.of<HomeViewModel>(context);   // gets all the details required on this page from Firestore
    final userName = homeVM.username;
    final streak = homeVM.streak;
    final selectedFocus = homeVM.currentFocus ?? "Focus on something";
    final weeklyGoal = homeVM.weeklyGoal ?? "Set a weekly goal";

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text("$streak", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  Icon(Icons.local_fire_department_rounded, color: Colors.redAccent)
                ],
              ),

              Text("Hey $userName!", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.orange)),

              const SizedBox(height: 20),

              const Text("Let's not let procrastination win today! Stay hard!!!",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
              ),

              const SizedBox(height: 50),

              const Text("Choose a focus goal from below",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),

              const SizedBox(height: 30),

              Center(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 14,
                  alignment: WrapAlignment.center,
                  children: suggestions.map((suggestion) {
                    final isSelected = selectedFocus == suggestion;
                    return GestureDetector(
                      onTap: () => _handleSuggestionTap(context, suggestion),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.green.shade300.withAlpha(160) : Colors.white.withAlpha(40),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(color: isSelected ? Colors.deepOrange.withAlpha(100) : Colors.grey.withAlpha(40)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 6, offset: const Offset(2, 4))
                          ],
                        ),
                        child: Text(
                          suggestion,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                              color: isSelected ? Colors.white : Colors.black26),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 50),

              Padding(
                padding: const EdgeInsets.only(bottom: 16.0), // Padding for bottom spacing
                child: GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,          // 2x2 grid layout
                    mainAxisSpacing: 12,        // Vertical spacing between cards
                    crossAxisSpacing: 12,       // Horizontal spacing between cards
                    childAspectRatio: 1.4,      // Aspect ratio for card dimensions
                  ),
                  children: [
                    _InfoTile(
                        emoji: '🧠',
                        title: "Today’s Goal",
                        subtitle: selectedFocus,
                        editFocus: () {
                          _promptForGoals(context);
                        }
                    ),

                    _InfoTile(emoji: '📅', title: "Weekly Goal", subtitle: weeklyGoal, editFocus: () { _promptForGoals(context); },),

                    _SliderTile(
                      label: "Interval",
                      min: 15, max: 90,
                      value: _intervalMinutes,
                      divisions: 15,
                      onChanged: (v) => setState(() => _intervalMinutes = v),
                      sliderLabel: (v) => "Interval: ${v.round()} min", // Dynamic label
                    ),

                    _SliderTile(
                      label: "Mood",
                      min: 1, max: 5,
                      value: _mood.toDouble(),
                      divisions: 4,              // discrete mood values
                      onChanged: (v) => setState(() => _mood = v.round()),
                      sliderLabel: (v) => _moodEmoji(v.round()), // Emoji based on value
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _moodEmoji(int val) => const ['😣', '💡', '⏰', '⚡', '🤗'][val.clamp(1, 5) - 1];
}


// _InfoTile widget to include an emoji for top cards
class _InfoTile extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback editFocus;

  const _InfoTile({required this.emoji, required this.title, required this.subtitle, required this.editFocus});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),

            const SizedBox(height: 8),

            TextButton(
              child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
              onPressed: () {
                editFocus();
              },
            ),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.black54),
            ),
          ],
        ),
      )
    );
  }
}

class _SliderTile extends StatelessWidget {
  final String label;
  final double min, max, value;
  final int divisions;
  final ValueChanged<double> onChanged;
  final String Function(double) sliderLabel;

  const _SliderTile({
    required this.label,
    required this.min, required this.max,
    required this.value,
    required this.divisions,
    required this.onChanged,
    required this.sliderLabel,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          Slider(
            min: min, max: max,
            divisions: divisions,
            activeColor: Colors.lightGreen,
            value: value,
            label: sliderLabel(value), // Dynamic label shown during slider interaction
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Common blurred card wrapper for consistent look
class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 3))
              ]
          ),
          padding: const EdgeInsets.all(12),
          child: child,
        ),
      ),
    );
  }
}