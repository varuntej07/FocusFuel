const {onSchedule} = require("firebase-functions/v2/scheduler");
const axios = require("axios");

const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();

const prompt = `You are my razor-sharp inner coach.
                Drop a brutal, 15-word zinger to kill laziness, fuel deep work,
                and push me closer to AI mastery. Be bold, witty, and real.
                Skip clichés. Deliver maximum impact, minimum words.
                Now send notification style responses to tasks like:
                Building resume, editing resume, writing resume, finishing focus fuel app
                No other explanation, no other text. Just the notification response`;

const OPENAI_API_KEY = process.env.OPENAI_API_KEY;

async function gptResponse() {
  try {
    const response = await axios.post("https://api.openai.com/v1/chat/completions",
        {
          model: "gpt-3.5-turbo",
          messages: [
            {role: "system", content: "You are a productivity assistant."},
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
    return response.data.choices[0].message.content.trim();
  } catch (err) {
    console.error("OpenAI request failed:", err.response?.data || err);
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
  console.log("🔑 OPENAI_API_KEY is set? ", !!OPENAI_API_KEY);
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
      body: await gptResponse(),
    },
  };
  try {
    const result = await admin.messaging().send(message);
    console.log("Notification sent:", result);
  } catch (err) {
    console.error("FCM send error:", err.message);
  }
});
