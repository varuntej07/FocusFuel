const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');

const db = admin.firestore();

// Razorpay webhook secret (set via: firebase functions:config:set razorpay.webhook_secret="xxx")
const webhookSecret = functions.config().razorpay?.webhook_secret;

/**
 * Razorpay webhook endpoint
 * Handles subscription lifecycle events
 *
 * Webhook URL: https://<region>-<project-id>.cloudfunctions.net/razorpayWebhook
 *
 * Events handled:
 * - subscription.authenticated: User completed payment authorization
 * - subscription.activated: Subscription became active
 * - subscription.charged: Recurring payment succeeded
 * - subscription.completed: Subscription completed all billing cycles
 * - subscription.pending: Subscription pending payment
 * - subscription.halted: Payment failed, subscription paused
 * - subscription.cancelled: User/admin cancelled subscription
 * - subscription.paused: Admin paused subscription
 * - subscription.resumed: Admin resumed subscription
 * - payment.failed: Payment attempt failed
 */
exports.razorpayWebhook = functions.https.onRequest(async (req, res) => {
  const webhookSignature = req.headers['x-razorpay-signature'];
  const webhookBody = req.rawBody.toString();

  // Step 1: Verify webhook signature
  if (!webhookSecret) {
    console.error('Razorpay webhook secret not configured');
    return res.status(500).send('Webhook secret not configured');
  }

  try {
    const expectedSignature = crypto
      .createHmac('sha256', webhookSecret)
      .update(webhookBody)
      .digest('hex');

    if (expectedSignature !== webhookSignature) {
      console.error('Webhook signature verification failed');
      return res.status(400).send('Invalid signature');
    }
  } catch (err) {
    console.error('Error verifying webhook signature:', err);
    return res.status(400).send('Signature verification failed');
  }

  // Step 2: Parse webhook payload
  let event;
  try {
    event = JSON.parse(webhookBody);
  } catch (err) {
    console.error('Invalid JSON payload:', err);
    return res.status(400).send('Invalid JSON');
  }

  const eventType = event.event;
  const payload = event.payload.subscription?.entity || event.payload.payment?.entity;

  console.log(`Received Razorpay webhook: ${eventType}`);
  console.log('Payload:', JSON.stringify(payload, null, 2));

  // Step 3: Handle event
  try {
    switch (eventType) {
      case 'subscription.authenticated':
        await handleSubscriptionAuthenticated(payload);
        break;

      case 'subscription.activated':
        await handleSubscriptionActivated(payload);
        break;

      case 'subscription.charged':
        await handleSubscriptionCharged(payload);
        break;

      case 'subscription.completed':
        await handleSubscriptionCompleted(payload);
        break;

      case 'subscription.pending':
        await handleSubscriptionPending(payload);
        break;

      case 'subscription.halted':
        await handleSubscriptionHalted(payload);
        break;

      case 'subscription.cancelled':
        await handleSubscriptionCancelled(payload);
        break;

      case 'subscription.paused':
        await handleSubscriptionPaused(payload);
        break;

      case 'subscription.resumed':
        await handleSubscriptionResumed(payload);
        break;

      case 'payment.failed':
        await handlePaymentFailed(payload);
        break;

      default:
        console.log(`Unhandled event type: ${eventType}`);
    }

    // Acknowledge receipt
    res.json({ received: true, event: eventType });
  } catch (error) {
    console.error('Error processing webhook:', error);
    res.status(500).json({ error: 'Webhook processing failed' });
  }
});

// ===== Event Handlers =====

/**
 * Subscription authenticated - User completed payment authorization
 */
