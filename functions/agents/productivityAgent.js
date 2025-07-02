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

            Your job: Make them finish, organize, or start something specific in the next 10 minutes that moves their goal forward.

            Rules:
            - Focus on task completion, organization, or priority setting.
            - NO vague advice. NO "consider doing". Tell them EXACTLY what to do.

            Strictly No explanations. No Markdown. 
            Return ONLY valid JSON in this format:
            {{"title": "Boost ya brain", "content": "Open your notes app. Write down the ONE thing you'll finish before lunch today."}}
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