import 'dart:io';
import 'package:flutter/services.dart';

class NativeBridge {
  static const MethodChannel _ch = MethodChannel('smoking.native');

  // متن‌های پیش‌فرض
  static const String _defaultTitle = 'Cigarette time';
  static const String _defaultBody = 'Do you want to smoke this cigarette?';

  // چک کردن پلتفرم
  static bool get _isAndroid => Platform.isAndroid;

  /// زمان‌بندی لیست Epoch‌ها برای نوتیفیکیشن
  static Future<void> scheduleEpochList(
      List<int> epochMillis, {
        String? title,
        String? body,
      }) async {
    if (!_isAndroid) return;
    await _ch.invokeMethod('scheduleList', {
      'times': epochMillis,
      'title': title ?? _defaultTitle,
      'body': body ?? _defaultBody,
    });
  }

  /// لغو همه نوتیفیکیشن‌ها
  static Future<void> cancelAll() async {
    if (!_isAndroid) return;
    await _ch.invokeMethod('cancelAll');
  }

  /// گرفتن تعداد سیگارهای کشیده/اسکیپ‌شده امروز
  static Future<Map<String, int>> getTodayCounts() async {
    if (!_isAndroid) return {'smoked_today': 0, 'skipped_today': 0};
    final res = await _ch.invokeMapMethod<String, int>('getTodayCounts') ?? {};
    return {
      'smoked_today': res['smoked_today'] ?? 0,
      'skipped_today': res['skipped_today'] ?? 0,
    };
  }

  /// صفر کردن شمارنده امروز
  static Future<void> resetTodayCounts() async {
    if (!_isAndroid) return;
    await _ch.invokeMethod('resetTodayCounts');
  }
}
