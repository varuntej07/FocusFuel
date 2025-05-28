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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<HomeViewModel>().bumpStreakIfNeeded();
      }
    });
  }

  void _handleSuggestionTap(BuildContext context ,String suggestion) {
    final homeVM = Provider.of<HomeViewModel>(context, listen: false);
    if (suggestion.contains("Other")) {
      _showCustomFocusDialog(context);
    } else {
      homeVM.setFocusGoal(suggestion);
    }
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


  Widget _buildInfoRow(String emoji, String label, String value) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Text("$label: ", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: Colors.black.withAlpha(204))),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final homeVM = Provider.of<HomeViewModel>(context);   // gets all the details required on this page from Firestore
    final userName = homeVM.username;
    final streak = homeVM.streak;
    final selectedFocus = homeVM.currentFocus ?? "Focus on something";

    return Scaffold(
      body: SafeArea(
        child: Padding(
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

              const SizedBox(height: 30),

              const Text("Let's not let procrastination win today! Stay hard!!!",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
              ),

              const SizedBox(height: 30),

              Expanded(
                child: Center(
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
                            color: isSelected ? Colors.orange.shade100.withAlpha(160) : Colors.white.withAlpha(40),
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(color: isSelected ? Colors.deepOrange.withAlpha(100) : Colors.grey.withAlpha(40)),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 6, offset: const Offset(2, 4))
                            ],
                          ),
                          child: Text(
                            suggestion,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(20),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withAlpha(50)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      spreadRadius: 2, blurRadius: 12,
                      offset: const Offset(0, 5),
                    )
                  ],
                  backgroundBlendMode: BlendMode.overlay,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.bolt_rounded, color: Colors.orangeAccent),
                              const SizedBox(width: 8),
                              Text("Live Focus Report", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black.withAlpha(230)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildInfoRow("🧠", "Focus", selectedFocus),
                          const SizedBox(height: 10),
                          _buildInfoRow("⏱️", "Next Check-in", "45 min"),
                          const SizedBox(height: 10),
                          _buildInfoRow("😌", "Mood", "Chill"),
                          const SizedBox(height: 16),
                          Text(
                            "You're 45 minutes away from unlocking a win!",
                            style: TextStyle(fontStyle: FontStyle.italic, fontSize: 14, color: Colors.redAccent.withAlpha(140)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}