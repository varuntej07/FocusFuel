const { admin } = require("./firebase");

const db = admin.firestore();

const DEFAULT_GOAL = "Work hard, stay hard, no excuses, no shortcuts";

// Helper function to get full user profile
async function getUserProfile(uid) {
    const userDoc = await db.doc(`Users/${uid}`).get();
    const userData = userDoc.data();

    return {
        uid: userDoc.id,
        username: userData?.username || "Anonymous",
        currentFocus: userData?.currentFocus || DEFAULT_GOAL,
        primaryInterests: userData?.primaryInterests || [],
        subInterests: userData?.subInterests || [],
        primaryGoal: userData?.primaryGoal || DEFAULT_GOAL,
        motivationStyle: userData?.motivationStyle || "gentle reminders",
        ageRange: userData?.ageRange || "23-29",
        preferredNotificationTime: userData?.preferredNotificationTime || "Morning (8-11 AM)",
        dailyScreenTime: userData?.dailyScreenTime || "",
        mostUsedApp: userData?.mostUsedApp || ""
    };
}

module.exports = { getUserProfile };