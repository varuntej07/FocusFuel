import 'dart:convert';

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

  static const String _lastSyncTimeKey = 'last_news_sync_time';
  static const String _lastCollectionDateKey = 'last_collection_date';

  Future<void> setLastSyncTime(DateTime time) async {
    await _preferences?.setString(_lastSyncTimeKey, time.toIso8601String());
  }

  DateTime? getLastSyncTime() {
    final timeStr = _preferences?.getString(_lastSyncTimeKey);
    return timeStr != null ? DateTime.parse(timeStr) : null;
  }

  Future<void> setLastCollectionDate(String date) async {
    await _preferences?.setString(_lastCollectionDateKey, date);
  }

  String? getLastCollectionDate() {
    return _preferences?.getString(_lastCollectionDateKey);
  }

  // Cache news articles
  Future<void> saveNewsArticles(List<Map<String, dynamic>> articles) async {
    final articlesJson = articles.map((article) => jsonEncode(article)).toList();
    await _preferences?.setStringList('cached_news_articles', articlesJson);
    await setLastSyncTime(DateTime.now());    // to track last sync time
  }

  List<Map<String, dynamic>>? getCachedNewsArticles() {
    final articlesJson = _preferences?.getStringList('cached_news_articles');
    if (articlesJson == null) return null;

    return articlesJson.map((articleStr) {
      return Map<String, dynamic>.from(jsonDecode(articleStr));
    }).toList();
  }

  // Cache last news fetch timestamp
  Future<void> saveLastNewsFetchTime() async {
    await _preferences?.setInt('last_news_fetch', DateTime.now().millisecondsSinceEpoch);
  }

  int? getLastNewsFetchTime() {
    return _preferences?.getInt('last_news_fetch');
  }

  // Cache selected tab articles separately (optional for tab-specific caching)
  Future<void> saveTabNewsArticles(int tabIndex, List<Map<String, dynamic>> articles) async {
    final articlesJson = articles.map((article) => jsonEncode(article)).toList();
    await _preferences?.setStringList('cached_news_tab_$tabIndex', articlesJson);
  }

  List<Map<String, dynamic>>? getCachedTabArticles(int tabIndex) {
    final articlesJson = _preferences?.getStringList('cached_news_tab_$tabIndex');
    if (articlesJson == null) return null;

    return articlesJson.map((articleStr) {
      return Map<String, dynamic>.from(jsonDecode(articleStr));
    }).toList();
  }
}