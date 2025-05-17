import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

class HomeViewModel extends ChangeNotifier{
  String? _username;
  int _streak = 0;
  String? _currentFocus;
  String _mood = 'Chill';

  String get username => _username ?? "Dude";
  int get streak => _streak;
  String get mood => _mood;
  String get currentFocus => _currentFocus ?? "None";

  Future<void> loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data();

    _username = data?['username'] ?? "Dude";
    _streak = data?['streak'] ?? 0;
    _currentFocus = data?['focus'];
    _mood = data?['mood'] ?? "Chill";

    notifyListeners();
  }

  void clear(){
    _username = null;
    _currentFocus = null;
    _streak = 0;
    _mood = "Chill";

    notifyListeners();
  }
}