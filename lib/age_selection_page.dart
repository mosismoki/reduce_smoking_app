import 'package:flutter/material.dart';

class AgeSelectionPage extends StatefulWidget {
  final String selectedGender;
  const AgeSelectionPage({super.key, required this.selectedGender});

  @override
  State<AgeSelectionPage> createState() => _AgeSelectionPageState();
}

class _AgeSelectionPageState extends State<AgeSelectionPage> {
  double _currentAge = 18;

  void _continue() {
    final age = _currentAge.round();
    debugPrint('Gender: ${widget.selectedGender}, Age: $age');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Select your age',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Text(
                '${_currentAge.round()}',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              Slider(
                value: _currentAge,
                min: 18,
                max: 80,
                divisions: 62,
                label: _currentAge.round().toString(),
                onChanged: (value) => setState(() => _currentAge = value),
                activeColor: Colors.white,
                inactiveColor: Colors.white24,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _continue,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF001F54),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

