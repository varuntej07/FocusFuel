const { ChatOpenAI } = require("@langchain/openai");
const { PromptTemplate } = require("@langchain/core/prompts");
const { StringOutputParser } = require("@langchain/core/output_parsers");

/**
 * Progress Check Agent
 * Sends accountability and check-in notifications when user engagement is low
 * Two types: Mid-day check-in and Evening accountability
 */
class ProgressCheckAgent {
    constructor(openaiApiKey) {
        this.model = new ChatOpenAI({
            openAIApiKey: openaiApiKey,
            modelName: "gpt-4o-mini",
            temperature: 0.7
        });
    }

    async generateNotification(userProfile, timeContext, engagementMetrics, checkType = 'midday') {
        const progressPrompt = PromptTemplate.fromTemplate(`
            You are a caring accountability partner checking in on a user who hasn't been engaging with their productivity notifications.
            Your tone should be casual, friendly, and supportive - like a close friend texting.

            User Context:
            - Name: {username}
            - Current Focus: {currentFocus}
            - Primary Goal: {primaryGoal}
            - Task: {currentTask}
            - Check Type: {checkType}
            - Time: {currentTime}

            Engagement Context:
            - Consecutive Notifications Ignored: {consecutiveIgnored}
            - Hours Since Last Click: {hoursSinceLastClick}
            - Engagement Level: {engagementLevel}
            - Suggestion: {suggestion}

            CHECK TYPES:
            1. MIDDAY (2 PM): Quick, light check-in. "How's it going?" energy. Focus on current progress.
               - MUST start with their first name: "{username}, how's..."

            2. EVENING (8 PM): Gentle accountability. Reflective tone. Focus on closure and tomorrow.
               - MUST start with their first name: "{username}, wrapping up..."

            TONE REQUIREMENTS:
            - ALWAYS start with user's first name followed by comma (e.g., "Varun, how's it going?")
            - Use casual language and contractions (don't, you're, let's, wanna, gonna)
            - End with supportive offer: "I'll help you out", "I got you", "Let's do this", "Want to chat?"
            - Make it feel like a text from a friend who cares about their progress

            ENGAGEMENT LEVEL GUIDANCE:
            - very_low (5+ ignored): Extra gentle. Offer to help adjust approach.
            - low (3-4 ignored): Curious check-in. Ask if they need different support.
            - medium: Friendly nudge. Check progress and offer guidance.

            CRITICAL RULES:
            - MUST start with first name
            - Never guilt-trip or make user feel bad
            - Keep under 180 characters total
            - Use their exact focus/task naturally in conversation
            - If no focus/task, ask what they're working on
            - DO NOT use emojis or markdown

            Return ONLY valid JSON:
            {{"title": "[2-4 words, casual]", "content": "[Start with first name, casual check-in, offer to help]"}}

            EXAMPLES:

            Midday, low engagement, focus="Finish proposal":
            {{"title": "Quick Check", "content": "{username}, how's the proposal coming? Taking a break or deep in it? Either way, I'm here if you need help."}}

            Evening, very_low engagement, no focus set:
            {{"title": "You Good?", "content": "{username}, haven't heard from you today—everything okay? What are you working on? I'll help you plan if you want."}}

            Midday, medium engagement, focus="Study React hooks":
            {{"title": "Making Progress?", "content": "{username}, are React hooks clicking yet? If you're stuck, let's break it down together. I got you."}}

            Evening, low engagement, task="Build landing page":
            {{"title": "How'd It Go?", "content": "{username}, how'd the landing page turn out today? Even rough drafts count as progress. Wanna review tomorrow's plan?"}}
        `);

        const chain = progressPrompt.pipe(this.model).pipe(new StringOutputParser());

        const response = await chain.invoke({
            username: userProfile.username,
            currentFocus: userProfile.currentFocus || "your goals",
            primaryGoal: userProfile.primaryGoal || "productivity",
            currentTask: userProfile.task || "what you're working on",
            checkType: checkType === 'midday' ? 'Midday Check-in (2 PM)' : 'Evening Accountability (8 PM)',
            currentTime: timeContext.currentTime,
            consecutiveIgnored: engagementMetrics.consecutiveIgnored || 0,
            hoursSinceLastClick: engagementMetrics.hoursSinceLastClick ?
                `${engagementMetrics.hoursSinceLastClick.toFixed(1)} hours` : 'never clicked',
            engagementLevel: engagementMetrics.engagementLevel || 'unknown',
            suggestion: engagementMetrics.suggestion || 'Be supportive and curious'
        });

        return response.trim();
    }
}

module.exports = { ProgressCheckAgent };
