// lib/core/api/chat_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ChatService {
  final _supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  /// Get full document text for AI context
  Future<String?> getDocumentText(int documentId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final doc = await _supabase
        .from('documents')
        .select('content')
        .eq('id', documentId)
        .eq('user_id', userId)
        .eq('is_deleted', false)
        .maybeSingle();

    return doc?['content'] as String?;
  }

  /// Get or create session ID for document
  /// Each document has its own persistent chat session
  String getSessionIdForDocument(int? documentId) {
    if (documentId == null) {
      // General chat (no document context)
      return 'general_${_uuid.v4()}';
    }
    return 'doc_$documentId';
  }

  /// Get chat history for a session (document or general)
  Future<List<Map<String, dynamic>>> getChatHistory(String sessionId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('chat_history')
          .select('*')
          .eq('user_id', userId)
          .eq('session_id', sessionId)
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to load chat history: $e');
    }
  }

  /// Save message to chat history
  Future<void> saveMessage({
    required String sessionId,
    required String role, // 'user' or 'assistant'
    required String content,
    int? documentId,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase.from('chat_history').insert({
        'user_id': userId,
        'session_id': sessionId,
        'document_id': documentId,
        'role': role,
        'content': content,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to save message: $e');
    }
  }

  /// Get all chat sessions (for chat list)
  Future<List<Map<String, dynamic>>> getAllSessions() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Get distinct sessions with last message
      final response = await _supabase
          .from('chat_history')
          .select('session_id, document_id, content, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final sessions = <String, Map<String, dynamic>>{};

      for (var msg in (response as List)) {
        final sessionId = msg['session_id'] as String;
        if (!sessions.containsKey(sessionId)) {
          sessions[sessionId] = {
            'session_id': sessionId,
            'document_id': msg['document_id'],
            'last_message': msg['content'],
            'last_message_at': msg['created_at'],
          };
        }
      }

      return sessions.values.toList();
    } catch (e) {
      throw Exception('Failed to load sessions: $e');
    }
  }

  /// Delete chat session
  Future<void> deleteSession(String sessionId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase
          .from('chat_history')
          .delete()
          .eq('user_id', userId)
          .eq('session_id', sessionId);
    } catch (e) {
      throw Exception('Failed to delete session: $e');
    }
  }

  /// Clear all chat history
  Future<void> clearAllHistory() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase.from('chat_history').delete().eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to clear history: $e');
    }
  }

  /// Get document info for session
  Future<Map<String, dynamic>?> getDocumentForSession(String sessionId) async {
    try {
      if (!sessionId.startsWith('doc_')) return null;

      final documentId = int.tryParse(sessionId.replaceFirst('doc_', ''));
      if (documentId == null) return null;

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('documents')
          .select('id, title, status, created_at')
          .eq('id', documentId)
          .eq('user_id', userId)
          .eq('is_deleted', false)
          .maybeSingle();

      return response as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  /// Search relevant document sections for RAG (Retrieval Augmented Generation)
  Future<List<Map<String, dynamic>>> searchDocumentSections({
    required String query,
    int? documentId,
    int limit = 5,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final List data = await _supabase
          .from('document_sections')
          .select('id, document_id, content, section_order')
          .eq('user_id', userId)
          .eq(
            documentId != null ? 'document_id' : 'id',
            documentId ?? 0,
          )
          .ilike('content', '%$query%')
          .limit(limit);

      return data.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// Get message count for session
  Future<int> getMessageCount(String sessionId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 0;

      final List data =
          await _supabase.from('chat_history').select('id').match({
        'user_id': userId,
        'session_id': sessionId,
      });

      return data.length;
    } catch (e) {
      return 0;
    }
  }
}
