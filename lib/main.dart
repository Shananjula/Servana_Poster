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
import 'package:servana/screens/helper_onboarding_screen.dart';

// --- ADD IMPORTS FOR YOUR NEW SCREENS ---
import 'package:servana/screens/helper_profile_screen.dart';
import 'package:servana/screens/poster_profile_screen.dart';


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

  // Activate Firebase App Check
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
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, child) {
        return MaterialApp(
          navigatorKey: NotificationService.navigatorKey,
          title: 'Servana',
          theme: AppTheme.lightTheme,
          debugShowCheckedModeBanner: false,
          locale: localeProvider.locale,
          supportedLocales: L10n.all,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const AuthWrapper(),
        );
      },
    );
  }
}


/// The AuthWrapper is the "brain" of the app's routing.
/// It listens to authentication state and user profile data to decide which screen to show.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  /// Initializes user-dependent services after a successful login.
  Future<void> _initializeServicesAfterLogin(User user) async {
    if (!mounted) return;
    context.read<UserProvider>().setUser(user);
    await NotificationService().initNotifications();
  }

  /// Ensures a user document exists in Firestore. This is called once upon login.
  Future<void> _ensureUserDocumentExists(User user) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snapshot = await userRef.get();

    if (!snapshot.exists) {
      await userRef.set({
        // --- STANDARDIZED: Now correctly uses 'phone' ---
        'phone': user.phoneNumber,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',
        'role': null,
        'helperProfileCompleted': false,
        'documentsSubmitted': false,
        'posterProfileCompleted': false,
        'verificationStatus': 'not_started',
      }, SetOptions(merge: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final User? user = authSnapshot.data;

        if (user == null) {
          Future.microtask(() {
            if (mounted) context.read<UserProvider>().clearUser();
          });
          return const LoginScreen();
        } else {
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
            builder: (context, userDocSnapshot) {

              if (userDocSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }

              if (!userDocSnapshot.hasData || !userDocSnapshot.data!.exists) {
                _ensureUserDocumentExists(user);
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }

              Future.microtask(() => _initializeServicesAfterLogin(user));

              final userData = userDocSnapshot.data!.data() as Map<String, dynamic>;

              final String? role = userData['role'];

              if (role == null) {
                return const RoleSelectionScreen();
              }

              if (role == 'helper') {
                final bool profileCompleted = userData['helperProfileCompleted'] == true;
                final bool docsSubmitted = userData['documentsSubmitted'] == true;
                final String verificationStatus = userData['verificationStatus'] ?? 'not_started';

                if (!profileCompleted) {
                  return const HelperProfileScreen();
                }
                if (!docsSubmitted) {
                  return const HelperOnboardingScreen();
                }
                if (verificationStatus != 'verified') {
                  return const VerificationStatusScreen();
                }
              }

              if (role == 'poster') {
                final bool profileCompleted = userData['posterProfileCompleted'] == true;
                if (!profileCompleted) {
                  return const PosterProfileScreen();
                }
              }

              return const HomeScreen();
            },
          );
        }
      },
    );
  }
}
