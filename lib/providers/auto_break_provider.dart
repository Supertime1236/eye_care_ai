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
///    app này) qua UsageService — mỗi lần poll kiểm tra delta so với lần
///    trước, cộng dồn vào bộ đếm "đã dùng máy bao lâu kể từ lần nghỉ gần
///    nhất". Nhờ đọc UsageStatsManager (toàn hệ thống), việc bắn nhắc không
///    phụ thuộc app đang mở là app nào.
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

  // BUG ĐÃ SỬA #1 (thanh đếm ngược "đứng hình", không nhảy số): trước đây
  // bộ đếm CHỈ được cập nhật (và notifyListeners()) mỗi 60 giây bên trong
  // _poll() — giữa 2 lần đó, UI đứng yên gần 1 phút, trông như bị treo.
  // Giờ:
  //  1. Poll THẬT (đọc UsageStatsManager) chạy dày hơn — mỗi 15 giây thay vì
  //     60 giây, để bộ đếm cập nhật thường xuyên hơn.
  //  2. Có thêm 1 Timer UI riêng chạy mỗi giây, CHỈ để gọi notifyListeners()
  //     — `secondsRemaining`/`progress` (xem 2 getter bên dưới) giờ tự NỘI
  //     SUY thêm phần thời gian đã trôi qua kể từ lần poll thật gần nhất,
  //     nên hiển thị "chạy" mượt từng giây thay vì nhảy cục mỗi 15-60 giây.
  //     Giá trị nội suy này CHỈ phục vụ hiển thị, không ảnh hưởng tới lúc
  //     nào thật sự bắn thông báo (vẫn do _poll() quyết định).
  static const Duration _kPollInterval = Duration(seconds: 15);

  bool _enabled = false;
  int _intervalSeconds = 20 * 60;
  int _accumulatedSeconds = 0;
  int? _lastUsageSeconds;
  // Mốc giờ của lần poll THẬT gần nhất — dùng để nội suy UI (xem
  // _interpolatedAccumulatedSeconds) và làm cơ sở tính wallElapsed khi
  // UsageStatsManager bị trễ (xem BUG ĐÃ SỬA #2 trong _poll()).
  DateTime? _lastPollAt;
  Timer? _pollTimer;
  Timer? _uiTickTimer;

  /// Gọi khi phát hiện được (tự động, không camera) rằng user đã nghỉ mắt
  /// thật — nơi gọi (main_shell.dart) gán hàm này để đi ghi vào HabitProvider.
  Future<void> Function()? onAutoConfirmed;

  bool get enabled => _enabled;
  int get intervalSeconds => _intervalSeconds;

  // Nội suy thêm thời gian THỰC đã trôi qua kể từ lần poll thật gần nhất
  // (kẹp trong đúng 1 chu kỳ poll) — giả định máy vẫn đang được dùng liên
  // tục giữa 2 lần poll, để thanh đếm ngược luôn "chạy" mượt thay vì đứng
  // yên chờ tới lần poll thật tiếp theo mới nhảy số.
  int get _interpolatedAccumulatedSeconds {
    if (!_enabled || _lastPollAt == null) return _accumulatedSeconds;
    final elapsed = DateTime.now().difference(_lastPollAt!).inSeconds;
    final capped = elapsed.clamp(0, _kPollInterval.inSeconds);
    return (_accumulatedSeconds + capped).clamp(0, _intervalSeconds);
  }

  int get secondsRemaining =>
      (_intervalSeconds - _interpolatedAccumulatedSeconds).clamp(0, _intervalSeconds);
  double get progress => _intervalSeconds == 0
      ? 0
      : (_interpolatedAccumulatedSeconds / _intervalSeconds).clamp(0.0, 1.0);

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
      _uiTickTimer?.cancel();
      _lastPollAt = null;
    }
    notifyListeners();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _uiTickTimer?.cancel();
    _pollTimer = Timer.periodic(_kPollInterval, (_) => _poll());
    // Timer UI riêng — chỉ để thanh tiến độ/số đếm ngược "chạy" mượt mỗi
    // giây bằng nội suy (xem _interpolatedAccumulatedSeconds), KHÔNG đọc
    // lại usage stat ở đây (đỡ tốn pin/CPU); việc đọc thật vẫn do
    // _pollTimer đảm nhiệm.
    _uiTickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_enabled) notifyListeners();
    });
    _poll();
  }

  Future<void> _poll() async {
    if (!_enabled) return;
    final totalMs = await UsageService.getTodayScreenTime();
    final totalSec = totalMs ~/ 1000;
    final now = DateTime.now();

    if (_lastUsageSeconds == null) {
      _lastUsageSeconds = totalSec;
      _lastPollAt = now;
      await _persist();
      notifyListeners();
      return;
    }

    var delta = totalSec - _lastUsageSeconds!;
    _lastUsageSeconds = totalSec;

    // BUG ĐÃ SỬA #2 ("đến giờ vẫn không báo"): UsageStatsManager của Android
    // KHÔNG cập nhật số liệu theo thời gian thực — hệ điều hành có thể trì
    // hoãn việc "chốt sổ" thời gian dùng app hiện tại tới hàng chục phút,
    // khiến delta đọc được cứ = 0 dù người dùng vẫn đang cầm máy dùng liên
    // tục, làm bộ đếm không bao giờ tới ngưỡng để bắn nhắc nghỉ mắt. Khi
    // phát hiện delta <= 0 (usage stat chưa kịp cập nhật), dùng tạm khoảng
    // THỜI GIAN THỰC đã trôi qua kể từ lần poll trước làm ước lượng thay
    // thế (thay vì để bộ đếm đứng yên vô thời hạn) — đây là đánh đổi chấp
    // nhận được: có thể đếm hơi rộng rãi lúc máy đang khoá màn hình ngắn,
    // nhưng khắc phục được lỗi "không bao giờ nhắc" nghiêm trọng hơn nhiều.
    if (delta <= 0) {
      final wallElapsed = _lastPollAt == null ? 0 : now.difference(_lastPollAt!).inSeconds;
      if (wallElapsed > 0 && wallElapsed < 3600) {
        delta = wallElapsed;
      }
    }
    _lastPollAt = now;

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
    _lastPollAt = DateTime.now();
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
    _uiTickTimer?.cancel();
    super.dispose();
  }
}