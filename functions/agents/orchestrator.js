const { NotificationRouter } = require('./router');
const { ProductivityAgent } = require('./productivityAgent');
const { LearningAgent } = require('./learningAgent');
const { FocusAgent } = require('./focusAgent');

class NotificationOrchestrator {
    constructor(openaiApiKey) {
        this.router = new NotificationRouter(openaiApiKey);  // Instantiates NotificationRouter, as this is gonna decide which agent to use
        this.agents = {                                      // Initializing all agents with OpenAI API key
            productivity: new ProductivityAgent(openaiApiKey),
            learning: new LearningAgent(openaiApiKey),
            focus: new FocusAgent(openaiApiKey),
            //news: new NewsAgent(openaiApiKey),
        };
    }

    async generateSmartNotification(userProfile, timeContext, recentNotifications) {
        try {
            console.log('Starting notification generation using orchestrator...');

            let selectedAgentType;
            let agent;

            if (userProfile.currentFocus && userProfile.currentFocus.trim() !== '') {
                selectedAgentType = 'focus';
                agent = this.agents.focus;
                // If user has a current focus, using FocusAgent directly
                console.log('CurrentFocus detected, bypassing router and using FocusAgent');
            } else {
                // Router decides which agent to use as router.selectAgent returns the agent type
                selectedAgentType = await this.router.selectAgent(userProfile, timeContext);
                console.log(`Router selected: ${selectedAgentType}`);

                // Get the appropriate agent from the agents map defined in our constructor above
                agent = this.agents[selectedAgentType];

                // If the router selected an agent that doesn't exist, fallback to productivity
                if (!agent) {
                    console.log(`Agent ${selectedAgentType} not found, falling back to productivity`);
                    agent = this.agents.productivity;
                }
            }

            // Generate notification with selected agent 
            let notification;

            if (selectedAgentType === 'focus') {
                notification = await agent.generateNotification(userProfile, timeContext, recentNotifications);
            } else {
                notification = await agent.generateNotification(userProfile, timeContext);  // For other agents, not passing recent notifications
            }

            console.log(`Generated ${selectedAgentType} notification: ${notification}...`);

            return {
                notification: notification,
                agentType: selectedAgentType,
                timestamp: new Date().toISOString()
            };
        } catch (error) {
            console.error('Error in notification orchestrator:', error);

            // Fallback
            return {
                notification: "Fallback error in orchestrator, check again",
                agentType: "fallback",
                timestamp: new Date().toISOString(),
                error: error.message
              };
        }
    }
}

module.exports = { NotificationOrchestrator };