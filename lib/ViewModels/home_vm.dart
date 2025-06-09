import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import '../Utils/shared_prefs_service.dart';
import '../Utils/streak_repo.dart';

class HomeViewModel extends ChangeNotifier{
  String? _username;
  int _streak = 0;
  String? _currentFocus;
  String _mood = 'Chill';
  final StreakRepository streakRepo;
  bool _disposed = false;
  String? _weeklyGoal;
  bool _isAuthenticated = false;

  // constructor that loads from preferences first
  HomeViewModel(this.streakRepo) {
    _isAuthenticated = FirebaseAuth.instance.currentUser != null;
    
    if (_isAuthenticated) {
      loadFromPrefs();
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

  Future<bool> shouldPromptGoals() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;                   // not signed in

    final snap = await FirebaseFirestore.instance.collection('Users').doc(uid).get();

    if (!snap.exists) return true;                  // user doc missing

    final data = snap.data() ?? {};
    _currentFocus = data['currentFocus'];           // may be null
    _weeklyGoal = data['weeklyGoal'];             // may be null
    notifyListeners();

    return _currentFocus == null;
  }

  Future<void> _mergeIntoUserDoc(Map<String, dynamic> data) async {
    if (!_isAuthenticated) return;  // Check auth state first
    
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance
        .collection('Users')
        .doc(uid)
        .set(data, SetOptions(merge: true));                     // merge == no overwrite
  }

  Future<void> bumpStreakIfNeeded() async {
    if (!_isAuthenticated) return;  // Check auth state first
    
    final int newStreak = await streakRepo.incrementIfNeeded();

    if (_disposed) return;           // VM no longer alive –> abort

    // write that number into SharedPreferences so it survives relaunches
    final prefs = await SharedPreferencesService.getInstance();
    await prefs.saveStreak(newStreak);

    // update local state & refresh UI
    _streak = newStreak;
    if (!_disposed) notifyListeners();
  }

  String get username => _isAuthenticated ? (_username ?? "Dude") : "Dude";
  int get streak => _isAuthenticated ? _streak : 0;
  String get mood => _mood;
  String? get currentFocus => _isAuthenticated ? _currentFocus : null;
  String? get weeklyGoal => _isAuthenticated ? _weeklyGoal : null;

  Future<void> loadFromPrefs() async {
    if (!_isAuthenticated) {
      clear();
      return;
    }

    final prefs = await SharedPreferencesService.getInstance();
    _username = prefs.getUsername();
    _streak = prefs.getStreak() ?? 0;
    _currentFocus = prefs.getCurrentFocus();
    _weeklyGoal = prefs.getWeeklyGoal();
    notifyListeners();
  }

  Future<void> setFocusGoal(String focus) async {
    if (!_isAuthenticated) return;  // Check auth state first
    
    final prefs = await SharedPreferencesService.getInstance();
    await prefs.saveCurrentFocus(focus);
    _currentFocus = focus;
    await _mergeIntoUserDoc({
      'currentFocus': _currentFocus,
      'focusUpdatedAt': FieldValue.serverTimestamp()
    });
    notifyListeners();
  }

  Future<void> setWeeklyGoal(String goal) async {
    if (!_isAuthenticated) return;  // Check auth state first
    
    final prefs = await SharedPreferencesService.getInstance();
    await prefs.saveWeeklyGoal(goal);
    _weeklyGoal = goal.trim();
    await _mergeIntoUserDoc({
      'weeklyGoal': _weeklyGoal,
      'weeklyGoalUpdatedAt': FieldValue.serverTimestamp()
    });
    notifyListeners();
  }

  void clear() {
    _username = null;
    _currentFocus = null;
    _streak = 0;
    _mood = "Chill";
    _weeklyGoal = null;
    notifyListeners();
  }
}