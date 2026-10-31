import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 1 "đêm" = từ 21:00 ngày [date] tới 05:00 hôm sau (hoặc tới bây giờ nếu đêm
/// đó đang diễn ra).
class NightUsageNight {
  const NightUsageNight({
    required this.date,
    required this.lastActivity,
    required this.usedLate,
    required this.ongoing,
  });

  /// Ngày BẮT ĐẦU của đêm (lúc 21:00).
  final DateTime date;

  /// Mốc hoạt động cuối ước lượng (độ phân giải ~1 phút); null = không ghi nhận.
  final DateTime? lastActivity;

  /// Có dùng máy sau 23:00 không; null = chưa đủ dữ liệu (đêm đang diễn ra mà
  /// chưa tới 23:00).
  final bool? usedLate;

  /// Đêm này còn đang diễn ra (chưa tới 05:00).
  final bool ongoing;
}

class NightUsageSummary {
  const NightUsageSummary({required this.nights});

  /// Mới nhất trước. Luôn có tối đa 7 đêm.
  final List<NightUsageNight> nights;

  NightUsageNight get latest => nights.first;

  /// Số đêm đã đủ dữ liệu để xét "dùng sau 23:00".
  int get countedNights => nights.where((n) => n.usedLate != null).length;
  int get lateNights => nights.where((n) => n.usedLate == true).length;
}

/// "Night Phone Usage": ước lượng THÓI QUEN dùng điện thoại ban đêm từ
/// UsageStatsManager. KHÔNG phải giờ ngủ chính xác — chỉ suy ra từ lúc máy
/// còn được dùng.
///
/// Phía native hiện chỉ có `getUsageBreakdown(startMillis, endMillis)` (tổng
/// thời gian dùng từng app trong 1 khoảng), không trả mốc từng phiên. Vì vậy
/// "hoạt động cuối" được tìm bằng TÌM KIẾM NHỊ PHÂN: hỏi tổng thời gian dùng
/// trong [t, cuối đêm] — giá trị này giảm dần khi t tăng — và thu hẹp t tới
/// khi còn ~1 phút. Mỗi đêm ~10 lần gọi nhẹ; đêm đã kết thúc được cache.
///
/// ĐỘ CHÍNH XÁC: phụ thuộc cách phía native tính phiên bắt đầu TRƯỚC mốc t.
/// Nếu phiên cuối kéo dài qua t và không được tính, kết quả có thể lệch về đầu
/// phiên đó. Nên coi là ước lượng và đối chiếu thử với Digital Wellbeing.
class NightUsageService {
  NightUsageService._();
  static final NightUsageService instance = NightUsageService._();

  static const _channel = MethodChannel('eye_care_ai/usage_events');
  static const _cachePrefix = 'night_usage_v1_';

  static const nightStartHour = 21;
  static const nightEndHour = 5;
  static const lateHour = 23;
  static const nightsBack = 7;

  // Dưới mức này coi là nhiễu (màn hình bật thoáng qua), không phải đang dùng.
  static const _activityThresholdMs = 5000;
  static const _lateThresholdMs = 60000;

  /// Tổng ms dùng máy trong [start, end]; null nếu không đọc được (chưa cấp
  /// quyền Usage Access, kênh native chưa sẵn sàng, không phải Android).
  Future<int?> _usageMs(DateTime start, DateTime end) async {
    if (!Platform.isAndroid) return null;
    if (!end.isAfter(start)) return 0;
    try {
      final raw = await _channel.invokeListMethod<dynamic>('getUsageBreakdown', {
        'startMillis': start.millisecondsSinceEpoch,
        'endMillis': end.millisecondsSinceEpoch,
      });
      if (raw == null) return null;
      var total = 0;
      for (final item in raw) {
        final map = Map<String, dynamic>.from(item as Map);
        total += (map['usageMillis'] as num?)?.toInt() ?? 0;
      }
      return total;
    } catch (_) {
      return null;
    }
  }

  /// Tính tóm tắt 7 đêm gần nhất. Trả về null nếu không đọc được dữ liệu.
  Future<NightUsageSummary?> compute() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();

    // Đêm mới nhất = đêm có mốc 21:00 gần nhất không vượt quá bây giờ.
    final latestDay = now.hour >= nightStartHour
        ? DateTime(now.year, now.month, now.day)
        : DateTime(now.year, now.month, now.day - 1);

    final nights = <NightUsageNight>[];
    for (var k = 0; k < nightsBack; k++) {
      final day = DateTime(latestDay.year, latestDay.month, latestDay.day - k);
      final night = await _computeNight(day, now, prefs);
      if (night == null) return null; // không đọc được -> bỏ cả thẻ.
      nights.add(night);
    }
    return NightUsageSummary(nights: nights);
  }

  Future<NightUsageNight?> _computeNight(
    DateTime day,
    DateTime now,
    SharedPreferences prefs,
  ) async {
    final start = DateTime(day.year, day.month, day.day, nightStartHour);
    final fullEnd = DateTime(day.year, day.month, day.day + 1, nightEndHour);
    final ongoing = fullEnd.isAfter(now);
    final end = ongoing ? now : fullEnd;
    final cacheKey = '$_cachePrefix${day.toIso8601String().substring(0, 10)}';

    // Đêm đã kết thúc từ >30 phút -> dữ liệu đã chốt, dùng cache nếu có.
    final settled = now.difference(fullEnd) > const Duration(minutes: 30);
    if (settled) {
      final cached = _readCache(prefs.getString(cacheKey), day);
      if (cached != null) return cached;
    }

    final lateStart = DateTime(day.year, day.month, day.day, lateHour);
    bool? usedLate;
    if (end.isAfter(lateStart)) {
      final lateMs = await _usageMs(lateStart, end);
      if (lateMs == null) return null;
      usedLate = lateMs >= _lateThresholdMs;
    }

    final lastActivity = await _findLastActivity(start, end);
    if (lastActivity == _failed) return null;

    final night = NightUsageNight(
      date: day,
      lastActivity: lastActivity == _none ? null : lastActivity,
      usedLate: usedLate,
      ongoing: ongoing,
    );
    if (settled) {
      await prefs.setString(cacheKey, _encode(night));
    }
    return night;
  }

  // Giá trị đánh dấu cho _findLastActivity (DateTime không có null-vs-lỗi).
  static final DateTime _none = DateTime.fromMillisecondsSinceEpoch(0);
  static final DateTime _failed = DateTime.fromMillisecondsSinceEpoch(1);

  /// Tìm nhị phân mốc t lớn nhất sao cho vẫn còn >= ngưỡng thời gian dùng máy
  /// trong [t, end]. Trả về [_none] nếu cả đêm không có hoạt động, [_failed]
  /// nếu đọc lỗi.
  Future<DateTime> _findLastActivity(DateTime start, DateTime end) async {
    final total = await _usageMs(start, end);
    if (total == null) return _failed;
    if (total < _activityThresholdMs) return _none;

    var lo = start; // luôn thoả: có hoạt động trong [lo, end]
    var hi = end; // luôn không thoả (hoặc là end)
    while (hi.difference(lo).inSeconds > 60) {
      final mid = lo.add(Duration(seconds: hi.difference(lo).inSeconds ~/ 2));
      final ms = await _usageMs(mid, end);
      if (ms == null) return _failed;
      if (ms >= _activityThresholdMs) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  String _encode(NightUsageNight n) => jsonEncode({
        'last': n.lastActivity?.millisecondsSinceEpoch,
        'late': n.usedLate,
      });

  NightUsageNight? _readCache(String? raw, DateTime day) {
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final last = map['last'];
      return NightUsageNight(
        date: day,
        lastActivity: last is int ? DateTime.fromMillisecondsSinceEpoch(last) : null,
        usedLate: map['late'] as bool?,
        ongoing: false,
      );
    } catch (_) {
      return null;
    }
  }
}