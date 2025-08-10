import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'notification_service.dart';
import 'native_bridge.dart';

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
  final ValueNotifier<Duration> remaining = ValueNotifier<Duration>(Duration.zero);

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
        final nextTime = DateTime.fromMillisecondsSinceEpoch(next, isUtc: false);
        _startCountdown(nextTime);
      }
    }
  }

  /// Number of cigarettes per day selected by the user.
  int? get cigsPerDay => _prefs.getInt(_cigsPerDayKey);

  /// Interval between cigarettes.
  Duration get interval =>
      cigsPerDay == null ? Duration.zero : Duration(minutes: (24 * 60 / cigsPerDay!).round());

  Future<void> _initNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    final darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [
        DarwinNotificationCategory(
          'cigarette',
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain('smoke', 'Smoke now'),
            DarwinNotificationAction.plain('skip', 'Skip'),
          ],
        ),
      ],
    );
    final settings = InitializationSettings(android: android, iOS: darwin);
    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse resp) {
        if (resp.actionId == 'smoke') {
          onSmokeNow();
        } else if (resp.actionId == 'skip') {
          onSkip();
        }
      },
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
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
      remaining.value = diff.isNegative ? Duration.zero : diff;
    }

    tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  /// Schedule a local notification at [time].
  Future<void> scheduleNotification(DateTime time) async {
    if (Platform.isAndroid) {
      // Use native scheduler via MethodChannel
      await NativeBridge.cancelAll();
      await NativeBridge.scheduleEpochList([time.millisecondsSinceEpoch]);
    } else {
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
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'cigarette',
      );
    }
  }

  /// Record a smoked cigarette.
  void registerSmoked() {
    _resetIfNewDay();
    smokedToday.value += 1;
    _prefs.setInt(_smokedKey, smokedToday.value);
  }

  /// Record a skipped cigarette.
  void registerSkipped() {
    _resetIfNewDay();
    skippedToday.value += 1;
    _prefs.setInt(_skippedKey, skippedToday.value);
  }

  /// Update remaining time until next cigarette (UI-only; does not start the ticker).
  void setRemaining(Duration d) {
    remaining.value = d;
  }

  /// Schedule the next cigarette (used when action is taken inside the app itself).
  void scheduleNext() {
    final next = DateTime.now().add(interval);
    _prefs.setInt(_nextCigKey, next.millisecondsSinceEpoch);
    _startCountdown(next);
    scheduleNotification(next);
  }

  /// User decides to smoke now (inside the app).
  void onSmokeNow() {
    registerSmoked();
    scheduleNext();
  }

  /// User decides to skip this cigarette (inside the app).
  void onSkip() {
    registerSkipped();
    scheduleNext();
  }

  /// NEW: Sync countdown from a native next-at timestamp (do NOT reschedule notifications here).
  void syncNextFromMillis(int nextAtMillis) {
    final next = DateTime.fromMillisecondsSinceEpoch(nextAtMillis);
    _prefs.setInt(_nextCigKey, nextAtMillis);
    _startCountdown(next); // starts the ticking timer so UI resets immediately
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

  Future<void> scheduleDay({
    required DateTime startLocal,
    required int cigsPerDay,
    required int gapMinutes,
  }) async {
    if (Platform.isAndroid) {
      await NativeBridge.cancelAll();
      final times = <int>[];
      for (int i = 0; i < cigsPerDay; i++) {
        final t = startLocal.add(Duration(minutes: gapMinutes * i));
        times.add(t.millisecondsSinceEpoch);
      }
      await NativeBridge.scheduleEpochList(times);
    } else {
      await NotificationService.instance.cancelAll();
      for (int i = 0; i < cigsPerDay; i++) {
        final t = startLocal.add(Duration(minutes: gapMinutes * i));
        await NotificationService.instance.scheduleCigarette(t, id: 1000 + i);
      }
    }

    // reset today counters
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('smoked_today', 0);
    await prefs.setInt('skipped_today', 0);
  }
}
