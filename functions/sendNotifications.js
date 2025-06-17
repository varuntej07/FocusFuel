const {onSchedule} = require("firebase-functions/v2/scheduler");
const { buildPrompt } = require("./utils/promptTemplates");
const { callOpenAI } = require("./utils/openai");

const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();

const todayKey = () =>
  new Intl.DateTimeFormat("en-CA", { timeZone: "America/Los_Angeles" }).format(new Date());

const DEFAULT_GOAL = "Work hard, stay hard, no excuses, no shortcuts";

// Helper function to get user focus
async function getUserFocus(uid) {
    const userDoc = await db.doc(`Users/${uid}`).get();
    return userDoc.data()?.currentFocus || DEFAULT_GOAL;
}

// Helper function to check if pack needs refresh
async function shouldRefreshPack(uid, currentFocus) {
    const packRef = db.doc(`NotificationPacks/${todayKey()}`);
    const packSnapshot = await packRef.get();

    if (!packSnapshot.exists) return true;

    const packData = packSnapshot.data();
    return !packData.messages?.length || packData.onFocus !== currentFocus;
}

async function generateGptResponse(uid, focus) {
    try {
        const response = await callOpenAI({
            model: "gpt-4o",
            messages: [
                { role: "system", content: "You are a expert productivity coach." },
                { role: "user", content: buildPrompt(focus) }
            ],
            temperature: 0.9
        });

        const rawResponse = response.data.choices[0].message.content.trim();

        let parsedResponse;
        try {
            parsedResponse = JSON.parse(rawResponse);
        } catch (e) {
            console.error("GPT did not return valid JSON:", rawResponse);
            return;
        }

        if (!Array.isArray(parsedResponse) || parsedResponse.length !== 30) {
            console.error("GPT returned wrong shape:", parsedResponse.length);
        }

        console.log(`Refilled notificationPack with ${parsedResponse.length} messages`);
        await saveNotificationPackToFirestore(uid, parsedResponse, focus);

        return parsedResponse; // Return the parsed pack of messages

    } catch (err) {
        console.error("OpenAI error:", err.message);
        return "You're slacking. Wtf? Check your OpenAI API key and try again!";
    }
}

async function getRandomMessage(uid) {
    const focus = await getUserFocus(uid);

    // Check if we need to refresh the pack
    if (await shouldRefreshPack(uid, focus)) {
        console.log("Refilling notificationPack");
        const newPack = await generateGptResponse(uid, focus);
        if (!newPack) {
            return "Error generating new messages. Please try again later.";
        }
    }

    const packRef = db.doc(`NotificationPacks/${todayKey()}`);
    const packSnapshot = await packRef.get();
    const pack = packSnapshot.exists ? packSnapshot.data().messages : [];

    if (!pack.length) {
        console.log("No messages available in notificationPack");
        return "No messages available.";
    }

    const idx = Math.floor(Math.random() * pack.length);
    const [msg] = pack.splice(idx, 1); // Modify local copy

    await packRef.update({ messages: pack }); // Update Firestore

    return msg;
}

// entry point is here to send scheduled notifications
module.exports = {
    sendScheduledNotification: onSchedule(
        {
            schedule: "*/30 9-22 * * *",
            secrets: ["OPENAI_API_KEY"],
            timeZone: "America/Los_Angeles",
        },
        async () => {
            const usersSnapshot = await db.collection("Users").where("isActive", "==", true).get();

            // Iterating through each user document
            for (const doc of usersSnapshot.docs) {
                const uid = doc.id;                 // dynamic userId
                const data = doc.data();
                const token = data.fcmToken;        // FCM token here
                const focus = data.currentFocus || DEFAULT_GOAL;
                const weeklyGoal = data.weeklyGoal;
                // const lastNotificationTime = data.lastNotificationTime?.toDate();
                // const notificationInterval = data.notificationInterval || 30;

                if (!token) {
                    console.warn(`No FCM token for user ${uid}`);
                    continue;
                }

                // getting a random message from the pack
                const notificationBody = await getRandomMessage(uid);

               // Create notification and conversation together
               await saveNotificationAndCreateConversation(uid, notificationBody, focus, weeklyGoal);

               // Update user's lastNotificationTime
               await db.collection('Users').doc(uid).update({
                   lastNotificationTime: admin.firestore.FieldValue.serverTimestamp()
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
                        title: 'Stay hard!',
                        body: notificationBody
                    },
                    data: {
                        deep_link: "/chat",
                    }
                };

                try {  // sending the notification to FCM servers
                    console.log("Notification message that to be sent is ", message);
                    console.log(`Notification Sent to ${uid}: ${notificationBody.slice(0, 40)}…`);

                    const result = await admin.messaging().send(message);
                    console.log("Notification sent:", result);
                } catch (err) {
                    console.error("FCM send error:", err.message);
                }
            }
        }
    )
};

async function saveNotificationAndCreateConversation(userId, message, focus, weeklyGoal) {
    try {
        const notificationRef = await db.collection("Notifications").add({
            userId: userId,
            message: message,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            clicked: false,
            type: focus
        });

        // Create conversation linked to notification
        const conversationRef = await db.collection('Conversations').add({
            userId: userId,
            startedAt: admin.firestore.FieldValue.serverTimestamp(),
            notificationId: notificationRef.id,
            userFocus: focus,
            weeklyGoal: weeklyGoal,
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


async function saveNotificationPackToFirestore(userId, pack, focus){
    try {
        const packData = {
            author: "GPT-4o",
            receivedAt: admin.firestore.FieldValue.serverTimestamp(),
            onFocus: focus,
            messages: pack,
        }
        await db.doc(`NotificationPacks/${todayKey()}`).set(packData);
    } catch(err) {
        console.error("Error saving GPT notification pack to Firestore:", err);
    }
}