import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../shared/widgets/sidebar.dart';
import '../../shared/theme/app_colors.dart';
import 'chat_input_bar.dart';
import 'message_bubble.dart';
import '../../core/config.dart';
import '../../core/api/gemini_chat_service.dart';

class ChatScreen extends StatefulWidget {
  final int? documentId;
  final String? documentTitle;

  const ChatScreen({
    super.key,
    this.documentId,
    this.documentTitle,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _supabase = Supabase.instance.client;
  final _geminiService = GeminiChatService();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];

  bool _isLoading = false;
  String? _sessionId;
  String _lastUsedProvider = ''; // Track which AI provider was used

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  void _initializeChat() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    _sessionId = widget.documentId != null
        ? 'doc_${widget.documentId}_${user.id}'
        : 'session_${user.id}';

    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    if (_sessionId == null) return;

    final response = await _supabase
        .from('chat_history')
        .select()
        .eq('session_id', _sessionId!)
        .order('created_at', ascending: true);

    setState(() {
      _messages.clear();
      _messages.addAll(
        List<Map<String, dynamic>>.from(response).map((msg) => {
              'id': msg['id'],
              'text': msg['content'],
              'isUser': msg['role'] == 'user',
              'timestamp': msg['created_at'],
            }),
      );
    });

    _scrollToBottom();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMessage = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'text': text,
      'isUser': true,
      'timestamp': DateTime.now().toIso8601String(),
    };

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      await _supabase.from('chat_history').insert({
        'user_id': user.id,
        'session_id': _sessionId,
        'role': 'user',
        'content': text,
      });

      final aiResponse = await _callAI(text);

      await _supabase.from('chat_history').insert({
        'user_id': user.id,
        'session_id': _sessionId,
        'role': 'assistant',
        'content': aiResponse,
      });

