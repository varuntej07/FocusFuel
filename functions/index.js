const {onSchedule} = require("firebase-functions/v2/scheduler");
const axios = require("axios");

const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();

const prompt = `You are a brutally honest, no-bullshit productivity and performance coaching assistant sending mobile notifications for a real app.

                Each notification MUST:
                - Be raw, aggressive, and unfiltered.
                - Mix insults and motivation with *clear, click-worthy bait*.
                - Be under 30 tokens (mobile-friendly).
                - Include a **tempting hook or action**, like “Tap for the plan” or “I’ve got your fix.” etc.,

                NEVER:
                - Be vague, soft, or generic.
                - Reuse phrasing or themes from the examples.
                - Sound like it was written for everyone. Write like it’s for **one lazy bastard who needs to work hard**.

                These below are few examples for notification messages (don’t copy, don’t remix):
                1. Job boards are a trap. I’ve got the strategy recruiters don’t want you to know. You want results or rejection?
                2. Discipline ain’t sexy, but it’s the only reason legends eat while you beg. click me to stay hard
                3. You lifting or just posting about it? I’ve got raw, no-BS routines, meal hacks, and mental drills. Want to stop guessing?
                4. Tired? Perfect. Now we see who’s real. Don’t be a bitch today
                5. I got real AI project blueprints—CV, NLP, LLM stuff that actually gets you hired. You want GitHub links or stay basic?
                6. You’re not stuck. You’re just lazy. Move your ass or watch others pass you by.
                7. You think discipline is hard? Wait ‘til you try regret. I’ve got the blueprint out. Want it?
                8. Still tweaking your resume? I’ve got cold email templates that land callbacks. Want them before someone else does?
                9. I’ve got a roadmap from jobless to hired—portfolios, resumes, cold emails, referrals. Want the system or just hope luck saves you?

                Generate 1 notification. Keep it aggressive, personal, intriguing and **impossible to ignore**.
`;

const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
let api_response;

async function generateGptResponse(uid) {
  try {
    const response = await axios.post("https://api.openai.com/v1/chat/completions",
        {
          model: "gpt-4o",
          messages: [
            {role: "system", content: "You are a expert productivity coach."},
            {role: "user", content: prompt},
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
    api_response = response.data.choices[0].message.content.trim();

    await saveNotificationToFirestore(uid, api_response);

    return api_response;
  } catch (err) {
    return "You're slacking. Wtf? Check your OpenAI API key and try again!";
  }
}

exports.sendScheduledNotification = onSchedule(
   {
       schedule: "*/30 7-23 * * *",
       secrets: ["OPENAI_API_KEY"],
       timeZone: "America/Los_Angeles",
   },
   async () => {

        const usersSnapshot = await db.collection("users").where("isActive", "==", true).get();

        // Iterate through each user document
        for (const doc of usersSnapshot.docs) {
          const uid = doc.id;                 // dynamic userId
          const data = doc.data();
          const token = data.fcmToken;        // FCM token here

          if (!token) {
            console.warn(`No FCM token for user ${uid}`);
            continue;
          }

      const _apiResponse = await generateGptResponse(uid);

      const message = {
        token,
        android: {
          priority: 'high',
          notification: {
            channel_id: 'focusfuel_channel',  // custom channel
          }
        },
        notification: {
          title: 'Stay hard!',
          body: _apiResponse
        },
        data: {
          deep_link: "/chat"
        }
      };

      try {  // sending the notification to FCM servers
        console.log("Notification message that to be sent is ", message);
        const result = await admin.messaging().send(message);
        console.log("Notification sent:", result);
      } catch (err) {
        console.error("FCM send error:", err.message);
      }
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
