// lib/core/auth/auth_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ✅ LOGIN
  Future<void> login(String email, String password) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.session == null) {
      throw Exception('Login failed');
    }
  }

  // ✅ SIGNUP
  Future<void> signup(String email, String password) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
    );

    if (response.session == null && response.user == null) {
      throw Exception('Signup failed');
    }
  }

  // ✅ LOGOUT
  Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  // ✅ TOKEN (REAL SUPABASE JWT)
  Future<String?> getToken() async {
    final session = _supabase.auth.currentSession;
    if (session == null) return null;

    // Check if token is expired
    final expiresAt = session.expiresAt;
    if (expiresAt != null &&
        DateTime.now().millisecondsSinceEpoch / 1000 >= expiresAt) {
      // Refresh the session
      try {
        final refreshResponse = await _supabase.auth.refreshSession();
        return refreshResponse.session?.accessToken;
      } catch (e) {
        print('Token refresh failed: $e');
        return null;
      }
    }

    return session.accessToken;
  }

  // ✅ AUTH CHECK (Fixed: Now returns Future<bool>)
  Future<bool> isAuthenticated() async {
    final session = _supabase.auth.currentSession;

    if (session == null) return false;

    // Verify token is not expired
    final expiresAt = session.expiresAt;
    if (expiresAt != null &&
        DateTime.now().millisecondsSinceEpoch / 1000 >= expiresAt) {
      return false;
    }

    return true;
  }

  // ✅ USER INFO
  User? get currentUser {
    return _supabase.auth.currentUser;
  }

  // ✅ USER ID
  String? get userId {
    return _supabase.auth.currentUser?.id;
  }

  // ✅ AUTH STATE STREAM
  Stream<AuthState> get authStateChanges {
    return _supabase.auth.onAuthStateChange;
  }
}
