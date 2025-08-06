import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'home_page.dart';
import 'smoking_scheduler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('Initializing Firebase...');

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('Firebase initialized');

  // Initialise smoking scheduler
  await SmokingScheduler.instance.init();

  try {
    final userCredential = await FirebaseAuth.instance.signInAnonymously();
    debugPrint("Signed in anonymously: ${userCredential.user?.uid}");

    // ذخیره کاربر در Firestore
    await FirebaseFirestore.instance.collection('users').add({
      'uid': userCredential.user?.uid,
      'timestamp': FieldValue.serverTimestamp(),
    });
    debugPrint("User saved to Firestore");

  } catch (e, st) {
    debugPrint("Error signing in anonymously: $e");
    debugPrintStack(stackTrace: st);
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase Auth Test',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
    );
  }
}
