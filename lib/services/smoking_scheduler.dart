import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:reduce_smoking_app/native_bridge.dart';

class SmokingScheduler {
  SmokingScheduler._internal();
  static final SmokingScheduler instance = SmokingScheduler._internal();

  // Keys
  static const _cigsPerDayKey   = 'cigsPerDay';
  static const _nextCigKey      = 'nextCigTimestamp';
  static const _windowEndKey    = 'smokingWindowEndTs';
  static const _smokedKey       = 'smoked_today';
  static const _skippedKey      = 'skipped_today';
  static const _dateKey         = 'statsDate';

  late SharedPreferences _prefs;
  Timer? _timer;

  // UI state
  final ValueNotifier<Duration> remaining = ValueNotifier(Duration.zero);
  final ValueNotifier<int> smokedToday    = ValueNotifier(0);
  final ValueNotifier<int> skippedToday   = ValueNotifier(0);
  final ValueNotifier<bool> inSmokingWindow = ValueNotifier(false);

  // 👇 گتر عمومی برای استفاده در MainPage
  int? get cigsPerDay => _prefs.getInt(_cigsPerDayKey);

  final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  Duration get _interval {
    final cigs = _prefs.getInt(_cigsPerDayKey) ?? 0;
    if (cigs <= 0) return Duration.zero;
    return Duration(minutes: (24 * 60 / cigs).round());
  }

  Future<void> init() async {
    tzdata.initializeTimeZones();
    _prefs = await SharedPreferences.getInstance();

    _resetIfNewDay();
    smokedToday.value  = _prefs.getInt(_smokedKey)  ?? 0;
    skippedToday.value = _prefs.getInt(_skippedKey) ?? 0;

    if ((_prefs.getInt(_cigsPerDayKey) ?? 0) <= 0) return;

    await _startOrRepairCountdown();
  }

  Future<void> refreshFromPrefs() async {
    _resetIfNewDay();
    smokedToday.value  = _prefs.getInt(_smokedKey)  ?? 0;
    skippedToday.value = _prefs.getInt(_skippedKey) ?? 0;
    await _startOrRepairCountdown();
  }

  Future<void> setCigsPerDay(int value) async {
    await _prefs.setInt(_cigsPerDayKey, value);
    await scheduleNext();
  }

  Future<void> smokeNow() async {
    _resetIfNewDay();
    smokedToday.value += 1;
    await _prefs.setInt(_smokedKey, smokedToday.value);

    final now = DateTime.now().millisecondsSinceEpoch;
    final windowEnd = now + const Duration(minutes: 5).inMilliseconds;
    await _prefs.setInt(_windowEndKey, windowEnd);
    await _prefs.setInt(_nextCigKey, 0);
    inSmokingWindow.value = true;

    _startCountdownTo(windowEnd);
  }

  Future<void> skipNow() async {
    _resetIfNewDay();
    skippedToday.value += 1;
    await _prefs.setInt(_skippedKey, skippedToday.value);
    await scheduleNext();
  }

  Future<void> scheduleNext() async {
    final next = DateTime.now().add(_interval);
    await _prefs.setInt(_nextCigKey, next.millisecondsSinceEpoch);
    await _prefs.setInt(_windowEndKey, 0);
    inSmokingWindow.value = false;

    if (Platform.isAndroid) {
      try {
        await NativeBridge.cancelAll();
        await NativeBridge.scheduleEpochList([next.millisecondsSinceEpoch]);
      } catch (_) {
        await _scheduleLocalNotification(next);
      }
    } else {
      await _scheduleLocalNotification(next);
    }

    _startCountdownTo(next.millisecondsSinceEpoch);
  }

  Future<void> _startOrRepairCountdown() async {
    final nowMs  = DateTime.now().millisecondsSinceEpoch;
    final winEnd = _prefs.getInt(_windowEndKey) ?? 0;
    var   nextTs = _prefs.getInt(_nextCigKey)   ?? 0;

    int target;
    if (winEnd > nowMs) {
      target = winEnd;
      inSmokingWindow.value = true;
    } else {
      if (nextTs <= nowMs || nextTs == 0) {
        final next = DateTime.now().add(_interval);
        nextTs = next.millisecondsSinceEpoch;
        await _prefs.setInt(_nextCigKey, nextTs);

        if (Platform.isAndroid) {
          try {
            await NativeBridge.cancelAll();
            await NativeBridge.scheduleEpochList([nextTs]);
          } catch (_) {
            await _scheduleLocalNotification(DateTime.fromMillisecondsSinceEpoch(nextTs));
          }
        } else {
          await _scheduleLocalNotification(DateTime.fromMillisecondsSinceEpoch(nextTs));
        }
      }
      target = nextTs;
      inSmokingWindow.value = false;
    }

    _startCountdownTo(target);
  }

  void _startCountdownTo(int targetMs) {
    _timer?.cancel();
    void tick() {
      final remain = targetMs - DateTime.now().millisecondsSinceEpoch;
      if (remain <= 0) {
        _timer?.cancel();
        if (inSmokingWindow.value) {
          scheduleNext();
        } else {
          remaining.value = Duration.zero;
        }
      } else {
        remaining.value = Duration(milliseconds: remain);
      }
    }
    tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  void syncNextFromMillis(int millis) {
    _startCountdownTo(millis);
  }

  Future<void> _scheduleLocalNotification(DateTime time) async {
    final android = const AndroidNotificationDetails(
      'cigarette_channel', 'Cigarette schedule',
      importance: Importance.max, priority: Priority.high,
    );
    final iOS = const DarwinNotificationDetails();
    final details = NotificationDetails(android: android, iOS: iOS);

    await _notifications.zonedSchedule(
      0,
      'Cigarette time',
      'Time to smoke',
      tz.TZDateTime.from(time, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'cigarette',
    );
  }

  void _resetIfNewDay() {
    final today = DateTime.now();
    final key = '${today.year}-${today.month}-${today.day}';
    final stored = _prefs.getString(_dateKey);
    if (stored != key) {
      smokedToday.value = 0;
      skippedToday.value = 0;
      _prefs
        ..setString(_dateKey, key)
        ..setInt(_smokedKey, 0)
        ..setInt(_skippedKey, 0);
    }
  }
}
