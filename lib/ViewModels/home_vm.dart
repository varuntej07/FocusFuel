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

  // constructor that loads from preferences first
  HomeViewModel(this.streakRepo) {
    loadFromPrefs();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
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

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferencesService.getInstance();
    _username = prefs.getUsername();
    _streak = prefs.getStreak() ?? 0;
    _currentFocus = prefs.getCurrentFocus();
    notifyListeners();
  }

  Future<void> setFocusGoal(String focus) async {
    final prefs = await SharedPreferencesService.getInstance();
    await prefs.saveCurrentFocus(focus);
    _currentFocus = focus;
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