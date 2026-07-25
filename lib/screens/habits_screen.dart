import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_strings.dart';
import '../providers/habit_provider.dart';
import '../providers/language_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';

// HabitsScreen hiển thị tiến trình các thói quen tốt cho mắt trong ngày.
// Đây là màn hình CHỈ XEM (read-only): giá trị `current` của mỗi thói quen
// được HabitProvider nạp từ DeviceDataService (cảm biến / hệ điều hành của máy),
// người dùng không còn tự nhập tay như trước.
class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  @override
  void initState() {
    super.initState();
    final habit = context.read<HabitProvider>();
    habit.startHabitTracking();
    // Chạy sau frame đầu để tránh gọi notifyListeners() trong lúc build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      habit.refreshHabitsFromDevice();
    });
  }

  @override
  Widget build(BuildContext context) {
    final habit = context.watch<HabitProvider>();
    final language = context.watch<LanguageProvider>();
    final strings = language.strings;

    return RefreshIndicator(
      onRefresh: habit.refreshHabitsFromDevice,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(strings.dailyHabits, style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 4),
                      Text(
                        strings.trackRoutines,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                _CompletionBadge(percent: habit.habitsCompletionPercent),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.wb_sunny_outlined, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  strings.vi
                      ? 'Cập nhật lần cuối: ${_formatTime(habit.habitsLastUpdated)}'
                      : 'Last updated: ${_formatTime(habit.habitsLastUpdated)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
                const Spacer(),
                if (habit.isRefreshingHabits)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: CircularProgressIndicator(
                            value: habit.habitsCompletionPercent / 100,
                            strokeWidth: 6,
                            backgroundColor: AppColors.border,
                            valueColor: const AlwaysStoppedAnimation(
                              AppColors.habitsAccent,
                            ),
                          ),
                        ),
                        Text(
                          '${habit.habitsCompletionPercent}%',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: AppColors.habitsAccent,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.todaysProgress,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          strings.completedHabits(habit.habits.where((h) => h.progress >= 1).length, habit.habits.length),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...habit.habits.map((habitItem) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _HabitCard(habit: habitItem),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '—';
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _CompletionBadge extends StatelessWidget {
  const _CompletionBadge({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: AppColors.gradientPrimary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$percent% Complete',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({required this.habit});

  final HabitData habit;

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;
    final color = Color(habit.color);
    final valueText = habit.unit == 'hrs'
        ? habit.current.toStringAsFixed(1)
        : habit.current.round().toString();
    final targetText = habit.unit == 'hrs'
        ? habit.target.toStringAsFixed(0)
        : habit.target.round().toString();

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
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(habit.icon, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            strings.habitTitle(habit.id),
                            style: Theme.of(context).textTheme.titleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: habit.isLive ? AppColors.success : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      strings.habitSubtitle(habit.id),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    valueText,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  Text(
                    strings.vi
                        ? 'trong $targetText ${strings.habitUnit(habit.unit)}'
                        : 'of $targetText ${strings.habitUnit(habit.unit)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedProgressBar(
            progress: habit.progress,
            color: color,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                strings.vi
                    ? '${(habit.progress * 100).round()}% mục tiêu ngày'
                    : '${(habit.progress * 100).round()}% of daily goal',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                _statusLabel(habit, strings),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: habit.isLive
                          ? (habit.progress >= 0.8 ? AppColors.success : AppColors.textMuted)
                          : AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _statusLabel(HabitData habit, AppStrings strings) {
    if (!habit.isLive) {
      return strings.vi ? 'Chưa có nguồn dữ liệu' : 'No data source yet';
    }
    if (habit.progress >= 1) {
      return strings.vi ? 'Đã đạt mục tiêu!' : 'Goal reached!';
    }
    if (habit.progress >= 0.8) {
      return strings.vi ? 'Sắp đạt mục tiêu!' : 'Almost there!';
    }
    return strings.vi ? 'Đang theo dõi...' : 'Tracking...';
  }
}
