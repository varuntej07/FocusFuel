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
            - Actionability: Contains concrete next step (not vague)
            - Specificity: References user's actual goal/task
            - Expert insight: Includes non-obvious tip/shortcut
            - Tone: Commanding but not generic motivational fluff
            - expert insight: Non-obvious tip/shortcut
            - Tone: Commanding, not generic motivation
            - Length: Title 2-4 words, content <200 chars
            - Tap-worthiness: Creates urgency to open chat

            Return ONLY valid JSON:
            {{"title": "[2-4 word command]", "content": "[corrected notification under 200 chars]", "reason": "[what was fixed or 'approved as-is']"}}
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