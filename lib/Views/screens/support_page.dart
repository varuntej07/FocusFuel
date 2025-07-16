import 'package:flutter/material.dart';
import 'package:focus_fuel/Services/shared_prefs_service.dart';
import 'package:provider/provider.dart';
import '../../ViewModels/auth_vm.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController issueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController();
    emailController = TextEditingController();
    issueController = TextEditingController();
  }


  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    issueController.dispose();
    super.dispose();
  }

  // helper to avoid repeating decoration boiler-plate
  InputDecoration _decor(String label) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    filled: true,
    fillColor:Colors.grey[100],
    focusedBorder: OutlineInputBorder( // Border when focused
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey[600]!, width: 2.0),
    )
  );

  void _showSuccessMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var sharedPrefs = SharedPreferencesService();
    return Scaffold(
      appBar: AppBar(title: const Text('Support', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)), centerTitle: true),
      body: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(20),
        child: Consumer<AuthViewModel>(
          builder: (context, vm, _) {
            return Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Facing a problem?',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Describe your issue and I\'ll get back to you soon.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 30),

                    TextFormField(
                      initialValue: sharedPrefs.getUsername(),
                      readOnly: true,
                      decoration: _decor('Name'),
                    ),
                    const SizedBox(height: 15),

                    TextFormField(
                      initialValue: sharedPrefs.getEmail(),
                      readOnly: true,
                      decoration: _decor('Email'),
                    ),
                    const SizedBox(height: 15),

                    TextFormField(
                      keyboardType: TextInputType.multiline,
                      controller: issueController,
                      maxLines: 8,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _decor('Describe the issue here...'),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please describe the issue';
                        }
                        if (val.trim().length < 7) {
                          return 'Please provide more details (at least 7 characters)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 30),

                    // Error message display
                    if (vm.errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          border: Border.all(color: Colors.red[200]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(vm.errorMessage!, style: TextStyle(color: Colors.red[700]),
                        ),
                      ),
                    ],

                    ElevatedButton(
                      onPressed: vm.isLoading
                          ? null
                          : () async {
                        if (!_formKey.currentState!.validate()) return;

                        await vm.submitSupportMessage(issueController.text);

                        _showSuccessMessage('Message sent successfully!');
                        issueController.clear();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black87,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        elevation: 2,
                      ),
                      child: const Text('Submit Support Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}