import 'package:flutter/material.dart';
import '../../models/user_model.dart';

class SignupViewModel extends ChangeNotifier {

  // Controllers inside so .signUp() down, can read them
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController    = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  String? errorMessage;

  Future<bool> signUp() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

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
      isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
