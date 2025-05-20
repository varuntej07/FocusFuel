const {onSchedule} = require("firebase-functions/v2/scheduler");
const axios = require("axios");

const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();

const prompt = `You are a brutally honest, no-bullshit productivity coach sending ultra-short (≤15 tokens), punchy push notifications designed to **insult and push** the user into action. Each notification MUST:

                - Be aggressive, raw, and unfiltered, mixing insults and motivation.
                - Tie directly to the user’s current goal and random motivation—make it personal.
                - Pack a clear, actionable command (e.g., “Run now!”).
                - Be fresh—never repeat phrases, structures, or examples.
                - Skip fluff, clichés, or weak praise.
                - Use the username only if it stings harder.
                - Rarely (max once every 10 notifications) twist a quote to fit the brutal tone.

                **Examples:**

                - **Goal**: DSA,
                  Notification: DSA king, don’t choke now. code! code! and code!!

                - **Goal**: Job Application,
                  Notification: Resume’s trash! fix it and send it now.

                - **Goal**: Workout,
                  Notification: Lazy ass, hit the gym already.

                - **Goal**: Avoid Distractions,
                  Notification: Distraction-free? Prove it, work ya ass off.

                - **Goal**: Building AI Projects,
                  Notification: AI’s a mess. soft, stop crying and start building!

                - **Goal**: Writing,
                  Notification: Pen’s dry, loser. write now!!

                **Key**: Every notification must be original, avoiding past outputs or examples. Lean into the raw tone without going soft.

                Now generate a brutal, raw, ultra-short (≤15 tokens) notification to stay hard, Just return the notification no other stuff.
`;

const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
let api_response;

async function generateGptResponse() {
  try {
    const response = await axios.post("https://api.openai.com/v1/chat/completions",
        {
          model: "gpt-3.5-turbo",
          messages: [
            {role: "system", content: "You are a expert productivity coach."},
            {role: "user", content: prompt},
          ],
          temperature: 0.7
        },
        {
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer " + OPENAI_API_KEY,
          },
        },
    );
    api_response = response.data.choices[0].message.content.trim();

    const uid = "O4e733SdzphXPpds73NXL5np1ZA2";
    await saveNotificationToFirestore(uid, api_response);

    return api_response;
  } catch (err) {
    return "You're slacking. Wtf? Check your OpenAI API key and try again!";
  }
}

exports.sendScheduledNotification = onSchedule(
   {
       schedule: "*/30 * * * *",
       secrets: ["OPENAI_API_KEY"],
       timeZone: "America/Los_Angeles",
     },
  async () => {
  const uid = "O4e733SdzphXPpds73NXL5np1ZA2";
  const snap = await db.collection("users").doc(uid).get();
  if (!snap.exists || !snap.data().fcmToken) {
        console.error("No FCM token found for user:", uid);
        return;
      }
  const token = snap.data().fcmToken;
  const message = {
    token: token,
    notification: {
      title: "Focus dawg!",
      body: await generateGptResponse(),
    },
  };
  try {
    const result = await admin.messaging().send(message);
    console.log("Notification sent:", result);
  } catch (err) {
    console.error("FCM send error:", err.message);
  }
});

async function saveNotificationToFirestore(userId, message){
    try {
        const messageData = {
            role: "Assistant",
            content: message,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),        // FieldValue class is static member of admin.firestore, not an instance of Firestore(db->line 7)
            goal: "",
        }
        const messageRef = db.collection("users").doc(userId).collection("messages");
        await messageRef.add(messageData);
    } catch(err){
        console.error("Error saving GPT notification to Firestore:", err);
    }
}
