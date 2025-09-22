const { admin } = require("./firebase");
const db = admin.firestore();

class UserHistoryService {
  constructor(userId) {
    this.userId = userId;
    this.userRef = db.collection('Users').doc(userId);
  }

  // Saves a new focus entry to user's history
  async saveFocusToHistory(focusContent, category) {
    const focusData = {
      content: focusContent,
      category: category,
      enteredAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: this.getNextMidnight(),
      wasCompleted: false
    };

    return await this.userRef.collection('focusHistory').add(focusData);
  }

  // Gets recent focus entries for user
  async getRecentFocuses(limit = 10) {
    const snapshot = await this.userRef.collection('focusHistory')
      .orderBy('enteredAt', 'desc')
      .limit(limit)
      .get();

    return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
  }

  // Saves a new task to user's history
  async saveTaskToHistory(taskContent) {
    const taskData = {
      content: taskContent,
      enteredAt: admin.firestore.FieldValue.serverTimestamp(),
      completedAt: null,
      isActive: true
    };

    return await this.userRef.collection('taskHistory').add(taskData);
  }

  // Gets all active (incomplete) tasks for user
  async getActiveTasks() {
    const snapshot = await this.userRef.collection('taskHistory')
      .where('isActive', '==', true)
      .where('completedAt', '==', null)
      .get();

    return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
  }

  // Saves a new weekly goal to user's history
  async saveGoalToHistory(goalContent) {
    const goalData = {
      content: goalContent,
      enteredAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: this.getNextWeek(),
      wasAchieved: false
    };

    return await this.userRef.collection('goalHistory').add(goalData);
  }

  // Gets recent weekly goals for user
  async getRecentGoals(limit = 5) {
    const snapshot = await this.userRef.collection('goalHistory')
      .orderBy('enteredAt', 'desc')
      .limit(limit)
      .get();

    return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
  }

  // Saves a user win
  async saveWin(winContent) {
    const winData = {
      content: winContent,
      enteredAt: admin.firestore.FieldValue.serverTimestamp()
    };

    return await this.userRef.collection('wins').add(winData);
  }

  // Calculates tomorrow at midnight (focus expiration time)
  getNextMidnight() {
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    tomorrow.setHours(0, 0, 0, 0);
    return tomorrow;
  }

  // Calculates date 7 days from now (goal expiration time)
  getNextWeek() {
    const nextWeek = new Date();
    nextWeek.setDate(nextWeek.getDate() + 7);
    return nextWeek;
  }


  // Gets comprehensive history data for AI notification generation
  // Uses Promise.allSettled to handle individual failures gracefully
  async getUserHistoryContext() {
      try {
          // Fetch all history data in parallel - won't fail if one query fails
          const [recentFocuses, activeTasks, recentGoals] = await Promise.allSettled([
              this.getRecentFocuses(5),
              this.getActiveTasks(),
              this.getRecentGoals(3)
          ]);

          return {
              recentFocuses: recentFocuses.status === 'fulfilled' ? recentFocuses.value : [],
              activeTasks: activeTasks.status === 'fulfilled' ? activeTasks.value : [],
              recentGoals: recentGoals.status === 'fulfilled' ? recentGoals.value : [],

              // Extracting metadata for AI agent selection
              lastFocusCategory: recentFocuses.status === 'fulfilled' && recentFocuses.value[0]?.category || null,
              hasIncompleteTasks: activeTasks.status === 'fulfilled' && activeTasks.value.length > 0
          };
      } catch (error) {
          console.error('Error getting user history context:', error);
          return {
              recentFocuses: [],
              activeTasks: [],
              recentGoals: [],
              lastFocusCategory: null,
              hasIncompleteTasks: false
          };
      }
  }
}

module.exports = { UserHistoryService };