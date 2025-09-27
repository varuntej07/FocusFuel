import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../ViewModels/auth_vm.dart';
import '../../ViewModels/home_vm.dart';
import '../../Services/shared_prefs_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool isLoggedin = false;
  late SharedPreferencesService _prefsService;

  @override
  void initState() {
    super.initState();
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefsService = await SharedPreferencesService.getInstance();
    if (mounted) {
      final authenticated = await _prefsService.isAuthenticated();
      setState(() {
        isLoggedin = authenticated;
      });
    }
  }

  Widget _buildProfileHeader(BuildContext context, AuthViewModel auth, HomeViewModel home) {
    final username = auth.userModel?.username ?? _prefsService.getUsername() ?? 'User';
    final email = auth.userModel?.email ?? _prefsService.getEmail() ?? 'No email';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.2),
            blurRadius: 14,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Text(
              username.isNotEmpty ? username[0].toUpperCase() : 'U',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            username,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            email,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            ),
          ),
          if (auth.canAccessPremiumFeatures) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                auth.userModel?.isSubscribed == true ? 'Premium' : 'Trial',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, {Color? iconColor}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24,
              color: iconColor ?? Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, AuthViewModel auth, HomeViewModel home) {
    final user = auth.userModel;
    if (user == null) {
      return const SizedBox();
    }

    return Row(
      children: [
        _buildStatCard(context, 'Current Streak', '${home.streak}', Icons.local_fire_department, iconColor: Colors.red),
        const SizedBox(width: 12),
        _buildStatCard(context, 'Longest Streak', '${user.longestStreak}', Icons.trending_up, iconColor: Colors.green),
        const SizedBox(width: 12),
        _buildStatCard(
          context,
          'Account Age',
          '${user.accountCreatedOn != null ? DateTime.now().difference(user.accountCreatedOn!).inDays : 0}',
          Icons.calendar_today,
          iconColor: Colors.blue
        ),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context, String title, String? value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value ?? 'Not set',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final home = context.watch<HomeViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: !isLoggedin ? const Center(child: Text('Please log in to view your profile'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileHeader(context, auth, home),
                  const SizedBox(height: 24),
                  _buildStatsRow(context, auth, home),
                  const SizedBox(height: 24),
                  Text(
                    'Current Goals',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard(context, 'Current Focus', home.currentFocus, Icons.center_focus_strong),
                  _buildInfoCard(context, 'Weekly Goal', home.weeklyGoal, Icons.flag),
                  _buildInfoCard(context, 'Current Task', home.usersTask, Icons.task_alt),
                  const SizedBox(height: 16),
                  Text(
                    'Account Information',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard(context, 'Username', auth.userModel?.username ?? _prefsService.getUsername(), Icons.person),
                  _buildInfoCard(context, 'Email', auth.userModel?.email ?? _prefsService.getEmail(), Icons.email),
                  _buildInfoCard(
                    context,
                    'Account Created',
                    auth.userModel?.accountCreatedOn != null
                      ? '${auth.userModel!.accountCreatedOn!.day}/${auth.userModel!.accountCreatedOn!.month}/${auth.userModel!.accountCreatedOn!.year}'
                      : null,
                    Icons.calendar_month
                  ),
                  _buildInfoCard(
                    context,
                    'Notifications',
                    auth.userModel?.notificationsEnabled == true ? 'Enabled' : 'Disabled',
                    Icons.notifications
                  ),
                ],
              ),
            ),
    );
  }
}