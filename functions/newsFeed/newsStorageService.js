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

                await db.runTransaction(async (transaction) => {
                    const existingDoc = await transaction.get(articleRef);
                        
                    if (!existingDoc.exists) {
                        transaction.set(articleRef, {
                            ...article,
                            savedAt: FieldValue.serverTimestamp(),
                            collectionDate: dateKey,
                            collectionTime: collectionTime,
                            collectionSession: today.getHours() < 12 ? 'morning' : 'afternoon',
                            isRead: false,
                            isBookmarked: false
                        });
                        savedArticles.push(articleId);
                    }
                });
            } catch (error) {
                console.error(`Failed to save article: ${article.title}`, error);
                continue; // Skip this article and continue with the next
            }
        }

        // Update user feed metadata with today's info if articles were saved
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

            const fetchSafeCollection = async (collectionDateKey) => {
                try {
                    const snapshot = await db.collection('UsersFeed')
                        .doc(userId)
                        .collection(collectionDateKey)
                        .orderBy('savedAt', 'desc')
                        .limit(limit)
                        .get();
                    
                    return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
                } catch (error) {
                    // Collection doesn't exist or no documents with savedAt field
                    console.log(`No articles found for ${collectionDateKey}: ${error.message}`);
                    return [];
                }
            };

            const [todayArticles, yesterdayArticles] = await Promise.all([
                fetchSafeCollection(todayKey),
                fetchSafeCollection(yesterdayKey)
            ]);

            const allArticles = [...todayArticles, ...yesterdayArticles];

            // Sort combined results and limit
            return {
                success: true,
                articles: allArticles
                    .sort((a, b) => {
                        const dateA = a.savedAt?.toDate() || new Date(0);
                        const dateB = b.savedAt?.toDate() || new Date(0);
                        return dateB - dateA;
                    })
                    .slice(0, limit)
            };
        }else {
            // Single date query with safety
            try {
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
            } catch (error) {
                console.log(`No articles found for date ${dateKey}: ${error.message}`);
                return {
                    success: true,
                    articles: []
                };
            }
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

module.exports = {
    saveUserNewsArticles,
    getUserNewsArticles,
};