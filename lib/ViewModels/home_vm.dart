import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import '../Services/shared_prefs_service.dart';
import '../Services/streak_repo.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';

/// HomeViewModel manages the home screen state and user data
class HomeViewModel extends ChangeNotifier {
  static const String _defaultUsername = "Dude";
  static const String _defaultMood = "Chill";
  static const int _defaultStreak = 0;

  // State management
  HomeState _state = HomeState.initial;
  bool _isAuthenticated = false;
  bool _disposed = false;

  // private instance variables of this class that holds the current user's data
  String? _username;
  int _streak = _defaultStreak;
  String? _currentFocus;
  String _mood = _defaultMood;
  String? _weeklyGoal;
  String? _usersTask;
  String? _wins;
  String? _greeting;

  // Getters for the private variables
  String get username => _isAuthenticated ? (_username ?? _defaultUsername) : _defaultUsername;
  int get streak => _isAuthenticated ? _streak : 0;
  String get mood => _mood;
  String? get currentFocus => _isAuthenticated ? _currentFocus : null;
  String? get weeklyGoal => _isAuthenticated ? _weeklyGoal : null;
  String? get usersTask => _isAuthenticated ? _usersTask : null;
  String? get wins => _isAuthenticated ? _wins : null;
  String? get greeting => _isAuthenticated ? _greeting : null;

  HomeState get state => _state;
  bool get isAuthenticated => _isAuthenticated;

  // Services - injected dependencies
  final StreakRepository streakRepo;
  late SharedPreferencesService _prefsService;

  // Constructor to initialize the view model
  HomeViewModel(this.streakRepo) {
    _initializeViewModel();
  }

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Initializing view model
  // This is the main entry point that sets up the entire state management
  Future<void> _initializeViewModel() async {
    try {
      // Initialize shared preferences service
      _prefsService = await SharedPreferencesService.getInstance();

      // Checking authentication by taking User object of the currently signed-in user if there is one as a parameter
      _updateAuthenticationState(FirebaseAuth.instance.currentUser);

      // Set up authentication state listener for real-time auth changes
      _setupAuthenticationListener();

      // Load initial data if user is authenticated
      if (_isAuthenticated) {
        await loadFromPrefs();
        await _checkAndUpdateTimezone();
      } else {
        clearAllUserData(); // Clear all data if not authenticated
      }
      _isInitialized = true;
    } catch (error, stackTrace) {
      _handleError('Failed to initialize HomeViewModel', error, stackTrace);
    }
  }

  // Set up listener for authentication state changes, this ensures the ViewModel stays in sync with auth state
  void _setupAuthenticationListener() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      final wasAuthenticated = _isAuthenticated;
      _updateAuthenticationState(user);

