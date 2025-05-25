import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeViewModel extends ChangeNotifier{
  String? _username;
  int _streak = 0;
  String? _currentFocus;
  String _mood = 'Chill';

  // constructor that loads from preferences first
  HomeViewModel() {
    _loadUsernameFromPrefs();
  }

  // helper to pull data from SharedPreferences
  Future<void> _loadUsernameFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('username');
    if (saved != null && _username == null) {
      _username = saved;
      notifyListeners();
    }
  }

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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', _username!);

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