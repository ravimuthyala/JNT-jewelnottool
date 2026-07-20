import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthEmailAliasService {
  static const String _collection = 'auth_email_aliases';
  static SupabaseClient get _supabase => Supabase.instance.client;

  static Future<void> saveAliasMapping({
    required String loginEmail,
    required String authEmail,
    required String uid,
  }) async {
    final normalizedLogin = loginEmail.trim().toLowerCase();
    final normalizedAuth = authEmail.trim().toLowerCase();
    if (normalizedLogin.isEmpty || normalizedAuth.isEmpty || uid.trim().isEmpty) {
      return;
    }
    final payload = <String, dynamic>{
      'id': uid.trim(),
      'login_email': normalizedLogin,
      'auth_email': normalizedAuth,
      'uid': uid.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    try {
      final existing = await _supabase
          .from(_collection)
          .select('login_email')
          .eq('login_email', normalizedLogin)
          .maybeSingle();
      if (existing == null) {
        await _supabase.from(_collection).insert(payload);
      } else {
        await _supabase
            .from(_collection)
            .update(payload)
            .eq('login_email', normalizedLogin);
      }
    } catch (e) {
      debugPrint('AuthEmailAliasService.saveAliasMapping failed: $e');
    }
  }

  static Future<String?> resolveAuthEmailForLogin(String loginEmail) async {
    try {
      final normalized = loginEmail.trim().toLowerCase();
      if (normalized.isEmpty) return null;
      final data = await _supabase
          .from(_collection)
          .select()
          .eq('login_email', normalized)
          .maybeSingle();
      if (data == null) return null;
      final map = Map<String, dynamic>.from(data);
      final authEmail = (map['auth_email'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      if (authEmail.isEmpty) return null;
      return authEmail;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> resolveUidForLogin(String loginEmail) async {
    try {
      final normalized = loginEmail.trim().toLowerCase();
      if (normalized.isEmpty) return null;
      final data = await _supabase
          .from(_collection)
          .select()
          .eq('login_email', normalized)
          .maybeSingle();
      if (data == null) return null;
      final map = Map<String, dynamic>.from(data);
      final uid = (map['uid'] ?? '').toString().trim();
      if (uid.isEmpty) return null;
      return uid;
    } catch (_) {
      return null;
    }
  }
}
