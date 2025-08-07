import 'package:flutter/material.dart';
import 'smoking_scheduler.dart';
import 'main.dart';

/// Main page that either accepts the number of cigarettes per day or displays
/// the countdown timer with daily statistics.
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final _controller = TextEditingController();
  final _scheduler = SmokingScheduler.instance;
  bool _dialogShown = false;

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
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: 1,
          items: [
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      );
    }

    // Timer display.
    return Scaffold(
      appBar: AppBar(title: const Text('Cigarette Timer')),
      body: Stack(
        children: [
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
                      if (duration == Duration.zero && !_dialogShown) {
                        _dialogShown = true;
                        flutterLocalNotificationsPlugin.show(
                          0,
                          'Time to smoke',
                          'Do you want to smoke this cigarette?',
                          const NotificationDetails(
                            android: AndroidNotificationDetails(
                              'smoke_channel',
                              'Smoke Reminder',
                              importance: Importance.max,
                              priority: Priority.high,
                            ),
                          ),
                        );
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('Time to smoke'),
                                content: const Text(
                                    'Do you want to smoke this cigarette?'),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      _scheduler.registerSmoked();
                                      _scheduler.scheduleNext();
                                      setState(() {
                                        _dialogShown = false;
                                      });
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text('✅ Accept'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      _scheduler.registerSkipped();
                                      _scheduler.scheduleNext();
                                      setState(() {
                                        _dialogShown = false;
                                      });
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
                      final hours =
                          duration.inHours.toString().padLeft(2, '0');
                      final minutes = duration.inMinutes
                          .remainder(60)
                          .toString()
                          .padLeft(2, '0');
                      final seconds = duration.inSeconds
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
                          'Next cigarette in: $hours:$minutes:$seconds',
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
