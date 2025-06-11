import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import '../Services/shared_prefs_service.dart';
import '../Services/streak_repo.dart';

class HomeViewModel extends ChangeNotifier {
  // State management
  HomeState _state = HomeState.initial;
  HomeState get state => _state;

  // User data
  String? _username;
  int _streak = 0;
  String? _currentFocus;
  String _mood = 'Chill';
  String? _weeklyGoal;
  bool _isAuthenticated = false;
  bool _disposed = false;

  // Getters
  String get username => _isAuthenticated ? (_username ?? "Dude") : "Dude";
  int get streak => _isAuthenticated ? _streak : 0;
  String get mood => _mood;
  String? get currentFocus => _isAuthenticated ? _currentFocus : null;
  String? get weeklyGoal => _isAuthenticated ? _weeklyGoal : null;
  bool get isAuthenticated => _isAuthenticated;

  // Services
  final StreakRepository streakRepo;
  late SharedPreferencesService _prefsService;

  // Constructor
  HomeViewModel(this.streakRepo) {
    _initialize();
  }

  // Initialize view model
  Future<void> _initialize() async {
    _prefsService = await SharedPreferencesService.getInstance();
    _isAuthenticated = FirebaseAuth.instance.currentUser != null;
    
    if (_isAuthenticated) {
      await loadFromPrefs();
    } else {
      clear(); // Clear all data if not authenticated
    }

    // Listen to auth state changes
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      _isAuthenticated = user != null;
      if (_isAuthenticated) {
        loadFromPrefs();
      } else {
        clear();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // Check if goals need to be prompted
  Future<bool> shouldPromptGoals() async {
    if (!_isAuthenticated) return false;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return false;

    final snap = await FirebaseFirestore.instance.collection('Users').doc(uid).get();
    if (!snap.exists) return true;                  // user doc missing

    final data = snap.data() ?? {};
    _currentFocus = data['currentFocus'];           // may be null
    _weeklyGoal = data['weeklyGoal'];             // may be null
    if (!_disposed) notifyListeners();

      return _currentFocus == null;
    } catch (e) {
      _state = HomeState.error;
      notifyListeners();
      return false;
    }
  }

  // Merge data into user document
  Future<void> _mergeIntoUserDoc(Map<String, dynamic> data) async {
    if (!_isAuthenticated) return;  // Check auth state first
    
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      await FirebaseFirestore.instance
          .collection('Users')
          .doc(uid)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      _state = HomeState.error;
      notifyListeners();
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
      _state = HomeState.success;
      if (!_disposed) notifyListeners();
    } catch (e) {
      _state = HomeState.error;
      notifyListeners();
    }
  }

  // Load data from preferences
  Future<void> loadFromPrefs() async {
    if (!_isAuthenticated) {
      clear();
      return;
    }

    try {
      _username = _prefsService.getUsername();
      _streak = _prefsService.getStreak() ?? 0;
      _currentFocus = _prefsService.getCurrentFocus();
      _weeklyGoal = _prefsService.getWeeklyGoal();
      _state = HomeState.success;
      notifyListeners();
    } catch (e) {
      _state = HomeState.error;
      if (!_disposed) notifyListeners();
    }
  }

  // Set focus goal
  Future<void> setFocusGoal(String focus) async {
    if (!_isAuthenticated) return;  // Check auth state first
    
    try {
      await _prefsService.saveCurrentFocus(focus);
      _currentFocus = focus;
      await _mergeIntoUserDoc({
        'currentFocus': _currentFocus,
        'focusUpdatedAt': FieldValue.serverTimestamp()
      });
      _state = HomeState.success;
      notifyListeners();
    } catch (e) {
      _state = HomeState.error;
      notifyListeners();
    }
  }

  // Set weekly goal
  Future<void> setWeeklyGoal(String goal) async {
    if (!_isAuthenticated) return;  // Check auth state first
    
    try {
      await _prefsService.saveWeeklyGoal(goal);
      _weeklyGoal = goal.trim();
      await _mergeIntoUserDoc({
        'weeklyGoal': _weeklyGoal,
        'weeklyGoalUpdatedAt': FieldValue.serverTimestamp()
      });
      _state = HomeState.success;
      notifyListeners();
    } catch (e) {
      _state = HomeState.error;
      notifyListeners();
    }
  }

  // Clear all data
  void clear() {
    _username = null;
    _currentFocus = null;
    _streak = 0;
    _mood = "Chill";
    _weeklyGoal = null;
    _state = HomeState.initial;
  }
}

// Home state enum for better state management
enum HomeState {
  initial,
  loading,
  success,
  error
}