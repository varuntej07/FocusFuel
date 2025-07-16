const { onSchedule } = require("firebase-functions/v2/scheduler");
const { NotificationOrchestrator } = require("../agents/orchestrator");
const { getUserProfile } = require("../utils/getUserProfile");
const { admin } = require("../utils/firebase");
const { getTimeContext } = require("../utils/getTimeContext");
const { DateTime } = require("luxon");

// Firestore DB instance for the active Firebase project (android/app/google-services.json)
const db = admin.firestore();

// Gets last x notifications for a user
async function getRecentNotifications(userId, limit = 3) {
    try {
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

// entry point is here to send scheduled notifications
module.exports = {
    sendScheduledNotification: onSchedule(
        {
            schedule: "0 * * * *",      // running every hour as t's not possible to schedule a onSchedule function with a dynamic user timezone.
            secrets: ["OPENAI_API_KEY"],
            timeZone: "America/Los_Angeles",
            memory: "512MB",
            timeout: 540
        },
        async () => {

            // Fetch all active users from Firestore
            const usersSnapshot = await db.collection("Users").where("isActive", "==", true).get();

            // Iterating through each user document
            for (const doc of usersSnapshot.docs) {
                const uid = doc.id;                 // dynamic userId
                const data = doc.data();
                const token = data.fcmToken;        // FCM token here
                const userTimezone = data.timezone || "America/Los_Angeles";    // User's timezone, default to PST

                if (!token) {
                    console.warn(`No FCM token for user ${uid}`);
                    continue;
                }

                // Fetch time context based on user's timezone using Luxon which is a powerful JS date/time library
                const userTime = DateTime.now().setZone(userTimezone);
                const localHour = userTime.hour;
                console.log(`Local hour for user ${data.username} in timezone ${userTimezone} is ${localHour}`);

                if (localHour >= 9 && localHour <= 23){
                    try {
                        const userProfile = await getUserProfile(uid);      // User profile from utils/getUserProfile.js
                        const timeContext = getTimeContext(data);

                        console.log(`${userProfile.username}'s Profile with interests ${userProfile.primaryInterests?.join(", ")}`);
                        console.log(`Current time context fetched : ${timeContext.currentTime}, Day: ${timeContext.dayOfWeek}, Hour: ${timeContext.currentHour}`);

                        const recentNotifications = await getRecentNotifications(uid);
                        console.log(`Fetched ${recentNotifications.length} recent notifications for duplicate prevention for ${data.username}`);
                        
                        const notificationResult = await generateSmartNotification(userProfile, timeContext, openaiApiKey, recentNotifications);

                        if (!notificationResult || !notificationResult.message) {
                            console.error(`Failed to generate notification for user ${userProfile.username} with ${uid}`);
                            continue; // Skip this user
                        }

                        let parsedNotification;
                        try {
                            // Extract JSON from response if it contains extra text
                            const jsonMatch = notificationResult.message.match(/\{.*\}/);
                            const jsonString = jsonMatch ? jsonMatch[0] : notificationResult.message;

                            parsedNotification = JSON.parse(jsonString);

                        } catch (e) {
                            console.log(`JSON parse failed for user ${userProfile.username}: ${notificationResult.message}`);
                            parsedNotification = { title: notificationResult.title, content: notificationResult.message };
                        }

                        const notificationTitle = parsedNotification.title || "Fuck again!";
                        const notificationBody = parsedNotification.content || notificationResult.message;

                        const agentType = notificationResult.agentType;

                        // Create notification and conversation
                        await saveNotificationAndCreateConversation(parsedNotification, userProfile);

                        // Update user's last notification info
                        await db.collection('Users').doc(uid).update({
                            lastNotificationTime: admin.firestore.FieldValue.serverTimestamp(),
                            lastNotificationType: agentType // Track if we used an agent
                        });

                        const message = {
                            token,
                            android: {
                                priority: 'high',
                                notification: {
                                    channel_id: 'focusfuel_channel',  // custom channel
                                }
                            },
                            notification: {
                                title: notificationTitle,
                                body: notificationBody
                            },
                            data: {
                                click_action: 'FLUTTER_NOTIFICATION_CLICK',
                                screen: 'chat',  // for Flutter routing
                            }
                        };

                        // sending the notification to FCM servers, remote message listeners are set up in the main.dart
                        await admin.messaging().send(message);
                    } catch (err) {
                        console.error("FCM send error:", err.message);
                    }
                 } else {
                     console.log(`Skipping notification for user ${uid} as local hour ${localHour} is outside 9-23 range`);
                 }
            }
        }
    )
};

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
            type: userProfile.currentFocus
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