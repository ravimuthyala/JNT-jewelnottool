import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ArtistDirectoryEntry {
  const ArtistDirectoryEntry({
    required this.id,
    required this.name,
    required this.rating,
    required this.email,
    required this.city,
    required this.state,
    required this.budgetMin,
    required this.budgetMax,
    required this.credential,
    required this.avatarUrl,
    required this.bio,
    required this.projectNotes,
    required this.portfolioImages,
    required this.acceptsDirectRequests,
    required this.acceptsNfcRequests,
    required this.tierLabel,
  });

  final String id;
  final String name;
  final double rating;
  final String email;
  final String city;
  final String state;
  final int budgetMin;
  final int budgetMax;
  final String credential;
  final String avatarUrl;
  final String bio;
  final String projectNotes;
  final List<String> portfolioImages;
  final bool acceptsDirectRequests;
  final bool acceptsNfcRequests;
  final String tierLabel;

  ArtistDirectoryEntry copyWith({
    String? id,
    String? name,
    double? rating,
    String? email,
    String? city,
    String? state,
    int? budgetMin,
    int? budgetMax,
    String? credential,
    String? avatarUrl,
    String? bio,
    String? projectNotes,
    List<String>? portfolioImages,
    bool? acceptsDirectRequests,
    bool? acceptsNfcRequests,
    String? tierLabel,
  }) {
    return ArtistDirectoryEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      rating: rating ?? this.rating,
      email: email ?? this.email,
      city: city ?? this.city,
      state: state ?? this.state,
      budgetMin: budgetMin ?? this.budgetMin,
      budgetMax: budgetMax ?? this.budgetMax,
      credential: credential ?? this.credential,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      projectNotes: projectNotes ?? this.projectNotes,
      portfolioImages: portfolioImages ?? this.portfolioImages,
      acceptsDirectRequests:
          acceptsDirectRequests ?? this.acceptsDirectRequests,
      acceptsNfcRequests: acceptsNfcRequests ?? this.acceptsNfcRequests,
      tierLabel: tierLabel ?? this.tierLabel,
    );
  }
}

class ArtistDirectoryService {
  static const int _defaultPageSize = 200;
  static const int _defaultMaxRows = 1200;

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<List<ArtistDirectoryEntry>> fetchHomeArtistsRandomized({
    int limit = 12,
    DateTime? now,
    bool hydrateMediaFallbacks = false,
  }) async {
    final seed = _dailySeed(now ?? DateTime.now());
    final merged = <ArtistDirectoryEntry>[];
    final byKey = <String, int>{};

    Future<void> addRows(List<Map<String, dynamic>> rows) async {
      for (final row in rows) {
        final entry = _fromRow(row);
        if (entry == null) continue;
        final dedupeKey = entry.email.isNotEmpty
            ? entry.email.toLowerCase()
            : entry.id;
        final existingIndex = byKey[dedupeKey];
        if (existingIndex == null) {
          byKey[dedupeKey] = merged.length;
          merged.add(entry);
        } else {
          merged[existingIndex] = _preferRicherEntry(
            merged[existingIndex],
            entry,
          );
        }
      }
    }

    try {
      final perTable = (limit * 3).clamp(16, 80);
      await addRows(await _fetchRows('artist', maxRows: perTable));
      await addRows(await _fetchRows('client_artist', maxRows: perTable));
    } catch (_) {
      // Fall through to the slower full fetch below.
    }

    if (merged.length < limit) {
      final all = await fetchAllArtists(
        hydrateMediaFallbacks: hydrateMediaFallbacks,
      );
      all.sort(
        (a, b) => _stableHash(
          '${a.id}|$seed',
        ).compareTo(_stableHash('${b.id}|$seed')),
      );
      for (final entry in all) {
        final dedupeKey = entry.email.isNotEmpty
            ? entry.email.toLowerCase()
            : entry.id;
        final existingIndex = byKey[dedupeKey];
        if (existingIndex == null) {
          byKey[dedupeKey] = merged.length;
          merged.add(entry);
        } else {
          merged[existingIndex] = _preferRicherEntry(
            merged[existingIndex],
            entry,
          );
        }
        if (merged.length >= limit) break;
      }
    }

    merged.sort(
      (a, b) =>
          _stableHash('${a.id}|$seed').compareTo(_stableHash('${b.id}|$seed')),
    );
    final limited = merged.take(limit).toList(growable: false);
    if (!hydrateMediaFallbacks) return limited;
    return _hydrateMissingPortfolios(limited);
  }

