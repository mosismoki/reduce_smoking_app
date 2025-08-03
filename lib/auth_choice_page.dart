import 'package:flutter/material.dart';
import 'login_page.dart';
import 'terms_page.dart';

class AuthChoicePage extends StatelessWidget {
  const AuthChoicePage({super.key});

  void _goToCreate(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TermsPage()),
    );
  }

  void _goToLogin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _goToCreate(context),
                child: const Text('Create Account'),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _goToLogin(context),
                child: const Text('Log In'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

