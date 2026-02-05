// lib/shared/widgets/charts/obligations_pie_chart.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';

class ObligationsPieChart extends StatefulWidget {
  final Map<String, int> obligationsByType;
  final bool isDark;

  const ObligationsPieChart({
    super.key,
    required this.obligationsByType,
    required this.isDark,
  });

  @override
  State<ObligationsPieChart> createState() => _ObligationsPieChartState();
}

class _ObligationsPieChartState extends State<ObligationsPieChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final data = _prepareData();
    final total = data.fold<int>(0, (sum, item) => sum + item.value);

    if (total == 0) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Obligations by Type',
          style: AppTextStyles.h3.copyWith(
            color: widget.isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: widget.isDark
                ? AppColors.cardBackgroundDark
                : AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(widget.isDark ? 0.3 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              pieTouchResponse == null ||
                              pieTouchResponse.touchedSection == null) {
                            touchedIndex = -1;
                            return;
                          }
                          touchedIndex = pieTouchResponse
                              .touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                    sectionsSpace: 2,
                    centerSpaceRadius: 50,
                    sections: data.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      final isTouched = index == touchedIndex;
                      final radius = isTouched ? 65.0 : 55.0;
                      final fontSize = isTouched ? 16.0 : 12.0;

                      return PieChartSectionData(
                        color: item.color,
                        value: item.value.toDouble(),
                        title: '${((item.value / total) * 100).toInt()}%',
                        radius: radius,
                        titleStyle: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildLegend(data, total),
            ],
          ),
        ),
      ],
    );
  }

  List<_PieData> _prepareData() {
    final colors = [
      AppColors.error,
      AppColors.warning,
      AppColors.info,
      AppColors.success,
      AppColors.accent,
      const Color(0xFF9C27B0),
      const Color(0xFF00BCD4),
    ];

    final data = <_PieData>[];
    var colorIndex = 0;

    widget.obligationsByType.forEach((type, count) {
      if (count > 0) {
        data.add(_PieData(
          label: _formatType(type),
          value: count,
          color: colors[colorIndex % colors.length],
        ));
        colorIndex++;
      }
    });

    return data;
  }

  Widget _buildLegend(List<_PieData> data, int total) {
    return Column(
      children: data.map((item) {
        final percentage = ((item.value / total) * 100).toInt();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: item.color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: widget.isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${item.value} ($percentage%)',
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: widget.isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: widget.isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.pie_chart_outline,
              size: 48,
              color: widget.isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'No obligations yet',
              style: AppTextStyles.bodyMedium.copyWith(
                color: widget.isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatType(String type) {
    return type.split('_').map((word) {
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }
}

class _PieData {
  final String label;
  final int value;
  final Color color;

  _PieData({
    required this.label,
    required this.value,
    required this.color,
  });
}
