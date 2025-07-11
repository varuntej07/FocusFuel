const { onSchedule } = require("firebase-functions/v2/scheduler");
const { callOpenAI } = require("../utils/openai");
const { getUserProfile } = require("../utils/getUserProfile");
const { isMoreReputableSource } = require("../utils/reputableNewsSources");
const { saveUserNewsArticles } = require("../newsFeed/newsStorageService");
const { admin } = require("../utils/firebase");
const { NewsAggregator } = require('./newsAggregator');

// Main entry point for collecting personalized news feed
// This function orchestrates the entire news data collection process
module.exports = {
    scheduledNewsCollection: onSchedule(
        {
            schedule: "0 7,14 * * *",
            secrets: ["OPENAI_API_KEY", "NEWSDATA_API_KEY"],
            timeZone: "America/Los_Angeles",
        },
        async () => {
            try {
                console.log("Scheduled news collection started");

                const db = admin.firestore();
                const usersSnapshot = await db.collection('Users').get();
                const users = usersSnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

                console.log(`Processing news collection for ${users.length} users`);

                const MAX_CREDITS_PER_RUN = 100; // Half of daily free 200, cuz running twice
                const activeUsers = users.filter(u => u.primaryInterests?.length > 0);
                const creditsPerUser = Math.floor(MAX_CREDITS_PER_RUN / activeUsers.length);

                console.log(`${activeUsers.length} active users, ${creditsPerUser} credits each`);

                const results = [];

                // Processing through each user
                for (const user of users) {
                    try {
                        const userId = user.uid;
                        if (!user.primaryInterests || user.primaryInterests.length === 0) {
                            console.log(`No primary interests for user ${userId}, skipping`);
                            results.push({
                                success: false,
                                userId: userId,
                                error: "No primary interests found"
                            });
                            continue;
                        }

                        // Get user profile 
                        const userProfile = await getUserProfile(userId);
                        console.log(`User profile retrieved: ${userProfile.username}, interests: ${userProfile.primaryInterests?.join(", ")}`);

                        // for each interest generating few search terms that relates to that interest
                        const searchTerms = await generateSearchTerms(userProfile.primaryInterests);
                        console.log(`Generated search terms:`, searchTerms);

                        // Collect articles for each search term
                        const articles = await collectArticlesForSearchTerms(searchTerms, userProfile, creditsPerUser);
                        console.log(`Collected a total of ${articles.length} articles`);

                        // Filter and clean articles
                        const cleanArticles = await filterAndCleanArticles(articles);
                        console.log(`After filtering: ${cleanArticles.length} clean articles`);

                        // Save articles to Firestore
                        const saveResult = await saveUserNewsArticles(userId, cleanArticles);
                        console.log(`Storage result is:`, saveResult);

                        results.push({
                            success: true,
                            userId: userId,
                            totalArticles: cleanArticles.length,
                            savedCount: saveResult.savedCount
                        });

                    } catch (userError) {
                        console.error(`Error processing user ${user.id}:`, userError);
                        results.push({
                            success: false,
                            userId: user.id,
                            error: userError.message
                        });
                    }
                }

                console.log(`Completed news collection for all users. Results:`, results);
                return {
                    success: true,
                    processedUsers: users.length,
                    results: results,
                    completedAt: new Date().toISOString()
                };

            } catch (error) {
                console.error("Error in scheduled news collection:", error);
                return {
                    success: false,
                    error: error.message
                };
            }
        }
    )
}

