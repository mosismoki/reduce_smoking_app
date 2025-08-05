import 'package:flutter/material.dart';
import 'smoking_scheduler.dart';

/// Home page that either accepts the number of cigarettes per day or displays
/// the countdown timer with daily statistics.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _controller = TextEditingController();
  final _scheduler = SmokingScheduler.instance;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_scheduler.cigsPerDay == null) {
      // Setup form for number of cigarettes per day.
      return Scaffold(
        appBar: AppBar(title: const Text('Set Daily Cigarettes')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cigarettes per day',
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  final value = int.tryParse(_controller.text);
                  if (value != null && value > 0) {
                    _scheduler.setCigsPerDay(value);
                    setState(() {});
                  }
                },
                child: const Text('Start'),
              ),
            ],
          ),
        ),
      );
    }

    // Timer display.
    return Scaffold(
      appBar: AppBar(title: const Text('Cigarette Timer')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ValueListenableBuilder<Duration>(
              valueListenable: _scheduler.remaining,
              builder: (context, duration, _) {
                final hours = duration.inHours.toString().padLeft(2, '0');
                final minutes =
                    duration.inMinutes.remainder(60).toString().padLeft(2, '0');
                final seconds =
                    duration.inSeconds.remainder(60).toString().padLeft(2, '0');
                return Text('Next cigarette in: '
                    '$hours:$minutes:$seconds');
              },
            ),
            const SizedBox(height: 24),
            ValueListenableBuilder<int>(
              valueListenable: _scheduler.smokedToday,
              builder: (context, count, _) => Text('Smoked today: $count'),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<int>(
              valueListenable: _scheduler.skippedToday,
              builder: (context, count, _) => Text('Skipped today: $count'),
            ),
          ],
        ),
      ),
    );
  }
}

