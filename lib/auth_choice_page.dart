import 'package:flutter/material.dart';
import 'login_page.dart';
import 'terms_page.dart';
import 'main_page.dart';
import 'services/auth_service.dart';

class AuthChoicePage extends StatelessWidget {
  const AuthChoicePage({super.key});

  void _goToCreate(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TermsPage()));
  }

  void _goToLogin(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  Future<void> _continueWithGoogle(BuildContext context) async {
    try {
      // در صورت نیاز می‌تونی extraProfile بدهی
      await AuthService.instance.signInWithGoogle();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainPage()),
              (_) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google sign-in failed: $e')),
        );
      }
    }
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
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _goToLogin(context),
                child: const Text('Log In'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _continueWithGoogle(context),
                child: const Text('Continue with Google'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
