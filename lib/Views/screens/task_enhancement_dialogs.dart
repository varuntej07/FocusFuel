import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../ViewModels/home_vm.dart';

class TaskEnhancementDialog extends StatefulWidget {
  final String quote;
  final String task;
  final Map<String, dynamic>? questions;
  final Function(Map<String, String>) onAnswersSubmitted;

  const TaskEnhancementDialog({
    super.key,
    required this.quote,
    required this.task,
    required this.questions,
    required this.onAnswersSubmitted,
  });

  @override
  State<TaskEnhancementDialog> createState() => _TaskEnhancementDialogState();
}

class _TaskEnhancementDialogState extends State<TaskEnhancementDialog> {
  Map<String, String> answers = {};
  Timer? _timer;
  bool _showQuestions = false;
  int _currentQuestionIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _timer = Timer(Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showQuestions = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The dialog uses Consumer to listen to ViewModel changes
    return Consumer<HomeViewModel>(
      builder: (context, homeVM, child) {
        final questions = homeVM.taskQuestions;       // Gets questions (updated when available)
        final questionsList = questions?['questions'] as List? ?? [];

        return AlertDialog(
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: Column(
              children: [
                // Quote - always visible and shows immediately
                if (!_showQuestions) ...[
                  Expanded(
                    child: Center(
                      child: Text(
                        widget.quote,
                        style: TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.bold, fontSize: 22),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],

                // Questions section
                if (_showQuestions) ...[
                  if (questions != null && questionsList.isNotEmpty) ...[
                    LinearProgressIndicator(
                      value: (_currentQuestionIndex + 1) / questionsList.length,
                      backgroundColor: Colors.grey[300],
                    ),

                    SizedBox(height: 10),

                    Text(
                      'Question ${_currentQuestionIndex + 1} of ${questionsList.length}',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),

                    SizedBox(height: 20),

                    // Question content
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        physics: NeverScrollableScrollPhysics(), // Disable swipe
                        itemCount: questionsList.length,
                        itemBuilder: (context, index) {
                          return _buildSingleQuestion(questionsList[index], index);
                        },
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 10),
                          Text("Hold on! Tryna know more about ya task to help you break it down.")
                        ]
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          actions: _buildActions(questions, questionsList),
        );
      },
    );
  }

  Widget _buildSingleQuestion(Map<String, dynamic> question, int index) {
    final questionText = question['question'] as String? ?? '';
    final options = question['options'] as List? ?? [];
    final questionKey = 'question_$index';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            questionText,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 20),
          ...options.map((option) {
            return RadioListTile<String>(
              title: Text(option as String),
              value: option,
              groupValue: answers[questionKey],           // stored in local state
              onChanged: (value) {
                setState(() {
                  answers[questionKey] = value!;        // updates answers map
                });
              },
              dense: true,
            );
          }),
        ],
      ),
    );
  }

  List<Widget> _buildActions(Map<String, dynamic>? questions, List questionsList) {
    if (!_showQuestions || questions == null || questionsList.isEmpty) {
      return [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close'),
        ),
      ];
    }

    final isLastQuestion = _currentQuestionIndex == questionsList.length - 1;
    final currentAnswer = answers['question_$_currentQuestionIndex'];

    return [
      if (_currentQuestionIndex > 0)
        TextButton(
          onPressed: () {
            setState(() {
              _currentQuestionIndex--;
              _pageController.previousPage(
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            });
          },
          child: Text('Back'),
        ),

      ElevatedButton(
        onPressed: currentAnswer == null ? null : () {
          if (isLastQuestion) {
            widget.onAnswersSubmitted(answers);         // This is _saveTaskAnswers
            Navigator.of(context).pop();
          } else {
            // Go to next question
            setState(() {
              _currentQuestionIndex++;
              _pageController.nextPage(
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            });
          }
        },
        child: Text(isLastQuestion ? 'Submit' : 'Next'),
      ),
    ];
  }
}