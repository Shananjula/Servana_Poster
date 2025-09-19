// lib/main.dart (patched) — preserves your original home & settings
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';

import 'package:servana/screens/posterhomeshell.dart';
import 'package:servana/screens/login_screen.dart'; // <- your phone login screen
import 'package:servana/utils/analytics_observer.dart';
import 'package:servana/utils/app_settings.dart';

// NEW: register FCM token after sign-in
import 'package:servana/services/push_service.dart';

// Compat route target (supports both old and new param names)
import 'package:servana/screens/conversation_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Crashlytics: capture Flutter framework errors
  FlutterError.onError = (details) async {
    FlutterError.presentError(details);
    await FirebaseCrashlytics.instance.recordFlutterError(details);
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to Theme + Locale from AppSettings and apply globally
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppSettings.themeMode,
      builder: (_, mode, __) {
        return ValueListenableBuilder<Locale?>(
          valueListenable: AppSettings.locale,
          builder: (_, loc, __) {
            return MaterialApp(
              title: 'Servana',
              debugShowCheckedModeBanner: false,

              // Material 3 themes
              theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
              darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
              themeMode: mode,      // live theme mode from AppSettings
              locale: loc,          // live locale (null => system)

              // Localizations
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [
                Locale('en'), Locale('si'), Locale('ta'),
              ],

              navigatorObservers: [ScreenTrackerObserver()],

              // Routes (handy for hard resets after sign-out)
              routes: {
                '/signin': (_) => const LoginScreen(),
                '/home':   (_) => const PosterHomeShell(),

                // ✅ Compat conversation route — supports both old and new callers
                '/conversation': (context) {
                  final args = ModalRoute.of(context)!.settings.arguments as Map?;
                  return ConversationScreen(
                    // new-style (if provided)
                    chatChannelId: args?['chatChannelId'] as String?,

                    // legacy compatibility
                    otherUserId:   (args?['otherUserId'] ?? args?['helperId']) as String?,
                    otherUserName: (args?['otherUserName'] ?? args?['helperName']) as String?,

                    // optional task context
                    taskId:        args?['taskId'] as String?,
                    taskTitle:     args?['taskTitle'] as String?,
                  );
                },
              },

              // Auth gate: swap between PosterHomeShell and LoginScreen
              home: StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final user = snapshot.data;
                  return user == null
                      ? const LoginScreen()
                      : _PosterHomeWithPush(child: const PosterHomeShell());
                },
              ),
            );
          },
        );
      },
    );
  }
}

/// Registers the device FCM token after sign-in without blocking your existing Home UI.
class _PosterHomeWithPush extends StatefulWidget {
  final Widget child;
  const _PosterHomeWithPush({required this.child});

  @override
  State<_PosterHomeWithPush> createState() => _PosterHomeWithPushState();
}

class _PosterHomeWithPushState extends State<_PosterHomeWithPush> {
  bool _attempted = false;

  @override
  void initState() {
    super.initState();
    _initPush();
  }

  Future<void> _initPush() async {
    try {
      await PushService.instance.initForCurrentUser(appRole: 'poster');
    } catch (_) {
      // Never block UI on push setup
    } finally {
      if (mounted) setState(() => _attempted = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Optionally show a tiny banner while registering. We keep it simple.
    return widget.child;
  }
}
