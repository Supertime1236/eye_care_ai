import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/habit_provider.dart';
import '../providers/language_provider.dart';
import '../providers/reminder_provider.dart';
import '../services/device_data_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';

// EyeBreakScreen thay thế hoàn toàn màn hình Eye Test cũ.
// Đây là một bộ đếm giờ nhắc người dùng nghỉ mắt theo chu kỳ (mặc định theo
// quy tắc 20-20-20). Khi hết giờ, một màn hình toàn màn hình hiện ra yêu cầu
// người dùng nhìn xa trong 20 giây, sau đó tự xác nhận đã nghỉ — số lần nghỉ
// này được ghi nhận THẬT (qua HabitProvider.recordEyeBreak) và đồng bộ với habit
// "Eye Breaks" ở trang Habits.
class EyeBreakScreen extends StatefulWidget {
  const EyeBreakScreen({super.key});

  @override
  State<EyeBreakScreen> createState() => _EyeBreakScreenState();
}

class _EyeBreakScreenState extends State<EyeBreakScreen> {
  Timer? _countdownTimer;
  int _secondsRemaining = 0;
  bool _breakPromptShowing = false;

  static const _intervalOptions = [10, 20, 30, 45];

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadSavedReminder();
  }

  Future<void> _loadSavedReminder() async {
    final reminder = context.read<ReminderProvider>();
    final endAt = await DeviceDataService.instance.loadBreakReminderEnd();
    final interval = await DeviceDataService.instance.loadBreakReminderIntervalMinutes();
    if (endAt != null && interval != null) {
      final now = DateTime.now();
      final secondsLeft = endAt.difference(now).inSeconds;
      if (secondsLeft > 0) {
        reminder.toggleEyeBreakReminder(true);
        _secondsRemaining = secondsLeft;
        _startCountdown(reminder);
      } else {
        _secondsRemaining = 0;
        _breakPromptShowing = true;
      }
      setState(() {});
    }
  }

  void _startReminder(ReminderProvider reminder) {
    _countdownTimer?.cancel();
    _secondsRemaining = reminder.reminderMinutes * 60;
    reminder.toggleEyeBreakReminder(true);
    _saveReminderEnd(reminder.reminderMinutes);
    _startCountdown(reminder);
    setState(() {});
  }

  void _startCountdown(ReminderProvider reminder) {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _secondsRemaining--;
        if (_secondsRemaining <= 0) {
          _breakPromptShowing = true;
          _countdownTimer?.cancel();
          NotificationService.instance.showInstantNotification(
            title: context.read<LanguageProvider>().strings.eyeBreakTimeUp,
            body: context.read<LanguageProvider>().strings.eyeBreakLookAway,
          );
        }
      });
    });
  }

  void _stopReminder(ReminderProvider reminder) {
    _countdownTimer?.cancel();
    reminder.toggleEyeBreakReminder(false);
    DeviceDataService.instance.clearBreakReminderEnd();
    setState(() {
      _secondsRemaining = 0;
      _breakPromptShowing = false;
    });
  }

  Future<void> _confirmBreakTaken(ReminderProvider reminder) async {
    await context.read<HabitProvider>().recordEyeBreak();
    if (!mounted) return;
    setState(() => _breakPromptShowing = false);
    // Tự động bắt đầu chu kỳ đếm ngược tiếp theo.
    _startReminder(reminder);
  }

  Future<void> _saveReminderEnd(int intervalMinutes) async {
    final endAt = DateTime.now().add(Duration(minutes: intervalMinutes));
    await DeviceDataService.instance.saveBreakReminderEnd(endAt, intervalMinutes);
  }

  void _dismissPrompt(ReminderProvider reminder) {
    setState(() => _breakPromptShowing = false);
    _startReminder(reminder);
  }

  String _formatCountdown(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final reminder = context.watch<ReminderProvider>();
    final language = context.watch<LanguageProvider>();
    final strings = language.strings;

    if (_breakPromptShowing) {
      return _BreakPromptView(
        onDone: () => _confirmBreakTaken(reminder),
        onSkip: () => _dismissPrompt(reminder),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.eyeBreakTitle, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(strings.eyeBreakSubtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),
          SectionCard(
            child: Column(
              children: [
                SizedBox(
                  width: 160,
                  height: 160,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 160,
                        height: 160,
                        child: CircularProgressIndicator(
                          value: reminder.isEyeBreakReminderActive && reminder.reminderMinutes > 0
                              ? _secondsRemaining / (reminder.reminderMinutes * 60)
                              : 1,
                          strokeWidth: 10,
                          backgroundColor: AppColors.border,
                          valueColor: const AlwaysStoppedAnimation(AppColors.testAccent),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            reminder.isEyeBreakReminderActive
                                ? _formatCountdown(_secondsRemaining)
                                : '--:--',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          Text(
                            reminder.isEyeBreakReminderActive
                                ? strings.eyeBreakNextIn
                                : strings.eyeBreakStart,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (!reminder.isEyeBreakReminderActive) ...[
                  Text(strings.eyeBreakIntervalLabel, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: _intervalOptions.map((minutes) {
                      final selected = reminder.reminderMinutes == minutes;
                      return ChoiceChip(
                        label: Text('$minutes ${strings.vi ? "phút" : "min"}'),
                        selected: selected,
                        onSelected: (_) => reminder.setReminderMinutes(minutes),
                        selectedColor: AppColors.testAccent.withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          color: selected ? AppColors.testAccent : null,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: reminder.isEyeBreakReminderActive
                          ? AppColors.error
                          : AppColors.testAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => reminder.isEyeBreakReminderActive
                        ? _stopReminder(reminder)
                        : _startReminder(reminder),
                    child: Text(
                      reminder.isEyeBreakReminderActive ? strings.eyeBreakStop : strings.eyeBreakStart,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.testAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Text('👁️', style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(strings.eyeBreakTodayCount, style: Theme.of(context).textTheme.bodySmall),
                      Text(
                        '${context.watch<HabitProvider>().eyeBreaksTakenToday}',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: AppColors.testAccent,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakPromptView extends StatefulWidget {
  const _BreakPromptView({required this.onDone, required this.onSkip});

  final VoidCallback onDone;
  final VoidCallback onSkip;

  @override
  State<_BreakPromptView> createState() => _BreakPromptViewState();
}

class _BreakPromptViewState extends State<_BreakPromptView> {
  int _secondsLeft = 20;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft <= 1) {
        _timer?.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;
    return Container(
      color: AppColors.testAccent.withValues(alpha: 0.06),
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🌿', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          Text(
            strings.eyeBreakTimeUp,
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            strings.eyeBreakLookAway,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text(
            '$_secondsLeft',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: AppColors.testAccent,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.testAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: widget.onDone,
              child: Text(strings.eyeBreakDone),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: widget.onSkip,
            child: Text(strings.eyeBreakSkip),
          ),
        ],
      ),
    );
  }
}
