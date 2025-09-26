const { ChatOpenAI } = require("@langchain/openai");
const { PromptTemplate } = require("@langchain/core/prompts");
const { StringOutputParser } = require("@langchain/core/output_parsers");

class ProductivityAgent {
    constructor(openaiApiKey) {
        this.model = new ChatOpenAI({
            openAIApiKey: openaiApiKey,
            modelName: "gpt-4o-mini",
            temperature: 0.6
        });
    }

    async generateNotification(userProfile, timeContext) {
        const productivityPrompt = PromptTemplate.fromTemplate(`
            You are a brutal mentor who calls out users when they slack. You're like a no-nonsense coach who mixes tough love with insider resources.
            The goal is to guilt, taunt, or pressure the user into tapping the notification and taking action.

            User Profile:
            - user name : {username}
            - Primary Goal: {primaryGoal}
            - Current Time: {currentTime}
            - subInterests: {subInterests}

            Your job: Make them start a specific 10-minute conversation or task that your AI coach can guide them through.

            Rules:
            - Do not explicitly include time references in the text
            - Every notification must be hyper-specific aggressive, taunting, sometimes insulting relating to their goals
            - Your goal is to make users intrigued and want to click on it. Dont just say click me or something rather provide resources and insider facts
            - keep the notification under 200 tokens
            REQUIRED: Concrete action verb + specific next step + expert insight

            Example:
            - User primary goal is 'Career Advancement'
            {{"title": "Practice right now", "content": "Master salary negotiation emails that average $18K raises - practice your pitch with AI coach now"}}

            Strictly No explanations. No Markdown. Return ONLY valid JSON in this format:
            {{"title": "2-3 word action verb", "content": "Specific task with exact steps that user might not know"}}
            `);

        const chain = productivityPrompt.pipe(this.model).pipe(new StringOutputParser());

        const response = await chain.invoke({
            username: userProfile.username,
            primaryGoal: userProfile.primaryGoal || "improve productivity",
            subInterests: userProfile.subInterests?.join(", ") || "",
            currentTime: timeContext.currentTime,
        });

        return response.trim();
    }
}

module.exports = { ProductivityAgent };