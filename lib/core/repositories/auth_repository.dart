import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for authentication-related Supabase operations.
/// Abstracts direct Supabase calls from UI screens.
class AuthRepository {
  final SupabaseClient _client;

  AuthRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Sends a password reset email to the specified email address.
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  /// Gets the current authentication session.
  Session? get currentSession => _client.auth.currentSession;

  /// Gets the current user.
  User? get currentUser => _client.auth.currentUser;

  /// Stream of authentication state changes.
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Signs out the current user.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Signs in with email and password.
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Signs up with email and password.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: data,
    );
  }
}
