// lib/features/dashboard/dashboard_screen.dart - FIXED VERSION

import 'package:flutter/material.dart';

import '../../core/api/dashboard_service.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/sidebar.dart';
import '../../shared/widgets/loading_skeleton.dart';
import '../../shared/widgets/charts/expiry_chart.dart';
import '../../shared/widgets/charts/obligations_pie_chart.dart';
import '../../shared/widgets/charts/progress_indicator_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DashboardService _dashboardService = DashboardService();
  
  bool _isLoading = true;
  String? _error;

  // Data
  int _documentCount = 0;
  Map<String, int> _entityStats = {};
  Map<String, int> _obligationStats = {};
  int _reminderCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final overview = await _dashboardService.getDashboardOverview();
      
      setState(() {
        _documentCount = overview['documents'] ?? 0;
        _entityStats = Map<String, int>.from(overview['entities'] ?? {});
        _obligationStats = Map<String, int>.from(overview['obligations'] ?? {});
        _reminderCount = overview['reminders'] ?? 0;
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

    if (_isLoading) return _buildSkeleton();
    if (_error != null) return _buildError();

    return Scaffold(
      // ✅ ADDED: Proper AppBar with menu button
      appBar: AppBar(
        title: const Text('Dashboard'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
            ),
            onPressed: _loadDashboard,
          ),
        ],
      ),
      drawer: AppSidebar(),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome section
              _buildWelcomeSection(isDark),
              const SizedBox(height: 24),

              _sectionLabel('QUICK STATS'),
              const SizedBox(height: 12),
              _summaryRow(isDark),
              const SizedBox(height: 28),

              _sectionLabel('ENTITY STATUS'),
              const SizedBox(height: 12),
              _entityStatusCard(isDark),
              const SizedBox(height: 24),

              ProgressIndicatorCard(
                title: 'Entities Active',
                current: _entityStats['active'] ?? 0,
                total: _entityStats['total'] ?? 0,
                color: AppColors.success,
                icon: Icons.verified_rounded,
                isDark: isDark,
              ),
              const SizedBox(height: 28),

              _sectionLabel('OBLIGATIONS'),
              const SizedBox(height: 12),
              _obligationStatusCard(isDark),
              const SizedBox(height: 24),

              ObligationsPieChart(
                obligationsByType: {
                  'pending': _obligationStats['pending'] ?? 0,
                  'overdue': _obligationStats['overdue'] ?? 0,
                  'completed': _obligationStats['completed'] ?? 0,
                },
                isDark: isDark,
              ),
              const SizedBox(height: 28),

              _sectionLabel('EXPIRY TIMELINE'),
              const SizedBox(height: 12),
              ExpiryChart(
                expiryBreakdown: {
                  '7_days': _entityStats['expiring_soon'] ?? 0,
                  '30_days': _entityStats['expiring_soon'] ?? 0,
                  '90_days': _entityStats['active'] ?? 0,
                  'beyond': _entityStats['active'] ?? 0,
                },
                isDark: isDark,
              ),
              const SizedBox(height: 28),

              _sectionLabel('DOCUMENT HEALTH'),
              const SizedBox(height: 12),
              _documentHealthCard(isDark),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF2C3E50), const Color(0xFF1A252F)]
              : [const Color(0xFF3498DB), const Color(0xFF2980B9)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : const Color(0xFF3498DB))
                .withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back! 👋',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Here\'s your document overview',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.dashboard_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _miniStat(
            'Entities',
            _entityStats['total'] ?? 0,
            Icons.layers_rounded,
            const Color(0xFF3498DB),
            isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _miniStat(
            'Pending',
            _obligationStats['pending'] ?? 0,
            Icons.pending_actions_rounded,
            const Color(0xFFF39C12),
            isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _miniStat(
            'Reminders',
            _reminderCount,
            Icons.notifications_active_rounded,
            const Color(0xFFE74C3C),
            isDark,
          ),
        ),
      ],
    );
  }

  Widget _entityStatusCard(bool isDark) {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('Active', _entityStats['active'] ?? 0, AppColors.success, Icons.check_circle_rounded),
          _row('Expiring (30d)', _entityStats['expiring_soon'] ?? 0, AppColors.warning, Icons.warning_rounded),
          _row('Expired', _entityStats['expired'] ?? 0, AppColors.error, Icons.cancel_rounded),
          _row('No expiry', _entityStats['no_expiry'] ?? 0, Colors.grey, Icons.remove_circle_outline_rounded),
        ],
      ),
      isDark,
    );
  }

  Widget _obligationStatusCard(bool isDark) {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('Pending', _obligationStats['pending'] ?? 0, const Color(0xFF6366F1), Icons.schedule_rounded),
          _row('Overdue', _obligationStats['overdue'] ?? 0, AppColors.error, Icons.error_rounded),
          _row('Due in 30 days', _obligationStats['upcoming'] ?? 0, AppColors.warning, Icons.event_rounded),
          _row('Completed', _obligationStats['completed'] ?? 0, AppColors.success, Icons.check_circle_rounded),
        ],
      ),
      isDark,
    );
  }

  Widget _documentHealthCard(bool isDark) {
    return _card(
      Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.description_rounded,
              color: AppColors.info,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_documentCount',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Total Documents',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      isDark,
    );
  }

  Widget _miniStat(String label, int value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, int value, Color c, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: c, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 15),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: c.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$value',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: c,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(Widget child, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(isDark),
      child: child,
    );
  }

  BoxDecoration _cardDecoration(bool isDark) {
    return BoxDecoration(
      color: isDark ? const Color(0xFF1A1F26) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: isDark
            ? const Color(0xFF2A3440)
            : Colors.grey.shade200,
      ),
      boxShadow: [
        BoxShadow(
          color: (isDark ? Colors.black : Colors.grey.shade300)
              .withOpacity(isDark ? 0.3 : 0.15),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _sectionLabel(String t) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      t,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: isDark ? AppColors.textSecondaryDark : Colors.grey.shade500,
        letterSpacing: 1.3,
      ),
    );
  }

  Widget _buildSkeleton() {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      drawer: AppSidebar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: List.generate(
            6,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: LoadingSkeleton(
                width: double.infinity,
                height: 120,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      drawer: AppSidebar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: AppColors.error,
              ),
              const SizedBox(height: 20),
              const Text(
                'Failed to load dashboard',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? 'Unknown error',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadDashboard,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}