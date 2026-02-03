/**
 * Process Debate Request
 * Cloud Function triggered when a new debate request is created
 * Follows patterns from functions/gptCalls/processGptRequests.js
 */

const { admin, db } = require('../utils/firebase');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { DebateOrchestrator } = require('./debateOrchestrator');
const { DEBATE_CONFIG, CUSTOM_AGENT_PRESETS } = require('./debateConfig');

// Check if user can start a new debate based on subscription and daily limits
async function checkDebateLimit(userId) {
    const userDoc = await db.collection('Users').doc(userId).get();
    const userData = userDoc.data();

    if (!userData) return { allowed: false, reason: 'User not found' };

    const subscriptionStatus = userData.subscriptionStatus || 'free';

    // Premium and trial users get higher limits
    if (subscriptionStatus === 'premium' || subscriptionStatus === 'trial') {
        const dailyDebateCount = userData.dailyDebateCount || 0;
        if (dailyDebateCount >= DEBATE_CONFIG.premiumUserDailyLimit) {
            return { allowed: false, reason: 'Daily limit reached for premium users' };
        }
        return { allowed: true };
    }

    // Free users: check daily limit
    const dailyDebateCount = userData.dailyDebateCount || 0;
    if (dailyDebateCount >= DEBATE_CONFIG.freeUserDailyLimit) {
        return { allowed: false, reason: 'Daily debate limit reached. Upgrade to Premium for more debates!' };
    }

    return { allowed: true };
}

// Increment debate counter after successful request
async function incrementDebateCounter(userId) {
    console.log(`Incrementing debate counter for user ${userId}`);
    await db.collection('Users').doc(userId).update({
        dailyDebateCount: admin.firestore.FieldValue.increment(1)
    });
}

// Get custom agent config from preset ID or custom config
function resolveCustomAgent(customAgentConfig) {
    if (!customAgentConfig) {
        return CUSTOM_AGENT_PRESETS[0]; // Default to Motivator
    }

    // If it's a preset ID, look it up
    if (typeof customAgentConfig === 'string') {
        const preset = CUSTOM_AGENT_PRESETS.find(p => p.id === customAgentConfig);
        return preset || CUSTOM_AGENT_PRESETS[0];
    }

    // If it's a full config object, use it directly
    if (customAgentConfig.id && customAgentConfig.systemPrompt) {
        return customAgentConfig;
    }

    // If it has a presetId, look it up
    if (customAgentConfig.presetId) {
        const preset = CUSTOM_AGENT_PRESETS.find(p => p.id === customAgentConfig.presetId);
        return preset || CUSTOM_AGENT_PRESETS[0];
    }

    return CUSTOM_AGENT_PRESETS[0];
}

module.exports = {
    processDebateRequest: onDocumentCreated(
        {
            document: 'DebateRequests/{requestId}',
            secrets: ['OPENAI_API_KEY', 'ELEVENLABS_API_KEY'],
            timeoutSeconds: 300,
            memory: "1GiB"
        },
        async (event) => {
            const snap = event.data;
            const requestData = snap.data();
            const { userId, dilemma, customAgent, debateId } = requestData;
            const requestId = event.params.requestId;

            console.log(`Processing debate request ${requestId} for user ${userId}`);

            try {
                // Check for duplicate requests
                const debateRef = db.collection('Users').doc(userId).collection('debates').doc(debateId);
                const debateDoc = await debateRef.get();

                if (debateDoc.exists) {
                    const debateData = debateDoc.data();
                    if (debateData.status === 'completed' || debateData.status === 'in_progress') {
                        console.log(`Debate ${debateId} already processed, skipping`);
                        await snap.ref.update({ status: 'duplicate' });
                        return;
                    }
                }

                // Check debate limits
                const limitCheck = await checkDebateLimit(userId);
                if (!limitCheck.allowed) {
                    console.log(`User ${userId} debate limit reached: ${limitCheck.reason}`);

                    await debateRef.update({
                        status: 'limit_reached',
                        error: limitCheck.reason,
                        updatedAt: admin.firestore.FieldValue.serverTimestamp()
                    });

                    await snap.ref.update({
                        status: 'limit_reached',
                        error: limitCheck.reason
                    });

                    return;
                }

                // Resolve custom agent config
                const resolvedCustomAgent = resolveCustomAgent(customAgent);

                // Update debate status to in_progress
                await debateRef.update({
                    status: 'in_progress',
                    startedAt: admin.firestore.FieldValue.serverTimestamp(),
                    updatedAt: admin.firestore.FieldValue.serverTimestamp()
                });

                // Update request status
                await snap.ref.update({ status: 'processing' });

                // Run the debate
                const orchestrator = new DebateOrchestrator(process.env.OPENAI_API_KEY);
                await orchestrator.runDebate(
                    {
                        dilemma: dilemma,
                        customAgent: resolvedCustomAgent
                    },
                    userId,
                    debateId
                );

                // Increment debate counter
                await incrementDebateCounter(userId);

                // Update request status
                await snap.ref.update({ status: 'completed' });

                console.log(`Debate request ${requestId} completed successfully`);

            } catch (error) {
                console.error(`Error processing debate request ${requestId}:`, error);

                // Update debate status to error
                const debateRef = db.collection('Users').doc(userId).collection('debates').doc(debateId);
                await debateRef.update({
                    status: 'error',
                    error: error.message,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp()
                });

                // Update request status
                await snap.ref.update({
                    status: 'error',
                    error: error.message
                });
            }
        }
    )
};
