
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class BlockchainAuditService {
  final _supabase = Supabase.instance.client;

  
  Future<String> createAuditEntry({
    required int documentId,
    required String userId,
    required int fileSize,
    required String contentHash,
    String? previousHash,
  }) async {
    try {
      // Generate block data
      final blockData = {
        'document_id': documentId,
        'user_id': userId,
        'file_size': fileSize,
        'content_hash': contentHash,
        'timestamp': DateTime.now().toIso8601String(),
        'previous_hash': previousHash ?? 'GENESIS',
      };

      // Generate SHA-256 hash of block
      final blockHash = _generateBlockHash(blockData);

      // Store in database 
      await _supabase.from('document_audit_trail').insert({
        'document_id': documentId,
        'user_id': userId,
        'hash': blockHash,
        'blockchain_tx': jsonEncode(blockData), // Store full block data
        'verified': true,
        'created_at': DateTime.now().toIso8601String(),
      });

      return blockHash;
    } catch (e) {
      throw BlockchainAuditException('Failed to create audit entry: $e');
    }
  }

  /// Generate SHA-256 hash of document content
  String generateContentHash(String content) {
    final bytes = utf8.encode(content);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Generate hash of entire audit block
  String _generateBlockHash(Map<String, dynamic> blockData) {
    // Create deterministic string from block data
    final blockString = jsonEncode(blockData);
    final bytes = utf8.encode(blockString);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verify document integrity
  /// Returns true if document has not been tampered with
  Future<bool> verifyDocumentIntegrity(int documentId) async {
    try {
      // Get all audit entries for document 
      final auditEntries = await _supabase
          .from('document_audit_trail')
          .select('*')
          .eq('document_id', documentId)
          .order('created_at', ascending: true);

      if ((auditEntries as List).isEmpty) {
        // No audit trail = not verified
        return false;
      }

      String? previousHash;

      // Verify chain integrity
      for (var entry in (auditEntries as List)) {
        final storedHash = entry['hash'] as String;
        final blockData =
            jsonDecode(entry['blockchain_tx']) as Map<String, dynamic>;

        // Verify previous hash matches
        if (previousHash != null &&
            blockData['previous_hash'] != previousHash) {
          // Chain broken = tampered
          return false;
        }

        // Verify block hash is correct
        final recalculatedHash = _generateBlockHash(blockData);
        if (recalculatedHash != storedHash) {
          // Hash mismatch = tampered
          return false;
        }

        previousHash = storedHash;
      }

      return true; // All checks passed
    } catch (e) {
      throw BlockchainAuditException('Verification failed: $e');
    }
  }

  /// Get audit trail for document
  Future<List<Map<String, dynamic>>> getAuditTrail(int documentId) async {
    try {
      final response = await _supabase
          .from('document_audit_trail')
          .select('*')
          .eq('document_id', documentId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw BlockchainAuditException('Failed to get audit trail: $e');
    }
  }

  /// Get latest audit entry for document
  Future<Map<String, dynamic>?> getLatestAuditEntry(int documentId) async {
    try {
      final response = await _supabase
          .from('document_audit_trail')
          .select('*')
          .eq('document_id', documentId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return response as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  /// Mark document as verified
  Future<void> markDocumentVerified(int documentId) async {
    try {
      await _supabase
          .from('document_audit_trail')
          .update({'verified': true}).eq('document_id', documentId);
    } catch (e) {
      throw BlockchainAuditException('Failed to mark as verified: $e');
    }
  }

  /// Get verification status
  Future<DocumentVerificationStatus> getVerificationStatus(
      int documentId) async {
    try {
      final isValid = await verifyDocumentIntegrity(documentId);
      final auditTrail = await getAuditTrail(documentId);

      return DocumentVerificationStatus(
        isVerified: isValid,
        auditCount: auditTrail.length,
        lastAuditDate: auditTrail.isNotEmpty
            ? DateTime.parse(auditTrail.first['created_at'])
            : null,
        chainValid: isValid,
      );
    } catch (e) {
      return DocumentVerificationStatus(
        isVerified: false,
        auditCount: 0,
        lastAuditDate: null,
        chainValid: false,
      );
    }
  }

  /// Create audit entry after document upload (integration point)
  Future<void> auditDocumentUpload({
    required int documentId,
    required String userId,
    required int fileSize,
    required String content,
  }) async {
    try {
      // Get previous hash (latest audit entry)
      final latestEntry = await getLatestAuditEntry(documentId);
      final previousHash = latestEntry?['hash'] as String?;

      // Generate content hash
      final contentHash = generateContentHash(content);

      // Create audit entry
      await createAuditEntry(
        documentId: documentId,
        userId: userId,
        fileSize: fileSize,
        contentHash: contentHash,
        previousHash: previousHash,
      );
    } catch (e) {
      // Log but don't fail upload
      print('⚠️ Blockchain audit failed: $e');
    }
  }

  /// Create audit entry after document modification
  Future<void> auditDocumentModification({
    required int documentId,
    required String userId,
    required String newContent,
  }) async {
    try {
      // Get document info
      final doc = await _supabase
          .from('documents')
          .select('file_size')
          .eq('id', documentId)
          .single();

      final fileSize = doc['file_size'] as int;

      // Audit the modification
      await auditDocumentUpload(
        documentId: documentId,
        userId: userId,
        fileSize: fileSize,
        content: newContent,
      );
    } catch (e) {
      print('⚠️ Blockchain audit failed: $e');
    }
  }
}

/// Verification status result
class DocumentVerificationStatus {
  final bool isVerified;
  final int auditCount;
  final DateTime? lastAuditDate;
  final bool chainValid;

  DocumentVerificationStatus({
    required this.isVerified,
    required this.auditCount,
    this.lastAuditDate,
    required this.chainValid,
  });
}

/// Custom exception for blockchain audit errors
class BlockchainAuditException implements Exception {
  final String message;
  BlockchainAuditException(this.message);

  @override
  String toString() => message;
}
