// lib/features/life/entities_screen.dart
import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/text_styles.dart';
import '../../shared/widgets/premium_card.dart';
import '../../shared/widgets/loading_skeleton.dart';
import 'obligations_screen.dart';
import 'reminders_screen.dart';

class EntitiesScreen extends StatefulWidget {
  const EntitiesScreen({super.key});

  @override
  State<EntitiesScreen> createState() => _EntitiesScreenState();
}

class _EntitiesScreenState extends State<EntitiesScreen> {
  final ApiClient _apiClient = ApiClient();
  List<Map<String, dynamic>> _entities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEntities();
  }

  Future<void> _loadEntities() async {
    try {
      final response = await _apiClient.get('life-entities');
      setState(() {
        _entities = List<Map<String, dynamic>>.from(response['entities'] ?? []);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Life Entities'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RemindersScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.assignment_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ObligationsScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? _buildSkeleton()
          : _entities.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.health_and_safety_outlined,
                        size: 64,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No life entities yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadEntities,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _entities.length,
                    itemBuilder: (context, index) {
                      final entity = _entities[index];
                      return _EntityCard(
                        title: entity['name'] ?? 'Untitled',
                        type: entity['type'] ?? 'Document',
                        status: entity['status'] ?? 'active',
                        expiryDate: entity['expiryDate'],
                        onTap: () {},
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add, color: Colors.white),
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
          height: 100,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _EntityCard extends StatelessWidget {
  final String title;
  final String type;
  final String status;
  final String? expiryDate;
  final VoidCallback onTap;

  const _EntityCard({
    required this.title,
    required this.type,
    required this.status,
    this.expiryDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _getStatusColor(status);
    final isExpiring = _isExpiringSoon(expiryDate);
    
    return PremiumCard(
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
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getTypeIcon(type),
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(type, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: AppTextStyles.caption.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (expiryDate != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  isExpiring ? Icons.warning_amber : Icons.schedule,
                  size: 16,
                  color: isExpiring
                      ? AppColors.warning
                      : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
                ),
                const SizedBox(width: 8),
                Text(
                  'Expires: ${_formatDate(expiryDate!)}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isExpiring ? AppColors.warning : null,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return AppColors.success;
      case 'expiring':
        return AppColors.warning;
      case 'expired':
        return AppColors.error;
      default:
        return AppColors.info;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'insurance':
        return Icons.health_and_safety_outlined;
      case 'id':
        return Icons.badge_outlined;
      case 'financial':
        return Icons.account_balance_outlined;
      case 'legal':
        return Icons.gavel_outlined;
      default:
        return Icons.description_outlined;
    }
  }

  bool _isExpiringSoon(String? date) {
    if (date == null) return false;
    try {
      final expiryDate = DateTime.parse(date);
      final now = DateTime.now();
      final difference = expiryDate.difference(now).inDays;
      return difference <= 30 && difference > 0;
    } catch (e) {
      return false;
    }
  }

  String _formatDate(String date) {
    try {
      final dateTime = DateTime.parse(date);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return date;
    }
  }
}