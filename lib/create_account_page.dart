import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'main_page.dart';
import 'package:reduce_smoking_app/services/smoking_scheduler.dart';
import 'services/auth_service.dart';


class CreateAccountPage extends StatefulWidget {
  final DateTime termsAcceptedAt;
  const CreateAccountPage({super.key, required this.termsAcceptedAt});

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  final _formKey = GlobalKey<FormState>();

  // auth
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _displayName = TextEditingController();
  final _username = TextEditingController(); // اختیاری؛ اگر نخواستی، می‌تونی حذف کنی

  // profile
  String? _gender;
  final _age = TextEditingController();
  final _country = TextEditingController();
  final _cigsPerDay = TextEditingController();
  final _startedYear = TextEditingController();
  final _habits = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _displayName.dispose();
    _username.dispose();
    _age.dispose();
    _country.dispose();
    _cigsPerDay.dispose();
    _startedYear.dispose();
    _habits.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // (اختیاری) چک یکتا بودن یوزرنیم
    if (_username.text.trim().isNotEmpty) {
      final ok = await AuthService.instance.isUsernameAvailable(_username.text.trim());
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username is already taken')),
        );
        return;
      }
    }

    final cigs = int.tryParse(_cigsPerDay.text.trim());
    final profile = {
      'displayName': _displayName.text.trim(),
      'username': _username.text.trim(),
      'usernameLower': _username.text.trim().toLowerCase(),
      'gender': _gender,
      'age': int.tryParse(_age.text.trim()),
      'country': _country.text.trim(),
      'cigsPerDay': cigs,
      'startedYear': int.tryParse(_startedYear.text.trim()),
      'habitsNote': _habits.text.trim(),
      'termsAcceptedAt': widget.termsAcceptedAt,
      'createdAt': DateTime.now(), // serverTimestamp هم در سرویس ست می‌کنیم
    };

    try {
      await AuthService.instance.signUpWithEmail(
        email: _email.text.trim(),
        password: _password.text,
        profile: profile,
      );

      // ست کردن برنامه‌ریز
      if (cigs != null && cigs > 0) {
        SmokingScheduler.instance.setCigsPerDay(cigs);
      }

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainPage()),
              (_) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign up failed: $e')),
      );
    }
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Auth fields
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: _req,
              ),
              TextFormField(
                controller: _password,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (v) {
                  if (v == null || v.length < 6) return 'Min 6 characters';
                  return null;
                },
              ),
              TextFormField(
                controller: _confirm,
                decoration: const InputDecoration(labelText: 'Confirm password'),
                obscureText: true,
                validator: (v) => v != _password.text ? 'Passwords do not match' : null,
              ),
              TextFormField(
                controller: _displayName,
                decoration: const InputDecoration(labelText: 'Name (display name)'),
                validator: _req,
              ),
              TextFormField(
                controller: _username,
                decoration: const InputDecoration(labelText: 'Username (optional)'),
              ),
              const Divider(height: 32),

              // Profile fields (قبلی‌های خودت + اعتبارسنجی ساده)
              DropdownButtonFormField<String>(
                value: _gender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (v) => setState(() => _gender = v),
                validator: (v) => v == null ? 'Please select your gender' : null,
              ),
              TextFormField(
                controller: _age,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Age'),
                validator: _req,
              ),
              TextFormField(
                controller: _country,
                decoration: const InputDecoration(labelText: 'Country'),
                validator: _req,
              ),
              TextFormField(
                controller: _cigsPerDay,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Cigarettes per day'),
                validator: _req,
              ),
              TextFormField(
                controller: _startedYear,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Since when you smoke (year)'),
                validator: _req,
              ),
              TextFormField(
                controller: _habits,
                decoration: const InputDecoration(labelText: 'Tell us about your smoking habits'),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Submit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
