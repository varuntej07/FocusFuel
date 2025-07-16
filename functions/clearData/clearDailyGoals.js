const {onSchedule} = require("firebase-functions/v2/scheduler");
const { admin } = require("../utils/firebase");
const { DateTime } = require("luxon");

module.exports = {
  clearDailyGoals: onSchedule(
    {
      schedule: "0 * * * *", // Run every hour at minute 0
      timeZone: "UTC",
    },
    async () => {
      const db = admin.firestore();
      console.log("Starting clearDailyGoals - checking users for midnight in their timezone");

      try {
        // Get all active users
        const usersSnap = await db.collection("Users").where("isActive", "==", true).get();

        const batch = db.batch();
        let clearedCount = 0;

        for (const doc of usersSnap.docs) {
          const userData = doc.data();
          const userTimezone = userData.timezone || "America/Los_Angeles";

          // Get current time in user's timezone
          const userTime = DateTime.now().setZone(userTimezone);

          // Check if it's between 00:00 and 00:59 in user's timezone
          if (userTime.hour === 0) {
            // Only clear if currentFocus exists
            if (userData.currentFocus && userData.currentFocus.trim() !== '') {
              batch.update(doc.ref, {
                currentFocus: admin.firestore.FieldValue.delete(),
                lastFocusClearedAt: admin.firestore.FieldValue.serverTimestamp()
              });
              clearedCount++;
              console.log(`Clearing focus for user ${userData.username || doc.id} in ${userTimezone}`);
            }
          }
        }

        if (clearedCount > 0) {
          await batch.commit();
          console.log(`Successfully cleared focus for ${clearedCount} users at their midnight`);
        } else {
          console.log("No users needed focus clearing this hour");
        }

        return { success: true, clearedCount };

      } catch (error) {
        console.error("Error in clearDailyGoals:", error);
        throw error;
      }
    }
  )
};