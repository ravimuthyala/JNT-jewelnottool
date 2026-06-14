import 'package:cloud_firestore/cloud_firestore.dart';

class AuthEmailAliasService {
  static const String _collection = 'auth_email_aliases';

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
    await FirebaseFirestore.instance.collection(_collection).doc(normalizedLogin).set({
      'loginEmail': normalizedLogin,
      'authEmail': normalizedAuth,
      'uid': uid.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<String?> resolveAuthEmailForLogin(String loginEmail) async {
    try {
      final normalized = loginEmail.trim().toLowerCase();
      if (normalized.isEmpty) return null;
      final snap = await FirebaseFirestore.instance
          .collection(_collection)
          .doc(normalized)
          .get();
      final data = snap.data();
      if (data == null) return null;
      final authEmail = (data['authEmail'] ?? '').toString().trim().toLowerCase();
      if (authEmail.isEmpty) return null;
      return authEmail;
    } catch (_) {
      // Avoid blocking login if anonymous reads are restricted by Firestore rules.
      return null;
    }
  }

  static Future<String?> resolveUidForLogin(String loginEmail) async {
    try {
      final normalized = loginEmail.trim().toLowerCase();
      if (normalized.isEmpty) return null;
      final snap = await FirebaseFirestore.instance
          .collection(_collection)
          .doc(normalized)
          .get();
      final data = snap.data();
      if (data == null) return null;
      final uid = (data['uid'] ?? '').toString().trim();
      if (uid.isEmpty) return null;
      return uid;
    } catch (_) {
      return null;
    }
  }
}
