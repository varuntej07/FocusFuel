import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:focus_fuel/Views/screens/menu_page.dart';
import 'chat_screen.dart';
import 'home_page.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  String userName = '';

  @override
  void initState() {
    super.initState();
    _setupFcm();
  }

  // requesting permission from the user to send notifications, then fetch FCM token
  Future<void> _setupFcm() async {

    final token = await FirebaseMessaging.instance.getToken(); // returns the device's FCM registration token
    final uid = FirebaseAuth.instance.currentUser?.uid;   // If currentUser exists, get its uid; otherwise, uid is null.

    if (uid != null && token != null) {
      try {
        await FirebaseFirestore.instance
            .collection('Users').doc(uid)
            .set({'fcmToken': token}, SetOptions(merge: true));
      } catch (e) {
        // maybe log it, but never crash
        debugPrint("FCM token save skipped: $e");
      }
    }

    // Tokens can be refreshed for various reasons like: Re-installation, User clearing app data etc.,
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      await FirebaseFirestore.instance
          .collection("Users")
          .doc(uid)
          .set({'fcmToken':newToken}, SetOptions(merge: true));
    });
  }

  final List<Widget> _pages = [
    const HomeFeed(),
    const ChatScreen(),
    const MenuPage()
  ];

  void _onTap(int index) => setState(() => _selectedIndex = index);

  @override
    Widget build(BuildContext context) {
      return Scaffold(
          body: IndexedStack(   // Only changes which one is painted, doesn’t dispose/rebuild others
            index: _selectedIndex,
            children: _pages,
          ),
          bottomNavigationBar: BottomNavigationBar(
              backgroundColor: Colors.white,
              selectedItemColor: Colors.black87,
              unselectedItemColor: Colors.grey,
              currentIndex: _selectedIndex,
              onTap: _onTap,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
                BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'Menu')
              ]
          )
      );
  }
}