const { NotificationRouter } = require('./router');
const { ProductivityAgent } = require('./productivityAgent');
const { LearningAgent } = require('./learningAgent');

class NotificationOrchestrator {
    constructor(openaiApiKey) {
        this.router = new NotificationRouter(openaiApiKey);  // Instantiates NotificationRouter, as this is gonna decide which agent to use
        this.agents = {                                      // Initializing all agents with OpenAI API key
            productivity: new ProductivityAgent(openaiApiKey),
            learning: new LearningAgent(openaiApiKey),
            //news: new NewsAgent(openaiApiKey),
        };
    }

    async generateSmartNotification(userProfile, timeContext) {
        try {
            console.log('Starting notification generation using orchestrator...');

            // Router decides which agent to use as router.selectAgent returns the agent type
            const selectedAgentType = await this.router.selectAgent(userProfile, timeContext);
            console.log(`Router selected: ${selectedAgentType}`);

            // Get the appropriate agent from the agents map defined in our constructor above
            let agent = this.agents[selectedAgentType];

            // If the router selected an agent that doesn't exist, fallback to productivity
            if (!agent) {
                console.log(`Agent ${selectedAgentType} not found, falling back to productivity`);
                agent = this.agents.productivity;
            }

            // Generate notification with selected agent 
            let notification;
            notification = await agent.generateNotification(userProfile, timeContext);  // Calling agent' generateNotification method

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