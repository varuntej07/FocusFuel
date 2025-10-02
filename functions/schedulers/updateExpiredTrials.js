const { onSchedule } = require("firebase-functions/v2/scheduler");
const { admin } = require("../utils/firebase");

const db = admin.firestore();

// Daily cron job to update expired trials, runs every day at 12:01 AM PST to check for expired trials
module.exports = {
    updateExpiredTrials: onSchedule(
        {
            schedule: "1 0 * * *",  // Run at 12:01 AM every day
            timeZone: "America/Los_Angeles",
            memory: "256MB",
            timeout: 300
        },
        async () => {
            console.log("Starting expired trials check...");

            try {
                const now = admin.firestore.Timestamp.now();

                // Query users where trial has expired but status is still "trial"
                const expiredTrialsSnapshot = await db.collection("Users")
                    .where("subscriptionStatus", "==", "trial")
                    .where("trialEndDate", "<", now)
                    .get();

                console.log(`Found ${expiredTrialsSnapshot.size} expired trials to update`);

                // Batch update for efficiency
                const batch = db.batch();
                let updateCount = 0;

                expiredTrialsSnapshot.forEach((doc) => {
                    const userRef = db.collection("Users").doc(doc.id);
                    batch.update(userRef, {
                        subscriptionStatus: "free",
                        isSubscribed: false,
                    });
                    updateCount++;

                    console.log(`Marked user ${doc.id} (${doc.data().username}) as free (trial expired)`);
                });

                // Commit batch update
                if (updateCount > 0) {
                    await batch.commit();
                    console.log(`Successfully updated ${updateCount} expired trials to free tier`);
                } else {
                    console.log("No expired trials to update");
                }

            } catch (error) {
                console.error("Error updating expired trials:", error);
                throw error;
            }
        }
    )
};
