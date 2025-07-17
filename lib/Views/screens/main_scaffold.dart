import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:focus_fuel/Views/screens/menu_page.dart';
import 'package:focus_fuel/Views/screens/news_feed.dart';
import 'chat_screen.dart';
import 'home_page.dart';


class MainScaffold extends StatefulWidget {
  final int initialIndex;

  const MainScaffold({super.key, this.initialIndex = 0}); // Default to home tab

  @override
  MainScaffoldState createState() => MainScaffoldState();
}

class MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _setupFcm();
    _selectedIndex = widget.initialIndex;
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
    const NewsFeed(),
    const ChatScreen(),
    const MenuPage(),
  ];

  void _onTap(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: IndexedStack(   // Only changes which one is painted, doesn’t dispose/rebuild others
          index: _selectedIndex,
          children: _pages,
        ),
        bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            selectedItemColor: Theme.of(context).primaryColor,
            unselectedItemColor: Theme.of(context).textTheme.bodyMedium?.color,
            currentIndex: _selectedIndex,
            onTap: _onTap,
            items: [
              BottomNavigationBarItem(
                  icon: ColorFiltered(
                    colorFilter: ColorFilter.mode(Theme.of(context).iconTheme.color!, BlendMode.srcIn),
                    child: Image.asset('lib/Assets/icons/home.png', width: 24, height: 24),
                  ),
                  label: 'Home'
              ),
              BottomNavigationBarItem(
                  icon: ColorFiltered(
                    colorFilter: ColorFilter.mode(Theme.of(context).iconTheme.color!, BlendMode.srcIn),
                    child: Image.asset('lib/Assets/icons/news.png', width: 24, height: 24),
                  ),
                  label: 'News'
              ),
              BottomNavigationBarItem(
                  icon: ColorFiltered(
                    colorFilter: ColorFilter.mode(Theme.of(context).iconTheme.color!, BlendMode.srcIn),
                    child: Image.asset('lib/Assets/icons/chat.png', width: 24, height: 24),
                  ),
                  label: 'Chat'
              ),
              BottomNavigationBarItem(
                  icon: ColorFiltered(
                    colorFilter: ColorFilter.mode(Theme.of(context).iconTheme.color!, BlendMode.srcIn),
                    child: Image.asset('lib/Assets/icons/menu.png', width: 24, height: 24),
                  ),
                  label: 'Menu'
              )
            ]
        )
    );
  }
}