import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../ViewModels/newsfeed_vm.dart';
import 'news_list_item.dart';
import '../../Services/news_service.dart';
import '../../Services/shared_prefs_service.dart';

class NewsFeed extends StatefulWidget {
  const NewsFeed({super.key});

  @override
  State<NewsFeed> createState() => _NewsFeedState();
}

class _NewsFeedState extends State<NewsFeed> {
  late NewsFeedViewModel newsVM;
  bool _isInitialized = false;
  bool _isDisposed = false;

  late NewsService _newsService;
  late SharedPreferencesService _prefsService;

  @override
  void initState() {
    super.initState();
    _initializeServices();      // initializes the services for news summary
    _initializeViewModel();    // triggers the entire flow
  }

  Future<void> _initializeServices() async {
    _prefsService = await SharedPreferencesService.getInstance();
    _newsService = NewsService(_prefsService);
  }

  Future<void> _initializeViewModel() async {
    newsVM = Provider.of<NewsFeedViewModel>(context, listen: false);  // viewmodel instance

    try {
      await newsVM.initialize();

      // Check if widget is still mounted before updating state
      if (mounted && !_isDisposed) {
        setState(() {
          _isInitialized = true;    // Updates UI to show content
        });
      }
    } catch (e) {
      print('Error initializing ViewModel: $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // early return if not initialized
    if (!_isInitialized) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return Scaffold(
      appBar: _buildAppBar(),
      body: Consumer<NewsFeedViewModel>(
        builder: (context, viewModel, child) {
          newsVM = viewModel; // Update reference

          return Column(
            children: [
              _buildTabSlider(viewModel),

              Expanded(child: _buildBody(viewModel)),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      actionsPadding: EdgeInsetsGeometry.fromLTRB(10, 10, 10, 10),
      backgroundColor: Colors.white,
      elevation: 0,
      title: const Text(
        'Discover',
        style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 28),
      ),

      // personalize the feed button
      actions: [
        IconButton(
            onPressed: () {
              // TODO: Listen to the news (premium feature)
            },
            icon: Image.asset('lib/Assets/icons/dark_headphone.png', width: 30, height: 30), color: Colors.black87),
        IconButton(
            onPressed: () {
              // TODO: Add topics for personalizing the feed
            },
            icon: Image.asset('lib/Assets/icons/add-to-favorites.png', width: 30, height: 34), color: Colors.black87),
      ],
    );
  }

  Widget _buildTabSlider(NewsFeedViewModel viewModel) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: viewModel.tabs.length,
        itemBuilder: (context, index) {
          final isSelected = index == viewModel.selectedTabIndex;

          return GestureDetector(
            onTap: () => viewModel.selectTab(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.black87 : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? Colors.black87 : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  viewModel.tabs[index],
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[600],
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(NewsFeedViewModel viewModel) {
    // Loading state
    if (viewModel.loadingState == NewsLoadingState.loading &&
        !viewModel.hasArticles) {
      return _buildLoadingState();
    }

    // Error state
    if (viewModel.loadingState == NewsLoadingState.error &&
        !viewModel.hasArticles) {
      return _buildErrorState(viewModel);
    }

    // Empty state
    if (!viewModel.hasArticles &&
        viewModel.loadingState == NewsLoadingState.loaded) {
      return _buildEmptyState(viewModel);
    }

    // Content state
    return _buildContentState(viewModel);
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading the best news for you...', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildErrorState(NewsFeedViewModel viewModel) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'Oops! Something went wrong',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              viewModel.errorMessage ?? 'Unknown error occurred',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => viewModel.loadNewsFeed(forceRefresh: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(NewsFeedViewModel viewModel) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.newspaper_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No articles found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              'Try selecting a different category',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => viewModel.refreshArticles(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentState(NewsFeedViewModel viewModel) {
    return RefreshIndicator(
      onRefresh: viewModel.refreshArticles,
      color: Colors.black87,
      child: viewModel.articles.isNotEmpty ? ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: viewModel.articles.length,
        itemBuilder: (context, index) {
          final article = viewModel.articles[index];      // Each article renders as NewsListItem

          return NewsListItem(
            article: article,
            onTap: () => _handleArticleTap(article),
            onBookmark: () => _handleBookmark(article),
            onListen: () => _handleListen(article),
          );
        },
      ) :
      const Center(child: Text('Pull to refresh to load cached articles', style: TextStyle(color: Colors.grey)),
      ),
    );
  }

  // Event handlers
  void _handleArticleTap(Map<String, dynamic> article) {
    // TODO: Navigate to full article view with animation
    print('Article tapped: ${article['title']}');
    _showNewsSummaryDialog(context, article, _newsService);
  }

  void _handleBookmark(Map<String, dynamic> article) {
    // TODO: Handle bookmark action
    print('Bookmark tapped: ${article['title']}');
  }

  void _handleListen(Map<String, dynamic> article) {
    // TODO: Handle listen/audio action
    print('Listen tapped: ${article['title']}');
  }
}

/// Shows an animated dialog with news summary
void _showNewsSummaryDialog(BuildContext context, Map<String, dynamic> article, NewsService newsService) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
      return const SizedBox.shrink();
    },
    transitionBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
      final screenSize = MediaQuery.of(context).size;
      final dialogWidth = screenSize.width * 0.9;
      final dialogHeight = screenSize.height * 0.9;

      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInBack,
      );

      return Center(
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(animation),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: dialogWidth,
                height: dialogHeight,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: _NewsSummaryDialog(article: article, newsService: newsService),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _NewsSummaryDialog extends StatefulWidget {
  final Map<String, dynamic> article;
  final NewsService newsService;

  const _NewsSummaryDialog({required this.article, required this.newsService});

  @override
  State<_NewsSummaryDialog> createState() => _NewsSummaryDialogState();
}

class _NewsSummaryDialogState extends State<_NewsSummaryDialog> {
  String? _summary;
  bool _isLoadingSummary = false;
  String? _summaryError;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    final title = widget.article['title'] ?? '';
    if (title.isEmpty) return;

    setState(() => _isLoadingSummary = true);

    try {
      final result = await widget.newsService.getNewsSummary(
        title: title,
        description: widget.article['description'],
        link: widget.article['link'],
        category: widget.article['category'],
      );

      if (result['success'] == true) {
        setState(() {
          _summary = result['summary'];
          _isLoadingSummary = false;
        });
      } else {
        setState(() {
          _summaryError = result['error'] ?? 'Failed to generate summary';
          _isLoadingSummary = false;
        });
      }
    } catch (e) {
      setState(() {
        _summaryError = 'Failed to load summary';
        _isLoadingSummary = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          // Header with close button
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'News Summary',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  color: Colors.grey[600],
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Article title
                  Text(
                    widget.article['title'] ?? 'No Title Available',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Article image if available
                  if (widget.article['image_url'] != null && widget.article['image_url'].toString().isNotEmpty)
                    Container(
                      height: 200,
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: NetworkImage(widget.article['image_url']),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                  // AI Summary or loading state
                  if (_isLoadingSummary)
                    const Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 8),
                          Text('Generating AI summary...', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  else if (_summaryError != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Summary unavailable', style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(widget.article['description'] ?? 'No content available...', style: TextStyle(fontSize: 16, color: Colors.grey[700], height: 1.6)),
                        ],
                      ),
                    )
                  else if (_summary != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.auto_awesome, size: 16, color: Colors.blue[700]),
                                const SizedBox(width: 4),
                                Text('AI Summary', style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.w600, fontSize: 14)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(_summary!, style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.6)),
                          ],
                        ),
                      )
                    else
                      Text(
                        widget.article['description'] ?? 'No content available...',
                        style: TextStyle(fontSize: 16, color: Colors.grey[700], height: 1.6),
                      ),

                  const SizedBox(height: 20),

                  // Source and date info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.deepOrangeAccent,
                        child: Text(
                          (widget.article['source_id'] ?? widget.article['source'] ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.article['source_id'] ?? widget.article['source'] ?? 'Unknown Source',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                            ),
                            Text(
                              formatPublishedDateWithIntl(widget.article['pubDate'] ?? 'Unknown'),
                              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}