const axios = require("axios");
const { defineSecret } = require('firebase-functions/params');

async function callOpenAI(options) {

    const openaiApiKey = defineSecret('OPENAI_API_KEY');
    const OPENAI_API_KEY = openaiApiKey.value();

    if (!OPENAI_API_KEY) {
        console.log("OpenAI API key is not configured. Please set it in your environment variables.");
    }

    try {
        const response = await axios.post(
            "https://api.openai.com/v1/chat/completions",
            options,
            {
                headers: {
                    "Content-Type": "application/json",
                    "Authorization": "Bearer " + OPENAI_API_KEY,
                },
                timeout: 30000, // 30 second timeout
                validateStatus: function (status) {
                    // Don't throw for any status, we'll handle it manually
                    return true;
                }
            }
        );

        // Check if request was successful
        if (response.status === 200) {
            console.log("OpenAI API call successful");
            return response;
        }

        // Handle specific error cases
        if (response.status === 400) {
            console.error("OpenAI 400 Error Details:", response.data);
            throw new Error(`OpenAI API Error: ${response.data?.error?.message || 'Invalid request format'}`);
        } else if (response.status === 401) {
            throw new Error("OpenAI API Key is invalid or expired");
        } else if (response.status === 429) {
            throw new Error("OpenAI API rate limit exceeded. Please try again later.");
        } else if (response.status >= 500) {
            throw new Error("OpenAI service is temporarily unavailable");
        } else {
            throw new Error(`OpenAI API Error: ${response.status} - ${response.statusText}`);
        }

    } catch (error) {
        console.log(error);
        throw error; 
    }
}

module.exports = { callOpenAI };