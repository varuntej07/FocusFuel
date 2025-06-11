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
    };
  }
}