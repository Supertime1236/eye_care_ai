import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/language_provider.dart';
import '../providers/settings_provider.dart';
import '../services/night_usage_service.dart';
import '../theme/app_colors.dart';
import 'shared_widgets.dart';

/// Thẻ "Dùng điện thoại ban đêm": hoạt động cuối + thói quen dùng sau 23:00
/// trong 7 đêm gần nhất. Chỉ là ƯỚC LƯỢNG thói quen từ thời gian dùng điện
/// thoại, không khẳng định giờ ngủ. Tự ẩn khi chưa có dữ liệu (chưa cấp quyền
/// Usage Access, không phải Android...).
class NightPhoneUsageCard extends StatefulWidget {
  const NightPhoneUsageCard({super.key});

  @override
  State<NightPhoneUsageCard> createState() => _NightPhoneUsageCardState();
}

class _NightPhoneUsageCardState extends State<NightPhoneUsageCard> {
  NightUsageSummary? _summary;

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
        ? (vi ? 'Hoạt động gần nhất tối nay' : 'Latest activity tonight')
        : (vi ? 'Hoạt động cuối đêm qua' : 'Last activity last night');

    String? insight;
    if (counted > 0) {
      insight = late == 0
          ? (vi
              ? 'Bạn hầu như không dùng điện thoại sau 23:00 trong $counted đêm gần đây.'
              : 'You barely used your phone after 23:00 in the last $counted nights.')
          : (vi
              ? 'Bạn thường dùng điện thoại sau 23:00 trong $late/$counted đêm gần đây.'
              : 'You used your phone after 23:00 on $late of the last $counted nights.');
    }

    // Chấm 7 đêm: cũ nhất bên trái -> mới nhất bên phải.
    final dots = summary.nights.reversed.toList();

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
            const SizedBox(height: 12),
            Text(caption, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(
              last == null ? '—' : _formatTime(last, is24Hour),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (insight != null) ...[
              const SizedBox(height: 8),
              Text(insight, style: Theme.of(context).textTheme.bodyMedium),
            ],
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [for (final n in dots) _NightDot(night: n, vi: vi, color: primary)],
            ),
            const SizedBox(height: 12),
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
}

class _NightDot extends StatelessWidget {
  const _NightDot({required this.night, required this.vi, required this.color});

  final NightUsageNight night;
  final bool vi;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const viDays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    const enDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final label = (vi ? viDays : enDays)[night.date.weekday - 1];

    final late = night.usedLate;
    final Color fill;
    final Color border;
    if (late == true) {
      fill = color;
      border = color;
    } else if (late == false) {
      fill = Colors.transparent;
      border = color.withValues(alpha: 0.5);
    } else {
      fill = Colors.transparent;
      border = AppColors.textMuted.withValues(alpha: 0.4);
    }

    return Column(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(color: border, width: 1.5),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
      ],
    );
  }
}