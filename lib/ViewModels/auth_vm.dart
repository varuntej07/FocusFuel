import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:focus_fuel/Models/user_model.dart';

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
  User? get currentUser => _currentUser;

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
      await db.collection('users').doc(credential.user!.uid).update({
        'isActive': true,
        'lastLogin': FieldValue.serverTimestamp()
      });

      final snap = await db.collection('users').doc(credential.user!.uid).get();

      final userModel = UserModel(
        uid: snap.get('uid'),
        email: snap.get('email'),
        username: snap.get('username'),
        isActive: snap.get('isActive'),
      );

      _currentUser = credential.user;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', userModel.username);

      return userModel;
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
      await db.collection('users').doc(credential.user!.uid).set({
        'uid': credential.user!.uid,
        'email': emailController.text.trim(),
        'username': usernameController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      _currentUser = credential.user;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', usernameController.text.trim());

      return credential.user;
    } catch (e) {
      errorMessage = "Registration failed. Try again.";
      return null;
    } finally {
      _stopLoading();
    }
  }

  Future<void> logout() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      // Marking this user inactive and removing their token on logout
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'isActive': false,
        'fcmToken': FieldValue.delete(),
      });
    }

    await FirebaseAuth.instance.signOut();

    // Wiping all cached prefs
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    _clearAll();
    _currentUser = null;
    notifyListeners();
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