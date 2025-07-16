const { admin } = require("./firebase");

const db = admin.firestore();

// Helper function to get full user profile
async function getUserProfile(uid) {
    const userDoc = await db.doc(`Users/${uid}`).get();
    const userData = userDoc.data();

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
        timezone: userData?.timezone || "America/Los_Angeles"
    };
}

module.exports = { getUserProfile };