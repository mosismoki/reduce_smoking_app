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

  // ---- Keys (aligned with FlutterSharedPreferences)
  static const _kCigsPerDay = 'cigsPerDay';
  static const _kNextTs     = 'nextCigTimestamp';   // epoch millis
  static const _kWinEndTs   = 'smokingWindowEndTs'; // epoch millis
  static const _kSmoked     = 'smoked_today';
  static const _kSkipped    = 'skipped_today';
  static const _kDate       = 'statsDate';          // yyyymmdd

  late SharedPreferences _prefs;
  Timer? _timer;

  // ---- Reactive state for UI
  final ValueNotifier<Duration> remaining       = ValueNotifier(Duration.zero);
  final ValueNotifier<int>      smokedToday     = ValueNotifier(0);
  final ValueNotifier<int>      skippedToday    = ValueNotifier(0);
  final ValueNotifier<bool>     inSmokingWindow = ValueNotifier(false);

  // Read-only plan
  int? get cigsPerDay => _initialized ? _prefs.getInt(_kCigsPerDay) : null;

  // iOS notifications (Android is native)
  final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // فاصله‌ی حداقل بین سیگارها از روی cigs/day (با کَلمپ و حداقل ۳۰ ثانیه)
  Duration get _interval {
    final raw = _prefs.getInt(_kCigsPerDay) ?? 0;
    if (raw <= 0) return Duration.zero;
    final cpd  = raw.clamp(1, 2000);
    final secs = (86400 / cpd).floor();
    return Duration(seconds: secs < 30 ? 30 : secs);
  }

  // ---- Lifecycle

  /// Call once at app boot (idempotent). لطفاً در main.dart صدا بزن.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try { tzdata.initializeTimeZones(); } catch (_) {}

    _prefs = await SharedPreferences.getInstance();
    try { await _prefs.reload(); } catch (_) {}

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
    try { await _notifications.initialize(initSettings); } catch (_) {}

    // لاگ وضعیت اولیه Prefs
    debugPrint('[Sched/init] cpd=${_prefs.getInt(_kCigsPerDay)} '
        'smoked=${_prefs.getInt(_kSmoked)} skipped=${_prefs.getInt(_kSkipped)} '
        'winEnd=${_prefs.getInt(_kWinEndTs)} nextTs=${_prefs.getInt(_kNextTs)} '
        'date=${_prefs.getString(_kDate)}');

    _hydrateAndRepair();
  }

  /// Call on resume (e.g. didChangeAppLifecycleState -> resumed)
  Future<void> refreshFromPrefs() async {
    try { await _prefs.reload(); } catch (_) {}
    _hydrateAndRepair();
  }

  /// Call on paused/inactive
  Future<void> flush() async {
    // اگر state معوقه داری اینجا persist کن؛ reload صرفاً sync می‌کند.
    try { await _prefs.reload(); } catch (_) {}
  }

  // ---- Public API

  Future<void> setCigsPerDay(int value) async {
    final v = value <= 0 ? 1 : value;
    final ok = await _prefs.setInt(_kCigsPerDay, v);
    debugPrint('[Sched/setCigsPerDay] set=$v ok=$ok');
    await scheduleNext();
  }

  /// باز کردن پنجره ۵ دقیقه‌ای و (اگر بیرون پنجره بودیم) ثبت ۱ واحد smoked
  Future<void> smokeNow() async {
    _resetIfNewDay();

    final nowMs  = DateTime.now().millisecondsSinceEpoch;
    final winEnd = nowMs + const Duration(minutes: 5).inMilliseconds;

    if (!inSmokingWindow.value) {
      smokedToday.value += 1;
      final ok = await _prefs.setInt(_kSmoked, smokedToday.value);
      debugPrint('[Sched/smokeNow] wrote smoked=${smokedToday.value} ok=$ok');
    }

    await _prefs.setInt(_kWinEndTs, winEnd);
    await _prefs.setInt(_kNextTs, 0);
    inSmokingWindow.value = true;

    debugPrint('[Sched/smokeNow] open window until=$winEnd');
    _startCountdownTo(winEnd);
  }

  /// رد کردن نوبت فعلی و رفتن به بعدی (اگر داخل پنجره بودیم اول پنجره را ببند)
  Future<void> skipNow() async {
    _resetIfNewDay();
    if (!inSmokingWindow.value) {
      skippedToday.value += 1;
      final ok = await _prefs.setInt(_kSkipped, skippedToday.value);
      debugPrint('[Sched/skipNow] wrote skipped=${skippedToday.value} ok=$ok');
    } else {
      inSmokingWindow.value = false;
      await _prefs.setInt(_kWinEndTs, 0);
      debugPrint('[Sched/skipNow] close window before scheduleNext');
    }
    await scheduleNext();
  }

  /// دکمه «Mark Smoked» (داخل/بیرون پنجره کار می‌کند)
  Future<void> markSmokedNow() async {
    _resetIfNewDay();
    if (inSmokingWindow.value) {
      smokedToday.value += 1;
      final ok = await _prefs.setInt(_kSmoked, smokedToday.value);
      debugPrint('[Sched/markSmokedNow] wrote smoked=${smokedToday.value} ok=$ok');
      inSmokingWindow.value = false;
      await _prefs.setInt(_kWinEndTs, 0);
      await scheduleNext();
    } else {
      await smokeNow();
    }
  }

  /// دکمه «Mark Skipped» (داخل/بیرون پنجره)
  Future<void> markSkippedNow() async {
    _resetIfNewDay();
    if (inSmokingWindow.value) {
      skippedToday.value += 1;
      final ok = await _prefs.setInt(_kSkipped, skippedToday.value);
      debugPrint('[Sched/markSkippedNow] wrote skipped=${skippedToday.value} ok=$ok');
      inSmokingWindow.value = false;
      await _prefs.setInt(_kWinEndTs, 0);
      await scheduleNext();
    } else {
      await skipNow();
    }
  }

  /// زمان‌بندی نوبت بعدی دقیقاً بر اساس فاصله‌ی فعلی
  Future<void> scheduleNext() async {
    final step = _interval;
    if (step == Duration.zero) {
      debugPrint('[Sched/scheduleNext] step=0 → no scheduling');
      return;
    }

    final nextMs = DateTime.now().add(step).millisecondsSinceEpoch;
    await _prefs.setInt(_kNextTs, nextMs);
    await _prefs.setInt(_kWinEndTs, 0);
    inSmokingWindow.value = false;

    debugPrint('[Sched/scheduleNext] nextTs=$nextMs step=${step.inSeconds}s');
    await _schedulePlatform(nextMs);
    _startCountdownTo(nextMs);
  }

  /// Sync عمومی از نیتیو → Flutter
  Future<void> syncFromMillis(int millis, {required bool isWindow}) async {
    if (isWindow) {
      await _prefs.setInt(_kWinEndTs, millis);
      await _prefs.setInt(_kNextTs, 0);
      inSmokingWindow.value = true;
      debugPrint('[Sched/sync] windowEnd=$millis');
    } else {
      await _prefs.setInt(_kNextTs, millis);
      await _prefs.setInt(_kWinEndTs, 0);
      inSmokingWindow.value = false;
      debugPrint('[Sched/sync] nextTs=$millis');
    }
    _startCountdownTo(millis);
  }

  @Deprecated('Use syncFromMillis(millis, isWindow: ...) instead')
  Future<void> syncNextFromMillis(int millis) async {
    await syncFromMillis(millis, isWindow: false);
  }

  // ---- Internals

  void _hydrateAndRepair() {
    _resetIfNewDay();

    smokedToday.value  = _prefs.getInt(_kSmoked)  ?? 0;
    skippedToday.value = _prefs.getInt(_kSkipped) ?? 0;

    debugPrint('[Sched/hydrate] smoked=${smokedToday.value} '
        'skipped=${skippedToday.value}');
    _startOrRepairCountdown();
  }

  Future<void> _startOrRepairCountdown() async {
    final nowMs  = DateTime.now().millisecondsSinceEpoch;
    final winEnd = _prefs.getInt(_kWinEndTs) ?? 0;
    int   nextTs = _prefs.getInt(_kNextTs)   ?? 0;

    final step = _interval;
    debugPrint('[Sched/repair] winEnd=$winEnd nextTs=$nextTs '
        'step=${step.inSeconds}s now=$nowMs');

    if (step == Duration.zero) {
      _cancelTicker();
      remaining.value = Duration.zero;
      inSmokingWindow.value = false;
      return;
    }

    int targetMs;

    if (winEnd > nowMs) {
      // هنوز داخل پنجره 5 دقیقه‌ای
      targetMs = winEnd;
      inSmokingWindow.value = true;
    } else {
      inSmokingWindow.value = false;

      if (nextTs <= 0) {
        nextTs = DateTime.now().add(step).millisecondsSinceEpoch;
      } else if (nextTs <= nowMs) {
        // اگر دستگاه خواب بوده/کشته شده، خودش را جلو بکِش
        final delta = nowMs - nextTs;
        final steps = (delta ~/ step.inMilliseconds) + 1;
        nextTs += steps * step.inMilliseconds;
      }
      await _prefs.setInt(_kNextTs, nextTs);

      await _schedulePlatform(nextTs);
      targetMs = nextTs;
    }

    _startCountdownTo(targetMs);
  }

  Future<void> _schedulePlatform(int whenMs) async {
    if (Platform.isAndroid) {
      try {
        await NativeBridge.cancelAll();
        await NativeBridge.scheduleEpochList([whenMs]);
      } catch (e) {
        debugPrint('[Sched/_schedulePlatform] Android native failed: $e');
      }
    } else {
      await _scheduleLocalNotification(
        DateTime.fromMillisecondsSinceEpoch(whenMs),
      );
    }
  }

  void _startCountdownTo(int targetMs) {
    _cancelTicker();

    void tick() {
      final remainMs = targetMs - DateTime.now().millisecondsSinceEpoch;
      if (remainMs <= 0) {
        _cancelTicker();

        if (inSmokingWindow.value) {
          // پایان پنجره بدون اقدام → بستن پنجره و زمان‌بندی نوبت بعد
          inSmokingWindow.value = false;
          _prefs.setInt(_kWinEndTs, 0);
          debugPrint('[Sched/tick] window ended → scheduleNext');
          scheduleNext(); // async
        } else {
          remaining.value = Duration.zero;
          debugPrint('[Sched/tick] reached nextTs');
        }
      } else {
        remaining.value = Duration(milliseconds: remainMs);
      }
    }

    // تیک فوری برای رفرش UI
    tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  void _cancelTicker() {
    _timer?.cancel();
    _timer = null;
  }

  // ---- iOS local notification (v17: فقط zonedSchedule)
  Future<void> _scheduleLocalNotification(DateTime time) async {
    const android = AndroidNotificationDetails(
      'cigarette_channel',
      'Cigarette schedule',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iOS = DarwinNotificationDetails();
    final details = NotificationDetails(android: android, iOS: iOS);

    final tzTime = tz.TZDateTime.from(time, tz.local);

    await _notifications.zonedSchedule(
      0,
      'Cigarette time',
      'Time to smoke',
      tzTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'cigarette',
    );
  }

  /// صفر کردن شمارنده‌ها تنها وقتی «روز عوض شده»
  void _resetIfNewDay() {
    final now = DateTime.now();
    final k = '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';

    final stored = _prefs.getString(_kDate);

    if (stored == null) {
      _prefs.setString(_kDate, k);
      debugPrint('[Sched/resetIfNewDay] first set date=$k');
      return;
    }

    if (stored != k) {
      smokedToday.value = 0;
      skippedToday.value = 0;
      _prefs
        ..setString(_kDate, k)
        ..setInt(_kSmoked, 0)
        ..setInt(_kSkipped, 0)
        ..setInt(_kWinEndTs, 0);
      inSmokingWindow.value = false;
      debugPrint('[Sched/resetIfNewDay] NEW DAY stored=$stored -> $k (counters reset)');
    } else {
      debugPrint('[Sched/resetIfNewDay] same day=$k (no reset)');
    }
  }
}
