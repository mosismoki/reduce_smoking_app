import 'package:flutter/material.dart';
import 'login_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reduce Smoking App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const TermsPage(),
    );
  }
}

class TermsPage extends StatefulWidget {
  const TermsPage({super.key});

  @override
  State<TermsPage> createState() => _TermsPageState();
}

class _TermsPageState extends State<TermsPage> {
  bool _agreed = false;

  void _goToLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Terms and Conditions',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Placeholder terms and conditions go here. Please read them carefully before continuing.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                CheckboxListTile(
                  value: _agreed,
                  onChanged: (value) => setState(() => _agreed = value ?? false),
                  title: const Text('I agree to the terms and conditions'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _agreed ? _goToLogin : null,
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
