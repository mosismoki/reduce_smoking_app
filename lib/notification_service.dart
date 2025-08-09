import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();
  final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();

  static const String channelId = 'smoke_schedule';
  static const String channelName = 'Smoking Schedule';
  static const String actionAccept = 'ACCEPT_CIG';
  static const String actionSkip = 'SKIP_CIG';

  Future<void> init() async {
    tzdata.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const init = InitializationSettings(android: androidInit, iOS: iosInit);

    await _fln.initialize(
      init,
      onDidReceiveNotificationResponse: _onForegroundAction,
      onDidReceiveBackgroundNotificationResponse: NotificationService.onBackgroundAction,
    );

    final android = _fln.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.requestNotificationsPermission();
      await android.requestExactAlarmsPermission();
    }
  }

  void _onForegroundAction(NotificationResponse r) {
    _handleAction(r.actionId);
  }

  @pragma('vm:entry-point')
  static void onBackgroundAction(NotificationResponse r) {
    NotificationService.instance._handleAction(r.actionId);
  }

  Future<void> _handleAction(String? actionId) async {
    final prefs = await SharedPreferences.getInstance();
    if (actionId == actionAccept) {
      final n = prefs.getInt('smoked_today') ?? 0;
      await prefs.setInt('smoked_today', n + 1);
      // TODO: optionally reschedule here based on adaptive logic
    } else if (actionId == actionSkip) {
      final n = prefs.getInt('skipped_today') ?? 0;
      await prefs.setInt('skipped_today', n + 1);
      // TODO: increase gap and reschedule if needed
    }
  }

  AndroidNotificationDetails _androidDetails() {
    return const AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(actionAccept, 'Accept',
            showsUserInterface: false, cancelNotification: true),
        AndroidNotificationAction(actionSkip, 'Skip',
            showsUserInterface: false, cancelNotification: true),
      ],
    );
  }

  Future<void> scheduleCigarette(DateTime localTime, {required int id}) async {
    final details = NotificationDetails(android: _androidDetails());
    await _fln.zonedSchedule(
      id,
      'Time to smoke',
      'Do you want to smoke this cigarette?',
      tz.TZDateTime.from(localTime, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: null,
      payload: 'cigarette',
    );
  }

  Future<void> cancel(int id) => _fln.cancel(id);
  Future<void> cancelAll() => _fln.cancelAll();
}
