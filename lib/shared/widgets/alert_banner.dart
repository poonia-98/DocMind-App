
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/text_styles.dart';

enum AlertType {
  error,
  warning,
  info,
  success,
}

class AlertBanner extends StatelessWidget {
  final AlertType type;
  final String title;
  final String? message;
  final IconData? icon;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;
  final bool showDismiss;

  const AlertBanner({
    super.key,
    required this.type,
    required this.title,
    this.message,
    this.icon,
    this.onTap,
    this.onDismiss,
    this.showDismiss = true,
  });

  // Factory constructors for common alert types
  factory AlertBanner.error({
    required String title,
    String? message,
    VoidCallback? onTap,
    VoidCallback? onDismiss,
  }) {
    return AlertBanner(
      type: AlertType.error,
      title: title,
      message: message,
      icon: Icons.error_outline,
      onTap: onTap,
      onDismiss: onDismiss,
    );
  }

  factory AlertBanner.warning({
    required String title,
    String? message,
    VoidCallback? onTap,
    VoidCallback? onDismiss,
  }) {
    return AlertBanner(
      type: AlertType.warning,
      title: title,
      message: message,
      icon: Icons.warning_amber_outlined,
      onTap: onTap,
      onDismiss: onDismiss,
    );
  }

  factory AlertBanner.info({
    required String title,
    String? message,
    VoidCallback? onTap,
    VoidCallback? onDismiss,
  }) {
    return AlertBanner(
      type: AlertType.info,
      title: title,
      message: message,
      icon: Icons.info_outline,
      onTap: onTap,
      onDismiss: onDismiss,
    );
  }

  factory AlertBanner.success({
    required String title,
    String? message,
    VoidCallback? onTap,
    VoidCallback? onDismiss,
  }) {
    return AlertBanner(
      type: AlertType.success,
      title: title,
      message: message,
      icon: Icons.check_circle_outline,
      onTap: onTap,
      onDismiss: onDismiss,
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    final displayIcon = icon ?? _getDefaultIcon();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    displayIcon,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      if (message != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          message!,
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),

                // Dismiss button
                if (showDismiss && onDismiss != null)
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: color),
                    onPressed: onDismiss,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),

                // Arrow if tappable
                if (onTap != null && !showDismiss)
                  Icon(
                    Icons.chevron_right,
                    color: color,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getColor() {
    switch (type) {
      case AlertType.error:
        return AppColors.error;
      case AlertType.warning:
        return AppColors.warning;
      case AlertType.info:
        return AppColors.info;
      case AlertType.success:
        return AppColors.success;
    }
  }

  IconData _getDefaultIcon() {
    switch (type) {
      case AlertType.error:
        return Icons.error_outline;
      case AlertType.warning:
        return Icons.warning_amber_outlined;
      case AlertType.info:
        return Icons.info_outline;
      case AlertType.success:
        return Icons.check_circle_outline;
    }
  }
}

/// Widget to display multiple alerts in a list
class AlertBannerList extends StatelessWidget {
  final List<Map<String, dynamic>> alerts;
  final Function(int)? onAlertTap;
  final Function(int)? onAlertDismiss;

  const AlertBannerList({
    super.key,
    required this.alerts,
    this.onAlertTap,
    this.onAlertDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const SizedBox.shrink();

    return Column(
      children: alerts.asMap().entries.map((entry) {
        final index = entry.key;
        final alert = entry.value;

        return AlertBanner(
          type: _parseAlertType(alert['type'] as String?),
          title: alert['title'] as String? ?? '',
          message: alert['message'] as String?,
          onTap: onAlertTap != null ? () => onAlertTap!(index) : null,
          onDismiss:
              onAlertDismiss != null ? () => onAlertDismiss!(index) : null,
        );
      }).toList(),
    );
  }

  AlertType _parseAlertType(String? type) {
    switch (type?.toLowerCase()) {
      case 'error':
        return AlertType.error;
      case 'warning':
        return AlertType.warning;
      case 'info':
        return AlertType.info;
      case 'success':
        return AlertType.success;
      default:
        return AlertType.info;
    }
  }
}
