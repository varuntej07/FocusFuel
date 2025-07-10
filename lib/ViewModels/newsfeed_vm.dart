import 'package:flutter/foundation.dart';
import '../services/shared_prefs_service.dart';

enum NewsLoadingState { idle, loading, loaded, error, refreshing }

class NewsFeedViewModel extends ChangeNotifier {
  List<Map<String, dynamic>> _articles = [];
  NewsLoadingState _loadingState = NewsLoadingState.idle;
  String? _errorMessage;
  int _selectedTabIndex = 0;

  late SharedPreferencesService _prefsService;

  final List<String> tabs = [
    'For You',
    'Top Stories',
    'AI',
    'Science',
    'Finance',
    'Sports',
    'weather'
  ];

  // Public getters
  List<Map<String, dynamic>> get articles => List.unmodifiable(_articles);
  NewsLoadingState get loadingState => _loadingState;
  String? get errorMessage => _errorMessage;
  int get selectedTabIndex => _selectedTabIndex;
  bool get isLoading => _loadingState == NewsLoadingState.loading;
  bool get isRefreshing => _loadingState == NewsLoadingState.refreshing;
  bool get hasArticles => _articles.isNotEmpty;

  // Initialize the view model
  Future<void> initialize() async {
    try {
      _prefsService = await SharedPreferencesService.getInstance();
      await loadNewsFeed();
    } catch (e) {
      _handleError('Failed to initialize: $e');
    }
  }

  // Handle tab selection
  void selectTab(int index) {
    if (index == _selectedTabIndex) return;

    _selectedTabIndex = index;
    notifyListeners();

    // TODO: Implement tab selection logic by loading articles for the selected tab
  }

  // Load news feed with caching - only from SharedPrefs for now
  Future<void> loadNewsFeed({bool forceRefresh = false}) async {
    if (_loadingState == NewsLoadingState.loading) return;

    try {
      _setLoadingState(
          forceRefresh ? NewsLoadingState.refreshing : NewsLoadingState.loading
      );
      _clearError();

      await _loadFromCache();

    } catch (e) {
      _handleError('Failed to load articles: $e');
    }
  }

  // Refresh articles (pull-to-refresh)
  Future<void> refreshArticles() async {
    await loadNewsFeed(forceRefresh: true);
  }

  // Private helper methods
  void _setLoadingState(NewsLoadingState state) {
    _loadingState = state;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  void _handleError(String error) {
    _errorMessage = error;
    _setLoadingState(NewsLoadingState.error);
  }

  Future<void> _loadFromCache() async {
    try {
      final cachedArticles = _prefsService.getCachedNewsArticles();

      if (cachedArticles != null && cachedArticles.isNotEmpty) {
        _articles = List.from(cachedArticles);
        _setLoadingState(NewsLoadingState.loaded);
        print('Loaded ${cachedArticles.length} articles from cache');
      } else {
        // No cached articles available
        _articles = [];
        _setLoadingState(NewsLoadingState.loaded);
        print('No cached articles found');
      }
    } catch (e) {
      _handleError('Failed to load cached articles: $e');
    }
  }
}