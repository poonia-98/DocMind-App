import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class GeminiChatService {
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';
  
  /// Call Gemini API with automatic model fallback
  /// Returns response text or null if all models fail
  Future<String?> chat({
    required String message,
    String? context,
    int maxRetries = 2,
  }) async {
    if (AppConfig.geminiApiKey.isEmpty) {
      print('⚠️ [GEMINI] API key not configured');
      return null;
    }

    // Build prompt
    final String systemPrompt = context != null && context.isNotEmpty
        ? 'You are a helpful assistant. Answer questions based ONLY on the provided document content. If the answer is not in the documents, say so clearly.'
        : 'You are a helpful assistant. Have a natural conversation with the user.';

    final String userPrompt = context != null && context.isNotEmpty
        ? 'DOCUMENT CONTENT:\n$context\n\nQUESTION: $message'
        : message;

    // Try each model in priority order
    for (final model in AppConfig.geminiModels) {
      print('🤖 [GEMINI] Trying model: $model');
      
      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          final response = await _callGeminiModel(
            model: model,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
          );

          if (response != null && response.isNotEmpty) {
            print('✅ [GEMINI] Success with $model (attempt $attempt)');
            return response;
          }
        } catch (e) {
          print('⚠️ [GEMINI] $model attempt $attempt failed: $e');
          if (attempt < maxRetries) {
            await Future.delayed(Duration(milliseconds: 500 * attempt));
          }
        }
      }
    }

    print('❌ [GEMINI] All models failed');
    return null;
  }

  Future<String?> _callGeminiModel({
    required String model,
    required String systemPrompt,
    required String userPrompt,
  }) async {
    final url = Uri.parse(
      '$_baseUrl/models/$model:generateContent?key=${AppConfig.geminiApiKey}',
    );

    final requestBody = {
      'contents': [
        {
          'parts': [
            {'text': '$systemPrompt\n\n$userPrompt'}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.7,
        'topK': 40,
        'topP': 0.95,
        'maxOutputTokens': 2048,
      },
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(requestBody),
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception('Gemini API timeout'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      // Extract text from Gemini response structure
      if (data['candidates'] != null && 
          data['candidates'].isNotEmpty &&
          data['candidates'][0]['content'] != null &&
          data['candidates'][0]['content']['parts'] != null &&
          data['candidates'][0]['content']['parts'].isNotEmpty) {
        
        final text = data['candidates'][0]['content']['parts'][0]['text'];
        if (text != null && text.toString().trim().isNotEmpty) {
          return text.toString().trim();
        }
      }
      
      print('⚠️ [GEMINI] Empty response from API');
      return null;
    } else if (response.statusCode == 429) {
      throw Exception('Rate limited');
    } else if (response.statusCode == 400) {
      print('⚠️ [GEMINI] Bad request: ${response.body}');
      throw Exception('Invalid request');
    } else {
      print('⚠️ [GEMINI] API error ${response.statusCode}: ${response.body}');
      throw Exception('API error: ${response.statusCode}');
    }
  }

  /// Generate embedding using Gemini (for future use)
  Future<List<double>?> generateEmbedding(String text) async {
    if (AppConfig.geminiApiKey.isEmpty) {
      return null;
    }

    try {
      final url = Uri.parse(
        '$_baseUrl/models/text-embedding-004:embedContent?key=${AppConfig.geminiApiKey}',
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'models/text-embedding-004',
          'content': {
            'parts': [
              {'text': text}
            ]
          },
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['embedding'] != null && data['embedding']['values'] != null) {
          return List<double>.from(data['embedding']['values']);
        }
      }
      
      return null;
    } catch (e) {
      print('⚠️ [GEMINI] Embedding generation failed: $e');
      return null;
    }
  }
}