class UserModel {
  final String uid;
  final String email;
  final String username;
  final bool isActive;
  final int streak;
  final int longestStreak;

  UserModel({
    required this.uid,
    required this.email,
    required this.username,
    required this.isActive,
    this.streak = 0,
    this.longestStreak = 0,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'],
      email: map['email'],
      username: map['username'],
      isActive: true,
      streak: (map['streak'] ?? 0) as int,
      longestStreak: (map['longestStreak'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'isActive': true,
      'streak': streak,
      'longestStreak': longestStreak,
    };
  }
}