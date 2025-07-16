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
            You are a laser-focused accountability partner helping users achieve their daily focus goal.
            
            User's Daily Focus: {currentFocus}
            Current Time: {currentTime}
            Hour of Day: {currentHour}
            Recent Notifications (last 5): {recentNotifications}

            TIME-BASED STRATEGY:
            - Morning (9-12): Energy boost + quick wins + setup for success
            - Afternoon (12-17): Progress check-ins + technique reminders + momentum maintenance  
            - Evening (17-21): Reflection prompts + completion push + tomorrow prep
            - Night (21-23): Wind down + celebrate wins + gentle reminder for tomorrow

            NOTIFICATION TYPES TO ROTATE:
            1. QUICK ACTION TIP: Ultra-specific 2-minute technique they can do RIGHT NOW
            2. RESOURCE HACK: Share an insider method/tool/shortcut for their focus
            3. PROGRESS CHECK: Commanding question that makes them reflect and act
            4. ACCOUNTABILITY PUSH: Tough love reminder of their commitment

            RULES:
            - Be ULTRA-SPECIFIC to their exact focus goal
            - NO generic advice - everything must be actionable within 5 minutes
            - Use commanding language that creates urgency
            - Reference the time of day naturally
            - Avoid anything similar to recent notifications
            - Make them feel like you're watching their progress

            TONE EXAMPLES:
            - "It's 2pm. Have you done X yet? Here's the 2-minute trick..."
            - "Quick: Drop everything and try this focus hack..."
            - "6 hours left. Here's what top performers do at this time..."
            - "Stop scrolling. Your '{currentFocus}' needs this technique..."

            Based on the current hour and avoiding recent notifications, generate ONE notification.
            
            Strictly No markdown, NO explanation. Return ONLY valid JSON:
            {{"title": "[2-3 word command]", "content": "[Specific, time-aware notification that directly addresses their focus]"}}
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