import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class TodayStats {
  final int smoked;
  final int skipped;
  final DateTime date;
  const TodayStats({required this.smoked, required this.skipped, required this.date});
}

class DataService {
  DataService._internal();
  static final DataService instance = DataService._internal();

  static const _kDate = 'statsDate';
  static const _kSmoked = 'smokedToday';
  static const _kSkipped = 'skippedToday';

  SharedPreferences? _prefs;
  final _controller = StreamController<TodayStats>.broadcast();

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _ensureToday();
    _emit();
  }

  /// استریم وضعیت امروز برای `watchToday()`
  Stream<TodayStats> watchToday() => _controller.stream;

  Future<void> incrementSmoked() async {
    await _ensureToday();
    final n = (_prefs?.getInt(_kSmoked) ?? 0) + 1;
    await _prefs?.setInt(_kSmoked, n);
    _emit();
  }

  Future<void> incrementSkipped() async {
    await _ensureToday();
    final n = (_prefs?.getInt(_kSkipped) ?? 0) + 1;
    await _prefs?.setInt(_kSkipped, n);
    _emit();
  }

  // --- کمک‌کننده‌ها ---
  Future<void> _ensureToday() async {
    final todayStr = _yyyyMmDd(DateTime.now());
    final saved = _prefs?.getString(_kDate);
    if (saved != todayStr) {
      await _prefs?.setString(_kDate, todayStr);
      await _prefs?.setInt(_kSmoked, 0);
      await _prefs?.setInt(_kSkipped, 0);
    }
  }

  void _emit() {
    final date = _prefs?.getString(_kDate);
    _controller.add(
      TodayStats(
        smoked: _prefs?.getInt(_kSmoked) ?? 0,
        skipped: _prefs?.getInt(_kSkipped) ?? 0,
        date: date != null ? DateTime.parse(date) : DateTime.now(),
      ),
    );
  }

  String _yyyyMmDd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
