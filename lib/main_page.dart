import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> _initFirebase() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    await auth.signInAnonymously(); // ورود سریع برای تست
  }
}

void main() async {
  await _initFirebase();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const MainPage(),
    );
  }
}
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'notification_service.dart'; // برای iOS
import 'package:reduce_smoking_app/services/smoking_scheduler.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _scheduler = SmokingScheduler.instance;
  static const _channel = MethodChannel('smoking.native');

  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // فرض: init() در main.dart انجام شده. اینجا فقط سینک می‌کنیم.
    _scheduler.refreshFromPrefs().whenComplete(() {
      if (mounted) setState(() => _ready = true);
    });

    // پیام‌های نیتیو از MainActivity (Broadcast → MethodChannel)
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onCountsChanged') {
        final Map<String, dynamic> data =
        Map<String, dynamic>.from(call.arguments ?? {});

        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final nextAtMillis = (data['next_at_millis'] as int?) ?? 0;
        final windowEndMs = (data['smokingWindowEndTs'] as int?) ?? 0;

        // شمارنده‌ها
        if (data.containsKey('smoked_today')) {
          _scheduler.smokedToday.value =
              (data['smoked_today'] as int?) ?? _scheduler.smokedToday.value;
        }
        if (data.containsKey('skipped_today')) {
          _scheduler.skippedToday.value =
              (data['skipped_today'] as int?) ?? _scheduler.skippedToday.value;
        }

        // تایمر
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // هر بار اپ به فورگراند میاد → از Prefs بخون و تایمر/آمار را سینک کن
    if (state == AppLifecycleState.resumed) {
      _scheduler.refreshFromPrefs();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  // فقط برای iOS تست دستی
  Future<void> _showReminderNotification() async {
    if (Platform.isAndroid) return;
    await NotificationService.instance
        .scheduleCigarette(DateTime.now(), id: 999);
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

    // اگر هنوز تعداد نخ روزانه مشخص نشده
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
                decoration:
                const InputDecoration(labelText: 'Cigarettes per day'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final value = int.tryParse(_controller.text);
                  if (value != null && value > 0) {
                    await _scheduler.setCigsPerDay(value);
                    await _scheduler.refreshFromPrefs(); // فوراً UI سینک شود
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

    // صفحه‌ی تایمر
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
                  // لیبل پنجره‌ی ۵ دقیقه‌ای
                  ValueListenableBuilder<bool>(
                    valueListenable: _scheduler.inSmokingWindow,
                    builder: (context, isWindow, _) {
                      if (!isWindow) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Smoking window',
                            style: TextStyle(color: Colors.white)),
                      );
                    },
                  ),
                  // تایمر
                  ValueListenableBuilder<Duration>(
                    valueListenable: _scheduler.remaining,
                    builder: (context, duration, _) {
                      final hh =
                      duration.inHours.toString().padLeft(2, '0');
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
                  // آمار
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
