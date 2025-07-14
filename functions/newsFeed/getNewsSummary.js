const { onCall } = require("firebase-functions/v2/https");
const { callPerplexity } = require("../utils/perplexity");

module.exports = {
    getNewsSummary: onCall(
        {
            secrets: ["PERPLEXITY_API_KEY"],
        },
        async (request) => {
            try {
                // Authentication check
                if (!request.auth) {
                    throw new Error('Authentication required');
                }

                const { title, description, link, category } = request.data;

                if (!title) {
                    throw new Error('Article title is required');
                }

                console.log(`Generating summary for article: ${title}`);

                // Create contextual prompt for Perplexity
                const prompt = buildSummaryPrompt(title, description, category);

                const perplexityOptions = {
                    model: "llama-3.1-sonar-small-128k-online",
                    messages: [
                        {
                            role: "system",
                            content: "You are a news summary expert. Create concise, accurate summaries of news articles. Focus on key facts, context, and implications. Keep summaries between 150-250 words."
                        },
                        {
                            role: "user",
                            content: prompt
                        }
                    ],
                    max_tokens: 400,
                    temperature: 0.2,
                    return_citations: true,
                    search_recency_filter: "week" // Get recent context
                };

                const response = await callPerplexity(perplexityOptions);
                const summary = response.data.choices[0].message.content;
                const citations = response.data.citations || [];

                console.log(`Summary generated successfully for: ${title}`);

                return {
                    success: true,
                    summary: summary,
                    citations: citations,
                    originalTitle: title,
                    originalLink: link,
                    generatedAt: new Date().toISOString()
                };

            } catch (error) {
                console.error('Error in getNewsSummary:', error);
                return {
                    success: false,
                    error: error.message,
                    summary: null
                };
            }
        }
    )
};

function buildSummaryPrompt(title, description, category) {
    let prompt = `Please provide a comprehensive summary of this news article:\n\n`;
    prompt += `Title: ${title}\n`;
    
    if (description) {
        prompt += `Description: ${description}\n`;
    }
    
    if (category) {
        prompt += `Category: ${category}\n`;
    }
    
    prompt += `\nPlease include:\n`;
    prompt += `1. Key facts and main points\n`;
    prompt += `2. Important context or background\n`;
    prompt += `3. Potential implications or significance\n`;
    prompt += `4. Any relevant recent developments\n\n`;
    prompt += `Keep the summary concise but informative (150-250 words).`;
    
    return prompt;
}