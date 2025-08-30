const { onCall } = require("firebase-functions/v2/https");
const axios = require("axios");
const { defineSecret } = require('firebase-functions/params');

const openaiApiKey = defineSecret('OPENAI_API_KEY');

const generateGreeting = onCall(
    {
        secrets: [openaiApiKey],
    },
    async () => {
        const apiKey = process.env.OPENAI_API_KEY;
        if (!apiKey) throw new Error("OPENAI_API_KEY missing in generateGreeting.js");

        const response = await axios.post(
        "https://api.openai.com/v1/chat/completions",
        {
          model: "gpt-4o-mini",
          messages: [
            {
                role: "system",
                content: "You are a motivational coach."
            },
            {
                role: "user",
                content: "Give one blunt, powerful no-bullshit greeting for hardcore hustlers"
            }
          ],
          max_tokens: 50,
          temperature: 0.76
        },
        {
            headers:
                {
                    Authorization: `Bearer ${apiKey}`
                }
        });

        const text = response.data.choices?.[0]?.message?.content?.trim() || "";
        console.log("Greeting generated from OpenAI: ", text);

        if (!text) throw new Error("Empty OpenAI response");

        return { text };          // returning a text object
    }
);

module.exports = { generateGreeting };