import 'dart:io';
import 'package:flutter/services.dart';

class NativeBridge {
  static const MethodChannel _ch = MethodChannel('smoking.native');

  static const String _defaultTitle = 'Cigarette time';
  static const String _defaultBody  = 'Do you want to smoke this cigarette?';

  static bool get _isAndroid => Platform.isAndroid;

  static Future<void> scheduleEpochList(
      List<int> epochMillis, {
        String? title,
        String? body,
      }) async {
    if (!_isAndroid) return;
    await _ch.invokeMethod('scheduleList', <String, dynamic>{
      'times': epochMillis,
      'title': title ?? _defaultTitle,
      'body' : body  ?? _defaultBody,
    });
  }

  static Future<void> cancelAll() async {
    if (!_isAndroid) return;
    await _ch.invokeMethod('cancelAll');
  }

  static Future<Map<String, int>> getTodayCounts() async {
    if (!_isAndroid) return const {'smoked_today': 0, 'skipped_today': 0};
    final res = await _ch.invokeMapMethod<String, Object?>('getTodayCounts');
    if (res == null) return const {'smoked_today': 0, 'skipped_today': 0};
    return {
      'smoked_today': (res['smoked_today'] as int?) ?? 0,
      'skipped_today': (res['skipped_today'] as int?) ?? 0,
    };
  }

  static Future<void> resetTodayCounts() async {
    if (!_isAndroid) return;
    await _ch.invokeMethod('resetTodayCounts');
  }

  /// اختیاری: گرفتن وضعیت زمان‌بندی از نیتیو برای دیباگ
  static Future<Map<String, int>> getScheduleState() async {
    if (!_isAndroid) return const {'nextTs': 0, 'winEnd': 0};
    final res = await _ch.invokeMapMethod<String, Object?>('getScheduleState');
    if (res == null) return const {'nextTs': 0, 'winEnd': 0};
    return {
      'nextTs': (res['nextTs'] as int?) ?? 0,
      'winEnd': (res['winEnd'] as int?) ?? 0,
    };
  }
}
