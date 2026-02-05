// lib/shared/widgets/decision_bottom_sheet.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/text_styles.dart';
import 'primary_button.dart';

class DecisionBottomSheet extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback onMoveToLifeEntities;
  final VoidCallback onSkip;
  final VoidCallback onTreatAsNormal;

  const DecisionBottomSheet({
    super.key,
    required this.title,
    required this.description,
    required this.onMoveToLifeEntities,
    required this.onSkip,
    required this.onTreatAsNormal,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required String description,
    required VoidCallback onMoveToLifeEntities,
    required VoidCallback onSkip,
    required VoidCallback onTreatAsNormal,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DecisionBottomSheet(
        title: title,
        description: description,
        onMoveToLifeEntities: onMoveToLifeEntities,
        onSkip: onSkip,
        onTreatAsNormal: onTreatAsNormal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : AppColors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.dividerDark : AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: AppTextStyles.h2.copyWith(
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                text: 'Move to Life Entities',
                icon: Icons.health_and_safety_outlined,
                onPressed: () {
                  Navigator.pop(context);
                  onMoveToLifeEntities();
                },
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                text: 'Treat as Normal Document',
                isSecondary: true,
                icon: Icons.description_outlined,
                onPressed: () {
                  Navigator.pop(context);
                  onTreatAsNormal();
                },
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onSkip();
                  },
                  child: Text(
                    'Skip for Now',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
