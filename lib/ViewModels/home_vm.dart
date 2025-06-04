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

  // constructor that loads from preferences first
  HomeViewModel(this.streakRepo) {
    loadFromPrefs();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<bool> shouldPromptGoals() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return true;                   // not signed in

    final snap = await FirebaseFirestore.instance.collection('Users').doc(uid).get();

    if (!snap.exists) return true;                  // user doc missing

    final data = snap.data() ?? {};
    _currentFocus = data['currentFocus'];           // may be null
    _weeklyGoal = data['weeklyGoal'];             // may be null
    notifyListeners();

    return _currentFocus == null;
  }

  Future<void> _mergeIntoUserDoc(Map<String, dynamic> data) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;          // get UID
    if (uid == null) return;                                     // not signed in

    await FirebaseFirestore.instance
        .collection('Users')
        .doc(uid)
        .set(data, SetOptions(merge: true));                     // merge == no overwrite
  }

  Future<void> bumpStreakIfNeeded() async {
    final int newStreak = await streakRepo.incrementIfNeeded();

    if (_disposed) return;           // VM no longer alive –> abort

    // write that number into SharedPreferences so it survives relaunches
    final prefs = await SharedPreferencesService.getInstance();
    await prefs.saveStreak(newStreak);

    // update local state & refresh UI
    _streak = newStreak;
    if (!_disposed) notifyListeners();
  }

  String get username => _username ?? "Dude";
  int get streak => _streak;
  String get mood => _mood;
  String? get currentFocus => _currentFocus;
  String? get weeklyGoal => _weeklyGoal;

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferencesService.getInstance();
    _username = prefs.getUsername();
    _streak = prefs.getStreak() ?? 0;
    _currentFocus = prefs.getCurrentFocus();
    _weeklyGoal = prefs.getWeeklyGoal();
    notifyListeners();
  }

  Future<void> setFocusGoal(String focus) async {
    final prefs = await SharedPreferencesService.getInstance();
    await prefs.saveCurrentFocus(focus);
    _currentFocus = focus;
    await _mergeIntoUserDoc({
      'currentFocus' : _currentFocus,
      'focusUpdatedAt' : FieldValue.serverTimestamp()
    });
    notifyListeners();
  }

  Future<void> setWeeklyGoal(String goal) async {
    final prefs = await SharedPreferencesService.getInstance();
    await prefs.saveWeeklyGoal(goal);
    _weeklyGoal = goal.trim();
    await _mergeIntoUserDoc({
      'weeklyGoal' : _weeklyGoal,
      'weeklyGoalUpdatedAt' : FieldValue.serverTimestamp()
    });
    notifyListeners();
  }

  void clear(){
    _username = null;
    _currentFocus = null;
    _streak = 0;
    _mood = "Chill";
    notifyListeners();
  }
}