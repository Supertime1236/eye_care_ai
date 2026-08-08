import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_strings.dart';

class LanguageProvider extends ChangeNotifier {
  static const _kVietnameseKey = 'pref_vietnamese';

  LanguageProvider() {
    _loadSavedPreferences();
  }

  bool _isVietnamese = false;

  bool get isVietnamese => _isVietnamese;
  Locale get locale => _isVietnamese ? const Locale('vi') : const Locale('en');
  AppStrings get strings => AppStrings(_isVietnamese);

  Future<void> reload() => _loadSavedPreferences();

  Future<void> _loadSavedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _isVietnamese = prefs.getBool(_kVietnameseKey) ?? _isVietnamese;
    notifyListeners();
  }

  Future<void> toggleVietnamese(bool value) async {
    _isVietnamese = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kVietnameseKey, value);
    notifyListeners();
  }
}
