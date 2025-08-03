import 'package:flutter/material.dart';
import 'gender_selection_page.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  void _goToGenderSelection(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GenderSelectionPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login or Create Account')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _goToGenderSelection(context),
                child: const Text('Create Account'),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _goToGenderSelection(context),
                child: const Text('Log In'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
