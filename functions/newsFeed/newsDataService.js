const fetch = require("node-fetch");

class NewsDataService {
    constructor() {
        this.apiKey = process.env.NEWSDATA_API_KEY;
        this.baseUrl = 'https://newsdata.io/api/1';
        this.requestCount = 0;
        this.dailyLimit = 160; // 80% of 200 daily credits for safety
    }

    async fetchNews(searchTerms, options = {}) {
        if (this.requestCount >= this.dailyLimit) {
            throw new Error('Daily API limit reached');
        }

        const query = searchTerms.map(term => term.term).join(' OR ');
        const params = new URLSearchParams({
            apikey: this.apiKey,
            q: query,
            language: 'en',
            country: 'us',
            size: options.size || 10,
            ...options
        });

        try {
            console.log(`NewsData.io request ${this.requestCount + 1}/${this.dailyLimit}`);

            const response = await fetch(`${this.baseUrl}/latest?${params}`, {
                timeout: 30000,
                headers: {
                    'User-Agent': 'FocusFuel-NewsBot/1.0'
                }
            });

            this.requestCount++;

            if (!response.ok) {
                throw new Error(`NewsData.io API error: ${response.status}`);
            }

            const data = await response.json();

            return this.formatArticles(data.results || [], searchTerms);
        } catch (error) {
            console.error('NewsData.io fetch error:', error);
            throw error;
        }
    }

    formatArticles(articles, searchTerms) {
        return articles.map(article => ({
            title: article.title,
            link: article.link,
            pubDate: article.pubDate,
            description: article.description || article.content || '',
            source: article.source_id || 'NewsData',
            searchTerm: 'multiple',
            category: this.inferCategory(article, searchTerms),
            guid: article.article_id || article.link,
            fetchedAt: new Date().toISOString(),
            provider: 'newsdata'
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