const fetch = require("node-fetch");
const xml2js = require("xml2js");

class RSSService {
    constructor() {
        this.parser = new xml2js.Parser({
            explicitArray: false,
            trim: true,
            mergeAttrs: true
        });

        // Comprehensive RSS feeds organized by category
        this.universalFeeds = {
            // TRENDING/UNIVERSAL
            trending: [
                { url: 'https://feeds.bbci.co.uk/news/rss.xml', source: 'BBC News', quality: 'premium' },
                { url: 'https://feeds.cnn.com/rss/edition.rss', source: 'CNN', quality: 'premium' },
                { url: 'https://feeds.reuters.com/reuters/topNews', source: 'Reuters', quality: 'premium' }
            ],

            // BUSINESS & FINANCE  
            business: [
                { url: 'https://feeds.bloomberg.com/markets/news.rss', source: 'Bloomberg', quality: 'premium' },
                { url: 'https://feeds.cnbc.com/cnbc/world', source: 'CNBC', quality: 'standard' },=
            ],

            // HEALTH & FITNESS
            health: [
                { url: 'https://rss.cnn.com/rss/edition_health.rss', source: 'CNN Health', quality: 'standard' },
                { url: 'https://feeds.webmd.com/rss/rss.aspx?RSSSource=RSS_PUBLIC', source: 'WebMD', quality: 'standard' }
            ],

            // ENTERTAINMENT & POP CULTURE
            entertainment: [
                { url: 'https://feeds.eonline.com/eonline/news', source: 'E! News', quality: 'standard' },
                { url: 'https://feeds.variety.com/variety/news', source: 'Variety', quality: 'standard' }
            ],

            // SCIENCE & INNOVATION
            science: [
                { url: 'https://feeds.nationalgeographic.com/ng/news', source: 'National Geographic', quality: 'premium' },
                { url: 'https://rss.sciencedaily.com/breaking.xml', source: 'Science Daily', quality: 'standard' }
            ],

            // LIFESTYLE & CULTURE
            lifestyle: [
                { url: 'https://feeds.vogue.com/vogue/news', source: 'Vogue', quality: 'standard' },
                { url: 'https://feeds.foodnetwork.com/fn/news', source: 'Food Network', quality: 'standard' }
            ],

            // SPORTS (broad appeal)
            sports: [
                { url: 'https://feeds.espn.com/espn/topNews', source: 'ESPN', quality: 'premium' },
                { url: 'https://www.skysports.com/rss/12040', source: 'Sky Sports', quality: 'standard' }
            ]
        };
    }

    // FETCH TRENDING NEWS - Gets articles everyone might find interesting
    async fetchTrendingNews(options = {}) {
        console.log('Fetching universal trending news...');
        
        const trendingFeeds = this.universalFeeds.trending;
        const maxArticlesPerFeed = Math.ceil((options.size || 20) / trendingFeeds.length);
        
        // Fetch from all trending sources in parallel
        const feedPromises = trendingFeeds.map(feed => 
            this.fetchSingleFeed(feed, maxArticlesPerFeed, 'universal')
        );

        const results = await Promise.allSettled(feedPromises);
        const allArticles = results
            .filter(result => result.status === 'fulfilled')
            .flatMap(result => result.value || []);

        console.log(`Fetched ${allArticles.length} universal trending articles`);
        return allArticles;
    }

    // FETCH BY CATEGORIES (Discovery Content) - Gets articles from specific categories for discovery
    async fetchByCategories(categories, options = {}) {
        console.log(`Fetching discovery content for categories: ${categories.join(', ')}`);
        
        const allPromises = [];
        const articlesPerCategory = Math.ceil((options.size || 15) / categories.length);

        // For each discovery category, fetch from available feeds
        categories.forEach(category => {
            const categoryFeeds = this.universalFeeds[category] || [];
            const articlesPerFeed = Math.ceil(articlesPerCategory / Math.max(categoryFeeds.length, 1));

            categoryFeeds.forEach(feed => {
                allPromises.push(
                    this.fetchSingleFeed(feed, articlesPerFeed, 'discovery', category)
                );
            });
        });

        const results = await Promise.allSettled(allPromises);
        const allArticles = results
            .filter(result => result.status === 'fulfilled')
            .flatMap(result => result.value || []);

        console.log(`Fetched ${allArticles.length} discovery articles`);
        return allArticles;
    }

