
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import '../../core/api/api_client.dart';
import '../../core/security/biometric_service.dart';
import '../../core/security/vault_encryption_service.dart';
import '../../features/settings/settings_service.dart';
import '../../features/chat/chat_screen.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/text_styles.dart';
import '../../shared/widgets/premium_card.dart';
import '../../shared/widgets/loading_skeleton.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  final _supabase = Supabase.instance.client;
  final ApiClient _apiClient = ApiClient();
  final BiometricService _biometricService = BiometricService();
  final VaultEncryptionService _encryption = VaultEncryptionService();

  List<Map<String, dynamic>> _vaultItems = [];
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAuth();
  }

  Future<void> _checkBiometricAuth() async {
    try {
      final settingsService = SettingsService();
      await settingsService.init();

      final biometricEnabled = await settingsService.isBiometricEnabled();
      final vaultExtraLock =
          await settingsService.getPreference<bool>('vault_extra_lock') ??
              false;

      if (biometricEnabled && vaultExtraLock) {
        final authenticated =
            await _biometricService.authenticateForVaultAccess();

        if (!authenticated) {
          if (mounted) {
            Navigator.pop(context);
          }
          return;
        }
      }

      setState(() => _isAuthenticated = true);
      _loadVaultItems();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Authentication failed: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _loadVaultItems() async {
    try {
      setState(() => _isLoading = true);

      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      // Get vault documents from Supabase
      final response = await _supabase
          .from('documents')
          .select('id, title, created_at, file_size, status')
          .eq('user_id', user.id)
          .eq('is_vault', true)
          .eq('is_deleted', false)
          .order('created_at', ascending: false);

      setState(() {
        _vaultItems = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading vault: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load vault items: $e')),
        );
      }
    }
  }

  Future<void> _addToVault() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.single.path == null) return;

      setState(() => _isLoading = true);
      final file = File(result.files.single.path!);

      // Upload to vault (modified upload to set is_vault = true)
      await _uploadVaultFile(file);

      await _loadVaultItems();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document added to vault')),
        );
      }
    } catch (e) {
      print('Error adding to vault: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add to vault: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadVaultFile(File file) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final fileName = file.path.split('/').last;
    final fileSize = await file.length();
    final fileBytes = await file.readAsBytes();
    final storagePath =
        'vault/${user.id}/${DateTime.now().millisecondsSinceEpoch}_$fileName';

    // Upload to storage
    await _supabase.storage
        .from('documents')
        .uploadBinary(storagePath, fileBytes);

    // Create vault document
    final doc = await _supabase
        .from('documents')
        .insert({
          'user_id': user.id,
          'title': fileName,
          'file_type': fileName.split('.').last,
          'file_size': fileSize,
          'status': 'processing',
          'processed': false,
          'source': 'vault',
          'is_vault': true, // Mark as vault document
        })
        .select()
        .single();

    // Create job for OCR processing
    await _supabase.from('jobs').insert({
      'user_id': user.id,
      'document_id': doc['id'],
      'type': 'OCR',
      'status': 'queued',
      'payload': {
        'path': storagePath,
        'filename': fileName,
      }
    });
  }

  Future<void> _moveToVault(int documentId) async {
    try {
      await _supabase
          .from('documents')
          .update({'is_vault': true}).eq('id', documentId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document moved to vault')),
        );
      }
      _loadVaultItems();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to move to vault: $e')),
        );
      }
    }
  }

  Future<void> _removeFromVault(int documentId) async {
    try {
      await _supabase
          .from('documents')
          .update({'is_vault': false}).eq('id', documentId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document removed from vault')),
        );
      }
      _loadVaultItems();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove from vault: $e')),
        );
      }
    }
  }

  Future<void> _deleteVaultItem(int documentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: const Text('Are you sure? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _supabase
          .from('documents')
          .update({'is_deleted': true}).eq('id', documentId);

      _loadVaultItems();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vault'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVaultItems,
          ),
        ],
      ),
      body: _isLoading
          ? _buildSkeleton()
          : _vaultItems.isEmpty
              ? _buildEmptyState(isDark)
              : RefreshIndicator(
                  onRefresh: _loadVaultItems,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _vaultItems.length,
                    itemBuilder: (context, index) {
                      final item = _vaultItems[index];
                      return _VaultCard(
                        title: item['title'] ?? 'Untitled',
                        subtitle: _formatFileSize(item['file_size']),
                        timestamp: item['created_at'] ?? '',
                        status: item['status'] ?? 'unknown',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                documentId: item['id'],
                                documentTitle: item['title'],
                              ),
                            ),
                          );
                        },
                        onRemove: () => _removeFromVault(item['id']),
                        onDelete: () => _deleteVaultItem(item['id']),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: _addToVault,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outlined,
            size: 64,
            color:
                isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          const Text('Vault is empty', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          const Text('Tap + to add secure documents'),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 5,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: LoadingSkeleton(
          width: double.infinity,
          height: 80,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  String _formatFileSize(dynamic size) {
    if (size == null) return 'Unknown size';
    final bytes = size is int ? size : int.tryParse(size.toString()) ?? 0;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _VaultCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String timestamp;
  final String status;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final VoidCallback onDelete;

  const _VaultCard({
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.status,
    required this.onTap,
    required this.onRemove,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.lock, color: AppColors.success),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'remove') onRemove();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'remove',
                child: Text('Move to Documents'),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
