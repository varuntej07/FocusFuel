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

  Future<bool> isAuthenticated() async {
    return _preferences?.containsKey('uid') ?? false;
  }

  Future<void> logout() async {
    await _preferences?.clear();
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

  Future<void> saveUsersTask(String task) async {
    await _preferences?.setString('usersTask', task);
  }

  String? getUsersTask() {
    return _preferences?.getString('usersTask');
  }

  Future<void> saveWins(String win) async {
    await _preferences?.setString('wins', win);
  }

  String? getWins() {
    return _preferences?.getString('wins');
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

  // Cache news summaries with 24-hour expiration
  Future<void> saveNewsSummary(String articleTitle, Map<String, dynamic> summaryData) async {
    final summaryWithTimestamp = {
      ...summaryData,
      'cachedAt': DateTime.now().toIso8601String(),
    };
    await _preferences?.setString('summary_${articleTitle.hashCode}', jsonEncode(summaryWithTimestamp));
  }

  Map<String, dynamic>? getCachedSummary(String articleTitle) {
    final summaryJson = _preferences?.getString('summary_${articleTitle.hashCode}');
    if (summaryJson == null) return null;

    final summaryData = Map<String, dynamic>.from(jsonDecode(summaryJson));
    final cachedAt = DateTime.parse(summaryData['cachedAt']);

    // Check if cache is older than 24 hours
    if (DateTime.now().difference(cachedAt).inHours >= 24) {
      _preferences?.remove('summary_${articleTitle.hashCode}');
      return null;
    }

    return summaryData;
  }

  // Save/remove bookmarked articles
  Future<void> saveBookmarkedArticle(Map<String, dynamic> article) async {
    final bookmarks = getBookmarkedArticles();
    final articleId = _getArticleId(article);

    // Remove if already exists to avoid duplicates
    bookmarks.removeWhere((bookmark) => _getArticleId(bookmark) == articleId);

    // Add to beginning of list
    bookmarks.insert(0, article);

    final bookmarksJson = bookmarks.map((bookmark) => jsonEncode(bookmark)).toList();
    await _preferences?.setStringList('bookmarked_articles', bookmarksJson);
  }

  Future<void> removeBookmarkedArticle(Map<String, dynamic> article) async {
    final bookmarks = getBookmarkedArticles();
    final articleId = _getArticleId(article);

    bookmarks.removeWhere((bookmark) => _getArticleId(bookmark) == articleId);

    final bookmarksJson = bookmarks.map((bookmark) => jsonEncode(bookmark)).toList();
    await _preferences?.setStringList('bookmarked_articles', bookmarksJson);
  }

  List<Map<String, dynamic>> getBookmarkedArticles() {
    final bookmarksJson = _preferences?.getStringList('bookmarked_articles');
    if (bookmarksJson == null) return [];

    return bookmarksJson.map((bookmarkStr) {
      return Map<String, dynamic>.from(jsonDecode(bookmarkStr));
    }).toList();
  }

  bool isArticleBookmarked(Map<String, dynamic> article) {
    final bookmarks = getBookmarkedArticles();
    final articleId = _getArticleId(article);
    return bookmarks.any((bookmark) => _getArticleId(bookmark) == articleId);
  }

  // Helper method to generate unique article ID
  String _getArticleId(Map<String, dynamic> article) {
    final title = article['title'] ?? '';
    final link = article['link'] ?? '';
    return '${title}_$link'.hashCode.toString();
  }

  Future<void> saveThemeMode(bool isDarkMode) async {
    await _preferences?.setBool('isDarkMode', isDarkMode);
  }

  bool? getThemeMode() {
    return _preferences?.getBool('isDarkMode');
  }

  Future<void> saveGreeting(String greeting) async {
    await _preferences?.setString('greeting', greeting);
  }

  String? getGreeting() {
    return _preferences?.getString('greeting');
  }
}