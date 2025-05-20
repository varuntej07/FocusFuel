import 'package:flutter/material.dart';
import 'package:focus_fuel/ViewModels/auth_vm.dart';
import 'package:focus_fuel/ViewModels/home_vm.dart';
import 'package:provider/provider.dart';
import '../screens/main_scaffold.dart';
import 'login_page.dart';

class Signup extends StatefulWidget {
  const Signup({super.key});

  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  final _formKey = GlobalKey<FormState>();
  bool _viewPassword = true;

  void _togglePassword() => setState(() => _viewPassword = !_viewPassword);
  void _toggleConfirmPass() => setState(() => _viewPassword = !_viewPassword);


  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>(); // Provides access to AuthViewModel
    final homeVM = context.watch<HomeViewModel>();

    return Scaffold(
      backgroundColor: Colors.purple[50],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey, // Links to _formKey for validation
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Center(
                child: Text(
                    "Create account to be in top 10%",
                    style: TextStyle(color: Colors.indigoAccent, fontSize: 20, fontWeight: FontWeight.bold)
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                  controller: auth.usernameController,
                  validator: (v) => (v?.isEmpty ?? true)? "Create a username brotha": null,
                  decoration: const InputDecoration(
                      hintText: "Create username", labelText: "Username",
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
                      prefixIcon: Icon(Icons.person)
                  )
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: auth.emailController,
                decoration: const InputDecoration(
                    hintText: "Enter ya email", labelText: 'Email',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
                    prefixIcon: Icon(Icons.email)
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if ((v?.isEmpty ?? true)) return "Enter email bro";
                  if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v!)) {
                    return "This doesn’t look like a valid email";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: auth.passwordController,
                obscureText: _viewPassword,
                decoration: InputDecoration(
                    hintText: 'Password', labelText: 'Create Password',
                    border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_viewPassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: _togglePassword
                    )
                ),
                validator: (value) {
                  if ((value?.isEmpty ?? true)) return 'Please create a password first';
                  if (value!.length < 6) return 'Password must be at least 6 characters';
                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: auth.confirmPasswordController,
                obscureText: _viewPassword,
                decoration: InputDecoration(
                    hintText: 'Confirm password', labelText: 'Confirm password',
                    border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
                    prefixIcon: const Icon(Icons.password_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(_viewPassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: _toggleConfirmPass,
                    )
                ),
                validator: (value) {
                  if ((value?.isEmpty ?? true)) return 'Please confirm ya password';
                  if (value != auth.passwordController.text) return 'Passwords do not match';
                  return null;
                },
              ),

              const SizedBox(height: 16),

              if (auth.errorMessage != null) ...[  // ... is the spread operator inside a list literal
                const SizedBox(height: 8),    // vertical spacing before the error text.
                Text(auth.errorMessage!, style: const TextStyle(color: Colors.red))
              ],

              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: auth.isLoading
                    ? null    // Prevents multiple taps while async signup is in progress
                    : () async {
                  if (!_formKey.currentState!.validate()) return;     // validate before signing up

                  if (!context.mounted) return;

                  if (await auth.signUp()) {
                    await homeVM.loadData();    // Preload user info before navigating
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[600],
                  minimumSize: const Size.fromHeight(48),
                ),
                child: auth.isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text("Sign Up", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account?"),
                  TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Login())),
                      child: const Text("Login")
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const HomePage()),
                  (route) => false),
          child: const Text("Skip")),
    );
  }
}