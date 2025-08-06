const { NotificationRouter } = require('./router');
const { ProductivityAgent } = require('./productivityAgent');
const { LearningAgent } = require('./learningAgent');
const { FocusAgent } = require('./focusAgent');
const { ToDoAgent } = require('./todoAgent');
const admin = require('firebase-admin');

class NotificationOrchestrator {
    constructor(openaiApiKey) {
        this.router = new NotificationRouter(openaiApiKey);  // Instantiates NotificationRouter, as this is gonna decide which agent to use
        this.agents = {                                      // Initializing all agents with OpenAI API key
            productivity: new ProductivityAgent(openaiApiKey),
            learning: new LearningAgent(openaiApiKey),
            focus: new FocusAgent(openaiApiKey),
            todo: new ToDoAgent(openaiApiKey),
        };
    }

    async generateSmartNotification(userProfile, timeContext, recentNotifications) {
        try {
            console.log('Starting notification generation using orchestrator...');

            let selectedAgentType;
            let agent;
            let enhancedUserProfile = { ...userProfile };           // creates a new object with all same properties as userProfile, but they're independent.

            // Checking for active tasks in UserTasks collection
            const activeTask = await this.getActiveUserTask(userProfile.uid);

            // Determine notification priority based on user state
            const hasFocus = userProfile.currentFocus && userProfile.currentFocus.trim() !== '';
            const hasWeeklyGoal = userProfile.weeklyGoal && userProfile.weeklyGoal.trim() !== '';
            const hasActiveTask = activeTask !== null;

            if (hasActiveTask) {
                // P1: Active task from UserTasks collection -> TodoAgent
                selectedAgentType = 'todo';
                agent = this.agents.todo;

                // Enhance user profile with task data when using todo agent
                enhancedUserProfile = await this.enhanceProfileWithTaskData(userProfile, activeTask);
                console.log('Active task detected, using ToDoAgent with enhanced profile');
            } else if (hasFocus) {
                //P2: User daily focus -> FocusAgent
                selectedAgentType = 'focus';
                agent = this.agents.focus;
                console.log('CurrentFocus detected, using FocusAgent');
            } else{
                // Nothing Set: Router decides which agent to use as router.selectAgent returns the agent type
                selectedAgentType = await this.router.selectAgent(userProfile, timeContext);
                console.log(`Router selected: ${selectedAgentType}`);

                // Get the appropriate agent from the agents map defined in our constructor above
                agent = this.agents[selectedAgentType];

                // If the router selected an agent that doesn't exist, fallback to productivity
                if (!agent) {
                    console.log(`Agent ${selectedAgentType} not found, falling back to productivity`);
                    selectedAgentType = 'productivity';  // Update selectedAgentType for consistency
                    agent = this.agents.productivity;
                }
            }

            // Generate notification with selected agent 
            let notification;

            if (selectedAgentType === 'focus') {
                // FocusAgent needs recent notifications to avoid redundancy
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

            // Fallback notification with better error handling
            return {
                notification: "Stay focused on your goals today! Check back later for personalized suggestions.",
                agentType: "fallback",
                timestamp: new Date().toISOString(),
                error: error.message
            };
        }
    }

    // Get the most recent active task for the user
    async getActiveUserTask(userId) {
        try {
            const tasksRef = admin.firestore().collection('UserTasks');
            const snapshot = await tasksRef
                .where('userId', '==', userId)
                .orderBy('timestamp', 'desc')
                .limit(1)
                .get();

            if (snapshot.empty) {
                console.log('No active tasks found for user');
                return null;
            }

            const taskDoc = snapshot.docs[0];
            const taskData = taskDoc.data();

            // Return structured task object with all necessary fields
            return {
                id: taskDoc.id,
                task: taskData.task,
                profile: taskData.profile,
                timestamp: taskData.timestamp,
                ...taskData
            };

        } catch (error) {
            console.error('Error fetching user task:', error);
            return null;
        }
    }

    // Enhance user profile with task-specific data for ToDoAgent
    async enhanceProfileWithTaskData(userProfile, activeTask) {
        const daysSinceStarted = this.calculateDaysSinceStarted(activeTask.timestamp);
        const learningStage = this.determineLearningStage(daysSinceStarted);

        return {
            ...userProfile,
            currentTask: activeTask.task,
            taskProfile: activeTask.profile,
            daysSinceStarted: daysSinceStarted,
            learningStage: learningStage,
            taskType: this.categorizeTask(activeTask.task)
        };
    }

    // Calculate days since task was started
    calculateDaysSinceStarted(timestamp) {
        if (!timestamp) return 1;

        // Handle both Firestore Timestamp and regular Date objects
        const taskDate = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
        const now = new Date();
        const diffTime = Math.abs(now - taskDate);
        const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

        return Math.max(diffDays, 1); // Minimum 1 day to avoid division by zero issues
    }

    // Determine learning stage based on days since task started
    determineLearningStage(daysSinceStarted) {
        if (daysSinceStarted <= 7) return 'foundation';         // 1 week
        else if (daysSinceStarted <= 14) return 'building';
        else return 'application';              // applying and mastering
    }

    // Categorize task type to determine coaching approach
    categorizeTask(task) {
        const learningKeywords = ['master', 'learn', 'understand', 'study', 'become expert'];
        const projectKeywords = ['build', 'complete', 'integrate', 'launch', 'develop', 'create', 'setting up', 'setup'];

        const taskLower = task.toLowerCase();

        if (learningKeywords.some(keyword => taskLower.includes(keyword))) {
            return 'learning';                  // Focus on knowledge acquisition and skill building
        } else if (projectKeywords.some(keyword => taskLower.includes(keyword))) {
            return 'project';                   // Focus on task completion and deliverables
        } else {
            return 'learning'; // default to learning approach
        }
    }
}

module.exports = { NotificationOrchestrator };