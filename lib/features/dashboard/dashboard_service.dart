// lib/core/api/dashboard_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardService {
  final _supabase = Supabase.instance.client;

  /// Get comprehensive dashboard overview
  /// Returns real-time stats for documents, obligations, entities, reminders
  Future<Map<String, dynamic>> getDashboardOverview() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Run queries in parallel for speed
      final results = await Future.wait([
        _getDocumentStats(),
        _getObligationStats(),
        _getEntityStats(),
        _getReminderStats(),
        _getRecentActivity(),
      ]);

      return {
        'documents': results[0],
        'obligations': results[1],
        'entities': results[2],
        'reminders': results[3],
        'recentActivity': results[4],
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      throw Exception('Failed to load dashboard: $e');
    }
  }

  /// Document statistics
  Future<Map<String, dynamic>> _getDocumentStats() async {
    final userId = _supabase.auth.currentUser!.id;

    // Total documents
    final totalDocs = await _supabase
        .from('documents')
        .select('id',)
        .eq('user_id', userId)
        .eq('is_deleted', false);

    // Processing documents
    final processing = await _supabase
        .from('documents')
        .select('id', )
        .eq('user_id', userId)
        .eq('status', 'processing')
        .eq('is_deleted', false);

    // Ready documents
    final ready = await _supabase
        .from('documents')
        .select('id', )
        .eq('user_id', userId)
        .eq('status', 'ready')
        .eq('is_deleted', false);

    // Vault documents
    final vault = await _supabase
        .from('documents')
        .select('id', )
        .eq('user_id', userId)
        .eq('is_vault', true)
        .eq('is_deleted', false);

    return {
      'total': (totalDocs as List).length,
      'processing': (processing as List).length,
      'ready': (ready as List).length,
      'vault': (vault as List).length,
      'percentProcessed': (totalDocs as List).isNotEmpty
          ? (((ready as List).length / (totalDocs as List).length) * 100).toInt()
          : 0,
    };
  }

  /// Obligation statistics
  Future<Map<String, dynamic>> _getObligationStats() async {
    final userId = _supabase.auth.currentUser!.id;
    final now = DateTime.now();

    // Total obligations
    final total = await _supabase
        .from('obligations')
        .select('id', )
        .eq('user_id', userId);

    // Pending obligations
    final pending = await _supabase
        .from('obligations')
        .select('id', )
        .eq('user_id', userId)
        .eq('status', 'pending');

    // Overdue (due_date < today AND status = pending)
    final overdue = await _supabase
        .from('obligations')
        .select('id', )
        .eq('user_id', userId)
        .eq('status', 'pending')
        .lt('due_date', now.toIso8601String().split('T')[0]);

    // Expiring soon (7 days)
    final sevenDaysLater = now.add(const Duration(days: 7));
    final expiringSoon = await _supabase
        .from('obligations')
        .select('id',)
        .eq('user_id', userId)
        .eq('status', 'pending')
        .gte('due_date', now.toIso8601String().split('T')[0])
        .lte('due_date', sevenDaysLater.toIso8601String().split('T')[0]);

    // Completed
    final completed = await _supabase
        .from('obligations')
        .select('id', )
        .eq('user_id', userId)
        .eq('status', 'completed');

    return {
      'total': (total as List).length,
      'pending': (pending as List).length,
      'overdue': (overdue as List).length,
      'expiringSoon': (expiringSoon as List).length,
      'completed': (completed as List).length
    };
  }

  /// Entity statistics
  Future<Map<String, dynamic>> _getEntityStats() async {
    final userId = _supabase.auth.currentUser!.id;

    final total = await _supabase
        .from('life_entities')
        .select('id', )
        .eq('user_id', userId);

    // Count by type
    final byType = await _supabase
        .from('life_entities')
        .select('type')
        .eq('user_id', userId);

    final typeCounts = <String, int>{};
    for (var entity in (byType as List)) {
      final type = entity['type'] as String;
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;
    }

    return {
      'total': (byType as List).length,
      'byType': typeCounts,
    };
  }

  /// Reminder statistics
  Future<Map<String, dynamic>> _getReminderStats() async {
    final userId = _supabase.auth.currentUser!.id;

    final total = await _supabase
        .from('reminders')
        .select('id', )
        .eq('user_id', userId);

    final pending = await _supabase
        .from('reminders')
        .select('id', )
        .eq('user_id', userId)
        .eq('sent', false)
        .gte('remind_at', DateTime.now().toIso8601String());

    return {
      'total': (total as List).length,
      'pending': (pending as List).length,
    };
  }

  /// Recent activity (last 10 actions)
  Future<List<Map<String, dynamic>>> _getRecentActivity() async {
    final userId = _supabase.auth.currentUser!.id;

    // Get recent documents
    final recentDocs = await _supabase
        .from('documents')
        .select('id, title, created_at')
        .eq('user_id', userId)
        .eq('is_deleted', false)
        .order('created_at', ascending: false)
        .limit(5);

    // Get recent obligations
    final recentObligations = await _supabase
        .from('obligations')
        .select('id, title, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(5);

    // Combine and sort
    final activities = <Map<String, dynamic>>[];

    for (var doc in (recentDocs as List)) {
      activities.add({
        'type': 'document',
        'title': 'Document uploaded',
        'subtitle': doc['title'],
        'timestamp': doc['created_at'],
      });
    }

    for (var obl in (recentObligations as List)) {
      activities.add({
        'type': 'obligation',
        'title': 'Obligation created',
        'subtitle': obl['title'],
        'timestamp': obl['created_at'],
      });
    }

    // Sort by timestamp descending
    activities.sort((a, b) =>
        (b['timestamp'] as String).compareTo(a['timestamp'] as String));

    return activities.take(10).toList();
  }

  /// Get upcoming obligations (for dashboard alerts)
  Future<List<Map<String, dynamic>>> getUpcomingObligations({int daysAhead = 30}) async {
    try {
      final result = await _supabase
          .rpc('get_upcoming_obligations', params: {'days_ahead': daysAhead});

      return List<Map<String, dynamic>>.from(result.data ?? []);
    } catch (e) {
      throw Exception('Failed to get upcoming obligations: $e');
    }
  }

  /// Get expiry breakdown (for charts)
  Future<Map<String, int>> getExpiryBreakdown() async {
    final userId = _supabase.auth.currentUser!.id;
    final now = DateTime.now();

    final obligations = await _supabase
        .from('obligations')
        .select('due_date')
        .eq('user_id', userId)
        .eq('status', 'pending')
        .gte('due_date', now.toIso8601String().split('T')[0]);

    final breakdown = {
      '7_days': 0,
      '30_days': 0,
      '90_days': 0,
      'beyond': 0,
    };

    for (var obl in (obligations as List)) {
      final dueDate = DateTime.parse(obl['due_date']);
      final daysUntil = dueDate.difference(now).inDays;

      if (daysUntil <= 7) {
        breakdown['7_days'] = breakdown['7_days']! + 1;
      } else if (daysUntil <= 30) {
        breakdown['30_days'] = breakdown['30_days']! + 1;
      } else if (daysUntil <= 90) {
        breakdown['90_days'] = breakdown['90_days']! + 1;
      } else {
        breakdown['beyond'] = breakdown['beyond']! + 1;
      }
    }

    return breakdown;
  }
}