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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        final homeVM = context.read<HomeViewModel>();

        // Wait for initialization
        while (!homeVM.isInitialized) {
          await Future.delayed(const Duration(milliseconds: 100));
        }

        if (homeVM.isAuthenticated) {
          await homeVM.bumpStreakIfNeeded();

          final shouldPrompt = await homeVM.shouldPromptGoals();
          if (shouldPrompt) {
            // executed after the X-second delay, but check if widget is still mounted
            Future.delayed(const Duration(seconds: 45), () {
              if (mounted) {
                _promptForGoals(context);
              }
            });
          }
        }
      }
    });
  }

  void _promptForGoals(BuildContext ctx) {
    String todayGoal = '';
    String weekGoal  = '';
    final homeVM =  ctx.read<HomeViewModel>();

    // Mark that prompt was shown today
    homeVM.markGoalPromptShown();

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
              decoration: InputDecoration(
                  hintText: homeVM.currentFocus,
                  labelText: "what's ya goal today?"
              ),
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
            child: Text('Skip', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
          ),
          TextButton(
            onPressed: () {
              if (todayGoal.trim().isNotEmpty) {
                homeVM.setFocusGoal(todayGoal.trim());
              }
              if (weekGoal.trim().isNotEmpty || weekGoal.trim().isEmpty) {
                homeVM.setWeeklyGoal(weekGoal.trim());
              }
              Navigator.pop(ctx);
            },
            child: Text('Save', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
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
                  Text("$streak", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.headlineLarge?.color)),
                  const SizedBox(width: 4),
                  Icon(Icons.local_fire_department_rounded, color: Colors.redAccent)
                ],
              ),

              Text("Hey $userName!", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),

              const SizedBox(height: 30),

              Text("Let's not let procrastination win today!!",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.headlineLarge?.color),
              ),

              const SizedBox(height: 50),

              Text("Set a focus goal and be productive!",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Theme.of(context).textTheme.bodyLarge?.color)),

              const SizedBox(height: 10),

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
                          color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3) : Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.4) : Theme.of(context).dividerColor.withValues(alpha: 0.4)),
                          boxShadow: [
                            BoxShadow(color: Theme.of(context).shadowColor.withValues(alpha: 0.1), blurRadius: 6, offset: const Offset(2, 4))
                          ],
                        ),
                        child: Text(
                          suggestion,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                              color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6)),
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
                    _InfoTile(title: "Today’s Goal", subtitle: selectedFocus, editFocus: () {_promptForGoals(context);}),

                    _InfoTile(title: "Weekly Goal", subtitle: weeklyGoal, editFocus: () { _promptForGoals(context); }),

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
  final String title;
  final String subtitle;
  final VoidCallback editFocus;

  const _InfoTile({required this.title, required this.subtitle, required this.editFocus});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            TextButton(
              child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.titleMedium?.color)),
              onPressed: () {
                editFocus();
              },
            ),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Theme.of(context).textTheme.bodyMedium?.color),
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
          Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Theme.of(context).textTheme.titleMedium?.color)),
          Slider(
            min: min, max: max,
            divisions: divisions,
            activeColor: Theme.of(context).colorScheme.primary,
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
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
              border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                    color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
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