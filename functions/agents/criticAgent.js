const { ChatOpenAI } = require("@langchain/openai");
const { PromptTemplate } = require("@langchain/core/prompts");
const { StringOutputParser } = require("@langchain/core/output_parsers");

class CriticAgent {
    constructor(openaiApiKey) {
        this.model = new ChatOpenAI({
            openAIApiKey: openaiApiKey,
            modelName: "gpt-4o-mini",
            temperature: 0.3
        });
    }

    async validateNotification(notificationObj, userContext, agentType) {
        const criticPrompt = PromptTemplate.fromTemplate(`
            Validate and correct this notification. Always return improved version.
            If the user taps this below notification which yields in a chat with AI, is the user gonna seamlessly move forward chatting?

            Notification: {notification}
            Agent Type: {agentType}
            User Context: {userContext}

            VALIDATION CRITERIA:
            - Personalization: MUST start with user's first name (e.g., "Varun, why don't you...")
            - Tone: Casual, friendly, like talking to an accountability partner/friend. Use contractions (don't, you're, let's)
            - Actionability: Contains concrete next step with "wanna try?" or "want to?" or similar casual invite
            - Specificity: References user's actual goal/task naturally in conversation
            - Expert insight: Includes non-obvious tip/shortcut presented as friendly advice
            - Supportive: End with offer to help (e.g., "I'll help you out", "Let's do this", "I got you")
            - Length: Title 2-4 words, content <200 chars
            - Tap-worthiness: Creates urgency but in a friendly way

            STYLE EXAMPLES:
            - "Varun, spotted a gap in your learning approach—try spaced repetition. Early adopters see 40% better retention. Wanna give it a shot? I'll walk you through it"
            - "Hey Varun, your focus task needs momentum. Break it into 25-min sprints—it's working for 80% of devs. Want to try? I'll help you plan"

            Return ONLY valid JSON:
            {{"title": "[2-4 word casual title]", "content": "[friendly, personalized message under 200 chars using first name]", "reason": "[what was fixed or 'approved as-is']"}}
        `);

        const chain = criticPrompt.pipe(this.model).pipe(new StringOutputParser());

        const response = await chain.invoke({
            notification: JSON.stringify(notificationObj),
            agentType: agentType || "unknown",
            userContext: JSON.stringify(userContext)
        });

        try {
            const parsed = JSON.parse(response.trim());
            return {
                title: parsed.title,
                content: parsed.content,
                reason: parsed.reason || "Validated"
            };
        } catch (e) {
            console.error('Critic JSON parse failed:', e);
            return {
                title: notificationObj.title,
                content: notificationObj.content,
                reason: "Critic failed - using original notification"
            };
        }
    }
}

module.exports = { CriticAgent };