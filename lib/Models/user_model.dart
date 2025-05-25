class UserModel {
  final String uid;
  final String email;
  final String username;
  final bool isActive;

  UserModel({
    required this.uid,
    required this.email,
    required this.username,
    required this.isActive
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'],
      email: map['email'],
      username: map['username'],
      isActive: true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'isActive': true,
    };
  }
}