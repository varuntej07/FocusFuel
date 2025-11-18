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
            Simplify this notification to make it more human, friendly, and tap-worthy. Keep the core insight but make it conversational.

            Notification: {notification}
            Agent Type: {agentType}
            User Context: {userContext}

            VALIDATION CRITERIA:
            - Personalization: Start with "{username}," to make it personal
            - Simplicity: Make it simple and easy to understand - no jargon or complex sentences
            - Tone: like a friend who wants you to win
            - Actionability: End with a casual call-to-action like "tap now to get tips" or "want help with this?"

            STYLE TRANSFORMATION EXAMPLES:

            Before: {{"title": "Master LinkedIn", "content": "Utilize LinkedIn's 'Open to Work' feature strategically: 70% of recruiters actively search for candidates here. Position yourself as a top contender—tap now to refine your profile!"}}
            After: {{"title": "Master LinkedIn", "content": "{username}, have you utilized LinkedIn's 'Open to Work' feature? 70% of recruiters actively search for candidates there. Position yourself as a top contender - tap now to get tips to refine your profile!"}}

            Before: {{"title": "Abstract First", "content": "Write a 120-word abstract that locks your argument scope. It kills endless note-taking and forces clarity fast."}}
            After: {{"title": "Abstract First", "content": "{username}, why not write a 120-word abstract that locks your argument scope. It kills endless note-taking and forces clarity fast. I'm here for guidance!"}}

            Before: {{"title": "Land Dream Clients", "content": "Top CEOs use this pitch: 'I can solve your biggest challenge with my proven strategy-let's discuss how..' Everyone's landing deals with it. Wanna try your pitch?"}}
            After: {{"title": "Land Dream Clients", "content": "Top CEOs use this pitch: 'I can solve your biggest challenge with my proven strategy—let's discuss how.' What's ya pitch? Wanna try your pitch? HMU for tips!"}}

            Return ONLY valid JSON:
            {{"title": "[title]", "content": "[simplified, personalized message with {username}]", "reason": "[what was changed]"}}
        `);

        const chain = criticPrompt.pipe(this.model).pipe(new StringOutputParser());

        const response = await chain.invoke({
            notification: JSON.stringify(notificationObj),
            agentType: agentType || "unknown",
            userContext: JSON.stringify(userContext),
            username: userContext.username || "Dude"
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