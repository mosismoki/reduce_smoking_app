import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'auth_choice_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
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

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  await _initNotifications();

  Timer.periodic(const Duration(minutes: 30), (timer) {
    showSmokeNotification();
  });
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'smoke_service',
      initialNotificationTitle: 'Smoking Reminder Service',
      initialNotificationContent: 'Running',
    ),
    iosConfiguration: IosConfiguration(),
  );
  await service.startService();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initNotifications();
  await initializeService();

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

  // 5. Run the app
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