    // FETCH SINGLE RSS FEED - Core method that fetches and parses individual RSS feeds
    async fetchSingleFeed(feedConfig, maxArticles = 10, contentType = 'universal', category = null) {
        try {
            console.log(`Fetching from ${feedConfig.source}...`);

            const controller = new AbortController();
            const timeoutId = setTimeout(() => controller.abort(), 15000); // 15 second timeout

            const response = await fetch(feedConfig.url, {
                signal: controller.signal,
                headers: {
                    'User-Agent': 'Mozilla/5.0 (compatible; FocusFuel-Universal/1.0)',
                    'Accept': 'application/rss+xml, application/xml, text/xml',
                    'Cache-Control': 'no-cache'
                }
            });

            clearTimeout(timeoutId);

            if (!response.ok) {
                throw new Error(`HTTP ${response.status} for ${feedConfig.source}`);
            }

            const xmlText = await response.text();
            const parsedXml = await this.parser.parseStringPromise(xmlText);

            // Handle different RSS/Atom formats
            const items = this.extractItems(parsedXml);
            if (!items || items.length === 0) {
                console.warn(`No items found in ${feedConfig.source}`);
                return [];
            }

            // Process and format articles
            const formattedArticles = items
                .slice(0, maxArticles)
                .map(item => this.formatArticle(item, feedConfig, contentType, category))
                .filter(article => article.title && article.link);

            console.log(`Successfully fetched ${formattedArticles.length} articles from ${feedConfig.source}`);
            return formattedArticles;

        } catch (error) {
            console.error(`Failed to fetch ${feedConfig.source}:`, error.message);
            return [];
        }
    }

    // EXTRACT ITEMS FROM PARSED XML - Handles different RSS/Atom feed formats
    extractItems(parsedXml) {
        // RSS 2.0 format
        if (parsedXml.rss?.channel?.item) {
            return Array.isArray(parsedXml.rss.channel.item) 
                ? parsedXml.rss.channel.item 
                : [parsedXml.rss.channel.item];
        }

        // Atom format
        if (parsedXml.feed?.entry) {
            return Array.isArray(parsedXml.feed.entry) 
                ? parsedXml.feed.entry 
                : [parsedXml.feed.entry];
        }

        // RDF format (less common)
        if (parsedXml['rdf:RDF']?.item) {
            return Array.isArray(parsedXml['rdf:RDF'].item) 
                ? parsedXml['rdf:RDF'].item 
                : [parsedXml['rdf:RDF'].item];
        }

        return null;
    }

    // FORMAT ARTICLE TO STANDARD STRUCTURE - Converts RSS item to your app's article format
    formatArticle(item, feedConfig, contentType, category) {
        // Handle different date formats
        const pubDate = item.pubDate || item.published || item['dc:date'] || new Date().toISOString();
        
        // Handle different description fields
        const description = item.description || item.summary || item.content || '';
        
        // Clean description (remove HTML tags)
        const cleanDescription = typeof description === 'string' 
            ? description.replace(/<[^>]*>/g, '').substring(0, 500)
            : '';

        return {
            // Standard fields (matching your existing format)
            title: this.cleanTitle(item.title),
            link: item.link || item.guid,
            pubDate: pubDate,
            description: cleanDescription,
            source: feedConfig.source,
            guid: item.guid?._  || item.guid || item.id || item.link,
            
            // Enhanced fields for content mixing
            contentType: contentType,
            category: category || this.inferCategory(item.title, description),
            sourceQuality: feedConfig.quality,
            fetchedAt: new Date().toISOString(),
            provider: 'universal-rss',
            
            // Optional fields
            imageUrl: this.extractImageUrl(item),
            author: item.author || item['dc:creator'] || null
        };
    }

    /**
     * UTILITY METHODS
     */
    
    // Clean article titles (remove source suffixes, extra formatting)
    cleanTitle(title) {
        if (!title) return '';
        return title
            .replace(/ - [^-]*$/, '')
            .replace(/\s+/g, ' ')
            .trim()
            .substring(0, 200);
    }

    // Extract image URL from RSS item (if available)
    extractImageUrl(item) {
        // Try multiple common image fields
        if (item.enclosure?.url && item.enclosure.type?.includes('image')) {
            return item.enclosure.url;
        }
        if (item['media:thumbnail']?.url) {
            return item['media:thumbnail'].url;
        }
        if (item.image?.url) {
            return item.image.url;
        }
        return null;
    }

    // Infer category from content (simple keyword matching)
    inferCategory(title, description) {
        const content = `${title} ${description}`.toLowerCase();
        
        if (content.match(/\b(stock|market|finance|economy|business)\b/)) return 'business';
        if (content.match(/\b(health|fitness|medical|wellness)\b/)) return 'health';
        if (content.match(/\b(movie|music|celebrity|entertainment)\b/)) return 'entertainment';
        if (content.match(/\b(science|research|study|discovery)\b/)) return 'science';
        if (content.match(/\b(sports|game|team|player)\b/)) return 'sports';
        if (content.match(/\b(fashion|food|travel|lifestyle)\b/)) return 'lifestyle';
        
        return 'general';
    }

    // delay utility for rate limiting
    delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
}

module.exports = { RSSService };