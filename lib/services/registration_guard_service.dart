import 'package:cloud_firestore/cloud_firestore.dart';

class RegistrationGuardService {
  static const _collections = <String>[
    'client',
    'artist',
    'client_artist',
    'company',
  ];

  static Future<bool> emailExists(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return false;

    final firestore = FirebaseFirestore.instance;
    try {
      for (final collection in _collections) {
        final snap = await firestore
            .collection(collection)
            .where('email', isEqualTo: normalized)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) return true;
      }
      return false;
    } on FirebaseException {
      // Do not block account creation when read rules prevent lookup.
      return false;
    } catch (_) {
      return false;
    }
  }
}
