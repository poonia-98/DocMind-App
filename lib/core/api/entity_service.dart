// lib/core/api/entity_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';

class LifeEntitiesService {
  final _supabase = Supabase.instance.client;

  /// ✅ Fetch clean entity views (reads from entity_views table)
  Future<List<Map<String, dynamic>>> getEntities() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // ✅ READ FROM entity_views (clean projection)
      final response = await _supabase
          .from('entity_views')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to load entities: $e');
    }
  }

  /// Create entity from OCR (stores raw_text, trigger auto-populates entity_views)
  Future<Map<String, dynamic>> createEntity({
    required String name,
    required String type,
    required String rawText, // OCR extracted text
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Insert into life_entities with raw_text
      final response = await _supabase
          .from('life_entities')
          .insert({
            'user_id': userId,
            'name': name,
            'type': type,
            'metadata': {
              'raw_text': rawText, // ← Backend will clean this
              ...?metadata,
            },
          })
          .select()
          .single();

      // Trigger automatically populates entity_views

      return response;
    } catch (e) {
      throw Exception('Failed to create entity: $e');
    }
  }

  /// Create entity with clean fields (for manual entry)
  Future<Map<String, dynamic>> createEntityClean({
    required String title,
    required String entityType,
    String? identifier,
    String? shortAddress,
    String? validTill,
    double? amount,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // First create life_entity
      final lifeEntity = await _supabase
          .from('life_entities')
          .insert({
            'user_id': userId,
            'name': title,
            'type': entityType,
            'metadata': {
              'manual_entry': true,
            },
          })
          .select()
          .single();

      // Then directly insert into entity_views (clean data)
      final entityView = await _supabase
          .from('entity_views')
          .insert({
            'user_id': userId,
            'source_table': 'life_entities',
            'source_id': lifeEntity['id'],
            'title': title,
            'identifier': identifier,
            'short_address': shortAddress,
            'valid_till': validTill,
            'amount': amount,
            'entity_type': entityType,
          })
          .select()
          .single();

      return entityView;
    } catch (e) {
      throw Exception('Failed to create entity: $e');
    }
  }

  /// Get entity by ID (from entity_views)
  Future<Map<String, dynamic>> getEntityById(int entityViewId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('entity_views')
          .select()
          .eq('id', entityViewId)
          .eq('user_id', userId)
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to load entity: $e');
    }
  }

  /// Update entity (updates life_entities, trigger re-syncs entity_views)
  Future<void> updateEntity(int sourceId, Map<String, dynamic> updates) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Update life_entities
      await _supabase
          .from('life_entities')
          .update(updates)
          .eq('id', sourceId)
          .eq('user_id', userId);

      // Trigger will auto-sync entity_views
    } catch (e) {
      throw Exception('Failed to update entity: $e');
    }
  }

  /// Update entity view directly (for manual edits)
  Future<void> updateEntityView(int entityViewId, {
    String? title,
    String? identifier,
    String? shortAddress,
    String? validTill,
    double? amount,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final updates = <String, dynamic>{};
      if (title != null) updates['title'] = title;
      if (identifier != null) updates['identifier'] = identifier;
      if (shortAddress != null) updates['short_address'] = shortAddress;
      if (validTill != null) updates['valid_till'] = validTill;
      if (amount != null) updates['amount'] = amount;
      
      updates['updated_at'] = DateTime.now().toIso8601String();

      await _supabase
          .from('entity_views')
          .update(updates)
          .eq('id', entityViewId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to update entity view: $e');
    }
  }

  /// Delete entity (deletes from life_entities, cascade deletes entity_views)
  Future<void> deleteEntity(int sourceId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Delete from life_entities (will cascade to entity_views)
      await _supabase
          .from('life_entities')
          .delete()
          .eq('id', sourceId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to delete entity: $e');
    }
  }

  /// Get entities by type (from entity_views)
  Future<List<Map<String, dynamic>>> getEntitiesByType(String type) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('entity_views')
          .select()
          .eq('user_id', userId)
          .eq('entity_type', type)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to load entities by type: $e');
    }
  }

  /// Get entities with expiry status (computed from entity_views.valid_till)
  Future<Map<String, List<Map<String, dynamic>>>> getEntitiesByStatus() async {
    try {
      final entities = await getEntities();
      final now = DateTime.now();

      final Map<String, List<Map<String, dynamic>>> categorized = {
        'active': [],
        'expiring_soon': [], // Within 30 days
        'expired': [],
        'no_expiry': [],
      };

      for (var entity in entities) {
        final validTillStr = entity['valid_till'];
        
        if (validTillStr == null || validTillStr.toString().isEmpty) {
          categorized['no_expiry']!.add(entity);
          continue;
        }

        try {
          final validTill = DateTime.parse(validTillStr.toString());
          final daysUntil = validTill.difference(now).inDays;

          if (daysUntil < 0) {
            categorized['expired']!.add(entity);
          } else if (daysUntil <= 30) {
            categorized['expiring_soon']!.add(entity);
          } else {
            categorized['active']!.add(entity);
          }
        } catch (e) {
          categorized['no_expiry']!.add(entity);
        }
      }

      return categorized;
    } catch (e) {
      throw Exception('Failed to categorize entities: $e');
    }
  }

  /// Force manual sync of all entity views (calls backend function)
  Future<int> syncAllEntityViews() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final result = await _supabase.rpc('sync_all_entity_views', params: {
        'p_user_id': userId,
      });

      return result ?? 0;
    } catch (e) {
      throw Exception('Failed to sync entity views: $e');
    }
  }

  /// Sync single entity view (calls backend function)
  Future<void> syncEntityView(int sourceId) async {
    try {
      await _supabase.rpc('sync_entity_view', params: {
        'p_entity_id': sourceId,
      });
    } catch (e) {
      throw Exception('Failed to sync entity view: $e');
    }
  }

  /// Link document to entity (for document-entity mapping)
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
        'confidence': confidence,
        'extracted_data': extractedData ?? {},
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to link document to entity: $e');
    }
  }

  /// Get entities linked to a document
  Future<List<Map<String, dynamic>>> getEntitiesForDocument(int documentId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('document_entity_mappings')
          .select('*, life_entities(*), entity_views(*)')
          .eq('document_id', documentId)
          .eq('user_id', userId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to load entities for document: $e');
    }
  }

  /// Get documents linked to an entity
  Future<List<Map<String, dynamic>>> getDocumentsForEntity(int entityId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('document_entity_mappings')
          .select('*, documents(*)')
          .eq('entity_id', entityId)
          .eq('user_id', userId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to load documents for entity: $e');
    }
  }
}