import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/text_styles.dart';
import '../../shared/widgets/premium_card.dart';
import '../../shared/widgets/loading_skeleton.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;

  Map<String, dynamic>? _impactScore;
  List<Map<String, dynamic>> _recommendations = [];

  String _selectedTimeframe = 'today';

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  // =========================
  // LOAD DASHBOARD DATA
  // =========================
  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final supabase = Supabase.instance.client;

      final scoreRes = await supabase
          .from('life_impact_scores')
          .select('*')
          .eq('user_id', user.id)
          .order('calculated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      final recRes = await supabase
          .from('recommendations')
          .select('*')
          .eq('user_id', user.id)
          .eq('dismissed', false);

      setState(() {
        _impactScore = scoreRes;
        _recommendations = List<Map<String, dynamic>>.from(recRes);
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: _isLoading
          ? _buildSkeleton()
          : RefreshIndicator(
              onRefresh: _loadDashboard,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_impactScore != null) _buildImpactScoreCard(),
                    const SizedBox(height: 20),

                    _buildTimeProjectionToggle(),
                    const SizedBox(height: 20),

                    if (_recommendations.isNotEmpty) ...[
                      Text('Recommendations', style: AppTextStyles.h2),
                      const SizedBox(height: 12),
                      ..._recommendations
                          .map(_buildRecommendationCard)
                          .toList(),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  // =========================
  // IMPACT SCORE CARD
  // =========================
  Widget _buildImpactScoreCard() {
    final score = _impactScore!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final int value = (score['score'] ?? 0).toInt();
    final String risk = score['risk_level'] ?? 'medium';

    Color riskColor;
    switch (risk) {
      case 'low':
        riskColor = AppColors.success;
        break;
      case 'high':
        riskColor = Colors.orange;
        break;
      case 'critical':
        riskColor = AppColors.error;
        break;
      default:
        riskColor = AppColors.warning;
    }

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Life Stability Score', style: AppTextStyles.h2),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  risk.toUpperCase(),
                  style: AppTextStyles.caption.copyWith(
                    color: riskColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: riskColor,
                ),
              ),
              Text(
                '/100',
                style: TextStyle(
                  fontSize: 24,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: LinearProgressIndicator(
                  value: value / 100,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation(riskColor),
                ),
              ),
            ],
          ),
          if (score['summary'] != null) ...[
            const SizedBox(height: 12),
            Text(score['summary'], style: AppTextStyles.bodySmall),
          ],
        ],
      ),
    );
  }

  // =========================
  // TIME TOGGLE
  // =========================
  Widget _buildTimeProjectionToggle() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'today', label: Text('Today')),
        ButtonSegment(value: '30d', label: Text('+30 Days')),
        ButtonSegment(value: '90d', label: Text('+90 Days')),
      ],
      selected: {_selectedTimeframe},
      onSelectionChanged: (value) {
        setState(() => _selectedTimeframe = value.first);
      },
    );
  }

  // =========================
  // RECOMMENDATION CARD
  // =========================
  Widget _buildRecommendationCard(Map<String, dynamic> rec) {
    final title = rec['title'] ?? 'Recommendation';
    final reasoning = rec['reasoning'] ?? '';
    final priority = rec['priority'] ?? 'medium';

    Color priorityColor;
    switch (priority) {
      case 'high':
        priorityColor = Colors.orange;
        break;
      case 'critical':
        priorityColor = AppColors.error;
        break;
      case 'low':
        priorityColor = AppColors.info;
        break;
      default:
        priorityColor = AppColors.warning;
    }

    return PremiumCard(
      margin: const EdgeInsets.only(bottom: 12),
      color: priorityColor.withOpacity(0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline,
                  color: priorityColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  priority.toUpperCase(),
                  style: AppTextStyles.caption.copyWith(
                    color: priorityColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (reasoning.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(reasoning, style: AppTextStyles.bodySmall),
          ],
        ],
      ),
    );
  }

  // =========================
  // LOADING
  // =========================
  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 4,
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
}
