// lib/core/api/reminders_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';

class RemindersService {
  final _supabase = Supabase.instance.client;

  /// Fetch all reminders for current user
  Future<List<Map<String, dynamic>>> getReminders() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('reminders')
          .select('*, obligations(title, due_date, type, life_entities(name, type, metadata))')
          .eq('user_id', userId)
          .order('remind_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to load reminders: $e');
    }
  }

  /// Get pending (unsent) reminders
  Future<List<Map<String, dynamic>>> getPendingReminders() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('reminders')
          .select('*, obligations(title, due_date, type, life_entities(name, type, metadata))')
          .eq('user_id', userId)
          .eq('sent', false)
          .gte('remind_at', DateTime.now().toIso8601String())
          .order('remind_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to load pending reminders: $e');
    }
  }

  /// Get reminders for today
  Future<List<Map<String, dynamic>>> getTodayReminders() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final response = await _supabase
          .from('reminders')
          .select('*, obligations(title, due_date, type, life_entities(name, type, metadata))')
          .eq('user_id', userId)
          .gte('remind_at', startOfDay.toIso8601String())
          .lt('remind_at', endOfDay.toIso8601String())
          .order('remind_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to load today\'s reminders: $e');
    }
  }

  /// Create reminder
  Future<Map<String, dynamic>> createReminder({
    required int obligationId,
    required DateTime remindAt,
    String? title,
    String? description,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('reminders')
          .insert({
            'user_id': userId,
            'obligation_id': obligationId,
            'title': title ?? 'Reminder',
            'description': description,
            'remind_at': remindAt.toIso8601String(),
            'sent': false,
          })
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to create reminder: $e');
    }
  }

  /// Mark reminder as sent
  Future<void> markReminderSent(int reminderId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase
          .from('reminders')
          .update({
            'sent': true,
            'sent_at': DateTime.now().toIso8601String(),
          })
          .eq('id', reminderId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to mark reminder as sent: $e');
    }
  }

  /// Delete reminder
  Future<void> deleteReminder(int reminderId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase
          .from('reminders')
          .delete()
          .eq('id', reminderId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to delete reminder: $e');
    }
  }

  /// Get reminders for specific obligation
  Future<List<Map<String, dynamic>>> getRemindersByObligation(int obligationId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('reminders')
          .select()
          .eq('user_id', userId)
          .eq('obligation_id', obligationId)
          .order('remind_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to load obligation reminders: $e');
    }
  }

  /// Get reminder count
  Future<int> getReminderCount({bool pendingOnly = false}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      var query = _supabase
          .from('reminders')
          .select('id')
          .eq('user_id', userId);

      if (pendingOnly) {
        query = query.eq('sent', false);
      }

      final response = await query;
      return response.length;
    } catch (e) {
      throw Exception('Failed to get reminder count: $e');
    }
  }
}