  static Future<List<ArtistDirectoryEntry>> fetchAllArtists({
    bool hydrateMediaFallbacks = true,
    int maxDocsPerCollection = _defaultMaxRows,
  }) async {
    final artistRows = await _fetchRows(
      'artist',
      maxRows: maxDocsPerCollection,
    );
    final clientArtistRows = await _fetchRows(
      'client_artist',
      maxRows: maxDocsPerCollection,
    );

    final merged = <ArtistDirectoryEntry>[];
    final byKey = <String, int>{};

    void addAll(List<Map<String, dynamic>> rows) {
      for (final row in rows) {
        final entry = _fromRow(row);
        if (entry == null) continue;
        final dedupeKey = entry.email.isNotEmpty
            ? entry.email.toLowerCase()
            : entry.id;
        final existingIndex = byKey[dedupeKey];
        if (existingIndex == null) {
          byKey[dedupeKey] = merged.length;
          merged.add(entry);
        } else {
          merged[existingIndex] = _preferRicherEntry(
            merged[existingIndex],
            entry,
          );
        }
      }
    }

    addAll(artistRows);
    addAll(clientArtistRows);

    merged.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (!hydrateMediaFallbacks) return merged;
    return _hydrateMissingPortfolios(merged);
  }

  static Future<List<Map<String, dynamic>>> _fetchRows(
    String table, {
    int maxRows = _defaultMaxRows,
  }) async {
    final rows = <Map<String, dynamic>>[];
    const pageSize = _defaultPageSize;
    var offset = 0;

    try {
      while (rows.length < maxRows) {
        final pageLimit = (maxRows - rows.length).clamp(1, pageSize);
        final page = await _client
            .from(table)
            .select()
            .order('id')
            .range(offset, offset + pageLimit - 1);
        if (page.isEmpty) break;

        final mapped = page
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(growable: false);
        rows.addAll(mapped);
        if (mapped.length < pageLimit) break;
        offset += mapped.length;
      }
    } catch (e) {
      debugPrint('ArtistDirectoryService._fetchRows($table) failed: $e');
      return rows;
    }

    return rows;
  }

  static Future<List<ArtistDirectoryEntry>> _hydrateMissingPortfolios(
    List<ArtistDirectoryEntry> entries,
  ) async {
    if (entries.isEmpty) return entries;
    final hydrated = await Future.wait(
      entries.map((entry) async {
        var next = entry;
        if (next.portfolioImages.isEmpty) {
          final fallback = await _loadPortfolioItemsFromStorage(
            next.id,
            email: next.email,
          );
          if (fallback.isNotEmpty) {
            next = next.copyWith(portfolioImages: fallback);
          }
        }
        if (next.avatarUrl.trim().isEmpty) {
          final avatar = await _loadAvatarFromStorage(
            next.id,
            email: next.email,
          );
          if (avatar.trim().isNotEmpty) {
            next = next.copyWith(avatarUrl: avatar.trim());
          }
        }
        return next;
      }),
    );
    return hydrated;
  }

