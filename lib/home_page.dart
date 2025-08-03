import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  _handleAction(response.actionId);
}

Future<void> _handleAction(String? actionId) async {
  if (actionId == null) return;
  final prefs = await SharedPreferences.getInstance();
  int interval = prefs.getInt('interval') ?? 60;
  int leaves = prefs.getInt('leaves') ?? 0;
  int smoked = prefs.getInt('smoked') ?? 0;

  if (actionId == 'skip') {
    leaves += 1;
    interval += 5;
    await prefs.setInt('leaves', leaves);
    await prefs.setInt('interval', interval);
  } else if (actionId == 'smoke') {
    smoked += 1;
    await prefs.setInt('smoked', smoked);
  }

  final nextTime = DateTime.now().add(Duration(minutes: interval));
  await prefs.setInt('nextSmoke', nextTime.millisecondsSinceEpoch);
  await scheduleNotifications(nextTime);
}

Future<void> scheduleNotifications(DateTime time) async {
  await flutterLocalNotificationsPlugin.cancelAll();
  final androidDetails = AndroidNotificationDetails(
    'smoke_channel',
    'Smoking',
    channelDescription: 'Smoking reminders',
    importance: Importance.max,
    priority: Priority.high,
    actions: const [
      AndroidNotificationAction('skip', 'Skip',
          titleColor: Colors.green),
      AndroidNotificationAction('smoke', 'Smoke',
          titleColor: Colors.red),
    ],
  );
  final details = NotificationDetails(android: androidDetails);
  final firstDate =
      tz.TZDateTime.now(tz.local).add(time.difference(DateTime.now()));
  await flutterLocalNotificationsPlugin.zonedSchedule(
    0,
    'Time to smoke?',
    'You can smoke now.',
    firstDate,
    details,
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
  );

  final secondDate = firstDate.add(const Duration(minutes: 5));
  const secondDetails = NotificationDetails(
      android: AndroidNotificationDetails('smoke_channel', 'Smoking'));
  await flutterLocalNotificationsPlugin.zonedSchedule(
    1,
    'Smoking time is over',
    '',
    secondDate,
    secondDetails,
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
  );
}

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  int _leaves = 0;
  int _interval = 60;
  DateTime _nextSmoke = DateTime.now().add(const Duration(minutes: 60));

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    tz.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await flutterLocalNotificationsPlugin.initialize(initSettings,
        onDidReceiveNotificationResponse: (resp) async {
      await _handleAction(resp.actionId);
      await _loadPrefs();
    },
        onDidReceiveBackgroundNotificationResponse:
            notificationTapBackground);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    await _loadPrefs();
    await scheduleNotifications(_nextSmoke);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final diff = _nextSmoke.difference(DateTime.now());
      setState(() {
        _remaining = diff.isNegative ? Duration.zero : diff;
      });
    });
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _leaves = prefs.getInt('leaves') ?? 0;
    _interval = prefs.getInt('interval') ?? 60;
    final nextMillis = prefs.getInt('nextSmoke');
    if (nextMillis != null) {
      _nextSmoke = DateTime.fromMillisecondsSinceEpoch(nextMillis);
    } else {
      _nextSmoke = DateTime.now().add(Duration(minutes: _interval));
      await prefs.setInt('nextSmoke', _nextSmoke.millisecondsSinceEpoch);
    }
    _startTimer();
    setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 16,
          top: 16,
          child: Text(
            _formatDuration(_remaining),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.nature, size: 120, color: Colors.green),
              Wrap(
                alignment: WrapAlignment.center,
                children: List.generate(
                  _leaves,
                  (_) => const Icon(Icons.eco, color: Colors.green),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${h.toString().padLeft(2, '0')}:$m:$s';
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainPage> {
  int _index = 0;
  final _pages = const [
    const HomeView(),
    _AccountPage(),
    _SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Account'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class _AccountPage extends StatelessWidget {
  const _AccountPage();
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Account'));
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage();
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Settings'));
  }
}
