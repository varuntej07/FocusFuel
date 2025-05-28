import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:focus_fuel/Models/user_model.dart';
import '../Utils/shared_prefs_service.dart';

// ViewModel for Authorization, responsible for business logic and Auth state
class AuthViewModel extends ChangeNotifier {

  // Controllers live here so the page can bind directly to them
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final usernameController = TextEditingController();

  bool isLoading = false;     // Controls the spinner & button state
  String? errorMessage;
  User? _currentUser;
  UserModel? _userModel;

  late SharedPreferencesService _prefsService;

  // Constructor – loads prefs only once
  AuthViewModel() {
    initializePreferences();
  }

  // Initializing SharedPreferences service
  Future<void> initializePreferences() async {
    _prefsService = await SharedPreferencesService.getInstance();
  }

  Future<void> _cacheUser() async {
    await _prefsService.saveUsername(_userModel!.username);
    await _prefsService.saveEmail(_userModel!.email);
    await _prefsService.saveUserId(_userModel!.uid);
  }

  void _startLoading() {
    isLoading = true;
    notifyListeners();
  }

  void _stopLoading() {
    isLoading = false;
    notifyListeners();
  }

  void _clearAll() {
    emailController.clear();
    passwordController.clear();
    confirmPasswordController.clear();
    usernameController.clear();
    errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    usernameController.dispose();
    super.dispose();
  }

  Future<UserModel?> login() async {
    _startLoading();
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final db = FirebaseFirestore.instance;
      // updating the collection whenever the user logs in
      await db.collection('Users').doc(credential.user!.uid).update({
        'isActive': true,
        'lastLogin': FieldValue.serverTimestamp()
      });

      final snap = await db.collection('Users').doc(credential.user!.uid).get();

      _userModel = UserModel(
        uid: snap.get('uid'),
        email: snap.get('email'),
        username: snap.get('username'),
        isActive: true,
      );

      _currentUser = credential.user;
      await _cacheUser();             // Saving to SharedPreferences using centralized service
      errorMessage = null;

      return _userModel;
    } on FirebaseAuthException catch (e) {
      errorMessage = _mapFirebaseError(e);
      return null;
    } finally {
      _stopLoading();
    }
  }

  Future<User?> signUp() async {
    _startLoading();
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final db = FirebaseFirestore.instance;
      // Setting up the collection whenever the user Signs up
      await db.collection('Users').doc(credential.user!.uid).set({
        'uid': credential.user!.uid,
        'email': emailController.text.trim(),
        'username': usernameController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      // building the model before touching prefs
      _userModel = UserModel(
        uid: credential.user!.uid,
        email: emailController.text.trim(),
        username: usernameController.text.trim(),
        isActive: true,
      );
      _currentUser = credential.user;

      await _cacheUser();           //  now caching it

      errorMessage = null;

      return credential.user;
    } catch (e) {
      errorMessage = "Registration failed. Try again.";
      return null;
    } finally {
      _stopLoading();
    }
  }

  Future<void> logout() async {
    var uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      // Marking this user inactive and removing their token on logout
      await FirebaseFirestore.instance.collection('Users').doc(uid).update({
        'isActive': false,
        'fcmToken': FieldValue.delete(),
      });
    }

    await FirebaseAuth.instance.signOut();

    await _prefsService.clearAll();

    _clearAll();
    _currentUser = null;
    _userModel = null;
    uid = null;
    notifyListeners();
  }

  Future<void> submitSupportMessage(String issueDescription) async {
    print("This is the _user model:  ----------$_userModel---------------");
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
    } catch (e) {
      errorMessage = 'Failed to send support message. Please try again.';
    } finally {
      _stopLoading();
    }
  }

  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address looks invalid. check again!';
      case 'user-not-found':
        return 'No account found for that email.';
      case 'invalid-credential':
        return 'Email or password is Incorrect. Try again';
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
}