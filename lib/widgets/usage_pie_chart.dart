import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/app_usage.dart';

class UsagePieChart extends StatefulWidget {
  final List<AppUsage> usages;
  final Duration totalTime;

  const UsagePieChart({
    super.key,
    required this.usages,
    required this.totalTime,
  });

  @override
  State<UsagePieChart> createState() => _UsagePieChartState();
}

class _UsagePieChartState extends State<UsagePieChart> {
  int? _touchedIndex;

  // Màu sắc cho biểu đồ
  static const List<Color> _colors = [
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFFF44336),
    Color(0xFF009688),
    Color(0xFF795548),
    Color(0xFF607D8B),
    Color(0xFFE91E63),
    Color(0xFF00BCD4),
  ];

  @override
  Widget build(BuildContext context) {
    // Chỉ lấy top 5 app
    final topUsages = widget.usages.take(5).toList();
    final otherTime = widget.usages.skip(5).fold(
      Duration.zero,
      (sum, usage) => sum + usage.totalTime,
    );

    // Thêm phần "Khác" nếu có
    final displayUsages = List<AppUsage>.from(topUsages);
    if (otherTime > Duration.zero) {
      displayUsages.add(AppUsage(
        packageName: 'other',
        appName: 'Khác',
        totalTime: otherTime,
      ));
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            pieTouchData: PieTouchData(
              touchCallback: (FlTouchEvent event, pieTouchResponse) {
                setState(() {
                  if (!event.isInterestedForInteractions ||
                      pieTouchResponse == null ||
                      pieTouchResponse.touchedSection == null) {
                    _touchedIndex = -1;
                    return;
                  }
                  _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                });
              },
            ),
            borderData: FlBorderData(show: false),
            sectionsSpace: 2,
            centerSpaceRadius: 60,
            sections: _buildSections(displayUsages),
          ),
        ),
        // Hiển thị tổng thời gian ở giữa
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatDuration(widget.totalTime),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Tổng thời gian',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<PieChartSectionData> _buildSections(List<AppUsage> usages) {
    final total = widget.totalTime.inSeconds;
    if (total == 0) return [];

    return usages.asMap().entries.map((entry) {
      final index = entry.key;
      final usage = entry.value;
      final percentage = (usage.totalTime.inSeconds / total) * 100;
      final isTouched = _touchedIndex == index;

      return PieChartSectionData(
        color: _colors[index % _colors.length],
        value: percentage,
        title: _touchedIndex == index ? usage.appName : '',
        radius: isTouched ? 120 : 100,
        titleStyle: TextStyle(
          fontSize: isTouched ? 14 : 0,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        badgeWidget: isTouched ? _buildDetailPopup(usage) : null,
        badgePositionPercentageOffset: 1.2,
      );
    }).toList();
  }

  Widget _buildDetailPopup(AppUsage usage) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      width: 200,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                usage.appName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(usage.totalTime.inSeconds / widget.totalTime.inSeconds * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DetailRow(
            icon: Icons.timer,
            label: 'Thời gian sử dụng',
            value: usage.formattedTime,
          )
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '$hours giờ $minutes phút';
    }
    return '$minutes phút';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}