const fetch = require("node-fetch");
const xml2js = require("xml2js");

class RSSService {
    constructor() {
        this.parser = new xml2js.Parser({
            explicitArray: false,
            trim: true,
            mergeAttrs: true
        });

        // Reliable RSS feeds for backup
        this.feeds = [
            { url: 'https://feeds.bbci.co.uk/news/technology/rss.xml', category: 'technology' },
            { url: 'https://feeds.feedburner.com/TechCrunch/', category: 'technology' },
            { url: 'https://www.theverge.com/rss/index.xml', category: 'technology' },
            { url: 'https://feeds.reuters.com/reuters/technologyNews', category: 'technology' },
            { url: 'https://feeds.bbci.co.uk/news/business/rss.xml', category: 'business' },
            { url: 'https://feeds.bbci.co.uk/news/health/rss.xml', category: 'health' },
            { url: 'https://feeds.npr.org/1001/rss.xml', category: 'general' },
            { url: 'https://feeds.washingtonpost.com/rss/business', category: 'business' },
            { url: 'https://feeds.cnn.com/rss/edition.rss', category: 'general' },
        ];
    }

    async fetchNews(searchTerms, options = {}) {
        const relevantFeeds = this.selectRelevantFeeds(searchTerms);
        const allArticles = [];
        const maxArticles = options.size || 20;

        for (const feed of relevantFeeds) {
            try {
                const articles = await this.fetchFeed(feed);
                allArticles.push(...articles);

                // Small delay between feeds
                await this.delay(1000);
            } catch (error) {
                console.error(`RSS feed failed: ${feed.url}`, error);
                continue;
            }
        }

        const filteredArticles = this.filterByRelevance(allArticles, searchTerms);
        return filteredArticles.slice(0, maxArticles);
    }

    async fetchFeed(feed) {
        const response = await fetch(feed.url, {
            timeout: 30000,
            headers: {
                'User-Agent': 'Mozilla/5.0 (compatible; FocusFuel-RSS/1.0)'
            }
        });

        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        }

        const xmlText = await response.text();
        const result = await this.parser.parseStringPromise(xmlText);

        if (!result.rss?.channel?.item) {
            return [];
        }

        const items = Array.isArray(result.rss.channel.item)
            ? result.rss.channel.item
            : [result.rss.channel.item];

        return items.map(item => ({
            title: this.cleanTitle(item.title),
            link: item.link,
            pubDate: item.pubDate,
            description: item.description || '',
            source: this.extractSource(result.rss.channel.title),
            searchTerm: 'rss-general',
            category: feed.category,
            guid: item.guid?._ || item.guid || item.link,
            fetchedAt: new Date().toISOString(),
            provider: 'rss'
        }));
    }

    selectRelevantFeeds(searchTerms) {
        const categories = [...new Set(searchTerms.map(term => {
            // Normalize category names to match RSS feed categories
            const cat = term.category.toLowerCase();
            if (cat.includes('tech')) return 'technology';
            if (cat.includes('health') || cat.includes('fitness')) return 'health';
            if (cat.includes('business')) return 'business';
            return 'technology'; // default fallback
        }))];

        return this.feeds.filter(feed =>
            categories.includes(feed.category)
        );
    }

    filterByRelevance(articles, searchTerms) {
        const searchWords = searchTerms
            .map(term => term.term.toLowerCase().split(' '))
            .flat();

        return articles.filter(article => {
            const content = `${article.title} ${article.description}`.toLowerCase();
            return searchWords.some(word => content.includes(word));
        });
    }

    cleanTitle(title) {
        return title?.replace(/ - [^-]*$/, '').trim() || '';
    }

    extractSource(channelTitle) {
        return channelTitle?.split(' ')[0] || 'RSS';
    }

    delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
}

module.exports = { RSSService };