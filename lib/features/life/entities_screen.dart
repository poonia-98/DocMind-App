import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/text_styles.dart';
import '../../shared/widgets/premium_card.dart';
import '../../shared/widgets/loading_skeleton.dart';
import 'obligations_screen.dart';
import 'reminders_screen.dart';

import 'package:supabase_flutter/supabase_flutter.dart';


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
    _trackEntityView();
  }

  Future<void> _loadEntities() async {
  try {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final data = await Supabase.instance.client
        .from('life_entities')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    setState(() {
      _entities = List<Map<String, dynamic>>.from(data);
      _isLoading = false;
    });
  } catch (e) {
    _isLoading = false;
  }
}


  Future<void> _detectDependencies() async {
  // Handled server-side by worker
}

Future<void> _trackEntityView() async {
  // Handled server-side by worker
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
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No life entities yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Upload documents or add manually',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
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
                        entity: entity,
                        onTap: () => _viewEntityDetails(entity),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
  try {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User not logged in');
    }

    // Insert entity
    final entityRes = await supabase
        .from('life_entities')
        .insert({
          'user_id': user.id,
          'name': 'Test Life Entity',
          'type': 'insurance_policy',
          'metadata': {
            'expiry_date': '2026-06-01',
            'source': 'manual_test',
          },
        })
        .select()
        .single();

    debugPrint('Life entity inserted: $entityRes');

    // Create obligation
    final dueDate = DateTime.parse('2026-06-01');
    final obligationRes = await supabase
        .from('obligations')
        .insert({
          'user_id': user.id,
          'entity_id': entityRes['id'],
          'title': 'Renew ${entityRes['name']}',
          'type': 'renewal',
          'due_date': dueDate.toIso8601String().split('T')[0],
          'status': 'pending',
        })
        .select()
        .single();

    debugPrint('Obligation created: $obligationRes');

    // Create reminders
    final remindAt14 = dueDate.subtract(const Duration(days: 14));
    final remindAt3 = dueDate.subtract(const Duration(days: 3));

    await supabase.from('reminders').insert([
      {
        'user_id': user.id,
        'obligation_id': obligationRes['id'],
        'title': '⏰ ${entityRes['name']} expires in 14 days',
        'remind_at': remindAt14.toIso8601String(),
        'type': 'expiry',
      },
      {
        'user_id': user.id,
        'obligation_id': obligationRes['id'],
        'title': '🚨 ${entityRes['name']} expires in 3 days',
        'remind_at': remindAt3.toIso8601String(),
        'type': 'expiry',
      }
    ]);

    debugPrint('Reminders created');

    // Reload the screen
    await _loadEntities();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Created entity with obligation and reminders'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    debugPrint('Life entity creation failed: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }
},

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

  Future<void> _viewEntityDetails(Map<String, dynamic> entity) async {
  // handled server-side
  // TODO: Implement entity details screen
}
}

class _EntityCard extends StatefulWidget {
  final Map<String, dynamic> entity;
  final VoidCallback onTap;

  const _EntityCard({
    required this.entity,
    required this.onTap,
  });

  @override
  State<_EntityCard> createState() => _EntityCardState();
}


class _EntityCardState extends State<_EntityCard> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final entity = widget.entity;

    final name = entity['name'] ?? 'Untitled';
    final type = entity['type'] ?? 'other';
    final metadata = entity['metadata'] ?? {};

    // Extract data
    final expiryDate = metadata['expiry_date'];
    final manuallyVerified = metadata['manually_verified'] ?? false;
    final aiConfidence = (metadata['ai_confidence'] ?? 0.0) as double;
    final lastVerified = metadata['last_verified_at'];

    // Calculate status
    final status = _calculateStatus(expiryDate);
    final statusColor = _getStatusColor(status);
    final isExpiring = _isExpiringSoon(expiryDate);

    return PremiumCard(
    onTap: widget.onTap,
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
                      name,
                      style: AppTextStyles.bodyMedium
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatType(type),
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

          // Expiry info
          if (expiryDate != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  isExpiring ? Icons.warning_amber : Icons.schedule,
                  size: 16,
                  color: isExpiring
                      ? AppColors.warning
                      : (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary),
                ),
                const SizedBox(width: 8),
                Text(
                  'Expires: ${_formatDate(expiryDate)}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isExpiring ? AppColors.warning : null,
                  ),
                ),
              ],
            ),
          ],

          // Trust & Confidence indicators
          const SizedBox(height: 12),
          Row(
            children: [
              if (manuallyVerified)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.success, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified,
                          size: 12, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(
                        'User Verified',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              if (manuallyVerified) const SizedBox(width: 8),

              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.psychology,
                      size: 14,
                      color: _getConfidenceColor(aiConfidence),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'AI: ${(aiConfidence * 100).toInt()}%',
                      style: AppTextStyles.caption.copyWith(
                        color: _getConfidenceColor(aiConfidence),
                      ),
                    ),
                  ],
                ),
              ),

              if (lastVerified != null)
                Text(
                  'Verified ${_formatRelativeDate(lastVerified)}',
                  style: AppTextStyles.caption.copyWith(
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


  String _calculateStatus(String? expiryDate) {
    if (expiryDate == null) return 'active';

    try {
      final expiry = DateTime.parse(expiryDate);
      final now = DateTime.now();
      final daysUntil = expiry.difference(now).inDays;

      if (daysUntil < 0) return 'expired';
      if (daysUntil <= 30) return 'expiring';
      return 'active';
    } catch (e) {
      return 'active';
    }
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

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return AppColors.success;
    if (confidence >= 0.6) return AppColors.warning;
    return AppColors.error;
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'insurance_policy':
        return Icons.health_and_safety_outlined;
      case 'license':
        return Icons.badge_outlined;
      case 'financial_account':
        return Icons.account_balance_outlined;
      case 'vehicle':
        return Icons.directions_car_outlined;
      case 'property':
        return Icons.home_outlined;
      case 'contract':
        return Icons.gavel_outlined;
      default:
        return Icons.description_outlined;
    }
  }

  IconData _getRelationshipIcon(String relationship) {
    switch (relationship.toLowerCase()) {
      case 'requires':
        return Icons.arrow_forward;
      case 'blocks':
        return Icons.block;
      case 'renews_with':
        return Icons.sync;
      case 'related_to':
        return Icons.link;
      default:
        return Icons.circle_outlined;
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

  String _formatRelativeDate(String date) {
    try {
      final dateTime = DateTime.parse(date);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays == 0) return 'today';
      if (difference.inDays == 1) return 'yesterday';
      if (difference.inDays < 7) return '${difference.inDays} days ago';
      if (difference.inDays < 30) return '${(difference.inDays / 7).floor()} weeks ago';
      return '${(difference.inDays / 30).floor()} months ago';
    } catch (e) {
      return '';
    }
  }

  String _formatType(String type) {
    return type
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
