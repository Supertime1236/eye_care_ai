import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Cho phép người dùng đổi màu nhấn (accent) chính của toàn app — dùng làm
// seedColor cho ColorScheme.fromSeed(...) trong AppTheme, để giao diện đa
// dạng/đầy màu sắc hơn thay vì luôn cố định 1 màu xanh dương.
enum AppAccentColor { blue, purple, pink, orange, green, teal }

extension AppAccentColorX on AppAccentColor {
  Color get seed {
    switch (this) {
      case AppAccentColor.blue:
        return const Color(0xFF3B82F6);
      case AppAccentColor.purple:
        return const Color(0xFF8B5CF6);
      case AppAccentColor.pink:
        return const Color(0xFFEC4899);
      case AppAccentColor.orange:
        return const Color(0xFFF97316);
      case AppAccentColor.green:
        return const Color(0xFF22C55E);
      case AppAccentColor.teal:
        return const Color(0xFF14B8A6);
    }
  }

  String label(bool vi) {
    switch (this) {
      case AppAccentColor.blue:
        return vi ? 'Xanh dương' : 'Blue';
      case AppAccentColor.purple:
        return vi ? 'Tím' : 'Purple';
      case AppAccentColor.pink:
        return vi ? 'Hồng' : 'Pink';
      case AppAccentColor.orange:
        return vi ? 'Cam' : 'Orange';
      case AppAccentColor.green:
        return vi ? 'Xanh lá' : 'Green';
      case AppAccentColor.teal:
        return vi ? 'Xanh ngọc' : 'Teal';
    }
  }
}

class AccentColorProvider extends ChangeNotifier {
  static const _kAccentPrefKey = 'pref_app_accent_color';

  AccentColorProvider() {
    _loadSavedPreference();
  }

  AppAccentColor _choice = AppAccentColor.blue;
  AppAccentColor get choice => _choice;
  Color get seedColor => _choice.seed;

  Future<void> reload() => _loadSavedPreference();

  Future<void> _loadSavedPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kAccentPrefKey);
    if (saved != null) {
      _choice = AppAccentColor.values.firstWhere(
        (e) => e.name == saved,
        orElse: () => AppAccentColor.blue,
      );
      notifyListeners();
    }
  }

  Future<void> setChoice(AppAccentColor value) async {
    _choice = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccentPrefKey, value.name);
    notifyListeners();
  }
}
