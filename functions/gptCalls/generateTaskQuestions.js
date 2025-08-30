const {onCall, HttpsError} = require("firebase-functions/v2/https");
const { callOpenAI } = require("../utils/openai");
const { defineSecret } = require('firebase-functions/params');

const openaiApiKey = defineSecret('OPENAI_API_KEY');

const generateTaskQuestions = onCall(
    {
        secrets: [openaiApiKey],
    },
    async (request) => {
        try {
            const { prompt } = request.data; // Extract prompt from request parameter

            if (!prompt) {
                throw new HttpsError('Prompt is required for task questions, check ya input');
            }

            const openAIOptions = {
                model: "gpt-4o",
                messages: [
                    {
                        role: "system",
                        content: "You are an AI assistant specialized in task analysis. Always follow the user's instructions exactly. NEVER use markdown formatting."
                    },
                    {
                        role: "user",
                        content: prompt
                    }
                ],
                max_tokens: 800,
                temperature: 0.7
            };

            const response = await callOpenAI(openAIOptions);
            let aiResponse = response.data.choices[0].message.content;

            let parsedResponse;

            // Check if we're expecting JSON (for questions)
            if (prompt.toLowerCase().includes('question') && prompt.toLowerCase().includes('json')) {
                try {
                    parsedResponse = JSON.parse(aiResponse);
                    return {
                        success: true,
                        response: aiResponse,
                        parsedData: parsedResponse
                    };
                } catch (parseError) {
                    console.log('Failed to parse as JSON response:');
                    throw new HttpsError('internal', 'Invalid JSON response');
                }
            } else {
                // for summaries, just return plain text
                return {
                    success: true,
                    response: aiResponse.trim()
                };
            }
        } catch (error) {
              console.error('Error in generateTaskQuestions:', error);

              if (error instanceof HttpsError) {
                  throw error;
              }

              throw new HttpsError('internal', 'Failed to generate task questions from OpenAI');
        }
    }
);

module.exports = { generateTaskQuestions };