const fetch = require("node-fetch");
const { defineSecret } = require('firebase-functions/params');

const newsdataApiKey = defineSecret('NEWSDATA_API_KEY');        // api configured already using firebase secrets

class NewsDataService {
    constructor() {
        this.baseUrl = 'https://newsdata.io/api/1';
        this.requestCount = 0;
        this.dailyLimit = 190; // 95% of 200 daily free credits, 1 credit = 10 articles
    }

    async fetchNews(searchTerms, options = {}) {
        const NEWSDATA_API_KEY = newsdataApiKey.value();
        const allArticles = [];

        // Group search terms by category to maximize relevance
        const termsByCategory = searchTerms.reduce((acc, term) => {
            if (!acc[term.category]) acc[term.category] = [];
            acc[term.category].push(term);
            return acc;
        }, {});

        // Process each category (more efficient than individual terms)
        for (const [category, terms] of Object.entries(termsByCategory)) {
            if (this.requestCount >= this.dailyLimit) {
                console.log('Daily API limit reached');
                break;
            }

            // Combine terms from same category and staying under 100 chars
            const categoryTerms = terms.slice(0, 5).map(t => t.term);
            const query = categoryTerms.join(' OR ').substring(0, 95);

            console.log(`Fetching for ${category}: ${query}`);

            const params = new URLSearchParams({
                apikey: NEWSDATA_API_KEY,
                q: query,
                language: 'en',
                country: 'us',
                image: 1,
                size: 10,
                category: this.mapToNewsDataCategory(category)
            });

            try {
                console.log(`Request ${this.requestCount + 1}/${this.dailyLimit}`);

                const response = await fetch(`${this.baseUrl}/latest?${params}`, {
                    timeout: 30000,
                    headers: {
                        'User-Agent': 'FocusFuel-NewsBot/1.0'
                    }
                });

                this.requestCount++;

                if (!response.ok) {
                    const errorBody = await response.text();
                    console.error(`Failed for category "${category}": ${errorBody}`);
                    continue;
                }

                const data = await response.json();
                const articles = data.results || [];

                // Tag articles with category
                const taggedArticles = articles.map(article => ({
                    ...article,
                    searchCategory: category
                }));

                allArticles.push(...taggedArticles);
                console.log(`Got ${articles.length} articles for ${category}`);

                // Small delay to respect rate limits
                await new Promise(resolve => setTimeout(resolve, 200));

            } catch (error) {
                console.error(`Error fetching ${category}:`, error);
                continue;
            }
        }

        console.log(`Total articles collected: ${allArticles.length}`);
        return this.formatArticles(allArticles, searchTerms);
    }

    // Map user categories to NewsData.io categories
    mapToNewsDataCategory(userCategory) {
        // Normalize first
        const normalized = userCategory.toLowerCase();

        if (normalized.includes('tech')) return 'technology';
        if (normalized.includes('health') || normalized.includes('fitness')) return 'health';
        if (normalized.includes('business')) return 'business';
        if (normalized.includes('sport')) return 'sports';
        if (normalized.includes('science')) return 'science';
        if (normalized.includes('entertain')) return 'entertainment';

        // Don't return empty string - it breaks the API
        return 'technology'; // Default fallback
    }

    // Transforms NewsData.io' response format to unified article structure Ensuring consistent data shape regardless of news source
    // Maps source_id -> source, article_id -> guid, other custom fields
    formatArticles(articles, searchTerms) {
        return articles.map(article => ({
            title: article.title,
            link: article.link,
            pubDate: article.pubDate,
            description: article.description || article.content || '',
            source: article.source_id || 'NewsData',
            searchTerm: article.searchCategory || searchTerms[0]?.term || 'unknown',
            category: this.inferCategory(article, searchTerms),
            guid: article.article_id || article.link,
            image_url: article.image_url || null,
            fetchedAt: new Date().toISOString(),
            provider: 'newsdata',
            // Additional metadata
            sourceIcon: article.source_icon || null,
            videoUrl: article.video_url || null,
            keywords: article.keywords || [],
            country: article.country || []
        }));
    }

    inferCategory(article, searchTerms) {
        // Simple category inference based on keywords
        const content = `${article.title} ${article.description || ''}`.toLowerCase();

        for (const searchTerm of searchTerms) {
            if (content.includes(searchTerm.term.toLowerCase())) {
                return searchTerm.category;
            }
        }

        return searchTerms[0]?.category || 'general';
    }

    getRemainingQuota() {
        return this.dailyLimit - this.requestCount;
    }
}

module.exports = { NewsDataService };