import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:focus_fuel/ViewModels/auth_vm.dart';
import 'package:focus_fuel/ViewModels/chat_vm.dart';
import 'package:focus_fuel/ViewModels/home_vm.dart';
import 'package:provider/provider.dart';
import 'Services/shared_prefs_service.dart';
import 'Services/streak_repo.dart';
import 'Themes/app_themes.dart';
import 'Themes/theme_provider.dart';
import 'ViewModels/newsfeed_vm.dart';
import 'ViewModels/onboarding_vm.dart';
import 'Views/Auth/login_page.dart';
import 'Views/screens/main_scaffold.dart';
import 'firebase_options.dart';
import 'Services/chat_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final GlobalKey<NavigatorState> navigationKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'focusfuel_channel',
    'FocusFuel Notifications',
    importance: Importance.high,
    enableVibration: true,
    playSound: true,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
  
  // Wiring FCM -> Awesome for background & foreground
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await SharedPreferencesService.getInstance();

  // Caches Firestore collections and documents locally on your device.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Setting up notification handlers BEFORE runApp
  _setupNotificationHandlers();

  runApp(const MyApp());
}

void _setupNotificationHandlers() async {
  // Requesting permissions first
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    carPlay: true,
  );

  // Foreground FCM handler - the message in onMessage.listen comes from FlutterFire's FLTFireMsgReceiver,
  // which handles FCM messages and forwards them as broadcasts as Instance of RemoteMessage.
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {

    _trackNotificationEvent('received', message);   // Track notification as received

    // This shows the native OS notification even in foreground
    FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true
    );
  });

  // When app is in background and user taps notification
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {

    _trackNotificationEvent('opened', message);   // Track notification as opened/clicked

    if (navigationKey.currentState != null) {
      navigationKey.currentState!.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MainScaffold(initialIndex: 2)), // 2 = Chat tab
            (route) => false, // Remove all previous routes
      );
    }
  });

  // When app is terminated and user taps notification
  FirebaseMessaging.instance.getInitialMessage().then((message) {
    if (message != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigationKey.currentState != null) {
          navigationKey.currentState!.pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const MainScaffold(initialIndex: 2)), // 2 = Chat tab
                (route) => false, // Remove all previous routes
          );
        }
      });
    }
  });
}

void _trackNotificationEvent(String eventType, RemoteMessage message) {
  final notificationId = message.data['notificationId'];
  final userId = message.data['userId'];

  if (notificationId != null && userId != null) {
    // Update the existing Notifications document
    FirebaseFirestore.instance.collection('Notifications').doc(notificationId).update({
      if (eventType == 'received') 'received': true,
      if (eventType == 'received') 'receivedAt': FieldValue.serverTimestamp(),
      if (eventType == 'opened') 'clicked': true,
      if (eventType == 'opened') 'clickedAt': FieldValue.serverTimestamp(),
    }).catchError((error) {
      print('Failed to track notification event: $error');
    });
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {

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
            ChangeNotifierProvider(create: (_) => ThemeProvider()..loadTheme()),
            Provider<StreakRepository>(create: (_) => StreakRepository()),
            Provider<ChatService>(create: (_) => ChatService()),
            ChangeNotifierProvider(create: (_) => AuthViewModel()),
            ChangeNotifierProvider(create: (context) => HomeViewModel(context.read<StreakRepository>())),
            ChangeNotifierProvider(create: (context) => ChatViewModel()),
            ChangeNotifierProvider(create: (_) => OnboardingViewModel()),
            ChangeNotifierProvider(create: (_) => NewsFeedViewModel()),
          ],
          child: Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return MaterialApp(
                navigatorKey: navigationKey,
                home: user != null ? const MainScaffold() : const Login(),
                theme: AppThemes.lightTheme,
                darkTheme: AppThemes.darkTheme,
                themeMode: themeProvider.themeMode, // DYNAMIC THEME
              );
            },
          ),
        );
      },
    );
  }
}