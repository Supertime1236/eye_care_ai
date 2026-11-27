import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_data_service.dart';
import 'eye_timeline_service.dart';
import 'notification_service.dart';

/// Chế độ nhắc nghỉ mắt THEO THỜI GIAN DÙNG ĐIỆN THOẠI: cứ dùng máy đủ X phút
/// (cộng dồn từ lần nghỉ gần nhất) thì nhắc nghỉ mắt và tự tính 1 lần nghỉ —
/// khác với hẹn giờ cố định (nhắc đều theo đồng hồ dù bạn có đang dùng máy hay không).
///
/// CÁCH ĐẾM: đọc tổng thời gian dùng máy hôm nay từ UsageStats, mức TĂNG giữa 2
/// lần đọc được cộng vào bộ đếm. Bộ đếm về 0 khi (a) nhắc xong, hoặc (b) bạn
/// ghi nhận 1 lần nghỉ mắt bằng bất kỳ cách nào (xem [resetAccumulation]).
///
/// KIỂM TRA ĐỊNH KỲ:
///  - App đang mở: mỗi 30 giây (chính xác).
///  - App đóng/ở nền: WorkManager mỗi ~15 phút (mức tối thiểu Android cho phép) —
///    nên thông báo có thể TRỄ tới ~15 phút so với mốc X, chứ không đúng từng phút.
///
/// Toàn bộ trạng thái lưu trong SharedPreferences (đọc lại mỗi lần kiểm tra) vì
/// 2 nơi chạy ở 2 isolate khác nhau.
class UsageBreakService extends ChangeNotifier {
  UsageBreakService._();
  static final UsageBreakService instance = UsageBreakService._();

  static const _channel = MethodChannel('eye_care_ai/usage_events');

  static const _kEnabledKey = 'pref_usage_break_enabled';
  static const _kMinutesKey = 'pref_usage_break_minutes';
  static const _kAccumKey = 'usage_break_accum_sec';
  static const _kLastTotalKey = 'usage_break_last_total_sec';
  static const _kLastDateKey = 'usage_break_last_date';

  static const minuteOptions = [15, 20, 30, 45, 60];
  static const defaultMinutes = 30;

  // Mức tăng tối đa tính cho 1 lần đọc — chặn nhảy vọt do dữ liệu usage bất thường.
  static const _maxDeltaSec = 30 * 60;
  // Dưới mức này coi là nhiễu, không phải đang dùng máy.
  static const _minDeltaSec = 5;

  bool _enabled = false;
  int _minutes = defaultMinutes;
  int _accumSec = 0;
  Timer? _timer;
  bool _polling = false;

  /// Foreground: gán để đếm lần nghỉ qua HabitProvider (cập nhật UI ngay).
  Future<void> Function()? onBreak;

  bool get enabled => _enabled;
  int get minutes => _minutes;
  int get accumulatedSeconds => _accumSec;
  double get progress => (_accumSec / (_minutes * 60)).clamp(0.0, 1.0);

