import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_strings.dart';
import '../providers/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';

// StatisticsScreen hiển thị biểu đồ và số liệu thống kê sức khỏe mắt.
//
// Đây là nơi người dùng xem các xu hướng theo tuần hoặc theo tháng.
// Màn hình chỉ đọc dữ liệu từ AppState, vì vậy khi cần thay đổi dữ liệu
// mẫu hoặc cách tính toán, bạn chỉnh sửa AppState hoặc các mảng dữ liệu bên dưới.
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  // Danh sách loại số liệu mà người dùng có thể chọn.
  // 0 = Score, 1 = Screen Time, 2 = Sleep.
  static const _metrics = ['Score', 'Screen Time', 'Sleep'];

  // Dữ liệu mẫu tuần/tháng cho mỗi loại số liệu.
  // Nếu muốn thay đổi biểu đồ demo, sửa trực tiếp các mảng này.
  static const _weeklyScore = [78.0, 80.0, 82.0, 79.0, 84.0, 81.0, 84.0];
  static const _monthlyScore = [72.0, 74.0, 76.0, 78.0, 80.0, 82.0, 84.0];

  static const _weeklyScreen = [5.2, 4.8, 4.5, 4.9, 4.2, 3.8, 4.2];
  static const _monthlyScreen = [6.1, 5.8, 5.5, 5.2, 4.8, 4.5, 4.2];

  static const _weeklySleep = [6.5, 7.0, 7.5, 6.8, 7.2, 8.0, 7.0];
  static const _monthlySleep = [6.0, 6.2, 6.5, 6.8, 7.0, 7.2, 7.0];

  // Chọn dữ liệu biểu đồ dựa vào tab đang chọn và loại số liệu.
  // AppState.statsTabIndex xác định Weekly / Monthly.
  // AppState.statsMetricIndex xác định Score / Screen Time / Sleep.
  List<double> _getData(AppState state) {
    final isWeekly = state.statsTabIndex == 0;
    switch (state.statsMetricIndex) {
      case 1:
        return isWeekly ? _weeklyScreen : _monthlyScreen;
      case 2:
        return isWeekly ? _weeklySleep : _monthlySleep;
      default:
        return isWeekly ? _weeklyScore : _monthlyScore;
    }
  }

  // Trả về đơn vị hiển thị phụ thuộc vào loại số liệu.
  // Score dùng đơn vị điểm, Screen Time và Sleep dùng giờ.
  String _getUnit(AppState state, AppStrings strings) {
    switch (state.statsMetricIndex) {
      case 1:
        return strings.hourUnit;
      case 2:
        return strings.hourUnit;
      default:
        return strings.pointUnit;
    }
  }

  // Chọn nhãn trục dưới tùy theo Weekly hay Monthly.
  List<String> _getLabels(AppState state, AppStrings strings) {
    return state.statsTabIndex == 0 ? strings.weeklyLabels : strings.monthlyLabels;
  }

  // Chuyển chỉ số metric thành chuỗi hiển thị cho các filter chip và tiêu đề.
  String _metricLabel(AppStrings strings, int index) {
    switch (index) {
      case 1:
        return strings.screenTime;
      case 2:
        return strings.sleep;
      default:
        return strings.score;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lấy trạng thái hiện tại từ AppState.
    // Khi AppState thay đổi, widget này sẽ tự động rebuild.
    final state = context.watch<AppState>();
    final strings = state.strings;
    final data = _getData(state);
    final labels = _getLabels(state, strings);
    final unit = _getUnit(state, strings);
    // maxY được dùng để định nghĩa giới hạn trục dọc của biểu đồ.
    final maxY = data.reduce(math.max) * 1.15;

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strings.statistics, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
              strings.trackTrends,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _TabSwitcher(
              tabs: [strings.weekly, strings.monthly],
              selected: state.statsTabIndex,
              onChanged: state.setStatsTabIndex,
            ),
            const SizedBox(height: 16),
            // Thanh chọn loại dữ liệu ở phía trên: Score, Screen Time, Sleep.
            // Đây là các filter chip, khi người dùng chọn thì state thay đổi.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_metrics.length, (i) {
                  final selected = state.statsMetricIndex == i;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(_metricLabel(strings, i)),
                      selected: selected,
                      onSelected: (_) => state.setStatsMetricIndex(i),
                      selectedColor: AppColors.statsAccent.withValues(alpha: 0.15),
                      checkmarkColor: AppColors.statsAccent,
                      labelStyle: TextStyle(
                        color: selected
                            ? AppColors.statsAccent
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      side: BorderSide(
                        color: selected
                            ? AppColors.statsAccent.withValues(alpha: 0.4)
                            : AppColors.border,
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _metricLabel(strings, state.statsMetricIndex),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        '${data.last.toStringAsFixed(state.statsMetricIndex == 0 ? 0 : 1)} $unit',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.statsAccent,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 180,
                    child: LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: maxY,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: maxY / 4,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: AppColors.border,
                            strokeWidth: 1,
                          ),
                        ),
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
                                final idx = value.toInt();
                                if (idx < 0 || idx >= labels.length) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    labels[idx],
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: List.generate(
                              data.length,
                              (i) => FlSpot(i.toDouble(), data[i]),
                            ),
                            isCurved: true,
                            color: AppColors.statsAccent,
                            barWidth: 3,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, bar, index) {
                                return FlDotCirclePainter(
                                  radius: index == data.length - 1 ? 5 : 3,
                                  color: AppColors.statsAccent,
                                  strokeWidth: 2,
                                  strokeColor: Colors.white,
                                );
                              },
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppColors.statsAccent.withValues(alpha: 0.2),
                                  AppColors.statsAccent.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Phần hiển thị thống kê phụ: tiến trình hoàn thành thói quen và streak.
            Row(
              children: [
                Expanded(
                  child: SectionCard(
                    child: Column(
                      children: [
                        Text(
                          strings.habitCompletion,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 120,
                          width: 120,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 36,
                              sections: [
                                PieChartSectionData(
                                  value: state.habitsCompletionPercent.toDouble(),
                                  color: AppColors.habitsAccent,
                                  radius: 14,
                                  showTitle: false,
                                ),
                                PieChartSectionData(
                                  value: (100 - state.habitsCompletionPercent).toDouble(),
                                  color: AppColors.border,
                                  radius: 14,
                                  showTitle: false,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Text(
                          '${state.habitsCompletionPercent}%',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: AppColors.habitsAccent,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SectionCard(
                    child: Column(
                      children: [
                        // Phần hiển thị chuỗi ngày hoàn thành liên tiếp.
                        // Sử dụng vòng tròn màu vàng để nhấn mạnh số ngày streak.
                        const SizedBox(height: 16),
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.warning,
                                AppColors.warning.withValues(alpha: 0.7),
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.warning.withValues(alpha: 0.3),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('🔥', style: TextStyle(fontSize: 20)),
                                Text(
                                  '${state.streakDays}',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'day streak',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TabSwitcher extends StatelessWidget {
  const _TabSwitcher({
    required this.tabs,
    required this.selected,
    required this.onChanged,
  });

  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.border.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isSelected = selected == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  tabs[i],
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: isSelected
                            ? AppColors.statsAccent
                            : AppColors.textMuted,
                      ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
