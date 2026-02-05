
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/voice/voice_service.dart';
import '../../shared/theme/app_colors.dart';
import '../../features/life/entities_screen.dart';
import '../../core/api/api_client.dart';
import '../../features/chat/camera_scan_screen.dart';

class ChatInputBar extends StatefulWidget {
  final Function(String) onSend;

  const ChatInputBar({
    super.key,
    required this.onSend,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();
  final VoiceService _voiceService = VoiceService();
  final _supabase = Supabase.instance.client;

  bool _isListening = false;
  bool _isUploading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: const Border(top: BorderSide(color: Colors.black12)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: _isUploading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              onPressed: _isUploading ? null : _showUploadOptions,
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            IconButton(
              icon: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color: AppColors.accent,
              ),
              onPressed: _toggleVoiceInput,
            ),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleVoiceInput() async {
    if (_isListening) {
      await _voiceService.stopListening();
      setState(() => _isListening = false);
    } else {
      final ok = await _voiceService.initialize();
      if (ok) {
        await _voiceService.startListening((text) {
          if (!mounted) return;
          setState(() {
            _controller.text = text;
            _isListening = false;
          });
        });
        setState(() => _isListening = true);
      }
    }
  }

  Future<void> _showUploadOptions() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _UploadOption(
              icon: Icons.document_scanner,
              label: 'Scan / Upload Image',
              onTap: () {
                Navigator.pop(context);

                
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CameraScanScreen(
                      onTextExtracted: (text) {
                        if (text != null) {
                          /* text is ready */
                        }
                      },
                    ),
                  ),
                );
              },
            ),
            _UploadOption(
              icon: Icons.picture_as_pdf,
              label: 'Upload PDF',
              onTap: () {
                Navigator.pop(context);
                _pickFile('pdf');
              },
            ),
            _UploadOption(
              icon: Icons.folder_special,
              label: 'Life Entities',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EntitiesScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile(String type) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: type == 'pdf' ? FileType.custom : FileType.image,
      allowedExtensions: type == 'pdf' ? ['pdf'] : null,
    );

    if (result != null && result.files.single.path != null) {
      await _uploadFile(
        File(result.files.single.path!),
        type,
      );
    }
  }

  Future<void> _uploadFile(File file, String type) async {
    setState(() => _isUploading = true);

    try {
      final apiClient = ApiClient();
      final docData = await apiClient.uploadFile(file);

      if (mounted) {
        setState(() => _isUploading = false);
        _showTickAnimation();
        await Future.delayed(const Duration(milliseconds: 200));
        _checkForEntities(docData['document_id']);
      }
    } catch (e) {
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showTickAnimation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (context) {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (context.mounted) Navigator.pop(context);
        });

        return const Center(
          child: Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 80,
          ),
        );
      },
    );
  }

  Future<void> _checkForEntities(dynamic documentId) async {
    
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSend(text);
      _controller.clear();
    }
  }
}

class _UploadOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _UploadOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.accent),
      title: Text(label),
      onTap: onTap,
    );
  }
}
