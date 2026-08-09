import 'package:flutter/services.dart';
import '../models/app_usage.dart';

class UsageService {
  static const MethodChannel _channel =
      MethodChannel('eye_care/usage');

  /// Kiểm tra quyền Usage Access
  static Future<bool> hasPermission() async {
    try {
      final bool granted =
          await _channel.invokeMethod("checkUsagePermission");

      return granted;
    } catch (_) {
      return false;
    }
  }

  /// Mở màn hình cấp quyền
  static Future<void> openPermissionSettings() async {
    await _channel.invokeMethod("openUsageSettings");
  }

  /// Lấy danh sách app sử dụng hôm nay
  static Future<List<AppUsage>> getTodayUsage() async {
    try {
      final List<dynamic> data =
        await _channel.invokeMethod("getTodayUsage");

      return data
        .map((e) => AppUsage.fromJson(
              Map<String, dynamic>.from(e),
            ))
        .toList();
    } on PlatformException {
      return [];
    }
  }

  /// Tổng Screen Time hôm nay (milliseconds)
  static Future<int> getTodayScreenTime() async {
    final apps = await getTodayUsage();

    int total = 0;

    for (final app in apps) {
      total += app.totalTime.inMilliseconds;
    }

    return total;
  }

  /// Lấy danh sách app sử dụng trong tuần
  static Future<Map<String, List<AppUsage>>> getWeeklyUsage() async {
    try {
      final Map<dynamic, dynamic> data =
          await _channel.invokeMethod("getWeeklyUsage");

      return data.map((key, value) {
        return MapEntry(
          key.toString(),
          (value as List)
              .map((e) => AppUsage.fromJson(Map<String, dynamic>.from(e)))
              .toList(),
        );
      });
    } on PlatformException {
      return {};
    }
  }

  /// Ước lượng số phút ngủ đêm qua từ Usage Events (lần cuối dùng máy tối
  /// qua -> lần đầu dùng máy sáng nay) — THAY THẾ Health Connect đã bị bỏ.
  /// Trả về null nếu không đủ dữ liệu tin cậy (ví dụ không mở máy buổi sáng
  /// trong khung giờ dự kiến, hoặc chưa có quyền Usage Access).
  static Future<int?> getSleepEstimateMinutes() async {
    try {
      final Map<dynamic, dynamic> data =
          await _channel.invokeMethod("getSleepEstimate");
      return data['sleepMinutes'] as int?;
    } on PlatformException {
      return null;
    }
  }
}