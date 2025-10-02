import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../ViewModels/auth_vm.dart';
class Feature {
  final String name;
  final bool isIncluded;
  Feature({required this.name, required this.isIncluded});
}

final premiumFeatures = [
  Feature(name: 'Ad-free experience', isIncluded: true),
  Feature(name: 'Customizable tone of voice for notifications', isIncluded: true),
  Feature(name: 'Customizable reminders to trigger notifications', isIncluded: true),
  Feature(name: 'Unlimited AI chat messages', isIncluded: true),
  Feature(name: 'Goal tracking', isIncluded: true),
  Feature(name: 'Productivity reports', isIncluded: true),
  Feature(name: 'Listen to articles', isIncluded: true),
  Feature(name: 'Personalized news feed', isIncluded: true),
  Feature(name: 'More news article suggestions', isIncluded: true),
];

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context);
    final userModel = authVM.userModel;

    return Scaffold(
      appBar: AppBar(title: Text('Subscription')),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            // Trial status banner
            if (userModel != null && userModel.isTrialActive)
              Container(
                padding: EdgeInsets.all(16),
                margin: EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange, width: 2),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: Colors.orange, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Free Trial Active',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${userModel.remainingTrialDays} days remaining',
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
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green, width: 2),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'You are a Premium member!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),

            Text(
              'Premium',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: premiumFeatures.length,
                itemBuilder: (context, index) {
                  final feature = premiumFeatures[index];
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          feature.isIncluded ? Icons.check : Icons.close,
                          color: Theme.of(context).iconTheme.color,
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            feature.name,
                            style: TextStyle(fontSize: 16, color: Theme.of(context).textTheme.bodyLarge?.color),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Hide subscribe button if already premium
            if (userModel == null || !userModel.isPremiumUser)
              SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: () async {
                    // TODO: Implement Stripe payment flow
                    // For now, show a placeholder message
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Payment integration coming soon! Configure Stripe to enable payments.'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: Text(
                    'Subscribe for \$4.49',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            SizedBox(height: 76),
          ],
        ),
      ),
    );
  }
}