async function handleSubscriptionAuthenticated(subscription) {
  console.log('Subscription authenticated:', subscription.id);

  const userId = subscription.notes?.userId;
  if (!userId) {
    console.error('No userId in subscription notes');
    return;
  }

  await db.collection('Users').doc(userId).update({
    subscriptionStatus: 'authenticated',
    razorpaySubscriptionStatus: subscription.status,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await logSubscriptionEvent(userId, subscription.id, 'authenticated', subscription);
}

/**
 * Subscription activated - First payment succeeded, subscription is now active
 */
async function handleSubscriptionActivated(subscription) {
  console.log('Subscription activated:', subscription.id);

  const userId = subscription.notes?.userId;
  if (!userId) {
    console.error('No userId in subscription notes');
    return;
  }

  await db.collection('Users').doc(userId).update({
    subscriptionStatus: 'premium',
    isSubscribed: true,
    razorpaySubscriptionStatus: subscription.status,
    subscriptionStartDate: subscription.current_start ? new Date(subscription.current_start * 1000) : admin.firestore.FieldValue.serverTimestamp(),
    subscriptionEndDate: subscription.current_end ? new Date(subscription.current_end * 1000) : null,
    nextBillingDate: subscription.charge_at ? new Date(subscription.charge_at * 1000) : null,
    lastPaymentDate: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await logSubscriptionEvent(userId, subscription.id, 'activated', subscription);

  console.log(`User ${userId} upgraded to premium via subscription ${subscription.id}`);
}

/**
 * Subscription charged - Recurring payment succeeded
 */
async function handleSubscriptionCharged(subscription) {
  console.log('Subscription charged:', subscription.id);

  const userId = subscription.notes?.userId;
  if (!userId) {
    console.error('No userId in subscription notes');
    return;
  }

  // Update next billing date and last payment
  await db.collection('Users').doc(userId).update({
    subscriptionStatus: 'premium',
    isSubscribed: true,
    razorpaySubscriptionStatus: subscription.status,
    lastPaymentDate: admin.firestore.FieldValue.serverTimestamp(),
    nextBillingDate: subscription.charge_at ? new Date(subscription.charge_at * 1000) : null,
    subscriptionEndDate: subscription.current_end ? new Date(subscription.current_end * 1000) : null,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await logSubscriptionEvent(userId, subscription.id, 'charged', subscription);

  console.log(`Recurring payment succeeded for user ${userId}`);
}

/**
 * Subscription completed - All billing cycles completed
 */
async function handleSubscriptionCompleted(subscription) {
  console.log('Subscription completed:', subscription.id);

  const userId = subscription.notes?.userId;
  if (!userId) {
    console.error('No userId in subscription notes');
    return;
  }

  // Mark subscription as expired
  await db.collection('Users').doc(userId).update({
    subscriptionStatus: 'expired',
    isSubscribed: false,
    razorpaySubscriptionStatus: subscription.status,
    subscriptionEndDate: new Date(subscription.end_at * 1000),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await logSubscriptionEvent(userId, subscription.id, 'completed', subscription);

  console.log(`Subscription completed for user ${userId}`);
}

/**
 * Subscription pending - Awaiting payment
 */
async function handleSubscriptionPending(subscription) {
  console.log('Subscription pending:', subscription.id);

  const userId = subscription.notes?.userId;
  if (!userId) {
    console.error('No userId in subscription notes');
    return;
  }

  await db.collection('Users').doc(userId).update({
    subscriptionStatus: 'pending_payment',
    razorpaySubscriptionStatus: subscription.status,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await logSubscriptionEvent(userId, subscription.id, 'pending', subscription);
}

/**
 * Subscription halted - Payment failed, auto-paused by Razorpay
 */
async function handleSubscriptionHalted(subscription) {
  console.log('Subscription halted:', subscription.id);

  const userId = subscription.notes?.userId;
  if (!userId) {
    console.error('No userId in subscription notes');
    return;
  }

  // Grace period: Keep premium for 3 days
  const gracePeriodEnd = new Date();
  gracePeriodEnd.setDate(gracePeriodEnd.getDate() + 3);

  await db.collection('Users').doc(userId).update({
    subscriptionStatus: 'payment_failed',
    isSubscribed: false,  // Revoke access immediately or after grace period
    razorpaySubscriptionStatus: subscription.status,
    gracePeriodEnd: gracePeriodEnd,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await logSubscriptionEvent(userId, subscription.id, 'halted', subscription);

  console.log(`Subscription halted for user ${userId} due to payment failure`);
}

/**
 * Subscription cancelled - User or admin cancelled
 */
async function handleSubscriptionCancelled(subscription) {
  console.log('Subscription cancelled:', subscription.id);

  const userId = subscription.notes?.userId;
  if (!userId) {
    console.error('No userId in subscription notes');
    return;
  }

  // Keep access until current period ends
  const currentEnd = subscription.current_end ? new Date(subscription.current_end * 1000) : new Date();

  await db.collection('Users').doc(userId).update({
    subscriptionStatus: 'cancelled',
    isSubscribed: false,
    razorpaySubscriptionStatus: subscription.status,
    subscriptionEndDate: currentEnd,
    cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await logSubscriptionEvent(userId, subscription.id, 'cancelled', subscription);

  console.log(`Subscription cancelled for user ${userId}`);
}

/**
 * Subscription paused - Admin paused
 */
async function handleSubscriptionPaused(subscription) {
  console.log('Subscription paused:', subscription.id);

  const userId = subscription.notes?.userId;
  if (!userId) {
    console.error('No userId in subscription notes');
    return;
  }

  await db.collection('Users').doc(userId).update({
    subscriptionStatus: 'paused',
    isSubscribed: false,
    razorpaySubscriptionStatus: subscription.status,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await logSubscriptionEvent(userId, subscription.id, 'paused', subscription);
}

/**
 * Subscription resumed - Admin resumed
 */
async function handleSubscriptionResumed(subscription) {
  console.log('Subscription resumed:', subscription.id);

  const userId = subscription.notes?.userId;
  if (!userId) {
    console.error('No userId in subscription notes');
    return;
  }

  await db.collection('Users').doc(userId).update({
    subscriptionStatus: 'premium',
    isSubscribed: true,
    razorpaySubscriptionStatus: subscription.status,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await logSubscriptionEvent(userId, subscription.id, 'resumed', subscription);
}

/**
 * Payment failed
 */
async function handlePaymentFailed(payment) {
  console.log('Payment failed:', payment.id);

  // Extract subscription ID from payment description or notes
  const subscriptionId = payment.subscription_id;
  if (!subscriptionId) {
    console.log('No subscription ID in payment');
    return;
  }

  // Find user by subscription ID
  const usersQuery = await db.collection('Users')
    .where('razorpaySubscriptionId', '==', subscriptionId)
    .limit(1)
    .get();

  if (usersQuery.empty) {
    console.error('User not found for subscription:', subscriptionId);
    return;
  }

  const userId = usersQuery.docs[0].id;

  await db.collection('Users').doc(userId).update({
    lastPaymentStatus: 'failed',
    lastPaymentError: payment.error_description || 'Payment failed',
    lastPaymentFailedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await db.collection('subscription_logs').add({
    userId: userId,
    subscriptionId: subscriptionId,
    paymentId: payment.id,
    event: 'payment_failed',
    error: payment.error_description,
    amount: payment.amount,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log(`Payment failed for user ${userId}, subscription ${subscriptionId}`);
}

/**
 * Log subscription event
 */
async function logSubscriptionEvent(userId, subscriptionId, event, subscriptionData) {
  await db.collection('subscription_logs').add({
    userId: userId,
    subscriptionId: subscriptionId,
    event: event,
    status: subscriptionData.status,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    razorpayData: {
      currentStart: subscriptionData.current_start,
      currentEnd: subscriptionData.current_end,
      chargeAt: subscriptionData.charge_at,
      endedAt: subscriptionData.ended_at,
      paidCount: subscriptionData.paid_count,
      totalCount: subscriptionData.total_count,
    }
  });
}
