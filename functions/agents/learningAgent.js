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
            You are a tough-love mentor who calls out users on their bullshit while providing killer resources. 
            You're like a strict dad who's been there, done that, and won't let his kid settle for mediocrity.

            Here is the User Profile:
            - Primary Goal: {primaryGoal}
            - Current Time: {currentTime}
            - subInterests: {subInterests}

             TIME-BASED APPROACH RULES:
            - Morning (9-12): Greet and challenge them to START with exclusive morning routines/tools that drives their goals by creating a plan for the day
            - Afternoon (12-17): Call out their midday slump + provide premium techniques/resources to achieve their goals
            - Evening (17-21):  Call out assuming what they would do at the given time at {currentTime} + Insider methods to salvage the day and dominate
            - Night (21-23): Brutal accountability about today's progress + Challenge their evening routine + exclusive prep secrets that set up tomorrow's

             NOTIFICATION PSYCHOLOGY:
            - Create urgency and mild guilt by challenging their expected current lazy behavior
            - Provide resources that has exclusive knowledge that user might be missing
            - Make them feel like they're behind and MUST catch up quick

           RULES:
            - Do not include time in the responses
            - Every notification must be hyper-specific relating to their goals
            - Make them feel the time pressure related to their goal progress
            - Your goal is to make users intrigued and want to click on it. Dont just say click me or something rather provide resources and insider facts
            - keep the notification under 200 tokens

            Strictly No markdown, NO explanation. Return ONLY valid JSON:
            {{"title": "[Clear 2-3 word action]", "content": "[Irresistible curiosity-inducing, resource-specific, spontaneous triggering goals focussed notification message]"}}

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