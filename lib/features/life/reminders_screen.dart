import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/text_styles.dart';
import '../../shared/widgets/premium_card.dart';
import '../../shared/widgets/loading_skeleton.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final ApiClient _apiClient = ApiClient();

  List<Map<String, dynamic>> _reminders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
  try {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final data = await Supabase.instance.client
        .from('reminders')
        .select('*, obligations(title)')
        .eq('user_id', user.id)
        .order('remind_at', ascending: true);

    setState(() {
      _reminders = List<Map<String, dynamic>>.from(data);
      _isLoading = false;
    });
  } catch (e) {
    _isLoading = false;
  }
}


  Future<String> _getCurrentUserId() async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    throw Exception('User not logged in');
  }
  return user.id;
}


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
      ),
      body: _isLoading
          ? _buildSkeleton()
          : _reminders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_outlined,
                        size: 64,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No reminders',
                        style: TextStyle(
                          fontSize: 18,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadReminders,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _reminders.length,
                    itemBuilder: (context, index) {
                      final reminder = _reminders[index];
                      return _ReminderCard(
                        reminder: reminder,
                        onTap: () => _handleReminderTap(reminder),
                        onDismiss: () => _dismissReminder(reminder),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 5,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: LoadingSkeleton(
          width: double.infinity,
          height: 80,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Future<void> _handleReminderTap(Map<String, dynamic> reminder) async {
    try {
      final userId = await _getCurrentUserId();
      await (
        userId: userId,
        interactionType: 'act_on_reminder',
        resourceType: 'reminder',
        resourceId: reminder['id'],
      );
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> _dismissReminder(Map<String, dynamic> reminder) async {
    try {
      final userId = await _getCurrentUserId();
      await (
        userId: userId,
        interactionType: 'dismiss_reminder',
        resourceType: 'reminder',
        resourceId: reminder['id'],
      );

      setState(() {
        _reminders.removeWhere((r) => r['id'] == reminder['id']);
      });
    } catch (e) {
      // Silent fail
    }
  }
}

class _ReminderCard extends StatelessWidget {
  final Map<String, dynamic> reminder;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _ReminderCard({
    required this.reminder,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final title = reminder['title'] ?? 'Untitled';
    final description = reminder['description'] ?? '';
    final scheduledDate = reminder['scheduledDate'] ?? reminder['remind_at'];
    final type = reminder['type'] ?? 'general';
    final sourceRule = reminder['source_rule'];

    final typeColor = _getTypeColor(type);

    return Dismissible(
      key: Key(reminder['id'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDismiss(),
      child: PremiumCard(
        onTap: onTap,
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.notifications_active_outlined,
                    color: typeColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.bodyMedium
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: AppTextStyles.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (scheduledDate != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    _formatDate(scheduledDate!),
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ],

            // Explainability footer
            if (sourceRule != null) ...[
              const Divider(height: 24),
              Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 12, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Auto-generated: $sourceRule',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'expiry':
      case 'renewal':
        return AppColors.warning;
      case 'payment':
        return AppColors.error;
      case 'deadline':
        return Colors.orange;
      default:
        return AppColors.accent;
    }
  }

  String _formatDate(String date) {
    try {
      final dateTime = DateTime.parse(date);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return date;
    }
  }
}