const { onCall } = require("firebase-functions/v2/https");
const { callPerplexity } = require("../utils/perplexity");

module.exports = {
    getNewsSummary: onCall(
        {
            secrets: ["PERPLEXITY_API_KEY"],
        },
        async (request) => {
            try {
                const { title, description, link, category } = request.data;

                if (!title) {
                    console.log('Article title not found');
                    throw new Error('Article title is required');
                }

                console.log(`Generating summary for article: ${title}`);

                // Create contextual prompt for Perplexity
                const prompt = buildSummaryPrompt(title, description, category);

                const perplexityOptions = {
                    model: "sonar",
                    messages: [
                        {
                            role: "system",
                            content: "You are a news briefing assistant. Research the topic thoroughly and provide a comprehensive, well-structured briefing that covers all key aspects: what happened, why it matters, key facts, context, and impact. Be clear, factual, and complete while staying concise."
                        },
                        {
                            role: "user",
                            content: prompt
                        }
                    ],
                    max_tokens: 700,
                    temperature: 0.3,
                    return_citations: false,
                    search_recency_filter: "week",
                    web_search_options: {
                        search_context_size: "low"
                    }
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
                console.error('Error in getNewsSummary function:', error);
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
    let prompt = `Find the latest news about: "${title}" and summarize the key facts that matter`;
    
    if (description) {
        prompt += `Description of the article: ${description}\n`;
    }
    
    return prompt;
}