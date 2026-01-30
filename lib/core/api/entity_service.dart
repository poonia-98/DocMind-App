// lib/core/api/entity_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class EntityService {
  final _supabase = Supabase.instance.client;

  /// Get all life entities for current user
  Future<List<Map<String, dynamic>>> getAllEntities() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('life_entities')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to load entities: $e');
    }
  }

  /// Get entity with all linked documents and obligations
  Future<Map<String, dynamic>> getEntityDetails(int entityId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Get entity
      final entity = await _supabase
          .from('life_entities')
          .select('*')
          .eq('id', entityId)
          .eq('user_id', userId)
          .single();

      // Get linked documents using RPC function
      final linkedDocs = await _supabase
          .rpc('get_entity_with_documents', params: {'p_entity_id': entityId});

      // Get obligations for this entity
      final obligations = await _supabase
          .from('obligations')
          .select('*')
          .eq('entity_id', entityId)
          .eq('user_id', userId)
          .order('due_date', ascending: true);

      // Get document count

      return {
        'entity': entity,
        'documents': linkedDocs is List ? linkedDocs : [],
        'obligations': obligations,
      };
    } catch (e) {
      throw Exception('Failed to load entity details: $e');
    }
  }

  /// Create new life entity
  Future<Map<String, dynamic>> createEntity({
    required String name,
    required String type,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('life_entities')
          .insert({
            'user_id': userId,
            'name': name,
            'type': type,
            'metadata': metadata ?? {},
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return response as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to create entity: $e');
    }
  }

  /// Update entity
  Future<void> updateEntity(int entityId, Map<String, dynamic> updates) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase
          .from('life_entities')
          .update({
            ...updates,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', entityId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to update entity: $e');
    }
  }

  /// Delete entity
  Future<void> deleteEntity(int entityId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase
          .from('life_entities')
          .delete()
          .eq('id', entityId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to delete entity: $e');
    }
  }

  /// Link document to entity
  Future<void> linkDocumentToEntity({
    required int documentId,
    required int entityId,
    double? confidence,
    Map<String, dynamic>? extractedData,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase.from('document_entity_mappings').insert({
        'document_id': documentId,
        'entity_id': entityId,
        'user_id': userId,
        'confidence': confidence ?? 1.0,
        'extracted_data': extractedData ?? {},
      });
    } catch (e) {
      throw Exception('Failed to link document: $e');
    }
  }

  /// Unlink document from entity
  Future<void> unlinkDocumentFromEntity(int documentId, int entityId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase
          .from('document_entity_mappings')
          .delete()
          .eq('document_id', documentId)
          .eq('entity_id', entityId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to unlink document: $e');
    }
  }

  /// Get entities by type
  Future<List<Map<String, dynamic>>> getEntitiesByType(String type) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('life_entities')
          .select('*')
          .eq('user_id', userId)
          .eq('type', type)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to load entities by type: $e');
    }
  }

  /// Check if document has linked entities
  Future<List<Map<String, dynamic>>> getEntitiesForDocument(
      int documentId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final mappings = await _supabase
          .from('document_entity_mappings')
          .select('entity_id, confidence, extracted_data')
          .eq('document_id', documentId)
          .eq('user_id', userId);

      if ((mappings as List).isEmpty) return [];

      // Get entity details
      final entityIds =
          (mappings as List).map((m) => m['entity_id'] as int).toList();

      final entities = await _supabase
          .from('life_entities')
          .select('*')
          .eq('user_id', userId)
          .inFilter('id', entityIds);

      // Merge confidence data
      final result = <Map<String, dynamic>>[];
      for (var entity in (entities as List)) {
        final mapping = (mappings as List).firstWhere(
          (m) => m['entity_id'] == entity['id'],
        );
        result.add({
          ...entity,
          'confidence': mapping['confidence'],
          'extracted_data': mapping['extracted_data'],
        });
      }

      return result;
    } catch (e) {
      throw Exception('Failed to get entities for document: $e');
    }
  }

  /// Get entity extraction log for document
  Future<Map<String, dynamic>?> getExtractionLog(int documentId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('entity_extraction_log')
          .select('*')
          .eq('document_id', documentId)
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return response as Map<String, dynamic>?;
    } catch (e) {
      throw Exception('Failed to get extraction log: $e');
    }
  }
}
