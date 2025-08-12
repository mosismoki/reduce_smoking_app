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
  static const _cigsPerDayKey = 'cigsPerDay';
  static const _nextCigKey    = 'nextCigTimestamp';   // millis
  static const _windowEndKey  = 'smokingWindowEndTs'; // millis
  static const _smokedKey     = 'smoked_today';
  static const _skippedKey    = 'skipped_today';
  static const _dateKey       = 'statsDate';          // yyyymmdd

  late SharedPreferences _prefs;
  Timer? _timer;

  // UI state
  final ValueNotifier<Duration> remaining       = ValueNotifier(Duration.zero);
  final ValueNotifier<int>      smokedToday     = ValueNotifier(0);
  final ValueNotifier<int>      skippedToday    = ValueNotifier(0);
  final ValueNotifier<bool>     inSmokingWindow = ValueNotifier(false);

  int? get cigsPerDay => _prefs.getInt(_cigsPerDayKey);

  final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  // ---- FIX: Safe interval (seconds-based, min 30s) ----
  Duration get _interval {
    final raw = _prefs.getInt(_cigsPerDayKey) ?? 0;
    if (raw <= 0) return Duration.zero;
    final cpd = raw.clamp(1, 2000); // safety bounds
    final secs = (86400 / cpd).floor();
    final safeSecs = secs < 30 ? 30 : secs;
    return Duration(seconds: safeSecs);
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
    await scheduleNext(); // re-schedule with new interval
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
    final step = _interval;
    if (step == Duration.zero) return;

    final next = DateTime.now().add(step);
    final nextMs = next.millisecondsSinceEpoch;

    await _prefs.setInt(_nextCigKey, nextMs);
    await _prefs.setInt(_windowEndKey, 0);
    inSmokingWindow.value = false;

    if (Platform.isAndroid) {
      try {
        await NativeBridge.cancelAll();
        await NativeBridge.scheduleEpochList([nextMs]);
      } catch (_) {
        await _scheduleLocalNotification(next);
      }
    } else {
      await _scheduleLocalNotification(next);
    }

    _startCountdownTo(nextMs);
  }

  // ---- FIX: robust restore + fast-forward if past ----
  Future<void> _startOrRepairCountdown() async {
    final nowMs   = DateTime.now().millisecondsSinceEpoch;
    final winEnd  = _prefs.getInt(_windowEndKey) ?? 0;
    int   nextTs  = _prefs.getInt(_nextCigKey)   ?? 0;

    final step = _interval;
    if (step == Duration.zero) return;

    int targetMs;

    if (winEnd > nowMs) {
      // still inside 5-minute window
      targetMs = winEnd;
      inSmokingWindow.value = true;
    } else {
      inSmokingWindow.value = false;

      if (nextTs <= 0) {
        nextTs = DateTime.now().add(step).millisecondsSinceEpoch;
      } else if (nextTs <= nowMs) {
        // Fast-forward in fixed multiples until the next time is in the future
        final delta = nowMs - nextTs;
        final steps = (delta ~/ step.inMilliseconds) + 1;
        nextTs += steps * step.inMilliseconds;
      }

      await _prefs.setInt(_nextCigKey, nextTs);
      targetMs = nextTs;

      // Ensure a notification is scheduled (best-effort)
      if (Platform.isAndroid) {
        try {
          await NativeBridge.cancelAll();
          await NativeBridge.scheduleEpochList([nextTs]);
        } catch (_) {
          await _scheduleLocalNotification(
              DateTime.fromMillisecondsSinceEpoch(nextTs));
        }
      } else {
        await _scheduleLocalNotification(
            DateTime.fromMillisecondsSinceEpoch(nextTs));
      }
    }

    _startCountdownTo(targetMs);
  }

  void _startCountdownTo(int targetMs) {
    _timer?.cancel();

    void tick() {
      final remainMs = targetMs - DateTime.now().millisecondsSinceEpoch;

      if (remainMs <= 0) {
        _timer?.cancel();
        if (inSmokingWindow.value) {
          // After 5-min window ends, immediately schedule next slot
          scheduleNext();
        } else {
          // Wait for user action (Accept/Skip) or notification action
          remaining.value = Duration.zero;
        }
      } else {
        remaining.value = Duration(milliseconds: remainMs);
      }
    }

    tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  // Optional: when native sends a new exact millis
  Future<void> syncNextFromMillis(int millis) async {
    await _prefs.setInt(_nextCigKey, millis);
    inSmokingWindow.value = false;
    _startCountdownTo(millis);
  }

  Future<void> _scheduleLocalNotification(DateTime time) async {
    final android = const AndroidNotificationDetails(
      'cigarette_channel',
      'Cigarette schedule',
      importance: Importance.max,
      priority: Priority.high,
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

  // ---- FIX: date key normalized yyyymmdd ----
  void _resetIfNewDay() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final todayKey = '$y$m$d';

    final stored = _prefs.getString(_dateKey);
    if (stored != todayKey) {
      smokedToday.value = 0;
      skippedToday.value = 0;
      _prefs
        ..setString(_dateKey, todayKey)
        ..setInt(_smokedKey, 0)
        ..setInt(_skippedKey, 0);
    }
  }
}
