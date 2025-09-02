const { ChatOpenAI } = require("@langchain/openai");
const { PromptTemplate } = require("@langchain/core/prompts");
const { StringOutputParser } = require("@langchain/core/output_parsers");

class ToDoAgent {
    constructor(openaiApiKey) {
        this.model = new ChatOpenAI({
            openAIApiKey: openaiApiKey,
            modelName: "gpt-4o",
            temperature: 0.76
        });
    }

    async generateNotification(userProfile, timeContext, recentNotifications = []) {
        const todoPrompt = PromptTemplate.fromTemplate(`
            You are a ruthless but helpful task finisher. Produce ONE crisp micro-nudge that moves the user forward NOW with a concrete action + an expert mid-task insight most people miss.

            User Current Task TODO: {userTask};
            Task Type: {taskType};
            User Background Context: {taskProfile};
            Time Commitment: {timeCommitment};
            Current Learning Stage: {learningStage};
            Days Since Started: {daysSinceStarted};
            Current Time: {currentTime};
            Primary Goal: {primaryGoal};
            Recent Notifications user received: {recentNotifications};

            TIME-BASED COACHING:
            - Morning (9-15): Deep work research, strategic learning, new material
            - Evening (16-23): tackling complex problems, review, planning for tomorrow

            PERSONALIZATION RULES:
            - Always reference their specific background and context from {taskProfile}
            - Suggest learning actions that match their experience level
            - For learning tasks: focus on knowledge building, not completion pressure
            - For project tasks: focus on specific technical progress

            RULES:
            - Always give specific, actionable steps they can take right away, avoid recent notifications
            - Build excitement about their progress and potential
            Strictly No markdown, NO explanation. Return ONLY valid JSON:
            {{"title": "[2-4 words command]", "content": "[Specific learning todo action with expert insight]"}}

            FEW-SHOT EXAMPLES:
            Task="Build an agent that books calendar slots automatically",
            OUTPUT: {{"title":"Fake the Flow","content":"Mock the Google Calendar API with a JSON stub before wiring OAuth. You’ll catch 80% of logic bugs without ever touching Google’s throttling nightmare."}}

            Task="Host my personal clone clone online using Ollama to generate human like responses",
            OUTPUT: {{"title":"Edge First","content":"Try fetching top-k chunks locally and hitting OpenAI instead of dragging 2.8GB models into the cloud. Your latency drops, your wallet thanks you."}}

            Task="Improve pull-up strength",
            OUTPUT: {{"title":"Single Cue Video","content":"Film one top-set from the side and focus only on scapular retraction before elbow flexion; review immediately and note bar path—one cue per set beats random fixes."}}

            Task="Apply to Eventeny mobile role",
            OUTPUT: {{"title":"Metric Pitch","content":"Record a 60-second pitch tying your Flutter work to a product metric. Numbers anchor the story and beat generic skill lists."}}

            Task="Integrate OpenAI with my app notifications"
            OUTPUT: {{"title":"Cache It","content":"Memoize retrieval results for repeated queries. Without caching, you’ll spend tokens re-asking the model if 2+2=4 every five minutes."}}
        `);

        const chain = todoPrompt.pipe(this.model).pipe(new StringOutputParser());

        const response = await chain.invoke({
            userTask: userProfile.currentTask,
            taskType: userProfile.taskType,
            taskProfile: userProfile.taskProfile || "No profile available",
            timeCommitment: userProfile.timeCommitment || "30 minutes daily",
            learningStage: userProfile.learningStage,
            daysSinceStarted: userProfile.daysSinceStarted || 1,
            currentTime: timeContext.currentTime,
            primaryGoal: userProfile.primaryGoal || "skill development",
            recentNotifications: recentNotifications.map((n, i) =>
                `${i+1}. ${n.title}: ${n.content}`
            ).join("\n") || "None yet today"
        });

        return response.trim();
    }
}

module.exports = { ToDoAgent };