import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';
import '../services/usage_service.dart';

/// Nhắc nghỉ mắt TỰ ĐỘNG dựa theo THỜI GIAN DÙNG MÁY THẬT (không cần người
/// dùng tự đặt hẹn giờ như EyeBreakScreen cũ).
///
/// Cách hoạt động:
/// 1. Chia đều mục tiêu "Nghỉ mắt/ngày" (habit 'breaks') ra thành các
///    khoảng countdown, dựa trên số giờ thức trung bình/ngày (giả định).
/// 2. Theo dõi tổng THỜI GIAN MÀN HÌNH SÁNG thật của TOÀN MÁY (không riêng
///    app này) qua UsageService — mỗi phút kiểm tra delta so với lần trước,
///    cộng dồn vào bộ đếm "đã dùng máy bao lâu kể từ lần nghỉ gần nhất".
///    Nhờ đọc UsageStatsManager (toàn hệ thống), việc bắn nhắc không phụ
///    thuộc app đang mở là app nào.
/// 3. Khi bộ đếm vượt countdown -> bắn thông báo nhắc nghỉ, RỒI 20 giây sau
///    tự kiểm tra lại: nếu trong 20 giây đó máy KHÔNG ghi nhận thêm thao tác
///    (tổng thời gian màn hình không tăng) -> coi như user đã thực sự rời
///    mắt khỏi máy, TỰ ĐỘNG ghi nhận 1 lần nghỉ (không cần bấm "Đã nghỉ",
///    không cần camera). Nếu máy vẫn tăng dùng liên tục -> gửi thêm 1 nhắc
///    nhẹ, KHÔNG tự tính là đã nghỉ.
class AutoBreakProvider extends ChangeNotifier {
  static const _kEnabledKey = 'pref_auto_break_enabled';
  static const _kAccumulatedSecKey = 'pref_auto_break_accumulated_sec';
  static const _kLastUsageSecKey = 'pref_auto_break_last_usage_sec';
  static const _kLastUsageDateKey = 'pref_auto_break_last_usage_date';
  // Giả định số giờ thức trung bình/ngày, dùng để chia countdown từ mục
  // tiêu số lần nghỉ — không có cách nào biết chính xác giờ ngủ TƯƠNG LAI
  // của người dùng, nên lấy 1 con số hợp lý phổ biến (16h thức/24h).
  static const double _kAssumedWakingHours = 16.0;
  static const int _kMinIntervalSec = 5 * 60;
  static const int _kMaxIntervalSec = 90 * 60;
  // Trong 20 giây kiểm tra sau khi nhắc, nếu tổng usage tăng thêm quá mốc
  // này (mili-giây) thì coi là "vẫn đang dùng máy", không tự tính là nghỉ.
  static const int _kBreakCheckWindowSeconds = 20;
  static const int _kUsageIncreaseToleranceMs = 3000;

  bool _enabled = false;
  int _intervalSeconds = 20 * 60;
  int _accumulatedSeconds = 0;
  int? _lastUsageSeconds;
  Timer? _pollTimer;

  /// Gọi khi phát hiện được (tự động, không camera) rằng user đã nghỉ mắt
  /// thật — nơi gọi (main_shell.dart) gán hàm này để đi ghi vào HabitProvider.
  Future<void> Function()? onAutoConfirmed;

  bool get enabled => _enabled;
  int get intervalSeconds => _intervalSeconds;
  int get secondsRemaining => (_intervalSeconds - _accumulatedSeconds).clamp(0, _intervalSeconds);
  double get progress => _intervalSeconds == 0 ? 0 : (_accumulatedSeconds / _intervalSeconds).clamp(0.0, 1.0);

  AutoBreakProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_kEnabledKey) ?? false;
    _accumulatedSeconds = prefs.getInt(_kAccumulatedSecKey) ?? 0;
    final storedDate = prefs.getString(_kLastUsageDateKey);
    final todayKey = _todayKey();
    // Sang ngày mới -> mốc usage cũ không còn ý nghĩa để tính delta (usage
    // system của Android tự reset theo ngày) -> bỏ mốc cũ, đo lại từ đầu.
    _lastUsageSeconds = storedDate == todayKey ? prefs.getInt(_kLastUsageSecKey) : null;
    if (_enabled) _startPolling();
    notifyListeners();
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  /// Gọi mỗi khi mục tiêu 'breaks' (HabitProvider) thay đổi hoặc lúc khởi
  /// động — chia đều giờ thức giả định cho số lần nghỉ mục tiêu.
  void recomputeInterval(double dailyTargetBreaks) {
    if (dailyTargetBreaks <= 0) return;
    final seconds = (_kAssumedWakingHours * 3600 / dailyTargetBreaks).round();
    final clamped = seconds.clamp(_kMinIntervalSec, _kMaxIntervalSec);
    if (clamped != _intervalSeconds) {
      _intervalSeconds = clamped;
      notifyListeners();
    }
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabledKey, value);
    if (value) {
      _startPolling();
    } else {
      _pollTimer?.cancel();
    }
    notifyListeners();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 60), (_) => _poll());
    _poll();
  }

  Future<void> _poll() async {
    if (!_enabled) return;
    final totalMs = await UsageService.getTodayScreenTime();
    final totalSec = totalMs ~/ 1000;

    if (_lastUsageSeconds == null) {
      _lastUsageSeconds = totalSec;
      await _persist();
      return;
    }

    final delta = totalSec - _lastUsageSeconds!;
    _lastUsageSeconds = totalSec;
    // delta <= 0: qua nửa đêm hoặc màn hình tắt hẳn suốt 1 phút -> bỏ qua.
    // delta quá lớn (>1h): dữ liệu usage bất thường -> bỏ qua, tránh cộng ảo.
    if (delta > 0 && delta < 3600) {
      _accumulatedSeconds += delta;
    }

    if (_accumulatedSeconds >= _intervalSeconds) {
      _accumulatedSeconds = 0;
      await _fireReminderAndCheck();
    }
    await _persist();
    notifyListeners();
  }

  Future<void> _fireReminderAndCheck() async {
    await NotificationService.instance.showInstantNotification(
      title: '👁️ Đến giờ nghỉ mắt',
      body: 'Nhìn xa 6 mét trong 20 giây nhé — mình sẽ tự kiểm tra bạn có thật sự nghỉ không.',
    );
    final beforeMs = await UsageService.getTodayScreenTime();
    Timer(Duration(seconds: _kBreakCheckWindowSeconds), () async {
      final afterMs = await UsageService.getTodayScreenTime();
      final stillUsingPhone = (afterMs - beforeMs) > _kUsageIncreaseToleranceMs;
      if (!stillUsingPhone) {
        // Không ghi nhận thêm thao tác trong 20 giây -> tự tính là đã nghỉ,
        // không cần người dùng bấm "Đã nghỉ"/dùng camera.
        await onAutoConfirmed?.call();
      } else {
        await NotificationService.instance.showInstantNotification(
          title: '⚠️ Bạn có vẻ vẫn đang dùng máy',
          body: 'Lần nhắc vừa rồi chưa tính là đã nghỉ mắt — cố nhìn xa ở lần nhắc tiếp theo nhé.',
        );
      }
    });
  }

  /// Người dùng tự bấm "Đã nghỉ" thủ công (nếu muốn) — reset bộ đếm sớm.
  Future<void> confirmBreakManually() async {
    _accumulatedSeconds = 0;
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAccumulatedSecKey, _accumulatedSeconds);
    await prefs.setString(_kLastUsageDateKey, _todayKey());
    if (_lastUsageSeconds != null) {
      await prefs.setInt(_kLastUsageSecKey, _lastUsageSeconds!);
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}