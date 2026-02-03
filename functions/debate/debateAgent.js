/**
 * Debate Agent
 * Generates debate turns using LangChain and OpenAI
 * Follows patterns from functions/agents/focusAgent.js
 */

const { ChatOpenAI } = require("@langchain/openai");
const { PromptTemplate } = require("@langchain/core/prompts");
const { StringOutputParser } = require("@langchain/core/output_parsers");
const { SystemMessage, HumanMessage } = require("@langchain/core/messages");

class DebateAgent {
    constructor(openaiApiKey, agentConfig) {
        this.model = new ChatOpenAI({
            openAIApiKey: openaiApiKey,
            modelName: "gpt-4o",
            temperature: 0.7
        });
        this.agentConfig = agentConfig;
    }

    async generateTurn(dilemma, conversationHistory, turnNumber, phase, userContext = {}) {
        const phaseInstructions = this._getPhaseInstructions(phase, turnNumber);

        const debatePrompt = PromptTemplate.fromTemplate(`
            ${this.agentConfig.systemPrompt}

            CURRENT DEBATE CONTEXT:
            User's Dilemma: {dilemma}

            USER CONTEXT (use to personalize your response):
            - Current Focus: {currentFocus}
            - Recent Wins: {recentWins}
            - Engagement Level: {engagementLevel}

            CONVERSATION SO FAR:
            {conversationHistory}

            CURRENT PHASE: {phase}
            TURN NUMBER: {turnNumber}

            PHASE-SPECIFIC INSTRUCTIONS:
            {phaseInstructions}

            YOUR RESPONSE GUIDELINES:
            - Stay in character as {agentName}
            - Keep responses concise (2-4 sentences max)
            - Directly address what was said before
            - Push toward clarity and action
            - Be specific, not generic

            Now respond as {agentName}. Do not include any prefixes like "Agent:" - just respond directly.
        `);

        const chain = debatePrompt.pipe(this.model).pipe(new StringOutputParser());

        const formattedHistory = this._formatConversationHistory(conversationHistory);

        const response = await chain.invoke({
            dilemma: dilemma,
            conversationHistory: formattedHistory || "This is the opening of the debate.",
            phase: phase,
            turnNumber: turnNumber.toString(),
            phaseInstructions: phaseInstructions,
            agentName: this.agentConfig.name,
            currentFocus: userContext.currentFocus || "Not specified",
            recentWins: userContext.recentWins || "None recorded",
            engagementLevel: userContext.engagementLevel || "Unknown"
        });

        return response.trim();
    }

    /**
     * Stream a debate turn in real-time using LangChain's native streaming
     * @yields {string} Text tokens as they are generated
     */
    async* streamTurn(dilemma, conversationHistory, turnNumber, phase, userContext = {}) {
        const phaseInstructions = this._getPhaseInstructions(phase, turnNumber);
        const formattedHistory = this._formatConversationHistory(conversationHistory);

        const systemContent = `${this.agentConfig.systemPrompt}

CURRENT DEBATE CONTEXT:
User's Dilemma: ${dilemma}

USER CONTEXT (use to personalize your response):
- Current Focus: ${userContext.currentFocus || "Not specified"}
- Recent Wins: ${userContext.recentWins || "None recorded"}
- Engagement Level: ${userContext.engagementLevel || "Unknown"}

CONVERSATION SO FAR:
${formattedHistory || "This is the opening of the debate."}

CURRENT PHASE: ${phase}
TURN NUMBER: ${turnNumber}

PHASE-SPECIFIC INSTRUCTIONS:
${phaseInstructions}

YOUR RESPONSE GUIDELINES:
- Stay in character as ${this.agentConfig.name}
- Keep responses concise (2-4 sentences max)
- Directly address what was said before
- Push toward clarity and action
- Be specific, not generic

Now respond as ${this.agentConfig.name}. Do not include any prefixes like "Agent:" - just respond directly.`;

        const messages = [
            new SystemMessage(systemContent),
            new HumanMessage(`Please provide your response for turn ${turnNumber}.`)
        ];

        // Stream using LangChain's native streaming API
        const stream = await this.model.stream(messages);

        for await (const chunk of stream) {
            // LangChain returns AIMessageChunk objects with content property
            if (chunk.content) {
                yield chunk.content;
            }
        }
    }

    _getPhaseInstructions(phase, turnNumber) {
        switch (phase) {
            case 'opening':
                return `This is the OPENING phase.
                - Establish your initial position on the user's dilemma
                - Set the tone for the debate with a clear, provocative take
                - Ask one pointed question to draw out their thinking`;

            case 'deepening':
                return `This is the DEEPENING phase (Turn ${turnNumber}).
                - Build on or challenge what was just said
                - Go deeper into the nuances and trade-offs
                - Expose assumptions or blind spots
                - Keep pushing toward insight`;

            case 'resolution':
                return `This is the RESOLUTION phase.
                - Synthesize the key insights from the debate
                - Push for a concrete commitment or decision
                - Offer a clear recommendation based on the discussion
                - End with something actionable`;

            default:
                return 'Respond thoughtfully to continue the debate.';
        }
    }

    _formatConversationHistory(history) {
        if (!history || history.length === 0) {
            return "";
        }

        return history.map(turn => {
            const speaker = turn.agentType === 'fixed' ? 'Ruthless Critic' : 'Your Ally';
            return `${speaker}: ${turn.text}`;
        }).join("\n\n");
    }
}

module.exports = { DebateAgent };
