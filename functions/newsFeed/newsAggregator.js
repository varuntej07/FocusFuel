const { NewsDataService } = require('./newsDataService');
const { RSSService } = require('./rssService');

// NewsDataService handles API calls to NewsData.io RSSService is a fallback option when something goes wrong
class NewsAggregator {
    constructor() {
        this.newsDataService = new NewsDataService();
        this.rssService = new RSSService();
        this.retryConfig = {
            maxAttempts: 3,
            baseDelay: 1000,
            maxDelay: 10000
        };
    }

    // Fetches news from all sources in parallel
    // Attempts each news source in order and returns array of article objects with specific enrichment
    async fetchNews(searchTerms, userProfile, options = {}) {
        console.log("Fetching news for user:", userProfile.username);

        const sourcePromises = [
            // PERSONALIZED: NewsData.io with user's search terms
            this.retryWrapper(
                () => this.newsDataService.fetchNews(searchTerms, options),
                'NewsData.io'
            ),
        
            // UNIVERSAL: Trending content from RSS
            this.retryWrapper(
                () => this.rssService.fetchTrendingNews({ size: options.maxRequests || 10 }),
                'RSS-Trending'
            ),
        
            // DISCOVERY: Categories user hasn't chosen
            this.retryWrapper(
                () => this.rssService.fetchByCategories(
                    this.getDiscoveryCategories(userProfile.primaryInterests), 
                    { size: options.maxRequests || 10 }
                ),
                'RSS-Discovery'
            )
        ];

        try {
            const results = await Promise.allSettled(sourcePromises);
        
            const allArticles = results
                .filter(result => result.status === 'fulfilled' && result.value?.length > 0)
                .flatMap(result => result.value);

            console.log(`Parallel fetch completed: ${allArticles.length} total articles fetched`);
        
            return this.enrichArticles(allArticles, userProfile);
        
        } catch (error) {
            console.error('Critical error in parallel fetch:', error);
            return [];
        }
    }

    // Gets categories for discovery content (categories user hasn't chosen)
    getDiscoveryCategories(userInterests) {
        const allCategories = ['business', 'health', 'entertainment', 'science', 'sports', 'lifestyle'];
        const userCategories = userInterests?.map(i => i.toLowerCase()) || [];
        
        // Return categories user hasn't explicitly chosen
        return allCategories.filter(cat => 
            !userCategories.some(userCat => userCat.includes(cat))
        );
    }

    // RETRY WRAPPER
    async retryWrapper(fetchFunction, sourceName) {
        let lastError;

        for (let attempt = 1; attempt <= this.retryConfig.maxAttempts; attempt++) {
            try {
                return await fetchFunction();
            } catch (error) {
                lastError = error;
                
                if (attempt === this.retryConfig.maxAttempts) break;

                const delay = this.retryConfig.baseDelay * attempt;
                console.log(`${sourceName} attempt ${attempt} failed, retrying in ${delay}ms`);
                await this.delay(delay);
            }
        }

        console.error(`${sourceName} exhausted all retries:`, lastError.message);
        return []; // Return empty array instead of throwing
    }

    // ENRICH ARTICLES
    enrichArticles(articles, userProfile) {
        return articles.map(article => ({
            ...article,
            userId: userProfile.uid,
        }));
    }

    delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
}

module.exports = { NewsAggregator };