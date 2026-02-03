/**
 * Debate Stream Endpoint
 * SSE (Server-Sent Events) endpoint for real-time debate streaming
 * Follows Firebase Cloud Functions v2 patterns
 */

const { onRequest, HttpsError } = require('firebase-functions/v2/https');
const { admin, db } = require('../utils/firebase');
const { DebateStreamOrchestrator } = require('./debateStreamOrchestrator');
const { CUSTOM_AGENT_PRESETS, DEBATE_CONFIG } = require('./debateConfig');

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

// Increment debate counter after successful debate
async function incrementDebateCounter(userId) {
    console.log(`Incrementing debate counter for user ${userId}`);
    await db.collection('Users').doc(userId).update({
        dailyDebateCount: admin.firestore.FieldValue.increment(1)
    });
}

// Resolve custom agent config from preset ID
function resolveCustomAgent(customAgentId) {
    if (!customAgentId) {
        return CUSTOM_AGENT_PRESETS[0]; // Default to Motivator
    }

    const preset = CUSTOM_AGENT_PRESETS.find(p => p.id === customAgentId);
    return preset || CUSTOM_AGENT_PRESETS[0];
}

module.exports = {
    debateStream: onRequest(
        {
            secrets: ['OPENAI_API_KEY', 'ELEVENLABS_API_KEY'],
            timeoutSeconds: 540,    // 9 minutes max
            memory: '1GiB',
            cors: true,
            invoker: 'public'       // Allow public access at Cloud Run level
        },
        async (req, res) => {
            // Only allow POST requests
            if (req.method !== 'POST') {
                res.status(405).json({ error: 'Method not allowed' });
                return;
            }

            // Auth extraction - Parses Bearer <token> from header
            const authHeader = req.headers.authorization;
            if (!authHeader || !authHeader.startsWith('Bearer ')) {
                res.status(401).json({ error: 'Unauthorized - Missing token' });
                console.log('Missing user token to process debateStream! Caught in debateStream.js')
                return;
            }

            const idToken = authHeader.split('Bearer ')[1];

            let userId;
            try {
                const decodedToken = await admin.auth().verifyIdToken(idToken);         // validates token with Firebase Auth
                userId = decodedToken.uid;
            } catch (error) {
                console.error('Token verification failed:', error);
                res.status(401).json({ error: 'Unauthorized - Invalid token' });
                return;
            }

            // Extract request data from req.body
            const { dilemma, customAgentPresetId, debateId } = req.body;

            if (!dilemma || !debateId) {
                res.status(400).json({ error: 'Missing required fields: dilemma, debateId' });
                return;
            }

            // Validate dilemma length
            if (dilemma.trim().length < 10) {
                res.status(400).json({ error: 'Dilemma must be at least 10 characters' });
                return;
            }

            console.log(`Starting debate stream for user ${userId}, debate ${debateId}`);

            try {
                // Check debate limits
                const limitCheck = await checkDebateLimit(userId);
                if (!limitCheck.allowed) {
                    console.log(`User ${userId} debate limit reached: ${limitCheck.reason}`);
                    res.status(429).json({ error: limitCheck.reason });
                    return;
                }

                // Resolve custom agent
                const resolvedCustomAgent = resolveCustomAgent(customAgentPresetId);

                // Get or create debate document
                const debateRef = db.collection('Users').doc(userId).collection('debates').doc(debateId);
                const debateDoc = await debateRef.get();

                if (!debateDoc.exists) {
                    // Create debate document
                    await debateRef.set({
                        userId: userId,
                        dilemma: dilemma,
                        status: 'in_progress',
                        state: 'idle',
                        customAgent: {
                            id: resolvedCustomAgent.id,
                            name: resolvedCustomAgent.name,
                            tone: resolvedCustomAgent.tone,
                            personality: resolvedCustomAgent.personality
                        },
                        createdAt: admin.firestore.FieldValue.serverTimestamp(),
                        startedAt: admin.firestore.FieldValue.serverTimestamp(),
                        updatedAt: admin.firestore.FieldValue.serverTimestamp()
                    });
                } else {
                    // Update existing debate to in_progress
                    await debateRef.update({
                        status: 'in_progress',
                        state: 'idle',
                        startedAt: admin.firestore.FieldValue.serverTimestamp(),
                        updatedAt: admin.firestore.FieldValue.serverTimestamp()
                    });
                }

                // Set up SSE headers
                res.setHeader('Content-Type', 'text/event-stream');
                res.setHeader('Cache-Control', 'no-cache');
                res.setHeader('Connection', 'keep-alive');
                res.setHeader('X-Accel-Buffering', 'no'); // Disable nginx buffering

                // Send initial connection event
                res.write('event: connected\n');
                res.write('data: {"status":"connected"}\n\n');

                // Create orchestrator and stream debate
                const orchestrator = new DebateStreamOrchestrator(process.env.OPENAI_API_KEY);

                let debateCompleted = false;

                try {
                    for await (const event of orchestrator.streamDebate(
                        {
                            dilemma: dilemma,
                            customAgent: resolvedCustomAgent
                        },
                        userId,
                        debateId
                    )) {
                        // Send SSE event
                        res.write(`event: ${event.event}\n`);
                        res.write(`data: ${JSON.stringify(event.data)}\n\n`);

                        // Check if debate completed
                        if (event.event === 'debate_complete') {
                            debateCompleted = true;
                        }

                        // Handle connection close
                        if (res.writableEnded) {
                            console.log(`Client disconnected from debate ${debateId}`);
                            break;
                        }
                    }

                    // Increment counter only if debate completed successfully
                    if (debateCompleted) {
                        await incrementDebateCounter(userId);
                    }

                    // Send final done event
                    res.write('event: done\n');
                    res.write('data: {"status":"done"}\n\n');

                } catch (streamError) {
                    console.error(`Error during debate stream ${debateId}:`, streamError);

                    // Send error event
                    res.write('event: error\n');
                    res.write(`data: ${JSON.stringify({ message: streamError.message })}\n\n`);

                    // Update debate status
                    await debateRef.update({
                        status: 'error',
                        state: 'error',
                        error: streamError.message,
                        updatedAt: admin.firestore.FieldValue.serverTimestamp()
                    });
                }

                // End the response
                res.end();

            } catch (error) {
                console.error(`Error setting up debate stream:`, error);

                // If headers not sent yet, send error response
                if (!res.headersSent) {
                    res.status(500).json({
                        error: 'Failed to start debate stream',
                        message: error.message
                    });
                } else {
                    // Send error event
                    res.write('event: error\n');
                    res.write(`data: ${JSON.stringify({ message: error.message })}\n\n`);
                    res.end();
                }
            }
        }
    )
};
