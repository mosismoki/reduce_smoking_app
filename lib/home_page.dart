import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> signInAnonymously(BuildContext context) async {
    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInAnonymously();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signed in anonymously: ${userCredential.user?.uid}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing in: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firebase Auth Test')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => signInAnonymously(context),
          child: const Text('Test Firebase Auth'),
        ),
      ),
    );
  }
}

