// main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:servana/firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// --- IMPORTS FOR LOCALIZATION ---
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:servana/l10n/app_localizations.dart';
import 'package:servana/providers/locale_provider.dart';

// --- APP-SPECIFIC IMPORTS ---
import 'package:servana/providers/user_provider.dart';
import 'package:servana/screens/home_screen.dart';
import 'package:servana/screens/login_screen.dart';
import 'package:servana/screens/role_selection_screen.dart';
import 'package:servana/screens/verification_status_screen.dart';
import 'package:servana/services/notification_service.dart';
import 'package:servana/theme/theme.dart';
// --- NEW IMPORT FOR ONBOARDING ---
import 'package:servana/screens/helper_onboarding_screen.dart';


// Background message handler for Firebase Messaging
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Handling a background message: ${message.messageId}");
}

Future<void> main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  // Load environment variables
  await dotenv.load(fileName: ".env");
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Activate Firebase App Check for debug mode
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );

  // Set up the background message handler for FCM
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        // Provider for managing app language/locale
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Consumer listens for locale changes to rebuild the MaterialApp
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, child) {
        return MaterialApp(
          // Navigator key for handling notifications
          navigatorKey: NotificationService.navigatorKey,
          title: 'Servana',
          theme: AppTheme.lightTheme,
          debugShowCheckedModeBanner: false,

          // --- Connect localization to the app ---
          locale: localeProvider.locale, // Set the current language
          supportedLocales: L10n.all, // Tell Flutter which languages are supported
          localizationsDelegates: const [
            AppLocalizations.delegate, // Your app's specific translations
            GlobalMaterialLocalizations.delegate, // Built-in translations for Material widgets
            GlobalWidgetsLocalizations.delegate, // For text direction
            GlobalCupertinoLocalizations.delegate, // For iOS-style widgets
          ],

          home: const AuthWrapper(),
        );
      },
    );
  }
}


// AuthWrapper handles the authentication state and user routing
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  // Initializes user-dependent services after a successful login
  Future<void> _initializeServicesAfterLogin(User user) async {
    // Check if the widget is still mounted before using context
    if (!mounted) return;
    context.read<UserProvider>().setUser(user);
    await NotificationService().initNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // Show a loading indicator while checking auth state
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final User? user = authSnapshot.data;

        // If the user is not logged in
        if (user == null) {
          // Defer the provider call to after the build phase to avoid errors
          Future.microtask(() {
            if (mounted) {
              context.read<UserProvider>().clearUser();
            }
          });
          return const LoginScreen();
        } else {
          // If the user is logged in, fetch their data from Firestore
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
            builder: (context, userDocSnapshot) {
              // Show a loading indicator while fetching user data
              if (userDocSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }

              // Defer service initialization to prevent build-time errors
              Future.microtask(() => _initializeServicesAfterLogin(user));

              // --- UPDATED User Routing Logic ---
              final userData = userDocSnapshot.data?.data() as Map<String, dynamic>? ?? {};
              final hasCompletedRoleSelection = userData['hasCompletedRoleSelection'] == true;
              final isHelper = userData['isHelper'] == true;
              final verificationStatus = userData['verificationStatus'] as String?;
              // Make sure to get the new onboardingStep field!
              final onboardingStep = userData['onboardingStep'] as int? ?? 0;

              // --- NEW User Routing Logic for Servana ---

              // 1. If role not selected, go to RoleSelectionScreen.
              if (!hasCompletedRoleSelection) {
                return const RoleSelectionScreen();
              }

              // 2. If user IS a helper but has NOT completed onboarding, send them to the pipeline.
              //    We check if the step is less than the final step number (which is 3).
              if (isHelper && onboardingStep < 3) {
                return const HelperOnboardingScreen();
              }

              // 3. If user IS a helper, has finished onboarding, but is not yet verified, show status.
              if (isHelper && verificationStatus != 'verified') {
                return const VerificationStatusScreen();
              }

              // 4. If all checks pass, they are a verified helper or a poster. Go to HomeScreen.
              return const HomeScreen();
            },
          );
        }
      },
    );
  }
}