  static Future<String> _loadAvatarFromStorage(
    String uid, {
    String email = '',
  }) async {
    final ids = <String>{uid.trim()}..removeWhere((value) => value.isEmpty);
    if (email.trim().isNotEmpty) {
      for (final table in const <String>['artist', 'client_artist']) {
        try {
          final rows = await _client
              .from(table)
              .select('id')
              .eq('email', email.trim().toLowerCase())
              .limit(4);
          for (final row in rows.whereType<Map>()) {
            final id = (row['id'] ?? '').toString().trim();
            if (id.isNotEmpty) ids.add(id);
          }
        } catch (_) {}
      }
    }

    for (final id in ids) {
      for (final bucket in const <String>['profile-pictures']) {
        final paths = <String>[
          'artists/$id/profile/avatar.jpg',
          'artists/$id/profile/avatar.jpeg',
          'artists/$id/profile/avatar.png',
          'artists/$id/profile/avatar.webp',
          'client_artists/$id/profile/avatar.jpg',
          'client_artists/$id/profile/avatar.jpeg',
          'client_artists/$id/profile/avatar.png',
          'client_artists/$id/profile/avatar.webp',
        ];
        for (final path in paths) {
          final publicUrl = _client.storage
              .from(bucket)
              .getPublicUrl(path)
              .trim();
          if (publicUrl.isNotEmpty) return publicUrl;
        }

        try {
          final artistEntries = await _listStorageFiles(
            bucket,
            'artists/$id/profile',
          );
          final clientArtistEntries = await _listStorageFiles(
            bucket,
            'client_artists/$id/profile',
          );
          final candidate = _pickAvatarPath([
            ...artistEntries,
            ...clientArtistEntries,
          ]);
          if (candidate.isNotEmpty) {
            return _client.storage.from(bucket).getPublicUrl(candidate).trim();
          }
        } catch (_) {}
      }
    }

    return '';
  }

  static Future<List<String>> _loadPortfolioItemsFromStorage(
    String uid, {
    String email = '',
  }) async {
    final ids = <String>{uid.trim()}..removeWhere((value) => value.isEmpty);
    if (email.trim().isNotEmpty) {
      for (final table in const <String>['artist', 'client_artist']) {
        try {
          final rows = await _client
              .from(table)
              .select('id')
              .eq('email', email.trim().toLowerCase())
              .limit(6);
          for (final row in rows.whereType<Map>()) {
            final id = (row['id'] ?? '').toString().trim();
            if (id.isNotEmpty) ids.add(id);
          }
        } catch (_) {}
      }
    }

    final urls = <String>[];
    for (final id in ids) {
      for (final folder in const <String>['artists', 'client_artists']) {
        final portfolioFolder = '$folder/$id/portfolio';
        try {
          final entries = await _listStorageFiles(
            'portfolio-images',
            portfolioFolder,
          );
          for (final entry in entries) {
            final path = entry.trim();
            if (path.isEmpty) continue;
            final resolved = _resolveStorageUrl(
              path.startsWith('portfolio-images/')
                  ? path.substring('portfolio-images/'.length)
                  : path,
              bucket: 'portfolio-images',
            );
            if (resolved.isNotEmpty) urls.add(resolved);
          }
        } catch (_) {}
      }
    }

    final dedup = <String>[];
    final seen = <String>{};
    for (final url in urls) {
      if (seen.add(url)) dedup.add(url);
    }
    return dedup;
  }

  static Future<List<String>> _listStorageFiles(
    String bucket,
    String path,
  ) async {
    final entries = await _client.storage.from(bucket).list(path: path);
    return entries
        .map((file) => '$path/${file.name}'.replaceAll('//', '/'))
        .toList(growable: false);
  }

  static String _pickAvatarPath(List<String> candidates) {
    for (final candidate in candidates) {
      final path = candidate.trim();
      if (path.isEmpty) continue;
      final lower = path.toLowerCase();
      if (lower.contains('/avatar.')) return path;
    }
    return candidates.isNotEmpty ? candidates.first.trim() : '';
  }

