const { ChatOpenAI } = require("@langchain/openai");
const { PromptTemplate } = require("@langchain/core/prompts");
const { StringOutputParser } = require("@langchain/core/output_parsers");

class LearningAgent {
    constructor(openaiApiKey) {
        this.model = new ChatOpenAI({
            openAIApiKey: openaiApiKey,
            modelName: "gpt-4o",
            temperature: 0.76
        });
    }

    async generateNotification(userProfile, timeContext) {
        const learningPrompt = PromptTemplate.fromTemplate(`
             You are a learning coach sending a mobile notification to spark curiosity and skill development.
             Create ONE mobile notification that makes the user LEARN something new right now.

            User Profile:
            - Primary Goal: {primaryGoal}
            - Current Time: {currentTime}
            - subInterests: {subInterests}

            
            Create ONE specific micro-learning task they can complete RIGHT NOW in 10 minutes or less.

            Requirements:
            - Give ONE concrete action with specific steps with serious tone
            - Make it immediately doable (no prep, no signup, no purchases)
            - Connect directly to their primary goal
            - Use specific resources, tools, or techniques
            - No generic advice - be precise and actionable

            Examples of GOOD tasks:
            - "Do you know doing this [specific topic] results in a better [specific results]"
            - "Read the first 3 pages of [specific document/article]"
            - "Write down 5 questions about [specific topic] you can't answer yet"
            - "Find and bookmark 2 code examples for [specific programming concept]"

            Strictly No markdown, NO explanation. Return ONLY valid JSON:
            {{"title": "[Clear 2-3 word action]", "content": "[Specific task they can do in 10 minutes with exact steps]"}}

            `);

        const chain = learningPrompt.pipe(this.model).pipe(new StringOutputParser());

        const response = await chain.invoke({
            subInterests: userProfile.subInterests?.join(", ") || "",
            primaryGoal: userProfile.primaryGoal || "",
            currentTime: timeContext.currentTime,
        });

        return response.trim();
    }
}

module.exports = { LearningAgent };