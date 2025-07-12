import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../ViewModels/newsfeed_vm.dart';
import 'news_list_item.dart';

class NewsFeed extends StatefulWidget {
  const NewsFeed({super.key});

  @override
  State<NewsFeed> createState() => _NewsFeedState();
}

class _NewsFeedState extends State<NewsFeed> {
  late NewsFeedViewModel newsVM;
  bool _isInitialized = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _initializeViewModel();    // triggers the entire flow
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
          Text(
            'Loading the best news for you...',
            style: TextStyle(color: Colors.grey),
          ),
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
      const Center(
        child: Text(
          'Pull to refresh to load cached articles',
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }

  // Event handlers
  void _handleArticleTap(Map<String, dynamic> article) {
    // TODO: Navigate to full article view with animation
    print('Article tapped: ${article['title']}');
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