      setState(() {
        _messages.add({
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'text': aiResponse,
          'isUser': false,
          'timestamp': DateTime.now().toIso8601String(),
          'provider': _lastUsedProvider, // Track which AI was used
        });
      });
    } catch (e) {
      setState(() {
        _messages.add({
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'text': 'Error: $e',
          'isUser': false,
          'timestamp': DateTime.now().toIso8601String(),
          'isError': true,
        });
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  Future<String> _callAI(String message) async {
    try {
      String context = '';

      // If chat is for a specific document, get that document's content
      if (widget.documentId != null) {
        print('📄 Fetching content for document ${widget.documentId}...');

        final sections = await _supabase
            .from('document_sections')
            .select('content')
            .eq('document_id', widget.documentId!)
            .order('section_order', ascending: true);

        if (sections.isNotEmpty) {
          context = sections
              .map((s) => s['content'] as String)
              .where((c) => c.isNotEmpty && c != '[NO TEXT EXTRACTED]')
              .join('\n\n');

          print(
              '✅ Got ${sections.length} sections, total ${context.length} chars');
        } else {
          print('⚠️ No sections found for document');
        }
      } else {
        // General chat - try to get context from embeddings
        print('🔍 Searching all documents using embeddings...');

        try {
          // Try Gemini embedding first
          final geminiEmbedding = await _geminiService.generateEmbedding(message);
          
          List<double>? questionEmbedding = geminiEmbedding;
          
          // Fallback to GitHub embedding if Gemini fails
          if (questionEmbedding == null && AppConfig.githubToken.isNotEmpty) {
            print('⚠️ Gemini embedding failed, trying GitHub...');
            questionEmbedding = await _generateGitHubEmbedding(message);
          }

          if (questionEmbedding != null) {
            final result = await _supabase.rpc(
              'ai_context_from_question',
              params: {
                'p_question_embedding': questionEmbedding,
                'p_limit': 5,
                'p_similarity_threshold': 0.65,
              },
            );

            if (result != null && result.toString().trim().isNotEmpty) {
              context = result.toString();
              print('✅ Found context from embeddings: ${context.length} chars');
            }
          }
        } catch (e) {
          print('⚠️ Embedding search failed: $e');
        }
      }

      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('🚀 AI CHAT REQUEST');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // PRIMARY: Try Gemini first
      print('🎯 PRIMARY: Attempting Gemini API...');
      final geminiResponse = await _geminiService.chat(
        message: message,
        context: context.isNotEmpty ? context : null,
      );

      if (geminiResponse != null && geminiResponse.isNotEmpty) {
        _lastUsedProvider = 'Gemini';
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('✅ SUCCESS: Gemini responded (${geminiResponse.length} chars)');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        return geminiResponse;
      }

      // FALLBACK: Try GitHub if Gemini failed
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('⚠️ Gemini failed, falling back to GitHub...');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      if (AppConfig.githubToken.isEmpty) {
        print('❌ GitHub token not configured');
        return 'AI service unavailable. Please configure Gemini API key in settings.';
      }

      final githubResponse = await _callGitHubAI(message, context);
      _lastUsedProvider = 'GitHub (fallback)';
      
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('✅ SUCCESS: GitHub fallback responded (${githubResponse.length} chars)');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      return githubResponse;

    } catch (e) {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print(' FATAL ERROR: Both AI providers failed');
      print('Error: $e');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      _lastUsedProvider = 'none';
      return 'Error: Both AI providers are unavailable. Please try again later.';
    }
  }

  /// Fallback: GitHub-based AI (only called if Gemini fails)
  Future<String> _callGitHubAI(String message, String context) async {
    String systemPrompt = context.isNotEmpty
        ? 'You are a helpful assistant. Answer questions based ONLY on the provided document content. If the answer is not in the documents, say so clearly.'
        : 'You are a helpful assistant. Have a natural conversation with the user.';

    String userPrompt = context.isNotEmpty
        ? 'DOCUMENT CONTENT:\n$context\n\nQUESTION: $message'
        : message;

    print('🔄 [GITHUB] Calling with ${context.isEmpty ? "no" : context.length.toString() + " chars of"} context...');

    final response = await http.post(
      Uri.parse('https://models.inference.ai.azure.com/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AppConfig.githubToken}',
      },
      body: jsonEncode({
        'model': 'gpt-4o-mini',
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt}
        ],
        'temperature': 0.7,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final aiText = data['choices'][0]['message']['content'] ?? 'No response';
      print('✅ [GITHUB] Responded: ${aiText.length} chars');
      return aiText;
    } else {
      print('❌ [GITHUB] API error: ${response.statusCode} - ${response.body}');
      throw Exception('GitHub AI service unavailable (${response.statusCode})');
    }
  }

  /// Fallback embedding generation using GitHub
  Future<List<double>?> _generateGitHubEmbedding(String text) async {
    try {
      final res = await http.post(
        Uri.parse('https://models.inference.ai.azure.com/embeddings'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AppConfig.githubToken}',
        },
        body: jsonEncode({
          'model': 'text-embedding-3-small',
          'input': text,
        }),
      );

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        return List<double>.from(json['data'][0]['embedding']);
      }
      return null;
    } catch (e) {
      print('⚠️ [GITHUB] Embedding failed: $e');
      return null;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _sessionId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.documentTitle ?? 'Chat'),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _clearChat,
            ),
        ],
      ),
      drawer: AppSidebar(),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState(isDark)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return MessageBubble(
                        text: message['text'],
                        isUser: message['isUser'],
                        timestamp: message['timestamp'],
                        isError: message['isError'] ?? false,
                      );
                    },
                  ),
          ),
          if (_isLoading) _buildThinking(isDark),
          ChatInputBar(onSend: _sendMessage),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 64,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary),
          const SizedBox(height: 16),
          const Text('Start a conversation'),
          const SizedBox(height: 8),
          Text(
            'Powered by Gemini AI',
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThinking(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const SizedBox(width: 16),
          const CircularProgressIndicator(strokeWidth: 2),
          const SizedBox(width: 12),
          Text(
            _lastUsedProvider.isEmpty ? 'Thinking...' : 'Using $_lastUsedProvider...',
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}