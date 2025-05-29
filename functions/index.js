const {onSchedule} = require("firebase-functions/v2/scheduler");
const axios = require("axios");
const { buildPrompt } = require("./promptTemplates");

const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();

const OPENAI_API_KEY = process.env.OPENAI_API_KEY;

const todayKey = () => new Date().toISOString().slice(0, 10); // "2025-05-28"

// should be dynamically updated
const DEFAULT_GOAL = "Mastering Prompt Engineering";

async function generateGptResponse(uid, goal) {
    try {
        const response = await axios.post("https://api.openai.com/v1/chat/completions",
            {
                model: "gpt-3.5-turbo",
                messages: [
                    { role: "system", content: "You are a expert productivity coach." },
                    { role: "user", content: buildPrompt(goal) }
                ],
                temperature: 0.9
            },
            {
                headers: {
                    "Content-Type": "application/json",
                    "Authorization": "Bearer " + OPENAI_API_KEY,
                },
            },
        );

        const rawResponse = response.data.choices[0].message.content.trim();

        let parsedResponse;
        try {
            parsedResponse = JSON.parse(rawResponse);
        } catch (e) {
            console.error("GPT did not return valid JSON:", rawResponse);
        }

        if (!Array.isArray(parsedResponse) || parsedResponse.length !== 30) {
            console.error("GPT returned wrong shape:", parsedResponse.length);
        }

        console.log(`Refilled notificationPack with ${parsedResponse.length} messages`);
        await saveNotificationPackToFirestore(uid, parsedResponse, goal);
        return parsedResponse; // Return the parsed pack of messages
    } catch (err) {
        console.error("OpenAI error:", err.message);
        return "You're slacking. Wtf? Check your OpenAI API key and try again!";
    }
}

// Grabs a random msg, remove it from the pack, refill if empty
async function getRandomMessage(uid) {
    const packRef = db.doc(`Users/${uid}/NotificationPacks/${todayKey()}`);
    let packSnapshot = await packRef.get();
    let pack = packSnapshot.exists ? packSnapshot.data().messages : [];

    if (!pack.length) {
        console.log("Refilling notificationPack");
        const userDoc = await db.doc(`Users/${uid}`).get();
        const goal = userDoc.data()?.goal || DEFAULT_GOAL; // Fetching dynamic goal

        await generateGptResponse(uid, goal);
        await new Promise(resolve => setTimeout(resolve, 1000)); // Ensuring write completes
        packSnapshot = await packRef.get(); // Refresh snapshot
        pack = packSnapshot.data().messages || [];
    }

    if (!pack.length) {
        return "No messages available.";
    }

    const idx = Math.floor(Math.random() * pack.length);
    const [msg] = pack.splice(idx, 1); // Modify local copy
    await packRef.update({ messages: pack }); // Update Firestore
    return msg;
}

exports.sendScheduledNotification = onSchedule(
    {
        schedule: "*/30 7-23 * * *",
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

          if (!token) {
            console.warn(`No FCM token for user ${uid}`);
            continue;
          }

            const notificationBody = await getRandomMessage(uid);
            await saveNotificationToFirestore(uid, notificationBody);

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
                console.log("Sent to ${uid}: ${notificationBody.slice(0, 40)}…");

                const result = await admin.messaging().send(message);
                console.log("Notification sent:", result);
            } catch (err) {
            console.error("FCM send error:", err.message);
            }
        }
    }
);

async function saveNotificationToFirestore(userId, message){
    try {
        const messageData = {
            role: "Assistant",
            content: message,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),        // FieldValue class is static member of admin.firestore, not an instance of Firestore(db->line 7)
            goal: "",
        }
        const messageRef = db.collection("Users").doc(userId).collection("NotificationMessages");
        await messageRef.add(messageData);
    } catch(err){
        console.error("Error saving GPT notification to Firestore:", err);
    }
}

async function saveNotificationPackToFirestore(userId, pack, goal){
    try {
        const packData = {
            author: "GPT-4o",
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            goal: `${goal}`,
            messages: pack,
        }
        await db.doc(`Users/${userId}/NotificationPacks/${todayKey()}`).set(packData);
        } catch(err){
        console.error("Error saving GPT notification pack to Firestore:", err);
    }
}