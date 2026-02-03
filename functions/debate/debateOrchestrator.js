/**
 * Debate Orchestrator
 * Manages the debate state machine and coordinates between agents
 * Follows patterns from functions/agents/orchestrator.js
 */

const { DebateAgent } = require('./debateAgent');
const { FIXED_AGENT_CONFIG, DEBATE_STATES, DEBATE_CONFIG } = require('./debateConfig');
const { admin, db } = require('../utils/firebase');
const { UserMemory } = require('../utils/userMemory');

class DebateOrchestrator {
    constructor(openaiApiKey) {
        this.openaiApiKey = openaiApiKey;
    }

    async runDebate(debateConfig, userId, debateId) {
        const { dilemma, customAgent } = debateConfig;

        // Initialize agents
        const fixedAgent = new DebateAgent(this.openaiApiKey, FIXED_AGENT_CONFIG);
        const customAgentInstance = new DebateAgent(this.openaiApiKey, customAgent);

        // Get user context for personalization
        const userContext = await this._getUserContext(userId);

        const debateRef = db.collection('Users').doc(userId).collection('debates').doc(debateId);

        try {
            // Update state to opening
            await debateRef.update({
                state: DEBATE_STATES.OPENING,
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });

            const turns = [];
            let currentPhase = 'opening';
            let turnNumber = 1;

            // Opening: Fixed agent goes first
            console.log(`Debate ${debateId}: Starting opening phase`);

            const openingTurn = await fixedAgent.generateTurn(
                dilemma,
                [],
                turnNumber,
                currentPhase,
                userContext
            );

            const firstTurn = {
                turnNumber: turnNumber,
                agentType: 'fixed',
                agentName: FIXED_AGENT_CONFIG.name,
                text: openingTurn,
                phase: currentPhase,
                timestamp: admin.firestore.FieldValue.serverTimestamp()
            };

            turns.push(firstTurn);
            await this._saveTurn(debateRef, firstTurn);
            turnNumber++;

            // Update state to exchange
            await debateRef.update({
                state: DEBATE_STATES.EXCHANGE,
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });

            // Main debate loop
            while (turnNumber <= DEBATE_CONFIG.maxTurns) {
                // Determine phase
                if (turnNumber <= 2) {
                    currentPhase = 'opening';
                } else if (turnNumber <= DEBATE_CONFIG.maxTurns - 1) {
                    currentPhase = 'deepening';
                } else {
                    currentPhase = 'resolution';
                }

                // Alternate between custom and fixed agent
                const isCustomAgentTurn = turnNumber % 2 === 0;
                const currentAgent = isCustomAgentTurn ? customAgentInstance : fixedAgent;
                const agentType = isCustomAgentTurn ? 'custom' : 'fixed';
                const agentName = isCustomAgentTurn ? customAgent.name : FIXED_AGENT_CONFIG.name;

                console.log(`Debate ${debateId}: Turn ${turnNumber}, Phase: ${currentPhase}, Agent: ${agentName}`);

                const turnText = await currentAgent.generateTurn(
                    dilemma,
                    turns,
                    turnNumber,
                    currentPhase,
                    userContext
                );

                const turn = {
                    turnNumber: turnNumber,
                    agentType: agentType,
                    agentName: agentName,
                    text: turnText,
                    phase: currentPhase,
                    timestamp: admin.firestore.FieldValue.serverTimestamp()
                };

                turns.push(turn);
                await this._saveTurn(debateRef, turn);
                turnNumber++;
            }

            // Generate summary
            await debateRef.update({
                state: DEBATE_STATES.SUMMARY,
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });

            console.log(`Debate ${debateId}: Generating summary`);
            const summary = await this._generateSummary(dilemma, turns, userContext);

            // Complete the debate
            await debateRef.update({
                state: DEBATE_STATES.COMPLETE,
                status: 'completed',
                summary: summary,
                totalTurns: turns.length,
                completedAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });

            console.log(`Debate ${debateId}: Completed successfully`);

            return {
                success: true,
                turns: turns,
                summary: summary
            };

        } catch (error) {
            console.error(`Debate ${debateId}: Error during debate:`, error);

            await debateRef.update({
                state: DEBATE_STATES.ERROR,
                status: 'error',
                error: error.message,
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });

            throw error;
        }
    }

    async _saveTurn(debateRef, turn) {
        await debateRef.collection('turns').add(turn);

        // Update debate doc with latest turn info
        await debateRef.update({
            currentTurn: turn.turnNumber,
            currentPhase: turn.phase,
            lastTurnText: turn.text,
            lastTurnAgent: turn.agentName,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
    }

    async _getUserContext(userId) {
        try {
            const userMemory = new UserMemory(userId);
            const memoryContext = await userMemory.buildMemoryContext();

            return {
                currentFocus: memoryContext.currentFocus || "Not set",
                recentWins: memoryContext.recentWins?.map(w => w.content).join(", ") || "None recorded",
                engagementLevel: memoryContext.engagementLevel || "Unknown"
            };
        } catch (error) {
            console.error('Error fetching user context:', error);
            return {
                currentFocus: "Not set",
                recentWins: "None recorded",
                engagementLevel: "Unknown"
            };
        }
    }

    async _generateSummary(dilemma, turns, userContext) {
        const { ChatOpenAI } = require("@langchain/openai");
        const { PromptTemplate } = require("@langchain/core/prompts");
        const { StringOutputParser } = require("@langchain/core/output_parsers");

        const model = new ChatOpenAI({
            openAIApiKey: this.openaiApiKey,
            modelName: "gpt-4o",
            temperature: 0.5
        });

        const summaryPrompt = PromptTemplate.fromTemplate(`
            You are summarizing a debate about a user's dilemma.

            ORIGINAL DILEMMA:
            {dilemma}

            DEBATE TRANSCRIPT:
            {transcript}

            Generate a helpful summary in the following JSON format ONLY (no other text):
            {{
                "criticKeyPoints": ["point1", "point2", "point3"],
                "customAgentKeyPoints": ["point1", "point2", "point3"],
                "suggestedAction": "A specific, actionable next step based on the debate",
                "insight": "One key insight or reframe from the debate"
            }}

            RULES:
            - Keep each key point to 1 sentence
            - The suggested action must be concrete and doable this week
            - The insight should be something non-obvious that emerged from the debate
            - Return ONLY valid JSON, no markdown or explanation
        `);

        const chain = summaryPrompt.pipe(model).pipe(new StringOutputParser());

        const transcript = turns.map(t => `${t.agentName}: ${t.text}`).join("\n\n");

        const response = await chain.invoke({
            dilemma: dilemma,
            transcript: transcript
        });

        try {
            const jsonMatch = response.match(/\{[\s\S]*\}/);
            if (jsonMatch) {
                return JSON.parse(jsonMatch[0]);
            }
            return JSON.parse(response);
        } catch (error) {
            console.error('Error parsing summary JSON:', error);
            return {
                criticKeyPoints: ["Summary generation failed"],
                customAgentKeyPoints: ["Please review the debate turns directly"],
                suggestedAction: "Reflect on the debate and decide your next step",
                insight: "The debate raised important considerations"
            };
        }
    }
}

module.exports = { DebateOrchestrator };
