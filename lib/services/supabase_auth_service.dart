import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_bootstrap.dart';

class SupabaseAuthService {
  static SupabaseClient get _client => SupabaseBootstrap.client;

  static User? get currentUser => _client.auth.currentUser;

  static String? get currentUserId => _client.auth.currentUser?.id;

  /// Role tables that each represent a distinct registered account. An email
  /// must map to exactly one account, never more than one of these.
  static const List<String> roleTables = <String>[
    'client',
    'artist',
    'company',
    'client_artist',
  ];

  /// Deliberately generic (no role name) so the message doesn't reveal
  /// which role an email is registered under, for either ADA or non-ADA
  /// users, and is identical across every registration flow.
  static const String emailAlreadyRegisteredMessage =
      'This email is already registered. Please use a different email.';

  /// Returns the role table where [email] is already registered, or null if
  /// the email isn't used by any existing account.
  ///
  /// This calls the `find_existing_role_for_email` Postgres function (see
  /// supabase/migrations/20260721203926_add_find_existing_role_for_email_rpc.sql)
  /// rather than selecting from the role tables directly: RLS on
  /// client/client_artist only allows reading your own row, and
  /// artist/company require an authenticated session, which registration
  /// typically doesn't have yet — a direct `.select().eq('email', ...)` here
  /// silently returns no rows and reports every duplicate email as
  /// available. The RPC is SECURITY DEFINER so it can check regardless of
  /// the caller's session, but only ever returns a role name, never row
  /// data.
  static Future<String?> findExistingRoleForEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || !normalized.contains('@')) return null;

    try {
      final result = await _client.rpc(
        'find_existing_role_for_email',
        params: {'p_email': normalized},
      );
      if (result is String && result.isNotEmpty) return result;
      return null;
    } catch (e) {
      debugPrint('SupabaseAuthService.findExistingRoleForEmail failed: $e');
      return null;
    }
  }

  static Future<User?> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password.trim(),
      );

      return response.user;
    } catch (e) {
      debugPrint('SupabaseAuthService.login failed: $e');
      rethrow;
    }
  }

  static Future<User?> signup({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password.trim(),
      );

      print('SIGNUP SUCCESS');
      print(response.user?.id);

      return response.user;
    } catch (e) {
      print('SIGNUP ERROR');
      print(e);
      rethrow;
    }
  }

  static Future<void> sendPasswordResetEmail({
    required String email,
    String? redirectTo,
  }) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: redirectTo,
      );
    } catch (e) {
      debugPrint('SupabaseAuthService.sendPasswordResetEmail failed: $e');
      rethrow;
    }
  }

  static Future<void> updatePassword(String password) async {
    try {
      await _client.auth.updateUser(
        UserAttributes(password: password.trim()),
      );
    } catch (e) {
      debugPrint('SupabaseAuthService.updatePassword failed: $e');
      rethrow;
    }
  }
  static Future<void> logout() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      debugPrint('SupabaseAuthService.logout failed: $e');
      rethrow;
    }
  }
}
