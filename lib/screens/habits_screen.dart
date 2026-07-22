import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';

// HabitsScreen hiển thị danh sách thói quen và tiến trình hoàn thành.
// Người dùng có thể xem tỷ lệ hoàn thành và chọn giá trị thói quen trong modal.
class HabitsScreen extends StatelessWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.dailyHabits, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(
            strings.trackRoutines,
            style: Theme.of(context).textTheme.bodyMedium,
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
                          value: state.habitsCompletionPercent / 100,
                          strokeWidth: 6,
                          backgroundColor: AppColors.border,
                          valueColor: const AlwaysStoppedAnimation(
                            AppColors.habitsAccent,
                          ),
                        ),
                      ),
                      Text(
                        '${state.habitsCompletionPercent}%',
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
                        strings.completedHabits(state.habits.where((h) => h.progress >= 1).length, state.habits.length),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...state.habits.map((habit) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _HabitCard(habit: habit),
            );
          }),
        ],
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({required this.habit});

  final HabitData habit;

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<AppState>().strings;
    final color = Color(habit.color);

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
                    Text(habit.title, style: Theme.of(context).textTheme.titleSmall),
                    Text(
                      'Target: ${habit.target} ${habit.unit}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _showHabitPicker(context, habit),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.border.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${habit.current}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: color,
                            ),
                      ),
                      Text(
                        strings.habitUnit(habit.unit),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AnimatedProgressBar(
                  progress: habit.progress,
                  color: color,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(habit.progress * 100).round()}%',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _showHabitPicker(BuildContext context, HabitData habit) async {
  final state = context.read<AppState>();
  final strings = state.strings;
  int selectedValue = habit.current;
  final controller = FixedExtentScrollController(initialItem: selectedValue);
  final result = await showModalBottomSheet<int>(
    context: context,
    backgroundColor: Theme.of(context).cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 24, left: 16, right: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${strings.chooseValue} ${strings.habitTitle(habit.id)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: ListWheelScrollView.useDelegate(
                controller: controller,
                physics: const FixedExtentScrollPhysics(),
                itemExtent: 48,
                onSelectedItemChanged: (index) {
                  selectedValue = index;
                },
                childDelegate: ListWheelChildBuilderDelegate(
                  builder: (context, index) {
                    if (index > habit.target * 2) return null;
                    return Center(
                      child: Text(
                        '$index ${habit.unit}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: index == selectedValue ? AppColors.primaryBlue : AppColors.textPrimary,
                            ),
                      ),
                    );
                  },
                  childCount: habit.target * 2 + 1,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context, selectedValue);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(strings.confirm),
              ),
            ),
          ],
        ),
      );
    },
  );

  if (result != null) {
    state.setHabitCurrent(habit.id, result);
  }
}
