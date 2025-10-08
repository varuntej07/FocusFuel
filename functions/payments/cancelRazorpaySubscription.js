const functions = require('firebase-functions');
const admin = require('firebase-admin');
const Razorpay = require('razorpay');

const db = admin.firestore();

// Initialize Razorpay
const razorpay = new Razorpay({
  key_id: functions.config().razorpay?.key_id || 'rzp_test_dummy',
  key_secret: functions.config().razorpay?.key_secret || 'dummy_secret'
});

/**
 * Cancel user's Razorpay subscription
 *
 * @param {Object} data - Request data
 * @param {boolean} data.cancelAtCycleEnd - If true, cancel at end of billing cycle (default: true)
 *
 * @returns {Object} - { success: true, message: string, endsAt: timestamp }
 */
exports.cancelRazorpaySubscription = functions.https.onCall(async (data, context) => {
  // Authentication check
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const userId = context.auth.uid;
  const { cancelAtCycleEnd = true } = data;

  try {
    // Get user's subscription details
    const userDoc = await db.collection('Users').doc(userId).get();
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'User not found');
    }

    const userData = userDoc.data();
    const subscriptionId = userData.razorpaySubscriptionId;

    if (!subscriptionId) {
      throw new functions.https.HttpsError('not-found', 'No active subscription found');
    }

    // Fetch subscription from Razorpay to verify status
    const subscription = await razorpay.subscriptions.fetch(subscriptionId);

    if (subscription.status === 'cancelled' || subscription.status === 'completed') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Subscription is already cancelled or completed'
      );
    }

    // Cancel subscription
    const cancelledSubscription = await razorpay.subscriptions.cancel(subscriptionId, cancelAtCycleEnd);

    console.log(`Cancelled subscription ${subscriptionId} for user ${userId}`);

    // Update Firestore
    const updateData = {
      subscriptionStatus: cancelAtCycleEnd ? 'cancelled_at_cycle_end' : 'cancelled',
      razorpaySubscriptionStatus: cancelledSubscription.status,
      cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (cancelAtCycleEnd) {
      // Keep access until current period ends
      updateData.isSubscribed = true;  // Keep premium access
      updateData.subscriptionEndDate = new Date(cancelledSubscription.current_end * 1000);
    } else {
      // Immediate cancellation
      updateData.isSubscribed = false;  // Revoke access immediately
      updateData.subscriptionEndDate = admin.firestore.FieldValue.serverTimestamp();
    }

    await db.collection('Users').doc(userId).update(updateData);

    // Log cancellation
    await db.collection('subscription_logs').add({
      userId: userId,
      subscriptionId: subscriptionId,
      event: 'cancellation_requested',
      cancelAtCycleEnd: cancelAtCycleEnd,
      status: cancelledSubscription.status,
      endsAt: cancelledSubscription.current_end,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      message: cancelAtCycleEnd
        ? 'Subscription will be cancelled at the end of the current billing cycle'
        : 'Subscription cancelled immediately',
      endsAt: cancelledSubscription.current_end,
      status: cancelledSubscription.status
    };

  } catch (error) {
    console.error('Error cancelling subscription:', error);

    // Log error
    await db.collection('subscription_logs').add({
      userId: userId,
      event: 'cancellation_error',
      error: error.message,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    throw new functions.https.HttpsError(
      'internal',
      `Unable to cancel subscription: ${error.message}`
    );
  }
});
