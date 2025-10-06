import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OnboardingViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Progress tracking
  int _currentStep = 0;
  final int _totalSteps = 7;
  bool _isLoading = false;
  String? _errorMessage;

  // User responses
  String? _selectedScreenTime;
  final List<String> _selectedMostUsedApps = [];
  final List<String> _selectedPrimaryInterests = [];
  final List<String> _selectedSubInterests = [];
  String? _selectedAgeRange;
  String? _selectedPrimaryGoal;
  String? _selectedMotivationStyle;
  String? _selectedNotificationTime;

  // Getters
  int get currentStep => _currentStep;
  int get totalSteps => _totalSteps;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  double get progress => (_currentStep + 1) / _totalSteps;

  String? get selectedScreenTime => _selectedScreenTime;
  List<String> get selectedMostUsedApps => _selectedMostUsedApps;
  List<String> get selectedPrimaryInterests => _selectedPrimaryInterests;
  List<String> get selectedSubInterests => _selectedSubInterests;
  String? get selectedAgeRange => _selectedAgeRange;
  String? get selectedPrimaryGoal => _selectedPrimaryGoal;
  String? get selectedMotivationStyle => _selectedMotivationStyle;
  String? get selectedNotificationTime => _selectedNotificationTime;

  // Question data
  final List<String> screenTimeOptions = [
    '1-2 hours',
    '3-4 hours',
    '5-6 hours',
    '7-8 hours',
    '9+ hours'
  ];

  final List<String> appOptions = [
    'Instagram',
    'TikTok',
    'YouTube',
    'Twitter/X',
    'Reddit',
    'Facebook',
    'Snapchat',
    'Gaming Apps',
    'Work/Productivity',
    'News & Reading',
    'Shopping',
    'Other'
  ];

  final List<String> primaryInterestOptions = [
    'Technology',
    'Artificial Intelligence',
    'Business',
    'Finance',
    'Health',
    'Fitness',
    'Sports',
    'Entertainment',
    'Science',
    'Lifestyle',
    'Politics',
    'Environment',
    'Education',
    'Travel',
    'Food',
    'Fashion',
    'Gaming',
    'Cryptocurrency',
    'Startups',
    'Space',
  ];

  final Map<String, List<String>> specificInterestsMap = {
    'Technology': ['AI Tools', 'Software Development', 'Gadgets', 'Tech News', 'Coding', 'Cloud Computing'],
    'Artificial Intelligence': ['Machine Learning', 'ChatGPT & LLMs', 'AI Research', 'Automation', 'Neural Networks', 'AI Ethics'],
    'Business': ['Entrepreneurship', 'Marketing', 'Management', 'Strategy', 'Leadership', 'Innovation'],
    'Finance': ['Investing', 'Stock Market', 'Personal Finance', 'Economics', 'Financial Planning', 'Trading'],
    'Health': ['Mental Health', 'Nutrition', 'Wellness', 'Disease Prevention', 'Healthcare', 'Sleep Optimization'],
    'Fitness': ['Workouts', 'Strength Training', 'Cardio', 'Yoga', 'Running', 'Sports Performance'],
    'Sports': ['Football', 'Basketball', 'Soccer', 'Tennis', 'Formula 1', 'Olympics'],
    'Entertainment': ['Movies', 'TV Shows', 'Music', 'Celebrities', 'Pop Culture', 'Streaming'],
    'Science': ['Space Exploration', 'Physics', 'Biology', 'Chemistry', 'Research', 'Discoveries'],
    'Lifestyle': ['Productivity', 'Minimalism', 'Self-Improvement', 'Habits', 'Organization', 'Work-Life Balance'],
    'Politics': ['Elections', 'Policy', 'International Relations', 'Government', 'Social Issues', 'Current Affairs'],
    'Environment': ['Climate Change', 'Sustainability', 'Conservation', 'Renewable Energy', 'Wildlife', 'Green Living'],
    'Education': ['Online Learning', 'Study Tips', 'Certifications', 'Universities', 'EdTech', 'Skills Development'],
    'Travel': ['Destinations', 'Travel Tips', 'Culture', 'Adventure', 'Budget Travel', 'Photography'],
    'Food': ['Recipes', 'Cooking', 'Restaurants', 'Nutrition', 'Food Trends', 'Meal Prep'],
    'Fashion': ['Style Trends', 'Designers', 'Sustainable Fashion', 'Accessories', 'Beauty', 'Streetwear'],
    'Gaming': ['Video Games', 'Esports', 'Game Reviews', 'Streaming', 'Game Development', 'Console News'],
    'Cryptocurrency': ['Bitcoin', 'Ethereum', 'Blockchain', 'DeFi', 'NFTs', 'Crypto Trading'],
    'Startups': ['Funding', 'Venture Capital', 'Founders', 'Product Launches', 'Unicorns', 'Tech Startups'],
    'Space': ['NASA', 'SpaceX', 'Astronomy', 'Mars Missions', 'Satellites', 'Cosmic Discoveries'],
  };

  final List<String> ageRangeOptions = [
    '13-17',
    '18-21',
    '22-25',
    '25-29',
    '30-35',
    '35+'
  ];

  final List<String> primaryGoalOptions = [
    'Reduce distracting app usage',
    'Boost daily productivity',
    'Build healthy daily habits',
    'Focus on continuous learning',
    'Improve mental & physical wellbeing',
    'Advance my career & skills',
    'Build self-confidence & resilience'
  ];

  final List<String> motivationStyleOptions = [
    'Gentle reminders',
    'Challenging nudges',
    'Inspirational quotes',
    'Progress tracking',
    'Achievement rewards',
    'Resources'
  ];

  // Selection methods
  void selectScreenTime(String screenTime) {
    _selectedScreenTime = screenTime;
    notifyListeners();
  }

  void toggleMostUsedApp(String app) {
    if (_selectedMostUsedApps.contains(app)) {
      _selectedMostUsedApps.remove(app);
    } else {
      if (_selectedMostUsedApps.length < 5) {
        _selectedMostUsedApps.add(app);
      }
    }
    notifyListeners();
  }

  void togglePrimaryInterest(String interest) {
    if (_selectedPrimaryInterests.contains(interest)) {
      _selectedPrimaryInterests.remove(interest);
      // Remove related sub-interests when primary interest is deselected
      final subInterests = specificInterestsMap[interest] ?? [];
      _selectedSubInterests.removeWhere((sub) => subInterests.contains(sub));
    } else {
      if (_selectedPrimaryInterests.length < 10) {
        _selectedPrimaryInterests.add(interest);
      }
    }
    notifyListeners();
  }

  void toggleSubInterest(String subInterest) {
    if (_selectedSubInterests.contains(subInterest)) {
      _selectedSubInterests.remove(subInterest);
    } else {
      if (_selectedSubInterests.length < 10) {
        _selectedSubInterests.add(subInterest);
      }
    }
    notifyListeners();
  }

  void selectAgeRange(String ageRange) {
    _selectedAgeRange = ageRange;
    notifyListeners();
  }

  void selectPrimaryGoal(String goal) {
    _selectedPrimaryGoal = goal;
    notifyListeners();
  }

  void selectMotivationStyle(String style) {
    _selectedMotivationStyle = style;
    notifyListeners();
  }

  void selectNotificationTime(String time) {
    _selectedNotificationTime = time;
    notifyListeners();
  }

  // Navigation methods
  void nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _currentStep++;
      notifyListeners();
    }
  }

  void previousStep() {
    if (_currentStep > 0) {
      _currentStep--;
      notifyListeners();
    }
  }

  // Get available sub-interests based on selected primary interests
  List<String> getAvailableSubInterests() {
    List<String> availableSubInterests = [];
    for (String interest in _selectedPrimaryInterests) {
      availableSubInterests.addAll(specificInterestsMap[interest] ?? []);
    }
    return availableSubInterests;
  }

  // Validation methods
  bool canProceedFromCurrentStep() {
    switch (_currentStep) {
      case 0: return  _selectedPrimaryInterests.isNotEmpty;
      case 1: return _selectedSubInterests.isNotEmpty;
      case 2: return _selectedPrimaryGoal != null;
      case 3: return _selectedMostUsedApps.isNotEmpty;
      case 4: return _selectedScreenTime != null;
      case 5: return _selectedAgeRange != null;
      case 6: return _selectedMotivationStyle != null;
      default: return false;
    }
  }

  // Save to Firestore
  Future<bool> saveOnboardingData(String userId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _firestore.collection('Users').doc(userId).update({
        'dailyScreenTime': _selectedScreenTime,
        'mostUsedApps': _selectedMostUsedApps,
        'primaryInterests': _selectedPrimaryInterests,
        'specificInterests': _selectedSubInterests,
        'ageRange': _selectedAgeRange,
        'primaryGoal': _selectedPrimaryGoal,
        'motivationStyle': _selectedMotivationStyle,
        'preferredNotificationTime': _selectedNotificationTime,
        'onboardingCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),

        // for LangChain system
        'currentFocus': _selectedPrimaryGoal ?? 'Master productivity and plan strategies for professional growth',
        'lastNotificationType': 'none',
        'lastNotificationTime': null,
      });

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to save preferences: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // Reset for testing
  void reset() {
    _currentStep = 0;
    _selectedScreenTime = null;
    _selectedMostUsedApps.clear();
    _selectedPrimaryInterests.clear();
    _selectedSubInterests.clear();
    _selectedAgeRange = null;
    _selectedPrimaryGoal = null;
    _selectedMotivationStyle = null;
    _selectedNotificationTime = null;
    _errorMessage = null;
    notifyListeners();
  }
}