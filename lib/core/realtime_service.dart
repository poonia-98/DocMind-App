// lib/core/realtime/realtime_service.dart
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class RealtimeService {
  final _supabase = Supabase.instance.client;
  final _subscriptions = <String, RealtimeChannel>{};

  // Stream controllers for real-time events
  final _documentStatusController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _obligationController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _reminderController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _chatMessageController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Public streams
  Stream<Map<String, dynamic>> get documentStatusStream =>
      _documentStatusController.stream;
  Stream<Map<String, dynamic>> get obligationStream =>
      _obligationController.stream;
  Stream<Map<String, dynamic>> get reminderStream => _reminderController.stream;
  Stream<Map<String, dynamic>> get chatMessageStream =>
      _chatMessageController.stream;

  /// Subscribe to document status changes
  /// Listens for: processing -> ready, or failed
  void subscribeToDocumentChanges() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final channel = _supabase
        .channel('documents_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'documents',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final data = payload.newRecord;

            // Only emit if status changed
            if (data['status'] == 'ready' || data['status'] == 'failed') {
              _documentStatusController.add({
                'document_id': data['id'],
                'title': data['title'],
                'status': data['status'],
                'processed': data['processed'],
                'timestamp': DateTime.now().toIso8601String(),
              });
            }
          },
        )
        .subscribe();

    _subscriptions['documents'] = channel;
  }

  /// Subscribe to new obligations
  void subscribeToObligations() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final channel = _supabase
        .channel('obligations_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'obligations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final data = payload.newRecord;
            _obligationController.add({
              'obligation_id': data['id'],
              'title': data['title'],
              'type': data['type'],
              'due_date': data['due_date'],
              'status': data['status'],
              'timestamp': DateTime.now().toIso8601String(),
            });
          },
        )
        .subscribe();

    _subscriptions['obligations'] = channel;
  }

  /// Subscribe to reminders
  void subscribeToReminders() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final channel = _supabase
        .channel('reminders_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'reminders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final data = payload.newRecord;

            // Only emit if reminder is due soon (within 1 hour)
            final remindAt = DateTime.parse(data['remind_at']);
            final now = DateTime.now();

            if (remindAt.difference(now).inHours <= 1) {
              _reminderController.add({
                'reminder_id': data['id'],
                'title': data['title'],
                'description': data['description'],
                'remind_at': data['remind_at'],
                'timestamp': DateTime.now().toIso8601String(),
              });
            }
          },
        )
        .subscribe();

    _subscriptions['reminders'] = channel;
  }

  /// Subscribe to chat messages (for collaborative features)
  void subscribeToChatMessages(String sessionId) {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final channel = _supabase
        .channel('chat_$sessionId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_history',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'session_id',
            value: sessionId,
          ),
          callback: (payload) {
            final data = payload.newRecord;
            _chatMessageController.add({
              'message_id': data['id'],
              'session_id': data['session_id'],
              'role': data['role'],
              'content': data['content'],
              'created_at': data['created_at'],
            });
          },
        )
        .subscribe();

    _subscriptions['chat_$sessionId'] = channel;
  }

  /// Subscribe to jobs (for upload progress tracking)
  void subscribeToJobs() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final channel = _supabase
        .channel('jobs_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'jobs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final data = payload.newRecord;

            // Emit job status changes
            if (data['status'] == 'completed' || data['status'] == 'failed') {
              _documentStatusController.add({
                'job_id': data['id'],
                'document_id': data['document_id'],
                'status': data['status'],
                'error': data['error'],
                'timestamp': DateTime.now().toIso8601String(),
              });
            }
          },
        )
        .subscribe();

    _subscriptions['jobs'] = channel;
  }

  /// Initialize all subscriptions
  void initializeAllSubscriptions() {
    subscribeToDocumentChanges();
    subscribeToObligations();
    subscribeToReminders();
    subscribeToJobs();
  }

  /// Unsubscribe from a specific channel
  void unsubscribe(String channelName) {
    final channel = _subscriptions[channelName];
    if (channel != null) {
      _supabase.removeChannel(channel);
      _subscriptions.remove(channelName);
    }
  }

  /// Unsubscribe from all channels
  void unsubscribeAll() {
    for (var channel in _subscriptions.values) {
      _supabase.removeChannel(channel);
    }
    _subscriptions.clear();
  }

  /// Dispose (call when user logs out)
  void dispose() {
    unsubscribeAll();
    _documentStatusController.close();
    _obligationController.close();
    _reminderController.close();
    _chatMessageController.close();
  }
}
