import 'package:flutter/material.dart';
import 'package:focus_fuel/ViewModels/auth_vm.dart';
import 'package:focus_fuel/Views/Auth/login_page.dart';
import 'package:focus_fuel/Views/screens/subscription_page.dart';
import 'package:focus_fuel/Views/screens/support_page.dart';
import 'package:provider/provider.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  bool isDarkMode = false;

  Widget _buildMenuCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    Color? background,
    String? subtitle,
    Widget? trailing,
    bool isIconTrailing = false,
  })
  {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: background ?? Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: isIconTrailing ? null : Icon(icon, size: 32, color: background != null ? Colors.white : Colors.black54),
                trailing: isIconTrailing
                    ? Icon(icon, size: 32, color: background != null ? Colors.white : Colors.black54)
                    : trailing,
                title: Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: background != null ? Colors.white : Colors.black87,
                  ),
                ),
                subtitle: subtitle != null ? Text(
                    subtitle,
                    style: TextStyle(fontSize: 14, color: background != null ? Colors.white70 : Colors.black54))
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void toggleTheme(bool value) {
    setState(() {
      isDarkMode = value;
      // actual dark mode logic using a theme provider or state manager
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          children: [
            _buildMenuCard(
              context: context,
              title: 'Try Premium 🔥',
              subtitle: 'Unlock pro features, stay extra hard!',
              icon: Icons.diamond,
              background: Colors.deepPurpleAccent,
              isIconTrailing: true,
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => SubscriptionScreen()));
              },
            ),
            Expanded(
              child: ListView(
                children: [
                  _buildMenuCard(
                    context: context,
                    title: 'Profile',
                    icon: Icons.person_outline,
                    onTap: () {
                      // TODO: navigate to profile
                    },
                  ),
                  _buildMenuCard(
                    context: context,
                    title: 'Settings',
                    icon: Icons.settings,
                    onTap: () {
                      // TODO: navigate to settings
                    },
                  ),
                  _buildMenuCard(
                    context: context,
                    title: 'Forums',
                    icon: Icons.forum,
                    onTap: () {
                      // TODO: navigate to forums
                    },
                  ),
                  _buildMenuCard(
                    context: context,
                    title: 'Support',
                    icon: Icons.contact_support_outlined,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => SupportScreen()));
                    },
                  ),
                  _buildMenuCard(
                    context: context,
                    title: 'Mode',
                    icon: Icons.dark_mode,
                    onTap: () {
                      // TODO Perform dark mode
                    }, // No action
                    trailing: Switch(
                      value: isDarkMode,
                      onChanged: toggleTheme,
                    ),
                  ),
                  const SizedBox(height: 30),
                  _buildMenuCard(
                    context: context,
                    title: 'Logout',
                    icon: Icons.exit_to_app,
                    onTap: () async {
                      await context.read<AuthViewModel>().logout();
                      Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => Login()), (Route<dynamic> route) => false
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}