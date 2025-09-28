import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:focus_fuel/Models/user_model.dart';
import '../Services/shared_prefs_service.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

// ViewModel for Authorization, responsible for business logic and Auth state
class AuthViewModel extends ChangeNotifier {
  // State management values defined in the AuthState enum. It represents the initial state of the authentication process.
  AuthState _state = AuthState.initial;
  AuthState get state => _state;

  // Controllers live here so the page can bind directly to them
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final usernameController = TextEditingController();

  bool isLoading = false;     // Controls the spinner & button state
  bool _isSubscribed = false;
  bool get isSubscribed => _isSubscribed;
  final bool _disposed = false;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  UserModel? _userModel;
  UserModel? get userModel => _userModel;

  late SharedPreferencesService _prefsService;

  // Constructor
  AuthViewModel() {
    initializePreferences();
    _setupAuthStateListener();
  }

  // Initializing SharedPreferences service
  Future<void> initializePreferences() async {
    _prefsService = await SharedPreferencesService.getInstance();
  }

  // Setup Firebase Auth state listener
  void _setupAuthStateListener() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        _loadUserData(user.uid);
      } else {
        _clearUserData();
      }
    });
  }

  // Load user data from Firestore
  Future<void> _loadUserData(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('Users').doc(uid).get();
      if (doc.exists) {
        _userModel = UserModel.fromMap(doc.data()!);
        // TODO: After loading userModel, check/update their subscription status here if needed
        await _cacheUser();
        _state = AuthState.authenticated;
        if (!_disposed) notifyListeners();
      } else {
        _state = AuthState.unauthenticated;
        if (!_disposed) notifyListeners();
      }
    } catch (error, stackTrace) {
      _handleError('Failed to load user data', error, stackTrace);
    }
  }

  // Cache user data to SharedPreferences
  Future<void> _cacheUser() async {
    if (_userModel == null) return;
    await _prefsService.saveUsername(_userModel!.username);
    await _prefsService.saveEmail(_userModel!.email);
    await _prefsService.saveUserId(_userModel!.uid);
  }

  void _startLoading() {
    isLoading = true;
    if (!_disposed) notifyListeners();
  }

  void _stopLoading() {
    isLoading = false;
    if (!_disposed) notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    if (!_disposed) notifyListeners();
  }

  // Clear user data
  void _clearUserData() {
    _userModel = null;
    _state = AuthState.unauthenticated;
  }

  // Clear form data
  void _clearForm() {
    emailController.clear();
    passwordController.clear();
    confirmPasswordController.clear();
    usernameController.clear();
    _errorMessage = null;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    usernameController.dispose();
    super.dispose();
  }

  // Login user
  Future<UserModel?> login() async {
    _startLoading();
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final timezone = await FlutterTimezone.getLocalTimezone();
      await FirebaseFirestore.instance.collection('Users').doc(credential.user!.uid).update({
        'isActive': true,
        'lastLogin': FieldValue.serverTimestamp(),
        'timezone': timezone.toString(),
      });

      final snap = await FirebaseFirestore.instance.collection('Users').doc(credential.user!.uid).get();
      _userModel = UserModel.fromMap(snap.data()!);
      await _cacheUser();
      _errorMessage = null;

      // Save the uid to SharedPreferences
      await _prefsService.saveUserId(credential.user!.uid);

      _state = AuthState.authenticated;
      if (!_disposed) notifyListeners();

      return _userModel;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapFirebaseError(e);
      _state = AuthState.error;
      return null;
    } finally {
      _stopLoading();
    }
  }

  // Sign up user
  Future<User?> signUp() async {
    _startLoading();
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final userData = {
        'uid': credential.user!.uid,
        'email': emailController.text.trim(),
        'username': usernameController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),    // server timestamp in UTC timezone
        'accountCreatedOn': FieldValue.serverTimestamp(),
        'isActive': true,
        'timezone': (await FlutterTimezone.getLocalTimezone()).toString(),
      };

      await FirebaseFirestore.instance.collection('Users').doc(credential.user!.uid).set(userData);

      // Creating UserModel with current timestamp instead of server timestamp
      _userModel = UserModel(
        uid: credential.user!.uid,
        email: emailController.text.trim(),
        username: usernameController.text.trim(),
        createdAt: DateTime.now(),
        isActive: true,
        accountCreatedOn: DateTime.now(),
        isSubscribed: _isSubscribed,
      );

      await _cacheUser();

      _errorMessage = null;
      _state = AuthState.authenticated;

      return credential.user;
    } catch (error, stackTrace) {
      if (error is FirebaseAuthException) {
        _errorMessage = _mapFirebaseError(error);
        _state = AuthState.error;

        if (!_disposed) notifyListeners();
      } else {
        _handleError('Registration failed', error, stackTrace);
      }
      return null;
    } finally {
      _stopLoading();
    }
  }

  Future<void> logout() async {
    _startLoading();
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        // Marking this user inactive and removing their token on logout
        await FirebaseFirestore.instance.collection('Users').doc(uid).update({
          'isActive': false,
          'fcmToken': FieldValue.delete(),
        });
      }

      await FirebaseAuth.instance.signOut();

      await _prefsService.logout();
      
      _clearForm();
      _clearUserData();

    } catch (error, stackTrace) {
      _handleError('Failed to logout', error, stackTrace);
    } finally {
      _stopLoading();
    }
  }

  Future<void> submitSupportMessage(String issueDescription) async {
    if (_userModel == null || issueDescription.isEmpty) return;

    _startLoading();
    try {
      // creating separate collection for support messages
      await FirebaseFirestore.instance.collection('ReportMessages').add({
        'name': _prefsService.getUsername(),
        'email': _prefsService.getEmail(),
        'issueDescription': issueDescription.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      _errorMessage = null;
    } catch (error, stackTrace) {
      _handleError('Failed to send support message', error, stackTrace);
    } finally {
      _stopLoading();
    }
  }

  void updateUserSubscriptionStatus(bool newStatus) {
    if (_userModel == null) return;
    _isSubscribed = newStatus;
    notifyListeners();
  }

  bool get canAccessPremiumFeatures {
    if (_userModel == null) return false;
    final now = DateTime.now();
    final accountCreatedOn = _userModel!.accountCreatedOn ?? DateTime.now().subtract(const Duration(days: 9999));
    final daysSinceSignup = now.difference(accountCreatedOn).inDays;
    return _userModel!.isSubscribed || daysSinceSignup <= 14;
  }

  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address looks invalid. check again!';
      case 'user-not-found':
        return 'No account found for that email.';
      case 'invalid-credential':
        return 'Email or password is incorrect. Try again';
      case 'email-already-in-use':
        return 'This email is already registered. Login instead';
      case 'weak-password':
        return 'Password too weak (min 6 chars).';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a bit and retry.';
      default:
        return e.message ?? 'Authentication error occurred. Please try again later';
    }
  }

  void _handleError(String context, dynamic error, [StackTrace? stackTrace]) {
    FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace ?? StackTrace.current,
        information: ['AuthViewModel: $context']
    );
    _errorMessage = 'Something went wrong. Please try again.';
    _state = AuthState.error;
    notifyListeners();
  }
}

// Auth state enum for better state management
enum AuthState {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error
}