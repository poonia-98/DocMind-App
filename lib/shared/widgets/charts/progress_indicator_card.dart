
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';

class ProgressIndicatorCard extends StatelessWidget {
  final String title;
  final int current;
  final int total;
  final Color? color;
  final IconData? icon;
  final bool isDark;

  const ProgressIndicatorCard({
    super.key,
    required this.title,
    required this.current,
    required this.total,
    this.color,
    this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = total > 0 ? (current / total * 100).toInt() : 0;
    final progress = total > 0 ? current / total : 0.0;
    final displayColor = color ?? AppColors.accent;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: displayColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: displayColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.h3.copyWith(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '$percentage%',
                style: AppTextStyles.h2.copyWith(
                  color: displayColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor:
                  isDark ? AppColors.dividerDark : AppColors.divider,
              valueColor: AlwaysStoppedAnimation<Color>(displayColor),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$current of $total',
                style: AppTextStyles.bodySmall.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
              ),
              if (total - current > 0)
                Text(
                  '${total - current} remaining',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Circular progress indicator for compact displays
class CircularProgressCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final int current;
  final int total;
  final Color? color;
  final IconData? icon;
  final bool isDark;

  const CircularProgressCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.current,
    required this.total,
    this.color,
    this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = total > 0 ? (current / total * 100).toInt() : 0;
    final progress = total > 0 ? current / total : 0.0;
    final displayColor = color ?? AppColors.accent;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  backgroundColor:
                      isDark ? AppColors.dividerDark : AppColors.divider,
                  valueColor: AlwaysStoppedAnimation<Color>(displayColor),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) Icon(icon, color: displayColor, size: 20),
                    Text(
                      '$percentage%',
                      style: AppTextStyles.h3.copyWith(
                        color: displayColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$current / $total completed',
                  style: AppTextStyles.caption.copyWith(
                    color: displayColor,
                    fontWeight: FontWeight.w600,
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
