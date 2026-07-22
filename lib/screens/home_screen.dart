import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;

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
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
                child: const Text('👤', style: TextStyle(fontSize: 20)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _ScoreCard(score: state.eyeHealthScore),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: '📱',
                  label: strings.screenTime,
                  value: '${state.screenTimeHours}h',
                  color: AppColors.homeAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  icon: '🌳',
                  label: strings.outdoor,
                  value: '${state.outdoorHours}h',
                  color: AppColors.primaryTeal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  icon: '☕',
                  label: strings.breaks,
                  value: '${state.breakCount}',
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(strings.weeklyOverview, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SectionCard(
            child: SizedBox(
              height: 120,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 100,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                          final idx = value.toInt();
                          if (idx < 0 || idx >= days.length) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            days[idx],
                            style: Theme.of(context).textTheme.bodySmall,
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    _bar(0, 72),
                    _bar(1, 78),
                    _bar(2, 84),
                    _bar(3, 80),
                    _bar(4, 88),
                    _bar(5, 76),
                    _bar(6, 84, isToday: true),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(strings.aiSuggestions, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _SuggestionCard(
            icon: '🌿',
            title: strings.takeBreak,
            subtitle: strings.takeBreakSubtitle,
            color: AppColors.primaryTeal,
          ),
          const SizedBox(height: 10),
          _SuggestionCard(
            icon: '☀️',
            title: strings.moreOutdoor,
            subtitle: strings.moreOutdoorSubtitle,
            color: AppColors.warning,
          ),
          const SizedBox(height: 10),
          _SuggestionCard(
            icon: '😴',
            title: strings.improveSleep,
            subtitle: strings.improveSleepSubtitle,
            color: AppColors.testAccent,
          ),
        ],
      ),
    );
  }

  BarChartGroupData _bar(int x, double y, {bool isToday = false}) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          width: 18,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: isToday
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
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<AppState>().strings;

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
  });

  final String icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
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
    );
  }
}