  static ArtistDirectoryEntry? _fromRow(Map<String, dynamic> data) {
    final profile = _asMap(
      data['profile'] ??
          data['profile_json'] ??
          data['profileData'] ??
          data['profile_data'],
    );
    final profileAddress = _asMap(profile['address']);
    final basic = _asMap(data['basic'] ?? data['basic_json']);
    final basicAddress = _asMap(basic['address']);
    final address = _asMap(data['address'] ?? data['address_json']);
    final pricing = _asMap(data['pricing'] ?? data['pricing_json']);
    final credentials = _asMap(data['credentials'] ?? data['credentials_json']);
    final artist = _asMap(data['artist'] ?? data['artist_json']);
    final artistAddress = _asMap(artist['address']);
    final artistProfile = _asMap(artist['profile']);
    final artistProfileAddress = _asMap(artistProfile['address']);
    final artistPricing = _asMap(artist['pricing']);
    final artistCredentials = _asMap(artist['credentials']);
    final client = _asMap(data['client']);
    final clientAddress = _asMap(client['address']);
    final clientProfile = _asMap(client['profile']);
    final clientProfileAddress = _asMap(clientProfile['address']);
    final portfolio = _asMap(data['portfolio'] ?? data['portfolio_json']);
    final artistPortfolio = _asMap(artist['portfolio']);
    final ascension = _asMap(data['ascension'] ?? data['ascension_json']);
    final sponsorshipRequest = _asMap(
      data['sponsorshipRequest'] ?? data['sponsorship_request'],
    );

    String firstNonEmpty(List<Object?> values) {
      for (final raw in values) {
        final text = _cleanValue(raw);
        if (text.isNotEmpty) return text;
      }
      return '';
    }

    int asInt(Object? raw, int fallback) {
      if (raw is int) return raw;
      if (raw is num) return raw.round();
      return int.tryParse(_cleanValue(raw)) ?? fallback;
    }

    double asRating(Object? raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse(_cleanValue(raw)) ?? 0;
    }

    bool asBool(Object? raw, bool fallback) {
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      final text = _cleanValue(raw).toLowerCase();
      if (text == 'true' || text == '1' || text == 'yes') return true;
      if (text == 'false' || text == '0' || text == 'no') return false;
      return fallback;
    }

    String resolveImage(Object? raw, {String bucket = 'portfolio-images'}) {
      final value = _cleanValue(raw);
      if (value.isEmpty) return '';
      return _resolveStorageUrl(value, bucket: bucket);
    }

    List<String> collectImageUrls(List<dynamic> rawList) {
      final out = <String>[];
      for (final raw in rawList) {
        if (raw is String) {
          final url = resolveImage(raw);
          if (url.isNotEmpty) out.add(url);
          continue;
        }
        if (raw is Map) {
          final candidate = firstNonEmpty([
            raw['imageUrl'],
            raw['imageURL'],
            raw['downloadUrl'],
            raw['downloadURL'],
            raw['photoUrl'],
            raw['photoURL'],
            raw['url'],
            raw['image'],
            raw['srcUrl'],
            raw['src'],
            raw['path'],
            raw['storagePath'],
            raw['fullPath'],
          ]);
          if (candidate.isNotEmpty) {
            final url = resolveImage(candidate);
            if (url.isNotEmpty) out.add(url);
          }
        }
      }
      return out;
    }

    final rawName = firstNonEmpty([
      profile['displayName'],
      profile['display_name'],
      profile['nameOrStudio'],
      profile['name_or_studio'],
      profile['studioName'],
      profile['studio_name'],
      profile['name'],
      data['panel_displayName'],
      data['panel_display_name'],
      data['panel_nameOrStudio'],
      data['panel_name_or_studio'],
      data['panel_studioName'],
      data['panel_studio_name'],
      data['displayName'],
      data['display_name'],
      data['name'],
    ]);

    final email = firstNonEmpty([
      data['email'],
      data['artist_email'],
      data['artistEmail'],
    ]);
    final name = rawName.isNotEmpty
        ? rawName
        : (email.isNotEmpty
              ? email.split('@').first.trim()
              : (data['id'] ?? '').toString().trim().isNotEmpty
              ? (data['id'] ?? '').toString().trim()
              : 'Artist');

    final city = firstNonEmpty([
      address['city'],
      address['addressCity'],
      basicAddress['city'],
      basicAddress['addressCity'],
      profileAddress['city'],
      profileAddress['addressCity'],
      clientAddress['city'],
      clientAddress['addressCity'],
      clientProfileAddress['city'],
      clientProfileAddress['addressCity'],
      basic['city'],
      basic['addressCity'],
      profile['city'],
      profile['addressCity'],
      clientProfile['city'],
      clientProfile['addressCity'],
      artistProfile['city'],
      artistProfile['addressCity'],
      artistAddress['city'],
      artistAddress['addressCity'],
      artistProfileAddress['city'],
      artistProfileAddress['addressCity'],
      artist['city'],
      artist['addressCity'],
      data['panel_city'],
      data['city'],
    ]);
    final state = firstNonEmpty([
      address['state'],
      basicAddress['state'],
      profileAddress['state'],
      clientAddress['state'],
      clientProfileAddress['state'],
      basic['state'],
      profile['state'],
      clientProfile['state'],
      artistProfile['state'],
      artistAddress['state'],
      artistProfileAddress['state'],
      artist['state'],
      data['panel_state'],
      data['state'],
    ]);
    final minBudget = asInt(
      pricing['minPrice'] ??
          pricing['min_price'] ??
          artistPricing['minPrice'] ??
          artistPricing['min_price'] ??
          data['panel_minPrice'] ??
          data['panel_min_price'] ??
          data['minPrice'] ??
          data['min_price'],
      50,
    );
    final maxBudget = asInt(
      pricing['maxPrice'] ??
          pricing['max_price'] ??
          artistPricing['maxPrice'] ??
          artistPricing['max_price'] ??
          data['panel_maxPrice'] ??
          data['panel_max_price'] ??
          data['maxPrice'] ??
          data['max_price'],
      200,
    );

    final credentialRaw = firstNonEmpty([
      credentials['nailTechType'],
      credentials['nail_tech_type'],
      artistCredentials['nailTechType'],
      artistCredentials['nail_tech_type'],
      data['panel_nailTechType'],
      data['panel_nail_tech_type'],
    ]).toLowerCase();
    final credential = credentialRaw == 'student'
        ? 'Student or unlicensed nail technician'
        : 'Professional Nail Technician';

    final avatarUrl = firstNonEmpty([
      resolveImage(profile['photoUrl'], bucket: 'profile-pictures'),
      resolveImage(profile['photo_url'], bucket: 'profile-pictures'),
      resolveImage(profile['avatarUrl'], bucket: 'profile-pictures'),
      resolveImage(profile['avatar_url'], bucket: 'profile-pictures'),
      resolveImage(profile['profileImageUrl'], bucket: 'profile-pictures'),
      resolveImage(profile['profile_image_url'], bucket: 'profile-pictures'),
      resolveImage(data['panel_profileImageUrl'], bucket: 'profile-pictures'),
      resolveImage(data['panel_profile_image_url'], bucket: 'profile-pictures'),
      resolveImage(data['profileImageUrl'], bucket: 'profile-pictures'),
      resolveImage(data['profile_image_url'], bucket: 'profile-pictures'),
      resolveImage(data['avatarUrl'], bucket: 'profile-pictures'),
      resolveImage(data['avatar_url'], bucket: 'profile-pictures'),
      resolveImage(data['photoUrl'], bucket: 'profile-pictures'),
      resolveImage(data['photo_url'], bucket: 'profile-pictures'),
      resolveImage(artist['photoUrl'], bucket: 'profile-pictures'),
      resolveImage(artist['photo_url'], bucket: 'profile-pictures'),
      resolveImage(artist['avatarUrl'], bucket: 'profile-pictures'),
      resolveImage(artist['avatar_url'], bucket: 'profile-pictures'),
      resolveImage(artist['profileImageUrl'], bucket: 'profile-pictures'),
      resolveImage(artist['profile_image_url'], bucket: 'profile-pictures'),
      resolveImage(
        (data['basic'] as Map<String, dynamic>?)?['profileImageUrl'],
        bucket: 'profile-pictures',
      ),
      resolveImage(
        (data['basic'] as Map<String, dynamic>?)?['avatarUrl'],
        bucket: 'profile-pictures',
      ),
    ]);

    final bio = firstNonEmpty([
      profile['bio'],
      profile['about'],
      profile['aboutMe'],
      data['bio'],
      data['about'],
      data['panel_bio'],
      data['panel_about'],
      artist['bio'],
      artist['about'],
    ]);
    final projectNotes = firstNonEmpty([
      data['projectNotes'],
      data['project_notes'],
      data['panel_projectNotes'],
      data['panel_project_notes'],
      portfolio['projectNotes'],
      portfolio['project_notes'],
      artistPortfolio['projectNotes'],
      artistPortfolio['project_notes'],
      profile['projectNotes'],
      profile['notes'],
      artist['projectNotes'],
    ]);

    final stats = _asMap(data['stats'] ?? data['stats_json']);
    final rating = asRating(
      stats['rating'] ??
          stats['averageRating'] ??
          stats['average_rating'] ??
          data['rating'] ??
          data['averageRating'] ??
          data['average_rating'] ??
          data['panel_rating'],
    );

    final portfolioImages = <String>[
      ...collectImageUrls(_asList(data['portfolioImages'])),
      ...collectImageUrls(_asList(data['portfolio_images'])),
      ...collectImageUrls(_asList(data['panel_artist_portfolioImages'])),
      ...collectImageUrls(_asList(data['panel_artist_portfolio_images'])),
      ...collectImageUrls(_asList(data['panel_portfolioImages'])),
      ...collectImageUrls(_asList(data['panel_portfolio_images'])),
      ...collectImageUrls(_asList(data['portfolioItems'])),
      ...collectImageUrls(_asList(data['portfolio_items'])),
      ...collectImageUrls(_asList(portfolio['images'])),
      ...collectImageUrls(_asList(portfolio['items'])),
      ...collectImageUrls(_asList(artistPortfolio['images'])),
      ...collectImageUrls(_asList(artistPortfolio['items'])),
      ...collectImageUrls(_asList(artist['portfolioImages'])),
      ...collectImageUrls(_asList(artist['portfolio_images'])),
      ...collectImageUrls(_asList(artist['portfolioItems'])),
      ...collectImageUrls(_asList(artist['portfolio_items'])),
    ];
    final dedupedPortfolio = <String>[];
    final seenUrls = <String>{};
    for (final url in portfolioImages) {
      if (seenUrls.add(url)) dedupedPortfolio.add(url);
    }

    final acceptsDirectRequests = asBool(
      data['panel_directRequestsEnabled'] ??
          data['panel_direct_requests_enabled'] ??
          data['panel_artist_directRequestsEnabled'] ??
          data['panel_artist_direct_requests_enabled'] ??
          data['directRequestsEnabled'] ??
          data['direct_requests_enabled'] ??
          profile['directRequestsEnabled'] ??
          profile['direct_requests_enabled'] ??
          _asMap(data['availability'])['directRequestsEnabled'] ??
          _asMap(data['availability'])['direct_requests_enabled'] ??
          _asMap(artist['availability'])['directRequestsEnabled'] ??
          _asMap(artist['availability'])['direct_requests_enabled'] ??
          artist['directRequestsEnabled'] ??
          artist['direct_requests_enabled'],
      false,
    );
    final acceptsNfcRequests = asBool(
      data['panel_nfcRequestEnabled'] ??
          data['panel_nfc_request_enabled'] ??
          data['nfcRequestEnabled'] ??
          data['nfc_request_enabled'] ??
          _asMap(data['availability'])['nfcRequestEnabled'] ??
          _asMap(data['availability'])['nfc_request_enabled'] ??
          _asMap(data['profile'])['nfcRequestEnabled'] ??
          _asMap(data['profile'])['nfc_request_enabled'] ??
          _asMap(artist['availability'])['nfcRequestEnabled'] ??
          _asMap(artist['availability'])['nfc_request_enabled'] ??
          artist['nfcRequestEnabled'] ??
          artist['nfc_request_enabled'],
      false,
    );

    final tierLabel = _resolveTierLabel(<Object?>[
      data['sponsorshipTier'],
      data['sponsorship_tier'],
      data['panel_ascensionLevel'],
      data['panel_ascension_level'],
      profile['ascensionTier'],
      profile['ascension_tier'],
      ascension['tier'],
      ascension['levelName'],
      ascension['level_name'],
      sponsorshipRequest['tier'],
    ]);

    return ArtistDirectoryEntry(
      id: (data['id'] ?? '').toString().trim(),
      name: name,
      rating: rating > 0 ? rating : 0,
      email: email,
      city: city,
      state: state,
      budgetMin: minBudget,
      budgetMax: maxBudget,
      credential: credential,
      avatarUrl: avatarUrl,
      bio: bio,
      projectNotes: projectNotes,
      portfolioImages: dedupedPortfolio,
      acceptsDirectRequests: acceptsDirectRequests,
      acceptsNfcRequests: acceptsNfcRequests,
      tierLabel: tierLabel,
    );
  }

