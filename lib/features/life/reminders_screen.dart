// lib/features/life/reminders_screen.dart

import 'package:flutter/material.dart';

import '../../core/api/reminders_service.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/text_styles.dart';
import '../../shared/theme/depth_icon_colors.dart';
import '../../shared/widgets/premium_card.dart';
import '../../shared/widgets/loading_skeleton.dart';
import '../../shared/widgets/depth_icon.dart';
import '../../shared/utils/entity_parser.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final RemindersService _remindersService = RemindersService();

  List<Map<String, dynamic>> _reminders = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final reminders = await _remindersService.getReminders();
      setState(() {
        _reminders = reminders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: _isLoading
          ? _buildSkeleton()
          : _error != null
              ? _buildErrorState(isDark)
              : _reminders.isEmpty
                  ? _buildEmptyState(isDark)
                  : RefreshIndicator(
                      onRefresh: _loadReminders,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: _reminders.length,
                        itemBuilder: (_, i) {
                          return _ReminderCard(reminder: _reminders[i]);
                        },
                      ),
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
          height: 80,
          borderRadius: BorderRadius.circular(16),
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
            Icons.notifications_outlined,
            preset: DepthIconColors.notification,
            size: 48,
            glowOpacity: 0.35,
          ),
          const SizedBox(height: 20),
          Text(
            'No reminders',
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
            'Youre all caught up',
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
            'Failed to load reminders',
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
            onPressed: _loadReminders,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// REMINDER CARD — REAL DATA WIRED
// =====================================================
class _ReminderCard extends StatelessWidget {
  final Map<String, dynamic> reminder;

  const _ReminderCard({required this.reminder});

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'insurance':
        return Icons.shield_outlined;
      case 'vehicle':
        return Icons.directions_car_outlined;
      case 'license':
        return Icons.badge_outlined;
      default:
        return Icons.notifications_active_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final obligation = reminder['obligations'];
    
    // Extract entity name from nested obligation -> life_entities
    String rawName = 'Reminder';
    String? type;
    
    if (obligation != null) {
      final entity = obligation['life_entities'];
      if (entity != null && entity['name'] != null) {
        rawName = entity['name'].toString();
        type = entity['type']?.toString();
      } else if (obligation['title'] != null) {
        rawName = obligation['title'].toString();
      }
      type ??= obligation['type']?.toString();
    }

    final parsed = EntityParser.parse(rawName);
    final days = EntityParser.daysUntil(obligation?['due_date']);
    final badge = EntityParser.expiryBadge(days);

final preset = DepthIconColors.notification;
    final iconData = _iconForType(type ?? 'general');

    // Format reminder time
    final remindAtStr = reminder['remind_at'];
    String remindTimeText = '';
    if (remindAtStr != null) {
      try {
        final remindAt = DateTime.parse(remindAtStr);
        final now = DateTime.now();
        final diff = remindAt.difference(now);
        
        if (diff.inDays > 0) {
          remindTimeText = 'In ${diff.inDays} days';
        } else if (diff.inHours > 0) {
          remindTimeText = 'In ${diff.inHours} hours';
        } else if (diff.inMinutes > 0) {
          remindTimeText = 'In ${diff.inMinutes} minutes';
        } else if (diff.inSeconds > 0) {
          remindTimeText = 'Soon';
        } else {
          remindTimeText = 'Overdue';
        }
      } catch (e) {
        remindTimeText = 'Invalid time';
      }
    }

    return PremiumCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon
              DepthIconTile(
                iconData,
                preset: preset,
                tileSize: 48,
                iconSize: 22,
              ),

              const SizedBox(width: 14),

              // Text
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
                      const SizedBox(height: 3),
                      Text(
                        parsed.identifier,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Badge
              _ExpiryBadge(
                label: badge.label,
                color: badge.color,
              ),
            ],
          ),
          
          // Reminder time
          if (remindTimeText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 6),
                Text(
                  'Remind: $remindTimeText',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// =====================================================
// EXPIRY BADGE
// =====================================================
class _ExpiryBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _ExpiryBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}