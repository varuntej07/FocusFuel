const {onSchedule} = require("firebase-functions/v2/scheduler");
const { admin } = require("../utils/firebase");
const { DateTime } = require("luxon");

module.exports = {
  clearWeeklyGoals: onSchedule(
    {
      schedule: "0 0 * * *", // Runs at midnight UTC every day
      timeZone: "UTC",
    },
    async () => {
      const db = admin.firestore();
      console.log("Starting clearWeeklyGoals - checking for goals that are 7+ days old");

      try {
        // Get all active users who have a weekly goal
        const usersSnap = await db.collection("Users")
          .where("isActive", "==", true)
          .get();

        const batch = db.batch();
        let clearedCount = 0;
        const now = DateTime.now();

        for (const doc of usersSnap.docs) {
          const userData = doc.data();

          // Only process if weeklyGoal exists
          if (userData.weeklyGoal && userData.weeklyGoal.trim() !== '' && userData.weeklyGoalUpdatedAt) {
            const userTimezone = userData.timezone || "America/Los_Angeles";

            // Convert Firestore timestamp to Luxon DateTime in user's timezone
            const goalUpdatedTime = DateTime.fromJSDate(userData.weeklyGoalUpdatedAt.toDate()).setZone(userTimezone);
            const currentTime = now.setZone(userTimezone);

            // Calculate days since the goal was updated
            const daysSinceUpdate = currentTime.diff(goalUpdatedTime, 'days').days;

            // If the goal is 7 days or older, clear it
            if (daysSinceUpdate >= 7) {
              // Archive the goal to goal history before clearing
              const goalHistoryRef = doc.ref.collection('goalHistory').doc();
              batch.set(goalHistoryRef, {
                content: userData.weeklyGoal,
                enteredAt: userData.weeklyGoalUpdatedAt,
                wasAchieved: false, // Default to false since we're auto-clearing
                clearedAt: admin.firestore.FieldValue.serverTimestamp(),
                clearedBy: 'scheduler'
              });

              // Clear the weekly goal from user document
              batch.update(doc.ref, {
                weeklyGoal: admin.firestore.FieldValue.delete(),
                weeklyGoalUpdatedAt: admin.firestore.FieldValue.delete(),
                lastWeeklyGoalClearedAt: admin.firestore.FieldValue.serverTimestamp()
              });

              clearedCount++;
              console.log(`Cleared 7+ day old goal for user ${userData.username || doc.id} (${daysSinceUpdate.toFixed(1)} days old)`);
            }
          }
        }

        if (clearedCount > 0) {
          await batch.commit();
          console.log(`Successfully cleared weekly goals for ${clearedCount} users`);
        } else {
          console.log("No weekly goals needed clearing today");
        }

        return { success: true, clearedCount };

      } catch (error) {
        console.error("Error in clearWeeklyGoals:", error);
        throw error;
      }
    }
  )
};
