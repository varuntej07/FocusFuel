const axios = require("axios");

const OPENAI_API_KEY = process.env.OPENAI_API_KEY;

async function callOpenAI(options) {
    if (!OPENAI_API_KEY) {
        console.log("OpenAI API key is not configured. Please set it in your environment variables.");
    }
    console.log("Calling OpenAI API with options:", options, "as the key is configured already")
    return await axios.post(
        "https://api.openai.com/v1/chat/completions",
        options,
        {
            headers: {
                "Content-Type": "application/json",
                "Authorization": "Bearer " + OPENAI_API_KEY,
            }
        }
    );
}

module.exports = { callOpenAI };