// lib/shared/widgets/entity_detection_popup.dart
import 'package:flutter/material.dart';
import '../../core/api/entity_service.dart';
import '../theme/app_colors.dart';
import '../theme/text_styles.dart';

class EntityDetectionPopup extends StatefulWidget {
  final int documentId;
  final String documentTitle;
  final List<Map<String, dynamic>> detectedEntities;
    final String documentText; // ✅ ADD THIS

  final VoidCallback onDismiss;

  const EntityDetectionPopup({
    super.key,
    required this.documentId,
    required this.documentTitle,
    required this.detectedEntities,
    required this.onDismiss,
        required this.documentText, // ✅ ADD THIS

  });

  @override
  State<EntityDetectionPopup> createState() => _EntityDetectionPopupState();
}

class _EntityDetectionPopupState extends State<EntityDetectionPopup> {
final LifeEntitiesService _entityService = LifeEntitiesService();
  final Map<int, bool> _selectedEntities = {};
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Pre-select all entities
    for (var i = 0; i < widget.detectedEntities.length; i++) {
      _selectedEntities[i] = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline,
                    color: AppColors.success,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🎯 Entities Detected',
                        style: AppTextStyles.h3.copyWith(
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Found ${widget.detectedEntities.length} life entities',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onDismiss,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Document name
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.cardBackgroundDark.withOpacity(0.5)
                    : AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.dividerDark : AppColors.divider,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 20,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.documentTitle,
                      style: AppTextStyles.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Entity list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.detectedEntities.length,
                itemBuilder: (context, index) {
                  final entity = widget.detectedEntities[index];
                  return _EntityCard(
                    entity: entity,
                    isSelected: _selectedEntities[index] ?? false,
                    onToggle: (value) {
                      setState(() {
                        _selectedEntities[index] = value;
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isProcessing ? null : widget.onDismiss,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Skip'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _handleAddEntities,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Add to Life Entities',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
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

  Future<void> _handleAddEntities() async {
    setState(() => _isProcessing = true);

    try {
      int addedCount = 0;

      for (var i = 0; i < widget.detectedEntities.length; i++) {
        if (_selectedEntities[i] == true) {
          final entity = widget.detectedEntities[i];

          // Create entity
          final extractedData =
    entity['extracted_data'] as Map<String, dynamic>? ?? {};

final rawText = (extractedData['full_text'] ??
        extractedData['raw_text'] ??
        extractedData['text'])
    ?.toString();

if (rawText == null || rawText.trim().isEmpty) {
  // OCR hi nahi mila → entity create mat kar
  continue;
}

final createdEntity = await _entityService.createEntity(
  name: entity['name'] as String,
  type: entity['type'] as String,
  rawText: widget.documentText,// ✅ ACTUAL OCR TEXT
);


          // Link to document
          await _entityService.linkDocumentToEntity(
            documentId: widget.documentId,
            entityId: createdEntity['id'] as int,
            confidence: entity['confidence'] as double?,
            extractedData: entity['extracted_data'] as Map<String, dynamic>?,
          );

          addedCount++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Added $addedCount entities successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        widget.onDismiss();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add entities: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}

class _EntityCard extends StatelessWidget {
  final Map<String, dynamic> entity;
  final bool isSelected;
  final ValueChanged<bool> onToggle;

  const _EntityCard({
    required this.entity,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final type = entity['type'] as String? ?? 'other';
    final confidence = entity['confidence'] as double? ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? AppColors.success
              : (isDark ? AppColors.dividerDark : AppColors.divider),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (value) => onToggle(value ?? false),
        activeColor: AppColors.success,
        title: Row(
          children: [
            Icon(_getTypeIcon(type), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                entity['name'] as String? ?? 'Unknown',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              _formatType(type),
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getConfidenceColor(confidence).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${(confidence * 100).toInt()}% confidence',
                    style: AppTextStyles.caption.copyWith(
                      color: _getConfidenceColor(confidence),
                      fontWeight: FontWeight.w600,
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

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'insurance_policy':
        return Icons.health_and_safety_outlined;
      case 'financial_account':
        return Icons.account_balance_outlined;
      case 'vehicle':
        return Icons.directions_car_outlined;
      case 'property':
        return Icons.home_outlined;
      case 'license':
        return Icons.badge_outlined;
      case 'contract':
        return Icons.description_outlined;
      case 'subscription':
        return Icons.repeat;
      default:
        return Icons.folder_special_outlined;
    }
  }

  String _formatType(String type) {
    return type.replaceAll('_', ' ').split(' ').map((word) {
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return AppColors.success;
    if (confidence >= 0.5) return AppColors.warning;
    return AppColors.error;
  }
}
