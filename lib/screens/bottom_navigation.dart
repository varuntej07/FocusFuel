import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({super.key});
  @override
  _BottomNavBarState createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  int _selectedIndex = 0;
  String? _fcmToken;

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
    );

    final token = await FirebaseMessaging.instance.getToken();      // returns the device's FCM registration token
    setState(() => _fcmToken = token);

    // Tokens can be refreshed for various reasons like: Re-installation, User clearing app data etc.,
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      setState(() => _fcmToken = newToken);
    });
  }

  void _onTap(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    final pages = [
      // Home page: Testing and displaying FCM token
      Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            'FCM Token:\n${_fcmToken ?? "Fetching..."}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ),
      ),
      const Center(child: Text('Chat', style: TextStyle(fontSize: 18))),
      const Center(child: Text('Settings', style: TextStyle(fontSize: 18))),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTap,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}