  static String _resolveTierLabel(List<Object?> candidates) {
    for (final raw in candidates) {
      final value = _cleanValue(raw).toLowerCase();
      if (value == 'goldsmith') return 'Goldsmith';
      if (value == 'crowned') return 'Crowned';
      if (value == 'maker') return 'Maker';
    }
    return 'Maker';
  }

  static ArtistDirectoryEntry _preferRicherEntry(
    ArtistDirectoryEntry current,
    ArtistDirectoryEntry incoming,
  ) {
    int score(ArtistDirectoryEntry entry) {
      var value = 0;
      value += entry.portfolioImages.length * 10;
      if (entry.avatarUrl.trim().isNotEmpty) value += 3;
      if (entry.rating > 0) value += 2;
      if (entry.city.trim().isNotEmpty) value += 1;
      if (entry.state.trim().isNotEmpty) value += 1;
      return value;
    }

    final currentScore = score(current);
    final incomingScore = score(incoming);
    if (incomingScore > currentScore) return incoming;
    if (incomingScore < currentScore) return current;

    final currentRange = (current.budgetMax - current.budgetMin).abs();
    final incomingRange = (incoming.budgetMax - incoming.budgetMin).abs();
    return incomingRange > currentRange ? incoming : current;
  }

  static int _dailySeed(DateTime date) =>
      (date.year * 10000) + (date.month * 100) + date.day;

