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
             You are a learning coach sending a mobile notification to spark curiosity and skill development.
             Create ONE mobile notification that makes the user LEARN something new right now.

            User Profile:
            - Primary Goal: {primaryGoal}
            - Current Time: {currentTime}
            - subInterests: {subInterests}

            Your job: Make them DO something specific in the next 10 minutes that moves their goal forward.

            Rules:
            - Focus on skill-building, knowledge gaps, or curiosity triggers
            - NO vague advice. NO "consider doing". Tell them EXACTLY what to do.

            Strictly No explanations. No Markdown. 
            Return ONLY valid JSON in this format:
            {{"title": "Priority Check", "content": "Look at your to-do list. Circle the ONE thing that matters most today."}}
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