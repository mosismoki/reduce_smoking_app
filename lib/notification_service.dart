import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();
  final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tzdata.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const init = InitializationSettings(android: androidInit, iOS: iosInit);

    await _fln.initialize(init);
    final android = _fln.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.requestNotificationsPermission();
      await android.requestExactAlarmsPermission();
    }
  }

  Future<void> scheduleCigarette(DateTime localTime, {required int id}) async {
    const android = AndroidNotificationDetails(
      'smoke_schedule', 'Smoking Schedule',
      importance: Importance.max, priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    );
    const details = NotificationDetails(android: android);
    await _fln.zonedSchedule(
      id,
      'Time to smoke',
      'Do you want to smoke this cigarette?',
      tz.TZDateTime.from(localTime, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelAll() => _fln.cancelAll();
}
