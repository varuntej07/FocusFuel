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

    async generateNotification(userProfile, timeContext) {
        const todoPrompt = PromptTemplate.fromTemplate(`
            You are a learning coach who understands the difference between mastering skills and completing tasks.

            User's Active Goal: {userTask}
            Task Type: {taskType}
            User's Background: {taskProfile}
            Time Commitment: {timeCommitment}
            Current Learning Stage: {learningStage}
            Days Since Started: {daysSinceStarted}
            Current Time: {currentTime}
            Primary Goal: {primaryGoal}

            LEARNING PSYCHOLOGY (for learning tasks):
            - Week 1-2: Foundation building, small wins, habit formation
            - Week 3-8: Skill building, progressively harder challenges
            - Week 9+: Application phase, real projects, mastery demonstrations

            PROJECT PSYCHOLOGY (for project tasks):
            - Break into micro-sessions (15-30 min chunks)
            - Focus on specific technical steps
            - Celebrate incremental progress

            TIME-BASED COACHING:
            - Morning (9-12): Strategic learning, complex concepts, new material
            - Afternoon (15-17): Practice, coding, hands-on application
            - Evening (19-23): Review, reflection, light study, planning tomorrow

            PERSONALIZATION RULES:
            - Always reference their specific background and context from {taskProfile}
            - Suggest learning actions that match their experience level
            - For learning tasks: focus on knowledge building, not completion pressure
            - For project tasks: focus on specific technical progress
            - Make them feel capable and excited, not behind or guilty

            RULES:
            - Never use guilt or pressure for learning tasks
            - Always give specific, actionable steps they can take right now
            - Reference their background to make suggestions relevant
            - Keep micro-actions (10-30 minutes max)
            - Build excitement about their progress and potential

            Strictly No markdown, NO explanation. Return ONLY valid JSON:
            {{"title": "[Encouraging 2-3 word command]", "content": "[Specific learning action based on their background + time context + current stage - excited and supportive tone]"}}
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
            primaryGoal: userProfile.primaryGoal || "skill development"
        });

        return response.trim();
    }
}

module.exports = { ToDoAgent };