const { onSchedule } = require("firebase-functions/v2/scheduler");
const { NotificationOrchestrator } = require("../agents/orchestrator");
const { getUserProfile } = require("../utils/getUserProfile");
const { admin } = require("../utils/firebase");
const { getTimeContext } = require("../utils/getTimeContext");
const { DateTime } = require("luxon");
const {sendFCMNotification} = require("./sendFCM");

// Firestore DB instance for the active Firebase project (android/app/google-services.json)
const db = admin.firestore();

// entry point is here to send scheduled notifications
module.exports = {
    sendScheduledNotification: onSchedule(
        {
            schedule: "0 * * * *",      // running every hour as it's not possible to set onSchedule function with a dynamic user timezone.
            secrets: ["OPENAI_API_KEY"],
            timeZone: "America/Los_Angeles",
            memory: "512MB",
            timeout: 540
        },
        async () => {

            const openaiApiKey = process.env.OPENAI_API_KEY;        // firebase secrets makes it available through this method

            if (!openaiApiKey) {
                console.log("Check ya OpenAI API key in firebase secrets as it seems to not configured");
            }

            // Fetch all active users from Firestore
            const usersSnapshot = await db.collection("Users").where("isActive", "==", true).get();

            // Iterating through each user document
            for (const doc of usersSnapshot.docs) {
                const uid = doc.id;                 // dynamic userId
                const data = doc.data();

                // Check if user should receive notification based on smart windows
                const shouldSend = await shouldSendNotificationNow(data);

                if (shouldSend.send) {
                    try {
                        await processUserNotification(uid, data, openaiApiKey, shouldSend.timeWindow);
                    } catch (err) {
                        console.error(`Error processing notification for user ${uid}:`, err.message);
                    }
                } else {
                    console.log(`Skipping user ${uid}: outside optimal time windows`);
                }
            }
        }
    )
};


async function shouldSendNotificationNow(userData) {
    const userTimezone = userData.timezone || "America/Los_Angeles";    // User's timezone, default to PST

    const userTime = DateTime.now().setZone(userTimezone);
    const localHour = userTime.hour;

   // allowed hours in alternating pattern
   const allowedHours = {
       morning: [9, 10, 12], // 10 AM, 12 PM
       afternoon: [15, 17], // 3 PM, 5 PM
       evening: [19, 21, 22, 23] // 7 PM, 9 PM, 11 PM
   };

   // Check if current hour is in any allowed time window
   const morningWindow = allowedHours.morning.includes(localHour);
   const afternoonWindow = allowedHours.afternoon.includes(localHour);
   const eveningWindow = allowedHours.evening.includes(localHour);

    if (!morningWindow && !afternoonWindow && !eveningWindow) {
        return { send: false };
    }

    // time window for context
    let timeWindow = 'general';

    if (morningWindow) timeWindow = 'morning';
    else if (afternoonWindow) timeWindow = 'afternoon';
    else if (eveningWindow) timeWindow = 'evening';

    return { send: true, timeWindow };
}

async function processUserNotification(uid, userData, openaiApiKey, timeWindow) {
    const userProfile = await getUserProfile(uid);
    const timeContext = getTimeContext(userData);

    console.log(`Processing ${timeWindow} notification for ${userProfile.username}`);

    const recentNotifications = await getRecentNotifications(uid);

    const orchestrator = new NotificationOrchestrator(openaiApiKey);
    const notificationResult = await orchestrator.generateSmartNotification(userProfile, timeContext, recentNotifications);

    // Parse and send notification
    let parsedNotification;
    try {
        const jsonMatch = notificationResult.notification.match(/\{.*\}/);
        const jsonString = jsonMatch ? jsonMatch[0] : notificationResult.notification;
        parsedNotification = JSON.parse(jsonString);
    } catch (e) {
        console.log(`JSON parse failed for user ${userProfile.username}: ${notificationResult}`);
        parsedNotification = {
            title: "Stay Hard",
            content: notificationResult
        };
    }

    // Save notification and create conversation in Firestore
    const saveResult = await saveNotificationAndCreateConversation(parsedNotification, userProfile);

    // send FCM notification with required params
    await sendFCMNotification(userData.fcmToken, parsedNotification, uid, saveResult.notificationId);

    // Update user's last notification info
    await db.collection('Users').doc(uid).update({
        lastNotificationTime: admin.firestore.FieldValue.serverTimestamp(),
        lastNotificationWindow: timeWindow,
        lastNotificationType: notificationResult.agentType,
    });

    console.log(`Sent ${notificationResult.agentType} notification to ${userProfile.username} during ${timeWindow} window`);
}

// Gets last x notifications for a user
async function getRecentNotifications(userId, limit = 3) {
    try {
        // Requires composite index, cuz of multiple filters - where + orderBy on different fields
        const recentNotifs = await db.collection("Notifications")
            .where("userId", "==", userId)
            .orderBy("timestamp", "desc")
            .limit(limit)
            .get();

        return recentNotifs.docs.map(doc => doc.data().message);
    } catch (error) {
        console.error("Error fetching recent notifications:", error);
        return [];
    }
}

async function generateSmartNotification(userProfile, timeContext, openaiApiKey, recentNotifications) {
    try {
        console.log(`Profile: ${userProfile.primaryInterests?.join(", ")} | Goal: ${userProfile.primaryGoal}`);

        // Initialize LangChain orchestrator
        const orchestrator = new NotificationOrchestrator(openaiApiKey);

        // Generate smart notification by passing essential params
        const result = await orchestrator.generateSmartNotification(userProfile, timeContext, recentNotifications);

        console.log(`Generated ${result.agentType} notification for user, ${userProfile.username}`);
        console.log("Notification content for passing to send", result.notification);
        return {
            message: result.notification,
            agentType: result.agentType
        };

    } catch (error) {
        console.error("LangChain error occurred while initiating the agent:", error);
        return {
            message: "Why the f!",
            agentType: "error_fallback"
        };
    }
}

// Helper function to save notification in Notifications collection and 
// also save notification as initial conversation message in Conversations collection
async function saveNotificationAndCreateConversation(message, userProfile) {
  
    try {
        // first save the notification to the Notifications collection
        const notificationRef = await db.collection("Notifications").add({
            userId: userProfile.uid,
            message: message,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            clicked: false,
            forFocus: userProfile.currentFocus
        });

        // Create conversation linked to notification
        const conversationRef = await db.collection('Conversations').add({
            userId: userProfile.uid,
            startedAt: admin.firestore.FieldValue.serverTimestamp(),
            notificationId: notificationRef.id,
            userFocus: userProfile.currentFocus,
            primaryGoal: userProfile.primaryGoal,
            status: 'active',
        });

        // Add initial assistant message to conversation
        await db.collection('Conversations')
            .doc(conversationRef.id)
            .collection('Messages')
            .add({
                content: message,
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
                role: 'assistant',
                isFirstMessage: true,
            });

        // Update conversation's lastMessageAt
        await db.collection('Conversations').doc(conversationRef.id).update({
            lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        return {
            notificationId: notificationRef.id,
            conversationId: conversationRef.id
        };

    } catch(err) {
        console.error("Error saving notification and creating conversation:", err);
        throw err;
    }
}