import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

// Data Classes
class Plan {
  final String title;
  final List<Section> sections;
  final String price;

  Plan({required this.title, required this.sections, required this.price});
}

class Section {
  final String header;
  final List<Feature> features;

  Section({required this.header, required this.features});
}

class Feature {
  final String name;
  final bool isIncluded;

  Feature({required this.name, required this.isIncluded});
}

// Plan Data
final basicPlan = Plan(
  title: 'Basic',
  sections: [
    Section(
      header: 'Enhanced Experience',
      features: [
        Feature(name: 'Ad-free experience', isIncluded: true),
        Feature(name: 'Task prioritization', isIncluded: false),
        Feature(name: 'Focus mode', isIncluded: true),
        Feature(name: 'Customizable reminders', isIncluded: false),
      ],
    ),
    Section(
      header: 'AI Assistance',
      features: [
        Feature(name: 'Usage limits for AI nudges', isIncluded: true),
        Feature(name: 'Advanced productivity analytics', isIncluded: false),
        Feature(name: 'Early access to new features', isIncluded: false),
      ],
    ),
    Section(
      header: 'Productivity Hub',
      features: [
        Feature(name: 'Goal tracking', isIncluded: true),
        Feature(name: 'Habit-building tools', isIncluded: false),
        Feature(name: 'Productivity reports', isIncluded: false),
        Feature(name: 'Integration with productivity apps', isIncluded: false),
      ],
    ),
  ],
  price: 'Starting at \$9.99',
);

final premiumPlan = Plan(
  title: 'Premium',
  sections: [
    Section(
      header: 'Enhanced Experience',
      features: [
        Feature(name: 'Ad-free experience', isIncluded: true),
        Feature(name: 'Task prioritization', isIncluded: true),
        Feature(name: 'Focus mode', isIncluded: true),
        Feature(name: 'Customizable reminders', isIncluded: true),
      ],
    ),
    Section(
      header: 'AI Assistance',
      features: [
        Feature(name: 'Unlimited AI nudges', isIncluded: true),
        Feature(name: 'Advanced productivity analytics', isIncluded: true),
        Feature(name: 'Early access to new features', isIncluded: true),
      ],
    ),
    Section(
      header: 'Productivity Hub',
      features: [
        Feature(name: 'Goal tracking', isIncluded: true),
        Feature(name: 'Habit-building tools', isIncluded: true),
        Feature(name: 'Productivity reports', isIncluded: true),
        Feature(name: 'Integration with productivity apps', isIncluded: true),
      ],
    ),
  ],
  price: 'Starting at \$14.99',
);


class FeatureItem extends StatelessWidget {
  final Feature feature;

  const FeatureItem({super.key, required this.feature});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            child: Text(feature.name, style: TextStyle(color: Colors.black)),
          ),
          SizedBox(width: 8),
          Icon(
            feature.isIncluded ? Icons.check_circle : Icons.lock,
            color: feature.isIncluded ? Colors.green : Colors.grey,
          ),
        ],
      ),
    );
  }
}

// Plan Card Widget
class PlanCard extends StatelessWidget {
  final Plan plan;

  const PlanCard({super.key, required this.plan});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Text(plan.title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black))),
              SizedBox(height: 16),
              ...plan.sections.map((section) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.header,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 8),
                  ...section.features.map((feature) => FeatureItem(feature: feature)),
                  SizedBox(height: 16),
                ],
              )),
              Spacer(),
              Center(
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        print('Subscribing to ${plan.title}');
                      },
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        padding: EdgeInsets.symmetric(horizontal: 70, vertical: 20),
                      ),
                      child: Text(plan.price, style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  _SubscriptionScreenState createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Subscription')),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              children: [
                PlanCard(plan: basicPlan),
                PlanCard(plan: premiumPlan),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: SmoothPageIndicator(
              controller: _pageController,
              count: 2,
              effect: WormEffect(
                dotColor: Colors.grey,
                activeDotColor: Colors.blue,
              ),
            ),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}