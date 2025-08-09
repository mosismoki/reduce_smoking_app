import 'dart:io';
import 'package:flutter/services.dart';

class NativeBridge {
  static const _ch = MethodChannel('smoking.native');

  static Future<void> scheduleEpochList(
    List<int> epochMillis, {
    String? title,
    String? body,
  }) async {
    if (!Platform.isAndroid) return;
    await _ch.invokeMethod('scheduleList', {
      'times': epochMillis,
      'title': title ?? 'Cigarette time',
      'body': body ?? 'Do you want to smoke this cigarette?',
    });
  }

  static Future<void> cancelAll() async {
    if (!Platform.isAndroid) return;
    await _ch.invokeMethod('cancelAll');
  }

  static Future<Map<String, int>> getTodayCounts() async {
    if (!Platform.isAndroid) return {'smoked_today': 0, 'skipped_today': 0};
    final res = await _ch.invokeMapMethod<String, int>('getTodayCounts');
    return {
      'smoked_today': res?['smoked_today'] ?? 0,
      'skipped_today': res?['skipped_today'] ?? 0,
    };
  }

  static Future<void> resetTodayCounts() async {
    if (!Platform.isAndroid) return;
    await _ch.invokeMethod('resetTodayCounts');
  }
}
