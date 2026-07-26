import 'dart:async';
import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Một dòng dữ liệu sử dụng của MỘT app trong ngày hôm nay, dùng cho biểu đồ
// tròn "App Usage Breakdown" ở trang Thống kê.
class AppUsageBreakdownEntry {
  AppUsageBreakdownEntry({
    required this.packageName,
    required this.appName,
    required this.usage,
    this.launchCount,
  });

  final String packageName;
  final String appName;
  final Duration usage;
  // Số lần mở app hôm nay. null nếu không lấy được (thiếu code native hoặc
  // chưa build lại app sau khi thêm MainActivity.kt).
  final int? launchCount;
}

// DeviceDataService chịu trách nhiệm lấy dữ liệu THẬT từ điện thoại
// (cảm biến, hệ điều hành, GPS) thay vì để người dùng tự nhập tay.
//
// Mỗi hàm getX() trả về:
//  - một giá trị số nếu lấy được dữ liệu thật
//  - null nếu nguồn dữ liệu không khả dụng trên thiết bị/nền tảng hiện tại
//    (ví dụ: iOS không cho đọc tổng screen-time qua API công khai),
//    khi đó UI sẽ hiển thị trạng thái "Chưa có nguồn dữ liệu" thay vì số giả.
//
// LƯU Ý QUAN TRỌNG (đọc trước khi build lên máy thật):
// - Android: cần cấp quyền "Usage access" thủ công trong Settings cho phone usage,
//   và bật Health Connect cho dữ liệu giấc ngủ.
// - iOS: cần bật capability "HealthKit" trong Xcode + khai báo mô tả quyền trong
//   Info.plist (đã thêm sẵn) để đọc giấc ngủ qua HealthKit.
// - Front-camera gaze detection (Eye Breaks) CHƯA được cài ở đây: đây là một
//   tính năng ML riêng (face/gaze detection liên tục qua camera), cần được
//   thiết kế kỹ về hiệu năng pin + quyền riêng tư trước khi triển khai, nên
//   habit "breaks" tạm thời vẫn là số 0 + trạng thái "Chưa có nguồn dữ liệu".
class DeviceDataService {
  DeviceDataService._();
  static final DeviceDataService instance = DeviceDataService._();

  static const _kOutdoorMinutesKey = 'outdoor_minutes_today';
  static const _kOutdoorDateKey = 'outdoor_minutes_date';
  static const _kReadingMinutesKey = 'reading_minutes_today';
  static const _kReadingDateKey = 'reading_minutes_date';

  StreamSubscription<AccelerometerEvent>? _accelSub;
  Timer? _outdoorSampleTimer;
  DateTime? _lastOutdoorSample;
  DateTime? _lastReadingSample;
  double _recentAccelVariance = 0;
  final List<double> _accelWindow = [];

