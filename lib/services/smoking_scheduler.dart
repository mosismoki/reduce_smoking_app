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

  // Keys (با FlutterSharedPreferences هم‌خوان)
  static const _kCigsPerDay = 'cigsPerDay';
  static const _kNextTs     = 'nextCigTimestamp';   // millis
  static const _kWinEndTs   = 'smokingWindowEndTs'; // millis
  static const _kSmoked     = 'smoked_today';
  static const _kSkipped    = 'skipped_today';
  static const _kDate       = 'statsDate';          // yyyymmdd

  late SharedPreferences _prefs;
  Timer? _timer;

  final ValueNotifier<Duration> remaining       = ValueNotifier(Duration.zero);
  final ValueNotifier<int>      smokedToday     = ValueNotifier(0);
  final ValueNotifier<int>      skippedToday    = ValueNotifier(0);
  final ValueNotifier<bool>     inSmokingWindow = ValueNotifier(false);

  int? get cigsPerDay => _prefs.getInt(_kCigsPerDay);

  // برای iOS استفاده می‌شود؛ روی اندروید دیگر ازش استفاده نمی‌کنیم
  final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  // فاصله امن (ثانیه‌ای، حداقل 30s)
  Duration get _interval {
    final raw = _prefs.getInt(_kCigsPerDay) ?? 0;
    if (raw <= 0) return Duration.zero;
    final cpd = raw.clamp(1, 2000);
    final secs = (86400 / cpd).floor();
    return Duration(seconds: secs < 30 ? 30 : secs);
  }

  Future<void> init() async {
    tzdata.initializeTimeZones();
    _prefs = await SharedPreferences.getInstance();
    _resetIfNewDay();
    smokedToday.value  = _prefs.getInt(_kSmoked)  ?? 0;
    skippedToday.value = _prefs.getInt(_kSkipped) ?? 0;
    if ((_prefs.getInt(_kCigsPerDay) ?? 0) > 0) {
      await _startOrRepairCountdown();
    }
  }

  Future<void> refreshFromPrefs() async {
    _resetIfNewDay();
    smokedToday.value  = _prefs.getInt(_kSmoked)  ?? 0;
    skippedToday.value = _prefs.getInt(_kSkipped) ?? 0;
    await _startOrRepairCountdown();
  }

  Future<void> setCigsPerDay(int value) async {
    await _prefs.setInt(_kCigsPerDay, value);
    await scheduleNext();
  }

  Future<void> smokeNow() async {
    _resetIfNewDay();
    smokedToday.value += 1;
    await _prefs.setInt(_kSmoked, smokedToday.value);

    final now = DateTime.now().millisecondsSinceEpoch;
    final winEnd = now + const Duration(minutes: 5).inMilliseconds;
    await _prefs.setInt(_kWinEndTs, winEnd);
    await _prefs.setInt(_kNextTs, 0);
    inSmokingWindow.value = true;

    _startCountdownTo(winEnd);
  }

  Future<void> skipNow() async {
    _resetIfNewDay();
    skippedToday.value += 1;
    await _prefs.setInt(_kSkipped, skippedToday.value);
    await scheduleNext();
  }

  Future<void> scheduleNext() async {
    final step = _interval;
    if (step == Duration.zero) return;

    final nextMs = DateTime.now().add(step).millisecondsSinceEpoch;
    await _prefs.setInt(_kNextTs, nextMs);
    await _prefs.setInt(_kWinEndTs, 0);
    inSmokingWindow.value = false;

    if (Platform.isAndroid) {
      try {
        await NativeBridge.cancelAll();
        await NativeBridge.scheduleEpochList([nextMs]); // CHANGED: فقط نیتیو
      } catch (_) {
        // CHANGED: فالبک اندروید حذف شد تا نوتیفِ فلاتر ساخته نشه
      }
    } else {
      await _scheduleLocalNotification(
          DateTime.fromMillisecondsSinceEpoch(nextMs));
    }

    _startCountdownTo(nextMs);
  }

  Future<void> _startOrRepairCountdown() async {
    final nowMs  = DateTime.now().millisecondsSinceEpoch;
    final winEnd = _prefs.getInt(_kWinEndTs) ?? 0;
    int   nextTs = _prefs.getInt(_kNextTs)   ?? 0;

    final step = _interval;
    if (step == Duration.zero) return;

    int targetMs;

    if (winEnd > nowMs) {
      targetMs = winEnd;
      inSmokingWindow.value = true;
    } else {
      inSmokingWindow.value = false;

      if (nextTs <= 0) {
        nextTs = DateTime.now().add(step).millisecondsSinceEpoch;
      } else if (nextTs <= nowMs) {
        final delta = nowMs - nextTs;
        final steps = (delta ~/ step.inMilliseconds) + 1;
        nextTs += steps * step.inMilliseconds;
      }
      await _prefs.setInt(_kNextTs, nextTs);

      // تضمین زمان‌بندی اندروید
      if (Platform.isAndroid) {
        try {
          await NativeBridge.cancelAll();
          await NativeBridge.scheduleEpochList([nextTs]); // CHANGED: فقط نیتیو
        } catch (_) {
          // CHANGED: فالبک اندروید حذف شد
        }
      } else {
        await _scheduleLocalNotification(
            DateTime.fromMillisecondsSinceEpoch(nextTs));
      }

      targetMs = nextTs;
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
          scheduleNext(); // بعد از ۵ دقیقه
        } else {
          remaining.value = Duration.zero;
        }
      } else {
        remaining.value = Duration(milliseconds: remainMs);
      }
    }
    tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  Future<void> syncNextFromMillis(int millis) async {
    await _prefs.setInt(_kNextTs, millis);
    inSmokingWindow.value = false;
    _startCountdownTo(millis);
  }

  // فقط برای iOS
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
    final now = DateTime.now();
    final k = '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final stored = _prefs.getString(_kDate);
    if (stored != k) {
      smokedToday.value = 0;
      skippedToday.value = 0;
      _prefs
        ..setString(_kDate, k)
        ..setInt(_kSmoked, 0)
        ..setInt(_kSkipped, 0);
    }
  }
}
