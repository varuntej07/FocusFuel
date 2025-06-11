const {onSchedule} = require("firebase-functions/v2/scheduler");

const admin = require("firebase-admin");

// Clears the currentFocus field for all users daily
module.exports = {
  clearDailyGoals: onSchedule(
    {
      schedule: "every day 00:05",
      timeZone: "America/Los_Angeles",
    },
    async () => {
      const db = admin.firestore();
      const usersSnap = await db.collection("Users").get();

      const batch = db.batch();
      usersSnap.forEach((doc) => {
        batch.update(doc.ref, {
          currentFocus: admin.firestore.FieldValue.delete(),
        });
      });

      await batch.commit();
      console.log(`Cleared focus for ${usersSnap.size} users`);
    }
  )
};