import 'package:supabase_flutter/supabase_flutter.dart';

class AmbassadorRoleService {
  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
  }

  static bool isAmbassadorFromData(Map<String, dynamic> data) {
    String norm(Object? value) => (value ?? '').toString().trim().toLowerCase();
    final profile = _asMap(data['profile']);
    final basic = _asMap(data['basic']);
    final client = _asMap(data['client']);
    final ascension = _asMap(data['ascension']);
    final profileAscension = _asMap(profile['ascension']);
    final basicAscension = _asMap(basic['ascension']);
    final clientAscension = _asMap(client['ascension']);

    bool hasAmbassadorMarker(Object? raw) {
      if (raw is Iterable) {
        return raw.any(hasAmbassadorMarker);
      }
      if (raw is Map) {
        return raw.entries.any(
          (entry) =>
              hasAmbassadorMarker(entry.key) ||
              hasAmbassadorMarker(entry.value),
        );
      }
      final value = norm(raw).replaceAll('_', ' ').replaceAll('-', ' ');
      return value == 'ambassador' ||
          (value.contains('ambassador') && !value.contains('not ambassador'));
    }

    final statuses = <String>[
      norm(ascension['status']),
      norm(ascension['partnerStatus']),
      norm(ascension['partner_status']),
      norm(ascension['tier']),
      norm(ascension['levelName']),
      norm(ascension['level_name']),
      norm(profileAscension['status']),
      norm(profileAscension['tier']),
      norm(profileAscension['levelName']),
      norm(basicAscension['status']),
      norm(basicAscension['tier']),
      norm(basicAscension['levelName']),
      norm(clientAscension['status']),
      norm(clientAscension['tier']),
      norm(clientAscension['levelName']),
      norm(data['status']),
      norm(data['partnerStatus']),
      norm(data['partner_status']),
      norm(data['tier']),
      norm(profile['status']),
      norm(profile['partnerStatus']),
      norm(profile['partner_status']),
      norm(profile['tier']),
      norm(basic['status']),
      norm(basic['partnerStatus']),
      norm(basic['partner_status']),
      norm(basic['tier']),
      norm(client['status']),
      norm(client['partnerStatus']),
      norm(client['partner_status']),
      norm(client['tier']),
    ];
    for (final status in statuses) {
      final normalized = status.replaceAll('_', ' ');
      if (normalized == 'ambassador' ||
          (normalized.contains('ambassador') &&
              !normalized.contains('not ambassador'))) {
        return true;
      }
    }

    return hasAmbassadorMarker(data['accountTags']) ||
        hasAmbassadorMarker(data['account_tags']) ||
        hasAmbassadorMarker(profile['accountTags']) ||
        hasAmbassadorMarker(profile['account_tags']) ||
        hasAmbassadorMarker(basic['accountTags']) ||
        hasAmbassadorMarker(basic['account_tags']) ||
        hasAmbassadorMarker(client['accountTags']) ||
        hasAmbassadorMarker(client['account_tags']) ||
        hasAmbassadorMarker(ascension['tags']) ||
        hasAmbassadorMarker(profileAscension['tags']) ||
        hasAmbassadorMarker(basicAscension['tags']) ||
        hasAmbassadorMarker(clientAscension['tags']);
  }

  static Future<bool> currentUserIsAmbassador({
    String fallbackEmail = '',
  }) async {
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
          if (isAmbassadorFromData(_asMap(row))) return true;
        }
      } catch (_) {}
    }
    return false;
  }
}
