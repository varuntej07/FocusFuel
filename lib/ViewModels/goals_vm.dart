import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';

class GoalsViewModel extends ChangeNotifier {
  GoalsState _state = GoalsState.initial;
  GoalsState get state => _state;

  bool _disposed = false;

  // History data lists
  List<Map<String, dynamic>> _focusHistory = [];
  List<Map<String, dynamic>> _goalHistory = [];
  List<Map<String, dynamic>> _taskHistory = [];

  List<Map<String, dynamic>> get focusHistory => _focusHistory;
  List<Map<String, dynamic>> get goalHistory => _goalHistory;
  List<Map<String, dynamic>> get taskHistory => _taskHistory;

  // Pagination - tracks the last document for each collection
  DocumentSnapshot? _lastFocusDoc;
  DocumentSnapshot? _lastGoalDoc;
  DocumentSnapshot? _lastTaskDoc;

  // Pagination state - tracks if more data is available
  bool _hasMoreFocus = true;
  bool _hasMoreGoal = true;
  bool _hasMoreTask = true;

  bool get hasMoreFocus => _hasMoreFocus;
  bool get hasMoreGoal => _hasMoreGoal;
  bool get hasMoreTask => _hasMoreTask;

  // Loading states for individual collections during pagination
  bool _isLoadingMoreFocus = false;
  bool _isLoadingMoreGoal = false;
  bool _isLoadingMoreTask = false;

  bool get isLoadingMoreFocus => _isLoadingMoreFocus;
  bool get isLoadingMoreGoal => _isLoadingMoreGoal;
  bool get isLoadingMoreTask => _isLoadingMoreTask;

  static const int _pageSize = 50;

  // Initializing the ViewModel - this is called automatically when ViewModel is created
  GoalsViewModel() {
    _initializeViewModel();
  }

