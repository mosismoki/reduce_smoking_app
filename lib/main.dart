// lib/main.dart
import 'package:flutter/material.dart';

// Pages
import 'auth_choice_page.dart';
import 'main_page.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

// Local notifications & scheduler
import 'notification_service.dart';
import 'package:reduce_smoking_app/services/smoking_scheduler.dart';

/// Toggle this to quickly enable/disable auto anonymous sign-in for testing.
const bool kAutoAnonymousSignIn = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Optional: auto sign-in anonymously for fast testing
  if (kAutoAnonymousSignIn) {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }
  }

  // Initialize local notifications
  await NotificationService.instance.init();

  // Initialize smoking scheduler (loads prefs & starts/resumes countdown)
  await SmokingScheduler.instance.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Reduce Smoking App',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF001F54),
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF001F54),
          brightness: Brightness.dark,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF001F54),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final user = snapshot.data;
          // If kAutoAnonymousSignIn = true, user will never be null after init.
          // If you set it to false, you'll see AuthChoicePage when logged out.
          return (user != null) ? const MainPage() : const AuthChoicePage();
        },
      ),
    );
  }
}
