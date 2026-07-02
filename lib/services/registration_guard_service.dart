import 'package:supabase_flutter/supabase_flutter.dart';

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

    final supabase = Supabase.instance.client;
    try {
      for (final collection in _collections) {
        final rows = await supabase.from(collection).select('id').eq('email', normalized).limit(1);
        if (rows.isNotEmpty) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
