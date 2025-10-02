import 'package:flutter/material.dart';
import 'package:focus_fuel/Views/screens/task_enhancement_dialogs.dart';
import 'package:provider/provider.dart';
import '../../ViewModels/home_vm.dart';
import '../../ViewModels/auth_vm.dart';
import 'subscription_page.dart';

class HomeFeed extends StatefulWidget {
  const HomeFeed({super.key});

  @override
  createState() => _HomeFeedState();
}

class _HomeFeedState extends State<HomeFeed> {

  String? selectedFocus;

  @override
  void initState(){
    super.initState();
    // Calling once, right after the first build frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        final homeVM = context.read<HomeViewModel>();

        homeVM.setShowDialogCallback((quote, task, questions, onSubmit) {
          if (mounted) {          // This is the actual callback that shows the dialog
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return TaskEnhancementDialog(
                  quote: quote,
                  task: task,
                  questions: questions, // Might be null initially
                  onAnswersSubmitted: onSubmit, // Points to _saveTaskAnswers in ViewModel
                );
              },
            );
          }
        });

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
          await homeVM.shouldGreet();
        }
      }
    });
  }

  void _promptForGoals(BuildContext ctx) {
    String todayGoal = '';
    final homeVM = ctx.read<HomeViewModel>();

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
              Navigator.pop(ctx);
            },
            child: Text('Save', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final homeVM = Provider.of<HomeViewModel>(context);   // gets all the details required on this page from Firestore
    final authVM = Provider.of<AuthViewModel>(context);
    final userName = homeVM.username;
    final streak = homeVM.streak;
    final selectedFocus = homeVM.currentFocus ?? "Focus on something";
    final weeklyGoal = homeVM.weeklyGoal ?? "Set a weekly goal";
    final task = homeVM.usersTask;
    final wins = homeVM.wins;
    final greeting = homeVM.greeting;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            children: [
              // Trial warning banner
              if (authVM.shouldShowTrialWarning)
                Container(
                  padding: EdgeInsets.all(12),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: authVM.remainingTrialDays == 1
                        ? Colors.red.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: authVM.remainingTrialDays == 1 ? Colors.red : Colors.orange,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning,
                        color: authVM.remainingTrialDays == 1 ? Colors.red : Colors.orange,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              authVM.remainingTrialDays == 1
                                  ? 'Trial ends tomorrow!'
                                  : 'Trial ending soon',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: authVM.remainingTrialDays == 1 ? Colors.red : Colors.orange,
                              ),
                            ),
                            Text(
                              '${authVM.remainingTrialDays} day${authVM.remainingTrialDays == 1 ? '' : 's'} of unlimited notifications left',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                          );
                        },
                        child: Text(
                          'Upgrade',
                          style: TextStyle(
                            color: authVM.remainingTrialDays == 1 ? Colors.red : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

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

              Text(
                greeting ?? "Don't let procrastination win today",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.headlineLarge?.color),
              ),

              const SizedBox(height: 36),

              Text(
                "Your Focus Dashboard",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _InfoTile(
                            title: "Today's Focus",
                            item: selectedFocus,
                            onTap: () => _showWhiteBoard(context, "Today's Focus",),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _InfoTile(
                            title: "Task To-Do",
                            item: task,
                            onTap: () => _showWhiteBoard(context, "Task To-Do",),   // Opens whiteboard dialog
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _InfoTile(
                            title: "Weekly Goal",
                            item: weeklyGoal,
                            onTap: () => _showWhiteBoard(context, "Weekly Goal",),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _InfoTile(
                            title: "My Small Wins",
                            items: [wins ?? "No wins yet"],
                            onTap: () => _showWhiteBoard(context, "My Small Wins",),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}


// _InfoTile widget to include an emoji for top cards
class _InfoTile extends StatelessWidget {
  final String title;
  final String? item;  // For single string items
  final List<String>? items;  // For multiple string items
  final VoidCallback onTap;

  const _InfoTile({required this.title, this.items, required this.onTap, this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 225,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 3)
            ),
          ]
        ),
        child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.titleMedium?.color,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      if (item != null)
                        Text(
                          item!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: (item == "Focus on something" ||
                                item == "Set a weekly goal" ||
                                item == "Task To-Do" ||
                                item == "My Small Wins")
                                ? Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5)
                                : Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                            fontStyle: (item == "Focus on something" ||
                                item == "Set a weekly goal" ||
                                item == "Task To-Do" ||
                                item == "My Small Wins")
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        )
                      else if (items != null)
                        ...items!.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            item,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                            ),
                          ),
                        )),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      );
    }
}

