// lib/main.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Pages
import 'auth_choice_page.dart';
import 'main_page.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

// Local services
import 'notification_service.dart';
import 'services/smoking_scheduler.dart';
import 'services/data_service.dart';

/// Toggle this to quickly enable/disable auto anonymous sign-in for testing.
const bool kAutoAnonymousSignIn = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ---- 1) Firebase (optional)
  bool firebaseOk = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseOk = true;
  } catch (_) {
    // در حالت توسعه اگر Firebase نبود، اپ باید بدون کرش بالا بیاد
    firebaseOk = false;
  }

  if (firebaseOk && kAutoAnonymousSignIn) {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      try { await auth.signInAnonymously(); } catch (_) {}
    }
  }

  // ---- 2) Local services – ترتیب مهم است
  await NotificationService.instance.init();
  await SmokingScheduler.instance.init(); // prefs & timers
  await DataService.instance.init();      // local stats

  runApp(MyApp(firebaseOk: firebaseOk));

  // ---- 3) به نیتیو اطلاع بده فلاتر آماده است (فقط اندروید)
  if (Platform.isAndroid) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      const channel = MethodChannel('smoking.native');
      try { await channel.invokeMethod('flutterReady'); } catch (_) {}
    });
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.firebaseOk});
  final bool firebaseOk;

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

      // اگر Firebase در دسترس نیست، اصلاً وارد StreamBuilder نشویم.
      home: firebaseOk
          ? StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final user = snapshot.data;
          // اگر کاربر لاگین است → MainPage؛ وگرنه → AuthChoicePage
          return (user != null) ? const MainPage() : const AuthChoicePage();
        },
      )
          : const MainPage(), // بدون Firebase مستقیم وارد اپ شو (UI-only)
    );
  }
}
