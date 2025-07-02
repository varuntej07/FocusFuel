const { ChatOpenAI } = require("@langchain/openai");
const { PromptTemplate } = require("@langchain/core/prompts");
const { StringOutputParser } = require("@langchain/core/output_parsers");

class NotificationRouter {
    constructor(openaiApiKey) {
        this.model = new ChatOpenAI({  // Initialize OpenAI model with provided API key
            openAIApiKey: openaiApiKey,
            modelName: "gpt-4o",
            temperature: 0.76
        });
    }

    async selectAgent(userProfile, timeContext) {
        const routerPrompt = PromptTemplate.fromTemplate(`
            You are a smart expert notification router. Pick the best agent for a user to send a mobile notification.

            Context: {currentTime}
            User focus: {primaryGoal}

            Agents:
                - productivity: Goals, habits, focus
                - news: Breaking news, trends  
                - wellness: Health, mental breaks
                - learning: Skills, facts, growth

            Match user's goal when possible.
            Do not return any other text or explanation, Strictly return ONLY: productivity/news/wellness/learning
        `);

        // just creating the chain with the prompt and model pipe to invoke later with user context
        // StringOutputParser will parse the output to string excluding additional metadata
        const chain = routerPrompt.pipe(this.model).pipe(new StringOutputParser());

        console.log(`chain created for routing: ${routerPrompt.template}, ${chain}`);

        // Invoke the chain - PromptTemplate fills with the values from userProfile and timeContext
        const response = await chain.invoke({
            primaryGoal: userProfile.primaryGoal || "",
            currentTime: timeContext.currentTime,
        });

        console.log(`Router response: ${response}`);

        return response.trim().toLowerCase();
    }
}

module.exports = { NotificationRouter };