import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../auth/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../security/blockchain_audit.dart';
import '../documents/embedding_service.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final dynamic data;

  ApiException(this.statusCode, this.message, [this.data]);

  @override
  String toString() => 'ApiException: $statusCode - $message';
}

class ApiClient {
  final AuthService _authService = AuthService();
  final _supabase = Supabase.instance.client;
  final _embeddingService = EmbeddingService();


  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    if (token == null) {
      throw ApiException(401, 'No authentication token available');
    }
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  

  Future<dynamic> uploadFile(File file) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw ApiException(401, 'User not logged in');

    try {
      final fileName = file.path.split('/').last;
      final fileSize = await file.length();
      final fileBytes = await file.readAsBytes();
      final storagePath =
          'uploads/${user.id}/${DateTime.now().millisecondsSinceEpoch}_$fileName';

      //  storage me upload
      await _supabase.storage
          .from('documents')
          .uploadBinary(storagePath, fileBytes);

      //  document create
      final doc = await _supabase
          .from('documents')
          .insert({
            'user_id': user.id,
            'title': fileName,
            'file_type': fileName.split('.').last,
            'file_size': fileSize,
            'status': 'processing',
            'processed': false,
            'source': 'queue',
          })
          .select()
          .single();

      final documentId = doc['id'] as int;

      // job create
      await _supabase.from('jobs').insert({
        'user_id': user.id,
        'document_id': documentId,
        'type': 'OCR',
        'status': 'queued',
        'payload': {
          'path': storagePath,
          'filename': fileName,
        }
      });

      //  CREATE BLOCKCHAIN AUDIT ENTRY
      final blockchainAudit = BlockchainAuditService();
      final contentHash =
          blockchainAudit.generateContentHash(String.fromCharCodes(fileBytes));

      await blockchainAudit.createAuditEntry(
        documentId: documentId,
        userId: user.id,
        fileSize: fileSize,
        contentHash: contentHash,
      );

      //  START BACKGROUND EMBEDDING GENERATION
      _generateEmbeddingsInBackground(documentId);

      return {'status': 'queued', 'document_id': documentId};
    } catch (e) {
      throw Exception('Upload failed: $e');
    }
  }

  //  BACKGROUND EMBEDDING GENERATION - FIXED
  Future<void> _generateEmbeddingsInBackground(int documentId) async {
    try {
      print('⏳ Waiting for document $documentId to finish processing...');

      for (int i = 0; i < 60; i++) {
        await Future.delayed(const Duration(seconds: 1));

        final doc = await _supabase
            .from('documents')
            .select('status, processed')
            .eq('id', documentId)
            .single();

        if (doc['status'] == 'ready' && doc['processed'] == true) {
          print('📄 OCR done for document $documentId');

          final user = _supabase.auth.currentUser;
          if (user == null) return;

          // 1️⃣ FETCH DETECTED ENTITIES (created by worker.py)
          final List detectedEntities = await _supabase
              .from('detected_entities')
              .select()
              .eq('document_id', documentId);

          print('🔍 Found ${detectedEntities.length} detected entities');

          for (final e in detectedEntities) {
            try {
              // 2️⃣ CREATE LIFE ENTITY
              final entity = await _supabase
                  .from('life_entities')
                  .insert({
                    'user_id': user.id,
                    'name': e['name'],
                    'type': e['type'],
                    'metadata': e['metadata'] ?? {},
                  })
                  .select()
                  .single();

              print('✅ Created life entity: ${entity['name']}');

              // 3️⃣ UPDATE detected_entity with entity_id
              await _supabase
                  .from('detected_entities')
                  .update({
                    'converted_to_entity': true,
                    'entity_id': entity['id'],
                  })
                  .eq('id', e['id']);

              // 4️⃣ OBLIGATION (if expiry exists)
              final metadata = e['metadata'] as Map<String, dynamic>?;
              final expiry = metadata?['expiry_date'];
              
              if (expiry != null) {
                try {
                  final due = DateTime.parse(expiry);

                  final obligation = await _supabase
                      .from('obligations')
                      .insert({
                        'user_id': user.id,
                        'entity_id': entity['id'],
                        'title': 'Renew ${entity['name']}',
                        'type': 'renewal',
                        'due_date': due.toIso8601String().split('T')[0], // Date only
                        'status': 'pending',
                      })
                      .select()
                      .single();

                  print('✅ Created obligation: ${obligation['title']}');

                  // 5️⃣ REMINDERS (14 days and 3 days before)
                  final remindAt14 = due.subtract(const Duration(days: 14));
                  final remindAt3 = due.subtract(const Duration(days: 3));

                  await _supabase.from('reminders').insert([
                    {
                      'user_id': user.id,
                      'obligation_id': obligation['id'],
                      'title': '⏰ Reminder: ${entity['name']} expires in 14 days',
                      'remind_at': remindAt14.toIso8601String(),
                      'type': 'expiry',
                    },
                    {
                      'user_id': user.id,
                      'obligation_id': obligation['id'],
                      'title': '🚨 Urgent: ${entity['name']} expires in 3 days',
                      'remind_at': remindAt3.toIso8601String(),
                      'type': 'expiry',
                    }
                  ]);

                  print('✅ Created 2 reminders for ${entity['name']}');
                } catch (dateError) {
                  print('⚠️ Failed to parse expiry date: $expiry');
                }
              }
            } catch (entityError) {
              print('❌ Failed to process entity: $entityError');
            }
          }

          // 6️⃣ EMBEDDINGS (LAST STEP)
          try {
            await _embeddingService.addEmbeddingsToDocument(documentId);
            print('✅ Added embeddings for document $documentId');
          } catch (embError) {
            print('⚠️ Embedding generation failed: $embError');
          }

          print('✅ LifeOS pipeline complete for document $documentId');
          return;
        }

        if (doc['status'] == 'failed') {
          print('❌ OCR failed for document $documentId');
          return;
        }
      }

      print('⚠️ OCR timeout for document $documentId');
    } catch (e) {
      print('❌ LifeOS pipeline error: $e');
    }
  }


  

  

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body);
    }
    throw ApiException(response.statusCode, response.body);
  }

  void dispose() {
    
}

}