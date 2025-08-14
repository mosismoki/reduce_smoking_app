// lib/main_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Firestore را فعلاً استفاده نمی‌کنیم
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
  bool _handlerAttached = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boot();

    // Native -> Flutter updates
    _channel.setMethodCallHandler((call) async {
      if (!mounted) return null; // صفحه dispose شده؟
      try {
        if (call.method == 'onCountsChanged') {
          final Map<String, dynamic> data =
          Map<String, dynamic>.from(call.arguments ?? {});

          final nowMs        = DateTime.now().millisecondsSinceEpoch;
          final nextAtMillis = (data['next_at_millis'] as num?)?.toInt() ?? 0;
          final windowEndMs  = (data['smokingWindowEndTs'] as num?)?.toInt() ?? 0;

          // آمار روز را از نیتیو بگیر
          if (data.containsKey('smoked_today')) {
            _scheduler.smokedToday.value =
                (data['smoked_today'] as num?)?.toInt() ??
                    _scheduler.smokedToday.value;
          }
          if (data.containsKey('skipped_today')) {
            _scheduler.skippedToday.value =
                (data['skipped_today'] as num?)?.toInt() ??
                    _scheduler.skippedToday.value;
          }

          // تشخیص نوع شمارش‌گر و سینک
          if (windowEndMs > nowMs) {
            await _scheduler.syncFromMillis(windowEndMs, isWindow: true);
          } else if (nextAtMillis > 0) {
            await _scheduler.syncFromMillis(nextAtMillis, isWindow: false);
          }

          // فقط اگر زیاد شده، به کلود بفرست (اختیاری)
          final newSmoked  = _scheduler.smokedToday.value;
          final newSkipped = _scheduler.skippedToday.value;
          if (newSmoked > _lastSmoked) {
            _lastSmoked = newSmoked;
            // await DataService.instance.incrementSmoked();
          }
          if (newSkipped > _lastSkipped) {
            _lastSkipped = newSkipped;
            // await DataService.instance.incrementSkipped();
          }

          if (mounted) setState(() {});
          return true;
        }
      } catch (_) {}
      return null;
    });
    _handlerAttached = true;
  }

  Future<void> _boot() async {
    // init قبلاً در main.dart صدا زده شده؛ اینجا فقط refresh کافی است
    await _scheduler.refreshFromPrefs();

    _lastSmoked  = _scheduler.smokedToday.value;
    _lastSkipped = _scheduler.skippedToday.value;

    if (mounted) setState(() => _ready = true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // قبل از رفتن به بک‌گراند هرچه هست ذخیره شود
      _scheduler.flush();
    }
    if (state == AppLifecycleState.resumed) {
      _scheduler.refreshFromPrefs().then((_) {
        _lastSmoked  = _scheduler.smokedToday.value;
        _lastSkipped = _scheduler.skippedToday.value;
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    // هندلر را آزاد کنیم تا اگر صفحه دوباره ساخت شد، دوبار ست نشود
    if (_handlerAttached) {
      // راه امن: جایگزینی با هندلر تهی
      _channel.setMethodCallHandler(null);
      _handlerAttached = false;
    }
    super.dispose();
  }

  Future<void> _showReminderNotification() async {
    if (Platform.isAndroid) return;
    await NotificationService.instance.scheduleCigarette(
      DateTime.now(),
      id: 999,
    );
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
                onSubmitted: (_) => _onStartPressed(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _onStartPressed,
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
                  // برچسب پنجره ۵ دقیقه‌ای
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

                  // تایمر
                  ValueListenableBuilder<Duration>(
                    valueListenable: _scheduler.remaining,
                    builder: (context, duration, _) {
                      final hh = duration.inHours.toString().padLeft(2, '0');
                      final mm = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
                      final ss = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
                      return ValueListenableBuilder<bool>(
                        valueListenable: _scheduler.inSmokingWindow,
                        builder: (context, isWindow, __) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isWindow
                                  ? 'Window ends in: $hh:$mm:$ss'
                                  : 'Next cigarette in: $hh:$mm:$ss',
                              style: const TextStyle(color: Colors.white),
                            ),
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // آمار لوکال (Prefs)
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

                  // دکمه‌ها (به Scheduler وصل)
                  Wrap(
                    spacing: 12,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          await _scheduler.smokeNow();
                          // اختیاری: سینک با کلود
                          // await DataService.instance.incrementSmoked();
                          if (mounted) setState(() {});
                        },
                        icon: const Icon(Icons.local_fire_department),
                        label: const Text('Mark Smoked'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await _scheduler.skipNow();
                          // اختیاری: سینک با کلود
                          // await DataService.instance.incrementSkipped();
                          if (mounted) setState(() {});
                        },
                        icon: const Icon(Icons.thumb_up_alt_outlined),
                        label: const Text('Mark Skipped'),
                      ),
                    ],
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

  Future<void> _onStartPressed() async {
    final txt = _controller.text.trim();
    final value = int.tryParse(txt);
    if (value == null || value <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid number > 0')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    await _scheduler.setCigsPerDay(value);
    await _scheduler.refreshFromPrefs();
    _lastSmoked  = _scheduler.smokedToday.value;
    _lastSkipped = _scheduler.skippedToday.value;
    if (mounted) setState(() {});
  }
}
