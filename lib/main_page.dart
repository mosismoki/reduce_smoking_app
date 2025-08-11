import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'notification_service.dart';
import 'package:reduce_smoking_app/services/smoking_scheduler.dart';


class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final _controller = TextEditingController();
  final _scheduler = SmokingScheduler.instance;
  static const _channel = MethodChannel('smoking.native');

  @override
  void initState() {
    super.initState();

    // 1) راه‌اندازی Scheduler
    SmokingScheduler.instance.init().then((_) async {
      // 2) pull فوری از prefs
      await SmokingScheduler.instance.refreshFromPrefs();
    });

    // 3) رویدادهای نیتیو
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onCountsChanged') {
        final data = Map<String, dynamic>.from(call.arguments);
        final nextAtMillis = (data['next_at_millis'] as int?) ?? 0;
        final windowEndMs  = (data['smokingWindowEndTs'] as int?) ?? 0;
        final nowMs = DateTime.now().millisecondsSinceEpoch;

        setState(() {
          _scheduler.smokedToday.value  = (data['smoked_today'] as int?) ?? 0;
          _scheduler.skippedToday.value = (data['skipped_today'] as int?) ?? 0;
        });

        // اگر داخل پنجره ۵ دقیقه‌ای هستیم، همون پنجره را در UI بشمار
        if (windowEndMs > nowMs) {
          _scheduler.inSmokingWindow.value = true;
          _scheduler.syncNextFromMillis(windowEndMs);
        } else if (nextAtMillis > 0) {
          _scheduler.inSmokingWindow.value = false;
          _scheduler.syncNextFromMillis(nextAtMillis);
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

  // iOS only helper
  Future<void> _showReminderNotification() async {
    if (Platform.isAndroid) return;
    await NotificationService.instance.scheduleCigarette(DateTime.now(), id: 999);
  }

  Widget _buildBottomNav() => BottomNavigationBar(
    currentIndex: 1,
    items: const [
      BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
      BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
    ],
  );

  @override
  Widget build(BuildContext context) {
    // اگر هنوز cigsPerDay تعیین نشده
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
                decoration: const InputDecoration(labelText: 'Cigarettes per day'),
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

    // صفحه تایمر
    return Scaffold(
      appBar: AppBar(title: const Text('Cigarette Timer')),
      body: Stack(
        children: [
          Center(
            child: Opacity(
              opacity: 1.0,
              child: Image.asset('assets/tree.png', fit: BoxFit.contain, height: 350),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // لیبل پنجره ۵ دقیقه‌ای (وقتی فعال است)
                  ValueListenableBuilder<bool>(
                    valueListenable: _scheduler.inSmokingWindow,
                    builder: (context, isWindow, _) {
                      if (!isWindow) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.redAccent, borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Smoking window', style: TextStyle(color: Colors.white)),
                      );
                    },
                  ),
                  // تایمر
                  ValueListenableBuilder<Duration>(
                    valueListenable: _scheduler.remaining,
                    builder: (context, duration, _) {
                      final hh = duration.inHours.toString().padLeft(2, '0');
                      final mm = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
                      final ss = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black, borderRadius: BorderRadius.circular(12),
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
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }
}
