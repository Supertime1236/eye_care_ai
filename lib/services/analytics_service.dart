import 'package:shared_preferences/shared_preferences.dart';

/// Singleton service that gates all anonymous usage analytics.
///
/// Every analytics call in the app MUST check [isEnabled] before logging.
/// When disabled, no data leaves the device. When enabled, anonymous events
/// may be logged (future: to a self-hosted endpoint or privacy-respecting
/// provider like PostHog self-hosted).
///
/// The toggle is persisted in SharedPreferences and controlled by
/// `SettingsMoreProvider.dataCollection`.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  static const _kEnabledKey = 'data_collection_enabled';
  bool _enabled = true;

  /// Whether analytics collection is currently enabled.
  bool get isEnabled => _enabled;

  /// Load persisted value from SharedPreferences. Call once at app start.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_kEnabledKey) ?? true;
  }

  /// Persist the toggle value. Called by `SettingsMoreProvider.setDataCollection`.
  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabledKey, value);
  }

  // ---- Logging stubs (future: send to analytics endpoint) ----

  /// Log an anonymous event. No-op when disabled.
  ///
  /// ```dart
  /// AnalyticsService.instance.logEvent('habit_completed', {'habit': 'outdoor'});
  /// ```
  void logEvent(String name, [Map<String, dynamic>? params]) {
    if (!_enabled) return;
    // TODO: implement actual logging (e.g., PostHog, Firebase Analytics, or self-hosted)
  }

  /// Log a screen view. No-op when disabled.
  void logScreenView(String screenName) {
    if (!_enabled) return;
    // TODO: implement
  }
}
