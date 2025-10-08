import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RazorpayService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static late Razorpay _razorpay;
  static BuildContext? _context;

  /// Initialize Razorpay instance
  static void initialize() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  /// Dispose Razorpay instance
  static void dispose() {
    _razorpay.clear();
  }

  /// Process subscription payment with Razorpay
  ///
  /// Returns true if payment flow was initiated successfully
  /// Actual success is handled via callbacks
  static Future<bool> createSubscription({
    required BuildContext context,
    required String planId,  // Razorpay plan ID from dashboard
  }) async {
    _context = context;

    try {
      // Get current user
      final user = _auth.currentUser;
      if (user == null) {
        _showError(context, 'You must be logged in to subscribe');
        return false;
      }

      // Show loading indicator
      _showLoadingDialog(context);

      // Step 1: Create subscription from Cloud Function
      final callable = _functions.httpsCallable('createRazorpaySubscription');
      final response = await callable.call({'planId': planId});

      final subscriptionId = response.data['subscriptionId'] as String;
      final customerId = response.data['customerId'] as String;

      // Close loading dialog
      if (context.mounted) Navigator.of(context).pop();

      // Step 2: Open Razorpay checkout for subscription
      await _openRazorpayCheckout(
        context: context,
        subscriptionId: subscriptionId,
        customerId: customerId,
      );

      return true;
    } catch (e) {
      // Close loading dialog if still open
      if (context.mounted) Navigator.of(context).pop();

      if (context.mounted) {
        _showError(context, 'Failed to create subscription: ${e.toString()}');
      }
      return false;
    }
  }

  /// Open Razorpay checkout for subscription payment
  static Future<void> _openRazorpayCheckout({
    required BuildContext context,
    required String subscriptionId,
    required String customerId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Get user details
    final userDoc = await _firestore.collection('Users').doc(user.uid).get();
    final userData = userDoc.data();
    final userName = userData?['username'] ?? 'FocusFuel User';
    final userEmail = user.email ?? userData?['email'] ?? '';
    final userPhone = userData?['phone'] ?? '';

    // Razorpay checkout options
    var options = {
      // IMPORTANT: Replace with your actual Razorpay Key ID
      // Get from: https://dashboard.razorpay.com/app/keys
      'key': 'rzp_test_YOUR_KEY_ID',  // TODO: Replace with actual key

      'subscription_id': subscriptionId,

      'name': 'FocusFuel Premium',
      'description': 'Monthly subscription to unlock all premium features',

      // Customer details (prefill)
      'prefill': {
        'email': userEmail,
        'contact': userPhone,
        'name': userName,
      },

      // Branding
      'theme': {
        'color': '#6366F1',  // Your app primary color
      },

      // Additional options
      'modal': {
        'confirm_close': true,
        'ondismiss': () {
          debugPrint('Checkout cancelled by user');
        }
      },

      'notes': {
        'userId': user.uid,
        'username': userName,
      },

      // Recurring payment flag
      'recurring': 1,
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error opening Razorpay checkout: $e');
      if (context.mounted) {
        _showError(context, 'Failed to open payment gateway');
      }
    }
  }

  /// Handle successful payment
  static void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint('Payment Success: ${response.paymentId}');
    debugPrint('Order ID: ${response.orderId}');
    debugPrint('Signature: ${response.signature}');

    if (_context != null && _context!.mounted) {
      _showSuccess(_context!, 'Payment successful! Welcome to Premium 🎉');

      // Navigate back or refresh
      Navigator.of(_context!).popUntil((route) => route.isFirst);
    }

    // Note: Subscription activation is handled by Razorpay webhook
    // User document will be updated automatically when webhook fires
  }

  /// Handle payment error
  static void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('Payment Error: ${response.code} - ${response.message}');

    if (_context != null && _context!.mounted) {
      String errorMessage = 'Payment failed';

      switch (response.code) {
        case Razorpay.PAYMENT_CANCELLED:
          errorMessage = 'Payment was cancelled';
          break;
        case Razorpay.NETWORK_ERROR:
          errorMessage = 'Network error. Please check your internet connection';
          break;
        case Razorpay.INVALID_OPTIONS:
          errorMessage = 'Invalid payment configuration';
          break;
        case Razorpay.TLS_ERROR:
          errorMessage = 'Security error. Please update your device';
          break;
        default:
          errorMessage = response.message ?? 'Payment failed. Please try again';
      }

      _showError(_context!, errorMessage);
    }
  }

  /// Handle external wallet selection
  static void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('External Wallet: ${response.walletName}');

    if (_context != null && _context!.mounted) {
      _showInfo(_context!, 'Opening ${response.walletName}...');
    }
  }

  /// Cancel user's subscription
  static Future<bool> cancelSubscription({
    required BuildContext context,
    bool cancelAtCycleEnd = true,
  }) async {
    try {
      // Show loading
      _showLoadingDialog(context);

      // Call Cloud Function to cancel subscription
      final callable = _functions.httpsCallable('cancelRazorpaySubscription');
      final response = await callable.call({
        'cancelAtCycleEnd': cancelAtCycleEnd,
      });

      // Close loading
      if (context.mounted) Navigator.of(context).pop();

      final success = response.data['success'] as bool;
      final message = response.data['message'] as String;

      if (success) {
        if (context.mounted) {
          _showSuccess(context, message);
        }
        return true;
      } else {
        if (context.mounted) {
          _showError(context, 'Failed to cancel subscription');
        }
        return false;
      }
    } catch (e) {
      // Close loading
      if (context.mounted) Navigator.of(context).pop();

      if (context.mounted) {
        _showError(context, 'Error cancelling subscription: ${e.toString()}');
      }
      return false;
    }
  }

  /// Show loading dialog
  static void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  /// Show error message
  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Show success message
  static void _showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Show info message
  static void _showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
