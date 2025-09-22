const { admin } = require("./firebase");
const { UserHistoryService } = require("./userHistoryService");

const db = admin.firestore();

// Helper function to get full user profile
async function getUserProfile(uid) {
    const userDoc = await db.doc(`Users/${uid}`).get();
    const userData = userDoc.data();

    // Generate AI summary of user's history using OpenAI
    const historyService = new UserHistorySummaryService(uid, process.env.OPENAI_API_KEY);
    const historySummary = await historyService.getUserHistorySummary();

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