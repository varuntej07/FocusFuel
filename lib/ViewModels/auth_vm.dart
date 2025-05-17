import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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

  Future<UserModel?> login() async {
    _startLoading();
    try {
      final userModel = await UserModel.login(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      isLoading = false;

      notifyListeners();

      return userModel;
    } on FirebaseAuthException catch (e) {
      errorMessage = _mapFirebaseError(e);
      return null;
    } finally {
      _stopLoading();
    }
  }

  Future<bool> signUp() async {
    _startLoading();
    try {
      // This does both: FirebaseAuth.createUser + Firestore write
      final user = await UserModel.register(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        username: usernameController.text.trim(),
      );

      if (user == null) {
        errorMessage = 'Signup failed: couldn’t store your data';
        return false;
      }
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    } finally {
      _stopLoading();
    }
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    _clearAll();
    notifyListeners(); // so UI resets (empty fields, no error)
  }

  void _startLoading() {
    errorMessage = null;
    isLoading    = true;
    notifyListeners();
  }
  void _stopLoading() {
    isLoading = false;
    notifyListeners();
  }

  // Turn raw FirebaseAuthException.code into a human message:
  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'user-not-found':
        return 'No account found for that email.';
      case 'wrong-password':
        return 'Incorrect password. Try again?';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password too weak (min 6 chars).';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a bit.';
      default:
        return e.message ?? 'Authentication error occurred.';
    }
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
}
