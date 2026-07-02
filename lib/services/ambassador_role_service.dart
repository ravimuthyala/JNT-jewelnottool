import 'package:supabase_flutter/supabase_flutter.dart';

class AmbassadorRoleService {
  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
  }

  static bool _isAmbassadorFromData(Map<String, dynamic> data) {
    String norm(Object? value) => (value ?? '').toString().trim().toLowerCase();
    final profile = _asMap(data['profile']);
    final basic = _asMap(data['basic']);
    final client = _asMap(data['client']);
    final ascension = _asMap(data['ascension']);
    final profileAscension = _asMap(profile['ascension']);
    final basicAscension = _asMap(basic['ascension']);
    final clientAscension = _asMap(client['ascension']);

    bool hasTag(Object? raw) {
      if (raw is! List) return false;
      for (final item in raw) {
        final value = norm(item).replaceAll('_', ' ');
        if (value == 'ambassador' || value.contains('ambassador')) {
          return true;
        }
      }
      return false;
    }

    final statuses = <String>[
      norm(ascension['status']),
      norm(profileAscension['status']),
      norm(basicAscension['status']),
      norm(clientAscension['status']),
      norm(data['status']),
      norm(data['partnerStatus']),
      norm(data['tier']),
      norm(profile['status']),
      norm(profile['partnerStatus']),
      norm(profile['tier']),
      norm(basic['status']),
      norm(basic['partnerStatus']),
      norm(basic['tier']),
    ];
    for (final status in statuses) {
      final normalized = status.replaceAll('_', ' ');
      if (normalized == 'ambassador' ||
          (normalized.contains('ambassador') &&
              !normalized.contains('not ambassador'))) {
        return true;
      }
    }

    return hasTag(data['accountTags']) ||
        hasTag(profile['accountTags']) ||
        hasTag(basic['accountTags']) ||
        hasTag(client['accountTags']) ||
        hasTag(ascension['tags']) ||
        hasTag(profileAscension['tags']) ||
        hasTag(basicAscension['tags']) ||
        hasTag(clientAscension['tags']);
  }

  static Future<bool> currentUserIsAmbassador({String fallbackEmail = ''}) async {
    final user = Supabase.instance.client.auth.currentUser;
    final uid = (user?.id ?? '').trim();
    final email = (user?.email ?? fallbackEmail).trim().toLowerCase();
    if (uid.isEmpty && email.isEmpty) return false;

    for (final table in const <String>['client_artist', 'client']) {
      try {
        List<dynamic> rows = const <dynamic>[];
        if (uid.isNotEmpty) {
          rows = await Supabase.instance.client
              .from(table)
              .select()
              .eq('id', uid)
              .limit(5);
        }
        if (rows.isEmpty && email.isNotEmpty) {
          rows = await Supabase.instance.client
              .from(table)
              .select()
              .eq('email', email)
              .limit(10);
        }
        for (final row in rows) {
          if (_isAmbassadorFromData(_asMap(row))) return true;
        }
      } catch (_) {}
    }
    return false;
  }
}
