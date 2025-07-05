const { FieldValue } = require('firebase-admin/firestore');
const { admin } = require("../utils/firebase");

const db = admin.firestore();

// Save news articles to Firestore
async function saveUserNewsArticles(userId, articles) {
    try {
        console.log(`Saving ${articles.length} articles for user: ${userId}`);

        const savedArticles = [];

        for (const article of articles) {
            try {
                const articleRef = await db
                    .collection('user_feeds')
                    .doc(userId)
                    .collection('articles')
                    .add({
                        ...article,
                        savedAt: FieldValue.serverTimestamp(),
                        isRead: false,
                        isBookmarked: false
                    });

                savedArticles.push(articleRef.id);
            } catch (error) {
                console.error(`Failed to save article: ${article.title}`, error);
            }
        }

        // Update user feed metadata
        await db.collection('user_feeds').doc(userId).set({
            lastUpdated: FieldValue.serverTimestamp(),
            totalArticles: savedArticles.length
        }, { merge: true });

        console.log(`Successfully saved ${savedArticles.length} articles for user: ${userId}`);

        return {
            success: true,
            savedCount: savedArticles.length
        };

    } catch (error) {
        console.error(`Error saving articles for user ${userId}:`, error);
        return {
            success: false,
            error: error.message
        };
    }
}

// Get user's news articles from Firestore
async function getUserNewsArticles(userId, limit = 30) {
    try {
        const articlesSnapshot = await db
            .collection('user_feeds')
            .doc(userId)
            .collection('articles')
            .orderBy('savedAt', 'desc')
            .limit(limit)
            .get();

        const articles = articlesSnapshot.docs.map(doc => ({
            id: doc.id,
            ...doc.data()
        }));

        return {
            success: true,
            articles: articles
        };

    } catch (error) {
        console.error(`Error getting articles for user ${userId}:`, error);
        return {
            success: false,
            articles: [],
            error: error.message
        };
    }
}

// Check if user needs fresh articles
async function needsUpdate(userId) {
    try {
        const userFeedDoc = await db.collection('user_feeds').doc(userId).get();

        if (!userFeedDoc.exists) {
            return true; // No data = needs update
        }

        const lastUpdated = userFeedDoc.data().lastUpdated?.toDate();
        const sixHoursAgo = new Date();
        sixHoursAgo.setHours(sixHoursAgo.getHours() - 6);

        return !lastUpdated || lastUpdated < sixHoursAgo;

    } catch (error) {
        console.error(`Error checking update status for user ${userId}:`, error);
        return true; // Error = assuming it needs update
    }
}

module.exports = {
    saveUserNewsArticles,
    getUserNewsArticles,
    needsUpdate
};