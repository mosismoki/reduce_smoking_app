import 'package:flutter/material.dart';

/// A simple home page that displays a test message.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Firebase Anonymous Sign-In Test'),
      ),
    );
  }
}

