import 'dart:async';
import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:health/health.dart';
import 'package:light/light.dart';
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

      // Trả về TOÀN BỘ danh sách (không cắt bớt) — màn hình Thống kê sẽ tự
      // gộp các app ít dùng vào một lát "Khác..." để tổng luôn khớp chính
      // xác với tổng thời gian dùng máy thật.
      return entries;
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

  // Chỉ xin quyền Health Connect MỘT LẦN trong suốt vòng đời app — trước đây
  // getSleepHours() gọi requestAuthorization() mỗi lần refreshHabitsFromDevice()
  // chạy (tức mỗi vài giây do timer poll ở MainShell), khiến log
  // "Permission launcher not found" bị spam liên tục và tốn tài nguyên hỏi
  // quyền lặp lại vô ích dù đã được cấp/từ chối từ trước.
  bool? _sleepPermissionGranted;

  // ---------------- Sleep: HealthKit (iOS) / Health Connect (Android) ----------------
  Future<double?> getSleepHours() async {
    try {
      final health = Health();
      final types = [HealthDataType.SLEEP_ASLEEP];

      if (_sleepPermissionGranted == null) {
        final alreadyGranted = await health.hasPermissions(types) ?? false;
        _sleepPermissionGranted = alreadyGranted || await health.requestAuthorization(types);
      }
      // Lưu ý: nếu người dùng từ chối lúc đầu rồi sau đó tự vào Cài đặt hệ
      // thống cấp quyền Health Connect thủ công, app cần được khởi động lại
      // mới nhận biết được (đổi lấy việc không phải spam hỏi quyền mỗi vài
      // giây — đánh đổi hợp lý).
      if (_sleepPermissionGranted != true) return null;

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

  // ---------------- Outdoor Time: chỉ dùng GPS ----------------
  // Trước đây tính năng này kết hợp thêm cảm biến ánh sáng (lux) với GPS để
  // đoán "đang ở ngoài trời". Theo yêu cầu, đã bỏ hẳn phần cảm biến ánh sáng
  // cho tính năng NÀY (cảm biến ánh sáng vẫn còn dùng riêng cho tính năng
  // "cảnh báo dùng điện thoại trong bóng tối" ở phần dưới) — giờ Outdoor Time
  // CHỈ dựa vào GPS:
  //   - Có fix vị trí với độ chính xác tốt (accuracy <= ~30m, lấy nhanh
  //     trong vài giây) -> coi là đang ở ngoài trời (ăng-ten GPS "nhìn thấy
  //     trời" thường chỉ xảy ra khi không bị mái/tường nhà che chắn).
  //   - Không lấy được fix / độ chính xác kém / thiếu quyền vị trí -> coi là
  //     trong nhà, không cộng dồn.
  static const _kGpsGoodAccuracyMeters = 30.0; // độ chính xác GPS coi là "tốt"

  Future<double> getOutdoorMinutesToday() async {
    final prefs = await SharedPreferences.getInstance();
    await _resetIfNewDay(prefs, _kOutdoorMinutesKey, _kOutdoorDateKey);
    return prefs.getDouble(_kOutdoorMinutesKey) ?? 0;
  }

  Future<void> startOutdoorTracking() async {
    _outdoorSampleTimer?.cancel();
    _outdoorSampleTimer = Timer.periodic(const Duration(minutes: 2), (_) async {
      final elapsedMinutes = _lastOutdoorSample == null
          ? 2.0
          : DateTime.now().difference(_lastOutdoorSample!).inSeconds / 60.0;
      _lastOutdoorSample = DateTime.now();

      final isOutdoor = await _detectOutdoorSample();
      if (isOutdoor == true) {
        final prefs = await SharedPreferences.getInstance();
        await _resetIfNewDay(prefs, _kOutdoorMinutesKey, _kOutdoorDateKey);
        final current = prefs.getDouble(_kOutdoorMinutesKey) ?? 0;
        await prefs.setDouble(_kOutdoorMinutesKey, current + elapsedMinutes);
      }
      // isOutdoor == false: trong nhà, không cộng dồn.
      // isOutdoor == null: không đọc được lux, bỏ qua mẫu này hoàn toàn.
    });
  }

  // Trả về true (ngoài trời) / false (trong nhà) / null (không đủ dữ liệu
  // cảm biến ánh sáng để kết luận cho mẫu này).
  Future<bool?> _detectOutdoorSample() async {
    // Đã bỏ cảm biến ánh sáng (lux) theo yêu cầu — giờ CHỈ dùng GPS: có fix
    // vị trí độ chính xác tốt -> coi là ngoài trời, ngược lại -> trong nhà.
    return _hasGoodGpsFix();
  }

  // Kiểm tra quyền vị trí đã được cấp hay chưa (không tự xin quyền ở đây —
  // việc xin quyền runtime nên do UI chủ động gọi requestLocationPermission()
  // để hiển thị đúng ngữ cảnh cho người dùng).
  Future<bool> hasLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  // Xin quyền vị trí runtime. Gọi từ UI (VD: màn hình cài đặt Outdoor Time)
  // trước khi bật tracking, để người dùng hiểu vì sao app cần quyền này.
  Future<bool> requestLocationPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) return false;
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  // Lấy nhanh 1 fix GPS (tối đa 5 giây) và đánh giá độ chính xác. Trả về
  // false (không phải null) khi thiếu quyền/dịch vụ vị trí hoặc không lấy
  // được fix trong thời gian cho phép, vì trong các trường hợp đó không có
  // căn cứ để xác nhận "ngoài trời" -> coi như không xác nhận được.
  Future<bool> _hasGoodGpsFix() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;

      final hasPermission = await hasLocationPermission();
      if (!hasPermission) return false;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      return position.accuracy <= _kGpsGoodAccuracyMeters;
    } catch (_) {
      // Timeout, dịch vụ bị tắt giữa chừng, hoặc lỗi phần cứng.
      return false;
    }
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
  // Đếm dồn TOÀN BỘ THỜI GIAN (không reset theo ngày như 2 key ở trên) —
  // dùng riêng cho màn hình Thành tựu (trước đây các thẻ 5 lần/15 lần nghỉ
  // mắt bị hardcode "đã mở khoá" sẵn dù người dùng chưa làm gì; giờ tính
  // thật dựa trên số này, người cài app mới sẽ bắt đầu từ 0).
  static const _kBreaksTotalAllTimeKey = 'eye_breaks_total_alltime';

  Future<int> getEyeBreaksToday() async {
    final prefs = await SharedPreferences.getInstance();
    await _resetIfNewDayInt(prefs, _kBreaksCountKey, _kBreaksDateKey);
    return prefs.getInt(_kBreaksCountKey) ?? 0;
  }

  Future<int> getTotalEyeBreaksAllTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kBreaksTotalAllTimeKey) ?? 0;
  }

  Future<int> recordEyeBreak() async {
    final prefs = await SharedPreferences.getInstance();
    await _resetIfNewDayInt(prefs, _kBreaksCountKey, _kBreaksDateKey);
    final current = (prefs.getInt(_kBreaksCountKey) ?? 0) + 1;
    await prefs.setInt(_kBreaksCountKey, current);
    final totalAllTime = (prefs.getInt(_kBreaksTotalAllTimeKey) ?? 0) + 1;
    await prefs.setInt(_kBreaksTotalAllTimeKey, totalAllTime);
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

  // ---------------- Daily snapshot history (for real Statistics charts) ----------------
  // Mỗi ngày, sau khi đồng bộ dữ liệu thiết bị xong, HabitProvider lưu lại
  // MỘT snapshot của ngày hôm đó (điểm hoàn thành habit, giờ dùng màn hình,
  // giờ ngủ). Biểu đồ tuần ở trang Thống kê đọc từ đây thay vì số liệu giả
  // cố định — những ngày CHƯA TỚI trong tuần hiện tại sẽ không có snapshot,
  // UI sẽ vẽ chúng như đoạn chưa hoàn thành thay vì bịa số.
  static const _kDailySnapshotPrefix = 'daily_snapshot_';

  Future<void> saveDailySnapshot({
    required int score,
    required double screenHours,
    required double sleepHours,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.setString(
      '$_kDailySnapshotPrefix$today',
      '$score|$screenHours|$sleepHours',
    );
  }

  // Trả về snapshot cho một ngày cụ thể, null nếu ngày đó chưa có dữ liệu
  // (chưa tới, hoặc người dùng không mở app hôm đó).
  Future<({int score, double screenHours, double sleepHours})?> loadDailySnapshot(
    DateTime date,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_kDailySnapshotPrefix${date.toIso8601String().substring(0, 10)}';
    final raw = prefs.getString(key);
    if (raw == null) return null;
    final parts = raw.split('|');
    if (parts.length != 3) return null;
    return (
      score: int.tryParse(parts[0]) ?? 0,
      screenHours: double.tryParse(parts[1]) ?? 0,
      sleepHours: double.tryParse(parts[2]) ?? 0,
    );
  }

  // Trả về danh sách 7 ngày của TUẦN HIỆN TẠI (Thứ 2 -> Chủ nhật). Với các
  // ngày đã qua/hôm nay: snapshot thật nếu có, null nếu không mở app hôm đó.
  // Với các ngày CHƯA TỚI: luôn null (chưa xảy ra thì không thể có dữ liệu).
  Future<List<({int score, double screenHours, double sleepHours})?>> loadCurrentWeekSnapshots() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));

    final result = <({int score, double screenHours, double sleepHours})?>[];
    for (var i = 0; i < 7; i++) {
      final day = monday.add(Duration(days: i));
      if (day.isAfter(today)) {
        result.add(null);
      } else {
        result.add(await loadDailySnapshot(day));
      }
    }
    return result;
  }

  // Trả về dữ liệu THÁNG HIỆN TẠI, gộp theo tuần (W1..W7, tối đa 7 tuần cho
  // các tháng có 5-6 tuần lịch) để vẽ biểu đồ Monthly bằng dữ liệu thật thay
  // vì số mẫu cố định. Mỗi phần tử là trung bình các ngày có snapshot trong
  // tuần đó; null nếu tuần đó chưa có ngày nào có dữ liệu (chưa tới hoặc
  // người dùng chưa mở app ngày nào trong tuần đó).
  Future<List<({int score, double screenHours, double sleepHours})?>>
      loadCurrentMonthWeeklySnapshots() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

    // Chỉ số tuần trong tháng: gộp theo cụm 7 ngày kể từ ngày 1, không phải
    // theo tuần lịch Thứ2-CN, để mọi tháng đều chia gọn thành tối đa 7 cụm.
    final buckets = List.generate(
      7,
      (_) => <({int score, double screenHours, double sleepHours})>[],
    );
    for (var d = 1; d <= daysInMonth; d++) {
      final day = DateTime(now.year, now.month, d);
      if (day.isAfter(today)) break;
      final snapshot = await loadDailySnapshot(day);
      if (snapshot != null) {
        final weekIndex = ((d - 1) ~/ 7).clamp(0, 6);
        buckets[weekIndex].add(snapshot);
      }
    }

    final result = <({int score, double screenHours, double sleepHours})?>[];

    for (final bucket in buckets) {
      if (bucket.isEmpty) {
        result.add(null);
        continue;
      }

      final avgScore =
          bucket.map((s) => s.score).reduce((a, b) => a + b) / bucket.length;

      final avgScreen =
          bucket.map((s) => s.screenHours).reduce((a, b) => a + b) / bucket.length;

      final avgSleep =
          bucket.map((s) => s.sleepHours).reduce((a, b) => a + b) / bucket.length;

      result.add((
        score: avgScore.round(),
        screenHours: avgScreen,
        sleepHours: avgSleep,
      ));
    }

    return result;
  }

  // Tính chuỗi ngày liên tiếp (streak) thật: đếm ngược từ hôm nay, mỗi ngày
  // có snapshot với điểm hoàn thành >= 80% thì tính là 1 ngày trong chuỗi,
  // dừng lại ở ngày đầu tiên không đạt hoặc không có dữ liệu.
  Future<int> calculateStreakDays() async {
    var streak = 0;
    var day = DateTime.now();
    for (var i = 0; i < 365; i++) {
      final snapshot = await loadDailySnapshot(DateTime(day.year, day.month, day.day));
      if (snapshot == null || snapshot.score < 80) break;
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  // ---------------- Cảnh báo dùng điện thoại trong bóng tối ----------------
  // Dùng lại cảm biến ánh sáng (lux) — lắng nghe liên tục trong khi app ở
  // foreground: nếu lux ở mức "tối" (giống phòng tắt đèn/ban đêm không đèn)
  // trong một khoảng thời gian liên tục đủ dài, coi như người dùng đang nhìn
  // màn hình trong bóng tối và gọi callback `onDarkWarning` MỘT LẦN cho tới
  // khi ánh sáng trở lại bình thường (tránh spam thông báo liên tục).
  StreamSubscription<int>? _darkRoomLightSub;
  DateTime? _darkSince;
  bool _darkWarningFired = false;

  static const _kDarkLuxThreshold = 10; // lux dưới mức này coi là "tối"
  static const _kDarkTriggerDuration = Duration(minutes: 2);

  void startDarkRoomMonitoring(Future<void> Function() onDarkWarning) {
    stopDarkRoomMonitoring();
    if (!Platform.isAndroid) return; // light sensor not available on iOS
    try {
      _darkRoomLightSub = Light().lightSensorStream.listen(
        (lux) {
          if (lux < _kDarkLuxThreshold) {
            _darkSince ??= DateTime.now();
            final elapsed = DateTime.now().difference(_darkSince!);
            if (!_darkWarningFired && elapsed >= _kDarkTriggerDuration) {
              _darkWarningFired = true;
              onDarkWarning();
            }
          } else {
            // Đủ sáng trở lại -> reset để lần "tối" tiếp theo lại được cảnh báo.
            _darkSince = null;
            _darkWarningFired = false;
          }
        },
        onError: (_) {},
      );
    } catch (_) {
      // Thiết bị không có cảm biến ánh sáng — bỏ qua tính năng này.
    }
  }

  void stopDarkRoomMonitoring() {
    _darkRoomLightSub?.cancel();
    _darkRoomLightSub = null;
    _darkSince = null;
    _darkWarningFired = false;
  }

  void dispose() {
    _accelSub?.cancel();
    _outdoorSampleTimer?.cancel();
    _darkRoomLightSub?.cancel();
  }
}