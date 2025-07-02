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
  String? _selectedMostUsedApp;
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
  String? get selectedMostUsedApp => _selectedMostUsedApp;
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
    'Social Media (Instagram, TikTok, etc.)',
    'Gaming',
    'YouTube/Entertainment',
    'Work/Productivity Apps',
    'News & Reading',
    'Shopping',
    'Other'
  ];

  final List<String> primaryInterestOptions = [
    'Personal Development',
    'Health & Fitness',
    'Career & Business',
    'Technology',
    'Creative Arts',
    'Education & Learning',
    'Social & Relationships',
    'Entertainment'
  ];

  final Map<String, List<String>> specificInterestsMap = {
    'Personal Development': ['Morning Routines', 'Journaling', 'Meditation & Breathing', 'Breaking Bad Habits', 'Building Confidence', 'Stoicism & Philosophy'],
    'Health & Fitness': ['Home Workouts', 'Meal Prep & Cooking', 'Mental Health Check-ins', 'Sleep Optimization', 'Hydration Tracking', 'Stress Management'],
    'Career & Business': ['Side Quests', 'Public Speaking', 'LinkedIn Networking', 'Skill Certifications', 'Personal Branding', 'Salary Negotiation'],
    'Technology': ['Coding Challenges', 'AI Tools & Prompts', 'Productivity Apps', 'Tech News & Trends', 'Digital Minimalism', 'Online Courses'],
    'Creative Arts': ['Daily Sketching', 'Content Creation', 'Music Practice', 'Photo Editing', 'DIY Projects', 'Creative Writing'],
    'Education & Learning': ['Language Apps', 'Podcast Learning', 'Book Reading', 'YouTube Tutorials', 'Online Certifications', 'Documentary Watching'],
    'Social & Relationships': ['Active Listening', 'Family Time', 'Friend Check-ins', 'Community Volunteering', 'Dating Confidence', 'Networking Events'],
    'Entertainment': ['Movie Nights', 'Gaming Sessions', 'Sports Updates', 'Travel Planning', 'New Hobbies', 'Local Events']
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
    'Reduce phone usage',
    'Improve productivity',
    'Build better habits',
    'Focus on learning',
    'Enhance wellbeing',
    'Career advancement',
    'Optimistic self-confidence'
  ];

  final List<String> motivationStyleOptions = [
    'Gentle reminders',
    'Challenging nudges',
    'Inspirational quotes',
    'Progress tracking',
    'Achievement rewards',
    'Resources'
  ];

  final List<String> notificationTimeOptions = [
    'Morning (8-11 AM)',
    'Mid-day (12-4 PM)',
    'Evening (6-9 PM)',
    'Night (9-2 AM)',
    'Random times'
  ];

  // Selection methods
  void selectScreenTime(String screenTime) {
    _selectedScreenTime = screenTime;
    notifyListeners();
  }

  void selectMostUsedApp(String app) {
    _selectedMostUsedApp = app;
    notifyListeners();
  }

  void togglePrimaryInterest(String interest) {
    if (_selectedPrimaryInterests.contains(interest)) {
      _selectedPrimaryInterests.remove(interest);
      // Remove related sub-interests when primary interest is deselected
      final subInterests = specificInterestsMap[interest] ?? [];
      _selectedSubInterests.removeWhere((sub) => subInterests.contains(sub));
    } else {
      if (_selectedPrimaryInterests.length < 5) {
        _selectedPrimaryInterests.add(interest);
      }
    }
    notifyListeners();
  }

  void toggleSubInterest(String subInterest) {
    if (_selectedSubInterests.contains(subInterest)) {
      _selectedSubInterests.remove(subInterest);
    } else {
      if (_selectedSubInterests.length < 7) {
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
      case 3: return _selectedMostUsedApp != null;
      case 4: return _selectedScreenTime != null; 
      case 5: return _selectedAgeRange != null;
      case 6: return _selectedMotivationStyle != null && _selectedNotificationTime != null;
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
        'mostUsedApp': _selectedMostUsedApp,
        'primaryInterests': _selectedPrimaryInterests,
        'subInterests': _selectedSubInterests,
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
    _selectedMostUsedApp = null;
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