const { onSchedule } = require("firebase-functions/v2/scheduler");
const fetch = require("node-fetch");
const xml2js = require("xml2js");
const { callOpenAI } = require("../utils/openai");
const { getUserProfile } = require("../utils/getUserProfile");
const { isMoreReputableSource } = require("../utils/reputableNewsSources");
const { saveUserNewsArticles } = require("../newsFeed/newsStorageService");
const { admin } = require("../utils/firebase");

// Main entry point for collecting personalized news feed
// This function orchestrates the entire data collection process
const scheduledNewsCollection = onSchedule(
    {
        schedule: "0 6 * * *",
        secrets: ["OPENAI_API_KEY"],
        timeZone: "America/Los_Angeles",
    },
    async () => {
        try {
            console.log("Scheduled news collection started");

            const db = admin.firestore();
            const usersSnapshot = await db.collection('users').get();
            const users = usersSnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

            console.log(`Processing news collection for ${users.length} users`);

            const results = [];

            // Processing through each user
            for (const user of users) {
                try {
                    const userId = user.id;
                    console.log(`Starting news feed collection for user: ${userId}`);

                    // Get user profile 
                    const userProfile = await getUserProfile(userId);
                    console.log(`User profile retrieved: ${userProfile.username}, interests: ${userProfile.primaryInterests?.join(", ")}`);

                    // for each interest generating few search terms that relates to that interest
                    const searchTerms = await generateSearchTerms(userProfile.primaryInterests);
                    console.log(`Generated search terms:`, searchTerms);

                    // Collect articles for each search term
                    const articles = await collectArticlesForSearchTerms(searchTerms, userProfile);
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
);

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
            For each interest, provide 4-6 related search terms that would capture news, trends, and 
            developments in that field.

            Format your response as a JSON object where each key is an interest area and the value is an array of search terms.

            Example format:
            {
              "artificial intelligence": ["AI", "machine learning", "neural networks", "automation", "ChatGPT"],
              "fitness": ["workout", "exercise", "health", "nutrition", "wellness"]
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
        console.log(`Finally returning search terms: ${searchTerms}`);
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
async function collectArticlesForSearchTerms(searchTerms, userProfile) {
    const allArticles = [];

    // Process search terms in batches to avoid rate limits
    const batchSize = 3;
    for (let i = 0; i < searchTerms.length; i += batchSize) {
        const batch = searchTerms.slice(i, i + batchSize);  // Get current batch of search terms

        // promise to fetch articles for each search term in the batch
        const batchPromises = batch.map(searchTerm => fetchGoogleNewsForTerm(searchTerm, userProfile));

        const batchResults = await Promise.allSettled(batchPromises);

        batchResults.forEach((result, index) => {
            if (result.status === 'fulfilled') {
                allArticles.push(...result.value);
            } else {
                console.error(`Failed to fetch articles for term: ${batch[index].term}`, result.reason);
            }
        });

        // Small delay between batches to be respectful
        if (i + batchSize < searchTerms.length) {
            await new Promise(resolve => setTimeout(resolve, 100));
        }
    }

    return allArticles;
}

//Fetch Google News for a specific search term
async function fetchGoogleNewsForTerm(searchTerm, userProfile) {
    try {
        const query = searchTerm.term;
        const googleNewsUrl = `https://news.google.com/rss/search?q=${encodeURIComponent(query)}&hl=en&gl=US&ceid=US:en`;

        console.log(`Fetching Google News for term: ${query}`);

        const response = await fetch(googleNewsUrl, {
            headers: {
                'User-Agent': 'Mozilla/5.0 (compatible; NewsBot/1.0)' // Mozilla on behalf of all browsers to avoid blocking 
            }
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        // Convert the HTTP response body from binary data to readable text string
        const xmlText = await response.text();

        // XML parser with specific configuration options
        const parser = new xml2js.Parser({
            explicitArray: false, // means single items won't be wrapped in arrays
            trim: true
        });

        // Using parseStringPromise to handle the XML to JSON parsing asynchronously
        const result = await parser.parseStringPromise(xmlText);

        // RSS feeds have hierarchy: rss -> channel -> items
        // so have to verify each level exists before trying to access articles
        if (!result.rss || !result.rss.channel || !result.rss.channel.item) {
            console.log(`No articles found for term: ${query}`);
            return [];
        }

        // Ensure items is always an array
        const items = Array.isArray(result.rss.channel.item)
            ? result.rss.channel.item
            : [result.rss.channel.item];

        return items.map(item => ({
            title: cleanTitle(item.title),
            link: item.link,
            pubDate: item.pubDate,
            description: item.description || '',
            source: extractSourceFromTitle(item.title),
            searchTerm: searchTerm.term,
            originalInterest: searchTerm.originalInterest,
            category: searchTerm.category,
            guid: item.guid && typeof item.guid === 'object' ? item.guid._ : item.guid,
            userId: userProfile.uid,
            fetchedAt: new Date().toISOString()
        }));

    } catch (error) {
        console.error(`Error fetching Google News for term ${searchTerm.term}:`, error);
        return [];
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

    // Now, removing articles that're older than 7 days
    const recentArticles = validArticles.filter(article => {
        try {
            const articleDate = new Date(article.pubDate);
            const weekAgo = new Date();
            weekAgo.setDate(weekAgo.getDate() - 7);
            return articleDate > weekAgo;
        } catch (error) {
            console.error(`Error parsing date for article: ${article.title}`);
            return false;
        }
    });

    console.log(`After date filtering: ${recentArticles.length} articles`);

    // Removing duplicate articles based on title similarity
    const uniqueArticles = removeDuplicateArticles(recentArticles);
    console.log(`After duplicate removal: ${uniqueArticles.length} articles`);

    // Sort by publication date (newest first)
    const sortedArticles = uniqueArticles.sort((a, b) =>
        new Date(b.pubDate) - new Date(a.pubDate)
    );

    // Limiting to top 30 articles to keep response manageable
    const limitedArticles = sortedArticles.slice(0, 30);

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
            if (calculateSimilarity(normalizedTitle, seenTitle) > 0.8) {
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

// Utility functions
function cleanTitle(title) {
    if (!title) return '';

    // Remove source suffix (ex: "Title - CNN" -> "Title")
    return title.replace(/ - [^-]*$/, '').trim();
}

function extractSourceFromTitle(title) {
    if (!title) return 'Unknown';

    const parts = title.split(' - ');
    return parts.length > 1 ? parts[parts.length - 1] : 'Unknown';
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

module.exports = {
    scheduledNewsCollection,
    generateSearchTerms,
    collectArticlesForSearchTerms,
    filterAndCleanArticles
};