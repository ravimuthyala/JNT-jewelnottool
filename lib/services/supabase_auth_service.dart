import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_bootstrap.dart';

class SupabaseAuthService {
  static SupabaseClient get _client => SupabaseBootstrap.client;

  static User? get currentUser => _client.auth.currentUser;

  static String? get currentUserId => _client.auth.currentUser?.id;

  static Future<User?> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password.trim(),
    );

    return response.user;
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
  static Future<void> logout() async {
    await _client.auth.signOut();
  }
}