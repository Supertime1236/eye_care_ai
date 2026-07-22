import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';

// EyeTestScreen quản lý quy trình kiểm tra mắt theo từng bước.
// Dữ liệu bước hiện tại được lấy từ AppState và mỗi bước hiển thị UI khác nhau.
class EyeTestScreen extends StatelessWidget {
  const EyeTestScreen({super.key});

  static const _snellenLines = [
    ('E', 48.0),
    ('F P', 36.0),
    ('T O Z', 28.0),
    ('L P E D', 22.0),
    ('P E C F D', 18.0),
    ('E D F C Z P', 14.0),
  ];

  static const _options = ['20/20', '20/25', '20/30', '20/40', '20/50'];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final step = state.eyeTestStep;
    final strings = state.strings;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strings.eyeTest, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                strings.snellenScreening,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (step + 1) / 4,
                  minHeight: 6,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation(AppColors.testAccent),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                strings.stepCount(step + 1, 4),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildStep(context, state),
          ),
        ),
      ],
    );
  }

  Widget _buildStep(BuildContext context, AppState state) {
    switch (state.eyeTestStep) {
      case 0:
        return _IntroStep(
          key: const ValueKey(0),
          onStart: () => state.nextEyeTestStep(),
        );
      case 1:
        return _CoverEyeStep(
          key: const ValueKey(1),
          isLeftEye: state.testingLeftEye,
          onContinue: () => state.nextEyeTestStep(),
        );
      case 2:
        return _ReadLettersStep(
          key: const ValueKey(2),
          isLeftEye: state.testingLeftEye,
          lines: _snellenLines,
          options: _options,
          onSelect: (result) => state.submitEyeResult(result),
        );
      case 3:
      default:
        return _ResultsStep(
          key: const ValueKey(3),
          leftResult: state.leftEyeResult ?? '20/20',
          rightResult: state.rightEyeResult ?? '20/25',
          onRetest: () => state.resetEyeTest(),
        );
    }
  }
}

class _IntroStep extends StatelessWidget {
  const _IntroStep({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<AppState>().strings;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          SectionCard(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.testAccent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('👁️', style: TextStyle(fontSize: 36)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  strings.visionScreeningTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  strings.snellenScreening,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _InfoRow(icon: '💡', text: strings.ensureLighting),
          _InfoRow(icon: '📏', text: strings.maintainDistance),
          _InfoRow(icon: '👓', text: strings.wearGlasses),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.testAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(strings.startTest),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _CoverEyeStep extends StatelessWidget {
  const _CoverEyeStep({
    super.key,
    required this.isLeftEye,
    required this.onContinue,
  });

  final bool isLeftEye;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<AppState>().strings;
    final eyeLabel = isLeftEye ? strings.eyeLabelLeft : strings.eyeLabelRight;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          SectionCard(
            child: Column(
              children: [
                Text(
                  '${strings.coverYour} $eyeLabel',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _EyeIcon(label: 'L', active: isLeftEye, covered: isLeftEye),
                    const SizedBox(width: 32),
                    _EyeIcon(
                      label: 'R',
                      active: !isLeftEye,
                      covered: !isLeftEye,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  strings.useHandCover,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onContinue,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.testAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(strings.continueText),
            ),
          ),
        ],
      ),
    );
  }
}

class _EyeIcon extends StatelessWidget {
  const _EyeIcon({
    required this.label,
    required this.active,
    required this.covered,
  });

  final String label;
  final bool active;
  final bool covered;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: active
                ? AppColors.testAccent.withValues(alpha: 0.15)
                : AppColors.border.withValues(alpha: 0.5),
            shape: BoxShape.circle,
            border: Border.all(
              color: active ? AppColors.testAccent : AppColors.border,
              width: 2,
            ),
          ),
          child: Center(
            child: covered
                ? const Text('🤚', style: TextStyle(fontSize: 28))
                : const Text('👁️', style: TextStyle(fontSize: 28)),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: active ? AppColors.testAccent : AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _ReadLettersStep extends StatelessWidget {
  const _ReadLettersStep({
    super.key,
    required this.isLeftEye,
    required this.lines,
    required this.options,
    required this.onSelect,
  });

  final bool isLeftEye;
  final List<(String, double)> lines;
  final List<String> options;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<AppState>().strings;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            strings.readSmallestLine,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            isLeftEye ? strings.eyeLabelLeft : strings.eyeLabelRight,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.testAccent,
                ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            child: Column(
              children: lines.map((line) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    line.$1,
                    style: TextStyle(
                      fontSize: line.$2,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 8,
                      color: AppColors.textPrimary,
                      fontFamily: 'monospace',
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          Text(strings.selectYourResult, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: options.map((opt) {
              return ActionChip(
                label: Text(opt),
                backgroundColor: AppColors.testAccent.withValues(alpha: 0.1),
                labelStyle: TextStyle(
                  color: AppColors.testAccent,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide(color: AppColors.testAccent.withValues(alpha: 0.3)),
                onPressed: () => onSelect(opt),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ResultsStep extends StatelessWidget {
  const _ResultsStep({
    super.key,
    required this.leftResult,
    required this.rightResult,
    required this.onRetest,
  });

  final String leftResult;
  final String rightResult;
  final VoidCallback onRetest;

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<AppState>().strings;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('✅', style: TextStyle(fontSize: 32)),
            ),
          ),
          const SizedBox(height: 12),
          Text(strings.testComplete, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _ResultCard(label: strings.eyeLabelLeft, result: leftResult),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ResultCard(label: strings.eyeLabelRight, result: rightResult),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SectionCard(
            color: AppColors.primaryBlue.withValues(alpha: 0.06),
            borderColor: AppColors.primaryBlue.withValues(alpha: 0.15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: AppColors.gradientPrimary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text('🤖', style: TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.aiInsight,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppColors.primaryBlue,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        strings.visionAiFeedback,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onRetest,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(strings.retakeTest),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.label, required this.result});

  final String label;
  final String result;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            result,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.testAccent,
                ),
          ),
        ],
      ),
    );
  }
}
