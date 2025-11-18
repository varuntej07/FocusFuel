const { ChatOpenAI } = require("@langchain/openai");
const { PromptTemplate } = require("@langchain/core/prompts");
const { StringOutputParser } = require("@langchain/core/output_parsers");

class FocusAgent {
    constructor(openaiApiKey) {
        this.model = new ChatOpenAI({
            openAIApiKey: openaiApiKey,
            modelName: "gpt-4o",
            temperature: 0.5
        });
    }

    async generateNotification(userProfile, timeContext, recentNotifications = []) {
        const focusPrompt = PromptTemplate.fromTemplate(`
             You are a strict mentor who sparks FOMO with exclusive insider facts and hidden gems that everyone successful is using,
             mixing curiosity with actionable value to push users toward their goals.
                User Focus Today: {currentFocus}
                Current Time: {currentTime}
                Recent Notifications: {recentNotifications}

                TIME-BASED COACHING:
                - Morning (9-12): Setup, planning, and strategic preparation for {currentFocus}
                - Afternoon (13-18): Exact execution steps, tools, and active methods for {currentFocus}
                - Evening (19-23): Quick wins, reflection, and planning the next move for {currentFocus}

                PERSONALIZATION RULES:
                - Always reference their exact {currentFocus} and what user might be doing with the goal at the time of the day
                - CRITICAL: DO NOT repeat any insights, tips, or advice from recent notifications below. Generate completely NEW and DIFFERENT advice
                - Recent Notifications to AVOID: {recentNotifications}
                - Every notification must be hyper-specific, create FOMO and relate to their goals/subInterests
                - If you notice the recent notifications cover similar topics, take a completely different angle or aspect of {currentFocus}

                RULES:
                - Always include one expert-level trick, pitfall, or shortcut about {currentFocus}
                - Strictly No markdown, NO explanation. Return ONLY valid JSON:
                {{"title": "[2-3 word alerting command]", "content": "[Concrete focus action + expert insight in one friendly but commanding line]"}}

                FEW-SHOT EXAMPLES:
                Focus="Finish research draft"
                OUTPUT: {{"title":"Abstract First","content":"Write a 120-word abstract that locks your argument scope. It kills endless note-taking and forces clarity fast."}}

                Focus="Prepare Flutter interview"
                OUTPUT: {{"title":"Build a Pitch","content":"Record a 45-second screen demo of a widget you built. Rewatch it and cut fluff—tight demos impress more than memorized answers."}}

                Focus="Deep dive into LangChain"
                OUTPUT: {{"title":"One Tool Max","content":"Spin up an agent with just the Python REPL tool first. Too many tools early = hallucinations dressed as confidence."}}

                Focus="Gym workout tonight"
                OUTPUT: {{"title":"Single Cue","content":"Film one top set and focus only on bar path. One technical cue per set beats random form checks."}}

                Focus="Study transformer architectures"
                OUTPUT: {{"title":"Recall Then Compare","content":"Sketch the encoder-decoder diagram from memory for 10 minutes, then compare it with Vaswani’s paper and circle the gap."}}
           `);

        const chain = focusPrompt.pipe(this.model).pipe(new StringOutputParser());

        // Format recent notifications for context
        const formattedRecentNotifs = recentNotifications.map((n, i) => 
            `${i+1}. ${n.title}: ${n.content}`
        ).join("\n");
        console.log("Formatted Recent Notifs for the user is : ", formattedRecentNotifs);

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