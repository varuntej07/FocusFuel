const axios = require("axios");

async function callOpenAI(options) {

    const OPENAI_API_KEY = process.env.OPENAI_API_KEY;

    if (!OPENAI_API_KEY) {
        console.log("OpenAI API key is not configured. Please set it in your environment variables.");
    }

    let attempt = 0;
    let lastErr;
    const maxAttempts = 3;

    while (attempt < maxAttempts) {
        try {
            const response = await axios.post(
                "https://api.openai.com/v1/chat/completions",
                options,
                {
                    headers: {
                        "Content-Type": "application/json",
                        "Authorization": "Bearer " + OPENAI_API_KEY,
                    },
                    timeout: 60000,
                    validateStatus: () => true,             // handle all statuses below
                }
            );

            if (response.status === 200) return response;

            // transient -> retry
            if (res.status === 429 || res.status >= 500) {
                throw new Error(`Transient OpenAI error: ${res.status}`);
            }

            // non-transient -> fail immediately
            throw new Error(response.data?.error?.message || `OpenAI error ${response.status}`);
        } catch (e) {
            lastErr = e;
            attempt++;
            if (attempt >= maxAttempts) break;

            await new Promise(r => setTimeout(r, 500 * Math.pow(2, attempt) + Math.random()*200));
        }
    }
    throw lastErr;
}

module.exports = { callOpenAI };