  // Initialize and load initial history data if user is authenticated
  Future<void> _initializeViewModel() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await loadInitialHistoryData();
      }
    } catch (error, stackTrace) {
      _handleError('Failed to initialize GoalsViewModel', error, stackTrace);
    }
  }

  // Load initial history data for all three collections (focus, goal, task), Called when goals page is opened or when user pulls to refresh
  Future<void> loadInitialHistoryData() async {
    try {
      _updateState(GoalsState.loading);

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _updateState(GoalsState.error);
        return;
      }

      // Reset pagination state
      _lastFocusDoc = null;
      _lastGoalDoc = null;
      _lastTaskDoc = null;
      _hasMoreFocus = true;
      _hasMoreGoal = true;
      _hasMoreTask = true;

      // Fetch initial data for all three collections in parallel
      await Future.wait([
        _fetchFocusHistory(uid, isInitial: true),
        _fetchGoalHistory(uid, isInitial: true),
        _fetchTaskHistory(uid, isInitial: true),
      ]);

      _updateState(GoalsState.success);
    } catch (error, stackTrace) {
      _handleError('Failed to load initial history data', error, stackTrace);
    }
  }

  // Fetch focus history from Firestore subcollection, uses pagination with last document snapshot
  Future<void> _fetchFocusHistory(String uid, {bool isInitial = false}) async {
    try {
      Query query = FirebaseFirestore.instance
          .collection('Users')
          .doc(uid)
          .collection('focusHistory')
          .orderBy('enteredAt', descending: true)
          .limit(_pageSize);

      // If not initial load, start after last document
      if (!isInitial && _lastFocusDoc != null) {
        query = query.startAfterDocument(_lastFocusDoc!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        _hasMoreFocus = false;
        if (isInitial) _focusHistory = [];
        return;
      }

      // Update last document for pagination
      _lastFocusDoc = snapshot.docs.last;

      // Check if there's more data available
      _hasMoreFocus = snapshot.docs.length == _pageSize;

      // Map documents to list with explicit type casting
      final newData = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return <String, dynamic>{
          'id': doc.id,
          ...data,
        };
      }).toList();

      if (isInitial) {
        _focusHistory = newData;
      } else {
        _focusHistory.addAll(newData);
      }

      if (!_disposed) notifyListeners();
    } catch (error, stackTrace) {
      _handleError('Failed to fetch focus history', error, stackTrace);
    }
  }

  // Fetch goal history from Firestore subcollection, uses pagination with last document snapshot
  Future<void> _fetchGoalHistory(String uid, {bool isInitial = false}) async {
    try {
      Query query = FirebaseFirestore.instance
          .collection('Users')
          .doc(uid)
          .collection('goalHistory')
          .orderBy('enteredAt', descending: true)
          .limit(_pageSize);

      // If not initial load, start after last document
      if (!isInitial && _lastGoalDoc != null) {
        query = query.startAfterDocument(_lastGoalDoc!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        _hasMoreGoal = false;
        if (isInitial) _goalHistory = [];
        return;
      }

      // Update last document for pagination
      _lastGoalDoc = snapshot.docs.last;

      // Check if there's more data available
      _hasMoreGoal = snapshot.docs.length == _pageSize;

      // Map documents to list with explicit type casting
      final newData = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return <String, dynamic>{
          'id': doc.id,
          ...data,
        };
      }).toList();

      if (isInitial) {
        _goalHistory = newData;
      } else {
        _goalHistory.addAll(newData);
      }

      if (!_disposed) notifyListeners();
    } catch (error, stackTrace) {
      _handleError('Failed to fetch goal history', error, stackTrace);
    }
  }

  // Fetch task history from Firestore subcollection, uses pagination with last document snapshot
  Future<void> _fetchTaskHistory(String uid, {bool isInitial = false}) async {
    try {
      Query query = FirebaseFirestore.instance
          .collection('Users')
          .doc(uid)
          .collection('taskHistory')
          .orderBy('enteredAt', descending: true)
          .limit(_pageSize);

      // If not initial load, start after last document
      if (!isInitial && _lastTaskDoc != null) {
        query = query.startAfterDocument(_lastTaskDoc!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        _hasMoreTask = false;
        if (isInitial) _taskHistory = [];
        return;
      }

      // Update last document for pagination
      _lastTaskDoc = snapshot.docs.last;

      // Check if there's more data available
      _hasMoreTask = snapshot.docs.length == _pageSize;

      // Map documents to list with explicit type casting
      final newData = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return <String, dynamic>{
          'id': doc.id,
          ...data,
        };
      }).toList();

      if (isInitial) {
        _taskHistory = newData;
      } else {
        _taskHistory.addAll(newData);
      }

      if (!_disposed) notifyListeners();
    } catch (error, stackTrace) {
      _handleError('Failed to fetch task history', error, stackTrace);
    }
  }

  /// Load more focus history items (next 50), Called when user clicks "Load More" button
  Future<void> loadMoreFocus() async {
    if (!_hasMoreFocus || _isLoadingMoreFocus) return;

    try {
      _isLoadingMoreFocus = true;
      if (!_disposed) notifyListeners();

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      await _fetchFocusHistory(uid, isInitial: false);
    } finally {
      _isLoadingMoreFocus = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> loadMoreGoal() async {
    if (!_hasMoreGoal || _isLoadingMoreGoal) return;

    try {
      _isLoadingMoreGoal = true;
      if (!_disposed) notifyListeners();

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      await _fetchGoalHistory(uid, isInitial: false);
    } finally {
      _isLoadingMoreGoal = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> loadMoreTask() async {
    if (!_hasMoreTask || _isLoadingMoreTask) return;

    try {
      _isLoadingMoreTask = true;
      if (!_disposed) notifyListeners();

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      await _fetchTaskHistory(uid, isInitial: false);
    } finally {
      _isLoadingMoreTask = false;
      if (!_disposed) notifyListeners();
    }
  }

  // Update the ViewModel state and notify listeners
  void _updateState(GoalsState newState) {
    if (_state != newState) {
      _state = newState;
      if (!_disposed) notifyListeners();
    }
  }

  /// Handle errors consistently across the ViewModel
  void _handleError(String context, dynamic error, [StackTrace? stackTrace]) {
    FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace ?? StackTrace.current,
        information: ['GoalsViewModel: $context']
    );
    _updateState(GoalsState.error);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Represents the different states of the GoalsViewModel
enum GoalsState {
  initial,   // Initial state when ViewModel is first created
  loading,   // Loading state during async operations
  success,   // Success state when operations complete successfully
  error      // Error state when operations fail
}