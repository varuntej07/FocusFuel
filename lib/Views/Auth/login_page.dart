import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../ViewModels/auth_vm.dart';
import '../../ViewModels/home_vm.dart';
import '../screens/main_scaffold.dart';
import 'signup_page.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _formKey = GlobalKey<FormState>();
  bool _viewPassword = true;
  void _togglePassword() => setState(() => _viewPassword = !_viewPassword);

  void _showLoginFailedDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Login Failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>(); // Listen for isLoading & errorMessage

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Welcome to Focus Fuel",
                style: TextStyle(color: Colors.black87, fontSize: 30, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),

              TextFormField(
                controller: auth.emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: "Email",
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(26)),
                ),
                validator: (v) => (v?.isEmpty ?? true) ? "Enter your email" : null),
              const SizedBox(height: 12),

              TextFormField(
                controller: auth.passwordController,
                obscureText: _viewPassword,
                decoration: InputDecoration(
                  hintText: "Password",
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_viewPassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: _togglePassword
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(26)),
                ),
                validator: (v) => (v?.isEmpty ?? true) ? "Enter your password" : null,
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: auth.isLoading ? null : () async {
                  if (!_formKey.currentState!.validate()) return;  // validate first before logging in

                  final success = await auth.login();
                  if (!context.mounted) return;

                  if (success != null) {
                    //context.read<ChatViewModel>().updateUser(success.uid);
                    await context.read<HomeViewModel>().loadFromPrefs();   // providing the logic for loading data through HomeViewModel
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
                  } else{
                    _showLoginFailedDialog(auth.errorMessage ?? 'Login failed. Please try again.');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: auth.isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text("Log In", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white,)),
              ),

              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account?"),
                  TextButton(
                    onPressed: () {
                      context.read<AuthViewModel>().clearError(); // Clear error before navigation
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const Signup()));
                    },
                    child: const Text("Sign Up", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}