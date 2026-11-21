import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/habit_provider.dart';
import '../providers/language_provider.dart';
import '../screens/distance_check_screen.dart';
import '../services/distance_monitor_service.dart';
import '../theme/app_colors.dart';
import 'shared_widgets.dart';

/// Thẻ thói quen "Khoảng cách mắt" ở màn Thói quen — thay cho thẻ chung vốn chỉ
/// hiện "23 trong 30 cm" mà không giải thích gì. Nói rõ: mục tiêu là gì, hôm nay
/// đang ở đâu so với mục tiêu, đã đo mấy lần, nên làm gì tiếp.
class DistanceHabitCard extends StatefulWidget {
  const DistanceHabitCard({super.key});

  @override
  State<DistanceHabitCard> createState() => _DistanceHabitCardState();
}

class _DistanceHabitCardState extends State<DistanceHabitCard> {
  static const double _farCm = DistanceMonitorService.idealMaxCm;

  final _monitor = DistanceMonitorService.instance;
  int _total = 0;
  int _good = 0;
  DateTime? _habitStamp;

  @override
  void initState() {
    super.initState();
    _monitor.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _monitor.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final counts = await _monitor.getTodayCounts();
    if (!mounted) return;
    setState(() {
      _total = counts.total;
      _good = counts.good;
    });
  }

  String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final vi = context.watch<LanguageProvider>().isVietnamese;
    final provider = context.watch<HabitProvider>();
    final habit = provider.habits.firstWhere((h) => h.id == 'distance');

    // Dữ liệu thói quen vừa được làm mới -> nạp lại số lần đo.
    if (provider.habitsLastUpdated != _habitStamp) {
      _habitStamp = provider.habitsLastUpdated;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }

    final target = habit.target;
    final avg = habit.isLive ? habit.current : null;
    final enabled = _monitor.enabled;
    final lastAt = _monitor.lastMeasuredAt;

    final Color statusColor;
    final String statusText;
    if (avg == null) {
      statusColor = AppColors.textMuted;
      statusText = vi ? 'Chưa có dữ liệu' : 'No data yet';
    } else if (avg < target) {
      statusColor = AppColors.warning;
      statusText = vi ? 'Hơi gần' : 'A bit close';
    } else {
      statusColor = AppColors.success;
      statusText = vi ? 'Đạt mục tiêu' : 'On target';
    }

    final String advice;
    if (avg != null && avg < target) {
      final more = (target - avg).ceil();
      advice = vi
          ? 'Trung bình hôm nay bạn cầm điện thoại cách mắt khoảng ${avg.round()} cm. Hãy thử lùi ra thêm khoảng $more cm.'
          : 'On average today you held your phone about ${avg.round()} cm from your eyes. Try moving back about $more cm.';
    } else if (avg != null) {
      advice = vi
          ? 'Bạn đang giữ khoảng cách tốt. Cứ duy trì nhé!'
          : "You're keeping a good distance. Keep it up!";
    } else if (!enabled) {
      advice = vi
          ? 'Bật đo khoảng cách để app nhắc khi bạn cầm điện thoại quá gần mắt.'
          : 'Turn on distance checks so the app can warn you when your phone is too close.';
    } else {
      advice = vi
          ? 'Đang chờ lần đo đầu tiên — hãy nhìn vào màn hình trong giây lát.'
          : 'Waiting for the first check — look at the screen for a moment.';
    }

    final goodPercent = _total == 0 ? null : (_good / _total * 100).round();
    final primary = Theme.of(context).colorScheme.primary;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(habit.color).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.straighten_outlined, size: 20, color: Color(habit.color)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vi ? 'Khoảng cách mắt' : 'Eye distance',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      vi ? 'Từ mắt tới màn hình điện thoại' : 'From your eyes to the phone screen',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                avg == null ? '—' : '${avg.round()}',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('cm', style: Theme.of(context).textTheme.titleSmall),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  vi ? 'Mục tiêu: từ ${target.round()} cm' : 'Goal: ${target.round()} cm or more',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          Text(
            vi ? 'Khoảng cách trung bình hôm nay' : "Today's average distance",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          _TargetGauge(value: avg, target: target, farCm: _farCm, color: statusColor, vi: vi),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  value: goodPercent == null ? '—' : '$goodPercent%',
                  label: vi ? 'Lần đo đạt chuẩn' : 'Checks in range',
                ),
              ),
              Expanded(
                child: _Stat(value: '$_total', label: vi ? 'Số lần đo' : 'Checks today'),
              ),
              Expanded(
                child: _Stat(
                  value: lastAt == null ? '—' : _hhmm(lastAt),
                  label: vi ? 'Đo gần nhất' : 'Last check',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(advice, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: enabled
                ? OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DistanceCheckScreen()),
                    ),
                    icon: const Icon(Icons.straighten_outlined, size: 18),
                    label: Text(vi ? 'Đo thử & hiệu chỉnh' : 'Try it & calibrate'),
                  )
                : FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: primary),
                    onPressed: () async {
                      final ok = await _monitor.setEnabled(true);
                      if (!context.mounted || ok) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(vi
                              ? 'Cần cấp quyền camera để đo khoảng cách.'
                              : 'Camera permission is required to measure distance.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.videocam_outlined, size: 18),
                    label: Text(vi ? 'Bật đo khoảng cách' : 'Turn on distance checks'),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Thanh cho thấy khoảng cách trung bình nằm đâu so với mục tiêu: vùng xanh là
/// khoảng nên giữ (từ mục tiêu trở lên), vùng cam là quá gần.
class _TargetGauge extends StatelessWidget {
  const _TargetGauge({
    required this.value,
    required this.target,
    required this.farCm,
    required this.color,
    required this.vi,
  });

  final double? value;
  final double target;
  final double farCm;
  final Color color;
  final bool vi;

  static const double _min = 10;
  static const double _max = 80;

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(context).dividerColor;
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            double pos(double v) => ((v - _min) / (_max - _min)).clamp(0.0, 1.0) * w;
            final okEnd = farCm < target ? target : farCm;
            return SizedBox(
              height: 24,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 7,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(5)),
                    ),
                  ),
                  // vùng quá gần
                  Positioned(
                    left: 0,
                    width: pos(target),
                    top: 7,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.35),
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(5)),
                      ),
                    ),
                  ),
                  // vùng nên giữ
                  Positioned(
                    left: pos(target),
                    width: pos(okEnd) - pos(target),
                    top: 7,
                    child: Container(color: AppColors.success.withValues(alpha: 0.4), height: 10),
                  ),
                  if (value != null)
                    Positioned(
                      left: pos(value!) - 8,
                      top: 4,
                      child: Container(
                        width: 16,
                        height: 16,
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
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              flex: ((target - _min).round()).clamp(1, 100),
              child: Text(vi ? 'Quá gần' : 'Too close', style: Theme.of(context).textTheme.bodySmall),
            ),
            Expanded(
              flex: ((_max - target).round()).clamp(1, 100),
              child: Text(
                vi ? 'Nên giữ' : 'Aim for',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}