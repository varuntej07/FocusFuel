import 'package:flutter/material.dart';
import 'package:focus_fuel/Views/screens/subscription_page.dart';

class SubscriptionDialog extends StatelessWidget {
  final String? title;
  final String? message;
  final String? featureName;
  final VoidCallback? onSubscribePressed;
  final VoidCallback? onCancelPressed;

  const SubscriptionDialog({
    super.key,
    this.title,
    this.message,
    this.featureName,
    this.onSubscribePressed,
    this.onCancelPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.lock, color: Colors.orange, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              title ?? 'Premium Feature',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message ?? '${featureName ?? 'This feature'} is available for premium users only.',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.star, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Subscribe to unlock all premium features',
                    style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onCancelPressed ?? () => Navigator.of(context).pop(),
          child: Text('Maybe Later', style: TextStyle(color: Colors.grey.shade600)),
        ),
        ElevatedButton(
          onPressed: onSubscribePressed ?? () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text('Subscribe Now'),
        ),
      ],
    );
  }

  // Static method to show the dialog easily
  static Future<void> show(
      BuildContext context, {
        String? title,
        String? message,
        String? featureName,
        VoidCallback? onSubscribePressed,
        VoidCallback? onCancelPressed,
      }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return SubscriptionDialog(
          title: title,
          message: message,
          featureName: featureName,
          onSubscribePressed: onSubscribePressed,
          onCancelPressed: onCancelPressed,
        );
      },
    );
  }
}

// Extension to make it even easier to use
extension SubscriptionDialogExtension on BuildContext {
  Future<void> showSubscriptionDialog({
    String? title,
    String? message,
    String? featureName,
    VoidCallback? onSubscribePressed,
    VoidCallback? onCancelPressed,
  }) {
    return SubscriptionDialog.show(
      this,
      title: title,
      message: message,
      featureName: featureName,
      onSubscribePressed: onSubscribePressed,
      onCancelPressed: onCancelPressed,
    );
  }
}