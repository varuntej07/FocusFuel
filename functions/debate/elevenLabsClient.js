/**
 * ElevenLabs TTS Client
 * Generates voice audio from text and uploads to Firebase Storage
 * Phase 6: Voice enhancement for debates
 */

const axios = require('axios');
const { admin } = require('../utils/firebase');

// Default voice IDs for debate agents
const DEFAULT_VOICES = {
    ruthless_critic: 'onwK4e9ZLuTAKqWW03F9', // Daniel - deep authoritative voice
    motivator: 'EXAVITQu4vr4xnSDxMaL',        // Sarah - warm encouraging voice
    analyst: 'TxGEqnHWrfWFTfGW9XjX',          // Josh - calm measured voice
    dreamer: 'XB0fDUnXU5powFXDhCwa',          // Charlotte - expressive creative voice
    devil_advocate: 'pNInz6obpgDQGcFmaJgB'    // Adam - provocative contrarian voice
};

// Voice settings for consistent output
const DEFAULT_VOICE_SETTINGS = {
    stability: 0.5,
    similarity_boost: 0.75,
    style: 0.0,
    use_speaker_boost: true
};

class ElevenLabsClient {
    constructor() {
        this.apiKey = process.env.ELEVENLABS_API_KEY;
        this.baseUrl = 'https://api.elevenlabs.io/v1';
        this.storage = admin.storage().bucket();
    }

    /**
     * Generate audio from text and upload to Firebase Storage
     * @param {string} text - Text to convert to speech
     * @param {string} agentId - Agent ID for voice selection
     * @param {string} debateId - Debate ID for storage path
     * @param {number} turnNumber - Turn number for file naming
     * @returns {Promise<string>} Storage path of uploaded audio
     */
    async generateAndUploadAudio(text, agentId, debateId, turnNumber) {
        if (!this.apiKey) {
            console.log('ElevenLabs API key not configured, skipping audio generation');
            return null;
        }

        try {
            const voiceId = DEFAULT_VOICES[agentId] || DEFAULT_VOICES.ruthless_critic;
            const audioBuffer = await this._generateAudio(text, voiceId);
            const storagePath = await this._uploadToStorage(audioBuffer, debateId, turnNumber, agentId);

            return storagePath;
        } catch (error) {
            console.error('Error generating audio:', error.message);
            return null;
        }
    }

    /**
     * Call ElevenLabs TTS API
     */
    async _generateAudio(text, voiceId) {
        const url = `${this.baseUrl}/text-to-speech/${voiceId}`;

        const response = await axios.post(
            url,
            {
                text: text,
                model_id: 'eleven_multilingual_v2',
                voice_settings: DEFAULT_VOICE_SETTINGS
            },
            {
                headers: {
                    'Accept': 'audio/mpeg',
                    'Content-Type': 'application/json',
                    'xi-api-key': this.apiKey
                },
                responseType: 'arraybuffer',
                timeout: 30000
            }
        );

        return Buffer.from(response.data);
    }

    /**
     * Upload audio buffer to Firebase Storage
     */
    async _uploadToStorage(audioBuffer, debateId, turnNumber, agentId) {
        const fileName = `debates/${debateId}/turn_${turnNumber}_${agentId}.mp3`;
        const file = this.storage.file(fileName);

        await file.save(audioBuffer, {
            metadata: {
                contentType: 'audio/mpeg',
                metadata: {
                    debateId: debateId,
                    turnNumber: turnNumber.toString(),
                    agentId: agentId
                }
            }
        });

        return fileName;
    }

    /**
     * Get a signed URL for audio playback
     */
    async getSignedUrl(storagePath) {
        if (!storagePath) return null;

        const file = this.storage.file(storagePath);
        const [url] = await file.getSignedUrl({
            action: 'read',
            expires: Date.now() + 24 * 60 * 60 * 1000 // 24 hours
        });

        return url;
    }

    /**
     * Delete audio files for a debate (cleanup)
     */
    async deleteDebateAudio(debateId) {
        try {
            const [files] = await this.storage.getFiles({
                prefix: `debates/${debateId}/`
            });

            await Promise.all(files.map(file => file.delete()));
            console.log(`Deleted ${files.length} audio files for debate ${debateId}`);
        } catch (error) {
            console.error('Error deleting debate audio:', error.message);
        }
    }
}

module.exports = { ElevenLabsClient, DEFAULT_VOICES };