  /// Gọi 1 lần lúc khởi động (xem HabitProvider.startHabitTracking).
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _readState(prefs);
    if (_enabled) _startTimer();
    notifyListeners();
  }

  void _readState(SharedPreferences prefs) {
    _enabled = prefs.getBool(_kEnabledKey) ?? false;
    _minutes = prefs.getInt(_kMinutesKey) ?? defaultMinutes;
    _accumSec = prefs.getInt(_kAccumKey) ?? 0;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabledKey, value);
    _enabled = value;
    // Bật/tắt -> đo lại từ đầu, không tính phần dùng máy từ trước đó.
    await prefs.setInt(_kAccumKey, 0);
    await prefs.remove(_kLastTotalKey);
    _accumSec = 0;
    if (value) {
      _startTimer();
      unawaited(pollOnce()); // đặt mốc ban đầu ngay.
    } else {
      _timer?.cancel();
      _timer = null;
    }
    notifyListeners();
  }

  Future<void> setMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kMinutesKey, minutes);
    _minutes = minutes;
    notifyListeners();
  }

  /// Gọi khi người dùng vừa nghỉ mắt (bằng cách nào cũng được) -> bộ đếm về 0.
  Future<void> resetAccumulation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAccumKey, 0);
    _accumSec = 0;
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => pollOnce());
  }

  /// 1 lần kiểm tra: cộng phần dùng máy mới vào bộ đếm, nếu đủ ngưỡng thì nhắc +
  /// tính 1 lần nghỉ. [fromBackground] = true khi chạy trong Worker (không có UI).
  Future<void> pollOnce({bool fromBackground = false}) async {
    if (_polling) return;
    _polling = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // trạng thái có thể vừa được isolate kia sửa.
      _readState(prefs);
      if (!_enabled) {
        if (!fromBackground) notifyListeners();
        return;
      }

      final total = await _todayUsageSeconds();
      if (total == null) return; // chưa cấp Usage Access / lỗi -> bỏ qua lần này.

      final today = DateTime.now().toIso8601String().substring(0, 10);
      final lastTotal = prefs.getInt(_kLastTotalKey);
      final lastDate = prefs.getString(_kLastDateKey);
      await prefs.setInt(_kLastTotalKey, total);
      await prefs.setString(_kLastDateKey, today);

      // Lần đầu, sang ngày mới (tổng reset), hoặc tổng giảm: chỉ đặt mốc.
      if (lastTotal == null || lastDate != today || total < lastTotal) {
        if (!fromBackground) notifyListeners();
        return;
      }

      final delta = total - lastTotal;
      if (delta >= _minDeltaSec) {
        _accumSec += delta > _maxDeltaSec ? _maxDeltaSec : delta;
      }

      if (_accumSec >= _minutes * 60) {
        final usedMinutes = _minutes;
        _accumSec = 0;
        await prefs.setInt(_kAccumKey, 0);
        await _fire(usedMinutes, fromBackground: fromBackground);
      } else {
        await prefs.setInt(_kAccumKey, _accumSec);
      }
      if (!fromBackground) notifyListeners();
    } finally {
      _polling = false;
    }
  }

  Future<void> _fire(int minutes, {required bool fromBackground}) async {
    final prefs = await SharedPreferences.getInstance();
    final vi = prefs.getBool('pref_vietnamese') ?? true;
    await NotificationService.instance.showInstantNotification(
      title: vi ? 'Đến giờ nghỉ mắt' : 'Time for an eye break',
      body: vi
          ? 'Bạn đã dùng điện thoại khoảng $minutes phút. Nhìn xa 6 mét trong 20 giây nhé.'
          : "You've used your phone for about $minutes minutes. Look 6 m away for 20 seconds.",
    );
    // Tính 1 lần nghỉ mắt. Foreground đi qua HabitProvider (cập nhật UI ngay);
    // nền thì ghi thẳng vào dữ liệu — HabitProvider sẽ đọc lại ở lần làm mới sau.
    if (!fromBackground && onBreak != null) {
      await onBreak!();
    } else {
      await DeviceDataService.instance.recordEyeBreak();
      unawaited(EyeTimelineService.instance.log(TimelineEventType.eyeBreak));
    }
  }

  // Tổng giây dùng máy hôm nay (cộng mọi ứng dụng); null nếu không đọc được.
  Future<int?> _todayUsageSeconds() async {
    if (!Platform.isAndroid) return null;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    try {
      final raw = await _channel.invokeListMethod<dynamic>('getUsageBreakdown', {
        'startMillis': start.millisecondsSinceEpoch,
        'endMillis': now.millisecondsSinceEpoch,
      });
      if (raw == null) return null;
      var ms = 0;
      for (final item in raw) {
        final m = Map<String, dynamic>.from(item as Map);
        ms += (m['usageMillis'] as num?)?.toInt() ?? 0;
      }
      return ms ~/ 1000;
    } catch (_) {
      return null;
    }
  }
}