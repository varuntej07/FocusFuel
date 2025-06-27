class UserModel {
  final String uid;
  final String email;
  final String username;
  final bool isActive;
  final int streak;
  final int longestStreak;
  final String? currentFocus;
  final String? weeklyGoal;
  final DateTime? focusUpdatedAt;
  final DateTime? weeklyGoalUpdatedAt;
  final DateTime? lastLogin;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int notificationInterval;
  final DateTime? lastNotificationTime;
  final bool notificationsEnabled;

  // Onboarding fields for personalized notifications
  final String? dailyScreenTime;
  final String? mostUsedApp;
  final List<String>? primaryInterests;
  final List<String>? specificInterests;
  final String? ageRange;
  final String? primaryGoal;
  final String? motivationStyle;
  final String? preferredNotificationTime;
  final bool onboardingCompleted;

  UserModel({
    required this.uid,
    required this.email,
    required this.username,
    required this.isActive,
    this.streak = 0,
    this.longestStreak = 0,
    this.currentFocus,
    this.weeklyGoal,
    this.focusUpdatedAt,
    this.weeklyGoalUpdatedAt,
    this.lastLogin,
    this.createdAt,
    this.updatedAt,
    this.notificationInterval = 30,   // Default notification interval is 30 minutes
    this.lastNotificationTime,
    this.notificationsEnabled = true,

    this.dailyScreenTime,
    this.mostUsedApp,
    this.primaryInterests,
    this.specificInterests,
    this.ageRange,
    this.primaryGoal,
    this.motivationStyle,
    this.preferredNotificationTime,
    this.onboardingCompleted = false,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'],
      email: map['email'],
      username: map['username'],
      isActive: map['isActive'] ?? true,
      streak: (map['streak'] ?? 0) as int,
      longestStreak: (map['longestStreak'] ?? 0) as int,
      currentFocus: map['currentFocus'],
      weeklyGoal: map['weeklyGoal'],
      focusUpdatedAt: map['focusUpdatedAt']?.toDate(),
      weeklyGoalUpdatedAt: map['weeklyGoalUpdatedAt']?.toDate(),
      lastLogin: map['lastLogin']?.toDate(),
      createdAt: map['createdAt']?.toDate(),
      updatedAt: map['updatedAt']?.toDate(),
      notificationInterval: map['notificationInterval'] ?? 30,
      lastNotificationTime: map['lastNotificationTime']?.toDate(),
      notificationsEnabled: map['notificationsEnabled'] ?? true,
      dailyScreenTime: map['dailyScreenTime'],
      mostUsedApp: map['mostUsedApp'],
      primaryInterests: map['primaryInterests']?.cast<String>(),
      specificInterests: map['specificInterests']?.cast<String>(),
      ageRange: map['ageRange'],
      primaryGoal: map['primaryGoal'],
      motivationStyle: map['motivationStyle'],
      preferredNotificationTime: map['preferredNotificationTime'],
      onboardingCompleted: map['onboardingCompleted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'isActive': isActive,
      'streak': streak,
      'longestStreak': longestStreak,
      'currentFocus': currentFocus,
      'weeklyGoal': weeklyGoal,
      'focusUpdatedAt': focusUpdatedAt,
      'weeklyGoalUpdatedAt': weeklyGoalUpdatedAt,
      'lastLogin': lastLogin,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'notificationInterval': notificationInterval,
      'lastNotificationTime': lastNotificationTime,
      'notificationsEnabled': notificationsEnabled,
      'dailyScreenTime': dailyScreenTime,
      'mostUsedApp': mostUsedApp,
      'primaryInterests': primaryInterests,
      'specificInterests': specificInterests,
      'ageRange': ageRange,
      'primaryGoal': primaryGoal,
      'motivationStyle': motivationStyle,
      'preferredNotificationTime': preferredNotificationTime,
      'onboardingCompleted': onboardingCompleted,
    };
  }
}