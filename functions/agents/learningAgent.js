const { ChatOpenAI } = require("@langchain/openai");
const { PromptTemplate } = require("@langchain/core/prompts");
const { StringOutputParser } = require("@langchain/core/output_parsers");

class LearningAgent {
    constructor(openaiApiKey) {
        this.model = new ChatOpenAI({
            openAIApiKey: openaiApiKey,
            modelName: "gpt-4o",
            temperature: 0.76
        });
    }

    async generateNotification(userProfile, timeContext) {
        const learningPrompt = PromptTemplate.fromTemplate(`
            You are an expert notification creator sending mobile notifications to users and making them click (that results in a chat UI with you)
            to talk to you about their interests and goals.

            Here is the User Profile:
            - Primary Goal: {primaryGoal}
            - Current Time: {currentTime}
            - subInterests: {subInterests}

           RULES:
            - Make the notification using insider secrets, unbelievable hidden hacks, and exclusive premium resources that is valuable enough for the user to click.
            - Your goal is to make users intrigued and want to click on it. so make sure it is juicy and captivating. Dont just say click me or something.
            - keep the notification under 200 tokens

            Strictly No markdown, NO explanation. Return ONLY valid JSON:
            {{"title": "[Clear 2-3 word action]", "content": "[Irresistible curiosity-inducing notification message]"}}

            `);

        const chain = learningPrompt.pipe(this.model).pipe(new StringOutputParser());

        const response = await chain.invoke({
            subInterests: userProfile.subInterests?.join(", ") || "",
            primaryGoal: userProfile.primaryGoal || "",
            currentTime: timeContext.currentTime,
        });

        return response.trim();
    }
}

module.exports = { LearningAgent };