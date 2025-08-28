const { ChatOpenAI } = require("@langchain/openai");
const { PromptTemplate } = require("@langchain/core/prompts");
const { StringOutputParser } = require("@langchain/core/output_parsers");

class ProductivityAgent {
    constructor(openaiApiKey) {
        this.model = new ChatOpenAI({
            openAIApiKey: openaiApiKey,
            modelName: "gpt-4o",
            temperature: 0.76
        });
    }

    async generateNotification(userProfile, timeContext) {
        const productivityPrompt = PromptTemplate.fromTemplate(`
            You are a no-bullshit productivity coach sending a mobile notification to help users take immediate action.
            Create ONE mobile notification that makes the user ACT NOW.

            User Profile:
            - Primary Goal: {primaryGoal}
            - Current Time: {currentTime}
            - subInterests: {subInterests}

            Your job: Make them start a specific 10-minute conversation or task that your AI coach can guide them through.

            Rules:
            - use strict tone, no fluff as if you are a strict coach sending a notification
            - Focus on task completion, organization, or priority setting. Tell them EXACTLY what to do.
            - Set clear expectation of what happens when they tap

            Example:
            - User primary goal is 'Career Advancement'
            {{"title": "[Practice right now]", "content": "[Master salary negotiation emails that average $18K raises - practice your pitch with AI coach now]"}}

            Strictly No explanations. No Markdown. Return ONLY valid JSON in this format:
            {{"title": "[2-3 word action verb]", "content": "[Specific task with exact steps that user might not know]"}}
            `);

        const chain = productivityPrompt.pipe(this.model).pipe(new StringOutputParser());

        const response = await chain.invoke({
            primaryGoal: userProfile.primaryGoal || "improve productivity",
            subInterests: userProfile.subInterests?.join(", ") || "",
            currentTime: timeContext.currentTime,
        });

        return response.trim();
    }
}

module.exports = { ProductivityAgent };