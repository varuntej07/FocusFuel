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
  final DateTime? accountCreatedOn;

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

  // subscription fields
  final bool isSubscribed;
  final DateTime? trialStartDate;
  final DateTime? trialEndDate;
  final String? subscriptionStatus;  // "trial" | "free" | "premium" | "pending_payment" | "cancelled" | "expired"
  final int dailyNotificationCount;
  final DateTime? lastNotificationCountReset;
  final int dailyChatQueryCount;
  final DateTime? lastChatQueryReset;

  // Razorpay subscription fields
  final String? razorpayCustomerId;
  final String? razorpaySubscriptionId;
  final String? subscriptionPlanId;
  final String? razorpaySubscriptionStatus;  // Razorpay subscription status
  final DateTime? subscriptionCreatedAt;
  final DateTime? nextBillingDate;
  final DateTime? cancelledAt;

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
    this.accountCreatedOn,

    this.dailyScreenTime,
    this.mostUsedApp,
    this.primaryInterests,
    this.specificInterests,
    this.ageRange,
    this.primaryGoal,
    this.motivationStyle,
    this.preferredNotificationTime,
    this.onboardingCompleted = false,

    required this.isSubscribed,
    this.trialStartDate,
    this.trialEndDate,
    this.subscriptionStatus,
    this.dailyNotificationCount = 0,
    this.lastNotificationCountReset,
    this.dailyChatQueryCount = 0,
    this.lastChatQueryReset,

    this.razorpayCustomerId,
    this.razorpaySubscriptionId,
    this.subscriptionPlanId,
    this.razorpaySubscriptionStatus,
    this.subscriptionCreatedAt,
    this.nextBillingDate,
    this.cancelledAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      username: data['username'] ?? 'User',
      isActive: data['isActive'] ?? true,
      streak: (data['streak'] ?? 0) as int,
      longestStreak: (data['longestStreak'] ?? 0) as int,
      currentFocus: data['currentFocus'],
      weeklyGoal: data['weeklyGoal'],
      focusUpdatedAt: data['focusUpdatedAt']?.toDate(),
      weeklyGoalUpdatedAt: data['weeklyGoalUpdatedAt']?.toDate(),
      lastLogin: data['lastLogin']?.toDate(),
      createdAt: data['createdAt']?.toDate(),
      updatedAt: data['updatedAt']?.toDate(),
      accountCreatedOn: data['accountCreatedOn']?.toDate(),
      notificationInterval: data['notificationInterval'] ?? 30,
      lastNotificationTime: data['lastNotificationTime']?.toDate(),
      notificationsEnabled: data['notificationsEnabled'] ?? true,
      dailyScreenTime: data['dailyScreenTime'],
      mostUsedApp: data['mostUsedApp'],
      primaryInterests: data['primaryInterests']?.cast<String>(),
      specificInterests: data['specificInterests']?.cast<String>(),
      ageRange: data['ageRange'],
      primaryGoal: data['primaryGoal'],
      motivationStyle: data['motivationStyle'],
      preferredNotificationTime: data['preferredNotificationTime'],
      onboardingCompleted: data['onboardingCompleted'] ?? false,
      isSubscribed: data['isSubscribed'] ?? false,
      trialStartDate: data['trialStartDate']?.toDate(),
      trialEndDate: data['trialEndDate']?.toDate(),
      subscriptionStatus: data['subscriptionStatus'],
      dailyNotificationCount: data['dailyNotificationCount'] ?? 0,
      lastNotificationCountReset: data['lastNotificationCountReset']?.toDate(),
      dailyChatQueryCount: data['dailyChatQueryCount'] ?? 0,
      lastChatQueryReset: data['lastChatQueryReset']?.toDate(),

      razorpayCustomerId: data['razorpayCustomerId'],
      razorpaySubscriptionId: data['razorpaySubscriptionId'],
      subscriptionPlanId: data['subscriptionPlanId'],
      razorpaySubscriptionStatus: data['razorpaySubscriptionStatus'],
      subscriptionCreatedAt: data['subscriptionCreatedAt']?.toDate(),
      nextBillingDate: data['nextBillingDate']?.toDate(),
      cancelledAt: data['cancelledAt']?.toDate(),
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
      'accountCreatedOn': accountCreatedOn,
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
      'isSubscribed': isSubscribed,
      'trialStartDate': trialStartDate,
      'trialEndDate': trialEndDate,
      'subscriptionStatus': subscriptionStatus,
      'dailyNotificationCount': dailyNotificationCount,
      'lastNotificationCountReset': lastNotificationCountReset,
      'dailyChatQueryCount': dailyChatQueryCount,
      'lastChatQueryReset': lastChatQueryReset,
      'razorpayCustomerId': razorpayCustomerId,
      'razorpaySubscriptionId': razorpaySubscriptionId,
      'subscriptionPlanId': subscriptionPlanId,
      'razorpaySubscriptionStatus': razorpaySubscriptionStatus,
      'subscriptionCreatedAt': subscriptionCreatedAt,
      'nextBillingDate': nextBillingDate,
      'cancelledAt': cancelledAt,
    };
  }

  // Helper methods for trial management
  int get remainingTrialDays {
    if (trialEndDate == null) return 0;
    final now = DateTime.now();
    final difference = trialEndDate!.difference(now).inDays;
    return difference > 0 ? difference : 0;
  }

  bool get isTrialExpired {
    if (trialEndDate == null) return true;
    return DateTime.now().isAfter(trialEndDate!);
  }

  bool get isTrialActive {
    return subscriptionStatus == 'trial' && !isTrialExpired;
  }

  bool get isPremiumUser {
    return subscriptionStatus == 'premium';
  }

  bool get isFreeUser {
    return subscriptionStatus == 'free';
  }

  String get subscriptionStatusDisplay {
    if (isPremiumUser) return 'Premium';
    if (isTrialActive) return 'Trial ($remainingTrialDays days left)';
    return 'Free';
  }
}