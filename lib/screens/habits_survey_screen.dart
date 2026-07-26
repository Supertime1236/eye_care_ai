import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_strings.dart';
import '../models/eye_health_standards.dart';
import '../providers/habit_provider.dart';
import '../providers/language_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';
import 'main_shell.dart';

// HabitsSurveyScreen: khảo sát từng câu một (giống dạng wizard/onboarding),
// so sánh câu trả lời với thông số tiêu chuẩn, và cho phép áp dụng ngay các
// target được gợi ý vào trang Habits.
//
// mandatory = true: dùng khi mở app lần đầu — không cho bỏ qua/back ra ngoài,
// sau khi áp dụng sẽ vào thẳng MainShell thay vì quay lại màn trước.
class HabitsSurveyScreen extends StatefulWidget {
  const HabitsSurveyScreen({super.key, this.mandatory = false});

  final bool mandatory;

  @override
  State<HabitsSurveyScreen> createState() => _HabitsSurveyScreenState();
}

class _HabitsSurveyScreenState extends State<HabitsSurveyScreen> {
  final _pageController = PageController();
  int _pageIndex = 0;

  AgeGroup _ageGroup = AgeGroup.adult;
  double _screenHours = 4;
  double _outdoorMinutes = 30;
  double _readingDistance = 30;
  double _sleepHours = 7;
  double _breaksPerDay = 4;

  SurveyResult? _result;
  int _targetStepIndex = 0;
  bool _showCustomTargetError = false;
  final Map<String, TargetLevel> _selectedTargetLevels = {};
  final Map<String, double> _selectedTargetValues = {};
  final Map<String, double> _customTargetValues = {};
  final Map<String, TextEditingController> _customTargetControllers = {};

