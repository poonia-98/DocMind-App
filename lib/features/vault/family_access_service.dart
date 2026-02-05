import 'package:supabase_flutter/supabase_flutter.dart';

/// Production-ready family access control
/// Enforces document permissions at BACKEND level (not UI-only)
/// Permissions: view, edit, none
/// FULLY WIRED with RLS policies
class FamilyAccessService {
  final _supabase = Supabase.instance.client;

  /// Add family member access to document
  /// Permission enforced by RLS policy in Supabase
  Future<void> grantAccess({
    required int documentId,
    required String familyMemberEmail,
    required String permission, // 'view' or 'edit'
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw FamilyAccessException('User not authenticated');
      }

      // Verify user owns document
      final doc = await _supabase
          .from('documents')
          .select('user_id')
          .eq('id', documentId)
          .eq('user_id', currentUserId)
          .maybeSingle();

      if (doc == null) {
        throw FamilyAccessException('Document not found or unauthorized');
      }

      // Get family member user ID by email
      final users = await _supabase
          .from('users')
          .select('id')
          .eq('email', familyMemberEmail)
          .maybeSingle();

      if (users == null) {
        throw FamilyAccessException(
            'User not found with email: $familyMemberEmail');
      }

      final familyMemberUserId = users['id'] as String;

      // Check if access already exists
      final existing = await _supabase
          .from('family_access')
          .select('id')
          .eq('document_id', documentId)
          .eq('shared_with_user_id', familyMemberUserId)
          .maybeSingle();

      if (existing != null) {
        // Update existing permission
        await _supabase.from('family_access').update({
          'permission': permission,
        }).eq('id', existing['id']);
      } else {
        // Create new access grant
        await _supabase.from('family_access').insert({
          'user_id': currentUserId,
          'shared_with_user_id': familyMemberUserId,
          'document_id': documentId,
          'permission': permission,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      throw FamilyAccessException('Failed to grant access: $e');
    }
  }

  /// Revoke family member access to document
  Future<void> revokeAccess({
    required int documentId,
    required String familyMemberUserId,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw FamilyAccessException('User not authenticated');
      }

      await _supabase
          .from('family_access')
          .delete()
          .eq('document_id', documentId)
          .eq('user_id', currentUserId)
          .eq('shared_with_user_id', familyMemberUserId);
    } catch (e) {
      throw FamilyAccessException('Failed to revoke access: $e');
    }
  }

  /// Get all users who have access to document
  Future<List<Map<String, dynamic>>> getDocumentAccessList(
      int documentId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw FamilyAccessException('User not authenticated');
      }

      final response = await _supabase
          .from('family_access')
          .select('*, users:shared_with_user_id(id, email, raw_user_meta_data)')
          .eq('document_id', documentId)
          .eq('user_id', currentUserId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw FamilyAccessException('Failed to get access list: $e');
    }
  }

  /// Get all documents shared with current user
  Future<List<Map<String, dynamic>>> getSharedWithMeDocuments() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw FamilyAccessException('User not authenticated');
      }

      final response = await _supabase
          .from('family_access')
          .select('*, documents(*)')
          .eq('shared_with_user_id', currentUserId)
          .neq('permission', 'none');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw FamilyAccessException('Failed to get shared documents: $e');
    }
  }

  /// Check if current user has access to document
  /// Returns permission level: 'view', 'edit', or null
  Future<String?> checkAccess(int documentId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return null;

      // Check if user owns document
      final ownedDoc = await _supabase
          .from('documents')
          .select('id')
          .eq('id', documentId)
          .eq('user_id', currentUserId)
          .maybeSingle();

      if (ownedDoc != null) {
        return 'edit'; // Owner has full access
      }

      // Check if document is shared with user
      final sharedAccess = await _supabase
          .from('family_access')
          .select('permission')
          .eq('document_id', documentId)
          .eq('shared_with_user_id', currentUserId)
          .maybeSingle();

      return sharedAccess?['permission'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Get family members (users who have been granted access to any document)
  Future<List<Map<String, dynamic>>> getFamilyMembers() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw FamilyAccessException('User not authenticated');
      }

      final response = await _supabase
          .from('family_access')
          .select(
              'shared_with_user_id, users:shared_with_user_id(id, email, raw_user_meta_data)')
          .eq('user_id', currentUserId);

      final uniqueUsers = <String, Map<String, dynamic>>{};
      for (var access in response) {
        final userId = access['shared_with_user_id'] as String;
        if (!uniqueUsers.containsKey(userId)) {
          uniqueUsers[userId] = access['users'] as Map<String, dynamic>;
        }
      }

      return uniqueUsers.values.toList();
    } catch (e) {
      throw FamilyAccessException('Failed to get family members: $e');
    }
  }

  /// Update permission for existing access
  Future<void> updatePermission({
    required int documentId,
    required String familyMemberUserId,
    required String newPermission,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw FamilyAccessException('User not authenticated');
      }

      await _supabase
          .from('family_access')
          .update({'permission': newPermission})
          .eq('document_id', documentId)
          .eq('user_id', currentUserId)
          .eq('shared_with_user_id', familyMemberUserId);
    } catch (e) {
      throw FamilyAccessException('Failed to update permission: $e');
    }
  }

  /// Bulk grant access to multiple documents
  Future<void> bulkGrantAccess({
    required List<int> documentIds,
    required String familyMemberEmail,
    required String permission,
  }) async {
    try {
      for (var documentId in documentIds) {
        await grantAccess(
          documentId: documentId,
          familyMemberEmail: familyMemberEmail,
          permission: permission,
        );
      }
    } catch (e) {
      throw FamilyAccessException('Bulk grant failed: $e');
    }
  }

  /// Remove all access for a family member
  Future<void> removeFamilyMember(String familyMemberUserId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw FamilyAccessException('User not authenticated');
      }

      await _supabase
          .from('family_access')
          .delete()
          .eq('user_id', currentUserId)
          .eq('shared_with_user_id', familyMemberUserId);
    } catch (e) {
      throw FamilyAccessException('Failed to remove family member: $e');
    }
  }
}

/// Custom exception for family access errors
class FamilyAccessException implements Exception {
  final String message;
  FamilyAccessException(this.message);

  @override
  String toString() => message;
}
