import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_data_service.dart';

/// Tổng của 1 ứng dụng trong 1 tháng.
class AppMonthTotal {
  const AppMonthTotal({
    required this.packageName,
    required this.appName,
    required this.seconds,
    required this.activeDays,
  });

  final String packageName;
  final String appName;
  final int seconds;
  final int activeDays;
}

class MonthlyAppUsage {
  const MonthlyAppUsage({
    required this.month,
    required this.daysInMonth,
    required this.dailySeconds,
    required this.apps,
    required this.totalSeconds,
    required this.vsPreviousPercent,
  });

  /// Ngày đầu tháng.
  final DateTime month;
  final int daysInMonth;

  /// Ngày trong tháng (1..31) -> tổng giây dùng máy. Chỉ có các ngày đã có dữ liệu.
  final Map<int, int> dailySeconds;

  /// Sắp theo thời gian dùng giảm dần.
  final List<AppMonthTotal> apps;
  final int totalSeconds;

  /// Thay đổi (%) của mức dùng TRUNG BÌNH MỖI NGÀY so với tháng trước; null nếu
  /// 1 trong 2 tháng có ít hơn 3 ngày dữ liệu.
  final double? vsPreviousPercent;

  int get trackedDays => dailySeconds.length;
  int get averagePerDaySeconds => trackedDays == 0 ? 0 : totalSeconds ~/ trackedDays;

  int? get busiestDay {
    if (dailySeconds.isEmpty) return null;
    return dailySeconds.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}

/// Lưu LỊCH SỬ thời gian dùng ứng dụng theo ngày để làm thống kê tháng.
///
/// VÌ SAO PHẢI TỰ LƯU: UsageStatsManager của Android chỉ giữ chi tiết sự kiện
/// khoảng 7 ngày gần nhất, nên không thể hỏi hệ điều hành "cả tháng". Thay vào
/// đó mỗi ngày app lưu lại 1 bản (top [_maxAppsPerDay] ứng dụng + tổng) vào
/// SharedPreferences, và mỗi ngày 1 lần điền bù 7 ngày gần nhất từ hệ điều hành
/// để có số liệu ngay lần đầu mở. Những ngày không mở app và đã quá 7 ngày sẽ
/// không có dữ liệu — UI nói rõ "n/m ngày có dữ liệu".
class AppUsageHistoryService {
  AppUsageHistoryService._();
  static final AppUsageHistoryService instance = AppUsageHistoryService._();

  static const _channel = MethodChannel('eye_care_ai/usage_events');
  static const _prefix = 'app_usage_';
  static const _backfillDateKey = 'app_usage_backfill_date';
  static const _maxAppsPerDay = 40;
  static const _keepDays = 400;
  static const _backfillDays = 7;

  String _key(DateTime d) => '$_prefix${d.toIso8601String().substring(0, 10)}';

  // ---------------- Ghi ----------------

  /// Lưu bản của HÔM NAY (ghi đè mỗi lần làm mới — số liệu chỉ tăng trong ngày).
  Future<void> saveToday(List<AppUsageBreakdownEntry> entries) async {
    if (entries.isEmpty) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await _saveDay(today, [
      for (final e in entries) (e.packageName, e.appName, e.usage.inSeconds),
    ]);
  }

  Future<void> _saveDay(DateTime day, List<(String, String, int)> apps) async {
    final sorted = List.of(apps)..sort((a, b) => b.$3.compareTo(a.$3));
    final total = sorted.fold<int>(0, (sum, a) => sum + a.$3);
    final top = sorted.take(_maxAppsPerDay);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(day),
      jsonEncode({
        't': total,
        'a': [
          for (final a in top) [a.$1, a.$2, a.$3],
        ],
      }),
    );
  }

