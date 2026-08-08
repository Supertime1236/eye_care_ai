import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemePreference { light, dark, system }

class ThemeProvider extends ChangeNotifier {
  static const _kThemePrefKey = 'pref_theme_mode'; // 'light' | 'dark' | 'system'

  ThemeProvider() {
    _loadSavedPreferences();
  }

  AppThemePreference _preference = AppThemePreference.system;
  // Độ sáng thật của MÀN HÌNH hiện tại (light/dark) — dùng khi preference = system.
  final Brightness _platformBrightness =
      WidgetsBinding.instance.platformDispatcher.platformBrightness;

  AppThemePreference get preference => _preference;

  bool get isDarkMode => switch (_preference) {
        AppThemePreference.dark => true,
        AppThemePreference.light => false,
        AppThemePreference.system => _platformBrightness == Brightness.dark,
      };

  ThemeMode get themeMode => switch (_preference) {
        AppThemePreference.dark => ThemeMode.dark,
        AppThemePreference.light => ThemeMode.light,
        AppThemePreference.system => ThemeMode.system,
      };

  Future<void> reload() => _loadSavedPreferences();

  Future<void> _loadSavedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kThemePrefKey);
    if (saved == null) {
      // Chưa từng chọn -> mặc định lấy đúng theo cài đặt sáng/tối của máy.
      _preference = AppThemePreference.system;
    } else {
      _preference = AppThemePreference.values.firstWhere(
        (e) => e.name == saved,
        orElse: () => AppThemePreference.system,
      );
    }
    notifyListeners();
  }

  Future<void> setPreference(AppThemePreference value) async {
    _preference = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemePrefKey, value.name);
    notifyListeners();
  }

  // Giữ tương thích ngược cho chỗ nào còn gọi toggleDarkMode(bool).
  Future<void> toggleDarkMode(bool value) =>
      setPreference(value ? AppThemePreference.dark : AppThemePreference.light);
}
