// lib/features/life/entities_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api/entity_service.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/text_styles.dart';
import '../../shared/theme/depth_icon_colors.dart';
import '../../shared/widgets/premium_card.dart';
import '../../shared/widgets/loading_skeleton.dart';
import '../../shared/widgets/depth_icon.dart';

import 'obligations_screen.dart';
import 'reminders_screen.dart';

class EntitiesScreen extends StatefulWidget {
  const EntitiesScreen({super.key});

  @override
  State<EntitiesScreen> createState() => _EntitiesScreenState();
}

class _EntitiesScreenState extends State<EntitiesScreen> {
  final LifeEntitiesService _entitiesService = LifeEntitiesService();

  List<Map<String, dynamic>> _entities = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEntities();
  }

  // =========================
  // DATA LOADING - NOW READS FROM entity_views
  // =========================
  Future<void> _loadEntities() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // ✅ This now reads from entity_views (clean data)
      final entities = await _entitiesService.getEntities();
      setState(() {
        _entities = entities;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // =========================
  // ADD ENTITY FLOW
  // =========================
  void _openAddEntityFlow() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Upload Document'),
              subtitle: const Text('AI will detect entities'),
              onTap: () {
                Navigator.pop(context);
                _showInfo(
                  'Document upload flow already exists.\n'
                  'Entities will be created only after user confirmation.',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Add Manually'),
              subtitle: const Text('Create entity yourself'),
              onTap: () {
                Navigator.pop(context);
                _openManualEntityForm();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // =========================
  // MANUAL ENTITY FORM
  // =========================
  void _openManualEntityForm() {
    showDialog(
      context: context,
      builder: (_) => _ManualEntityDialog(
        onCreated: () => _loadEntities(),
      ),
    );
  }

  void _showInfo(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // =========================
  // UI
  // =========================
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
          : _error != null
              ? _buildErrorState(isDark)
              : _entities.isEmpty
                  ? _buildEmptyState(isDark)
                  : RefreshIndicator(
                      onRefresh: _loadEntities,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: _entities.length,
                        itemBuilder: (_, index) {
                          final entity = _entities[index];
                          return _EntityCard(
                            entity: entity,
                            onTap: () {
                              // TODO: Navigate to entity detail screen
                            },
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddEntityFlow,
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add, color: Colors.white),
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
          height: 120,
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
            Icons.health_and_safety_outlined,
            preset: DepthIconColors.entity,
            size: 48,
            glowOpacity: 0.35,
          ),
          const SizedBox(height: 20),
          Text(
            'No life entities yet',
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
            'Failed to load entities',
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
            onPressed: _loadEntities,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// ENTITY CARD — READS CLEAN DATA FROM entity_views
// =====================================================

class _EntityCard extends StatelessWidget {
  final Map<String, dynamic> entity;
  final VoidCallback onTap;

  const _EntityCard({
    required this.entity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ ALL FIELDS ARE ALREADY CLEAN - NO PARSING NEEDED
    final title = (entity['title'] ?? 'Document').toString();
    final identifier = (entity['identifier'] ?? '—').toString();
    final shortAddress = (entity['short_address'] ?? '—').toString();
    final validTill = entity['valid_till']?.toString() ?? '—';
    final amount = entity['amount'];
    final entityType = (entity['entity_type'] ?? 'other').toString();

    // Calculate expiry badge
    final badgeData = _calculateExpiryBadge(validTill);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Theme.of(context).cardColor,
          border: Border.all(color: badgeData.color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: badgeData.color.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TITLE ROW
            Row(
              children: [
                _getIconForType(entityType),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ID NUMBER
            if (identifier != '—')
              _buildRow(
                'ID Number',
                identifier,
                Icons.badge_outlined,
              ),

            // OFFICE/ADDRESS
            if (shortAddress != '—')
              _buildRow(
                'Office',
                shortAddress,
                Icons.location_on_outlined,
              ),

            // AMOUNT (if exists)
            if (amount != null)
              _buildRow(
                'Amount',
                '₹${_formatAmount(amount)}',
                Icons.currency_rupee,
              ),

            const SizedBox(height: 12),

            // FOOTER: Valid Till + Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Valid till: $validTill',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: badgeData.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: badgeData.color.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    badgeData.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: badgeData.color,
                      letterSpacing: 0.3,
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

  Widget _buildRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _getIconForType(String type) {
    IconData iconData;
    Color iconColor;

    switch (type.toLowerCase()) {
      case 'license':
        iconData = Icons.badge_outlined;
        iconColor = Colors.blue;
        break;
      case 'vehicle':
        iconData = Icons.directions_car_outlined;
        iconColor = Colors.orange;
        break;
      case 'insurance_policy':
        iconData = Icons.shield_outlined;
        iconColor = Colors.green;
        break;
      case 'property':
        iconData = Icons.home_outlined;
        iconColor = Colors.purple;
        break;
      case 'financial_account':
        iconData = Icons.account_balance_outlined;
        iconColor = Colors.teal;
        break;
      default:
        iconData = Icons.description_outlined;
        iconColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        iconData,
        size: 20,
        color: iconColor,
      ),
    );
  }

  _BadgeData _calculateExpiryBadge(String validTill) {
    if (validTill == '—' || validTill.isEmpty) {
      return _BadgeData('Active', AppColors.success);
    }

    try {
      final expiryDate = DateTime.parse(validTill);
      final now = DateTime.now();
      final daysUntil = expiryDate.difference(now).inDays;

      if (daysUntil < 0) {
        return _BadgeData('Expired', AppColors.error);
      } else if (daysUntil == 0) {
        return _BadgeData('Expires Today', AppColors.error);
      } else if (daysUntil <= 7) {
        return _BadgeData('$daysUntil days left', AppColors.error);
      } else if (daysUntil <= 30) {
        return _BadgeData('$daysUntil days left', AppColors.warning);
      } else {
        return _BadgeData('Active', AppColors.success);
      }
    } catch (e) {
      return _BadgeData('Active', AppColors.success);
    }
  }

  String _formatAmount(dynamic amount) {
    try {
      final num = double.parse(amount.toString());
      if (num >= 100000) {
        return '${(num / 100000).toStringAsFixed(2)}L';
      } else if (num >= 1000) {
        return '${(num / 1000).toStringAsFixed(2)}K';
      } else {
        return num.toStringAsFixed(2);
      }
    } catch (e) {
      return amount.toString();
    }
  }
}

class _BadgeData {
  final String label;
  final Color color;
  _BadgeData(this.label, this.color);
}

// =====================================================
// MANUAL ENTITY DIALOG
// =====================================================
class _ManualEntityDialog extends StatefulWidget {
  final VoidCallback onCreated;

  const _ManualEntityDialog({required this.onCreated});

  @override
  State<_ManualEntityDialog> createState() => _ManualEntityDialogState();
}

class _ManualEntityDialogState extends State<_ManualEntityDialog> {
  final LifeEntitiesService _entitiesService = LifeEntitiesService();
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _identifierCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  String _selectedType = 'other';
  bool _saving = false;

  final List<Map<String, String>> _entityTypes = [
    {'value': 'license', 'label': 'License'},
    {'value': 'vehicle', 'label': 'Vehicle'},
    {'value': 'insurance_policy', 'label': 'Insurance Policy'},
    {'value': 'property', 'label': 'Property'},
    {'value': 'financial_account', 'label': 'Financial Account'},
    {'value': 'contract', 'label': 'Contract'},
    {'value': 'other', 'label': 'Other'},
  ];

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      // Create entity with clean fields that will populate entity_views
      await _entitiesService.createEntityClean(
        title: _titleCtrl.text.trim(),
        identifier: _identifierCtrl.text.trim(),
        shortAddress: _addressCtrl.text.trim(),
        validTill: _expiryCtrl.text.trim(),
        amount: _amountCtrl.text.trim().isNotEmpty 
            ? double.tryParse(_amountCtrl.text.trim())
            : null,
        entityType: _selectedType,
      );

      if (mounted) {
        widget.onCreated();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entity created successfully ✓'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create entity: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Entity Manually'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Type dropdown
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: _entityTypes.map((type) {
                  return DropdownMenuItem(
                    value: type['value'],
                    child: Text(type['label']!),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedType = value);
                  }
                },
              ),
              const SizedBox(height: 12),

              // Title
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  hintText: 'e.g., Driving License',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // Identifier
              TextFormField(
                controller: _identifierCtrl,
                decoration: const InputDecoration(
                  labelText: 'ID Number',
                  hintText: 'e.g., DL-1420110012345',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 12),

              // Address
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Office/Address',
                  hintText: 'e.g., Indira Nagar, Delhi',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 12),

              // Expiry Date
              TextFormField(
                controller: _expiryCtrl,
                decoration: const InputDecoration(
                  labelText: 'Valid Till',
                  hintText: 'YYYY-MM-DD (e.g., 2025-12-31)',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                keyboardType: TextInputType.datetime,
              ),
              const SizedBox(height: 12),

              // Amount (optional)
              TextFormField(
                controller: _amountCtrl,
                decoration: const InputDecoration(
                  labelText: 'Amount (optional)',
                  hintText: 'e.g., 50000',
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _identifierCtrl.dispose();
    _addressCtrl.dispose();
    _expiryCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }
}