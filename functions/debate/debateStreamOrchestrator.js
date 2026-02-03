/**
 * Debate Stream Orchestrator
 * Manages streaming debate generation with real-time text and audio
 * Yields SSE events as debate progresses
 */

const { DebateAgent } = require('./debateAgent');
const { ElevenLabsClient } = require('./elevenLabsClient');
const { FIXED_AGENT_CONFIG, DEBATE_STATES, DEBATE_CONFIG } = require('./debateConfig');
const { admin, db } = require('../utils/firebase');
const { UserMemory } = require('../utils/userMemory');

class DebateStreamOrchestrator {
    constructor(openaiApiKey) {
        this.openaiApiKey = openaiApiKey;
        this.elevenLabsClient = new ElevenLabsClient();
    }

    /**
     * Stream a debate in real-time
     * @param {Object} debateConfig - Configuration with dilemma and customAgent
     * @param {string} userId - User ID
     * @param {string} debateId - Debate ID
     * @yields {Object} SSE events: turn_start, token, turn_end, audio_ready, debate_complete, error
     */
    async* streamDebate(debateConfig, userId, debateId) {
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
            let turnNumber = 1;

            // Main debate loop
            while (turnNumber <= DEBATE_CONFIG.maxTurns) {
                // Determine phase
                const currentPhase = this._determinePhase(turnNumber);

                // Alternate between fixed and custom agent
                const isFixedAgent = turnNumber % 2 === 1; // Odd turns = fixed agent
                const currentAgent = isFixedAgent ? fixedAgent : customAgentInstance;
                const agentType = isFixedAgent ? 'fixed' : 'custom';
                const agentName = isFixedAgent ? FIXED_AGENT_CONFIG.name : customAgent.name;
                const agentId = isFixedAgent ? FIXED_AGENT_CONFIG.id : customAgent.id;

                // Emit turn_start event
                yield {
                    event: 'turn_start',
                    data: {
                        turnNumber,
                        agentType,
                        agentName,
                        phase: currentPhase
                    }
                };

                // Stream the turn text
                let turnText = '';

                try {
                    for await (const token of currentAgent.streamTurn(
                        dilemma,
                        turns,
                        turnNumber,
                        currentPhase,
                        userContext
                    )) {
                        turnText += token;

                        // Emit token event
                        yield {
                            event: 'token',
                            data: {
                                turnNumber,
                                agentType,
                                text: token
                            }
                        };
                    }
                } catch (streamError) {
                    console.error(`Error streaming turn ${turnNumber}:`, streamError);
                    yield {
                        event: 'error',
                        data: {
                            message: 'Failed to generate turn',
                            turnNumber
                        }
                    };
                    throw streamError;
                }

                // Turn complete - save to Firestore
                const turn = {
                    turnNumber,
                    agentType,
                    agentName,
                    text: turnText,
                    phase: currentPhase,
                    timestamp: admin.firestore.FieldValue.serverTimestamp()
                };

                turns.push(turn);
                await this._saveTurn(debateRef, turn);

                // Emit turn_end event
                yield {
                    event: 'turn_end',
                    data: {
                        turnNumber,
                        agentType,
                        agentName,
                        fullText: turnText,
                        phase: currentPhase
                    }
                };

                // Generate audio in background
                // Don't await - let it generate while next turn starts
                this._generateAudioAsync(turnText, agentId, debateId, turnNumber, agentType)
                    .then(audioPath => {
                        if (audioPath) {
                            // Update turn with audio path
                            debateRef.collection('turns')
                                .where('turnNumber', '==', turnNumber)
                                .limit(1)
                                .get()
                                .then(snapshot => {
                                    if (!snapshot.empty) {
                                        snapshot.docs[0].ref.update({ audioStoragePath: audioPath });
                                    }
                                });
                        }
                    })
                    .catch(audioError => {
                        console.error(`Audio generation failed for turn ${turnNumber}:`, audioError);
                    });

                // Update debate state
                if (turnNumber === 1) {
                    await debateRef.update({
                        state: DEBATE_STATES.EXCHANGE,
                        updatedAt: admin.firestore.FieldValue.serverTimestamp()
                    });
                }

                turnNumber++;
            }

            // Generate summary
            await debateRef.update({
                state: DEBATE_STATES.SUMMARY,
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });

            yield {
                event: 'summary_start',
                data: { message: 'Generating summary' }
            };

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

            yield {
                event: 'debate_complete',
                data: {
                    totalTurns: turns.length,
                    summary: summary
                }
            };

        } catch (error) {
            console.error(`Error in debate stream ${debateId}:`, error);

            await debateRef.update({
                state: DEBATE_STATES.ERROR,
                status: 'error',
                error: error.message,
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });

            yield {
                event: 'error',
                data: {
                    message: error.message || 'An error occurred during the debate'
                }
            };

            throw error;
        }
    }

    _determinePhase(turnNumber) {
        if (turnNumber <= 2) {
            return 'opening';
        } else if (turnNumber <= DEBATE_CONFIG.maxTurns - 1) {
            return 'deepening';
        } else {
            return 'resolution';
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

    async _generateAudioAsync(text, agentId, debateId, turnNumber, agentType) {
        try {
            const audioPath = await this.elevenLabsClient.generateAndUploadAudio(
                text,
                agentId,
                debateId,
                turnNumber
            );
            return audioPath;
        } catch (error) {
            console.error(`Audio generation failed for turn ${turnNumber}:`, error);
            return null;
        }
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

module.exports = { DebateStreamOrchestrator };
