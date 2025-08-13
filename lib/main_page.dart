// lib/main_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ⛔️ Remove Firestore import – not needed with TodayStats stream
// import 'package:cloud_firestore/cloud_firestore.dart';

import 'services/data_service.dart';
import 'notification_service.dart';
import 'services/smoking_scheduler.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _scheduler = SmokingScheduler.instance;
  static const _channel = MethodChannel('smoking.native');

  int _lastSmoked = 0;
  int _lastSkipped = 0;

  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _scheduler.refreshFromPrefs().whenComplete(() {
      _lastSmoked = _scheduler.smokedToday.value;
      _lastSkipped = _scheduler.skippedToday.value;
      if (mounted) setState(() => _ready = true);
    });

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onCountsChanged') {
        final Map<String, dynamic> data =
        Map<String, dynamic>.from(call.arguments ?? {});

        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final nextAtMillis = (data['next_at_millis'] as int?) ?? 0;
        final windowEndMs = (data['smokingWindowEndTs'] as int?) ?? 0;

        if (data.containsKey('smoked_today')) {
          _scheduler.smokedToday.value =
              (data['smoked_today'] as int?) ?? _scheduler.smokedToday.value;
        }
        if (data.containsKey('skipped_today')) {
          _scheduler.skippedToday.value =
              (data['skipped_today'] as int?) ?? _scheduler.skippedToday.value;
        }

        if (windowEndMs > nowMs) {
          _scheduler.inSmokingWindow.value = true;
          _scheduler.syncNextFromMillis(windowEndMs);
        } else if (nextAtMillis > 0) {
          _scheduler.inSmokingWindow.value = false;
          _scheduler.syncNextFromMillis(nextAtMillis);
        }

        final newSmoked = _scheduler.smokedToday.value;
        final newSkipped = _scheduler.skippedToday.value;

        if (newSmoked > _lastSmoked) {
          _lastSmoked = newSmoked;
          await DataService.instance.incrementSmoked();
        }
        if (newSkipped > _lastSkipped) {
          _lastSkipped = newSkipped;
          await DataService.instance.incrementSkipped();
        }
        return true;
      }
      return null;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduler.refreshFromPrefs().then((_) {
        _lastSmoked = _scheduler.smokedToday.value;
        _lastSkipped = _scheduler.skippedToday.value;
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

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
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final cpd = _scheduler.cigsPerDay ?? 0;
    if (cpd <= 0) {
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
                onPressed: () async {
                  final value = int.tryParse(_controller.text);
                  if (value != null && value > 0) {
                    await _scheduler.setCigsPerDay(value);
                    await _scheduler.refreshFromPrefs();
                    _lastSmoked = _scheduler.smokedToday.value;
                    _lastSkipped = _scheduler.skippedToday.value;
                    if (mounted) setState(() {});
                  }
                },
                child: const Text('Start'),
              ),
              if (!Platform.isAndroid)
                TextButton(
                  onPressed: _showReminderNotification,
                  child: const Text('Test iOS notification'),
                ),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomNav(),
      );
    }

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
                  ValueListenableBuilder<bool>(
                    valueListenable: _scheduler.inSmokingWindow,
                    builder: (context, isWindow, _) {
                      if (!isWindow) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Smoking window', style: TextStyle(color: Colors.white)),
                      );
                    },
                  ),
                  ValueListenableBuilder<Duration>(
                    valueListenable: _scheduler.remaining,
                    builder: (context, duration, _) {
                      final hh = duration.inHours.toString().padLeft(2, '0');
                      final mm = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
                      final ss = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
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
                    builder: (context, cnt, _) => Text('Smoked today: $cnt'),
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<int>(
                    valueListenable: _scheduler.skippedToday,
                    builder: (context, cnt, _) => Text('Skipped today: $cnt'),
                  ),
                  const SizedBox(height: 16),

                  // Buttons (local counters + persist via DataService)
                  Wrap(
                    spacing: 12,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          _scheduler.smokedToday.value++;
                          _lastSmoked = _scheduler.smokedToday.value;
                          await DataService.instance.incrementSmoked();
                          if (mounted) setState(() {});
                        },
                        icon: const Icon(Icons.local_fire_department),
                        label: const Text('Mark Smoked'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          _scheduler.skippedToday.value++;
                          _lastSkipped = _scheduler.skippedToday.value;
                          await DataService.instance.incrementSkipped();
                          if (mounted) setState(() {});
                        },
                        icon: const Icon(Icons.thumb_up_alt_outlined),
                        label: const Text('Mark Skipped'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // 🔁 Show live stats from DataService (TodayStats stream)
                  StreamBuilder<TodayStats>(
                    stream: DataService.instance.watchToday(),
                    builder: (context, snap) {
                      final stats = snap.data ??
                          TodayStats(smoked: 0, skipped: 0, date: DateTime.now());
                      return Text('Server → Smoked: ${stats.smoked} | Skipped: ${stats.skipped}');
                    },
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
