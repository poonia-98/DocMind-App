
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardService {
  final _supabase = Supabase.instance.client;

  /// Get simplified dashboard overview
  Future<Map<String, dynamic>> getDashboardOverview() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final results = await Future.wait([
        getDocumentCount(),
        getEntityStats(),
        getObligationStats(),
        getReminderCount(),
      ]);

      return {
        'documents': results[0],
        'entities': results[1],
        'obligations': results[2],
        'reminders': results[3],
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      throw Exception('Failed to load dashboard: $e');
    }
  }

  /// Get document count
  Future<int> getDocumentCount() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('documents')
          .select('id')
          .eq('user_id', userId)
          .eq('is_deleted', false);

      return response.length;
    } catch (e) {
      return 0;
    }
  }

  /// Get entity statistics
  Future<Map<String, int>> getEntityStats() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final entities = await _supabase
          .from('life_entities')
          .select()
          .eq('user_id', userId);

      final now = DateTime.now();
      int active = 0;
      int expiringSoon = 0;
      int expired = 0;
      int noExpiry = 0;

      for (var entity in entities) {
        final expiryStr = entity['metadata']?['expiry_date'];
        if (expiryStr == null || expiryStr.toString().isEmpty) {
          noExpiry++;
          continue;
        }

        try {
          final expiry = DateTime.parse(expiryStr.toString());
          final daysUntil = expiry.difference(now).inDays;

          if (daysUntil < 0) {
            expired++;
          } else if (daysUntil <= 30) {
            expiringSoon++;
          } else {
            active++;
          }
        } catch (e) {
          noExpiry++;
        }
      }

      return {
        'total': entities.length,
        'active': active,
        'expiring_soon': expiringSoon,
        'expired': expired,
        'no_expiry': noExpiry,
      };
    } catch (e) {
      return {
        'total': 0,
        'active': 0,
        'expiring_soon': 0,
        'expired': 0,
        'no_expiry': 0,
      };
    }
  }

  /// Get obligation statistics
  Future<Map<String, int>> getObligationStats() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final obligations = await _supabase
          .from('obligations')
          .select()
          .eq('user_id', userId);

      final now = DateTime.now();
      final thirtyDaysLater = now.add(const Duration(days: 30));

      int pending = 0;
      int overdue = 0;
      int upcoming = 0;
      int completed = 0;

      for (var obl in obligations) {
        final status = obl['status']?.toString() ?? 'pending';
        
        if (status == 'completed') {
          completed++;
          continue;
        }

        if (status == 'pending') {
          pending++;
          
          final dueDateStr = obl['due_date'];
          if (dueDateStr != null) {
            try {
              final dueDate = DateTime.parse(dueDateStr);
              
              if (dueDate.isBefore(now)) {
                overdue++;
              } else if (dueDate.isBefore(thirtyDaysLater)) {
                upcoming++;
              }
            } catch (e) {
              // Invalid date
            }
          }
        }
      }

      return {
        'total': obligations.length,
        'pending': pending,
        'overdue': overdue,
        'upcoming': upcoming,
        'completed': completed,
      };
    } catch (e) {
      return {
        'total': 0,
        'pending': 0,
        'overdue': 0,
        'upcoming': 0,
        'completed': 0,
      };
    }
  }

  /// Get reminder count
  Future<int> getReminderCount() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('reminders')
          .select('id')
          .eq('user_id', userId);

      return response.length;
    } catch (e) {
      return 0;
    }
  }
}