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

              const SizedBox(height: 30),

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
                            item: 'taskToDo',
                            onTap: () => _showWhiteBoard(context, "Task To-Do",),
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
                            items: ["Nothing yet"],
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
        height: 176,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.titleMedium?.color,
                ),
              ),
              SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      if (item != null)
                        Text(
                          item!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
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
  showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (BuildContext context) {
      return Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 60,
            left: 20,
            right: 20,
          ),
          height: MediaQuery.of(context).size.height * 0.6,
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: _WhiteBoardContent(
                title: title,
                initialItems: const [],
                onSave: (List<String> savedItems) {
                  print('Saved items: $savedItems');
                },
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _WhiteBoardContent extends StatefulWidget {
  final String title;
  final Function(List<String>) onSave;
  final List<String> initialItems;

  const _WhiteBoardContent({
    required this.title,
    required this.onSave,
    this.initialItems = const [],
  });

  @override
  State<_WhiteBoardContent> createState() => _WhiteBoardContentState();
}

class _WhiteBoardContentState extends State<_WhiteBoardContent> {
  late List<TextEditingController> controllers;
  late List<String> items;

  @override
  void initState() {
    super.initState();
    items = List.from(widget.initialItems);
    if (items.isEmpty) {
      items.add(''); // Start with one empty item
    }
    controllers = items.map((item) => TextEditingController(text: item)).toList();
  }

  @override
  void dispose() {
    for (var controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addNewItem() {
    setState(() {
      items.add('');
      controllers.add(TextEditingController());
    });
  }

  void _removeItem(int index) {
    if (controllers.length > 1) {
      setState(() {
        controllers[index].dispose();
        controllers.removeAt(index);
        items.removeAt(index);
      });
    }
  }

  void _save() {
    List<String> savedItems = controllers
        .map((controller) => controller.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    widget.onSave(savedItems);
    Navigator.of(context).pop();
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
          // Minimal header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                // Minimal close button
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
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ListView.builder(
                itemCount: controllers.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Minimal bullet point
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.only(right: 16, top: 12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                        ),

                        // Clean text input that looks like handwriting
                        Expanded(
                          child: TextField(
                            controller: controllers[index],
                            style: TextStyle(
                              fontSize: 16,
                              color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                              height: 1.4,
                              fontWeight: FontWeight.w400,
                            ),
                            decoration: InputDecoration(
                              hintText: index == 0 ? 'Start writing...' : '',
                              hintStyle: TextStyle(
                                color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.3),
                                fontSize: 16,
                                fontStyle: FontStyle.italic,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 4),
                              isDense: true,
                            ),
                            maxLines: null,
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) => _addNewItem(),
                          ),
                        ),

                        // Minimal remove option (only show on long press or when text is empty)
                        if (controllers.length > 1 && controllers[index].text.isEmpty)
                          GestureDetector(
                            onTap: () => _removeItem(index),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8, top: 8),
                              child: Icon(Icons.remove, size: 16, color: Colors.red),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // Bottom actions
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: Row(
              children: [
                // Minimal add line button
                GestureDetector(
                  onTap: _addNewItem,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add,
                          size: 16,
                          color: isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black54,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'line',
                          style: TextStyle(fontSize: 14, color: isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ),

                // Simple save button
                GestureDetector(
                  onTap: _save,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white.withValues(alpha: 0.8) : Colors.black.withValues(alpha: 0.8),
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
}