  // ---------------- Phone Usage: real OS screen-on time ----------------
  // Android: dùng UsageStatsManager thông qua package app_usage.
  // Người dùng phải cấp quyền "Usage access" thủ công (không có runtime dialog).
  // iOS: Apple không cho app bên thứ ba đọc tổng screen-time -> trả về null.
  //
  // LƯU Ý: UsageStatsManager của Android đôi khi trả về NHIỀU dòng cho cùng
  // một package (do dữ liệu được gộp theo nhiều khung ngày/tuần/tháng chồng
  // nhau ở tầng hệ điều hành). Nếu cộng dồn tất cả các dòng một cách ngây thơ,
  // tổng thời gian sẽ bị đếm trùng và cao hơn thực tế (vd: 5h58p thực tế lại
  // hiện thành 8.9h). Cách xử lý: gom theo packageName, chỉ lấy giá trị LỚN
  // NHẤT cho mỗi package (không cộng dồn các dòng trùng), sau đó mới cộng
  // tổng giữa các package khác nhau.
  Future<double?> getPhoneUsageHours() async {
    if (!Platform.isAndroid) return null;
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final breakdown = await getAppUsageBreakdownToday();
      if (breakdown.isEmpty) return null;

      final totalSeconds = breakdown.fold<int>(0, (sum, e) => sum + e.usage.inSeconds);

      // Chặn trên an toàn: tổng thời gian dùng máy không thể vượt quá số giờ
      // thực tế đã trôi qua từ đầu ngày đến giờ. Nếu vượt (do lỗi hệ điều
      // hành hiếm gặp), cắt về mốc này để tránh hiện số vô lý.
      final elapsedSecondsToday = now.difference(startOfDay).inSeconds;
      final clampedSeconds = totalSeconds > elapsedSecondsToday
          ? elapsedSecondsToday
          : totalSeconds;

      return clampedSeconds / 3600.0;
    } catch (_) {
      // Quyền chưa được cấp hoặc thiết bị không hỗ trợ.
      return null;
    }
  }

  // ---------------- Per-app usage breakdown (for the Statistics pie chart) ----------------
  static const _usageEventsChannel = MethodChannel('eye_care_ai/usage_events');

  Future<Map<String, int>> _getLaunchCounts(DateTime start, DateTime end) async {
    if (!Platform.isAndroid) return {};
    try {
      final raw = await _usageEventsChannel.invokeMapMethod<String, dynamic>(
        'getLaunchCounts',
        {
          'startMillis': start.millisecondsSinceEpoch,
          'endMillis': end.millisecondsSinceEpoch,
        },
      );
      return raw?.map((key, value) => MapEntry(key, (value as num).toInt())) ?? {};
    } catch (_) {
      // Kênh native chưa sẵn sàng (vd: chưa rebuild app) -> UI hiện "Chưa có
      // dữ liệu" cho số lần mở thay vì lỗi.
      return {};
    }
  }

  Future<List<AppUsageBreakdownEntry>> getAppUsageBreakdownToday() async {
    if (!Platform.isAndroid) return [];
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final launchCounts = await _getLaunchCounts(startOfDay, now);

      final raw = await _usageEventsChannel.invokeListMethod<dynamic>(
        'getUsageBreakdown',
        {
          'startMillis': startOfDay.millisecondsSinceEpoch,
          'endMillis': now.millisecondsSinceEpoch,
        },
      );

      if (raw == null) return [];

      final entries = raw.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        final packageName = map['packageName'] as String;
        return AppUsageBreakdownEntry(
          packageName: packageName,
          appName: map['appName'] as String,
          usage: Duration(milliseconds: (map['usageMillis'] as num).toInt()),
          launchCount: launchCounts[packageName],
        );
      }).toList()
        ..sort((a, b) => b.usage.compareTo(a.usage));

      // Giới hạn 8 app hàng đầu để biểu đồ tròn không bị vụn quá nhiều lát.
      return entries.take(8).toList();
    } catch (_) {
      // Kênh native chưa sẵn sàng (chưa rebuild app sau khi thêm code Kotlin
      // mới) hoặc lỗi khác -> trả về rỗng, UI hiện "Chưa có nguồn dữ liệu".
      return [];
    }
  }

  // Android không cho xin quyền "Usage access" qua runtime dialog, nhưng CÓ
  // một intent hệ thống mở thẳng màn hình danh sách "Usage access" (thay vì
  // chỉ mở trang Settings chung của app) — người dùng chỉ còn phải tìm tên
  // app trong danh sách rồi bật lên, đỡ hơn vài bước so với trước.
  Future<void> openUsageAccessSettings() async {
    if (!Platform.isAndroid) return;
    try {
      const intent = AndroidIntent(action: 'android.settings.USAGE_ACCESS_SETTINGS');
      await intent.launch();
    } catch (_) {
      // Một số ROM tùy biến không hỗ trợ intent trên -> lùi về mở Settings
      // chung của app để người dùng tự điều hướng tiếp.
      await openAppSettings();
    }
  }

  // Kiểm tra xem quyền Usage Access đã được cấp hay chưa, để UI hiện đúng
  // trạng thái thay vì chỉ đoán qua việc dữ liệu có về hay không.
  Future<bool> hasUsageAccessPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _usageEventsChannel.invokeMethod<bool>('hasUsageAccess');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  // ---------------- Sleep: HealthKit (iOS) / Health Connect (Android) ----------------
  Future<double?> getSleepHours() async {
    try {
      final health = Health();
      final types = [HealthDataType.SLEEP_ASLEEP];
      final granted = await health.requestAuthorization(types);
      if (!granted) return null;

      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(hours: 20));
      final points = await health.getHealthDataFromTypes(
        types: types,
        startTime: yesterday,
        endTime: now,
      );
      if (points.isEmpty) return null;

      final totalMinutes = points.fold<int>(0, (sum, p) {
        final value = p.value;
        if (value is NumericHealthValue) {
          return sum + value.numericValue.round();
        }
        return sum + p.dateTo.difference(p.dateFrom).inMinutes;
      });
      return totalMinutes / 60.0;
    } catch (_) {
      return null;
    }
  }

  // ---------------- Outdoor Time: GPS presence sampling ----------------
  // Không thể track liên tục khi app ở background nếu chưa có background
  // service riêng, nên đây là bản đo khi app đang mở: mỗi ~2 phút kiểm tra vị
  // trí + độ chính xác GPS, coi là "ngoài trời" nếu bắt được tín hiệu GPS tốt
  // (độ chính xác < 30m, điều hiếm khi xảy ra trong nhà). Kết quả cộng dồn và
  // lưu theo ngày bằng SharedPreferences.
  Future<double> getOutdoorMinutesToday() async {
    final prefs = await SharedPreferences.getInstance();
    await _resetIfNewDay(prefs, _kOutdoorMinutesKey, _kOutdoorDateKey);
    return prefs.getDouble(_kOutdoorMinutesKey) ?? 0;
  }

  Future<void> startOutdoorTracking() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final requested = await Geolocator.requestPermission();
      if (requested == LocationPermission.denied ||
          requested == LocationPermission.deniedForever) {
        return;
      }
    }
    if (!await Geolocator.isLocationServiceEnabled()) return;

    _outdoorSampleTimer?.cancel();
    _outdoorSampleTimer = Timer.periodic(const Duration(minutes: 2), (_) async {
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        final isOutdoor = position.accuracy < 30;
        final elapsedMinutes = _lastOutdoorSample == null
            ? 2.0
            : DateTime.now().difference(_lastOutdoorSample!).inSeconds / 60.0;
        _lastOutdoorSample = DateTime.now();
        if (isOutdoor) {
          final prefs = await SharedPreferences.getInstance();
          await _resetIfNewDay(prefs, _kOutdoorMinutesKey, _kOutdoorDateKey);
          final current = prefs.getDouble(_kOutdoorMinutesKey) ?? 0;
          await prefs.setDouble(_kOutdoorMinutesKey, current + elapsedMinutes);
        }
      } catch (_) {
        // Bỏ qua lần lấy vị trí lỗi, thử lại ở chu kỳ tiếp theo.
      }
    });
  }

  // ---------------- Reading Time: accelerometer stillness heuristic ----------------
  // Không có plugin ambient-light-sensor nào còn được bảo trì tốt trên
  // pub.dev hiện tại, nên bước đầu chỉ dùng gia tốc kế: nếu điện thoại được
  // cầm khá yên (biến thiên gia tốc thấp) trong khoảng thời gian dài, tính là
  // đang "đọc". Đây là ước lượng gần đúng, không phải đo trực tiếp ánh sáng.
  Future<double> getReadingMinutesToday() async {
    final prefs = await SharedPreferences.getInstance();
    await _resetIfNewDay(prefs, _kReadingMinutesKey, _kReadingDateKey);
    return prefs.getDouble(_kReadingMinutesKey) ?? 0;
  }

  void startReadingTracking() {
    _accelSub?.cancel();
    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 500),
    ).listen((event) {
      final magnitude = event.x * event.x + event.y * event.y + event.z * event.z;
      _accelWindow.add(magnitude);
      if (_accelWindow.length > 20) _accelWindow.removeAt(0);
      if (_accelWindow.length < 5) return;

      final mean = _accelWindow.reduce((a, b) => a + b) / _accelWindow.length;
      final variance = _accelWindow
              .map((v) => (v - mean) * (v - mean))
              .reduce((a, b) => a + b) /
          _accelWindow.length;
      _recentAccelVariance = variance;

      final isStill = _recentAccelVariance < 0.05;
      final now = DateTime.now();
      final elapsedMinutes = _lastReadingSample == null
          ? 0.5
          : now.difference(_lastReadingSample!).inSeconds / 60.0;
      _lastReadingSample = now;

      if (isStill && elapsedMinutes < 5) {
        SharedPreferences.getInstance().then((prefs) async {
          await _resetIfNewDay(prefs, _kReadingMinutesKey, _kReadingDateKey);
          final current = prefs.getDouble(_kReadingMinutesKey) ?? 0;
          await prefs.setDouble(_kReadingMinutesKey, current + elapsedMinutes);
        });
      }
    });
  }

  // ---------------- Eye Breaks: confirmed via the in-app break reminder ----------------
  // Trước đây dự tính dùng front-camera gaze detection, nhưng đó là một
  // pipeline ML riêng (hiệu năng pin + quyền riêng tư cần thiết kế kỹ) nên
  // thay vào đó: mỗi lần người dùng nhấn "Đã nghỉ mắt" ở màn hình nhắc nghỉ
  // mắt, số lần được cộng dồn và lưu theo ngày — đây vẫn là dữ liệu THẬT do
  // người dùng xác nhận, không phải số giả định sẵn.
  static const _kBreaksCountKey = 'eye_breaks_today';
  static const _kBreaksDateKey = 'eye_breaks_date';

  Future<int> getEyeBreaksToday() async {
    final prefs = await SharedPreferences.getInstance();
    await _resetIfNewDayInt(prefs, _kBreaksCountKey, _kBreaksDateKey);
    return prefs.getInt(_kBreaksCountKey) ?? 0;
  }

  Future<int> recordEyeBreak() async {
    final prefs = await SharedPreferences.getInstance();
    await _resetIfNewDayInt(prefs, _kBreaksCountKey, _kBreaksDateKey);
    final current = (prefs.getInt(_kBreaksCountKey) ?? 0) + 1;
    await prefs.setInt(_kBreaksCountKey, current);
    return current;
  }

  Future<void> _resetIfNewDayInt(
    SharedPreferences prefs,
    String valueKey,
    String dateKey,
  ) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final storedDate = prefs.getString(dateKey);
    if (storedDate != today) {
      await prefs.setString(dateKey, today);
      await prefs.setInt(valueKey, 0);
    }
  }

  Future<void> _resetIfNewDay(
    SharedPreferences prefs,
    String valueKey,
    String dateKey,
  ) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final storedDate = prefs.getString(dateKey);
    if (storedDate != today) {
      await prefs.setString(dateKey, today);
      await prefs.setDouble(valueKey, 0);
    }
  }

  // ---------------- App-level flags persisted across restarts ----------------
  static const _kSurveyCompletedKey = 'survey_completed';

  Future<bool> isSurveyCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kSurveyCompletedKey) ?? false;
  }

  Future<void> setSurveyCompleted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSurveyCompletedKey, value);
  }

  // ---------------- Break reminder: persist the countdown across restarts ----------------
  static const _kBreakReminderEndKey = 'break_reminder_end_at';
  static const _kBreakReminderIntervalKey = 'break_reminder_interval_minutes';

  Future<void> saveBreakReminderEnd(DateTime endAt, int intervalMinutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBreakReminderEndKey, endAt.toIso8601String());
    await prefs.setInt(_kBreakReminderIntervalKey, intervalMinutes);
  }

  Future<void> clearBreakReminderEnd() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kBreakReminderEndKey);
  }

  // Trả về thời điểm kết thúc đã lưu (null nếu không có bộ đếm nào đang chạy).
  Future<DateTime?> loadBreakReminderEnd() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kBreakReminderEndKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<int?> loadBreakReminderIntervalMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kBreakReminderIntervalKey);
  }

  void dispose() {
    _accelSub?.cancel();
    _outdoorSampleTimer?.cancel();
  }
}
