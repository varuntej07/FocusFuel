import 'package:flutter/material.dart';
import 'package:focus_fuel/ViewModels/auth_vm.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../ViewModels/home_vm.dart';
import '../screens/main_scaffold.dart';
import 'login_page.dart';
import 'onboarding_flow.dart';

class Signup extends StatefulWidget {
  const Signup({super.key});

  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  final _formKey = GlobalKey<FormState>();
  bool _viewPassword = true;
  bool _isTermsAccepted = false;

  void _togglePassword() => setState(() => _viewPassword = !_viewPassword);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>(); // Provides access to AuthViewModel

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HomePage()),
            ),
            child: const Text(
              'Skip',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28.0),
        child: Form(
          key: _formKey, // Links to _formKey for validation
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                  "Focus Fuel",
                  style: GoogleFonts.dmSerifText(
                    textStyle: const TextStyle(
                      fontSize: 50,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              const Text(
                "Create an account to be in top 10%",
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),

              const SizedBox(height: 26),

              TextFormField(
                  controller: auth.usernameController,
                  validator: (v) => (v?.isEmpty ?? true)? "Create a username brotha": null,
                  decoration: InputDecoration(
                    hintText: "Create username", labelText: "Username",
                    labelStyle: const TextStyle(color: Colors.black87),
                    border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(26))),
                    prefixIcon: const Icon(Icons.person_outline),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide: const BorderSide(color: Colors.black26),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide: BorderSide(color: Colors.black87),
                    ),
                  )
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: auth.emailController,
                decoration: InputDecoration(
                  hintText: "Enter ya email", labelText: 'Email',
                  labelStyle: TextStyle(color: Colors.black87),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
                  prefixIcon: Icon(Icons.email_outlined),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: const BorderSide(color: Colors.black26),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide(color: Colors.black87),
                  ),
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
                    labelStyle: TextStyle(color: Colors.black87),
                    border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(26)),
                      ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide: const BorderSide(color: Colors.black26),
                      ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide: BorderSide(color: Colors.black87),
                    ),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_viewPassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: _togglePassword
                    ),
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
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Confirm password', labelText: 'Confirm password',
                  labelStyle: TextStyle(color: Colors.black87),
                  border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(26))),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(26),
                    borderSide: const BorderSide(color: Colors.black26),
                    ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(26),
                    borderSide: BorderSide(color: Colors.black87),
                  ),
                  prefixIcon: const Icon(Icons.password_outlined),
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

              // Terms and Conditions Checkbox
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _isTermsAccepted,
                    onChanged: (value) {
                      setState(() {
                        _isTermsAccepted = value ?? false;
                      });
                    },
                    activeColor: Colors.black87,
                    side: const BorderSide(color: Colors.black26),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                            height: 1.4,
                          ),
                          children: [
                            const TextSpan(
                              text: 'By checking this box, I agree that I have read, understood, and consent to our ',
                            ),
                            TextSpan(
                              text: 'Terms of Use',
                              style: TextStyle(
                                color: Colors.black87, fontWeight: FontWeight.w500,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: auth.isLoading
                    ? null    // Prevents multiple taps while async signup is in progress
                    : () async {
                  if (!_formKey.currentState!.validate()) return;     // validate before signing up

                  if (!context.mounted) return;

                  final user = await auth.signUp();
                  if (user != null) {
                    await context.read<HomeViewModel>().loadFromPrefs();

                    // Start full-screen onboarding for new users
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) =>
                              OnboardingScreen(userId: user.uid),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                            return FadeTransition(opacity: animation, child: child);
                          },
                          transitionDuration: const Duration(milliseconds: 500),
                        ),
                      ).then((_) {
                        // Navigate to main app after onboarding completes
                        if (context.mounted) {
                          Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const HomePage())
                          );
                        }
                      });
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: auth.isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text("Sign Up", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),

              const SizedBox(height: 30),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account?"),
                  TextButton(
                      onPressed: () {
                        context.read<AuthViewModel>().clearError(); // Clear error before navigation
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const Login()));
                      },
                      child: const Text("Login", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold))
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