// Generate search terms using OpenAI based on user interests
// This replaces hardcoded search terms with AI-generated ones
async function generateSearchTerms(primaryInterests) {
    try {
        if (!primaryInterests || primaryInterests.length === 0) {
            console.log("No primary interests found, returning default terms");
            return ["technology", "business", "health"];
        }

        const allInterests = [...primaryInterests];

        const prompt = `
            Based on these user interests: ${allInterests.join(", ")}
        
            Generate specific search terms that would find relevant news articles for each interest area. 
            For each interest, provide 2-4 related search terms that would capture news, trends, and 
            developments in that field.

            Format your response as a JSON object where each key is an interest area and the value is an array of search terms.

            Example format:
            {
              "artificial intelligence": ["Deep learning", "machine learning", "automation",],
              "fitness": ["workout", "health", "nutrition",]
            }

            Keep search terms concise and news-focused. Include both broad terms and specific trending topics.
            NO markdown, NO extra quotes, just JSON response
            `;

        const response = await callOpenAI({
            model: "gpt-4o",
            messages: [
                {
                    role: "system",
                    content: "You are a news search expert. Generate relevant search terms for finding current news articles based on user interests."
                },
                {
                    role: "user",
                    content: prompt
                }
            ],
            temperature: 0.9,
            max_tokens: 500
        });

        // generated JSON response of search terms, response format as shown in prompt
        const aiResponse = response.data.choices[0].message.content;

        // Parse JSON response
        const searchTermsObj = JSON.parse(aiResponse);

        // Convert to flat array with all metadata
        const searchTerms = [];
        for (const [interest, terms] of Object.entries(searchTermsObj)) {
            for (const term of terms) {
                searchTerms.push({
                    term: term,
                    category: interest
                });
            }
        }
        // Now the searchTerms array is objects with term and category
        // [{ term: 'AI advancements', category: 'Technology' }, {..}, ....]
        return searchTerms;

    } catch (error) {
        console.error("Error generating search terms from OpenAI:", error);

        // Fallback to basic terms if AI fails
        const fallbackTerms = primaryInterests.map(interest => ({
            term: interest,
            category: interest
        }));

        return fallbackTerms;
    }
}

// Collect articles for all search terms
async function collectArticlesForSearchTerms(searchTerms, userProfile, creditsPerUser) {
    const newsAggregator = new NewsAggregator();

    try {
        return await newsAggregator.fetchNews(searchTerms, userProfile, {maxRequests: creditsPerUser});
    } catch (error) {
        console.error('All news sources failed:', error);
        return []; // Return empty array instead of crashing
    }
}


// Filter and clean articles
async function filterAndCleanArticles(articles) {
    console.log(`Starting article filtering with ${articles.length} articles`);

    // First remove articles with missing essential data
    const validArticles = articles.filter(article => {
        return article.title &&
            article.link &&
            article.title.length > 10 &&
            article.title.length < 200;
    });

    console.log(`After basic validation: ${validArticles.length} articles`);

    // Removing duplicate articles based on title similarity
    const uniqueArticles = removeDuplicateArticles(recentArticles);
    console.log(`After duplicate removal: ${uniqueArticles.length} articles`);

    // Sort by publication date (newest first)
    const sortedArticles = uniqueArticles.sort((a, b) =>
        new Date(b.pubDate) - new Date(a.pubDate)
    );

    // Limiting to top X articles to keep response manageable
    const ARTICLES_TO_KEEP = 100;
    const limitedArticles = sortedArticles.slice(0, ARTICLES_TO_KEEP);

    console.log(`Final filtered articles: ${limitedArticles.length}`);

    return limitedArticles;
}

function removeDuplicateArticles(articles) {
    const seen = new Map();
    const unique = [];

    for (const article of articles) {
        const normalizedTitle = normalizeTitle(article.title);

        let isDuplicate = false;    // flag to track duplicate articles

        // Iterate through seen and check if the title already exists in the seen map
        for (const [seenTitle, seenArticle] of seen) {
            if (calculateSimilarity(normalizedTitle, seenTitle) > 0.8) {   // 80% title similarity threshold
                isDuplicate = true;

                // Keep the article from a more reputable source or more recent
                if (isMoreReputableSource(article.source, seenArticle.source) ||
                    (article.source === seenArticle.source && new Date(article.pubDate) > new Date(seenArticle.pubDate))) {

                    // Replace the old article with the new one
                    const index = unique.findIndex(a => a.title === seenArticle.title);
                    if (index !== -1) {
                        unique[index] = article;
                        seen.delete(seenTitle);
                        seen.set(normalizedTitle, article);
                    }
                }
                break;
            }
        }
        // If no similar article was found, add article to both tracking structures
        if (!isDuplicate) {
            seen.set(normalizedTitle, article);
            unique.push(article);
        }
    }

    return unique;
}

function normalizeTitle(title) {
    return title.toLowerCase()
        .replace(/[^\w\s]/g, '')
        .replace(/\s+/g, ' ')
        .trim();
}

// calculates similarity between two strings based on Jaccard index
function calculateSimilarity(str1, str2) {
    const words1 = str1.split(' ');
    const words2 = str2.split(' ');

    const intersection = words1.filter(word => words2.includes(word));
    const union = [...new Set([...words1, ...words2])];

    return intersection.length / union.length;
}