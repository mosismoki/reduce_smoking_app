// lib/services/smoking_scheduler.dart
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

  // Keys (هماهنگ با FlutterSharedPreferences)
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

  // فقط برای iOS استفاده می‌شود؛ روی اندروید نوتیف را نیتیو زمان‌بندی می‌کنیم
  final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  // فاصلهٔ ایمن (حداقل 30 ثانیه)
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

  /// شبیه ACCEPT از نوتیف، وقتی پنجره باز نیست → پنجره ۵ دقیقه‌ای را باز می‌کند.
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

  /// شبیه SKIP وقتی پنجره باز نیست → مستقیماً می‌رود سراغ نوبت بعد
  Future<void> skipNow() async {
    _resetIfNewDay();
    skippedToday.value += 1;
    await _prefs.setInt(_kSkipped, skippedToday.value);
    await scheduleNext();
  }

  /// دکمهٔ «Mark Smoked» (در صورت نیاز)
  Future<void> markSmokedNow() async {
    _resetIfNewDay();
    if (inSmokingWindow.value) {
      smokedToday.value += 1;
      await _prefs.setInt(_kSmoked, smokedToday.value);
      inSmokingWindow.value = false;
      await _prefs.setInt(_kWinEndTs, 0);
      await scheduleNext();
    } else {
      await smokeNow();
    }
  }

  /// دکمهٔ «Mark Skipped» (در صورت نیاز)
  Future<void> markSkippedNow() async {
    _resetIfNewDay();
    if (inSmokingWindow.value) {
      skippedToday.value += 1;
      await _prefs.setInt(_kSkipped, skippedToday.value);
      inSmokingWindow.value = false;
      await _prefs.setInt(_kWinEndTs, 0);
      await scheduleNext();
    } else {
      await skipNow();
    }
  }

  /// تنظیم نوبت بعد با فاصلهٔ اصلی
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
        await NativeBridge.scheduleEpochList([nextMs]); // فقط نیتیو
      } catch (_) {
        // فالبک اندروید عمداً حذف شد
      }
    } else {
      await _scheduleLocalNotification(DateTime.fromMillisecondsSinceEpoch(nextMs));
    }

    _startCountdownTo(nextMs);
  }

  /// تعمیر/شروع شمارش بر اساس وضعیت ذخیره‌شده
  Future<void> _startOrRepairCountdown() async {
    final nowMs  = DateTime.now().millisecondsSinceEpoch;
    final winEnd = _prefs.getInt(_kWinEndTs) ?? 0;
    int   nextTs = _prefs.getInt(_kNextTs)   ?? 0;

    final step = _interval;
    if (step == Duration.zero) return;

    int targetMs;

    if (winEnd > nowMs) {
      // هنوز در پنجرهٔ ۵ دقیقه‌ای هستیم
      targetMs = winEnd;
      inSmokingWindow.value = true;
    } else {
      // بیرون پنجره → سراغ نوبت بعدی
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
          await NativeBridge.scheduleEpochList([nextTs]);
        } catch (_) {}
      } else {
        await _scheduleLocalNotification(DateTime.fromMillisecondsSinceEpoch(nextTs));
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
          // پنجره تمام شد و کاربر اقدامی نکرد → برو سراغ نوبت بعد
          inSmokingWindow.value = false;
          _prefs.setInt(_kWinEndTs, 0);
          scheduleNext();
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

  /// متد جدید برای سینک از سمت نیتیو/کانال
  Future<void> syncFromMillis(int millis, {required bool isWindow}) async {
    if (isWindow) {
      await _prefs.setInt(_kWinEndTs, millis);
      await _prefs.setInt(_kNextTs, 0);
      inSmokingWindow.value = true;
    } else {
      await _prefs.setInt(_kNextTs, millis);
      await _prefs.setInt(_kWinEndTs, 0);
      inSmokingWindow.value = false;
    }
    _startCountdownTo(millis);
  }

  /// برای سازگاری با کدهای قبلی (قدیمی)
  @Deprecated('Use syncFromMillis(millis, isWindow: ...) instead')
  Future<void> syncNextFromMillis(int millis) async {
    await syncFromMillis(millis, isWindow: false);
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

  /// فیکس: در اولین اجرا امروز، فقط تاریخ را ست کن و آمار را صفر نکن
  void _resetIfNewDay() {
    final now = DateTime.now();
    final k = '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final stored = _prefs.getString(_kDate);

    if (stored == null) {
      _prefs.setString(_kDate, k);
      return;
    }

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
