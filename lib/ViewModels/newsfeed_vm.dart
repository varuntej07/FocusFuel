import 'package:flutter/foundation.dart';
import '../Services/news_service.dart';
import '../Services/shared_prefs_service.dart';

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
    'Business',
    'Health',
    'Sports',
    'Lifestyle'
  ];

  // Public getters
  List<Map<String, dynamic>> get articles => List.unmodifiable(_articles);
  NewsLoadingState get loadingState => _loadingState;
  String? get errorMessage => _errorMessage;
  int get selectedTabIndex => _selectedTabIndex;
  bool get isLoading => _loadingState == NewsLoadingState.loading;
  bool get isRefreshing => _loadingState == NewsLoadingState.refreshing;
  bool get hasArticles => _articles.isNotEmpty;

  late NewsService _newsService;
  bool _isDisposed = false;

  // Initialize the view model
  Future<void> initialize() async {
    if (_isDisposed) return;

    try {
      _prefsService = await SharedPreferencesService.getInstance();
      _newsService = NewsService(_prefsService);   // news service instance with prefs

      if (!_isDisposed) {
        await loadNewsFeed();     // starts actual news loading
      }

    } catch (e) {
      _handleError('Failed to initialize: $e');
    }
  }

  List<Map<String, dynamic>> _allArticles = [];  // Store all articles
  String _selectedCategory = 'For You';  // Tracks selected category

  // getter for selected category
  String get selectedCategory => _selectedCategory;

  // Handle tab selection
  void selectTab(int index) {
    if (index == _selectedTabIndex) return;

    _selectedTabIndex = index;
    _selectedCategory = tabs[index];

    // Filter articles based on selected category
    _filterArticlesByCategory();
    notifyListeners();
  }

  void _filterArticlesByCategory() {
    if (_selectedCategory == 'For You') {
      _articles = List.from(_allArticles);    // Show all articles for this tab
    } else {
      // Filter articles by category
      _articles = _allArticles.where((article) {
        final articleCategory = (article['category'] ?? '').toString().toLowerCase();
        final searchCategory = (article['searchCategory'] ?? '').toString().toLowerCase();
        final selectedCat = _selectedCategory.toLowerCase();

        // Check if article category matches selected tab
        return articleCategory.contains(selectedCat) ||
            searchCategory.contains(selectedCat) ||
            _isCategoryMatch(articleCategory, selectedCat) ||
            _isCategoryMatch(searchCategory, selectedCat);
      }).toList();
    }
  }

  // helper method to handle category matching logic for _filterArticlesByCategory
  bool _isCategoryMatch(String articleCategory, String selectedCategory) {
    switch (selectedCategory) {
      case 'ai':
        return articleCategory.contains('technology') ||
            articleCategory.contains('artificial') ||
            articleCategory.contains('ai') ||
            articleCategory.contains('research');
      case 'business':
        return articleCategory.contains('business');
      case 'finance':
        return articleCategory.contains('business') ||
            articleCategory.contains('finance') ||
            articleCategory.contains('economy');
      case 'health':
        return articleCategory.contains('health') || articleCategory.contains('fitness');
      case 'sports':
        return articleCategory.contains('sport');
      case 'top stories':
        return true; // Show all for top stories
      default:
        return articleCategory.contains(selectedCategory);
    }
  }

  // Load news feed with caching
  Future<void> loadNewsFeed({bool forceRefresh = false}) async {
    if (_loadingState == NewsLoadingState.loading) return;

    try {
      _setLoadingState(
          forceRefresh ? NewsLoadingState.refreshing : NewsLoadingState.loading
      );

      _clearError();

      final articles = await _newsService.getNewsArticles(forceRefresh: forceRefresh);

      _allArticles = articles;         // updates internal state with all articles from news service
      _filterArticlesByCategory();  // Apply current filter

      _setLoadingState(NewsLoadingState.loaded);

    } catch (e) {
      _handleError('Failed to load articles: $e');
    }
  }

  Future<void> toggleBookmark(Map<String, dynamic> article) async {
    if (_prefsService.isArticleBookmarked(article)) {
      await _prefsService.removeBookmarkedArticle(article);
    } else {
      await _prefsService.saveBookmarkedArticle(article);
    }
    notifyListeners(); // Refresh UI to update bookmark icon
  }

  bool isArticleBookmarked(Map<String, dynamic> article) {
    return _prefsService.isArticleBookmarked(article);
  }

  List<Map<String, dynamic>> getBookmarkedArticles() {
    return _prefsService.getBookmarkedArticles();
  }

  // Refresh articles (pull-to-refresh)
  Future<void> refreshArticles() async {
    await loadNewsFeed(forceRefresh: true);
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  // Private helper methods
  void _setLoadingState(NewsLoadingState state) {
    if (_isDisposed) return;
    _loadingState = state;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  void _handleError(String error) {
    if (_isDisposed) return;
    _errorMessage = error;
    _setLoadingState(NewsLoadingState.error);
  }
}