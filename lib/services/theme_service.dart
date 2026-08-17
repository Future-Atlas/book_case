import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const _darkModeKey = 'dark_mode_enabled';

  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  bool _isDarkMode = true;

  bool get isDarkMode => _isDarkMode;

  Future<void> initialize() async {
    _isDarkMode = await _preferences.getBool(_darkModeKey) ?? true;
  }

  Future<void> setDarkMode(bool enabled) async {
    if (_isDarkMode == enabled) return;
    _isDarkMode = enabled;
    notifyListeners();
    await _preferences.setBool(_darkModeKey, enabled);
  }
}
