import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/habit_provider.dart';
import '../providers/language_provider.dart';
import '../providers/profile_provider.dart';
import '../services/device_data_service.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';
import 'habits_survey_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final habit = context.watch<HabitProvider>();
    final language = context.watch<LanguageProvider>();
    final strings = language.strings;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.goodMorning,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    strings.welcomeTitle,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
              Builder(builder: (context) {
                final profile = context.watch<ProfileProvider>();
                return CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
                  backgroundImage: profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
                  child: profile.avatarUrl == null
                      ? Text(
                          profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '👤',
                          style: const TextStyle(fontSize: 18, color: AppColors.primaryBlue),
                        )
                      : null,
                );
              }),
            ],
          ),
          const SizedBox(height: 20),
          _ScoreCard(score: habit.eyeHealthScore),
          const SizedBox(height: 16),
          SectionCard(
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HabitsSurveyScreen()),
              ),
              borderRadius: BorderRadius.circular(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: AppColors.gradientPrimary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Text('📋', style: TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(strings.surveyEntryTitle, style: Theme.of(context).textTheme.titleSmall),
                        Text(
                          strings.surveyEntrySubtitle,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: '📱',
                  label: strings.screenTime,
                  value: '${habit.screenTimeHours.toStringAsFixed(1)}h',
                  color: AppColors.homeAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  icon: '🌳',
                  label: strings.outdoor,
                  value: '${habit.outdoorHours.toStringAsFixed(1)}h',
                  color: AppColors.primaryTeal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  icon: '☕',
                  label: strings.breaks,
                  value: '${habit.breakCount}',
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(strings.weeklyOverview, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          const _WeeklyOverviewChart(),
          const SizedBox(height: 20),
          Text(strings.aiSuggestions, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _SuggestionCard(
            icon: '🌿',
            title: strings.takeBreak,
            subtitle: strings.takeBreakSubtitle,
            color: AppColors.primaryTeal,
            bullets: strings.vi
                ? const [
                    ('✨', 'AI: hôm qua bạn nhìn màn hình liên tục ~47 phút, gần gấp đôi mức thường thấy.'),
                    ('👁️', '20 phút nhìn màn hình → 20 giây nhìn xa 6 mét.'),
                    ('🔥', 'Duy trì 3 ngày liên tiếp để mở khoá huy hiệu.'),
                  ]
                : const [
                    ('✨', 'AI: yesterday you had ~47 min of continuous screen time, almost double your usual.'),
                    ('👁️', '20 min on screen → 20 sec looking 6m away.'),
                    ('🔥', 'Keep a 3-day streak to unlock a badge.'),
                  ],
          ),
          const SizedBox(height: 10),
          _SuggestionCard(
            icon: '☀️',
            title: strings.moreOutdoor,
            subtitle: strings.moreOutdoorSubtitle,
            color: AppColors.warning,
            bullets: strings.vi
                ? const [
                    ('✨', 'AI: ước tính thời gian ngoài trời từ hoạt động hằng ngày của bạn.'),
                    ('🌤️', 'Ánh sáng tự nhiên giúp làm chậm tiến triển cận thị.'),
                    ('💡', 'Kết hợp đi bộ ngoài trời với cuộc gọi hoặc giờ ăn trưa.'),
                  ]
                : const [
                    ('✨', "AI estimates outdoor exposure from your daily activity."),
                    ('🌤️', 'Natural light helps slow myopia progression.'),
                    ('💡', 'Pair outdoor time with a call or lunch break.'),
                  ],
          ),
          const SizedBox(height: 10),
          _SuggestionCard(
            icon: '😴',
            title: strings.improveSleep,
            subtitle: strings.improveSleepSubtitle,
            color: AppColors.testAccent,
            bullets: strings.vi
                ? const [
                    ('✨', 'AI: tuần này màn hình chỉ tắt trước giờ ngủ trung bình 11 phút.'),
                    ('🌙', 'Nên để màn hình nghỉ ít nhất 30 phút trước khi ngủ.'),
                    ('⏰', 'Mục tiêu: 7-8 giờ ngủ mỗi đêm.'),
                  ]
                : const [
                    ('✨', 'AI: your screens were on until 11 min before bed on average this week.'),
                    ('🌙', 'Aim for at least 30 screen-free minutes before bed.'),
                    ('⏰', 'Target: 7-8 hours of sleep per night.'),
                  ],
          ),
        ],
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.gradientScore,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.eyeHealthScore,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  strings.goodProgress,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    strings.fromLastWeek,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                ),
              ],
            ),
          ),
          ScoreRing(score: score),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final String icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: color,
                ),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.bullets,
  });

  final String icon;
  final String title;
  final String subtitle;
  final Color color;
  // Các gợi ý rút gọn (icon + vài chữ) hiện khi mở chi tiết — thay cho đoạn
  // văn dài, đúng tinh thần "tóm gọn bằng phương tiện phi ngôn ngữ".
  final List<(String, String)> bullets;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetail(context),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(icon, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(icon, style: const TextStyle(fontSize: 24)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(title, style: Theme.of(sheetContext).textTheme.titleMedium),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              for (final b in bullets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.$1, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(b.$2, style: Theme.of(sheetContext).textTheme.bodyMedium),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// Trước đây biểu đồ "Tổng quan tuần" ở Trang chủ dùng 7 số cứng
// (72,78,84,80,88,76,84) — không phản ánh dữ liệu thật của người dùng.
// Widget này tự tải snapshot điểm sức khỏe mắt của 7 ngày gần nhất từ
// DeviceDataService (cùng nguồn dữ liệu với biểu đồ Tuần ở màn Statistics),
// ngày nào chưa có dữ liệu thì vẽ cột rất thấp/mờ thay vì bịa số.
class _WeeklyOverviewChart extends StatefulWidget {
  const _WeeklyOverviewChart();

  @override
  State<_WeeklyOverviewChart> createState() => _WeeklyOverviewChartState();
}

class _WeeklyOverviewChartState extends State<_WeeklyOverviewChart> {
  List<({int score, double screenHours, double sleepHours})?>? _snapshots;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final snapshots = await DeviceDataService.instance.loadCurrentWeekSnapshots();
    if (!mounted) return;
    setState(() => _snapshots = snapshots);
  }

  BarChartGroupData _bar(int x, double? y, {bool isToday = false}) {
    final value = y ?? 4.0; // chưa có dữ liệu -> cột rất thấp thay vì bịa số
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: value,
          width: 18,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: y == null
                ? [AppColors.border, AppColors.border]
                : isToday
                    ? [AppColors.primaryBlue, AppColors.primaryTeal]
                    : [
                        AppColors.primaryBlue.withValues(alpha: 0.4),
                        AppColors.primaryTeal.withValues(alpha: 0.4),
                      ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshots = _snapshots;
    final today = DateTime.now().weekday - 1; // 0 = thứ 2 ... 6 = chủ nhật

    return SectionCard(
      child: SizedBox(
        height: 120,
        child: snapshots == null
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 100,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
                          final idx = value.toInt();
                          if (idx < 0 || idx >= days.length) return const SizedBox.shrink();
                          return Text(days[idx], style: Theme.of(context).textTheme.bodySmall);
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(7, (i) {
                    final score = (i < snapshots.length ? snapshots[i]?.score.toDouble() : null);
                    return _bar(i, score, isToday: i == today);
                  }),
                ),
              ),
      ),
    );
  }
}
