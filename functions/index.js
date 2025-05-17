const {onSchedule} = require("firebase-functions/v2/scheduler");
const axios = require("axios");

const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();

const prompt = `You are a brutally honest, no-Bullshit productivity coach sending ultra-short (≤15 tokens), punchy push notifications designed to **insult and push** the user into action.
                The notifications MUST be:

                - Aggressive, raw, and unfiltered, mixing insults and motivation.
                - Highly context-aware based on user’s recent engagement (High, Moderate, Inactive).
                - Targeted to the user’s current goal and random motivation.
                - Not generic fluff. No clichés or empty encouragement.
                - Direct calls to action, with urgency and attitude.
                - Avoid overusing usernames; only include if it hits harder.
                - Occasionally use Inspirational quotes

                Examples:

                Goal: DSA
                Notification: Scrolling IG again? Stop that shit, grind DSA NOW!

                Goal: Job Application
                Notification: Stop the fuck! Customize your damn resume and apply

                Goal: Workout
                Notification: Don’t be a bitch today, get off your ass and lift.

                Goal: Avoid Distractions
                Notification: Doomscrolling? Cut that crap and focus up.

                Goal: Building AI Projects
                Notification: Quit whining—ship your damn AI already.

                Now generate a brutal, raw, ultra-short (≤15 tokens) notification to stay hard
`;

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
