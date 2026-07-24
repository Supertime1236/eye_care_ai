import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';

// EyeBreakScreen thay thế hoàn toàn màn hình Eye Test cũ.
// Đây là một bộ đếm giờ nhắc người dùng nghỉ mắt theo chu kỳ (mặc định theo
// quy tắc 20-20-20). Khi hết giờ, một màn hình toàn màn hình hiện ra yêu cầu
// người dùng nhìn xa trong 20 giây, sau đó tự xác nhận đã nghỉ — số lần nghỉ
// này được ghi nhận THẬT (qua AppState.recordEyeBreak) và đồng bộ với habit
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

  void _startReminder(AppState state) {
    _countdownTimer?.cancel();
    _secondsRemaining = state.reminderMinutes * 60;
    state.toggleEyeBreakReminder(true);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _secondsRemaining--;
        if (_secondsRemaining <= 0) {
          _breakPromptShowing = true;
          _countdownTimer?.cancel();
        }
      });
    });
    setState(() {});
  }

  void _stopReminder(AppState state) {
    _countdownTimer?.cancel();
    state.toggleEyeBreakReminder(false);
    setState(() {
      _secondsRemaining = 0;
      _breakPromptShowing = false;
    });
  }

  Future<void> _confirmBreakTaken(AppState state) async {
    await state.recordEyeBreak();
    if (!mounted) return;
    setState(() => _breakPromptShowing = false);
    // Tự động bắt đầu chu kỳ đếm ngược tiếp theo.
    _startReminder(state);
  }

  void _dismissPrompt(AppState state) {
    setState(() => _breakPromptShowing = false);
    _startReminder(state);
  }

  String _formatCountdown(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;

    if (_breakPromptShowing) {
      return _BreakPromptView(
        onDone: () => _confirmBreakTaken(state),
        onSkip: () => _dismissPrompt(state),
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
                          value: state.isEyeBreakReminderActive && state.reminderMinutes > 0
                              ? _secondsRemaining / (state.reminderMinutes * 60)
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
                            state.isEyeBreakReminderActive
                                ? _formatCountdown(_secondsRemaining)
                                : '--:--',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          Text(
                            state.isEyeBreakReminderActive
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
                if (!state.isEyeBreakReminderActive) ...[
                  Text(strings.eyeBreakIntervalLabel, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: _intervalOptions.map((minutes) {
                      final selected = state.reminderMinutes == minutes;
                      return ChoiceChip(
                        label: Text('$minutes ${strings.vi ? "phút" : "min"}'),
                        selected: selected,
                        onSelected: (_) => state.setReminderMinutes(minutes),
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
                      backgroundColor: state.isEyeBreakReminderActive
                          ? AppColors.error
                          : AppColors.testAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => state.isEyeBreakReminderActive
                        ? _stopReminder(state)
                        : _startReminder(state),
                    child: Text(
                      state.isEyeBreakReminderActive ? strings.eyeBreakStop : strings.eyeBreakStart,
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
                        '${state.eyeBreaksTakenToday}',
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
    final strings = context.watch<AppState>().strings;
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
