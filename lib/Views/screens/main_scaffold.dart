import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:focus_fuel/Views/screens/menu_page.dart';
import '../../main.dart';
import 'chat_screen.dart';
import 'home_page.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  String userName = '';

  @override
  void initState() {
    super.initState();
    _setupFcm();
  }

  // requesting permission from the user to send notifications, then fetch FCM token
  Future<void> _setupFcm() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      carPlay: true,
    );

    final token = await FirebaseMessaging.instance.getToken(); // returns the device's FCM registration token

    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({'fcmToken':token}, SetOptions(merge: true));

    // Tokens can be refreshed for various reasons like: Re-installation, User clearing app data etc.,
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .set({'fcmToken':newToken}, SetOptions(merge: true));
    });

    // listens for messages only when the app is in foreground (open)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification; // extracts the actual notification details
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
            notification.hashCode,
            // a unique ID so it doesn’t overwrite old ones
            notification.title, notification.body,
            const NotificationDetails(
              android: AndroidNotificationDetails( // configuration of how the notification appears (channel, sound, priority...)
                  'high_importance_channel', 'High Importance Notifications', // should match what's initialized in main.dart'
                  importance: Importance.high, priority: Priority.high
              ),
            )
        );
      }
    });
  }

  void _onTap(int index) => setState(() => _selectedIndex = index);

    @override
    Widget build(BuildContext context) {
      final pages = [
        const HomeFeed(),
        const ChatScreen(),
        const MenuPage()
      ];
      return Scaffold(
          body: pages[_selectedIndex],
          bottomNavigationBar: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: _onTap,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
                BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'More')
              ]
          )
      );
  }
}