import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import '../Services/shared_prefs_service.dart';
import 'home_vm.dart';

class GoalsViewModel extends ChangeNotifier {
  GoalsState _state = GoalsState.initial;
  GoalsState get state => _state;

  bool _disposed = false;
  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  List<Map<String, dynamic>> _focusHistory = [];
  List<Map<String, dynamic>> _goalHistory = [];
  List<Map<String, dynamic>> _taskHistory = [];

  List<Map<String, dynamic>> get focusHistory => _focusHistory;
  List<Map<String, dynamic>> get goalHistory => _goalHistory;
  List<Map<String, dynamic>> get taskHistory => _taskHistory;

  late SharedPreferencesService _prefsService;
  HomeViewModel? _homeViewModel;

  List<StreamSubscription<QuerySnapshot>>? _streamSubscriptions;

  GoalsViewModel() {
    _initializeViewModel();
  }

  void setHomeViewModel(HomeViewModel homeViewModel) {
    _homeViewModel = homeViewModel;
    _homeViewModel?.addListener(_onHomeViewModelChanged);
  }

  void _onHomeViewModelChanged() {
    if (_isAuthenticated) {
      _loadHistoryDataRealTime();
    }
  }

  Future<void> _initializeViewModel() async {
    try {
      _prefsService = await SharedPreferencesService.getInstance();
      _updateAuthenticationState(FirebaseAuth.instance.currentUser);
      _setupAuthenticationListener();

      if (_isAuthenticated) {
        await _loadHistoryDataRealTime();
      }
    } catch (error, stackTrace) {
      _handleError('Failed to initialize GoalsViewModel', error, stackTrace);
    }
  }

  void _setupAuthenticationListener() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      final wasAuthenticated = _isAuthenticated;
      _updateAuthenticationState(user);

      if (wasAuthenticated != _isAuthenticated) {
        if (_isAuthenticated) {
          await _loadHistoryDataRealTime();
        } else {
          _clearHistoryData();
          _cancelStreamSubscriptions();
        }
      }
    });
  }

  void _updateAuthenticationState(User? user) {
    final newAuthState = user != null;
    if (_isAuthenticated != newAuthState) {
      _isAuthenticated = newAuthState;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _loadHistoryDataRealTime() async {
    if (!_isAuthenticated) {
      _clearHistoryData();
      return;
    }

    try {
      _updateState(GoalsState.loading);

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _updateState(GoalsState.error);
        return;
      }

      _cancelStreamSubscriptions();
      _streamSubscriptions = [];

      // Set up real-time listeners for all history collections
      _setupFocusHistoryStream(uid);
      _setupGoalHistoryStream(uid);
      _setupTaskHistoryStream(uid);

      _updateState(GoalsState.success);
    } catch (error, stackTrace) {
      _handleError('Failed to load history data', error, stackTrace);
    }
  }

  void _setupFocusHistoryStream(String uid) {
    final subscription = FirebaseFirestore.instance
        .collection('Users')
        .doc(uid)
        .collection('focusHistory')
        .orderBy('enteredAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      _focusHistory = snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
      if (!_disposed) notifyListeners();
    }, onError: (error) {
      _handleError('Focus history stream error', error);
    });

    _streamSubscriptions?.add(subscription);
  }

  void _setupGoalHistoryStream(String uid) {
    final subscription = FirebaseFirestore.instance
        .collection('Users')
        .doc(uid)
        .collection('goalHistory')
        .orderBy('enteredAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      _goalHistory = snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
      if (!_disposed) notifyListeners();
    }, onError: (error) {
      _handleError('Goal history stream error', error);
    });

    _streamSubscriptions?.add(subscription);
  }

  void _setupTaskHistoryStream(String uid) {
    final subscription = FirebaseFirestore.instance
        .collection('Users')
        .doc(uid)
        .collection('taskHistory')
        .orderBy('enteredAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      _taskHistory = snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
      if (!_disposed) notifyListeners();
    }, onError: (error) {
      _handleError('Task history stream error', error);
    });

    _streamSubscriptions?.add(subscription);
  }

  void _cancelStreamSubscriptions() {
    _streamSubscriptions?.forEach((subscription) => subscription.cancel());
    _streamSubscriptions?.clear();
  }

  void _clearHistoryData() {
    _focusHistory = [];
    _goalHistory = [];
    _taskHistory = [];
    _updateState(GoalsState.initial);
  }

  void _updateState(GoalsState newState) {
    if (_state != newState) {
      _state = newState;
      if (!_disposed) notifyListeners();
    }
  }

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
    _homeViewModel?.removeListener(_onHomeViewModelChanged);
    _cancelStreamSubscriptions();
    super.dispose();
  }
}

enum GoalsState {
  initial,
  loading,
  success,
  error,
}