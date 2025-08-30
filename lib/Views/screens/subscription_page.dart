import 'package:flutter/material.dart';

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
    return Scaffold(
      appBar: AppBar(title: Text('Subscription')),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
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
            SizedBox(
              width: 200,
              child: ElevatedButton(
                onPressed: () => print('Subscribing to Premium'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: Text(
                  'Subscribe for \$3.49',
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