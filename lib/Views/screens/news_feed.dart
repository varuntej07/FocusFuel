import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:focus_fuel/Views/screens/subscription_dialog.dart';
import 'package:provider/provider.dart';
import '../../ViewModels/newsfeed_vm.dart';
import '../../ViewModels/auth_vm.dart';
import 'news_list_item.dart';
import '../../Services/news_service.dart';
import '../../Services/shared_prefs_service.dart';
import '../../Services/audio_service.dart';
import 'interests_selection_page.dart';

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
    } catch (error, stackTrace) {
      FirebaseCrashlytics.instance.recordError(error, stackTrace, information: ['Error while Initializing ViewModel in news_feed: $context']);
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
      elevation: 0,
      title: const Text(
        'Discover',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 28),
      ),

      // personalize the feed button
      actions: [
        IconButton(
            onPressed: () => _handlePersonalizeFeed(context),
            icon: ColorFiltered(
              colorFilter: ColorFilter.mode(Theme.of(context).iconTheme.color!, BlendMode.srcIn),
              child: Image.asset('lib/Assets/icons/add-to-favorites.png', width: 30, height: 34),
            )
        ),
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
                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      viewModel.tabs[index],
                      style: TextStyle(
                        color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).textTheme.bodyMedium?.color,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    // Show loading indicator only for selected tab during filtering
                    if (isSelected && viewModel.isRefreshing)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onPrimary),
                        ),
                      ),
                  ],
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('Loading the best news for you...', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
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
            Icon(Icons.error_outline, size: 64, color: Theme.of(context).iconTheme.color),
            const SizedBox(height: 16),
            Text(
              'Oops! Something went wrong',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Theme.of(context).primaryColor),
            ),
            const SizedBox(height: 8),
            Text(
              viewModel.errorMessage ?? 'Unknown error occurred',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).iconTheme.color, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => viewModel.loadNewsFeed(forceRefresh: true),
              style: ElevatedButton.styleFrom(
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
            Text(
              'No articles found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyLarge?.color),
            ),
            const SizedBox(height: 8),
            Text(
              'No articles available for ${viewModel.selectedCategory}',
              style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => viewModel.refreshArticles(),
              style: ElevatedButton.styleFrom(
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
            isBookmarked: viewModel.isArticleBookmarked(article),
          );
        },
      ) :
      const Center(child: Text('Pull to refresh to load cached articles', style: TextStyle(color: Colors.grey)),
      ),
    );
  }

  // Event handlers
  void _handleArticleTap(Map<String, dynamic> article) {
    _showNewsSummaryDialog(context, article, _newsService);
  }

  void _handleBookmark(Map<String, dynamic> article) {
    newsVM.toggleBookmark(article);

    // Show feedback to user
    final isBookmarked = newsVM.isArticleBookmarked(article);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isBookmarked ? 'Article bookmarked' : 'Bookmark removed'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _handlePersonalizeFeed(BuildContext context) {
    // Check subscription status
    final authVM = context.read<AuthViewModel>();
    final userModel = authVM.userModel;

    // Only allow premium and trial users to personalize feed
    if (userModel == null || userModel.isFreeUser) {
      context.showSubscriptionDialog(
        title: 'Premium Feature',
        featureName: 'Get personalized news feed recommendations',
      );
      return;
    }

    // Premium/trial users: Open interests selection page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const InterestsSelectionPage(),
      ),
    );
  }

  void _handleListen(Map<String, dynamic> article) {
    // Check subscription status
    final authVM = context.read<AuthViewModel>();
    final userModel = authVM.userModel;

    // Only allow premium and trial users to use audio feature
    if (userModel == null || userModel.isFreeUser) {
      context.showSubscriptionDialog(
        title: 'Premium Feature',
        featureName: 'Listen to news articles just by a click',
      );
      return;
    }

    // Premium/trial users: Open summary dialog with audio playback
    _showNewsSummaryWithAudio(context, article);
  }

  void _showNewsSummaryWithAudio(BuildContext context, Map<String, dynamic> article) {
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
                  child: _NewsSummaryDialogWithAudio(article: article, newsService: _newsService),
                ),
              ),
            ),
          ),
        );
      },
    );
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

/// News summary dialog with audio playback
class _NewsSummaryDialogWithAudio extends StatefulWidget {
  final Map<String, dynamic> article;
  final NewsService newsService;

  const _NewsSummaryDialogWithAudio({required this.article, required this.newsService});

  @override
  State<_NewsSummaryDialogWithAudio> createState() => _NewsSummaryDialogWithAudioState();
}

class _NewsSummaryDialogWithAudioState extends State<_NewsSummaryDialogWithAudio> {
  String? _summary;
  bool _isLoadingSummary = false;
  String? _summaryError;
  AudioService? _audioService;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _audioService = context.read<AudioService>();
  }

  @override
  void dispose() {
    // Stop audio when dialog closes
    _audioService?.stop();
    super.dispose();
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

        // Start playing audio once summary is loaded
        if (_summary != null && _audioService != null) {
          _audioService!.playArticle({
            'title': title,
            'description': _summary!,
          });
        }
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
          // Header with close button and audio controls
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
                // Audio controls
                if (_summary != null && _audioService != null)
                  _buildAudioControls(),
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

                  // Progress bar at bottom
                  if (_summary != null && _audioService != null)
                    _buildProgressBar(),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAudioControls() {
    return AnimatedBuilder(
      animation: _audioService!,
      builder: (context, child) {
        final isPlaying = _audioService!.isPlaying;
        final isPaused = _audioService!.isPaused;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Play/Pause button
            IconButton(
              onPressed: () {
                if (isPlaying) {
                  _audioService!.pause();
                } else if (isPaused) {
                  // Resume from where we paused
                  _audioService!.resume();
                } else {
                  // Start fresh
                  _audioService!.playArticle({
                    'title': widget.article['title'] ?? '',
                    'description': _summary!,
                  });
                }
              },
              icon: Icon(
                isPlaying ? Icons.pause_circle : Icons.play_circle,
                color: Colors.blue[700],
              ),
              iconSize: 32,
            ),
            // Speed button
            IconButton(
              onPressed: () => _showSpeedDialog(context),
              icon: Icon(Icons.speed, color: Colors.grey[600]),
              iconSize: 24,
            ),
          ],
        );
      },
    );
  }

  Widget _buildProgressBar() {
    return AnimatedBuilder(
      animation: _audioService!,
      builder: (context, child) {
        final progress = _audioService!.progress;

        return Container(
          margin: const EdgeInsets.only(top: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Audio Playback',
                style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSpeedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Playback Speed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSpeedOption(context, '0.5x', 0.5),
            _buildSpeedOption(context, '0.75x', 0.75),
            _buildSpeedOption(context, '1.0x (Normal)', 1.0),
            _buildSpeedOption(context, '1.25x', 1.25),
            _buildSpeedOption(context, '1.5x', 1.5),
            _buildSpeedOption(context, '2.0x', 2.0),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedOption(BuildContext context, String label, double speed) {
    return ListTile(
      title: Text(label),
      onTap: () {
        _audioService!.setSpeechRate(speed);
        Navigator.of(context).pop();
      },
    );
  }
}