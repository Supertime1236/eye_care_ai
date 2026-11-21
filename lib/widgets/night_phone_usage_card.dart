import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/language_provider.dart';
import '../providers/settings_provider.dart';
import '../services/night_usage_service.dart';
import '../theme/app_colors.dart';
import 'shared_widgets.dart';

/// Thẻ "Dùng điện thoại ban đêm": cho biết bạn thường dùng điện thoại tới mấy
/// giờ vào ban đêm. Chỉ là ƯỚC LƯỢNG thói quen từ thời gian dùng điện thoại,
/// không khẳng định giờ ngủ. Tự ẩn khi chưa có dữ liệu.
///
/// Mặc định chỉ hiện phần tóm tắt dễ hiểu (giờ cuối + 1 câu nhận xét). Bấm
/// "Xem 7 đêm" để mở biểu đồ: mỗi đêm là 1 thanh ngang, thanh càng dài nghĩa là
/// càng dùng máy muộn; vạch đứng đánh dấu mốc 23:00.
class NightPhoneUsageCard extends StatefulWidget {
  const NightPhoneUsageCard({super.key});

  @override
  State<NightPhoneUsageCard> createState() => _NightPhoneUsageCardState();
}

class _NightPhoneUsageCardState extends State<NightPhoneUsageCard> {
  NightUsageSummary? _summary;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final summary = await NightUsageService.instance.compute();
    if (!mounted) return;
    setState(() => _summary = summary);
  }

  String _formatTime(DateTime t, bool is24Hour) {
    if (is24Hour) {
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
    final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h12:${t.minute.toString().padLeft(2, '0')} ${t.hour >= 12 ? 'PM' : 'AM'}';
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    if (summary == null) return const SizedBox.shrink();

    final vi = context.watch<LanguageProvider>().isVietnamese;
    final is24Hour = context.watch<SettingsProvider>().is24Hour;
    final primary = Theme.of(context).colorScheme.primary;
    final latest = summary.latest;
    final last = latest.lastActivity;
    final counted = summary.countedNights;
    final late = summary.lateNights;

    final caption = latest.ongoing
        ? (vi ? 'Lần dùng máy gần nhất tối nay' : 'Latest phone use tonight')
        : (vi ? 'Lần cuối bạn dùng máy đêm qua' : 'Last time you used your phone last night');

    // 12:13 AM dễ gây nhầm là buổi trưa -> ghi chú rõ là sau nửa đêm.
    final afterMidnight = last != null && last.hour < nightEndHourLabel;

    String? insight;
    String? tip;
    if (counted > 0) {
      if (late == 0) {
        insight = vi
            ? 'Bạn hầu như không dùng điện thoại sau 23:00 trong $counted đêm gần đây.'
            : 'You barely used your phone after 23:00 in the last $counted nights.';
      } else {
        insight = vi
            ? 'Bạn dùng điện thoại sau 23:00 trong $late/$counted đêm gần đây.'
            : 'You used your phone after 23:00 on $late of the last $counted nights.';
        if (late >= (counted / 2).ceil()) {
          tip = vi
              ? 'Thử đặt điện thoại xuống trước 23:00 để mắt được nghỉ và dễ ngủ hơn.'
              : 'Try putting your phone down before 23:00 to rest your eyes and wind down.';
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.bedtime_outlined, size: 18, color: primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    vi ? 'Dùng điện thoại ban đêm' : 'Night phone usage',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(caption, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  last == null ? '—' : _formatTime(last, is24Hour),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (afterMidnight) ...[
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      vi ? 'sau nửa đêm' : 'after midnight',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textMuted),
                    ),
                  ),
                ],
              ],
            ),
            if (insight != null) ...[
              const SizedBox(height: 10),
              Text(insight, style: Theme.of(context).textTheme.bodyMedium),
            ],
            if (tip != null) ...[
              const SizedBox(height: 4),
              Text(
                tip,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ],
            const SizedBox(height: 6),
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Text(
                      _expanded
                          ? (vi ? 'Ẩn chi tiết' : 'Hide details')
                          : (vi ? 'Xem 7 đêm gần đây' : 'See the last 7 nights'),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: primary),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      size: 20,
                      color: primary,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? _NightBars(summary: summary, vi: vi, is24Hour: is24Hour, format: _formatTime)
                  : const SizedBox(width: double.infinity),
            ),
            const SizedBox(height: 6),
            Text(
              vi
                  ? 'Ước lượng từ thời gian dùng điện thoại (21:00–05:00), không phải giờ ngủ chính xác.'
                  : 'Estimated from phone usage (21:00–05:00), not an exact bedtime.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  // Giờ < mốc này (sáng sớm) được coi là sau nửa đêm của đêm đó.
  static const int nightEndHourLabel = 12;
}

/// 7 thanh ngang, mỗi thanh là 1 đêm (cũ nhất ở trên). Trục ngang đi từ 21:00 tới
/// 05:00; chiều dài thanh = lúc hoạt động cuối. Vạch đứng = 23:00.
class _NightBars extends StatelessWidget {
  const _NightBars({
    required this.summary,
    required this.vi,
    required this.is24Hour,
    required this.format,
  });

  final NightUsageSummary summary;
  final bool vi;
  final bool is24Hour;
  final String Function(DateTime, bool) format;

  static const int _spanMinutes = 8 * 60; // 21:00 -> 05:00
  static const int _lateMarkMinutes = 2 * 60; // 23:00 cách 21:00 là 120 phút

  @override
  Widget build(BuildContext context) {
    final nights = summary.nights.reversed.toList(); // cũ nhất ở trên
    final track = Theme.of(context).dividerColor;
    const viDays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    const enDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            vi
                ? 'Mỗi thanh là 1 đêm. Thanh dài tới đâu là bạn còn dùng máy tới giờ đó.'
                : 'Each bar is one night. The longer the bar, the later you were still using your phone.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          for (final n in nights) _row(context, n, track, vi ? viDays : enDays),
          const SizedBox(height: 6),
          // Chú thích trục: 21:00 ... 23:00 ... 05:00
          Row(
            children: [
              const SizedBox(width: 54),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    final markX = c.maxWidth * _lateMarkMinutes / _spanMinutes;
                    return SizedBox(
                      height: 16,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            child: Text('21:00', style: _axisStyle(context)),
                          ),
                          Positioned(
                            left: markX - 14,
                            child: Text('23:00',
                                style: _axisStyle(context)?.copyWith(fontWeight: FontWeight.w700)),
                          ),
                          Positioned(
                            right: 0,
                            child: Text('05:00', style: _axisStyle(context)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 56),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _legendDot(AppColors.success),
              const SizedBox(width: 6),
              Text(vi ? 'Trước 23:00' : 'Before 23:00', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 16),
              _legendDot(AppColors.warning),
              const SizedBox(width: 6),
              Text(vi ? 'Sau 23:00' : 'After 23:00', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  TextStyle? _axisStyle(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10.5, color: AppColors.textMuted);

  Widget _legendDot(Color c) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
      );

  Widget _row(BuildContext context, NightUsageNight n, Color track, List<String> days) {
    final label = '${days[n.date.weekday - 1]} ${n.date.day}/${n.date.month}';
    final last = n.lastActivity;

    double fraction = 0;
    Color barColor = AppColors.success;
    String valueText;
    if (last == null) {
      valueText = n.usedLate == null
          ? (vi ? 'Chưa đủ' : 'Pending')
          : (vi ? 'Không dùng' : 'No use');
    } else {
      final start = DateTime(n.date.year, n.date.month, n.date.day, 21);
      final minutes = last.difference(start).inMinutes.clamp(0, _spanMinutes);
      fraction = minutes / _spanMinutes;
      barColor = minutes > _lateMarkMinutes ? AppColors.warning : AppColors.success;
      valueText = format(last, is24Hour);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                return SizedBox(
                  height: 14,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: track.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      if (last != null)
                        Container(
                          width: (w * fraction).clamp(4.0, w),
                          decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      // vạch mốc 23:00
                      Positioned(
                        left: w * _lateMarkMinutes / _spanMinutes,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 1.5,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              valueText,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}