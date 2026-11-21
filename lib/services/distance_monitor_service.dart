import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'distance_service.dart';
import 'eye_timeline_service.dart';
import 'notification_coordinator.dart';

/// Nhắc giữ khoảng cách mắt-màn hình bằng camera trước.
///  - TẮT MẶC ĐỊNH, người dùng tự bật (xin quyền camera lúc bật).
///  - KHÔNG chạy camera liên tục: khi app đang mở, bật camera trước vài giây để
///    đo rồi tắt ngay. Lần đo ĐẦU TIÊN diễn ra ~8 giây sau khi bật (để người
///    dùng thấy kết quả ngay), sau đó mỗi ~3 phút và mỗi khi mở lại app.
///  - Chỉ chạy khi app ở foreground (Android không cho mở camera từ nền).
///  - Số đo được nhân với HỆ SỐ HIỆU CHỈNH (xem [calibration]) — cách đo thô
///    sai khoảng ±15-20% do giả định góc nhìn camera, hiệu chỉnh 1 lần với một
///    khoảng cách đã biết sẽ bù phần lớn sai số đó.
///  - Chỉ CẢNH BÁO khi đủ tin cậy: < 20 cm báo ngay, 20-30 cm cần 2 lần liên tiếp.
///  - Ảnh chỉ dùng để tìm khuôn mặt trong bộ nhớ, không lưu, không gửi đi.
///
/// Dùng chung [DistanceService] với bài Kiểm tra mắt và màn "Đo khoảng cách":
/// camera đang bận thì bỏ qua lần đo này.
class DistanceMonitorService extends ChangeNotifier with WidgetsBindingObserver {
  DistanceMonitorService._();
  static final DistanceMonitorService instance = DistanceMonitorService._();

  static const _kEnabledKey = 'pref_distance_monitor_enabled';
  static const _kCalibrationKey = 'pref_distance_calibration';
  static const _kGoodKey = 'dist_good_count';
  static const _kTotalKey = 'dist_total_count';
  static const _kSumKey = 'dist_sum_cm';
  static const _kDateKey = 'dist_sample_date';

  static const _interval = Duration(minutes: 3);
  static const _firstDelay = Duration(seconds: 8);
  static const _resumeDelay = Duration(seconds: 5);
  static const _minGapBetweenMeasures = Duration(minutes: 2);
  static const _maxBurst = Duration(seconds: 12);
  static const _minBurst = Duration(seconds: 3);
  static const _enoughSamples = 6;

  static const double idealMinCm = 30;
  static const double idealMaxCm = 55;
  // Dưới mức này báo NGAY, không cần đợi lần đo thứ 2.
  static const double veryCloseCm = 20;

  bool _enabled = false;
  bool _initialized = false;
  bool _measuring = false;
  Timer? _timer;
  Timer? _delayedTimer;
  int _consecutiveClose = 0;
  double _calibration = 1.0;
  double? _lastCm;
  DateTime? _lastAt;

  /// Màn "Đo khoảng cách" đang dùng camera -> tạm dừng đo nền để không tranh nhau.
  bool suspended = false;

  /// Công tắc người dùng đã bật hay chưa.
  bool get enabled => _enabled;

  /// Hệ số nhân hiệu chỉnh (1.0 = chưa hiệu chỉnh).
  double get calibration => _calibration;
  bool get isCalibrated => (_calibration - 1.0).abs() > 0.005;

  /// Lần đo nền gần nhất (đã hiệu chỉnh) — để hiện cho người dùng biết đang chạy.
  double? get lastMeasuredCm => _lastCm;
  DateTime? get lastMeasuredAt => _lastAt;