void _showWhiteBoard(BuildContext context, String title) {
  final homeVM = Provider.of<HomeViewModel>(context, listen: false);      // Gets ViewModel instance

  // Get current value based on title
  String? currentValue;

  if (title == "Today's Focus") {
    currentValue = homeVM.currentFocus;
  } else if (title == "Weekly Goal") {
    currentValue = homeVM.weeklyGoal;
  } else if (title == "Task To-Do") {
    currentValue = homeVM.usersTask;
  } else if (title == "My Small Wins") {
    currentValue = homeVM.wins;
  }

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) {
      return  Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 60,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20, // This handles keyboard
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: 350,
            child: Material(
              color: Colors.transparent,
              child: _WhiteBoardContent(
                title: title,
                initialValue: currentValue, // Pass current value
                onSave: (String savedText) async {
                  // Save based on title
                  if (title == "Today's Focus") {
                    await homeVM.setFocusGoal(savedText);
                  } else if (title == "Weekly Goal") {
                    await homeVM.setWeeklyGoal(savedText);
                  } else if (title == "Task To-Do") {
                    await homeVM.setTasks(savedText);
                  } else if (title == "My Small Wins") {
                    await homeVM.setWins(savedText);
                  }
                }
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return ScaleTransition(
        scale: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ),
        child: child,
      );
    },
  );
}

class _WhiteBoardContent extends StatefulWidget {
  final String title;
  final Function(String) onSave;
  final String? initialValue;

  const _WhiteBoardContent({
    required this.title,
    required this.onSave,
    this.initialValue,
  });

  @override
  State<_WhiteBoardContent> createState() => _WhiteBoardContentState();
}

class _WhiteBoardContentState extends State<_WhiteBoardContent> {
  late TextEditingController controller;
  List<TextEditingController> bulletControllers = [];
  late bool isBulletMode;

  late List<String> items;

  @override
  void initState() {
    super.initState();
    // Check if this is "My Small Wins" for bullet mode
    isBulletMode = widget.title == "My Small Wins";

    if (isBulletMode) {
      // Initialize bullet points
      _initializeBulletPoints();
    } else {
      // Initialize with current value or empty string
      controller = TextEditingController(text: widget.initialValue ?? '');
    }
  }

  void _initializeBulletPoints() {
    // Parse existing wins if any
    if (widget.initialValue != null && widget.initialValue!.isNotEmpty) {
      // Split by newlines and create controllers for each
      List<String> existingWins = widget.initialValue!.split('\n').where((win) => win.trim().isNotEmpty).toList();

      for (String win in existingWins) {
        bulletControllers.add(TextEditingController(text: win.trim()));
      }
    }

    // Always have at least one empty controller
    if (bulletControllers.isEmpty) {
      bulletControllers.add(TextEditingController());
    }
  }

  void _addNewBulletPoint() {
    setState(() {
      bulletControllers.add(TextEditingController());
    });

    // Focus the new text field after a brief delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (bulletControllers.isNotEmpty) {
        FocusScope.of(context).requestFocus(FocusNode());
      }
    });
  }

  @override
  void dispose() {
    if (isBulletMode) {
      for (var controller in bulletControllers) {
        controller.dispose();
      }
    } else {
      controller.dispose();
    }
    super.dispose();
  }


  void _save() async {
    String text = controller.text.trim();       // Gets the task text from TextField

    if (isBulletMode) {
      // Combine all bullet points
      List<String> wins = bulletControllers
          .map((controller) => controller.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      text = wins.join('\n');
    } else {
      text = controller.text.trim();
    }

    try {
      if (widget.title == "Task To-Do" && text.isNotEmpty && mounted) {
        Navigator.of(context).pop(); // Close whiteboard first only for Task To-Do, to show following dialogs with questions
      }

      // Calls the onSave callback passed from _showWhiteBoard and triggers homeVM.setTasks(text)
      await widget.onSave(text);

      // For other types, close after saving
      if (widget.title != "Task To-Do" && mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20), // Match the outer container
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                      letterSpacing: 0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                // close button
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      size: 20,
                      color: isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Whiteboard writing area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: isBulletMode ? _buildBulletPointView(isDark) : _buildSingleTextView(isDark),
            ),
          ),

          // Bottom actions
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end, // Align to right
              children: [
                GestureDetector(
                  onTap: _save,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onPrimary,
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

  Widget _buildSingleTextView(bool isDark) {
    return TextField(
      controller: controller,
      style: TextStyle(
        fontSize: 16,
        color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
        height: 1.4,
      ),
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      decoration: InputDecoration(
        hintText: _getHintText(),
        hintStyle: TextStyle(
          color: isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.4),
        ),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.all(8),
        focusedBorder: InputBorder.none,
        enabledBorder: InputBorder.none,
        fillColor: Colors.transparent, // Make background transparent
        filled: false, // Disable background fill
      ),
    );
  }

  Widget _buildBulletPointView(bool isDark) {
    return ListView.builder(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      itemCount: bulletControllers.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bullet point
              Container(
                margin: const EdgeInsets.only(top: 12, right: 12),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
              ),

              // Text field
              Expanded(
                child: TextField(
                  controller: bulletControllers[index],
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                    height: 1.4,
                  ),
                  decoration: InputDecoration(
                    hintText: index == 0 ? 'What is your small win that ya proud of...' : 'Another win...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.4),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    fillColor: Colors.transparent, // Make background transparent
                    filled: false, // Disable background fill
                  ),
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _addNewBulletPoint(),
                  maxLines: null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getHintText() {
    switch (widget.title) {
      case "Today's Focus":
        return "What's your main focus today?";
      case "Weekly Goal":
        return "What do you want to achieve this week?";
      case "Task To-Do":
        return "What tasks need to be completed?";
      case "My Small Wins":
        return "What small victories have you achieved?";
      default:
        return "Start writing...";
    }
  }
}