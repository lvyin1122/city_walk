import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Stream to listen to auth state changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // Get persisted session
  Session? get currentSession => _supabase.auth.currentSession;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final AuthResponse response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );
      return response;
    } catch (error) {
      throw Exception('Sign up failed: $error');
    }
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final AuthResponse response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } catch (error) {
      throw Exception('Sign in failed: $error');
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (error) {
      throw Exception('Sign out failed: $error');
    }
  }

  bool isAuthenticated() {
    return currentSession != null;
  }

  User? getCurrentUser() {
    return currentSession?.user;
  }

  // Refresh session if needed
  Future<void> refreshSession() async {
    try {
      if (currentSession?.isExpired == true) {
        await _supabase.auth.refreshSession();
      }
    } catch (error) {
      throw Exception('Failed to refresh session: $error');
    }
  }

  // Get user metadata
  Map<String, dynamic>? getUserMetadata() {
    return getCurrentUser()?.userMetadata;
  }
} 