import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/auth_flags.dart';
// import '../config/environment.dart'; -- see _simulateAuthEmails below.
import 'supabase_bootstrap.dart';

class SupabaseAuthService {
  static SupabaseClient get _client => SupabaseBootstrap.client;

  static User? get currentUser => _client.auth.currentUser;

  static String? get currentUserId => _client.auth.currentUser?.id;

  /// See [kSimulateAuthEmailSending]. The safer, original version of this
  /// getter hard-blocked simulation outside dev/UAT:
  ///
  ///   static bool get _simulateAuthEmails =>
  ///       kSimulateAuthEmailSending && !Environment.isProduction;
  ///
  /// That guard is commented out (not deleted) below, at explicit request,
  /// so simulation is deliberately active in EVERY environment INCLUDING
  /// Production for now, while Production's real SMTP isn't configured
  /// yet. That means Production can currently create pre-confirmed users
  /// and generate password-reset links via the Admin API without owning
  /// the inbox. Uncomment the `&& !Environment.isProduction` clause above
  /// (restoring the import too) -- or flip [kSimulateAuthEmailSending] off
  /// -- once real SMTP is verified working end-to-end and this is no
  /// longer needed anywhere.
  static bool get _simulateAuthEmails =>
      kSimulateAuthEmailSending /* && !Environment.isProduction */;

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
    final normalizedEmail = email.trim();
    final normalizedPassword = password.trim();
    try {
      if (_simulateAuthEmails) {
        return await _simulateSignup(
          email: normalizedEmail,
          password: normalizedPassword,
        );
      }

      final response = await _client.auth.signUp(
        email: normalizedEmail,
        password: normalizedPassword,
      );

      return response.user;
    } catch (e) {
      debugPrint('SupabaseAuthService.signup failed: $e');
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

  /// Returns the recovery link when [kSimulateAuthEmailSending] produced one
  /// instead of a real email (test-only, dev/UAT only) -- null in the real
  /// send path, which is the normal production behavior. Callers should
  /// only expect a non-null value while actively testing.
  static Future<String?> sendPasswordResetEmail({
    required String email,
    String? redirectTo,
  }) async {
    final normalizedEmail = email.trim();
    try {
      if (_simulateAuthEmails) {
        return await _simulateGenerateResetLink(
          email: normalizedEmail,
          redirectTo: redirectTo,
        );
      }

      await _client.auth.resetPasswordForEmail(
        normalizedEmail,
        redirectTo: redirectTo,
      );
      return null;
    } catch (e) {
      debugPrint('SupabaseAuthService.sendPasswordResetEmail failed: $e');
      rethrow;
    }
  }

  /// TEST-ONLY path used while [kSimulateAuthEmailSending] is on -- creates
  /// a pre-confirmed user via the Auth Admin API (admin-auth-simulate edge
  /// function) instead of calling the real signUp(), so no confirmation
  /// email is sent and the built-in mailer's rate limit is never touched.
  /// Then signs in immediately to get a real session, matching what a real
  /// signUp() would have produced.
  static Future<User?> _simulateSignup({
    required String email,
    required String password,
  }) async {
    final data = await _invokeSimulate('create_confirmed_user', {
      'email': email,
      'password': password,
    });

    if (data['userId'] == null) {
      throw const AuthException('Unable to create user (simulation).');
    }

    return login(email: email, password: password);
  }

  /// TEST-ONLY path used while [kSimulateAuthEmailSending] is on -- returns
  /// the real recovery link directly (via the Auth Admin API) instead of
  /// emailing it, so the reset flow can be exercised without a real inbox.
  static Future<String> _simulateGenerateResetLink({
    required String email,
    String? redirectTo,
  }) async {
    final data = await _invokeSimulate('generate_reset_link', {
      'email': email,
      if (redirectTo != null) 'redirectTo': redirectTo,
    });

    final link = data['actionLink']?.toString();
    if (link == null || link.isEmpty) {
      throw const AuthException('Unable to generate reset link (simulation).');
    }
    return link;
  }

  /// Shared caller for the admin-auth-simulate edge function. Normalizes
  /// every failure mode (function-level error response, transport-level
  /// FunctionException) into an [AuthException] so existing catch blocks in
  /// registration/forgot-password pages (which only expect AuthException)
  /// keep working unchanged regardless of whether simulation is on.
  static Future<Map<String, dynamic>> _invokeSimulate(
    String action,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _client.functions.invoke(
        'admin-auth-simulate',
        body: {'action': action, ...body},
        headers: {'x-simulate-secret': kAuthSimulateSharedSecret},
      );

      final data = res.data;
      final errorMessage = data is Map ? data['error']?.toString() : null;
      if (errorMessage != null) {
        throw AuthException(errorMessage);
      }
      if (data is! Map<String, dynamic>) {
        throw const AuthException('Unexpected simulation response.');
      }
      return data;
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map ? details['error']?.toString() : null;
      throw AuthException(
        message ?? e.reasonPhrase ?? 'Simulation request failed.',
      );
    }
  }
}
