import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Manages cigarette scheduling, timers, notifications, and analytics.
class SmokingScheduler {
  SmokingScheduler._internal();

  static final SmokingScheduler instance = SmokingScheduler._internal();

  static const _cigsPerDayKey = 'cigsPerDay';
  static const _nextCigKey = 'nextCigTimestamp';
  static const _smokedKey = 'smokedToday';
  static const _skippedKey = 'skippedToday';
  static const _dateKey = 'statsDate';

  late SharedPreferences _prefs;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Timer? _timer;

  /// Remaining time until next cigarette.
  final ValueNotifier<Duration> remaining =
      ValueNotifier<Duration>(Duration.zero);

  /// Total cigarettes smoked today.
  final ValueNotifier<int> smokedToday = ValueNotifier<int>(0);

  /// Total cigarettes skipped today.
  final ValueNotifier<int> skippedToday = ValueNotifier<int>(0);

  /// Initialise preferences, notification plugin and resume any timers.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    tz.initializeTimeZones();
    await _initNotifications();

    smokedToday.value = _prefs.getInt(_smokedKey) ?? 0;
    skippedToday.value = _prefs.getInt(_skippedKey) ?? 0;

    _resetIfNewDay();

    if (cigsPerDay != null) {
      final next = _prefs.getInt(_nextCigKey);
      if (next != null) {
        final nextTime =
            DateTime.fromMillisecondsSinceEpoch(next, isUtc: false);
        _startCountdown(nextTime);
      }
    }
  }

  /// Number of cigarettes per day selected by the user.
  int? get cigsPerDay => _prefs.getInt(_cigsPerDayKey);

  /// Interval between cigarettes.
  Duration get interval => cigsPerDay == null
      ? Duration.zero
      : Duration(minutes: (24 * 60 / cigsPerDay!).round());

  Future<void> _initNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    final darwin = DarwinInitializationSettings(notificationCategories: [
      DarwinNotificationCategory('cigarette', actions: <DarwinNotificationAction>[
        const DarwinNotificationAction.plain('smoke', 'Smoke now'),
        const DarwinNotificationAction.plain('skip', 'Skip'),
      ])
    ]);
    final settings = InitializationSettings(android: android, iOS: darwin);
    await _notifications.initialize(settings,
        onDidReceiveNotificationResponse: (NotificationResponse resp) {
      if (resp.actionId == 'smoke') {
        onSmokeNow();
      } else if (resp.actionId == 'skip') {
        onSkip();
      }
    });

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestPermission();
    await _notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Set cigarettes per day and schedule the first cigarette.
  void setCigsPerDay(int value) {
    _prefs.setInt(_cigsPerDayKey, value);
    final next = DateTime.now().add(interval);
    _prefs.setInt(_nextCigKey, next.millisecondsSinceEpoch);
    _startCountdown(next);
    scheduleNotification(next);
  }

  void _startCountdown(DateTime next) {
    _timer?.cancel();
    void tick() {
      final now = DateTime.now();
      final diff = next.difference(now);
      if (diff.isNegative) {
        remaining.value = Duration.zero;
      } else {
        remaining.value = diff;
      }
    }

    tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  /// Schedule a local notification at [time].
  Future<void> scheduleNotification(DateTime time) async {
    await _notifications.zonedSchedule(
      0,
      'Cigarette time',
      'Time to smoke',
      tz.TZDateTime.from(time, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'cigarette_channel',
          'Cigarette schedule',
          importance: Importance.max,
          priority: Priority.high,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction('smoke', 'Smoke now'),
            AndroidNotificationAction('skip', 'Skip'),
          ],
        ),
        iOS: DarwinNotificationDetails(categoryIdentifier: 'cigarette'),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'cigarette',
    );
  }

  /// User decides to smoke now.
  void onSmokeNow() {
    _resetIfNewDay();
    smokedToday.value += 1;
    _prefs.setInt(_smokedKey, smokedToday.value);

    final next = DateTime.now().add(interval);
    _prefs.setInt(_nextCigKey, next.millisecondsSinceEpoch);
    _startCountdown(next);
    scheduleNotification(next);
  }

  /// User decides to skip this cigarette.
  void onSkip() {
    _resetIfNewDay();
    skippedToday.value += 1;
    _prefs.setInt(_skippedKey, skippedToday.value);

    final next = DateTime.now().add(interval);
    _prefs.setInt(_nextCigKey, next.millisecondsSinceEpoch);
    _startCountdown(next);
    scheduleNotification(next);
  }

  void _resetIfNewDay() {
    final today = DateTime.now();
    final todayStr = _dateString(today);
    final stored = _prefs.getString(_dateKey);
    if (stored != todayStr) {
      smokedToday.value = 0;
      skippedToday.value = 0;
      _prefs
        ..setString(_dateKey, todayStr)
        ..setInt(_smokedKey, 0)
        ..setInt(_skippedKey, 0);
    }
  }

  String _dateString(DateTime d) => '${d.year}-${d.month}-${d.day}';
}

