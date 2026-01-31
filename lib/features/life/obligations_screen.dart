import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/text_styles.dart';
import '../../shared/widgets/premium_card.dart';
import '../../shared/widgets/loading_skeleton.dart';

import 'package:supabase_flutter/supabase_flutter.dart';


class ObligationsScreen extends StatefulWidget {

  
  const ObligationsScreen({super.key});

  @override
  State<ObligationsScreen> createState() => _ObligationsScreenState();
}

class _ObligationsScreenState extends State<ObligationsScreen> {

  void _viewObligationDetails(Map<String, dynamic> obligation) {}

  final ApiClient _apiClient = ApiClient();
  
  List<Map<String, dynamic>> _obligations = [];
  bool _isLoading = true;
  bool _showBehaviorInsight = false;

  @override
  void initState() {
    super.initState();
    _loadObligations();
  }

  Future<void> _loadObligations() async {
  try {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final data = await Supabase.instance.client
        .from('obligations')
        .select('*, life_entities(name)')
        .eq('user_id', user.id)
        .order('due_date', ascending: true);

    setState(() {
      _obligations = List<Map<String, dynamic>>.from(data);
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
        title: const Text('Obligations'),
      ),
      body: _isLoading
          ? _buildSkeleton()
          : Column(
              children: [
                // Behavioral insight banner
                  _buildBehaviorInsight(),

                // Obligations list
                Expanded(
                  child: _obligations.isEmpty
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
                                onComplete: () =>
                                    _completeObligation(obligation),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildBehaviorInsight() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline,
                  color: Colors.amber.shade700, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Behavioral Insight',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 20),
                onPressed: () {
                  setState(() {
                    _showBehaviorInsight = false;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'You tend to complete obligations close to deadlines. I\'ve moved your reminders 2 weeks earlier to help you stay ahead.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: () {
                  // TODO: Revert adaptation
                },
                child: const Text('Revert to default timing'),
              ),
              const Spacer(),
              
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 64,
            color:
                isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No obligations',
            style: TextStyle(
              fontSize: 18,
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

  

  Future<void> _completeObligation(Map<String, dynamic> obligation) async {
    try {
      final userId = await _getCurrentUserId();

      // Calculate if completed on time
      final dueDate = DateTime.parse(obligation['due_date']);
      final now = DateTime.now();
      final isOnTime = now.isBefore(dueDate) || now.isAtSameMomentAs(dueDate);
      final delayDays = isOnTime ? 0 : now.difference(dueDate).inDays;

      // Track completion
      

      // Update obligation status
      final supabase = Supabase.instance.client;

await supabase
    .from('obligations')
    .update({
      'status': 'completed',
      'completed_at': DateTime.now().toIso8601String(),
    })
    .eq('id', obligation['id']);


      // Reload
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
          const SnackBar(content: Text('Failed to complete obligation')),
        );
      }
    }
  }
}

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final title = obligation['title'] ?? 'Untitled';
    final description = obligation['description'] ?? '';
    final dueDate = obligation['due_date'];
    final status = obligation['status'] ?? 'pending';
    final type = obligation['type'] ?? 'other';
    final amount = obligation['amount'];

    final priority = _calculatePriority(dueDate, amount);
    final priorityColor = _getPriorityColor(priority);
    final isOverdue = _isOverdue(dueDate);

    return PremiumCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: priorityColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: AppTextStyles.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: priorityColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      priority.toUpperCase(),
                      style: AppTextStyles.caption.copyWith(
                        color: priorityColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (amount != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '₹${amount.toStringAsFixed(0)}',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (dueDate != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  isOverdue ? Icons.error_outline : Icons.schedule,
                  size: 16,
                  color: isOverdue
                      ? AppColors.error
                      : (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary),
                ),
                const SizedBox(width: 8),
                Text(
                  isOverdue
                      ? 'Overdue: ${_formatDate(dueDate!)}'
                      : 'Due: ${_formatDate(dueDate!)}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isOverdue ? AppColors.error : null,
                  ),
                ),
                const Spacer(),
                Text(
                  _getRelativeDueDate(dueDate),
                  style: AppTextStyles.caption.copyWith(
                    color: isOverdue ? AppColors.error : priorityColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],

          // Action button
          if (status == 'pending') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onComplete,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Mark Complete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: priorityColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _calculatePriority(String? dueDate, dynamic amount) {
    if (dueDate == null) return 'low';

    try {
      final due = DateTime.parse(dueDate);
      final now = DateTime.now();
      final daysUntil = due.difference(now).inDays;

      if (daysUntil < 0) return 'critical'; // Overdue
      if (daysUntil <= 3) return 'high';
      if (daysUntil <= 7) return 'medium';

      // High amount = higher priority
      if (amount != null && amount > 5000) {
        return daysUntil <= 14 ? 'high' : 'medium';
      }

      return 'low';
    } catch (e) {
      return 'medium';
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return AppColors.error;
      case 'high':
        return Colors.orange;
      case 'medium':
        return AppColors.warning;
      case 'low':
        return AppColors.info;
      default:
        return AppColors.textSecondary;
    }
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
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return date;
    }
  }

  String _getRelativeDueDate(String date) {
    try {
      final due = DateTime.parse(date);
      final now = DateTime.now();
      final diff = due.difference(now).inDays;

      if (diff < 0) return '${-diff} days overdue';
      if (diff == 0) return 'Due today';
      if (diff == 1) return 'Due tomorrow';
      return 'in $diff days';
    } catch (e) {
      return '';
    }
  }
}

class _ObligationDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> obligation;

  const _ObligationDetailsSheet({
    required this.obligation,
  });

  @override
  State<_ObligationDetailsSheet> createState() =>
      _ObligationDetailsSheetState();
}

class _ObligationDetailsSheetState extends State<_ObligationDetailsSheet> {
  List<String> _consequences = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadConsequences();
  }

  Future<void> _loadConsequences() async {
  try {
    // Intelligence removed → no second order effects
    setState(() {
      _consequences = [];
      _loading = false;
    });
  } catch (e) {
    setState(() {
      _loading = false;
    });
  }
}


  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                widget.obligation['title'] ?? 'Obligation Details',
                style: AppTextStyles.h1,
              ),
              const SizedBox(height: 16),

              // Details
              _buildDetailRow('Type', widget.obligation['type'] ?? 'N/A'),
              if (widget.obligation['amount'] != null)
                _buildDetailRow(
                  'Amount',
                  '₹${widget.obligation['amount'].toStringAsFixed(2)}',
                ),
              if (widget.obligation['due_date'] != null)
                _buildDetailRow(
                  'Due Date',
                  _formatDate(widget.obligation['due_date']),
                ),
              if (widget.obligation['description'] != null)
                _buildDetailRow(
                  'Description',
                  widget.obligation['description'],
                ),

              // Second-order effects
              if (!_loading && _consequences.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber,
                              color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            'If you miss this:',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._consequences.map((consequence) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.arrow_right,
                                    size: 16, color: Colors.red.shade700),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    consequence,
                                    style: AppTextStyles.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ],

              if (_loading) ...[
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String date) {
    try {
      final d = DateTime.parse(date);
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return date;
    }
  }
}