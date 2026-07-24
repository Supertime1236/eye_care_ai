import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_strings.dart';
import '../models/eye_health_standards.dart';
import '../providers/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';

// HabitsSurveyScreen: khảo sát ngắn về thói quen liên quan đến mắt, so sánh
// với thông số tiêu chuẩn (lib/models/eye_health_standards.dart) và cho phép
// người dùng áp dụng ngay các target được gợi ý vào trang Habits.
class HabitsSurveyScreen extends StatefulWidget {
  const HabitsSurveyScreen({super.key});

  @override
  State<HabitsSurveyScreen> createState() => _HabitsSurveyScreenState();
}

class _HabitsSurveyScreenState extends State<HabitsSurveyScreen> {
  AgeGroup _ageGroup = AgeGroup.adult;
  double _screenHours = 4;
  double _outdoorMinutes = 30;
  double _readingDistance = 30;
  double _sleepHours = 7;
  double _breaksPerDay = 4;

  SurveyResult? _result;

  void _submit(bool vi) {
    final answers = SurveyAnswers(
      ageGroup: _ageGroup,
      screenHoursPerDay: _screenHours,
      outdoorMinutesPerDay: _outdoorMinutes,
      readingDistanceCm: _readingDistance,
      sleepHoursPerNight: _sleepHours,
      breaksPerDay: _breaksPerDay,
    );
    setState(() => _result = evaluateSurvey(answers, vi));
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<AppState>().strings;

    return Scaffold(
      appBar: AppBar(
        title: Text(_result == null ? strings.surveyTitle : strings.surveyResultsTitle),
      ),
      body: SafeArea(
        child: _result == null ? _buildForm(context, strings) : _buildResults(context, strings),
      ),
    );
  }

  Widget _buildForm(BuildContext context, AppStrings strings) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.surveyAgeQuestion, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
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
          const SizedBox(height: 24),
          _SurveySlider(
            question: strings.surveyScreenQuestion,
            value: _screenHours,
            min: 0,
            max: 12,
            divisions: 24,
            unit: strings.vi ? 'giờ' : 'hrs',
            onChanged: (v) => setState(() => _screenHours = v),
          ),
          _SurveySlider(
            question: strings.surveyOutdoorQuestion,
            value: _outdoorMinutes,
            min: 0,
            max: 180,
            divisions: 36,
            unit: strings.vi ? 'phút' : 'min',
            onChanged: (v) => setState(() => _outdoorMinutes = v),
          ),
          _SurveySlider(
            question: strings.surveyDistanceQuestion,
            value: _readingDistance,
            min: 10,
            max: 80,
            divisions: 70,
            unit: 'cm',
            onChanged: (v) => setState(() => _readingDistance = v),
          ),
          _SurveySlider(
            question: strings.surveySleepQuestion,
            value: _sleepHours,
            min: 3,
            max: 12,
            divisions: 18,
            unit: strings.vi ? 'giờ' : 'hrs',
            onChanged: (v) => setState(() => _sleepHours = v),
          ),
          _SurveySlider(
            question: strings.surveyBreaksQuestion,
            value: _breaksPerDay,
            min: 0,
            max: 20,
            divisions: 20,
            unit: strings.vi ? 'lần' : 'times',
            onChanged: (v) => setState(() => _breaksPerDay = v),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.habitsAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _submit(strings.vi),
              child: Text(strings.surveySubmit),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context, AppStrings strings) {
    final result = _result!;
    final state = context.read<AppState>();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.surveyResultsSubtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          ...result.rows.map((row) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ComparisonCard(row: row, strings: strings),
              )),
          const SizedBox(height: 8),
          Text(
            strings.surveyDisclaimer,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.habitsAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                state.applySurveyTargets(result.targets);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(strings.surveyAppliedMessage)),
                );
                Navigator.of(context).pop();
              },
              child: Text(strings.surveyApplyButton),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => setState(() => _result = null),
              child: Text(strings.surveyRetake),
            ),
          ),
        ],
      ),
    );
  }
}

class _SurveySlider extends StatelessWidget {
  const _SurveySlider({
    required this.question,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.unit,
    required this.onChanged,
  });

  final String question;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String unit;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question, style: Theme.of(context).textTheme.titleSmall),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: divisions,
                  activeColor: AppColors.habitsAccent,
                  label: '${value.round()} $unit',
                  onChanged: onChanged,
                ),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  '${value.round()} $unit',
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({required this.row, required this.strings});

  final ComparisonRow row;
  final AppStrings strings;

  String _rowTitle(String id) {
    switch (id) {
      case 'phone':
        return strings.habitTitle('phone');
      case 'outdoor':
        return strings.habitTitle('outdoor');
      case 'sleep':
        return strings.habitTitle('sleep');
      case 'breaks':
        return strings.habitTitle('breaks');
      case 'reading_distance':
        return strings.vi ? 'Khoảng cách đọc' : 'Reading Distance';
      default:
        return id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = row.isGood ? AppColors.success : AppColors.warning;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(_rowTitle(row.id), style: Theme.of(context).textTheme.titleSmall),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  row.isGood ? strings.surveyGoodStatus : strings.surveyNeedsWorkStatus,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatLine(
                  label: strings.surveyCurrentLabel,
                  value: row.currentValue.round().toString(),
                ),
              ),
              Expanded(
                child: _StatLine(
                  label: strings.surveyTargetLabel,
                  value: row.recommendedLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            row.tip,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
        Text(value, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}
