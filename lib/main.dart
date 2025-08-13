// lib/main.dart
import 'package:flutter/material.dart';

// Pages
import 'auth_choice_page.dart';
import 'main_page.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

// Local services
import 'notification_service.dart';
import 'services/smoking_scheduler.dart'; // ← relative import (not package:)
import 'services/data_service.dart';      // ← for local persisted stats

/// Toggle this to quickly enable/disable auto anonymous sign-in for testing.
const bool kAutoAnonymousSignIn = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Firebase (optional auth)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (kAutoAnonymousSignIn) {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }
  }

  // 2) Local services
  await NotificationService.instance.init();
  await SmokingScheduler.instance.init(); // loads prefs & timers
  await DataService.instance.init();      // loads SharedPreferences & stream

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
      // If kAutoAnonymousSignIn = true you will never see AuthChoicePage.
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final user = snapshot.data;
          return (user != null) ? const MainPage() : const AuthChoicePage();
        },
      ),
    );
  }
}
