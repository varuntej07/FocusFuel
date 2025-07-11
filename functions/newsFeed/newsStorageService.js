const { FieldValue } = require('firebase-admin/firestore');
const { admin } = require("../utils/firebase");
const crypto = require('crypto');

const db = admin.firestore();

// Save news articles to Firestore
async function saveUserNewsArticles(userId, articles) {
    try {
        console.log(`Saving ${articles.length} articles for user: ${userId}`);

        const today = new Date();
        const dateKey = today.toISOString().split('T')[0]; // Format: YYYY-MM-DD
        const collectionTime = new Date().toISOString();

        const savedArticles = [];

        for (const article of articles) {
            try {
                // Generate unique article ID to prevent duplicates from 8am and 2pm runs
                const articleId = crypto
                    .createHash('md5')
                    .update(`${article.title}_${article.link}`)
                    .digest('hex');

                const articleRef = await db
                    .collection('UsersFeed')
                    .doc(userId)
                    .collection(dateKey)
                    .doc(articleId);  // Use specific ID instead of .add()

                // Check if article already exists for today (prevents duplicates)
                const existingDoc = await articleRef.get();
                if (existingDoc.exists) {
                    console.log(`Article already exists for today: ${article.title}`);
                    continue; // Skip this article
                }

                // Save new article
                await articleRef.set({
                    ...article,
                    savedAt: FieldValue.serverTimestamp(),
                    collectionDate: dateKey,        // for organizing collections
                    collectionTime: collectionTime,
                    collectionSession: today.getHours() < 12 ? 'morning' : 'afternoon',     // as i run news fetch twice
                    isRead: false,
                    isBookmarked: false
                });

                savedArticles.push(articleId);
            } catch (error) {
                console.error(`Failed to save article: ${article.title}`, error);
            }
        }

        // Update user feed metadata with today's info
        if (savedArticles.length > 0) {
            await db.collection('UsersFeed').doc(userId).set({
                lastUpdated: FieldValue.serverTimestamp(),
                lastCollectionDate: dateKey,
                totalArticlesToday: FieldValue.increment(savedArticles.length)
            }, { merge: true });
        }

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
async function getUserNewsArticles(userId, dateKey, limit = 30) {
    try {
        // Get articles from multiple days if no specific date
        if (!dateKey) {
            const today = new Date();
            const yesterday = new Date(today);
            yesterday.setDate(yesterday.getDate() - 1);

            const todayKey = today.toISOString().split('T')[0];
            const yesterdayKey = yesterday.toISOString().split('T')[0];

            // Fetch from both days
            const [todaySnapshot, yesterdaySnapshot] = await Promise.all([
                db.collection('UsersFeed').doc(userId).collection(todayKey)
                    .orderBy('savedAt', 'desc').limit(limit).get(),
                db.collection('UsersFeed').doc(userId).collection(yesterdayKey)
                    .orderBy('savedAt', 'desc').limit(limit).get()
            ]);

            const articles = [
                ...todaySnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })),
                ...yesterdaySnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }))
            ];

            // Sort combined results and limit
            return {
                success: true,
                articles: articles
                    .sort((a, b) => {
                        const dateA = a.savedAt?.toDate() || new Date(0);
                        const dateB = b.savedAt?.toDate() || new Date(0);
                        return dateB - dateA;
                    })
                    .slice(0, limit)
            };
        }else {
             const articlesSnapshot = await db
                 .collection('UsersFeed')
                 .doc(userId)
                 .collection(dateKey)
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
        }
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
        const userFeedDoc = await db.collection('UsersFeed').doc(userId).get();

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