import 'package:cloud_functions/cloud_functions.dart';
import 'shared_prefs_service.dart';

class NewsService {
  static final _functions = FirebaseFunctions.instance;
  final SharedPreferencesService _prefsService;

  NewsService(this._prefsService);

  Future<List<Map<String, dynamic>>> getNewsArticles({bool forceRefresh = false}) async {
    if (!forceRefresh && !_shouldSync()) {
      return _prefsService.getCachedNewsArticles() ?? [];  // returns cached articles if not force refresh
    }

    try {
      final callable = _functions.httpsCallable('getUserNewsFeed');     // Creates Firebase callable function to get user's news feed
      final result = await callable.call({
        'userId': _prefsService.getUserId(),  // gets user id from prefs to get user's news feed
      });

      if (result.data['success'] == true) {
        final articlesData = result.data['articles'] as List;

        final articles = articlesData.map((article) {
          return Map<String, dynamic>.from(article as Map);     // converts Map<Object?, Object?> to Map<String, dynamic>
        }).toList();

        await _prefsService.saveNewsArticles(articles);         // Caches articles locally

        if (articles.isNotEmpty) {
          await _prefsService.setLastCollectionDate(articles.first['collectionDate']);
        }

        return articles;          // Returns the articles to ViewModel
      }

      throw Exception(result.data['error'] ?? 'Failed to fetch articles');
    } catch (e) {
      print('Error in getNewsArticles: $e');
      return _prefsService.getCachedNewsArticles() ?? [];
    }
  }

  bool _shouldSync() {
    final lastSync = _prefsService.getLastSyncTime();       // gets last sync time from prefs
    if (lastSync == null) return true;      // First time, fetch fresh

    final now = DateTime.now();
    final timeSinceSync = now.difference(lastSync);

    if (timeSinceSync.inHours >= 12) return true;     // If 12+ hours old, fetch fresh

    final currentHour = now.hour;
    final lastSyncHour = lastSync.hour;

    // Smart sync: fetches only at 7am and 2pm daily
    if (lastSyncHour < 7 && currentHour >= 7) return true;
    if (lastSyncHour < 14 && currentHour >= 14) return true;

    if (now.day != lastSync.day) return true;         // New day, fetch fresh

    return false;         // Use cache
  }
}