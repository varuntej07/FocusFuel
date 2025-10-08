const { admin } = require("./firebase");
const db = admin.firestore();

/**
 * Engagement Tracker Utility
 * Analyzes user's notification interaction patterns
 */
class EngagementTracker {
    constructor(userId) {
        this.userId = userId;
    }

    /**
     * Get user's engagement metrics over the last 24 hours
     * Returns: {
     *   totalSent: number,
     *   totalClicked: number,
     *   clickRate: number (0-1),
     *   lastClickedAt: timestamp,
     *   consecutiveIgnored: number,
     *   hoursSinceLastClick: number,
     *   isEngaged: boolean
     * }
     */
    async getEngagementMetrics() {
        const now = new Date();
        const last24Hours = new Date(now.getTime() - 24 * 60 * 60 * 1000);

        try {
            // Get all notifications sent in last 24 hours
            const notificationsSnapshot = await db.collection('Notifications')
                .where('userId', '==', this.userId)
                .where('timestamp', '>=', last24Hours)
                .orderBy('timestamp', 'desc')
                .get();

            const notifications = notificationsSnapshot.docs.map(doc => ({
                id: doc.id,
                ...doc.data()
            }));

            const totalSent = notifications.length;
            const clickedNotifications = notifications.filter(n => n.clicked === true);
            const totalClicked = clickedNotifications.length;
            const clickRate = totalSent > 0 ? totalClicked / totalSent : 0;

            // Find last clicked notification
            const lastClicked = clickedNotifications.length > 0 ? clickedNotifications[0] : null;
            const lastClickedAt = lastClicked?.clickedAt || null;

            // Calculate consecutive ignored (from most recent backwards)
            let consecutiveIgnored = 0;
            for (const notif of notifications) {
                if (notif.clicked === true) break;
                consecutiveIgnored++;
            }

            // Hours since last click
            let hoursSinceLastClick = null;
            if (lastClickedAt) {
                const lastClickDate = lastClickedAt.toDate ? lastClickedAt.toDate() : new Date(lastClickedAt);
                hoursSinceLastClick = (now - lastClickDate) / (1000 * 60 * 60);
            }

            // Determine if user is engaged
            // Engaged if: clicked in last 12 hours OR click rate > 30% OR fewer than 3 consecutive ignored
            const isEngaged = (
                (hoursSinceLastClick !== null && hoursSinceLastClick < 12) ||
                clickRate > 0.3 ||
                consecutiveIgnored < 3
            );

            return {
                totalSent,
                totalClicked,
                clickRate,
                lastClickedAt,
                consecutiveIgnored,
                hoursSinceLastClick,
                isEngaged
            };

        } catch (error) {
            console.error('Error getting engagement metrics:', error);
            return {
                totalSent: 0,
                totalClicked: 0,
                clickRate: 0,
                lastClickedAt: null,
                consecutiveIgnored: 0,
                hoursSinceLastClick: null,
                isEngaged: true // Default to engaged to avoid spamming
            };
        }
    }

    /**
     * Check if user needs a progress check notification
     * Progress checks are sent only if user is disengaged
     */
    async shouldSendProgressCheck() {
        const metrics = await this.getEngagementMetrics();

        // Don't send progress check if user is engaged
        if (metrics.isEngaged) {
            return {
                shouldSend: false,
                reason: 'User is engaged with notifications'
            };
        }

        // Check if user is new (created less than 48 hours ago)
        const userDoc = await db.collection('Users').doc(this.userId).get();
        const userData = userDoc.data();

        if (userData.createdAt) {
            const createdDate = userData.createdAt.toDate ? userData.createdAt.toDate() : new Date(userData.createdAt);
            const hoursSinceCreation = (new Date() - createdDate) / (1000 * 60 * 60);

            if (hoursSinceCreation < 48) {
                return {
                    shouldSend: false,
                    reason: 'User is new (< 48 hours), give them time to adjust'
                };
            }
        }

        // Check if we've already sent a progress check recently
        const lastProgressCheck = await this.getLastProgressCheckTime();
        if (lastProgressCheck) {
            const hoursSinceProgressCheck = (new Date() - lastProgressCheck) / (1000 * 60 * 60);

            // Don't send progress checks more than twice a day (12 hour gap minimum)
            if (hoursSinceProgressCheck < 12) {
                return {
                    shouldSend: false,
                    reason: 'Progress check sent less than 12 hours ago'
                };
            }
        }

        return {
            shouldSend: true,
            reason: `User disengaged: ${metrics.consecutiveIgnored} consecutive ignored, ${metrics.hoursSinceLastClick?.toFixed(1) || 'never'} hours since last click`,
            metrics
        };
    }

    /**
     * Get the timestamp of the last progress check notification sent
     */
    async getLastProgressCheckTime() {
        try {
            const progressCheckSnapshot = await db.collection('Notifications')
                .where('userId', '==', this.userId)
                .where('generationContext.agentType', '==', 'progress_check')
                .orderBy('timestamp', 'desc')
                .limit(1)
                .get();

            if (progressCheckSnapshot.empty) {
                return null;
            }

            const lastProgressCheck = progressCheckSnapshot.docs[0].data();
            const timestamp = lastProgressCheck.timestamp;
            return timestamp.toDate ? timestamp.toDate() : new Date(timestamp);

        } catch (error) {
            console.error('Error getting last progress check time:', error);
            return null;
        }
    }

    /**
     * Get engagement context for agents
     * This provides context about user behavior for personalized messaging
     */
    async getEngagementContext() {
        const metrics = await this.getEngagementMetrics();

        let engagementLevel = 'high';
        if (metrics.consecutiveIgnored >= 5) {
            engagementLevel = 'very_low';
        } else if (metrics.consecutiveIgnored >= 3 || metrics.clickRate < 0.2) {
            engagementLevel = 'low';
        } else if (metrics.clickRate < 0.5) {
            engagementLevel = 'medium';
        }

        return {
            ...metrics,
            engagementLevel,
            suggestion: this.getEngagementSuggestion(engagementLevel, metrics)
        };
    }

    /**
     * Provide suggestions for agents based on engagement level
     */
    getEngagementSuggestion(level, metrics) {
        switch (level) {
            case 'very_low':
                return 'User seems disconnected. Use gentle, curious tone. Ask open-ended questions.';
            case 'low':
                return 'User engagement is low. Try different approach - more personal, less pushy.';
            case 'medium':
                return 'Mixed engagement. Maintain variety in notification types.';
            case 'high':
                return 'User is engaged. Continue current strategy with fresh content.';
            default:
                return 'Maintain balanced approach.';
        }
    }
}

module.exports = { EngagementTracker };
