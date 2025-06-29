import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:firebase_app_check/firebase_app_check.dart'; // --- NEW ---

import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'providers/user_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/notification_service.dart';
import 'theme/theme.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Handling a background message: ${message.messageId}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // --- NEW: Initialize Firebase App Check ---
  // This helps protect your backend from abuse.
  await FirebaseAppCheck.instance.activate(
    // Use the debug provider in development.
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NotificationService.navigatorKey,
      title: 'Helpify',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  // --- UPDATED: Moved notification initialization here ---
  // We only initialize notifications AFTER a user is successfully logged in.
  Future<void> _initializeServicesAfterLogin() async {
    // This prevents blocking the UI thread on app start.
    await NotificationService().initNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final User? user = snapshot.data;
        if (user == null) {
          context.read<UserProvider>().clearUser();
          return const LoginScreen();
        } else {
          // --- UPDATED: Use a FutureBuilder to handle initialization ---
          // This ensures the HomeScreen is only shown after services are ready.
          return FutureBuilder(
            future: _initializeServicesAfterLogin(),
            builder: (context, initSnapshot) {
              if (initSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              // Once initialization is complete, set the user and show the HomeScreen.
              context.read<UserProvider>().setUser(user);
              return const HomeScreen();
            },
          );
        }
      },
    );
  }
}
