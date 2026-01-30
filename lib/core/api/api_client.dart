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




  static const int QUEUE_THRESHOLD = 5 * 1024 * 1024; 

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

  

  Future<dynamic> get(String endpoint, {Map<String, String>? queryParams}) async {
    final headers = await _getHeaders();
    var uri = Uri.parse('${AppConfig.supabaseUrl}/api/$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }
    final response = await http.get(uri, headers: headers).timeout(AppConfig.requestTimeout);
    return _handleResponse(response);
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('${AppConfig.supabaseUrl}/api/$endpoint');
    final response = await http.post(uri, headers: headers, body: json.encode(data)).timeout(AppConfig.requestTimeout);
    return _handleResponse(response);
  }

  Future<dynamic> put(String endpoint, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('${AppConfig.supabaseUrl}/api/$endpoint');
    final response = await http.put(uri, headers: headers, body: json.encode(data)).timeout(AppConfig.requestTimeout);
    return _handleResponse(response);
  }

  Future<dynamic> delete(String endpoint, {Map<String, String>? queryParams}) async {
    final headers = await _getHeaders();
    var uri = Uri.parse('${AppConfig.supabaseUrl}/api/$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }
    final response = await http.delete(uri, headers: headers).timeout(AppConfig.requestTimeout);
    return _handleResponse(response);
  }

 

  Future<dynamic> uploadFile(File file) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw ApiException(401, 'User not logged in');

    try {
      final fileName = file.path.split('/').last;
      final fileSize = await file.length();
      final fileBytes = await file.readAsBytes();
      final storagePath = 'uploads/${user.id}/${DateTime.now().millisecondsSinceEpoch}_$fileName';

      //  storage me upload
      await _supabase.storage
          .from('documents')
          .uploadBinary(storagePath, fileBytes);

      //  document create 
      final doc = await _supabase.from('documents').insert({
        'user_id': user.id,
        'title': fileName,
        'file_type': fileName.split('.').last,
        'file_size': fileSize,
        'status': 'processing',
        'processed': false,
        'source': 'queue',
      }).select().single();

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
      final contentHash = blockchainAudit.generateContentHash(
        String.fromCharCodes(fileBytes)
      );
      
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

  //  BACKGROUND EMBEDDING GENERATION
  Future<void> _generateEmbeddingsInBackground(int documentId) async {
    try {
      print('⏳ Waiting for document $documentId to finish processing...');
      
      // Wait for OCR processing to complete (max 60 seconds)
      for (int i = 0; i < 60; i++) {
        await Future.delayed(const Duration(seconds: 1));
        
        final doc = await _supabase
            .from('documents')
            .select('status, processed')
            .eq('id', documentId)
            .single();
        
        if (doc['status'] == 'ready' && doc['processed'] == true) {
          print('📄 Document $documentId processing complete, generating embeddings...');
          
          // Generate embeddings for all sections
          await _embeddingService.addEmbeddingsToDocument(documentId);
          
          print('✅ Embeddings generated successfully for document $documentId');
          return;
        }
        
        if (doc['status'] == 'failed') {
          print('❌ Document $documentId processing failed, skipping embeddings');
          return;
        }
      }
      
      print('⚠️ Timeout waiting for document $documentId processing');
    } catch (e) {
      print('❌ Error generating embeddings for document $documentId: $e');
      
    }
  }

  // --- HELPER METHODS ---

  List<String> _createChunks(String text, int wordsPerChunk) {
    if (text.isEmpty) return [];
    
    // Extra spaces saaf karo aur split karo
    List<String> words = text.trim().split(RegExp(r'\s+'));
    List<String> chunks = [];
    
    for (var i = 0; i < words.length; i += wordsPerChunk) {
      int end = (i + wordsPerChunk < words.length) ? i + wordsPerChunk : words.length;
      chunks.add(words.sublist(i, end).join(' '));
    }
    
    return chunks;
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body);
    }
    throw ApiException(response.statusCode, response.body);
  }

  void dispose() {
    // Cleaner disposal
  }
}