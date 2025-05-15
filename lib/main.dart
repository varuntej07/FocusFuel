import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:focus_fuel/ViewModels/auth/login_vm.dart';
import 'package:focus_fuel/ViewModels/auth/signup_vm.dart';
import 'package:provider/provider.dart';
import 'Views/Auth/login_page.dart';
import 'firebase_options.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);


  try{
    // Tells Android what small icon to show in the notification bar
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('notification_icon');
    final InitializationSettings settings = InitializationSettings(android: androidSettings);
    await flutterLocalNotificationsPlugin.initialize(settings);
  } catch (e) {
    print('Error initializing FlutterLocalNotificationsPlugin: $e');
  }

  // Create channel for Android as all notifications must be assigned to a channel
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel', 'High Importance Notifications',
    importance: Importance.high,    // sound will play, notification shows as a heads-up banner (not silent)
  );

  // registers the channel defined above with the Android system and ensures that the OS knows about the 'high_importance_channel'
  await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // Background msg handler (must be top-level)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
      MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => SignupViewModel()),
            ChangeNotifierProvider(create: (_) => LoginViewModel())
          ],
          child: const MyApp()
      )
  );
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Login(),
    );
  }
}