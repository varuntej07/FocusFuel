import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesService {
  static SharedPreferencesService? _instance;
  static SharedPreferences? _preferences;

  // Singleton pattern
  static Future<SharedPreferencesService> getInstance() async {
    _instance ??= SharedPreferencesService();       // if null then assign, create wrapper once
    _preferences ??= await SharedPreferences.getInstance();     // open prefs once and assign
    return _instance!;
  }

  // cuz _preferences is static, every instance in this class sees the same pointer.

  Future<void> saveUsername(String username) async {
    await _preferences?.setString('username', username);
  }

  String? getUsername() {
    return _preferences?.getString('username');
  }

  Future<void> saveEmail(String email) async {
    await _preferences?.setString('email', email);
  }

  String? getEmail() {
    return _preferences?.getString('email');
  }

  Future<void> saveUserId(String uid) async {
    await _preferences?.setString('uid', uid);
  }

  String? getUserId() {
    return _preferences?.getString('uid');
  }

  Future<void> clearAll() async {
    await _preferences?.clear();
  }

  Future<void> saveStreak(int streak) async {
    await _preferences?.setInt('streak', streak);
  }

  int? getStreak() {
    return _preferences?.getInt('streak');
  }

  Future<void> saveCurrentFocus(String focus) async {
    await _preferences?.setString('currentFocus', focus);
  }

  String? getCurrentFocus() {
    return _preferences?.getString('currentFocus');
  }

  Future<void> saveWeeklyGoal(String goal) async {
    await _preferences?.setString('weeklyGoal', goal);
  }

  String? getWeeklyGoal() {
    return _preferences?.getString('weeklyGoal');
  }

  Future<void> saveNotificationInterval(int interval) async {
    await _preferences?.setInt('notificationInterval', interval);
  }

  int? getNotificationInterval() {
    return _preferences?.getInt('notificationInterval');
  }
}