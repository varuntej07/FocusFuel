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

    async generateNotification(userProfile, timeContext, recentNotifications = []) {
        const productivityPrompt = PromptTemplate.fromTemplate(`
            You are a savvy mentor who sparks FOMO with exclusive insider facts and tips. You're like an insider friend sharing hidden gems that everyone successful is using,
            mixing curiosity with actionable value to push users toward their goals.

            User Profile:
            - user name : {username}
            - Primary Goal: {primaryGoal}
            - Current Time: {currentTime}
            - subInterests: {subInterests}

            CRITICAL - Previous Notifications to AVOID (DO NOT repeat these insights/advice):
            {previous_notifications}

            Your job: Create FOMO to make them tap the notification and start a chat session where the AI coach can personalize, practice, or ask follow-ups on the revealed tip.
            IMPORTANT: Generate completely NEW and DIFFERENT advice that has NOT been covered in the previous notifications above.

            Rules:
            - Do not explicitly include time references in the text
            - Every notification must be hyper-specific, create FOMO and relate to their goals/subInterests
            - Base insights on real, well-known stats, techniques, or methods from reliable sources (e.g., Harvard Business Review stats, common productivity hacks like Pomodoro)—be confident and accurate.
            - Your goal is to make users intrigued and want to click on it. Dont just say click me or something rather provide resources and insider facts
            - keep the notification under 200 tokens

            REQUIRED: Concrete action verb + revealed specific tool/method/technique + FOMO hook + call to tap for personalization/practice

            Example:
            - User primary goal is 'Career Advancement'
            {{"title": "Land Dream Clients", "content": "Top CEOs use this pitch: 'I can solve your biggest challenge with my proven strategy-let's discuss how..' Everyone's landing deals with it. Wanna try your pitch?"}}

            - User primary goal is 'Health & Fitness'
            {{"title": "Burn Fat Fast", "content": "Fitness gurus love HIIT: 30-sec sprints, 30-sec rest for 10 mins. It’s trending for quick results—tap to get a custom workout plan!"}}

            Strictly No explanations. No Markdown. Return ONLY valid JSON in this format:
            {{"title": "2-3 word action verb", "content": "Specific task with exact steps that user might not know"}}
        `);

        const chain = productivityPrompt.pipe(this.model).pipe(new StringOutputParser());

        // Format recent notifications for context
        const formattedRecentNotifs = recentNotifications.map((n, i) =>
            `${i+1}. ${n.title}: ${n.content}`
        ).join("\n");

        const response = await chain.invoke({
            username: userProfile.username,
            primaryGoal: userProfile.primaryGoal || "improve productivity",
            subInterests: userProfile.subInterests?.join(", ") || "",
            currentTime: timeContext.currentTime,
            previous_notifications: formattedRecentNotifs || "None yet—start a new sequence.",
        });

        return response.trim();
    }
}

module.exports = { ProductivityAgent };