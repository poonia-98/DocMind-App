// auth_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  
  Future<void> login(String email, String password)
  
   async {
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.session == null) {
      throw Exception('Login failed');
    }
  }

  
  Future<void> signup(String email, String password) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
    );

    if (response.session == null && response.user == null) {
      throw Exception('Signup failed');
    }
  }

  
  Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  
  Future<String?> getToken() async {



    final session = _supabase.auth.currentSession;


    if (session == null) return null;

    
    final expiresAt = session.expiresAt;
    if (expiresAt != null &&
        DateTime.now().millisecondsSinceEpoch / 1000 >= expiresAt) {
      


      try {
        final refreshResponse = await _supabase.auth.refreshSession();
       
        return refreshResponse.session?.accessToken;
      } 
      
      catch (e) {
        print('Token refresh failed: $e');
        return null;
      }
    }

    return session.accessToken;
  }

  
  Future<bool> isAuthenticated() 
  
  
  async {
    final session = _supabase.auth.currentSession;

    if (session == null) return false;

    
    final expiresAt = session.expiresAt;
    if (expiresAt != null &&
        DateTime.now().millisecondsSinceEpoch / 1000 >= expiresAt) {
      return false;
    }

    return true;
  }

  
  User? get currentUser {
    return _supabase.auth.currentUser;
  }

  
  String? get userId {
    return _supabase.auth.currentUser?.id;
  }

  
  Stream<AuthState> get authStateChanges 
  
  {
    return _supabase.auth.onAuthStateChange;
  }
}
