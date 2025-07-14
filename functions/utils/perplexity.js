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
                search_recency_filter: options.search_recency_filter || "month"
            },
            {
                headers: {
                    "Content-Type": "application/json",
                    "Authorization": "Bearer " + PERPLEXITY_API_KEY,
                },
                timeout: 30000, // 30 second timeout
                validateStatus: function (status) {
                    return true;
                }
            }
        );

        // Check if request was successful
        if (response.status === 200) {
            console.log("Perplexity API call successful");
            return response;
        }

        // Handle specific error cases
        if (response.status === 400) {
            console.error("Perplexity 400 Error Details:", response.data);
            throw new Error(`Perplexity API Error: ${response.data?.error?.message || 'Invalid request format'}`);
        } else if (response.status === 401) {
            throw new Error("Perplexity API Key is invalid or expired");
        } else if (response.status === 429) {
            throw new Error("Perplexity API rate limit exceeded. Please try again later.");
        } else if (response.status >= 500) {
            throw new Error("Perplexity service is temporarily unavailable");
        } else {
            throw new Error(`Perplexity API Error: ${response.status} - ${response.statusText}`);
        }

    } catch (error) {
        console.log("Perplexity API call failed, check callPerplexity:", error.message);
        throw error;
    }
}

module.exports = { callPerplexity };