import 'package:flutter/material.dart';
import 'auth_choice_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'firebase_options.dart';
import 'smoking_scheduler.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _initNotifications() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const settings = InitializationSettings(android: android);
  await flutterLocalNotificationsPlugin.initialize(settings);
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
}

@pragma('vm:entry-point')
Future<void> showSmokeNotification() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const settings = InitializationSettings(android: android);
  await flutterLocalNotificationsPlugin.initialize(settings);
  const androidDetails = AndroidNotificationDetails(
    'smoke_channel',
    'Smoke Reminders',
    importance: Importance.high,
    priority: Priority.high,
  );
  const details = NotificationDetails(android: androidDetails);
  await flutterLocalNotificationsPlugin.show(
    0,
    'Time to smoke',
    'Do you want to smoke this cigarette?',
    details,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AndroidAlarmManager.initialize();
  await _initNotifications();

  // 1. Init Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. Sign in anonymously
  await FirebaseAuth.instance.signInAnonymously();

  // 3. Save user to Firestore
  await FirebaseFirestore.instance.collection('users').add({
    'uid': FirebaseAuth.instance.currentUser?.uid,
    'timestamp': FieldValue.serverTimestamp(),
  });

  // 4. Initialize SmokingScheduler
  await SmokingScheduler.instance.init();

  // 5. Schedule periodic notification every 30 minutes
  await AndroidAlarmManager.periodic(
    const Duration(minutes: 30),
    0,
    showSmokeNotification,
    wakeup: true,
    rescheduleOnReboot: true,
  );

  // 6. Run the app
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
