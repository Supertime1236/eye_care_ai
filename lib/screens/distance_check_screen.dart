import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../providers/language_provider.dart';
import '../services/distance_monitor_service.dart';
import '../services/distance_service.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';

enum _CheckState { starting, noPermission, noCamera, running }

/// "Đo khoảng cách": đo TRỰC TIẾP khoảng cách mắt-màn hình bằng camera trước
/// (cập nhật liên tục), kèm chức năng HIỆU CHỈNH — giữ điện thoại cách mắt đúng
/// 1 khoảng đã biết rồi bấm 1 nút để app bù sai số đo thô (~±15-20%).
class DistanceCheckScreen extends StatefulWidget {
  const DistanceCheckScreen({super.key});

  @override
  State<DistanceCheckScreen> createState() => _DistanceCheckScreenState();
}

class _DistanceCheckScreenState extends State<DistanceCheckScreen> {
  static const _recentCount = 7;
  static const _faceTimeout = Duration(milliseconds: 1500);
  static const _knownOptions = [30.0, 35.0, 40.0, 45.0];

  final _monitor = DistanceMonitorService.instance;
  _CheckState _state = _CheckState.starting;
  StreamSubscription<FaceMeasurement?>? _sub;
  final List<double> _rawRecent = [];
  DateTime? _lastSampleAt;
  Timer? _faceTimer;
  double _knownCm = 40; // cẳng tay (khuỷu -> đầu ngón tay) thường ~40cm, đúng gợi ý trong khảo sát.

  @override
  void initState() {
    super.initState();
    _monitor.suspended = true; // tạm dừng đo nền để không tranh camera.
    _start();
    // Cập nhật định kỳ để biết khi nào "mất mặt" (không có sự kiện nào đến).
    _faceTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _faceTimer?.cancel();
    _sub?.cancel();
    DistanceService.instance.stop();
    _monitor.suspended = false;
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _state = _CheckState.starting);
    var status = await Permission.camera.status;
    if (!status.isGranted) status = await Permission.camera.request();
    if (!mounted) return;
    if (!status.isGranted) {
      setState(() => _state = _CheckState.noPermission);
      return;
    }

