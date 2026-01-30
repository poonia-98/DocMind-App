import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/text_styles.dart';
import '../../shared/widgets/premium_card.dart';
import '../../shared/widgets/loading_skeleton.dart';

class ObligationsScreen extends StatefulWidget {
  const ObligationsScreen({super.key});

  @override
  State<ObligationsScreen> createState() => _ObligationsScreenState();
}

class _ObligationsScreenState extends State<ObligationsScreen> {
  final ApiClient _apiClient = ApiClient();

  List<Map<String, dynamic>> _obligations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadObligations();
  }

  Future<void> _loadObligations() async {
    try {
      final response =
          await _apiClient.get('life-entities/obligations');

      setState(() {
        _obligations =
            List<Map<String, dynamic>>.from(
              response['obligations'] ?? [],
            );
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Obligations'),
      ),
      body: _isLoading
          ? _buildSkeleton()
          : _obligations.isEmpty
              ? _buildEmptyState(isDark)
              : RefreshIndicator(
                  onRefresh: _loadObligations,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _obligations.length,
                    itemBuilder: (context, index) {
                      final obligation =
                          _obligations[index];

                      return _ObligationCard(
                        title:
                            obligation['title'] ??
                                'Untitled',
                        description:
                            obligation['description'] ??
                                '',
                        dueDate:
                            obligation['dueDate'],
                        status:
                            obligation['status'] ??
                                'pending',
                        priority:
                            obligation['priority'] ??
                                'medium',
                        onTap: () {},
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
          Icon(
            Icons.assignment_outlined,
            size: 64,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondary,
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
        padding:
            const EdgeInsets.only(bottom: 12),
        child: LoadingSkeleton(
          width: double.infinity,
          height: 100,
          borderRadius:
              BorderRadius.circular(16),
        ),
      ),
    );
  }
}

// --------------------------------------------------

class _ObligationCard extends StatelessWidget {
  final String title;
  final String description;
  final String? dueDate;
  final String status;
  final String priority;
  final VoidCallback onTap;

  const _ObligationCard({
    required this.title,
    required this.description,
    this.dueDate,
    required this.status,
    required this.priority,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness ==
            Brightness.dark;

    final priorityColor =
        _getPriorityColor(priority);
    final isOverdue = _isOverdue(dueDate);

    return PremiumCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: priorityColor,
                  borderRadius:
                      BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles
                          .bodyMedium
                          .copyWith(
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: AppTextStyles
                            .bodySmall,
                        maxLines: 2,
                        overflow:
                            TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color:
                      priorityColor.withOpacity(
                          0.1),
                  borderRadius:
                      BorderRadius.circular(6),
                ),
                child: Text(
                  priority.toUpperCase(),
                  style: AppTextStyles.caption
                      .copyWith(
                    color: priorityColor,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (dueDate != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  isOverdue
                      ? Icons.error_outline
                      : Icons.schedule,
                  size: 16,
                  color: isOverdue
                      ? AppColors.error
                      : (isDark
                          ? AppColors
                              .textSecondaryDark
                          : AppColors
                              .textSecondary),
                ),
                const SizedBox(width: 8),
                Text(
                  isOverdue
                      ? 'Overdue: ${_formatDate(dueDate!)}'
                      : 'Due: ${_formatDate(dueDate!)}',
                  style: AppTextStyles.bodySmall
                      .copyWith(
                    color: isOverdue
                        ? AppColors.error
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return AppColors.error;
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
      final due =
          DateTime.parse(date);
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
}