  static int _stableHash(String value) {
    var hash = 5381;
    for (final codeUnit in value.codeUnits) {
      hash = ((hash << 5) + hash) ^ codeUnit;
    }
    return hash & 0x7fffffff;
  }

  static Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
  }

  static List<dynamic> _asList(Object? raw) {
    if (raw is List<dynamic>) return raw;
    if (raw is List) return raw.map((value) => value).toList(growable: false);
    return const <dynamic>[];
  }

  static String _cleanValue(Object? raw) {
    if (raw == null) return '';
    final value = raw.toString().trim();
    if (value.isEmpty) return '';
    final lower = value.toLowerCase();
    if (lower == 'null' || lower == 'none') return '';
    if (lower.startsWith('assets/')) return '';
    if (lower.contains('profile_placeholder')) return '';
    if (lower.contains('avatar_placeholder')) return '';
    return value;
  }

  static bool _isSupportedImageRef(String value) {
    final v = value.trim();
    if (v.isEmpty) return false;
    if (v.startsWith('http://') ||
        v.startsWith('https://') ||
        v.startsWith('data:image/') ||
        v.startsWith('gs://')) {
      return true;
    }
    if (v.startsWith('artists/') ||
        v.startsWith('client_artists/') ||
        v.startsWith('portfolio-images/') ||
        v.startsWith('profile-pictures/') ||
        v.startsWith('portfolio/')) {
      return true;
    }
    return v.contains('/') && !v.startsWith('/');
  }

  static String _resolveStorageUrl(
    String raw, {
    String bucket = 'portfolio-images',
  }) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    final lower = value.toLowerCase();
    if (lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('data:image/')) {
      return value;
    }
    if (lower.startsWith('profile-pictures/')) {
      return _client.storage
          .from('profile-pictures')
          .getPublicUrl(value.substring('profile-pictures/'.length))
          .trim();
    }
    if (lower.startsWith('portfolio-images/')) {
      return _client.storage
          .from('portfolio-images')
          .getPublicUrl(value.substring('portfolio-images/'.length))
          .trim();
    }
    if (lower.startsWith('artists/') ||
        lower.startsWith('client_artists/') ||
        lower.startsWith('portfolio/')) {
      return _client.storage.from(bucket).getPublicUrl(value).trim();
    }
    if (_isSupportedImageRef(value)) {
      return _client.storage.from(bucket).getPublicUrl(value).trim();
    }
    return value;
  }
}
