import 'package:flutter/material.dart';
import '../../ViewModels/auth/signup_vm.dart';
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

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SignupViewModel>(); // Provides access to SignupViewModel

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
                  controller: vm.usernameController,
                  validator: (v) => (v?.isEmpty ?? true)? "Create a username brotha": null,
                  decoration: const InputDecoration(
                      hintText: "Create username", labelText: "Username",
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
                      prefixIcon: Icon(Icons.person)
                  )
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: vm.emailController,
                decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
                    prefixIcon: Icon(Icons.email)
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Enter email brotha';
                  }
                  if (!value.contains('@')) {
                    return 'Enter a valid email dawg';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: vm.passwordController,
                obscureText: true, // Masks password
                decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
                    prefixIcon: Icon(Icons.password)
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                     return 'Please create a password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 22),
              if (vm.isLoading) const CircularProgressIndicator(),
              if (vm.errorMessage != null) ...[  // ... is the spread operator inside a list literal
                const SizedBox(height: 8),    // vertical spacing before the error text.
                Text(vm.errorMessage!, style: const TextStyle(color: Colors.red))
              ],
              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: vm.isLoading
                    ? null    // Prevents multiple submissions
                    : () async {
                  if (!_formKey.currentState!.validate()) return;
                  if (await vm.signUp() && context.mounted) {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[600],
                  minimumSize: const Size.fromHeight(48),
                ),
                child: vm.isLoading
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