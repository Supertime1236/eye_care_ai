import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const _kMetricKey = 'pref_use_metric';
  static const _k24HourKey = 'pref_24_hour';
  static const _kNotifyBreaksKey = 'pref_notify_breaks';
  static const _kNotifyTestsKey = 'pref_notify_tests';
  static const _kNotifyHabitsKey = 'pref_notify_habits';
  static const _kNotifyTipsKey = 'pref_notify_tips';

  SettingsProvider() {
    _loadSavedPreferences();
  }

  bool _useMetric = true;
  bool _is24Hour = false;
  bool _notifyBreaks = true;
  bool _notifyTests = true;
  bool _notifyHabits = true;
  bool _notifyTips = true;

  bool get useMetric => _useMetric;
  bool get is24Hour => _is24Hour;
  bool get notifyBreaks => _notifyBreaks;
  bool get notifyTests => _notifyTests;
  bool get notifyHabits => _notifyHabits;
  bool get notifyTips => _notifyTips;

  Future<void> _loadSavedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _useMetric = prefs.getBool(_kMetricKey) ?? _useMetric;
    _is24Hour = prefs.getBool(_k24HourKey) ?? _is24Hour;
    _notifyBreaks = prefs.getBool(_kNotifyBreaksKey) ?? _notifyBreaks;
    _notifyTests = prefs.getBool(_kNotifyTestsKey) ?? _notifyTests;
    _notifyHabits = prefs.getBool(_kNotifyHabitsKey) ?? _notifyHabits;
    _notifyTips = prefs.getBool(_kNotifyTipsKey) ?? _notifyTips;
    notifyListeners();
  }

  Future<void> toggleMetric(bool value) async {
    _useMetric = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kMetricKey, value);
    notifyListeners();
  }

  Future<void> toggleTimeFormat(bool value) async {
    _is24Hour = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_k24HourKey, value);
    notifyListeners();
  }

  Future<void> setNotification(String key, bool value) async {
    switch (key) {
      case 'breaks':
        _notifyBreaks = value;
        break;
      case 'tests':
        _notifyTests = value;
        break;
      case 'habits':
        _notifyHabits = value;
        break;
      case 'tips':
        _notifyTips = value;
        break;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationKey(key), value);
    notifyListeners();
  }

  String _notificationKey(String key) {
    switch (key) {
      case 'breaks':
        return _kNotifyBreaksKey;
      case 'tests':
        return _kNotifyTestsKey;
      case 'habits':
        return _kNotifyHabitsKey;
      case 'tips':
        return _kNotifyTipsKey;
      default:
        return key;
    }
  }
}
