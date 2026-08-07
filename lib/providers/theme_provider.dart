import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemePreference { light, dark, system }

class ThemeProvider extends ChangeNotifier {
  static const _kThemePrefKey = 'pref_theme_mode'; // 'light' | 'dark' | 'system'
  static const _kBlueLightEnabledKey = 'pref_blue_light_filter_enabled';
  static const _kBlueLightIntensityKey = 'pref_blue_light_filter_intensity';

  ThemeProvider() {
    _loadSavedPreferences();
  }

  AppThemePreference _preference = AppThemePreference.system;
  // Độ sáng thật của MÀN HÌNH hiện tại (light/dark) — dùng khi preference = system.
  final Brightness _platformBrightness =
      WidgetsBinding.instance.platformDispatcher.platformBrightness;

  // Bộ lọc ánh sáng xanh: phủ 1 lớp màu hổ phách mờ lên TOÀN BỘ app (xem
  // builder của MaterialApp trong main.dart) để làm ấm màu màn hình, giảm
  // ánh sáng xanh — cách làm phổ biến của các app "Night Shift"/"Blue light
  // filter" khi không có quyền truy cập trực tiếp phần cứng hiển thị.
  bool _blueLightFilterEnabled = false;
  double _blueLightIntensity = 0.25; // 0.0 - 0.6, độ đậm của lớp phủ hổ phách

  AppThemePreference get preference => _preference;
  bool get blueLightFilterEnabled => _blueLightFilterEnabled;
  double get blueLightIntensity => _blueLightIntensity;

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
    _blueLightFilterEnabled = prefs.getBool(_kBlueLightEnabledKey) ?? _blueLightFilterEnabled;
    _blueLightIntensity = prefs.getDouble(_kBlueLightIntensityKey) ?? _blueLightIntensity;
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

  Future<void> setBlueLightFilterEnabled(bool value) async {
    _blueLightFilterEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBlueLightEnabledKey, value);
    notifyListeners();
  }

  Future<void> setBlueLightIntensity(double value) async {
    _blueLightIntensity = value.clamp(0.0, 0.6);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kBlueLightIntensityKey, _blueLightIntensity);
    notifyListeners();
  }
}
