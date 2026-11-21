import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/language_provider.dart';
import '../services/app_usage_history_service.dart';
import '../theme/app_colors.dart';
import 'shared_widgets.dart';

/// Thống kê THÁNG theo thời gian sử dụng ứng dụng: tổng giờ, trung bình mỗi
/// ngày, so với tháng trước, biểu đồ từng ngày và các ứng dụng dùng nhiều nhất.
class MonthlyAppUsageCard extends StatefulWidget {
  const MonthlyAppUsageCard({super.key});

  @override
  State<MonthlyAppUsageCard> createState() => _MonthlyAppUsageCardState();
}

class _MonthlyAppUsageCardState extends State<MonthlyAppUsageCard> {
  static const _maxMonthsBack = 11;
  static const _topApps = 6;

  int _monthOffset = 0; // 0 = tháng này
  MonthlyAppUsage? _data;
  bool _loading = true;

  DateTime get _month {
    final now = DateTime.now();
    return DateTime(now.year, now.month - _monthOffset);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    // Điền bù 7 ngày gần nhất (mỗi ngày 1 lần) trước khi đọc, để lần đầu mở
    // đã có số liệu.
    await AppUsageHistoryService.instance.backfillRecentDays();
    final data = await AppUsageHistoryService.instance.loadMonth(_month);
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  void _changeMonth(int delta) {
    final next = _monthOffset + delta;
    if (next < 0 || next > _maxMonthsBack) return;
    _monthOffset = next;
    _load();
  }

  String _monthLabel(bool vi) {
    final m = _month;
    if (vi) return 'Tháng ${m.month}/${m.year}';
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${names[m.month - 1]} ${m.year}';
  }

  String _duration(int seconds, bool vi) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h == 0) return vi ? '$m phút' : '${m}m';
    if (m == 0) return vi ? '$h giờ' : '${h}h';
    return vi ? '$h giờ $m phút' : '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final vi = context.watch<LanguageProvider>().isVietnamese;
    final data = _data;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _monthOffset < _maxMonthsBack ? () => _changeMonth(1) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  _monthLabel(vi),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                onPressed: _monthOffset > 0 ? () => _changeMonth(-1) : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          if (_loading || data == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (data.trackedDays == 0)
            _empty(context, vi)
          else
            ..._content(context, data, vi),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context, bool vi) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          const Icon(Icons.calendar_month_outlined, size: 36, color: AppColors.textMuted),
          const SizedBox(height: 10),
          Text(
            vi ? 'Chưa có dữ liệu cho tháng này' : 'No data for this month yet',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            vi
                ? 'Số liệu được lưu mỗi ngày bạn mở app. Cần cấp quyền Usage Access để đọc thời gian sử dụng.'
                : 'Data is saved on each day you open the app. Usage Access permission is required.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  List<Widget> _content(BuildContext context, MonthlyAppUsage data, bool vi) {
    final primary = Theme.of(context).colorScheme.primary;
    final vs = data.vsPreviousPercent;
    final busiest = data.busiestDay;

    return [
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(child: _Tile(value: _duration(data.totalSeconds, vi), label: vi ? 'Tổng thời gian' : 'Total')),
          const SizedBox(width: 10),
          Expanded(
            child: _Tile(
              value: _duration(data.averagePerDaySeconds, vi),
              label: vi ? 'Trung bình/ngày' : 'Daily average',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Tile(
              value: '${data.trackedDays}/${data.daysInMonth}',
              label: vi ? 'Ngày có dữ liệu' : 'Days tracked',
            ),
          ),
        ],
      ),
      if (vs != null) ...[
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              vs > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              size: 18,
              // Dùng máy nhiều hơn là chiều "đáng chú ý", ít hơn là chiều tốt.
              color: vs > 5 ? AppColors.warning : (vs < -5 ? AppColors.success : AppColors.textMuted),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                vs.abs() < 3
                    ? (vi ? 'Mức dùng mỗi ngày gần như không đổi so với tháng trước.' : 'Daily use is about the same as last month.')
                    : (vi
                        ? 'Mức dùng mỗi ngày ${vs > 0 ? 'tăng' : 'giảm'} ${vs.abs().round()}% so với tháng trước.'
                        : 'Daily use ${vs > 0 ? 'rose' : 'fell'} ${vs.abs().round()}% vs last month.'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ],
      if (busiest != null) ...[
        const SizedBox(height: 6),
        Text(
          vi
              ? 'Ngày dùng nhiều nhất: $busiest/${data.month.month} (${_duration(data.dailySeconds[busiest]!, vi)}).'
              : 'Busiest day: ${data.month.month}/$busiest (${_duration(data.dailySeconds[busiest]!, vi)}).',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
      const SizedBox(height: 18),
      Text(vi ? 'Mỗi ngày trong tháng' : 'Each day of the month', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 10),
      SizedBox(height: 140, child: _dailyChart(context, data, vi, primary)),
      const SizedBox(height: 18),
      Text(vi ? 'Ứng dụng dùng nhiều nhất' : 'Most used apps', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 10),
      ..._appRows(context, data, vi, primary),
      const SizedBox(height: 10),
      Text(
        vi
            ? 'Android chỉ lưu chi tiết khoảng 7 ngày, nên app tự lưu số liệu mỗi ngày bạn mở app. Ngày nào không mở app (và đã quá 7 ngày) sẽ không có dữ liệu.'
            : 'Android only keeps about 7 days of detail, so the app saves a daily record whenever you open it. Days you did not open the app (and older than 7 days) have no data.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
      ),
    ];
  }

  Widget _dailyChart(BuildContext context, MonthlyAppUsage data, bool vi, Color primary) {
    var maxHours = 1.0;
    for (final s in data.dailySeconds.values) {
      final h = s / 3600;
      if (h > maxHours) maxHours = h;
    }
    final month = data.month;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceBetween,
        maxY: maxHours * 1.2,
        minY: 0,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final day = group.x;
              final seconds = data.dailySeconds[day] ?? 0;
              return BarTooltipItem(
                '$day/${month.month}: ${_duration(seconds, vi)}',
                Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final day = value.round();
                if (day != value) return const SizedBox.shrink();
                if (day != 1 && day % 5 != 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('$day', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var d = 1; d <= data.daysInMonth; d++)
            BarChartGroupData(
              x: d,
              barRods: [
                BarChartRodData(
                  toY: (data.dailySeconds[d] ?? 0) / 3600,
                  width: 5,
                  color: data.dailySeconds.containsKey(d) ? primary : Colors.transparent,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  List<Widget> _appRows(BuildContext context, MonthlyAppUsage data, bool vi, Color primary) {
    final top = data.apps.take(_topApps).toList();
    final shown = top.fold<int>(0, (sum, a) => sum + a.seconds);
    final other = data.totalSeconds - shown;
    final maxSeconds = top.isEmpty ? 1 : top.first.seconds;

    Widget row(String name, int seconds, {Color? color, String? sub}) {
      final share = data.totalSeconds == 0 ? 0 : (seconds / data.totalSeconds * 100).round();
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_duration(seconds, vi)} · $share%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (seconds / maxSeconds).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                valueColor: AlwaysStoppedAnimation(color ?? primary),
              ),
            ),
            if (sub != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(sub, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
              ),
          ],
        ),
      );
    }

    return [
      for (final a in top)
        row(
          a.appName.isEmpty ? a.packageName : a.appName,
          a.seconds,
          sub: vi ? 'Dùng ${a.activeDays} ngày' : 'Used on ${a.activeDays} days',
        ),
      if (other > 0 && data.apps.length > _topApps)
        row(vi ? 'Khác...' : 'Other...', other, color: AppColors.textMuted),
    ];
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 2),
        Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}