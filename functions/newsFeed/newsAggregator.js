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

    // Attempts each news source in order and returns array of article objects with specific enrichment
    // Expected format: [{title, link, pubDate, description, source, relevanceScore, userId}, ...]
    async fetchNews(searchTerms, userProfile, options = {}) {
        const sources = [
            { name: 'NewsData.io', service: this.newsDataService },
            { name: 'RSS', service: this.rssService }
        ];

        for (const source of sources) {
            try {
                console.log(`Attempting to fetch from ${source.name}`);
                const articles = await this.retryWrapper(
                    () => source.service.fetchNews(searchTerms, options),
                    source.name
                );

                if (articles && articles.length > 0) {
                    console.log(`Successfully fetched ${articles.length} articles from ${source.name}`);
                    return this.enrichArticles(articles, userProfile);
                }
            } catch (error) {
                console.error(`${source.name} failed:`, error.message);
                continue;
            }
        }

        throw new Error('All news sources failed');
    }

    // Retry wrapper with exponential backoff for resilient API calls
    async retryWrapper(fetchFunction, sourceName) {
        let lastError;

        for (let attempt = 1; attempt <= this.retryConfig.maxAttempts; attempt++) {
            try {
                return await fetchFunction();
            } catch (error) {
                lastError = error;

                if (attempt === this.retryConfig.maxAttempts) {
                    break;
                }

                // Exponential backoff with jitter
                const delay = Math.min(
                    this.retryConfig.baseDelay * Math.pow(2, attempt - 1),
                    this.retryConfig.maxDelay
                );
                const jitter = Math.random() * 0.1 * delay;

                console.log(`${sourceName} attempt ${attempt} failed, retrying in ${Math.round(delay + jitter)}ms`);
                await this.delay(delay + jitter);
            }
        }

        throw lastError;
    }

    // Enrich articles with user context and relevance scoring
    enrichArticles(articles, userProfile) {
        return articles.map(article => ({
            ...article,
            userId: userProfile.uid,
        }));
    }


    // Utility function for adding delays
    delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
}

module.exports = { NewsAggregator };