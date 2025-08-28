const axios = require("axios");
const { defineSecret } = require('firebase-functions/params');

const perplexityApiKey = defineSecret('PERPLEXITY_API_KEY');

async function callPerplexity(options) {
    const PERPLEXITY_API_KEY = perplexityApiKey.value();

    if (!PERPLEXITY_API_KEY) {
        console.error("Perplexity API key is not configured.check firebase:secrets");
        throw new Error("Perplexity API key is missing");
    }

    try {
        const response = await axios.post(
            "https://api.perplexity.ai/chat/completions",
            {
                model: options.model || "sonar",
                messages: options.messages,
                max_tokens: options.max_tokens || 1000,
                temperature: options.temperature || 0.2,
                return_citations: options.return_citations || true,
                return_images: options.return_images || false,
                return_related_questions: options.return_related_questions || false,
                search_domain_filter: options.search_domain_filter || [],
                search_recency_filter: options.search_recency_filter || "week"
            },
            {
                headers: {
                    "Content-Type": "application/json",
                    "Authorization": "Bearer " + PERPLEXITY_API_KEY,
                },
                timeout: 60000, // 60 second timeout
                validateStatus: () => true,
            }
        );

        if (response.status === 200) return response;

        if (res.status === 429 || res.status >= 500) {
            throw new Error(`Transient OpenAI error: ${res.status}`);
        }

        throw new Error(res.data?.error?.message || `OpenAI error ${res.status}`);

    } catch (error) {
        console.log("Perplexity API call failed, check callPerplexity:", error.message);
        throw error;
    }
}

module.exports = { callPerplexity };