  static const _totalQuestions = 6;

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _customTargetControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _goNext() {
    if (_result == null) {
      if (_pageIndex < _totalQuestions - 1) {
        setState(() => _pageIndex++);
        _pageController.nextPage(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _submit();
      }
      return;
    }

    if (_targetStepIndex < _surveyTargetHabitIds.length - 1) {
      setState(() => _targetStepIndex++);
    }
  }

  void _goBack() {
    if (_pageIndex == 0) return;
    setState(() => _pageIndex--);
    _pageController.previousPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  static const _surveyTargetHabitIds = ['phone', 'outdoor', 'sleep', 'breaks'];

  void _submit() {
    final vi = context.read<LanguageProvider>().strings.vi;
    final answers = SurveyAnswers(
      ageGroup: _ageGroup,
      screenHoursPerDay: _screenHours,
      outdoorMinutesPerDay: _outdoorMinutes,
      readingDistanceCm: _readingDistance,
      sleepHoursPerNight: _sleepHours,
      breaksPerDay: _breaksPerDay,
    );
    final result = evaluateSurvey(answers, vi);
    setState(() {
      _result = result;
      _targetStepIndex = 0;
      _showCustomTargetError = false;
      _selectedTargetLevels.clear();
      _selectedTargetValues.clear();
      _customTargetValues.clear();
      _customTargetControllers.clear();
      for (final id in _surveyTargetHabitIds) {
        final row = result.rows.firstWhere((row) => row.id == id);
        _selectedTargetLevels[id] = TargetLevel.recommended;
        _selectedTargetValues[id] = row.recommendedValue;
      }
    });
  }

  void _retake() {
    setState(() {
      _result = null;
      _pageIndex = 0;
      _targetStepIndex = 0;
      _showCustomTargetError = false;
      _selectedTargetLevels.clear();
      _selectedTargetValues.clear();
      _customTargetValues.clear();
      for (final controller in _customTargetControllers.values) {
        controller.dispose();
      }
      _customTargetControllers.clear();
    });
    _pageController.jumpToPage(0);
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>();
    final theme = context.watch<ThemeProvider>();
    final strings = language.strings;

    return PopScope(
      canPop: !widget.mandatory || _result != null,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.mandatory,
          title: Text(_result == null ? strings.surveyTitle : strings.surveyResultsTitle),
          actions: [
            // Cho phép đổi ngôn ngữ và chế độ sáng/tối ngay trong khảo sát
            // bắt buộc lần đầu — lúc này người dùng chưa vào được trang Settings.
            TextButton(
              onPressed: () => language.toggleVietnamese(!language.isVietnamese),
              child: Text(
                strings.vi ? 'EN' : 'VI',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              icon: Icon(theme.isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
              tooltip: strings.vi ? 'Đổi giao diện' : 'Toggle theme',
              onPressed: () => theme.toggleDarkMode(!theme.isDarkMode),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          child: _result == null ? _buildWizard(context, strings) : _buildResults(context, strings),
        ),
      ),
    );
  }

  Widget _buildWizard(BuildContext context, AppStrings strings) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.stepCount(_pageIndex + 1, _totalQuestions),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (_pageIndex + 1) / _totalQuestions,
                  minHeight: 6,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation(AppColors.habitsAccent),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _QuestionPage(
                question: strings.surveyAgeQuestion,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AgeGroup.values.map((group) {
                    final selected = _ageGroup == group;
                    return ChoiceChip(
                      label: Text(EyeHealthStandards.ageGroupLabel(group, strings.vi)),
                      selected: selected,
                      onSelected: (_) => setState(() => _ageGroup = group),
                      selectedColor: AppColors.habitsAccent.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: selected ? AppColors.habitsAccent : null,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    );
                  }).toList(),
                ),
              ),
              _QuestionPage(
                question: strings.surveyScreenQuestion,
                child: _StepperInput(
                  value: _screenHours,
                  min: 0,
                  max: 16,
                  step: 0.5,
                  unit: strings.vi ? 'giờ' : 'hrs',
                  onChanged: (v) => setState(() => _screenHours = v),
                ),
              ),
              _QuestionPage(
                question: strings.surveyOutdoorQuestion,
                child: _StepperInput(
                  value: _outdoorMinutes,
                  min: 0,
                  max: 240,
                  step: 10,
                  unit: strings.vi ? 'phút' : 'min',
                  onChanged: (v) => setState(() => _outdoorMinutes = v),
                ),
              ),
              _QuestionPage(
                question: strings.surveyDistanceQuestion,
                child: _StepperInput(
                  value: _readingDistance,
                  min: 10,
                  max: 80,
                  step: 1,
                  unit: 'cm',
                  onChanged: (v) => setState(() => _readingDistance = v),
                ),
              ),
              _QuestionPage(
                question: strings.surveySleepQuestion,
                child: _StepperInput(
                  value: _sleepHours,
                  min: 3,
                  max: 12,
                  step: 0.5,
                  unit: strings.vi ? 'giờ' : 'hrs',
                  onChanged: (v) => setState(() => _sleepHours = v),
                ),
              ),
              _QuestionPage(
                question: strings.surveyBreaksQuestion,
                child: _StepperInput(
                  value: _breaksPerDay,
                  min: 0,
                  max: 20,
                  step: 1,
                  unit: strings.vi ? 'lần' : 'times',
                  onChanged: (v) => setState(() => _breaksPerDay = v),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Row(
            children: [
              if (_pageIndex > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _goBack,
                    child: Text(strings.vi ? 'Quay lại' : 'Back'),
                  ),
                ),
              if (_pageIndex > 0) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.habitsAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _goNext,
                  child: Text(
                    _pageIndex == _totalQuestions - 1
                        ? strings.surveySubmit
                        : (strings.vi ? 'Tiếp tục' : 'Next'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResults(BuildContext context, AppStrings strings) {
    final result = _result!;
    final settings = context.watch<SettingsProvider>();
    final currentHabitId = _surveyTargetHabitIds[_targetStepIndex];
    final currentRow = result.rows.firstWhere((row) => row.id == currentHabitId);
    final selectedLevel = _selectedTargetLevels[currentHabitId] ?? TargetLevel.recommended;
    final currentTargetValue = _selectedTargetValues[currentHabitId] ?? currentRow.recommendedValue;
    final customController = _customTargetControllers.putIfAbsent(
      currentHabitId,
      () => TextEditingController(text: _selectedTargetValues[currentHabitId]?.toStringAsFixed(1) ?? ''),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.targetSelectionTitle, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(strings.targetSummarySubtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_habitTitle(currentHabitId, strings), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  '${strings.targetCurrentLabel}: ${_formatTargetValue(currentRow.currentValue, currentRow.unit, settings.useMetric)} ${_unitLabel(currentRow.unit, settings.useMetric, strings)}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  '${strings.targetRecommendedLabel}: ${_formatTargetValue(currentRow.recommendedValue, currentRow.unit, settings.useMetric)} ${_unitLabel(currentRow.unit, settings.useMetric, strings)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 20),
                _TargetChoiceCard(
                  title: strings.targetOptionEasy,
                  description: strings.vi
                      ? 'Nội dung dễ đạt hơn, gần với giá trị hiện tại.'
                      : 'Easier than recommended, closer to your current value.',
                  selected: selectedLevel == TargetLevel.easy,
                  onTap: () {
                    setState(() {
                      _selectedTargetLevels[currentHabitId] = TargetLevel.easy;
                      _selectedTargetValues[currentHabitId] = EyeHealthStandards.calculateTargetValue(
                        currentRow.currentValue,
                        currentRow.recommendedValue,
                        TargetLevel.easy,
                      );
                      _showCustomTargetError = false;
                    });
                  },
                  value: _formatTargetValue(
                    EyeHealthStandards.calculateTargetValue(
                      currentRow.currentValue,
                      currentRow.recommendedValue,
                      TargetLevel.easy,
                    ),
                    currentRow.unit,
                    settings.useMetric,
                  ),
                  unit: _unitLabel(currentRow.unit, settings.useMetric, strings),
                ),
                const SizedBox(height: 12),
                _TargetChoiceCard(
                  title: strings.targetOptionRecommended,
                  description: strings.vi
                      ? 'Mục tiêu chuyển tiếp vừa phải, dễ thực hiện hơn.'
                      : 'A transition target that is easier than ideal but still better.',
                  selected: selectedLevel == TargetLevel.recommended,
                  onTap: () {
                    setState(() {
                      _selectedTargetLevels[currentHabitId] = TargetLevel.recommended;
                      _selectedTargetValues[currentHabitId] = EyeHealthStandards.calculateTargetValue(
                        currentRow.currentValue,
                        currentRow.recommendedValue,
                        TargetLevel.recommended,
                      );
                      _showCustomTargetError = false;
                    });
                  },
                  value: _formatTargetValue(
                    EyeHealthStandards.calculateTargetValue(
                      currentRow.currentValue,
                      currentRow.recommendedValue,
                      TargetLevel.recommended,
                    ),
                    currentRow.unit,
                    settings.useMetric,
                  ),
                  unit: _unitLabel(currentRow.unit, settings.useMetric, strings),
                ),
                const SizedBox(height: 12),
                _TargetChoiceCard(
                  title: strings.targetOptionChallenge,
                  description: strings.vi
                      ? 'Thử thách hơn, gần với mức khuyến nghị chuẩn.'
                      : 'More ambitious, closer to the recommended goal.',
                  selected: selectedLevel == TargetLevel.challenge,
                  onTap: () {
                    setState(() {
                      _selectedTargetLevels[currentHabitId] = TargetLevel.challenge;
                      _selectedTargetValues[currentHabitId] = EyeHealthStandards.calculateTargetValue(
                        currentRow.currentValue,
                        currentRow.recommendedValue,
                        TargetLevel.challenge,
                      );
                      _showCustomTargetError = false;
                    });
                  },
                  value: _formatTargetValue(
                    EyeHealthStandards.calculateTargetValue(
                      currentRow.currentValue,
                      currentRow.recommendedValue,
                      TargetLevel.challenge,
                    ),
                    currentRow.unit,
                    settings.useMetric,
                  ),
                  unit: _unitLabel(currentRow.unit, settings.useMetric, strings),
                ),
                const SizedBox(height: 12),
                _TargetChoiceCard(
                  title: strings.targetOptionCustom,
                  description: strings.vi
                      ? 'Nhập giá trị theo ý bạn trong khoảng hợp lý.'
                      : 'Enter a custom target within a valid range.',
                  selected: selectedLevel == TargetLevel.custom,
                  onTap: () {
                    setState(() {
                      _selectedTargetLevels[currentHabitId] = TargetLevel.custom;
                      _showCustomTargetError = false;
                    });
                  },
                  value: _formatTargetValue(currentTargetValue, currentRow.unit, settings.useMetric),
                  unit: _unitLabel(currentRow.unit, settings.useMetric, strings),
                ),
                if (selectedLevel == TargetLevel.custom) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: customController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: strings.targetCustomHint,
                      errorText: _showCustomTargetError ? strings.targetCustomError : null,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (text) {
                      final value = double.tryParse(text);
                      if (value != null) {
                        _customTargetValues[currentHabitId] = value;
                        _selectedTargetValues[currentHabitId] = value;
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_targetStepIndex < _surveyTargetHabitIds.length - 1)
            Row(
              children: [
                if (_targetStepIndex > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _targetStepIndex--),
                      child: Text(strings.targetBack),
                    ),
                  ),
                if (_targetStepIndex > 0) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.habitsAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      if (selectedLevel == TargetLevel.custom) {
                        final value = double.tryParse(customController.text);
                        if (value == null ||
                            !EyeHealthStandards.inCustomRange(
                              value,
                              currentRow.currentValue,
                              currentRow.recommendedValue,
                              currentRow.isDecrease,
                            )) {
                          setState(() => _showCustomTargetError = true);
                          return;
                        }
                      }
                      _goNext();
                    },
                    child: Text(strings.targetNext),
                  ),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ..._surveyTargetHabitIds.map((id) {
                  final row = result.rows.firstWhere((row) => row.id == id);
                  final value = _selectedTargetValues[id] ?? row.recommendedValue;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_habitTitle(id, strings), style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 8),
                          Text(
                            '${strings.targetYourPlan}: ${_formatTargetValue(value, row.unit, settings.useMetric)} ${_unitLabel(row.unit, settings.useMetric, strings)}',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${strings.targetOptionRecommended}: ${_formatTargetValue(row.recommendedValue, row.unit, settings.useMetric)} ${_unitLabel(row.unit, settings.useMetric, strings)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.habitsAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final selectedTargets = Map<String, double>.fromEntries(
                      _surveyTargetHabitIds.map((id) => MapEntry(id, _selectedTargetValues[id] ?? result.rows.firstWhere((row) => row.id == id).recommendedValue)),
                    );
                    await context.read<HabitProvider>().applySurveyTargets(selectedTargets);
                    await context.read<HabitProvider>().markSurveyCompleted();
                    if (!context.mounted) return;
                    if (widget.mandatory) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const MainShell()),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(strings.surveyAppliedMessage)),
                      );
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text(strings.targetApplyButton),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _retake,
                  child: Text(strings.surveyRetake),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _QuestionPage extends StatelessWidget {
  const _QuestionPage({required this.question, required this.child});

  final String question;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}

// _StepperInput: chọn giá trị bằng nút +/- thay vì kéo thanh trượt, dễ căn
// chỉnh chính xác hơn trên di động.
class _StepperInput extends StatelessWidget {
  const _StepperInput({
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.unit,
    required this.onChanged,
  });

  final double value;
  final double min;
  final double max;
  final double step;
  final String unit;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _RoundIconButton(
            icon: Icons.remove_rounded,
            onTap: value > min ? () => onChanged((value - step).clamp(min, max)) : null,
          ),
          Column(
            children: [
              Text(
                value % 1 == 0 ? value.round().toString() : value.toStringAsFixed(1),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: AppColors.habitsAccent,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              Text(unit, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          _RoundIconButton(
            icon: Icons.add_rounded,
            onTap: value < max ? () => onChanged((value + step).clamp(min, max)) : null,
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: enabled ? AppColors.habitsAccent.withValues(alpha: 0.12) : AppColors.border,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            color: enabled ? AppColors.habitsAccent : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _TargetChoiceCard extends StatelessWidget {
  const _TargetChoiceCard({
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
    required this.value,
    required this.unit,
  });

  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected ? AppColors.habitsAccent.withValues(alpha: 0.12) : null,
          border: Border.all(
            color: selected ? AppColors.habitsAccent : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(description, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$value $unit',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.habitsAccent,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

String _habitTitle(String id, AppStrings strings) {
  switch (id) {
    case 'phone':
      return strings.habitTitle('phone');
    case 'outdoor':
      return strings.habitTitle('outdoor');
    case 'sleep':
      return strings.habitTitle('sleep');
    case 'breaks':
      return strings.habitTitle('breaks');
    default:
      return strings.habitTitle(id);
  }
}

String _formatTargetValue(double value, String unit, bool useMetric) {
  final formatted = value % 1 == 0 ? value.round().toString() : value.toStringAsFixed(1);
  return formatted;
}

String _unitLabel(String unit, bool useMetric, AppStrings strings) {
  if (unit == 'cm' && !useMetric) {
    return strings.inchUnit;
  }
  return strings.habitUnit(unit);
}

double valueToInches(double cm) => cm / 2.54;
