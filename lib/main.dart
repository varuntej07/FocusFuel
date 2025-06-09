import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:focus_fuel/Utils/route_navigator.dart';
import 'package:focus_fuel/ViewModels/auth_vm.dart';
import 'package:focus_fuel/ViewModels/chat_vm.dart';
import 'package:focus_fuel/ViewModels/home_vm.dart';
import 'package:provider/provider.dart';
import 'Utils/shared_prefs_service.dart';
import 'Utils/streak_repo.dart';
import 'firebase_options.dart';

final GlobalKey<NavigatorState> navigationKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Wiring FCM → Awesome for background & foreground
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await SharedPreferencesService.getInstance();

  // Caches Firestore collections and documents locally on your device.
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {

    // Foreground FCM handler - the message in onMessage.listen comes from FlutterFire's FLTFireMsgReceiver,
    // which handles FCM messages and forwards them as broadcasts as Instance of RemoteMessage.
    FirebaseMessaging.onMessage.listen((RemoteMessage message){
      // This shows the native OS notification even in foreground
      FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
     final deepLink = message.data['deep_link'];
      if (deepLink != null) {
        print('User tapped on push: Navigate to $deepLink');
      }
    });

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Wait for auth state to resolve
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }

        // Get the current user
        final user = snapshot.data;

        return MultiProvider(
          providers: [
            Provider<StreakRepository>(create: (_) => StreakRepository()),
            ChangeNotifierProvider(create: (_) => AuthViewModel()),
            ChangeNotifierProvider(create: (context) => HomeViewModel(context.read<StreakRepository>())),
            ChangeNotifierProvider(create: (_) => ChatViewModel(userId: user?.uid ?? '')),
          ],
          child: MaterialApp(
            navigatorKey: navigationKey,
            initialRoute: user != null ? '/' : '/login',
            onGenerateRoute: RouteNavigator.routeGenerator,
          ),
        );
      },
    );
  }
}