      // Only reload data if authentication state actually changed
      if (wasAuthenticated != _isAuthenticated) {
        if (_isAuthenticated) {
          await loadFromPrefs();
        } else {
          clearAllUserData();
        }
      }
    });
  }

  // Update authentication state and notify listeners if needed
  void _updateAuthenticationState(User? user) {
    final newAuthState = user != null;      // This determines if user is authenticated
    if (_isAuthenticated != newAuthState) {
      _isAuthenticated = newAuthState;

      if (!_disposed) notifyListeners();
    }
  }

  // Check if goals need to be prompted and returns true if currentFocus is missing, indicating setup is incomplete
  Future<bool> shouldPromptGoals() async {
    if (!_isAuthenticated) return false;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return false;

      final snap = await FirebaseFirestore.instance.collection('Users').doc(uid).get();
      if (!snap.exists) return true;

      final data = snap.data() ?? {};
      _currentFocus = data['currentFocus'];           // may be null

      // Check if prompt was already shown today
      final lastPromptDate = data['lastGoalPromptDate'];
      final today = DateTime.now();
      final todayString = '${today.year}-${today.month}-${today.day}';

      // If prompt was shown today, don't show again
      if (lastPromptDate == todayString) {
        if (!_disposed) notifyListeners();
        return false;
      }

      if (!_disposed) notifyListeners();

      return _currentFocus == null;
    } catch (error, stackTrace) {
      _handleError('Failed to show alert dialog to ask for user focus/goal', error, stackTrace);
      return false;
    }
  }

  Future<String?> shouldGreet() async {
    if (!_isAuthenticated) return null;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return null;

      final snap = await FirebaseFirestore.instance.collection('Users').doc(uid).get();
      if (!snap.exists) return null;

      final data = snap.data() ?? {};
      final lastGreetingDate = data['lastGreetingsShownAt'];
      final today = DateTime.now();
      final todayString = '${today.year}-${today.month}-${today.day}';

      // Already greeted today
      if (lastGreetingDate == todayString) return null;

      // Otherwise return a motivational greeting
      final greeting = await _generateMotivationalGreeting();

      await markGreetingsShown();

      return greeting;
    } catch (error, stackTrace) {
      _handleError('Failed to decide greeting', error, stackTrace);
      return null;
    }
  }

  Future<String> _generateMotivationalGreeting() async {
    try {
      final generateGreeting = FirebaseFunctions.instance.httpsCallable(
          'generateGreeting',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 30))
      );

      final result = await generateGreeting.call({
        'prompt': '''
                  Generate one blunt, high-impact quote tailored for users who already exhibit passion, discipline, and adrenaline-fueled drive. 
                  This quote will be displayed on a mobile screen immediately after the app is opened—assume the user is already awake, committed, and seeking reinforcement, not initiation.
                  Avoid generic commands like "wake up" or "get to work." 
                  Instead, deliver a raw, intense, David Goggins-style message that reinforces mental toughness, relentless pursuit, and staying locked in. NO markdown, NO hyphen, NO explanation—return only the quote.
                '''
      });

      final rawText = (result.data['text'] as String?)?.trim();
      String? text;

      if (rawText != null && rawText.length >= 2) {
        final firstChar = rawText[0];
        final lastChar = rawText[rawText.length - 1];

        if ((firstChar == '"' || firstChar == "'") && firstChar == lastChar) {
          text = rawText.substring(1, rawText.length - 1);
        }
      } else {
        text = rawText;
      }

      if (text == null || text.isEmpty) throw 'Empty';

      _greeting = text;
      if (!_disposed) notifyListeners();
      return text;
    } catch (error, stackTrace) {
      _handleError('Failed to call OpenAI for greeting message generation', error, stackTrace);
      return "Don't let procrastination win today, stay hard!";
    }
  }

  // Mark that goal prompt was shown today
  Future<void> markGoalPromptShown() async {
    if (!_isAuthenticated) return;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final today = DateTime.now();
      final todayString = '${today.year}-${today.month}-${today.day}';

      await FirebaseFirestore.instance.collection('Users').doc(uid).update({
        'lastGoalPromptDate': todayString,
      });
    } catch (error, stackTrace) {
      _handleError('Failed to mark goal prompt as shown today', error, stackTrace);
    }
  }

  Future<void> markGreetingsShown() async {
    if (!_isAuthenticated) return;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final today = DateTime.now();
      final todayString = '${today.year}-${today.month}-${today.day}';

      await FirebaseFirestore.instance.collection('Users').doc(uid).update({
        'lastGreetingWas': _greeting,
        'lastGreetingsShownAt': todayString,
      });

      await _prefsService.saveGreeting(_greeting ?? "Don't let procrastination win today");

    } catch (error, stackTrace) {
      _handleError('Failed to mark welcome message as shown today', error, stackTrace);
    }
  }

  // Update streak
  Future<void> bumpStreakIfNeeded() async {
    if (!_isAuthenticated) return;  // Check auth state first
    
    try {
      final int newStreak = await streakRepo.incrementIfNeeded();
      if (_disposed) return;

      await _prefsService.saveStreak(newStreak);
      _streak = newStreak;
      _updateState(HomeState.success);
      if (!_disposed) notifyListeners();
    } catch (error, stackTrace) {
      _handleError('Failed to bump streak ', error, stackTrace);
    }
  }

  // Set focus goal, updating both local preferences and Firestore
  Future<void> setFocusGoal(String focus) async {
    if (!_isAuthenticated || focus.trim().isEmpty) return;  // Check auth state first
    
    try {
      _updateState(HomeState.loading);
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // Update local preferences first for immediate UI feedback
      await _prefsService.saveCurrentFocus(focus);
      _currentFocus = focus;

      // Update Firestore with focus and timestamp
      await _mergeIntoUserDoc({
        'currentFocus': _currentFocus,
        'focusUpdatedAt': FieldValue.serverTimestamp()
      });

      // Save the new focus to history
      if (focus.trim().isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('Users')
            .doc(uid)
            .collection('focusHistory')
            .add({
          'content': focus.trim(),
          'enteredAt': FieldValue.serverTimestamp(),
          'wasCompleted': false,              // should track this based on user action
        });
      }

      _updateState(HomeState.success);
    } catch (error, stackTrace) {
      _handleError('Failed to set focus goal:', error, stackTrace);
    }
  }

  // Set weekly goal updating both local preferences and Firestore
  Future<void> setWeeklyGoal(String goal) async {
    if (!_isAuthenticated) return;  // Check auth state first
    
    try {
      _updateState(HomeState.loading);

      final weeklyGoal = goal.trim();
      final uid = FirebaseAuth.instance.currentUser!.uid;

      try {
        if (goal.trim().isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('Users')
              .doc(uid)
              .collection('goalHistory')
              .add({
            'content': _weeklyGoal,
            'enteredAt': FieldValue.serverTimestamp(),
            'wasAchieved': false,
          });
        }
      } catch (error, stackTrace) {
        _handleError('Failed to save goal to history', error, stackTrace);
      }

      await _prefsService.saveWeeklyGoal(weeklyGoal);       // Updating local preferences first
      _weeklyGoal = weeklyGoal.isEmpty ? null : weeklyGoal;

      await _mergeIntoUserDoc({
        'weeklyGoal': _weeklyGoal,
        'weeklyGoalUpdatedAt': FieldValue.serverTimestamp()
      });

      _updateState(HomeState.success);

    } catch (error, stackTrace) {
      _handleError('Failed to set weekly goal: ', error, stackTrace);
    }
  }

  bool _isGeneratingQuestions = false;      // Flag to track if questions are being generated for user's Task To-Do
  bool get isGeneratingQuestions => _isGeneratingQuestions;

  final List<String> _taskQuotes = [
    "The secret of getting ahead is getting started.",
    "You are never too old to set another goal or to dream a new dream.",
    "It always seems impossible until it's done.",
    "The only way to do great work is to love what you do",
    "Your limitation—it's only your imagination.",
    "Great things never come from comfort zones.",
    "Dream it. Wish it. Do it.",
    "Success doesn't just find you. You have to go out and get it.",
    "The harder you work for something, the greater you'll feel when you achieve it.",
    "Don't stop when you're tired. Stop when you're done.",
    "Wake up with determination. Go to bed with satisfaction.",
    "Do something today that your future self will thank you for.",
    "It's going to be hard, but hard does not mean impossible.",
    "Sometimes we're tested not to show our weaknesses, but to discover our strengths.",
    "The key to success is to focus on goals, not obstacles.",
    "You don't need to see the whole staircase, just take the first step.",
    "The distance between dreams and reality is called action.",
    "Success is what happens after you've survived all your mistakes.",
    "Discipline is the bridge between goals and accomplishment.",
    "The only limit to our realization of tomorrow will be our doubts of today.",
    "Start where you are. Use what you have. Do what you can.",
    "If you want something you've never had, you must be willing to do something you've never done."
  ];

  Map<String, dynamic>? _taskQuestions;
  Map<String, dynamic>? get taskQuestions => _taskQuestions;    // so the dialog can access questions

  Future<void> setTasks(String task) async {
    if (!_isAuthenticated) return;

    try {
      _updateState(HomeState.loading);

      final uid = FirebaseAuth.instance.currentUser!.uid;
      final usersTask = task.trim();      // local variable to avoid unnecessary updates

      // Check if task has changed since last update and update Firestore if so
      if (usersTask != _usersTask) {
        if (usersTask.isNotEmpty) {           // saving it to history first if not empty
          await FirebaseFirestore.instance
              .collection('Users')
              .doc(uid)
              .collection('taskHistory')
              .add({
            'content': usersTask,
            'enteredAt': FieldValue.serverTimestamp(),
            'completedAt': null,
            'isActive': true,
          });
        }

        await _prefsService.saveUsersTask(usersTask); // Updating local preferences first

        _usersTask = usersTask.isEmpty ? null : usersTask;

        // then updating Firestore with task and timestamp
        await _mergeIntoUserDoc({
          'usersTask': _usersTask,
          'usersTaskUpdatedAt': FieldValue.serverTimestamp()
        });

        _updateState(HomeState.success);

        // Show enhancement dialog only if task is not empty
        if (_usersTask != null && _usersTask!.isNotEmpty) {
          await _showTaskEnhancementDialog(); // Show the dialog first with quote only

          // generating questions in the background to avoid blocking UI (no need to await)
          _isGeneratingQuestions = true;
          _generateTaskQuestions().then((_) {
            _isGeneratingQuestions = false;
            if (!_disposed) notifyListeners(); // Updates any listeners (like the dialog)
          }).catchError((error, stackTrace) {
            _handleError(
                'Failed to generate task questions', error, stackTrace);
            _isGeneratingQuestions = false;
            _taskQuestions = null;
            if (!_disposed) notifyListeners();
          });
        }
        if (!_disposed) notifyListeners();
      }
    } catch (error, stackTrace) {
      _handleError('Failed to set Tasks: ', error, stackTrace);
    }
  }

  // Show task enhancement dialog with a quote
  Future<void> _showTaskEnhancementDialog() async {
    final random = Random();
    final quote = _taskQuotes[random.nextInt(_taskQuotes.length)];

    _showTaskDialog(quote);     // using the callback to show the dialog with the quote
  }

  Function(String, String, Map<String, dynamic>?, Function(Map<String, String>))? _showDialogCallback;

  // Show task enhancement dialog via callback
  void _showTaskDialog(String quote) {
    if (_showDialogCallback != null) {
      // Calls the callback with current data (questions might be null at this point)
      _showDialogCallback!(quote, _usersTask!, _taskQuestions, _saveTaskAnswers);
    }
  }

  // Set the callback method for showing the task enhancement dialog
  void setShowDialogCallback(Function(String, String, Map<String, dynamic>?, Function(Map<String, String>)) callback) {
    _showDialogCallback = callback;
  }

  // Generate questions using OpenAI (runs in background)
  Future<void> _generateTaskQuestions() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _taskQuestions = null;
        return;
      }

      // calls GPT defined in Firebase Functions with timeout and proper options
      final callable = FirebaseFunctions.instance.httpsCallable(
        'generateTaskQuestions',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );

      final result = await callable.call({
        'prompt': '''
                  Task: $_usersTask
                  Generate exactly 3 strategic questions with 3 multiple choice options each.
                  Goal: Questions should try to extract as much info as possible from user' task and background to send notifications related that task.
                  Make options cover 100% of possible answers that captures user' level.
                  No markdown, No explanation, Strictly return only JSON format with questions and options arrays.
                '''
      });

      // Parsing the response from GPT
      if (result.data != null && result.data is Map<String, dynamic>) {
        final data = result.data as Map<String, dynamic>;

        if (data['success'] == true && data['response'] != null) {
          _taskQuestions = jsonDecode(data['response']);        // Store questions in ViewModel
          // notifyListeners() is called in the .then() block of setTasks
        }
      }
    } on FirebaseFunctionsException catch (e) {
      _handleError('Firebase Functions Error: ${e.code}', e);
      _taskQuestions = null;
    } catch (error, stackTrace) {
      _handleError('Failed to call OpenAI for task questions', error, stackTrace);
      _taskQuestions = null;
    }
  }

  // Save task answers to Firestore
  Future<void> _saveTaskAnswers(Map<String, String> answers) async {
    if (!_isAuthenticated) return;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // Generate summarized task profile from user' answers to his task
      final taskProfile = await generateUserTaskProfile(answers);

      await FirebaseFirestore.instance.collection('UserTasks').add({
        'userId': uid,
        'task': _usersTask,
        'profile': taskProfile,         // AI-generated summary of users knowledge on the task he is about to work on
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Clear questions from memory
      _taskQuestions = null;

    } catch (error, stackTrace) {
      _handleError('Failed to save task answers', error, stackTrace);
    }
  }

  Future<String> generateUserTaskProfile(Map<String, String> answers) async {
    try {
      // Another Firebase Function call to GPT for generating task profile
      final callable = FirebaseFunctions.instance.httpsCallable(
        'generateTaskQuestions',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );

      String formattedQA = '';
      if (_taskQuestions != null && _taskQuestions!['questions'] != null) {
        final questions = _taskQuestions!['questions'] as List;
        questions.asMap().forEach((index, q) {
          final answer = answers['question_$index'] ?? 'No answer';
          formattedQA += 'Q${index + 1}: ${q['question']}\n';
          formattedQA += 'A${index + 1}: $answer\n\n';
        });
      }

      final result = await callable.call({
        'prompt': '''
          'task': $_usersTask,
          'user responses': $formattedQA
          Based on the task and user's answers, create a concise profile (max 100 words) that captures:
          1. User's experience level
          2. Specific goals
          3. Context and constraints
          4. Key preferences
          
          No markdown, No special characters, Just the summary.. Format as a small paragraph that can be used for generating personalized notifications later,
        '''
      });

      if (result.data != null && result.data['success'] == true && result.data['response'] != null) {
        return result.data['response'].toString();
      }

      throw Exception('Invalid response from generateTaskProfile');

    } catch (error, stackTrace) {
      _handleError('Failed to generate task profile', error, stackTrace);
      rethrow;    // Re-throw to handle it in _saveTaskAnswers
    }
  }

  Future<void> setWins(String win) async {
    if (!_isAuthenticated) return;

    try {
      _updateState(HomeState.loading);

      final wins = win.trim();

      final uid = FirebaseAuth.instance.currentUser!.uid;
      if (wins.isNotEmpty) {          // saving it to history first if not empty
        await FirebaseFirestore.instance
            .collection('Users')
            .doc(uid)
            .collection('wins')
            .add({
          'content': wins,
          'enteredAt': FieldValue.serverTimestamp(),
        });
      }

      await _prefsService.saveWins(wins);

      _wins = wins.isEmpty ? null : wins;

      await _mergeIntoUserDoc({
        'wins': _wins,
        'winsUpdatedAt': FieldValue.serverTimestamp()
      });

      _updateState(HomeState.success);

      if (!_disposed) notifyListeners();
    } catch (e, stackTrace) {
      _handleError('Failed to set wins: ', e, stackTrace);
    }
  }

  // Load data from local preferences - provides immediate data access without network calls
  Future<void> loadFromPrefs() async {
    if (!_isAuthenticated) {
      clearAllUserData();
      return;
    }

    try {
      _updateState(HomeState.loading);

      _username = _prefsService.getUsername();
      _streak = _prefsService.getStreak() ?? _defaultStreak;
      _currentFocus = _prefsService.getCurrentFocus();
      _weeklyGoal = _prefsService.getWeeklyGoal();
      _usersTask = _prefsService.getUsersTask();
      _wins = _prefsService.getWins();
      _greeting = _prefsService.getGreeting();

      _updateState(HomeState.success);

    } catch (error, stackTrace) {
      _handleError('Failed to load user data from preferences: ', error, stackTrace);
    }
  }

  Future<void> _checkAndUpdateTimezone() async {
    if (!_isAuthenticated) return;

    try {
      final currentTimezone = await FlutterTimezone.getLocalTimezone();

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('Users').doc(uid).update({
          'timezone': currentTimezone.toString(),
          'timezoneUpdatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (error, stackTrace) {
      _handleError('Failed to check and update timezone:', error, stackTrace);
    }
  }

  // Merge data into user document
  Future<void> _mergeIntoUserDoc(Map<String, dynamic> data) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance
        .collection('Users')
        .doc(uid)
        .set(data, SetOptions(merge: true));
  }

  // Clear all data
  void clearAllUserData() {
    _username = null;
    _currentFocus = null;
    _streak = _defaultStreak;
    _mood = _defaultMood;
    _weeklyGoal = null;
    _usersTask = null;
    _wins = null;
    _greeting = null;
    _updateState(HomeState.initial);
  }

  // Update the ViewModel state and notify listeners
  void _updateState(HomeState newState) {
    if (_state != newState) {
      _state = newState;

      if (!_disposed) notifyListeners();
    }
  }

  // Handle errors consistently across the ViewModel
  void _handleError(String context, dynamic error, [StackTrace? stackTrace]) {
    FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace ?? StackTrace.current,
        information: ['HomeViewModel: $context']
    );
    _updateState(HomeState.error);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Represents the different states of the HomeViewModel
enum HomeState {
  initial,      // Initial state when ViewModel is first created
  loading,      // Loading state during async operations
  success,      // Success state when operations complete successfully
  error          // Error state when operations fail
}