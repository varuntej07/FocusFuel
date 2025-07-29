const { ChatOpenAI } = require("@langchain/openai");
const { PromptTemplate } = require("@langchain/core/prompts");
const { StringOutputParser } = require("@langchain/core/output_parsers");

class FocusAgent {
    constructor(openaiApiKey) {
        this.model = new ChatOpenAI({
            openAIApiKey: openaiApiKey,
            modelName: "gpt-4o",
            temperature: 0.76
        });
    }

    async generateNotification(userProfile, timeContext, recentNotifications = []) {
        const focusPrompt = PromptTemplate.fromTemplate(`
            You are a laser-focused notification generator, helping users achieve their daily focus goal by sending mobile notifications.

            User's Daily Focus: {currentFocus}
            Current Time: {currentTime}
            Hour of Day: {currentHour}
            Recent Notifications (last 5): {recentNotifications}

            TIME-BASED STRATEGY:
            - Morning (9-12): Setup with specific tools, apps, or techniques for {currentFocus}
            - Afternoon (13-18): Exact methods + productivity hacks + resources for achieving {currentFocus} effectively
            - Evening (19-21): Progress audits + Hard accountability questions + completion tactics {currentFocus}
            - Night (22-23): Quick wins reflection by asking what they accomplished + tone set to {currentFocus} for tomorrow

            NOTIFICATION TYPES TO ROTATE:
            1. TECHNIQUE HACK: Ultra-specific method/tool/app they can implement/work in 2 minutes
            2. RESOURCE DROP: Exact shortcut, website, template any resource that accelerates {currentFocus}
            3. ACCOUNTABILITY CHECK: Direct question that forces immediate action on {currentFocus}

            RULES:
            - Every word must relate to their EXACT {currentFocus} - no generic productivity advice
            - Always provide specific tools, websites, techniques, or resources they can use immediately
            - Use commanding language that demands action straight away
            - Make them want to tap the notification to chat and get more help with {currentFocus}

            Based on the current hour and avoiding recent notifications, generate ONE notification.
            
            Strictly No markdown, NO explanation. Return ONLY valid JSON like this:
            {{"title": "[2-3 word alerting command]", "content": "[Hyper-specific technique/resource/question about their exact currentFocus that makes them want to chat for more help]"}}
        `);

        const chain = focusPrompt.pipe(this.model).pipe(new StringOutputParser());

        // Format recent notifications for context
        const formattedRecentNotifs = recentNotifications.map((n, i) => 
            `${i+1}. ${n.title}: ${n.content}`
        ).join("\n");

        const response = await chain.invoke({
            currentFocus: userProfile.currentFocus,
            currentTime: timeContext.currentTime,
            currentHour: timeContext.currentHour,
            recentNotifications: formattedRecentNotifs || "None yet today"
        });

        return response.trim();
    }
}

module.exports = { FocusAgent };