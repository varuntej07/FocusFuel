import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import '../Services/shared_prefs_service.dart';
import '../Services/streak_repo.dart';

/// HomeViewModel manages the home screen state and user data
class HomeViewModel extends ChangeNotifier {
  static const String _defaultUsername = "Dude";
  static const String _defaultMood = "Chill";
  static const int _defaultStreak = 0;

  // State management
  HomeState _state = HomeState.initial;
  bool _isAuthenticated = false;
  bool _disposed = false;

  // User data
  String? _username;
  int _streak = _defaultStreak;
  String? _currentFocus;
  String _mood = _defaultMood;
  String? _weeklyGoal;

  // Getters
  String get username => _isAuthenticated ? (_username ?? _defaultUsername) : _defaultUsername;
  int get streak => _isAuthenticated ? _streak : 0;
  String get mood => _mood;
  String? get currentFocus => _isAuthenticated ? _currentFocus : null;
  String? get weeklyGoal => _isAuthenticated ? _weeklyGoal : null;

  HomeState get state => _state;
  bool get isAuthenticated => _isAuthenticated;

  // Services - injected dependencies
  final StreakRepository streakRepo;
  late SharedPreferencesService _prefsService;

  // Constructor to initialize the view model
  HomeViewModel(this.streakRepo) {
    _initializeViewModel();
  }

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Initializing view model
  // This is the main entry point that sets up the entire state management
  Future<void> _initializeViewModel() async {
    try {
      // Initialize shared preferences service
      _prefsService = await SharedPreferencesService.getInstance();

      // Checking authentication by taking User object of the currently signed-in user if there is one as a parameter
      _updateAuthenticationState(FirebaseAuth.instance.currentUser);

      // Set up authentication state listener for real-time auth changes
      _setupAuthenticationListener();

      // Load initial data if user is authenticated
      if (_isAuthenticated) {
        await loadFromPrefs();
        await _checkAndUpdateTimezone();
      } else {
        clearAllUserData(); // Clear all data if not authenticated
      }
      _isInitialized = true;
    } catch (e) {
      _handleError('Failed to initialize HomeViewModel: $e');
    }
  }

  /// Set up listener for authentication state changes
  /// This ensures the ViewModel stays in sync with auth state
  void _setupAuthenticationListener() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      final wasAuthenticated = _isAuthenticated;
      _updateAuthenticationState(user);