    final service = DistanceService.instance;
    if (!await service.isCameraAvailable()) {
      if (mounted) setState(() => _state = _CheckState.noCamera);
      return;
    }
    // Nếu 1 lần đo nền đang giữ camera thì dừng nó lại, màn này ưu tiên.
    await service.stop();
    final ok = await service.start();
    if (!mounted) return;
    if (!ok) {
      setState(() => _state = _CheckState.noCamera);
      return;
    }
    _sub = service.distanceStream.listen((m) {
      final d = m?.distanceCm;
      if (d == null) return;
      _rawRecent.add(d);
      if (_rawRecent.length > _recentCount) _rawRecent.removeAt(0);
      _lastSampleAt = DateTime.now();
    });
    setState(() => _state = _CheckState.running);
  }

  bool get _faceVisible =>
      _lastSampleAt != null && DateTime.now().difference(_lastSampleAt!) < _faceTimeout;

  double? get _rawMedian =>
      _rawRecent.isEmpty ? null : DistanceMonitorService.median(_rawRecent);

  double? get _calibratedCm {
    final raw = _rawMedian;
    if (raw == null || !_faceVisible) return null;
    return raw * _monitor.calibration;
  }

  Future<void> _calibrate(bool vi) async {
    final raw = _rawMedian;
    if (raw == null || _rawRecent.length < 5 || !_faceVisible) return;
    await _monitor.setCalibration(_knownCm / raw);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(vi
            ? 'Đã hiệu chỉnh theo khoảng cách ${_knownCm.round()} cm.'
            : 'Calibrated to ${_knownCm.round()} cm.'),
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final vi = context.watch<LanguageProvider>().isVietnamese;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: vi ? 'Quay lại' : 'Back',
        ),
        title: Text(vi ? 'Đo khoảng cách' : 'Distance check'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            switch (_state) {
              _CheckState.starting => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                ),
              _CheckState.noPermission => _MessageCard(
                  icon: Icons.no_photography_outlined,
                  text: vi
                      ? 'Cần quyền camera để đo khoảng cách. Ảnh không được lưu hay gửi đi.'
                      : 'Camera permission is needed to measure distance. Images are never saved or sent.',
                  actionLabel: vi ? 'Mở cài đặt' : 'Open settings',
                  onAction: openAppSettings,
                ),
              _CheckState.noCamera => _MessageCard(
                  icon: Icons.videocam_off_outlined,
                  text: vi
                      ? 'Không mở được camera trước. Thử đóng các app đang dùng camera rồi thử lại.'
                      : 'Could not open the front camera. Close other camera apps and try again.',
                  actionLabel: vi ? 'Thử lại' : 'Retry',
                  onAction: _start,
                ),
              _CheckState.running => _buildLive(context, vi),
            },
          ],
        ),
      ),
    );
  }

  Widget _buildLive(BuildContext context, bool vi) {
    final cm = _calibratedCm;
    final status = _statusFor(cm, vi);
    final canCalibrate = _faceVisible && _rawRecent.length >= 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          child: Column(
            children: [
              const SizedBox(height: 6),
              Text(
                cm == null ? '—' : '${cm.round()} cm',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: status.color,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(status.icon, size: 18, color: status.color),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      status.text,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: status.color,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _Gauge(cm: cm, color: status.color, vi: vi),
              const SizedBox(height: 8),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      vi ? 'Hiệu chỉnh cho chính xác hơn' : 'Calibrate for accuracy',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  if (_monitor.isCalibrated)
                    Text(
                      vi ? 'Đã hiệu chỉnh' : 'Calibrated',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: AppColors.success, fontWeight: FontWeight.w700),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                vi
                    ? 'Cầm điện thoại cách mắt đúng khoảng bạn chọn (dùng thước, hoặc cẳng tay từ khuỷu tới đầu ngón tay ≈ 40 cm), giữ yên rồi bấm Hiệu chỉnh.'
                    : 'Hold the phone exactly the chosen distance from your eyes (use a ruler, or your forearm from elbow to fingertip ≈ 40 cm), keep still, then tap Calibrate.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: _knownOptions.map((v) {
                  final selected = _knownCm == v;
                  return ChoiceChip(
                    label: Text('${v.round()} cm'),
                    selected: selected,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _knownCm = v),
                    selectedColor: AppColors.habitsAccent.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: selected ? AppColors.habitsAccent : null,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: canCalibrate ? () => _calibrate(vi) : null,
                      child: Text(vi ? 'Hiệu chỉnh' : 'Calibrate'),
                    ),
                  ),
                  if (_monitor.isCalibrated) ...[
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () async {
                        await _monitor.resetCalibration();
                        if (mounted) setState(() {});
                      },
                      child: Text(vi ? 'Đặt lại' : 'Reset'),
                    ),
                  ],
                ],
              ),
              if (!canCalibrate)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    vi ? 'Cần nhìn vào camera trước để hiệu chỉnh.' : 'Look at the front camera to calibrate.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textMuted),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          vi
              ? 'Khoảng phù hợp: 30–55 cm. Ảnh chỉ được xử lý trong bộ nhớ, không lưu hay gửi đi.'
              : 'Comfortable range: 30–55 cm. Images are processed in memory only, never saved or sent.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }

  _Status _statusFor(double? cm, bool vi) {
    if (cm == null) {
      return _Status(
        AppColors.textMuted,
        Icons.face_retouching_off_outlined,
        vi ? 'Chưa thấy khuôn mặt — hãy nhìn vào camera trước' : 'No face detected — look at the front camera',
      );
    }
    if (cm < DistanceMonitorService.idealMinCm) {
      return _Status(
        AppColors.warning,
        Icons.warning_amber_rounded,
        vi ? 'Quá gần — lùi ra một chút' : 'Too close — move back a little',
      );
    }
    if (cm <= DistanceMonitorService.idealMaxCm) {
      return _Status(
        AppColors.success,
        Icons.check_circle_outline_rounded,
        vi ? 'Khoảng cách phù hợp' : 'Good distance',
      );
    }
    return _Status(
      AppColors.primaryBlue,
      Icons.info_outline_rounded,
      vi ? 'Hơi xa — có thể đưa lại gần hơn' : 'A bit far — you can bring it closer',
    );
  }
}

class _Status {
  const _Status(this.color, this.icon, this.text);
  final Color color;
  final IconData icon;
  final String text;
}

class _Gauge extends StatelessWidget {
  const _Gauge({required this.cm, required this.color, required this.vi});

  final double? cm;
  final Color color;
  final bool vi;

  static const double _min = 10;
  static const double _max = 80;

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).dividerColor;
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            double pos(double v) => ((v - _min) / (_max - _min)).clamp(0.0, 1.0) * w;
            return SizedBox(
              height: 26,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 8,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(5)),
                    ),
                  ),
                  Positioned(
                    left: pos(DistanceMonitorService.idealMinCm),
                    width: pos(DistanceMonitorService.idealMaxCm) - pos(DistanceMonitorService.idealMinCm),
                    top: 8,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                  if (cm != null)
                    Positioned(
                      left: pos(cm!) - 9,
                      top: 4,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              flex: 20,
              child: Text(vi ? 'Gần' : 'Close', style: Theme.of(context).textTheme.bodySmall),
            ),
            Expanded(
              flex: 25,
              child: Text(
                vi ? 'Phù hợp' : 'Good',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Expanded(
              flex: 25,
              child: Text(
                vi ? 'Xa' : 'Far',
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Icon(icon, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 14),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}