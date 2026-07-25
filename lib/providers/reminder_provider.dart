import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReminderProvider extends ChangeNotifier {
  static const _kReminderMinutesKey = 'pref_reminder_minutes';

  ReminderProvider() {
    _loadSavedPreferences();
  }

  bool _isEyeBreakReminderActive = false;
  int _reminderMinutes = 20;

  bool get isEyeBreakReminderActive => _isEyeBreakReminderActive;
  int get reminderMinutes => _reminderMinutes;

  Future<void> _loadSavedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _reminderMinutes = prefs.getInt(_kReminderMinutesKey) ?? _reminderMinutes;
    notifyListeners();
  }

  Future<void> setReminderMinutes(int minutes) async {
    _reminderMinutes = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kReminderMinutesKey, minutes);
    notifyListeners();
  }

  void toggleEyeBreakReminder(bool active) {
    _isEyeBreakReminderActive = active;
    notifyListeners();
  }
}
