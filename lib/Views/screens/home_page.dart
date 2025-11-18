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

          // Check and show trial dialog first
          final shouldShowTrial = await homeVM.shouldShowTrialDialog();
          if (shouldShowTrial && mounted) {
            _showTrialDialog(context);
          }

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

  void _showTrialDialog(BuildContext ctx) {
    final homeVM = ctx.read<HomeViewModel>();

    // Mark that trial dialog was shown
    homeVM.markTrialDialogShown();

    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.celebration, color: Colors.purple, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "Welcome to FocusFuel!",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "You're on a 14-day free trial with full premium access!",
              style: TextStyle(fontSize: 16, height: 1.4, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFeatureRow(Icons.notifications_active, "Unlimited AI notifications"),
                  SizedBox(height: 8),
                  _buildFeatureRow(Icons.chat_bubble, "Unlimited AI chat queries"),
                  SizedBox(height: 8),
                  _buildFeatureRow(Icons.volume_up, "Listen to articles"),
                  SizedBox(height: 8),
                  _buildFeatureRow(Icons.newspaper, "Personalized news feed"),
                  SizedBox(height: 8),
                  _buildFeatureRow(Icons.star, "And much more..."),
                ],
              ),
            ),
            SizedBox(height: 12),
            Text(
              "After your trial, subscribe for just \$4.49/month to keep all features!",
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Got it!',
              style: TextStyle(
                color: Colors.purple,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.purple, size: 20),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
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

              // Header: Username + Streak
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "Hey $userName! 👋",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.headlineLarge?.color,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        "$streak",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.headlineLarge?.color,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.local_fire_department_rounded, color: Colors.redAccent, size: 24),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Hero Focus Card (Full Width)
              _HeroFocusCard(
                focus: selectedFocus,
                onTap: () => _showWhiteBoard(context, "Today's Focus"),
              ),

              const SizedBox(height: 16),

              // Task and Weekly Goal Grid (2 columns)
              Row(
                children: [
                  Expanded(
                    child: _CompactInfoCard(
                      title: "Task To-Do",
                      icon: Icons.check_circle_outline,
                      iconColor: const Color(0xFF6366F1),
                      content: task != null && task.isNotEmpty ? task : "No tasks yet",
                      onTap: () => _showWhiteBoard(context, "Task To-Do"),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _CompactInfoCard(
                      title: "Weekly Goal",
                      icon: Icons.emoji_events,
                      iconColor: const Color(0xFFF59E0B),
                      content: weeklyGoal.isNotEmpty ? weeklyGoal : "Set a goal",
                      onTap: () => _showWhiteBoard(context, "Weekly Goal"),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Small Wins Card (Full Width)
              _WinsCard(
                wins: wins,
                onTap: () => _showWhiteBoard(context, "My Small Wins"),
              ),

              const SizedBox(height: 16),

              // Motivational Quote
              if (greeting != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF6366F1).withValues(alpha: 0.1),
                        const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    greeting,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                    ),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }
}


// Hero Focus Card with circular progress indicator
class _HeroFocusCard extends StatelessWidget {
  final String focus;
  final VoidCallback onTap;

  const _HeroFocusCard({
    required this.focus,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPlaceholder = focus == "Focus on something";

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 250,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF6366F1),
              const Color(0xFF8B5CF6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Title
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.track_changes, color: Colors.white, size: 24),
                const SizedBox(width: 8),
                const Text(
                  "Today's Focus",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Focus Text
            Text(
              focus,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isPlaceholder
                    ? Colors.white.withValues(alpha: 0.7)
                    : Colors.white,
                fontStyle: isPlaceholder ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Compact Info Card for Task and Weekly Goal
class _CompactInfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final String content;
  final VoidCallback onTap;

  const _CompactInfoCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.content,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPlaceholder = content == "No tasks yet" ||
        content == "Set a goal" ||
        content == "Task To-Do" ||
        content == "Weekly Goal";

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon and Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.titleMedium?.color,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  content,
                  style: TextStyle(
                    fontSize: 14,
                    color: isPlaceholder
                        ? Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5)
                        : Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                    fontStyle: isPlaceholder ? FontStyle.italic : FontStyle.normal,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Wins Card (Full Width)
class _WinsCard extends StatelessWidget {
  final String? wins;
  final VoidCallback onTap;

  const _WinsCard({
    required this.wins,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayWins = wins ?? "No wins yet";
    final isPlaceholder = wins == null || wins!.isEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF10B981).withValues(alpha: 0.15),
              const Color(0xFF059669).withValues(alpha: 0.15),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title with Icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.stars, color: Color(0xFF10B981), size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  "My Small Wins",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF10B981),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Wins Content
            Text(
              displayWins,
              style: TextStyle(
                fontSize: 14,
                color: isPlaceholder
                    ? Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5)
                    : Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                fontStyle: isPlaceholder ? FontStyle.italic : FontStyle.normal,
                height: 1.5,
              ),
            ),
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