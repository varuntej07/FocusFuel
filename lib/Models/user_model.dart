import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel{
  final String uid;
  final String email;
  final String username;

  UserModel({required this.uid, required this.email, required this.username});

  static Future<User?> register({
    required String email,
    required String password,
    required String username
  }) async {
    final auth = FirebaseAuth.instance;
    final db = FirebaseFirestore.instance;

    final credential = await auth.createUserWithEmailAndPassword(email: email, password: password);

    try{
      await db.collection('users').doc(credential.user!.uid).set({
        'uid': credential.user!.uid,
        'email': email,
        'username': username,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch(e){
      return null;
    }
    return credential.user;
  }

  static Future<UserModel?> login({
    required String email,
    required String password,
  }) async{
    final auth = FirebaseAuth.instance;
    final db = FirebaseFirestore.instance;

    final credentials = await auth.signInWithEmailAndPassword(email: email, password: password);

    final snap = await db.collection('users').doc(credentials.user!.uid).get();

    return UserModel(
      uid: snap.get('uid'),
      email: snap.get('email'),
      username: snap.get('username'),
    );
  }
}