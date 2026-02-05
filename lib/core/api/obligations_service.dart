

import 'package:supabase_flutter/supabase_flutter.dart';

class ObligationsService {
  final _supabase = Supabase.instance.client;

  /// Fetch all obligations for current user
  Future<List<Map<String, dynamic>>> getObligations() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('obligations')
          .select('*, life_entities(name, type, metadata)')
          .eq('user_id', userId)
          .order('due_date', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to load obligations: $e');
    }
  }

  /// Get pending obligations
  Future<List<Map<String, dynamic>>> getPendingObligations() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('obligations')
          .select('*, life_entities(name, type, metadata)')
          .eq('user_id', userId)
          .eq('status', 'pending')
          .order('due_date', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to load pending obligations: $e');
    }
  }

  /// Get overdue obligations
  Future<List<Map<String, dynamic>>> getOverdueObligations() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final today = DateTime.now().toIso8601String().split('T')[0];

      final response = await _supabase
          .from('obligations')
          .select('*, life_entities(name, type, metadata)')
          .eq('user_id', userId)
          .eq('status', 'pending')
          .lt('due_date', today)
          .order('due_date', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to load overdue obligations: $e');
    }
  }

  /// Get obligations due in next N days
  Future<List<Map<String, dynamic>>> getUpcomingObligations({int days = 30}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final today = DateTime.now();
      final futureDate = today.add(Duration(days: days));
      
      final todayStr = today.toIso8601String().split('T')[0];
      final futureDateStr = futureDate.toIso8601String().split('T')[0];

      final response = await _supabase
          .from('obligations')
          .select('*, life_entities(name, type, metadata)')
          .eq('user_id', userId)
          .eq('status', 'pending')
          .gte('due_date', todayStr)
          .lte('due_date', futureDateStr)
          .order('due_date', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to load upcoming obligations: $e');
    }
  }

  /// Complete an obligation
  Future<void> completeObligation(int obligationId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase
          .from('obligations')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', obligationId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to complete obligation: $e');
    }
  }

  /// Create new obligation
  Future<Map<String, dynamic>> createObligation({
    required String title,
    required String type,
    required String dueDate,
    int? entityId,
    double? amount,
    String? currency,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('obligations')
          .insert({
            'user_id': userId,
            'title': title,
            'type': type,
            'due_date': dueDate,
            'entity_id': entityId,
            'amount': amount,
            'currency': currency ?? 'INR',
            'status': 'pending',
            'metadata': metadata ?? {},
          })
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to create obligation: $e');
    }
  }

  /// Update obligation
  Future<void> updateObligation(int obligationId, Map<String, dynamic> updates) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase
          .from('obligations')
          .update(updates)
          .eq('id', obligationId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to update obligation: $e');
    }
  }

  /// Delete obligation
  Future<void> deleteObligation(int obligationId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase
          .from('obligations')
          .delete()
          .eq('id', obligationId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to delete obligation: $e');
    }
  }

  /// Get obligations by entity
  Future<List<Map<String, dynamic>>> getObligationsByEntity(int entityId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('obligations')
          .select()
          .eq('user_id', userId)
          .eq('entity_id', entityId)
          .order('due_date', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to load entity obligations: $e');
    }
  }

  /// Get obligation statistics
  Future<Map<String, int>> getObligationStats() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final all = await getObligations();
      final pending = await getPendingObligations();
      final overdue = await getOverdueObligations();
      final upcoming = await getUpcomingObligations(days: 7);

      return {
        'total': all.length,
        'pending': pending.length,
        'overdue': overdue.length,
        'upcoming': upcoming.length,
        'completed': all.where((o) => o['status'] == 'completed').length,
      };
    } catch (e) {
      throw Exception('Failed to load obligation stats: $e');
    }
  }
}