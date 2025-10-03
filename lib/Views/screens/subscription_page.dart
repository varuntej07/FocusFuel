import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../ViewModels/auth_vm.dart';
import 'payment_method_selection_page.dart';

class Feature {
  final IconData icon;
  final String name;
  final bool isPremium;
  Feature({required this.icon, required this.name, required this.isPremium});
}

final features = [
  Feature(icon: Icons.notifications_active, name: 'Unlimited AI notifications', isPremium: true),
  Feature(icon: Icons.chat_bubble, name: 'Unlimited AI chat queries (Free: 5/day)', isPremium: true),
  Feature(icon: Icons.volume_up, name: 'Listen to articles', isPremium: true),
  Feature(icon: Icons.tune, name: 'Customizable notification tone', isPremium: true),
  Feature(icon: Icons.alarm, name: 'Custom reminder triggers', isPremium: true),
  Feature(icon: Icons.trending_up, name: 'Goal tracking & analytics', isPremium: true),
  Feature(icon: Icons.bar_chart, name: 'Productivity reports', isPremium: true),
  Feature(icon: Icons.newspaper, name: 'Personalized news feed', isPremium: true),
  Feature(icon: Icons.article, name: 'More article suggestions', isPremium: true),
  Feature(icon: Icons.block, name: 'Ad-free experience', isPremium: true),
];

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context);
    final userModel = authVM.userModel;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[50],
      appBar: AppBar(
        title: Text('Subscription'),
        elevation: 0,
        backgroundColor: isDark ? Colors.black : Colors.grey[50],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Trial status banner
              if (userModel != null && userModel.isTrialActive)
                Container(
                  padding: EdgeInsets.all(16),
                  margin: EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).dividerColor, width: 2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.access_time, color: Theme.of(context).colorScheme.onPrimary, size: 24),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Free Trial Active',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).textTheme.headlineLarge?.color,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '${userModel.remainingTrialDays} days remaining of unlimited access',
                              style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium?.color),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Premium status banner
              if (userModel != null && userModel.isPremiumUser)
                Container(
                  padding: EdgeInsets.all(16),
                  margin: EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).dividerColor, width: 2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check_circle, color: Theme.of(context).colorScheme.onPrimary, size: 24),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Premium Member',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).textTheme.headlineLarge?.color,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Enjoying unlimited access to all features',
                              style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium?.color),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Pricing card
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '\$',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                        Text(
                          '4.49',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimary,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'per month',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.9),
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Monthly Subscription',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 36),

              // Features list
              ...features.map((feature) => Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Icon(
                      feature.isPremium ? Icons.check : Icons.close,
                      color: Theme.of(context).iconTheme.color,
                      size: 20,
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        feature.name,
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ),
                  ],
                ),
              )).toList(),

              SizedBox(height: 24),

              // Subscribe button (hide if already premium)
              if (userModel == null || !userModel.isPremiumUser)
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PaymentMethodSelectionPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 5,
                  ),
                  child: Text(
                    'Get Premium for \$4.49/month',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),

              SizedBox(height: 16),

              // Terms text
              Text(
                'Monthly subscription • Cancel anytime',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}