const { admin } = require("./firebase");
const { ChatOpenAI } = require("@langchain/openai");
const { PromptTemplate } = require("@langchain/core/prompts");
const { StringOutputParser } = require("@langchain/core/output_parsers");

const db = admin.firestore();

class UserHistorySummaryService {
    constructor(userId, openaiApiKey) {
        this.userId = userId;
        this.userRef = db.collection('Users').doc(userId);
        this.model = new ChatOpenAI({
            openAIApiKey: openaiApiKey,
            modelName: "gpt-4o",
            temperature: 0.3
        });
    }

    async getUserHistorySummary() {
        try {
            const [focuses, tasks, goals] = await Promise.all([
                this.getHistory('focusHistory', 10),
                this.getHistory('taskHistory', 10),
                this.getHistory('goalHistory', 8)
            ]);

            // No history = empty summary
            if (focuses.length === 0 && tasks.length === 0 && goals.length === 0) {
                return {
                    summary: "New user with no activity history",
                    isEmpty: true
                };
            }

            // Generate AI summary using OpenAI
            const summary = await this.generateSummary(focuses, tasks, goals);

            return {
                summary: summary.trim(),
                isEmpty: false,
                lastFocus: focuses[0]?.content || null,             // Most recent for quick access
                lastTask: tasks[0]?.content || null
            };

        } catch (error) {
            console.error('Error generating summary:', error);
            return {
                summary: "Error loading user history",
                isEmpty: true
            };
        }
    }

    async generateSummary(focuses, tasks, goals) {
        const prompt = PromptTemplate.fromTemplate(`
            Extract productivity patterns from user data. Output format: concise statement of facts only.

            RECENT FOCUSES: {focuses}
            RECENT TASKS: {tasks}
            RECENT GOALS: {goals}

            Rules:
            List most recent focus/task/goal verbatim if present.
            Focus on most recent activity and patterns, keep it concise and actionable
            as this summary is going to be context for future mobile notifications.
        `);

        const chain = prompt.pipe(this.model).pipe(new StringOutputParser());

        return await chain.invoke({
            focuses: this.formatEntries(focuses),
            tasks: this.formatEntries(tasks),
            goals: this.formatEntries(goals)
        });
    }

    // Fetches recent entries from a specific history collection
    async getHistory(collection, limit) {
        const snapshot = await this.userRef.collection(collection)
            .orderBy('enteredAt', 'desc')
            .limit(limit)
            .get();

        return snapshot.docs.map(doc => doc.data());
    }

    // Formats history entries for AI prompt (human-readable list)
    formatEntries(entries) {
        if (entries.length === 0) return "None";

        // Take first 5 entries and format with date and content
        return entries.slice(0, 5).map((entry, i) => {
            const content = entry.content || entry.task || entry.goal || "No content";
            const date = this.formatDate(entry.enteredAt);
            return `${i + 1}. [${date}] ${content}`;
        }).join('\n');
    }

    // Converts Firestore timestamp to readable date string
    formatDate(timestamp) {
        if (!timestamp) return "Unknown";

        let date;
        if (timestamp.toDate && typeof timestamp.toDate === 'function') {
            date = timestamp.toDate();
        } else if (timestamp instanceof Date) {
            date = timestamp;
        } else {
            date = new Date(timestamp);
        }

        if (isNaN(date.getTime())) return "Invalid Date";
        return `${date.getMonth() + 1}/${date.getDate()}`;
    }
}

module.exports = { UserHistorySummaryService };