  /// Mỗi ngày 1 lần: điền bù (và chốt lại số liệu hôm qua) từ hệ điều hành cho
  /// [_backfillDays] ngày gần nhất, rồi dọn dữ liệu quá cũ. An toàn gọi nhiều lần.
  Future<void> backfillRecentDays() async {
    if (!Platform.isAndroid) return;
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayKey = now.toIso8601String().substring(0, 10);
    if (prefs.getString(_backfillDateKey) == todayKey) return;

    final today = DateTime(now.year, now.month, now.day);
    var anySuccess = false;
    for (var i = 1; i <= _backfillDays; i++) {
      final day = DateTime(today.year, today.month, today.day - i);
      // Hôm qua LUÔN chốt lại (bản lưu lúc gần nửa đêm có thể thiếu); các ngày
      // xa hơn chỉ điền khi chưa có.
      if (i > 1 && prefs.containsKey(_key(day))) continue;
      final apps = await _queryDay(day);
      if (apps == null) continue; // không đọc được -> thử lại hôm sau.
      anySuccess = true;
      if (apps.isNotEmpty) await _saveDay(day, apps);
    }
    if (anySuccess) {
      await prefs.setString(_backfillDateKey, todayKey);
      await _prune(prefs, today);
    }
  }

  Future<List<(String, String, int)>?> _queryDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(day.year, day.month, day.day + 1);
    try {
      final raw = await _channel.invokeListMethod<dynamic>('getUsageBreakdown', {
        'startMillis': start.millisecondsSinceEpoch,
        'endMillis': end.millisecondsSinceEpoch,
      });
      if (raw == null) return null;
      final result = <(String, String, int)>[];
      for (final item in raw) {
        final m = Map<String, dynamic>.from(item as Map);
        final seconds = ((m['usageMillis'] as num?)?.toInt() ?? 0) ~/ 1000;
        if (seconds <= 0) continue;
        result.add((m['packageName'] as String? ?? '', m['appName'] as String? ?? '', seconds));
      }
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<void> _prune(SharedPreferences prefs, DateTime today) async {
    final cutoff = _key(DateTime(today.year, today.month, today.day - _keepDays));
    for (final key in prefs.getKeys().where((k) => k.startsWith(_prefix) && k != _backfillDateKey).toList()) {
      if (key.compareTo(cutoff) < 0) await prefs.remove(key);
    }
  }

  // ---------------- Đọc / tổng hợp ----------------

  Future<MonthlyAppUsage> loadMonth(DateTime anyDayInMonth) async {
    final prefs = await SharedPreferences.getInstance();
    final month = DateTime(anyDayInMonth.year, anyDayInMonth.month);
    final current = _aggregate(prefs, month, withApps: true);

    final prevMonth = DateTime(month.year, month.month - 1);
    final prev = _aggregate(prefs, prevMonth, withApps: false);
    double? vs;
    if (current.daily.length >= 3 && prev.daily.length >= 3) {
      final curAvg = current.total / current.daily.length;
      final prevAvg = prev.total / prev.daily.length;
      if (prevAvg > 0) vs = (curAvg - prevAvg) / prevAvg * 100;
    }

    final apps = current.apps.values.toList()
      ..sort((a, b) => b.seconds.compareTo(a.seconds));

    return MonthlyAppUsage(
      month: month,
      daysInMonth: DateTime(month.year, month.month + 1, 0).day,
      dailySeconds: current.daily,
      apps: [
        for (final a in apps)
          AppMonthTotal(
            packageName: a.pkg,
            appName: a.name,
            seconds: a.seconds,
            activeDays: a.days,
          ),
      ],
      totalSeconds: current.total,
      vsPreviousPercent: vs,
    );
  }

  _Agg _aggregate(SharedPreferences prefs, DateTime month, {required bool withApps}) {
    final agg = _Agg();
    final days = DateTime(month.year, month.month + 1, 0).day;
    for (var d = 1; d <= days; d++) {
      final raw = prefs.getString(_key(DateTime(month.year, month.month, d)));
      if (raw == null) continue;
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final total = (map['t'] as num?)?.toInt() ?? 0;
        agg.daily[d] = total;
        agg.total += total;
        if (!withApps) continue;
        for (final item in (map['a'] as List? ?? const [])) {
          final list = item as List;
          final pkg = list[0] as String;
          final entry = agg.apps.putIfAbsent(pkg, () => _AppAgg(pkg, list[1] as String));
          entry.seconds += (list[2] as num).toInt();
          entry.days += 1;
        }
      } catch (_) {
        // Bản ghi hỏng -> bỏ qua ngày đó.
      }
    }
    return agg;
  }
}

class _Agg {
  final Map<int, int> daily = {};
  final Map<String, _AppAgg> apps = {};
  int total = 0;
}

class _AppAgg {
  _AppAgg(this.pkg, this.name);
  final String pkg;
  final String name;
  int seconds = 0;
  int days = 0;
}