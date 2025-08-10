import 'package:flutter/material.dart';

// Pages
import 'auth_choice_page.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

// Local notifications
import 'notification_service.dart';
import 'smoking_scheduler.dart';


Future<void> _initFirebaseAndUser() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Sign in anonymously (safe with try/catch)
  try {
    await FirebaseAuth.instance.signInAnonymously();
    debugPrint("Signed in anonymously: ${FirebaseAuth.instance.currentUser?.uid}");
  } catch (e) {
    debugPrint("Anonymous sign-in failed: $e");
  }

  // Save basic user record (safe if offline)
  try {
    await FirebaseFirestore.instance.collection('users').add({
      'uid': FirebaseAuth.instance.currentUser?.uid,
      'timestamp': FieldValue.serverTimestamp(),
    });
    debugPrint("User saved to Firestore");
  } catch (e) {
    debugPrint("Saving user to Firestore failed: $e");
  }
}

Future<void> _initSmokingScheduler() async {
  try {
    await SmokingScheduler.instance.init();
  } catch (e) {
    debugPrint("SmokingScheduler init failed: $e");
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  await _initFirebaseAndUser();
  await _initSmokingScheduler();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      home: const AuthChoicePage(),
    );
  }
}
