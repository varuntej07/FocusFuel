import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../Models/user_model.dart';

// ViewModel for Login screen, responsible for business logic and auth state.
class LoginViewModel extends ChangeNotifier {

  // Controllers live here so the page can bind directly to them
  final TextEditingController emailController    = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;  // Controls the spinner & button state
  String? errorMessage;

  /// Attempts to sign in using [UserModel.login]. Returns the model on success.
  Future<UserModel?> login() async {
    isLoading    = true;
    errorMessage = null;
    notifyListeners();

    try {
      final userModel = await UserModel.login(
        email:    emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      isLoading = false;

      notifyListeners();

      return userModel;
    } on FirebaseAuthException catch (e) {
      errorMessage = e.message ?? 'Login failed';
    } catch (e) {
      errorMessage = 'Login failed';
    }
    isLoading = false;

    notifyListeners();

    return null;
  }

  @override
  void dispose() {
    // Cleans up controllers when the VM is destroyed
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
