// lib/features/dashboard/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:docmind_app/features/dashboard/dashboard_service.dart';
import 'package:docmind_app/core/realtime_service.dart';
import 'package:docmind_app/shared/widgets/charts/obligations_pie_chart.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/text_styles.dart';
import '../../shared/widgets/premium_card.dart';
import '../../shared/widgets/loading_skeleton.dart';
import '../../shared/widgets/alert_banner.dart';
import '../../shared/widgets/charts/progress_indicator_card.dart';
import '../../shared/widgets/charts/expiry_chart.dart';
import '../life/entities_screen.dart';
import '../life/obligations_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DashboardService _dashboardService = DashboardService();
  final RealtimeService _realtimeService = RealtimeService();
  
  Map<String, dynamic>? _dashboardData;
  List<Map<String, dynamic>> _alerts = [];
  Map<String, int> _expiryBreakdown = {};
  bool _isLoading = true;
  StreamSubscription? _documentSubscription;
  StreamSubscription? _obligationSubscription;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _setupRealtimeSubscriptions();
  }

  @override
  void dispose() {
    _documentSubscription?.cancel();
    _obligationSubscription?.cancel();
    super.dispose();
  }

  void _setupRealtimeSubscriptions() {
    // Subscribe to document changes
    _realtimeService.subscribeToDocumentChanges();
    _documentSubscription = _realtimeService.documentStatusStream.listen((_) {
      _loadDashboardData(); // Refresh on change
    });

    // Subscribe to obligation changes
    _realtimeService.subscribeToObligations();
    _obligationSubscription = _realtimeService.obligationStream.listen((data) {
      _loadDashboardData();
      
      // Show alert for new obligation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('New obligation: ${data['title']}'),
            backgroundColor: AppColors.info,
            action: SnackBarAction(
              label: 'VIEW',
              textColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ObligationsScreen(),
                  ),
                );
              },
            ),
          ),
        );
      }
    });
  }

  Future<void> _loadDashboardData() async {
    try {
      setState(() => _isLoading = true);

      final data = await _dashboardService.getDashboardOverview();
      final breakdown = await _dashboardService.getExpiryBreakdown();
      final upcoming = await _dashboardService.getUpcomingObligations(daysAhead: 30);

      // Generate alerts
      final alerts = <Map<String, dynamic>>[];
      
      // Overdue obligations
      final overdue = data['obligations']['overdue'] as int? ?? 0;
      if (overdue > 0) {
        alerts.add({
          'type': 'error',
          'title': '🚨 $overdue Overdue Obligations',
          'message': 'You have overdue items that need immediate attention',
          'action': 'obligations',
        });
      }

      // Expiring soon (7 days)
      final expiringSoon = data['obligations']['expiringSoon'] as int? ?? 0;
      if (expiringSoon > 0) {
        alerts.add({
          'type': 'warning',
          'title': '⚠️ $expiringSoon Items Expiring Soon',
          'message': 'Expiring in the next 7 days',
          'action': 'obligations',
        });
      }

      // Processing documents
      final processing = data['documents']['processing'] as int? ?? 0;
      if (processing > 0) {
        alerts.add({
          'type': 'info',
          'title': '⏳ $processing Documents Processing',
          'message': 'Your documents are being extracted',
          'action': 'documents',
        });
      }

      setState(() {
        _dashboardData = data;
        _expiryBreakdown = breakdown;
        _alerts = alerts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load dashboard: $e'),
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
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: _isLoading
          ? _buildSkeleton()
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome header
                    Text(
                      'Enterprise Overview',
                      style: AppTextStyles.h2.copyWith(
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Last updated: ${_formatTimestamp(_dashboardData?['timestamp'])}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Alerts
                    if (_alerts.isNotEmpty) ...[
                      AlertBannerList(
                        alerts: _alerts,
                        onAlertTap: (index) => _handleAlertTap(_alerts[index]),
                        onAlertDismiss: (index) {
                          setState(() {
                            _alerts.removeAt(index);
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Stats Grid
                    _buildStatsGrid(isDark),
                    const SizedBox(height: 24),

                    // Progress Indicators
                    _buildProgressSection(isDark),
                    const SizedBox(height: 32),

                    // Charts
                    ExpiryChart(
                      expiryBreakdown: _expiryBreakdown,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 32),

                    ObligationsPieChart(
                      obligationsByType: _getObligationsByType(),
                      isDark: isDark,
                    ),
                    const SizedBox(height: 32),

                    // Recent Activity
                    _buildRecentActivity(isDark),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsGrid(bool isDark) {
    final docs = _dashboardData?['documents'] ?? {};
    final obligations = _dashboardData?['obligations'] ?? {};

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Total Documents',
                value: (docs['total'] ?? 0).toString(),
                icon: Icons.folder_outlined,
                color: AppColors.accent,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _StatCard(
                title: 'Pending Items',
                value: (obligations['pending'] ?? 0).toString(),
                icon: Icons.pending_outlined,
                color: AppColors.warning,
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Expiring Soon',
                value: (obligations['expiringSoon'] ?? 0).toString(),
                icon: Icons.schedule_outlined,
                color: AppColors.info,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _StatCard(
                title: 'Overdue',
                value: (obligations['overdue'] ?? 0).toString(),
                icon: Icons.error_outline,
                color: AppColors.error,
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressSection(bool isDark) {
    final docs = _dashboardData?['documents'] ?? {};
    final obligations = _dashboardData?['obligations'] ?? {};

    return Column(
      children: [
        ProgressIndicatorCard(
          title: 'Document Processing',
          current: docs['ready'] ?? 0,
          total: docs['total'] ?? 0,
          color: AppColors.accent,
          icon: Icons.description_outlined,
          isDark: isDark,
        ),
        const SizedBox(height: 16),
        CircularProgressCard(
          title: 'Obligations Completed',
          subtitle: 'Track your progress',
          current: obligations['completed'] ?? 0,
          total: obligations['total'] ?? 0,
          color: AppColors.success,
          icon: Icons.check_circle_outline,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildRecentActivity(bool isDark) {
    final activities = _dashboardData?['recentActivity'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: AppTextStyles.h3.copyWith(
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        if (activities.isEmpty)
          PremiumCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No recent activity',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          )
        else
          ...activities.take(10).map((activity) => _ActivityItem(
                title: activity['title'] ?? '',
                subtitle: activity['subtitle'] ?? '',
                timestamp: activity['timestamp'] ?? '',
                icon: _getActivityIcon(activity['type']),
                isDark: isDark,
              )),
      ],
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const LoadingSkeleton(width: 200, height: 32),
        const SizedBox(height: 24),
        Row(
          children: const [
            Expanded(child: LoadingSkeleton(width: double.infinity, height: 120)),
            SizedBox(width: 16),
            Expanded(child: LoadingSkeleton(width: double.infinity, height: 120)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: const [
            Expanded(child: LoadingSkeleton(width: double.infinity, height: 120)),
            SizedBox(width: 16),
            Expanded(child: LoadingSkeleton(width: double.infinity, height: 120)),
          ],
        ),
      ],
    );
  }

  IconData _getActivityIcon(String? type) {
    switch (type) {
      case 'document':
        return Icons.description_outlined;
      case 'obligation':
        return Icons.assignment_outlined;
      case 'life_entity':
        return Icons.health_and_safety_outlined;
      case 'vault':
        return Icons.lock_outlined;
      default:
        return Icons.circle;
    }
  }

  Map<String, int> _getObligationsByType() {
    // This should come from backend, but for now use sample data
    return {
      'renewal': 5,
      'payment': 8,
      'expiry': 3,
      'deadline': 2,
    };
  }

  void _handleAlertTap(Map<String, dynamic> alert) {
    final action = alert['action'] as String?;
    if (action == 'obligations') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ObligationsScreen()),
      );
    } else if (action == 'entities') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const EntitiesScreen()),
      );
    }
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'Just now';
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (e) {
      return 'Just now';
    }
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTextStyles.h1.copyWith(
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AppTextStyles.bodySmall.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String timestamp;
  final IconData icon;
  final bool isDark;

  const _ActivityItem({
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.accent),
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
                const SizedBox(height: 4),
                Text(subtitle, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          Text(
            _formatTime(timestamp),
            style: AppTextStyles.caption.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      return '${diff.inDays}d';
    } catch (e) {
      return '';
    }
  }
}