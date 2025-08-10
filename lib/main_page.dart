import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'notification_service.dart';
import 'smoking_scheduler.dart';

/// Main page that either accepts the number of cigarettes per day
/// or displays the countdown timer with daily stats.
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final _controller = TextEditingController();
  final _scheduler = SmokingScheduler.instance;
  bool _dialogShown = false;

  static const _channel = MethodChannel('smoking.native');

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onCountsChanged') {
        final data = Map<String, dynamic>.from(call.arguments);
        final action = data['action'] as String?;
        final nextAtMillis = (data['next_at_millis'] as int?) ?? 0;

        setState(() {
          _scheduler.smokedToday.value =
              (data['smoked_today'] as int?) ?? 0;
          _scheduler.skippedToday.value =
              (data['skipped_today'] as int?) ?? 0;
        });

        if (action == 'accept') {
          _scheduler.registerSmoked();
        } else if (action == 'skip') {
          _scheduler.registerSkipped();
        }

        if (nextAtMillis > 0) {
          final now = DateTime.now().millisecondsSinceEpoch;
          final remainingMs =
              (nextAtMillis - now).clamp(0, 24 * 3600 * 1000);
          _scheduler.setRemaining(
              Duration(milliseconds: remainingMs));
        }
        return true;
      }
      return null;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _showReminderNotification() async {
    if (Platform.isAndroid) return;
    await NotificationService.instance.scheduleCigarette(
      DateTime.now(),
      id: 999,
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: 1,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // First-time setup: ask for cigarettes/day
    if (_scheduler.cigsPerDay == null) {
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
        bottomNavigationBar: _buildBottomNav(),
      );
    }

    // Timer display
    return Scaffold(
      appBar: AppBar(title: const Text('Cigarette Timer')),
      body: Stack(
        children: [
          // Background tree
          Center(
            child: Opacity(
              opacity: 1.0,
              child: Image.asset(
                'assets/tree.png',
                fit: BoxFit.contain,
                height: 350,
              ),
            ),
          ),

          // Timer + stats
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<Duration>(
                    valueListenable: _scheduler.remaining,
                    builder: (context, duration, _) {
                      // When timer hits zero, show a notification and a dialog once
                      if (duration == Duration.zero && !_dialogShown) {
                        _dialogShown = true;

                        _showReminderNotification();

                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('Time to smoke'),
                                content: const Text(
                                  'Do you want to smoke this cigarette?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      _scheduler.registerSmoked();
                                      _scheduler.scheduleNext();
                                      setState(() => _dialogShown = false);
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text('✅ Accept'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      _scheduler.registerSkipped();
                                      _scheduler.scheduleNext();
                                      setState(() => _dialogShown = false);
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text('❌ Skip'),
                                  ),
                                ],
                              );
                            },
                          );
                        });
                      }

                      final hh = duration.inHours.toString().padLeft(2, '0');
                      final mm = duration.inMinutes
                          .remainder(60)
                          .toString()
                          .padLeft(2, '0');
                      final ss = duration.inSeconds
                          .remainder(60)
                          .toString()
                          .padLeft(2, '0');

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Next cigarette in: $hh:$mm:$ss',
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  ValueListenableBuilder<int>(
                    valueListenable: _scheduler.smokedToday,
                    builder: (context, count, _) =>
                        Text('Smoked today: $count'),
                  ),
                  const SizedBox(height: 8),

                  ValueListenableBuilder<int>(
                    valueListenable: _scheduler.skippedToday,
                    builder: (context, count, _) =>
                        Text('Skipped today: $count'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }
}
