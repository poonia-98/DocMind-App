import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';

class EmbeddingService {
  final _supabase = Supabase.instance.client;

  Future<List<double>> generateEmbedding(String text) async {
    if (text.trim().isEmpty) {
      throw Exception('Empty text provided');
    }

    final res = await http.post(
      Uri.parse('https://models.inference.ai.azure.com/embeddings'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AppConfig.githubToken}',
      },
      body: jsonEncode({
        'model': 'text-embedding-3-small',
        'input': text.trim(),
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('Embedding API failed: ${res.statusCode} - ${res.body}');
    }

    final json = jsonDecode(res.body);
    return List<double>.from(json['data'][0]['embedding']);
  }

  Future<void> addEmbeddingsToDocument(int documentId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final sections = await _supabase
        .from('document_sections')
        .select('id, content')
        .eq('document_id', documentId)
        .eq('user_id', userId);

    if (sections.isEmpty) {
      print('❌ No sections found for document $documentId');
      return;
    }

    print('📊 Found ${sections.length} sections, generating embeddings...');

    for (var section in sections) {
      final sectionId = section['id'];
      final content = section['content'] as String;

      if (content.trim().isEmpty || content == '[NO TEXT EXTRACTED]') {
        continue;
      }

      try {
        final embedding = await generateEmbedding(content);

        await _supabase
            .from('document_sections')
            .update({'embedding': embedding}).eq('id', sectionId);

        print('✅ Embedding added to section $sectionId');
      } catch (e) {
        print('❌ Failed to add embedding to section $sectionId: $e');
      }
    }

    print('✅ Embeddings complete for document $documentId');
  }
}
