const functions = require('firebase-functions');
const admin = require('firebase-admin');
const Razorpay = require('razorpay');

const db = admin.firestore();

// Initialize Razorpay with credentials from Firebase config
// Set via: firebase functions:config:set razorpay.key_id="rzp_test_xxx" razorpay.key_secret="xxx"
const razorpay = new Razorpay({
  key_id: functions.config().razorpay?.key_id || 'rzp_test_dummy',
  key_secret: functions.config().razorpay?.key_secret || 'dummy_secret'
});

/**
 * Creates a Razorpay subscription for a user
 *
 * @param {Object} data - Request data
 * @param {string} data.planId - Razorpay plan ID (created in dashboard)
 * @param {number} data.totalCount - Number of billing cycles (12 for annual, leave empty for perpetual)
 *
 * @returns {Object} - { subscriptionId, razorpayOrderId, customerId }
 */
exports.createRazorpaySubscription = functions.https.onCall(async (data, context) => {
  // Authentication check
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const userId = context.auth.uid;
  const { planId = functions.config().razorpay?.plan_id } = data;

  if (!planId) {
    throw new functions.https.HttpsError('invalid-argument', 'Plan ID is required');
  }

  try {
    // Get user details from Firestore
    const userDoc = await db.collection('Users').doc(userId).get();
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'User not found');
    }

    const userData = userDoc.data();
    const userEmail = context.auth.token.email || userData.email;
    const userName = userData.username || 'FocusFuel User';

    // Check if user already has an active subscription
    if (userData.subscriptionStatus === 'premium' && userData.razorpaySubscriptionId) {
      // Verify if subscription is actually active in Razorpay
      try {
        const existingSubscription = await razorpay.subscriptions.fetch(userData.razorpaySubscriptionId);
        if (existingSubscription.status === 'active' || existingSubscription.status === 'authenticated') {
          throw new functions.https.HttpsError('already-exists', 'User already has an active subscription');
        }
      } catch (err) {
        console.log('Existing subscription check failed, proceeding with new subscription:', err.message);
      }
    }

    // Step 1: Create or fetch Razorpay customer
    let customerId = userData.razorpayCustomerId;

    if (!customerId) {
      const customer = await razorpay.customers.create({
        name: userName,
        email: userEmail,
        fail_existing: 0,  // Don't fail if customer already exists
        notes: {
          userId: userId,
          source: 'focusfuel_app'
        }
      });
      customerId = customer.id;

      // Save customer ID to Firestore
      await db.collection('Users').doc(userId).update({
        razorpayCustomerId: customerId
      });

      console.log(`Created Razorpay customer: ${customerId} for user: ${userId}`);
    }

    // Step 2: Create subscription
    const subscriptionData = {
      plan_id: planId,
      customer_id: customerId,
      quantity: 1,
      total_count: data.totalCount || undefined,  // undefined = perpetual subscription
      customer_notify: 1,  // Send email notifications
      notes: {
        userId: userId,
        username: userName
      },
      notify_info: {
        notify_email: userEmail
      }
    };

    const subscription = await razorpay.subscriptions.create(subscriptionData);

    // Step 3: Log subscription creation
    await db.collection('subscription_logs').add({
      userId: userId,
      subscriptionId: subscription.id,
      customerId: customerId,
      planId: planId,
      status: 'created',
      amount: subscription.plan_id ? 'from_plan' : 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      razorpayData: {
        subscriptionStatus: subscription.status,
        startAt: subscription.start_at,
        endAt: subscription.end_at,
        authAttempts: subscription.auth_attempts
      }
    });

    // Step 4: Update user document with subscription details
    await db.collection('Users').doc(userId).update({
      razorpaySubscriptionId: subscription.id,
      subscriptionStatus: 'pending_payment',  // Will be updated to 'premium' after first payment
      subscriptionPlanId: planId,
      subscriptionCreatedAt: admin.firestore.FieldValue.serverTimestamp(),
      subscriptionStartDate: subscription.start_at ? new Date(subscription.start_at * 1000) : null,
      subscriptionEndDate: subscription.end_at ? new Date(subscription.end_at * 1000) : null,
    });

    console.log(`Created subscription ${subscription.id} for user ${userId}`);

    // Return subscription details to client
    return {
      subscriptionId: subscription.id,
      customerId: customerId,
      status: subscription.status,
      shortUrl: subscription.short_url,  // Payment link if provided
      // For standard checkout flow, no order ID is returned
      // The subscription ID is used to authenticate payment
    };

  } catch (error) {
    console.error('Error creating Razorpay subscription:', error);

    // Log error
    await db.collection('subscription_logs').add({
      userId: userId,
      error: error.message,
      errorCode: error.error?.code,
      status: 'error',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    throw new functions.https.HttpsError(
      'internal',
      `Unable to create subscription: ${error.message}`
    );
  }
});
