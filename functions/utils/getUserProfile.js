const { admin } = require("./firebase");
const { UserHistoryService } = require("./userHistoryService");
const { UserHistorySummaryService } = require("./userHistorySummaryService");

const db = admin.firestore();

// Helper function to get full user profile
async function getUserProfile(uid) {
    const userDoc = await db.doc(`Users/${uid}`).get();
    const userData = userDoc.data();

    // Generate AI summary of user's history using OpenAI
    const historyService = new UserHistorySummaryService(uid, process.env.OPENAI_API_KEY);
    const historySummary = await historyService.getUserHistorySummary();

    // Save the history summary to the user document for easy access
    await db.doc(`Users/${uid}`).set({
        historySummary: historySummary,
        historySummaryUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    return {
        uid: userDoc.id,
        username: userData?.username || "Anonymous",
        currentFocus: userData?.currentFocus || "",
        weeklyGoal: userData?.weeklyGoal || "",
        primaryInterests: userData?.primaryInterests || [],
        subInterests: userData?.subInterests || [],
        primaryGoal: userData?.primaryGoal || "Career Advancement",
        motivationStyle: userData?.motivationStyle || "gentle reminders",
        ageRange: userData?.ageRange || "23-29",
        preferredNotificationTime: userData?.preferredNotificationTime || "Morning (8-11 AM)",
        dailyScreenTime: userData?.dailyScreenTime || "",
        mostUsedApp: userData?.mostUsedApp || "",
        timezone: userData?.timezone || "America/Los_Angeles",
        task: userData?.usersTask || "",
        historySummary: historySummary
    };
}

module.exports = { getUserProfile };