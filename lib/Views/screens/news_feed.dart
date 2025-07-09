import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'news_feed_card.dart';
import '../../Services/shared_prefs_service.dart';

class Newsfeed extends StatefulWidget {
  const Newsfeed({super.key});

  @override
  State<Newsfeed> createState() => NewsFeedState();
}

class NewsFeedState extends State<Newsfeed> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _articles = [];
  String? _errorMessage;
  int selectedTabIndex = 0;

  final List<String> tabs = ['For You', 'Top Stories', 'Tech & Science', 'Finance', 'Sports'];

  late SharedPreferencesService _prefsService;

  @override
  void initState() {
    super.initState();
    _initializeAndLoadNews();
  }

  Future<void> _initializeAndLoadNews() async {
    _prefsService = await SharedPreferencesService.getInstance();
    _loadNewsFeed(); // Now load articles if not already loaded from cache
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('News Feed'),
        centerTitle: true,
      ),
      body: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 30),
          child: Column(
              children: [
                _buildTabSlider(),
                _buildBody()
              ]
          )
      ),
    );
  }

  Widget _buildTabSlider() {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        itemBuilder: (context, index) {
          final isSelected = index == selectedTabIndex;
          return GestureDetector(
            onTap: () {
              setState(() {
                selectedTabIndex = index;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(26),
                border: isSelected
                    ? Border.all(color: Colors.black45, width: 1)
                    : null,
              ),
              child: Center(
                child: Text(
                  tabs[index],
                  style: TextStyle(
                    color: isSelected ? Colors.black87 : Colors.grey[500],
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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

  Widget _buildBody() {
    if (_isLoading) {
      return const Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Hold on while we load best news for you...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'Error loading news',
                style: TextStyle(fontSize: 18, color: Colors.red),
              ),
              SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black87),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _loadNewsFeed(forceRefresh: true),
                child: Text('Load News'),
              ),
            ],
          ),
        ),
      );
    }

    if (_articles.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.newspaper, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No articles loaded',
                style: TextStyle(fontSize: 18, color: Colors.black38),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadNewsFeed,
                child: Text('Load News'),
              ),
            ],
          ),
        ),
      );
    }

    return NewsFeedCard(articles: _articles);
  }

  Future<void> _loadNewsFeed({bool forceRefresh = false}) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      // Check if we have cached data and it's still fresh (less than 30 minutes old)
      if (!forceRefresh) {
        final cachedArticles = _prefsService.getCachedNewsArticles();
        final lastFetchTime = _prefsService.getLastNewsFetchTime();

        if (cachedArticles != null && lastFetchTime != null) {
          final timeDifference = DateTime.now().millisecondsSinceEpoch - lastFetchTime;
          final thirtyMinutesInMs = 2 * 60 * 60 * 1000; // 2 hours

          if (timeDifference < thirtyMinutesInMs) {
            // Use cached data
            setState(() {
              _articles = cachedArticles;
              _isLoading = false;
            });
            print('Loaded ${cachedArticles.length} articles from cache');
            return;
          }
        }
      }

      // Get current user ID
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      print('Loading fresh news feed for user: ${user.uid}');

      // Call the Cloud Function to get stored articles
      final callable = FirebaseFunctions.instance.httpsCallable('getUserNewsFeed');
      final result = await callable.call({'userId': user.uid});

      if (result.data['success'] == true) {
        final articlesData = result.data['articles'] as List<dynamic>? ?? [];
        final articles = articlesData.map((article) {
          return Map<String, dynamic>.from(article as Map<Object?, Object?>);
        }).toList();

        // Cache the fresh data
        await _prefsService.saveNewsArticles(articles);
        await _prefsService.saveLastNewsFetchTime();

        setState(() {
          _articles = articles;
          _isLoading = false;
        });

        print('Loaded ${articles.length} fresh articles from Firestore and cached them');

      } else {
        throw Exception(result.data['error'] ?? 'Failed to load news');
      }
    } catch (e) {
      print('Error loading news feed: $e');

      // If network fails, try to use cached data as fallback
      final cachedArticles = _prefsService.getCachedNewsArticles();
      if (cachedArticles != null) {
        if (mounted) {
          setState(() {
            _articles = cachedArticles;
            _isLoading = false;
          });
        }
        print('Network failed, using cached articles as fallback');
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = e.toString();
            _isLoading = false;
          });
        }
      }
    }
  }
}