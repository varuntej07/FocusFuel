const { onCall } = require("firebase-functions/v2/https");
const { getUserNewsArticles } = require("./newsStorageService");

module.exports = {
    getUserNewsFeed: onCall(async (request) => {
        try {
            const { userId } = request.data;

            if (!userId) {
                throw new Error('User ID is required');
            }

            console.log(`Retrieving news articles for user: ${userId}`);

            // Get articles from Firestore, expects (userID, dateKey, num of articles)
            const result = await getUserNewsArticles(userId, null, 100);
            if (!result.success) {
                throw new Error(result.error || 'Failed to retrieve articles');
            }

            console.log(`Retrieved ${result.articles.length} articles for user: ${userId}`);

            return {
                success: true,
                articles: result.articles,
                count: result.articles.length
            };

        } catch (error) {
            console.error('Error in getUserNewsFeed:', error);
            return {
                success: false,
                error: error.message,
                articles: []
            };
        }
    })
};