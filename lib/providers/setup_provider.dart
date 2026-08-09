import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/device_data_service.dart';
import '../services/focus_mode_service.dart';
import '../services/usage_service.dart';

enum SetupStepId { usageAccess, notifications, sleep, focusMode }

class SetupProvider extends ChangeNotifier {
  static const _kWizardCompletedKey = 'pref_setup_wizard_completed';

  bool _wizardCompleted = false;
  bool get wizardCompleted => _wizardCompleted;

  bool _loading = true;
  bool get loading => _loading;

  final Map<SetupStepId, bool> _status = {
    for (final id in SetupStepId.values) id: false,
  };
  Map<SetupStepId, bool> get status => Map.unmodifiable(_status);

  int get grantedCount => _status.values.where((v) => v).length;
  int get totalCount => SetupStepId.values.length;
  bool get allGranted => grantedCount == totalCount;

  SetupProvider() {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _wizardCompleted = prefs.getBool(_kWizardCompletedKey) ?? false;

    try {
      await refreshStatus().timeout(const Duration(seconds: 6));
    } catch (_) {
      _status[SetupStepId.usageAccess] = false;
      _status[SetupStepId.notifications] = false;
      _status[SetupStepId.sleep] = false;
      _status[SetupStepId.focusMode] = false;
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> reload() => _init();

  bool isGranted(SetupStepId id) => _status[id] ?? false;

  Future<void> refreshStatus() async {
    try {
      late final Future<bool> notificationFuture;
      if (Platform.isAndroid) {
        notificationFuture = Permission.notification.status.then((s) => s.isGranted);
      } else {
        notificationFuture = Future.value(true);
      }

      final results = await Future.wait<bool>([
        UsageService.hasPermission(),
        notificationFuture,
        DeviceDataService.instance.hasSleepPermission(),
        FocusModeService.instance.hasAccess(),
      ]).timeout(const Duration(seconds: 6));

      _status[SetupStepId.usageAccess] = results[0];
      _status[SetupStepId.notifications] = results[1];
      _status[SetupStepId.sleep] = results[2];
      _status[SetupStepId.focusMode] = results[3];
      notifyListeners();
    } catch (_) {
      notifyListeners();
    }
  }

  Future<void> markWizardCompleted() async {
    _wizardCompleted = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kWizardCompletedKey, true);
    notifyListeners();
  }
}
