const { onSchedule } = require("firebase-functions/v2/scheduler");
const { NotificationOrchestrator } = require("../agents/orchestrator");
const { getUserProfile } = require("../utils/getUserProfile");
const { admin } = require("../utils/firebase");

// Firestore DB instance for the active Firebase project (android/app/google-services.json)
const db = admin.firestore();

// Helper function to get time context
function getTimeContext(userData) {
    // Date object in PDT/PST timezone
    const now = new Date();
    const pstOptions = { timeZone: "America/Los_Angeles" };
    const pstTime = new Date(now.toLocaleString("en-US", pstOptions));

    return {
        currentTime: pstTime.toLocaleString("en-US"), // Readable time string
        dayOfWeek: pstTime.toLocaleDateString('en-US', {
            weekday: 'long',
            timeZone: "America/Los_Angeles"
        }),
        currentHour: pstTime.getHours(), // agents to know what time it is
        lastNotificationType: userData.lastNotificationType || "none"
    };
}

async function generateSmartNotification(userProfile, timeContext, openaiApiKey) {
    try {
        console.log(`Profile: ${userProfile.primaryInterests?.join(", ")} | Goal: ${userProfile.primaryGoal}`);

        // Initialize LangChain orchestrator
        const orchestrator = new NotificationOrchestrator(openaiApiKey);

        // Generate smart notification
        const result = await orchestrator.generateSmartNotification(userProfile, timeContext);

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
            schedule: "0 9-23 * * *",
            secrets: ["OPENAI_API_KEY"],
            timeZone: "America/Los_Angeles",
        },
        async () => {
            const openaiApiKey = process.env.OPENAI_API_KEY;

            if (!openaiApiKey) {
                console.log("OpenAI API key not found");
            }

            // Fetch all active users from Firestore
            const usersSnapshot = await db.collection("Users").where("isActive", "==", true).get();

            // Iterating through each user document
            for (const doc of usersSnapshot.docs) {
                const uid = doc.id;                 // dynamic userId
                const data = doc.data();
                const token = data.fcmToken;        // FCM token here

                if (!token) {
                    console.warn(`No FCM token for user ${uid}`);
                    continue;
                }

                try {
                    const userProfile = await getUserProfile(uid);      // User profile from utils/getUserProfile.js
                    const timeContext = getTimeContext(data);

                    console.log(`${userProfile.username}'s Profile with interests ${userProfile.primaryInterests?.join(", ")} | Goal: ${userProfile.primaryGoal}`);
                    console.log(`Current time context fetched : ${timeContext.currentTime}, Day: ${timeContext.dayOfWeek}, Hour: ${timeContext.currentHour}`);

                    const notificationResult = await generateSmartNotification(userProfile, timeContext, openaiApiKey);
                    console.log(`Notification result for user ${userProfile.username}:`, notificationResult);

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
                        console.log(`Parsed notification for user ${userProfile.username}:`, parsedNotification);

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
                                click_action: 'FLUTTER_NOTIFICATION_CLICK',   // deep-link guarantee
                            }
                        },
                        notification: {
                            title: notificationTitle,
                            body: notificationBody
                        },
                        data: {
                            deep_link: "/chat",
                        }
                    };

                    console.log("Notification message that to be sent is ", message);

                    // sending the notification to FCM servers, remote message listeners are set up in the main.dart
                    await admin.messaging().send(message);
                } catch (err) {
                    console.error("FCM send error:", err.message);
                }
            }
        }
    )
};

// Helper function to save notification in Notifications collection and 
// also save notification as initial conversation meassage in Conversations collection
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