import 'package:flutter/material.dart';
import 'package:focus_fuel/ViewModels/auth_vm.dart';
import 'package:focus_fuel/Views/screens/profile_page.dart';
import 'package:focus_fuel/Views/screens/goals_page.dart';
import 'package:focus_fuel/Views/screens/settings_page.dart';
import 'package:focus_fuel/Views/screens/subscription_page.dart';
import 'package:focus_fuel/Views/screens/support_page.dart';
import 'package:provider/provider.dart';
import '../../Themes/theme_provider.dart';
import '../../ViewModels/home_vm.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  bool isDarkMode = false;
  bool isLoggedin = false;

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
          color: background ?? Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.2),
              blurRadius: 14,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: isIconTrailing ? null : Icon(icon, size: 26, color: background != null ? Colors.white : Theme.of(context).colorScheme.onSurface),                trailing: isIconTrailing
                    ? Icon(icon, size: 32, color: background != null ? Colors.white : Theme.of(context).colorScheme.onSurface)
                    : trailing,
                title: Text(
                  title,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: background != null ? Colors.white : Theme.of(context).textTheme.titleMedium?.color
                  ),
                ),
                subtitle: subtitle != null ? Text(
                    subtitle,
                    style: TextStyle(fontSize: 14, color: background != null ? Colors.white70 : Theme.of(context).textTheme.bodyMedium?.color))
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    isLoggedin = context.watch<HomeViewModel>().isAuthenticated;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 30),
        child: Column(
          children: [
            SizedBox(height: 10),

            _buildMenuCard(
              context: context,
              title: 'Try Premium 🔥',
              subtitle: 'Unlock pro features, stay extra hard!',
              icon: Icons.diamond,
              background: Colors.black87,
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
                      Navigator.push(context, MaterialPageRoute(
                          builder: (context) => ProfilePage()
                      ));
                    },
                  ),
                  _buildMenuCard(
                      context: context,
                      title: 'Goals',
                      icon: Icons.flag_rounded,
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(
                            builder: (context) => GoalsPage()
                        ));
                      }
                  ),
                  _buildMenuCard(
                    context: context,
                    title: 'Settings',
                    icon: Icons.settings,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(
                          builder: (context) => SettingsPage()
                      ));
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

                  Consumer<ThemeProvider>(
                    builder: (context, themeProvider, child) {
                      return _buildMenuCard(
                        context: context,
                        title: 'Mode',
                        icon: Icons.dark_mode,
                        onTap: () {}, // No action needed
                        trailing: Switch(
                          value: themeProvider.isDarkMode,
                          onChanged: (value) => themeProvider.toggleTheme(),
                          activeThumbColor: Theme.of(context).colorScheme.primary,
                        ),
                      );
                    },
                  ),

                  _buildMenuCard(
                    context: context,
                    title: isLoggedin ? 'Logout' : 'Login',
                    icon: isLoggedin ? Icons.exit_to_app : Icons.login,
                    onTap: () async {
                      await context.read<AuthViewModel>().logout();
                      // Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => Login()), (Route<dynamic> route) => false);
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