  /// Gọi 1 lần lúc khởi động (xem HabitProvider.startHabitTracking). An toàn gọi lại.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_kEnabledKey) ?? false;
    _calibration = (prefs.getDouble(_kCalibrationKey) ?? 1.0).clamp(0.5, 2.0);
    WidgetsBinding.instance.addObserver(this);
    if (_enabled) _startTimers();
    notifyListeners();
  }

  /// Bật/tắt. Khi bật sẽ xin quyền camera; trả về false nếu bị từ chối (và
  /// công tắc tự quay về tắt).
  Future<bool> setEnabled(bool value) async {
    if (value) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        value = false;
      }
    }
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabledKey, value);
    _consecutiveClose = 0;
    if (value) {
      _startTimers();
    } else {
      _stopTimers();
    }
    notifyListeners();
    return value;
  }

  /// Lưu hệ số hiệu chỉnh mới (kẹp trong 0.5-2.0 để loại giá trị vô lý).
  Future<void> setCalibration(double factor) async {
    _calibration = factor.clamp(0.5, 2.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kCalibrationKey, _calibration);
    notifyListeners();
  }

  Future<void> resetCalibration() => setCalibration(1.0);

  void _startTimers() {
    _stopTimers();
    _timer = Timer.periodic(_interval, (_) => _tick());
    // Lần đo đầu sớm, để người dùng thấy kết quả ngay sau khi bật.
    _delayedTimer = Timer(_firstDelay, _tick);
  }

  void _stopTimers() {
    _timer?.cancel();
    _timer = null;
    _delayedTimer?.cancel();
    _delayedTimer = null;
  }

  // Mở lại app sau khi ở nền -> đo lại sớm (nếu lần đo trước đã khá lâu).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_enabled) return;
    final last = _lastAt;
    if (last == null || DateTime.now().difference(last) >= _minGapBetweenMeasures) {
      _delayedTimer?.cancel();
      _delayedTimer = Timer(_resumeDelay, _tick);
    }
  }

  Future<void> _tick() async {
    if (!_enabled || suspended || _measuring) return;
    // BUG ĐÃ SỬA: trước đây yêu cầu lifecycleState == resumed nghiêm ngặt; giá
    // trị này có thể là null/inactive ngay sau khi khởi động nên mọi lần đo bị
    // bỏ qua. Giờ chỉ bỏ qua khi app CHẮC CHẮN đang ở nền.
    final state = WidgetsBinding.instance.lifecycleState;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      return;
    }

    _measuring = true;
    try {
      final raw = await _measureOnce();
      if (raw == null) return; // không thấy mặt/camera bận -> bỏ qua, không phạt.
      final cm = raw * _calibration;
      _lastCm = cm;
      _lastAt = DateTime.now();
      notifyListeners();
      await _recordSample(cm);
      await _evaluate(cm);
    } finally {
      _measuring = false;
    }
  }

  Future<void> _evaluate(double cm) async {
    if (cm < idealMinCm) {
      _consecutiveClose++;
      // Quá gần (< 20 cm) báo ngay; gần vừa (20-30 cm) cần 2 lần đo liên tiếp
      // để tránh báo nhầm do sai số đo.
      if (cm < veryCloseCm || _consecutiveClose >= 2) {
        _consecutiveClose = 0;
        unawaited(EyeTimelineService.instance.log(
          TimelineEventType.distanceWarning,
          value: cm.round(),
          minGap: const Duration(minutes: 10),
        ));
        final prefs = await SharedPreferences.getInstance();
        final vi = prefs.getBool('pref_vietnamese') ?? true;
        final cmText = cm.round();
        await NotificationCoordinator.instance.notify(
          NotificationRequest(
            kind: NotificationKind.distance,
            title: vi ? 'Bạn đang để màn hình quá gần' : 'Your screen is too close',
            body: vi
                ? 'Bạn đang cách màn hình khoảng $cmText cm. Nên giữ 30–50 cm (khoảng 1 gang tay rưỡi) để đỡ mỏi mắt.'
                : "You're about $cmText cm from the screen. Aim for 30–50 cm (about a forearm's length) to reduce eye strain.",
            mergeLine: vi
                ? 'Đang cách màn hình ~$cmText cm — nên giữ 30–50 cm.'
                : 'About $cmText cm from the screen — aim for 30–50 cm.',
          ),
        );
      }
    } else {
      _consecutiveClose = 0;
    }
  }

  // Mở camera trước vài giây, thu mẫu tới khi đủ (hoặc hết giờ), lấy trung vị
  // số đo THÔ (chưa nhân hệ số hiệu chỉnh), rồi tắt ngay.
  Future<double?> _measureOnce() async {
    final service = DistanceService.instance;
    if (service.isRunning) return null; // camera đang bận -> không tranh.
    if (!await service.isCameraAvailable()) return null;

    final values = <double>[];
    StreamSubscription<FaceMeasurement?>? sub;
    try {
      final ok = await service.start();
      if (!ok) return null;
      sub = service.distanceStream.listen((m) {
        final d = m?.distanceCm;
        if (d != null) values.add(d);
      });
      // Chờ thích ứng: tối thiểu _minBurst, thoát sớm khi đủ mẫu, tối đa _maxBurst
      // (ML Kit mất 1-3 giây để khởi động lần đầu).
      final stopwatch = Stopwatch()..start();
      while (stopwatch.elapsed < _maxBurst) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (stopwatch.elapsed >= _minBurst && values.length >= _enoughSamples) break;
        if (suspended || !_enabled) return null;
      }
    } finally {
      await sub?.cancel();
      await service.stop();
    }

    if (values.length < 3) return null; // quá ít mẫu có mặt -> không tin cậy.
    return median(values);
  }

  static double median(List<double> input) {
    final values = List<double>.of(input)..sort();
    final mid = values.length ~/ 2;
    return values.length.isOdd ? values[mid] : (values[mid - 1] + values[mid]) / 2;
  }

  // ---------------- Thống kê trong ngày (cho thẻ điểm + thói quen) ----------------
  Future<void> _recordSample(double cm) async {
    final prefs = await SharedPreferences.getInstance();
    await _resetIfNewDay(prefs);
    final total = (prefs.getInt(_kTotalKey) ?? 0) + 1;
    await prefs.setInt(_kTotalKey, total);
    if (cm >= idealMinCm && cm <= idealMaxCm) {
      await prefs.setInt(_kGoodKey, (prefs.getInt(_kGoodKey) ?? 0) + 1);
    }
    await prefs.setDouble(_kSumKey, (prefs.getDouble(_kSumKey) ?? 0) + cm);
  }

  Future<void> _resetIfNewDay(SharedPreferences prefs) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (prefs.getString(_kDateKey) != today) {
      await prefs.setString(_kDateKey, today);
      await prefs.setInt(_kGoodKey, 0);
      await prefs.setInt(_kTotalKey, 0);
      await prefs.setDouble(_kSumKey, 0);
    }
  }

  /// % số lần đo hôm nay nằm trong khoảng 30–55 cm; null nếu chưa có lần đo nào.
  Future<double?> getDistanceScoreToday() async {
    final prefs = await SharedPreferences.getInstance();
    await _resetIfNewDay(prefs);
    final total = prefs.getInt(_kTotalKey) ?? 0;
    if (total == 0) return null;
    return ((prefs.getInt(_kGoodKey) ?? 0) / total * 100).clamp(0, 100).toDouble();
  }

  /// Khoảng cách TRUNG BÌNH (cm) của các lần đo hôm nay — dùng làm giá trị
  /// hiện tại của thói quen "Khoảng cách"; null nếu chưa có lần đo nào.
  Future<double?> getAverageDistanceTodayCm() async {
    final prefs = await SharedPreferences.getInstance();
    await _resetIfNewDay(prefs);
    final total = prefs.getInt(_kTotalKey) ?? 0;
    if (total == 0) return null;
    return (prefs.getDouble(_kSumKey) ?? 0) / total;
  }

  /// Số lần đo hôm nay và số lần nằm trong khoảng 30-55 cm — cho thẻ thói quen.
  Future<({int total, int good})> getTodayCounts() async {
    final prefs = await SharedPreferences.getInstance();
    await _resetIfNewDay(prefs);
    return (total: prefs.getInt(_kTotalKey) ?? 0, good: prefs.getInt(_kGoodKey) ?? 0);
  }
}