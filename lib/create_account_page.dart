import 'package:flutter/material.dart';
import 'home_page.dart';

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({super.key});

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  final _formKey = GlobalKey<FormState>();
  String? _gender;
  final _ageController = TextEditingController();
  final _countryController = TextEditingController();
  final _cigarettesController = TextEditingController();
  final _sinceController = TextEditingController();
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _ageController.dispose();
    _countryController.dispose();
    _cigarettesController.dispose();
    _sinceController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      debugPrint('Gender: $_gender, Age: ${_ageController.text}, Country: ${_countryController.text}, Cigarettes: ${_cigarettesController.text}, Since: ${_sinceController.text}, Message: ${_messageController.text}');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainPage()),
      );
    }
  }

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
              DropdownButtonFormField<String>(
                value: _gender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (value) => setState(() => _gender = value),
                validator: (value) => value == null ? 'Please select your gender' : null,
              ),
              TextFormField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Age'),
                validator: (value) => value == null || value.isEmpty ? 'Enter your age' : null,
              ),
              TextFormField(
                controller: _countryController,
                decoration: const InputDecoration(labelText: 'Country'),
                validator: (value) => value == null || value.isEmpty ? 'Enter your country' : null,
              ),
              TextFormField(
                controller: _cigarettesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Cigarettes per day'),
                validator: (value) => value == null || value.isEmpty ? 'Enter number of cigarettes' : null,
              ),
              TextFormField(
                controller: _sinceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Since when you smoke (year)'),
                validator: (value) => value == null || value.isEmpty ? 'Enter year' : null,
              ),
              TextFormField(
                controller: _messageController,
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

