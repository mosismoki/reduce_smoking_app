import 'package:shared_preferences/shared_preferences.dart';

class DataService {
  DataService._internal();
  static final DataService instance = DataService._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // نمونه متدهای بی‌خطر تا ارجاعات نخوابند
  int getInt(String key, {int defaultValue = 0}) {
    return _prefs?.getInt(key) ?? defaultValue;
  }

  Future<void> setInt(String key, int value) async {
    await _prefs?.setInt(key, value);
  }

  String getString(String key, {String defaultValue = ''}) {
    return _prefs?.getString(key) ?? defaultValue;
  }

  Future<void> setString(String key, String value) async {
    await _prefs?.setString(key, value);
  }
}
