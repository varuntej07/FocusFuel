const { ProductivityAgent } = require('./productivityAgent');
const { FocusAgent } = require('./focusAgent');
const { ToDoAgent } = require('./todoAgent');
const admin = require('firebase-admin');
const { CalendarAgent } = require('./calendarAgent');
const { CriticAgent } = require('./criticAgent');

class NotificationOrchestrator {
    constructor(openaiApiKey) {
        this.openaiApiKey = openaiApiKey;
        this.agents = {                                      // Initializing all agents with OpenAI API key
            productivity: new ProductivityAgent(openaiApiKey),
            focus: new FocusAgent(openaiApiKey),
            todo: new ToDoAgent(openaiApiKey),
            calendar: new CalendarAgent(openaiApiKey),
        };
    }

    // userProfile is the whole data object from getUserProfile(uid)
    async generateSmartNotification(userProfile, timeContext, recentNotifications) {
        try {
            let selectedAgentType;
            let agent;
            let enhancedUserProfile = { ...userProfile };           // creates a new object with all same properties as userProfile, but they're independent.

            // Checking for active tasks in UserTasks collection
            const activeTask = await this.getActiveUserTask(userProfile.uid);

            // Determine notification priority based on user state
            const hasFocus = userProfile.currentFocus && userProfile.currentFocus.trim() !== '';
            const hasWeeklyGoal = userProfile.weeklyGoal && userProfile.weeklyGoal.trim() !== '';
            const hasActiveTask = userProfile.task && userProfile.task.trim() !== "";

            console.log(`Starting notification generation using orchestrator for ${userProfile.username}...`);

            if (hasActiveTask) {
                selectedAgentType = 'todo';                 // P1: Active task from UserTasks collection -> TodoAgent
                agent = this.agents.todo;

                enhancedUserProfile = await this.enhanceProfileForTodoAgent(userProfile);     // Enhance user profile with task data when using todo agent
                console.log('Active task detected, using ToDoAgent with enhanced profile');
            } else if (hasFocus) {
                selectedAgentType = 'focus';                // P2: User daily focus -> FocusAgent
                agent = this.agents.focus;
                console.log('CurrentFocus detected, using FocusAgent');
            } else{
                const historyResult = this.selectAgentFromHistory(userProfile.historySummary);
                selectedAgentType = historyResult.agentType;
                enhancedUserProfile = { ...userProfile, ...historyResult.enhancedProfile };
                agent = this.agents[selectedAgentType];

                console.log(`No dashboard entries found, using history-based ${selectedAgentType} agent`);
            }

            // Ensure I have a valid agent, so falling back to productivity if somehow null
            if (!agent) {
                console.log(`Agent ${selectedAgentType} not found, falling back to productivity`);
                selectedAgentType = 'productivity';
                agent = this.agents.productivity;
            }

            // Generate notification with selected agent 
            let notification;

            if (selectedAgentType === 'todo') {
               // ToDoAgent needs enhanced profile with task data
               notification = await agent.generateNotification(enhancedUserProfile, timeContext, recentNotifications);
            } else if (selectedAgentType === 'focus') {
               // FocusAgent needs recent notifications to avoid redundancy
               notification = await agent.generateNotification(enhancedUserProfile, timeContext, recentNotifications);
            } else {
               notification = await agent.generateNotification(enhancedUserProfile, timeContext);
            }

            console.log(`Generated ${selectedAgentType} notification: ${notification}...`);

            // Parsing the JSON string from agent
            let parsedNotification;
            try {
                const jsonMatch = notification.match(/\{.*\}/s);
                parsedNotification = JSON.parse(jsonMatch ? jsonMatch[0] : notification);
            } catch (e) {
                console.error('Failed to parse agent notification:', e);
                parsedNotification = { title: "Focus Now", content: notification };
            }

            console.log('Validating notification using a critic agent...');

            const critic = new CriticAgent(this.openaiApiKey);
            const critique = await critic.validateNotification(
                parsedNotification,
                {
                     focus: userProfile.currentFocus || "User have no active focus set today",
                     task: userProfile.currentTask || "User have no active task set today"
                },
                selectedAgentType
            );

            // Use critic's output (which always returns corrected version)
            const finalNotification = {
                title: critique.title,
                content: critique.content
            };

            console.log(`Critic feedback: ${critique.reason}`);

            return {
                notification: JSON.stringify(finalNotification), // Return as JSON string (expected by sendNotifications.js)
                agentType: selectedAgentType,
                timestamp: new Date().toISOString(),
                criticReason: critique.reason
            };
        } catch (error) {
            console.error('Error in notification orchestrator:', error);

            // Fallback notification with better error handling
            return {
                notification: JSON.stringify({
                    "title": "Stay Focused",
                    "content": "Check your goals and get your work done right now!"
                }),
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
            const snapshot = await tasksRef                     // requires a composite indexing in firebase
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
    async enhanceProfileForTodoAgent(userProfile) {
        const taskContent = userProfile.task;
        const daysSinceStarted = this.calculateDaysSinceStarted(userProfile.task?.timestamp);

        return {
            ...userProfile,
            currentTask: taskContent,
            taskProfile: userProfile.primaryGoal || "General productivity",
            daysSinceStarted: daysSinceStarted,            // default
            learningStage: this.determineLearningStage(daysSinceStarted),
            taskType: this.categorizeTask(taskContent),
            timeCommitment: userProfile.task?.timeCommitment || "5 hours daily",
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
        if (daysSinceStarted <= 3) return 'foundation';
        else if (daysSinceStarted <= 7) return 'building';
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

    selectAgentFromHistory(historyContext) {
        const historySummary = historyContext?.historySummary || historyContext;
        if (!historySummary || historySummary.isEmpty) {
            return {
                agentType: 'productivity',
                enhancedProfile: {}
            };
        }

        // Use last focus/task to determine agent
        if (historySummary.lastTask) {
            return {
                agentType: 'todo',
                enhancedProfile: {
                    currentTask: historySummary.lastTask,
                    taskProfile: historySummary.summary,
                    daysSinceStarted: 1,
                    learningStage: 'building',
                    taskType: 'project'
                }
            };
        } else {
            console.log("Error fetching last task from historySummary")
        }

        if (historySummary.lastFocus) {
            return {
                agentType: 'focus',
                enhancedProfile: {
                    currentFocus: historySummary.lastFocus
                }
            };
        }

        return {
            agentType: 'productivity',
            enhancedProfile: {
                historyContext: historySummary.summary
            }
        };
    }
}

module.exports = { NotificationOrchestrator };