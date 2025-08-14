import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _fln =
  FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Timezone init (idempotent)
    try { tzdata.initializeTimeZones(); } catch (_) {}

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const init = InitializationSettings(android: androidInit, iOS: iosInit);

    try {
      await _fln.initialize(init);
    } catch (_) {}

    // Android 13+ runtime notif permission + exact alarms (با try/catch و null-safe)
    try {
      final android = _fln.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();
    } catch (_) {}

    // iOS permissions
    try {
      await _fln
          .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (_) {}
  }

  /// زمان‌بندی یک نوتیف برای زمان local مشخص (one-shot)
  Future<void> scheduleCigarette(DateTime localTime, {required int id}) async {
    const android = AndroidNotificationDetails(
      'cigarette_channel',        // یکسان با SmokingScheduler
      'Cigarette schedule',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    );
    const iOS = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: iOS);

    final tzTime = tz.TZDateTime.from(localTime, tz.local);

    await _fln.zonedSchedule(
      id,
      'Time to smoke',
      'Do you want to smoke this cigarette?',
      tzTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'cigarette',
    );
  }

  Future<void> cancelAll() => _fln.cancelAll();
}
