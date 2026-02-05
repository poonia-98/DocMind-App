// lib/features/life/obligations_screen.dart

import 'package:flutter/material.dart';

import '../../core/api/obligations_service.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/text_styles.dart';
import '../../shared/theme/depth_icon_colors.dart';
import '../../shared/widgets/premium_card.dart';
import '../../shared/widgets/loading_skeleton.dart';
import '../../shared/widgets/depth_icon.dart';
import '../../shared/utils/entity_parser.dart';

class ObligationsScreen extends StatefulWidget {
  const ObligationsScreen({super.key});

  @override
  State<ObligationsScreen> createState() => _ObligationsScreenState();
}

class _ObligationsScreenState extends State<ObligationsScreen> {
  final ObligationsService _obligationsService = ObligationsService();

  List<Map<String, dynamic>> _obligations = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadObligations();
  }

  Future<void> _loadObligations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final obligations = await _obligationsService.getObligations();
      setState(() {
        _obligations = obligations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _viewObligationDetails(Map<String, dynamic> obligation) {
    // TODO: Navigate to obligation detail screen
  }

  Future<void> _completeObligation(Map<String, dynamic> obligation) async {
    try {
      final dueDate = DateTime.parse(obligation['due_date']);
      final now = DateTime.now();
      final isOnTime = now.isBefore(dueDate) || now.isAtSameMomentAs(dueDate);

      await _obligationsService.completeObligation(obligation['id']);
      await _loadObligations();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isOnTime
                  ? '✓ Great job! Completed on time.'
                  : '✓ Completed. Try to complete earlier next time.',
            ),
            backgroundColor: isOnTime ? AppColors.success : AppColors.warning,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete obligation: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Obligations'),
      ),
      body: _isLoading
          ? _buildSkeleton()
          : _error != null
              ? _buildErrorState(isDark)
              : _obligations.isEmpty
                  ? _buildEmptyState(isDark)
                  : RefreshIndicator(
                      onRefresh: _loadObligations,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: _obligations.length,
                        itemBuilder: (context, index) {
                          final obligation = _obligations[index];
                          return _ObligationCard(
                            obligation: obligation,
                            onTap: () => _viewObligationDetails(obligation),
                            onComplete: () => _completeObligation(obligation),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DepthIcon(
            Icons.assignment_outlined,
            preset: DepthIconColors.obligation,
            size: 48,
            glowOpacity: 0.35,
          ),
          const SizedBox(height: 20),
          Text(
            'No obligations',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Nothing due at the moment',
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 5,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: LoadingSkeleton(
          width: double.infinity,
          height: 100,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: AppColors.error,
          ),
          const SizedBox(height: 20),
          Text(
            'Failed to load obligations',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _error ?? 'Unknown error',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.error,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadObligations,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// OBLIGATION CARD — REAL DATA WIRED
// =====================================================
class _ObligationCard extends StatelessWidget {
  final Map<String, dynamic> obligation;
  final VoidCallback onTap;
  final VoidCallback onComplete;

  const _ObligationCard({
    required this.obligation,
    required this.onTap,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final entity = obligation['life_entities'];
    final rawName = (entity != null ? entity['name'] : obligation['title'] ?? '').toString();

    final parsed = EntityParser.parse(rawName);
    final dueDate = obligation['due_date'];
    final status = (obligation['status'] ?? 'pending').toString();
    final type = (obligation['type'] ?? 'other').toString();

    final isOverdue = _isOverdue(dueDate);
    final preset = DepthIconColors.forType(type);
    final iconData = _iconForType(type);
    final statusInfo = _statusInfo(status, isOverdue);

    final canComplete = status == 'pending';

    return PremiumCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon tile
          DepthIconTile(
            iconData,
            preset: preset,
            tileSize: 48,
            iconSize: 22,
          ),
          const SizedBox(width: 14),
          
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  parsed.name,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (parsed.identifier.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    parsed.identifier,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                
                // Due date row
                if (dueDate != null)
                  Row(
                    children: [
                      Icon(
                        isOverdue ? Icons.error_outline : Icons.calendar_today_outlined,
                        size: 13,
                        color: isOverdue
                            ? AppColors.error
                            : Colors.grey.shade500,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isOverdue
                            ? 'Overdue — ${_formatDate(dueDate)}'
                            : 'Due ${_formatDate(dueDate)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isOverdue
                              ? AppColors.error
                              : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          
          // Status badge
          _StatusBadge(label: statusInfo.first, color: statusInfo.second),
          
          // Complete button
          if (canComplete) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              color: AppColors.success,
              onPressed: onComplete,
              tooltip: 'Mark as complete',
            ),
          ],
        ],
      ),
    );
  }

  bool _isOverdue(String? date) {
    if (date == null) return false;
    try {
      final due = DateTime.parse(date);
      return due.isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  String _formatDate(String date) {
    try {
      final d = DateTime.parse(date);
      final months = [
        'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'
      ];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return date;
    }
  }

  _LabelColor _statusInfo(String status, bool isOverdue) {
    if (isOverdue && status == 'pending') {
      return _LabelColor('Overdue', AppColors.error);
    }
    switch (status.toLowerCase()) {
      case 'completed':
        return _LabelColor('Completed', AppColors.success);
      case 'pending':
        return _LabelColor('Pending', const Color(0xFF6366F1));
      default:
        return _LabelColor('Pending', const Color(0xFF6366F1));
    }
  }

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'expiry':
      case 'renewal':
        return Icons.refresh_outlined;
      case 'payment':
        return Icons.payment_outlined;
      case 'deadline':
        return Icons.flag_outlined;
      case 'vehicle':
        return Icons.directions_car_outlined;
      case 'insurance':
        return Icons.shield_outlined;
      case 'license':
        return Icons.badge_outlined;
      default:
        return Icons.assignment_outlined;
    }
  }
}

class _LabelColor {
  final String first;
  final Color second;
  const _LabelColor(this.first, this.second);
}

// =====================================================
// STATUS BADGE
// =====================================================
class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}