      // Only reload data if authentication state actually changed
      if (wasAuthenticated != _isAuthenticated) {
        if (_isAuthenticated) {
          await loadFromPrefs();
        } else {
          clearAllUserData();
        }
      }
    });
  }

  /// Update authentication state and notify listeners if needed
  void _updateAuthenticationState(User? user) {
    final newAuthState = user != null;      // This determines if user is authenticated
    if (_isAuthenticated != newAuthState) {
      _isAuthenticated = newAuthState;

      if (!_disposed) notifyListeners();
    }
  }

  /// Check if goals need to be prompted
  /// Returns true if currentFocus is missing, indicating setup is incomplete
  Future<bool> shouldPromptGoals() async {
    if (!_isAuthenticated) return false;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return false;

      final snap = await FirebaseFirestore.instance.collection('Users').doc(uid).get();
      if (!snap.exists) return true;

      final data = snap.data() ?? {};
      _currentFocus = data['currentFocus'];           // may be null
      _weeklyGoal = data['weeklyGoal'];             // may be null

      // Check if prompt was already shown today
      final lastPromptDate = data['lastGoalPromptDate'];
      final today = DateTime.now();
      final todayString = '${today.year}-${today.month}-${today.day}';

      // If prompt was shown today, don't show again
      if (lastPromptDate == todayString) {
        if (!_disposed) notifyListeners();
        return false;
      }

      if (!_disposed) notifyListeners();

      return _currentFocus == null;
    } catch (e) {
      _handleError('Failed to check goal status: $e');
      return false;
    }
  }

  /// Mark that goal prompt was shown today
  Future<void> markGoalPromptShown() async {
    if (!_isAuthenticated) return;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final today = DateTime.now();
      final todayString = '${today.year}-${today.month}-${today.day}';

      await FirebaseFirestore.instance.collection('Users').doc(uid).update({
        'lastGoalPromptDate': todayString,
      });
    } catch (e) {
      _handleError('Failed to mark prompt shown: $e');
    }
  }

  // Update streak
  Future<void> bumpStreakIfNeeded() async {
    if (!_isAuthenticated) return;  // Check auth state first
    
    try {
      final int newStreak = await streakRepo.incrementIfNeeded();
      if (_disposed) return;

      await _prefsService.saveStreak(newStreak);
      _streak = newStreak;
      _updateState(HomeState.success);
      if (!_disposed) notifyListeners();
    } catch (e) {
      _handleError('Failed to update streak: $e');
    }
  }

  /// Set focus goal
  /// This updates both local preferences and Firestore
  Future<void> setFocusGoal(String focus) async {
    if (!_isAuthenticated || focus.trim().isEmpty) return;  // Check auth state first
    
    try {
      _updateState(HomeState.loading);

      // Update local preferences first for immediate UI feedback
      await _prefsService.saveCurrentFocus(focus);
      _currentFocus = focus;

      // Update Firestore with focus and timestamp
      await _mergeIntoUserDoc({
        'currentFocus': _currentFocus,
        'focusUpdatedAt': FieldValue.serverTimestamp()
      });

      _updateState(HomeState.success);
    } catch (e) {
      _handleError('Failed to set focus goal: $e');
    }
  }

  /// Set weekly goal
  /// This updates both local preferences and Firestore
  Future<void> setWeeklyGoal(String goal) async {
    if (!_isAuthenticated) return;  // Check auth state first
    
    try {
      _updateState(HomeState.loading);

      final weeklyGoal = goal.trim();

      await _prefsService.saveWeeklyGoal(weeklyGoal);       // Updating local preferences first
      _weeklyGoal = weeklyGoal.isEmpty ? null : weeklyGoal;

      await _mergeIntoUserDoc({
        'weeklyGoal': _weeklyGoal,
        'weeklyGoalUpdatedAt': FieldValue.serverTimestamp()
      });

      _updateState(HomeState.success);

    } catch (e) {
      _handleError('Failed to set weekly goal: $e');
    }
  }

  /// Load data from local preferences
  /// This provides immediate data access without network calls
  Future<void> loadFromPrefs() async {
    if (!_isAuthenticated) {
      clearAllUserData();
      return;
    }

    try {
      _updateState(HomeState.loading);

      _username = _prefsService.getUsername();
      _streak = _prefsService.getStreak() ?? _defaultStreak;
      _currentFocus = _prefsService.getCurrentFocus();
      _weeklyGoal = _prefsService.getWeeklyGoal();

      _updateState(HomeState.success);

    } catch (e) {
      _handleError('Failed to load user data from preferences: $e');
    }
  }

  Future<void> _checkAndUpdateTimezone() async {
    if (!_isAuthenticated) return;

    try {
      final currentTimezone = await FlutterTimezone.getLocalTimezone();
      print('Current timezone detected: $currentTimezone');

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        // Only update if timezone detection succeeds
        await FirebaseFirestore.instance.collection('Users').doc(uid).update({
          'timezone': currentTimezone,
          'timezoneUpdatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Timezone update failed: $e');
    }
  }

  // Merge data into user document
  Future<void> _mergeIntoUserDoc(Map<String, dynamic> data) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance
        .collection('Users')
        .doc(uid)
        .set(data, SetOptions(merge: true));
  }

  // Clear all data
  void clearAllUserData() {
    _username = null;
    _currentFocus = null;
    _streak = _defaultStreak;
    _mood = _defaultMood;
    _weeklyGoal = null;
    _updateState(HomeState.initial);
  }

  // Update the ViewModel state and notify listeners
  void _updateState(HomeState newState) {
    if (_state != newState) {
      _state = newState;

      if (!_disposed) notifyListeners();
    }
  }

  /// Handle errors consistently across the ViewModel
  void _handleError(String errorMessage) {
    // TODO: Should Add proper logging here
    print('HomeViewModel Error: $errorMessage');
    _updateState(HomeState.error);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Represents the different states of the HomeViewModel
enum HomeState {
  initial,      // Initial state when ViewModel is first created
  loading,      // Loading state during async operations
  success,      // Success state when operations complete successfully
  error          // Error state when operations fail
}