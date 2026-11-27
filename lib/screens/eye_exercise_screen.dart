import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_strings.dart';
import '../providers/language_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';

enum EyeExerciseType { blink, focus, movement, relax }

class EyeExerciseScreen extends StatefulWidget {
  const EyeExerciseScreen({super.key});

  @override
  State<EyeExerciseScreen> createState() => _EyeExerciseScreenState();
}

class _EyeExerciseScreenState extends State<EyeExerciseScreen> {
  static const _historyKey = 'eye_exercise_history';
  Timer? _timer;
  EyeExerciseType? _activeType;
  int _remainingSeconds = 0;
  int _completedSecondsToday = 0;

  int get _completedMinutesToday => (_completedSecondsToday / 60).ceil();

  @override
  void initState() {
    super.initState();
    _loadTodayProgress();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadTodayProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null) return;
    try {
      final today = DateTime.now();
      final entries = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      final seconds = entries.fold<int>(0, (sum, entry) {
        final date = DateTime.tryParse(entry['date'] as String? ?? '');
        if (date == null ||
            date.year != today.year ||
            date.month != today.month ||
            date.day != today.day) {
          return sum;
        }
        return sum + ((entry['seconds'] as num?)?.toInt() ?? 0);
      });
      if (mounted) setState(() => _completedSecondsToday = seconds);
    } catch (_) {}
  }

  int _durationFor(EyeExerciseType type) => switch (type) {
    EyeExerciseType.blink => 30,
    EyeExerciseType.focus => 60,
    EyeExerciseType.movement => 60,
    EyeExerciseType.relax => 30,
  };

  void _start(EyeExerciseType type) {
    _timer?.cancel();
    setState(() {
      _activeType = type;
      _remainingSeconds = _durationFor(type);
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds <= 1) {
        _timer?.cancel();
        _finish(type);
      } else {
        setState(() => _remainingSeconds -= 1);
      }
    });
  }

  Future<void> _finish(EyeExerciseType type) async {
    final duration = _durationFor(type);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    List<Map<String, dynamic>> history = [];
    if (raw != null) {
      try {
        history = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      } catch (_) {}
    }
    history.add({
      'date': DateTime.now().toIso8601String(),
      'type': type.name,
      'seconds': duration,
    });
    if (history.length > 100) history = history.sublist(history.length - 100);
    await prefs.setString(_historyKey, jsonEncode(history));

    if (!mounted) return;
    setState(() {
      _activeType = null;
      _remainingSeconds = 0;
      _completedSecondsToday += duration;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.read<LanguageProvider>().strings.eyeExerciseCompleted,
        ),
      ),
    );
  }

  void _stop() {
    _timer?.cancel();
    setState(() {
      _activeType = null;
      _remainingSeconds = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;
    final accent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(strings.eyeExerciseTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_activeType != null)
                      _ActiveExercise(
                        type: _activeType!,
                        remainingSeconds: _remainingSeconds,
                        strings: strings,
                        accent: accent,
                        onStop: _stop,
                      )
                    else ...[
                      SectionCard(
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Icon(Icons.spa_rounded, color: accent),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    strings.eyeExerciseToday,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$_completedMinutesToday ${strings.minuteUnit}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          color: accent,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        strings.eyeExerciseChoose,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      _ExerciseCard(
                        icon: Icons.visibility_outlined,
                        title: strings.eyeExerciseBlinkTitle,
                        subtitle: strings.eyeExerciseBlinkBody,
                        duration: '30 ${strings.secondUnit}',
                        onStart: () => _start(EyeExerciseType.blink),
                      ),
                      _ExerciseCard(
                        icon: Icons.zoom_out_map_rounded,
                        title: strings.eyeExerciseFocusTitle,
                        subtitle: strings.eyeExerciseFocusBody,
                        duration: '60 ${strings.secondUnit}',
                        onStart: () => _start(EyeExerciseType.focus),
                      ),
                      _ExerciseCard(
                        icon: Icons.control_camera_rounded,
                        title: strings.eyeExerciseMovementTitle,
                        subtitle: strings.eyeExerciseMovementBody,
                        duration: '60 ${strings.secondUnit}',
                        onStart: () => _start(EyeExerciseType.movement),
                      ),
                      _ExerciseCard(
                        icon: Icons.self_improvement_rounded,
                        title: strings.eyeExerciseRelaxTitle,
                        subtitle: strings.eyeExerciseRelaxBody,
                        duration: '30 ${strings.secondUnit}',
                        onStart: () => _start(EyeExerciseType.relax),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        strings.eyeExerciseSafety,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.onStart,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String duration;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    duration,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onStart,
              child: const Icon(Icons.play_arrow_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveExercise extends StatelessWidget {
  const _ActiveExercise({
    required this.type,
    required this.remainingSeconds,
    required this.strings,
    required this.accent,
    required this.onStop,
  });

  final EyeExerciseType type;
  final int remainingSeconds;
  final AppStrings strings;
  final Color accent;
  final VoidCallback onStop;

  String get title => switch (type) {
    EyeExerciseType.blink => strings.eyeExerciseBlinkTitle,
    EyeExerciseType.focus => strings.eyeExerciseFocusTitle,
    EyeExerciseType.movement => strings.eyeExerciseMovementTitle,
    EyeExerciseType.relax => strings.eyeExerciseRelaxTitle,
  };

  String get instruction => switch (type) {
    EyeExerciseType.blink => strings.eyeExerciseBlinkInstruction,
    EyeExerciseType.focus => strings.eyeExerciseFocusInstruction,
    EyeExerciseType.movement => strings.eyeExerciseMovementInstruction,
    EyeExerciseType.relax => strings.eyeExerciseRelaxInstruction,
  };

  IconData get icon => switch (type) {
    EyeExerciseType.blink => Icons.visibility_outlined,
    EyeExerciseType.focus => Icons.zoom_out_map_rounded,
    EyeExerciseType.movement => Icons.control_camera_rounded,
    EyeExerciseType.relax => Icons.self_improvement_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final total = switch (type) {
      EyeExerciseType.blink => 30,
      EyeExerciseType.focus => 60,
      EyeExerciseType.movement => 60,
      EyeExerciseType.relax => 30,
    };
    final progress = (total - remainingSeconds) / total;

    return SectionCard(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 360;
            final iconSize = compact ? 40.0 : 48.0;
            final timerSize = compact ? 88.0 : 112.0;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: iconSize, color: accent),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  instruction,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: timerSize,
                  height: timerSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 8,
                          backgroundColor: AppColors.border,
                          valueColor: AlwaysStoppedAnimation(accent),
                        ),
                      ),
                      Text(
                        '$remainingSeconds',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: onStop,
                  icon: const Icon(Icons.stop_rounded),
                  label: Text(strings.eyeExerciseStop),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
