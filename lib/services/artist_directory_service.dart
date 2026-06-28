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
  static const int _defaultMaxDocsPerCollection = 1200;

  static SupabaseClient get _supabase => Supabase.instance.client;

  static bool _isSupportedImageRef(String value) {
    final v = value.trim();
    if (v.isEmpty) return false;
    if (v.startsWith('http://') ||
        v.startsWith('https://') ||
        v.startsWith('data:image/') ||
        v.startsWith('gs://')) {
      return true;
    }
    // Accept Firebase Storage full paths and legacy relative paths.
    if (v.startsWith('artists/') ||
        v.startsWith('client_artists/') ||
        v.startsWith('portfolio/') ||
        v.startsWith('uploads/')) {
      return true;
    }
    // Fallback: treat slash-based non-URL values as storage paths.
    return v.contains('/') && !v.startsWith('/');
  }

  static ArtistDirectoryEntry _preferRicherEntry(
    ArtistDirectoryEntry current,
    ArtistDirectoryEntry incoming,
  ) {
    int score(ArtistDirectoryEntry e) {
      var s = 0;
      s += e.portfolioImages.length * 10;
      if (e.avatarUrl.trim().isNotEmpty) s += 3;
      if (e.rating > 0) s += 2;
      if (e.city.trim().isNotEmpty) s += 1;
      if (e.state.trim().isNotEmpty) s += 1;
      return s;
    }

    final currentScore = score(current);
    final incomingScore = score(incoming);
    if (incomingScore > currentScore) return incoming;
    if (incomingScore < currentScore) return current;

    // Tie-breaker: keep the one with wider budget range data if available.
    final currentRange = (current.budgetMax - current.budgetMin).abs();
    final incomingRange = (incoming.budgetMax - incoming.budgetMin).abs();
    return incomingRange > currentRange ? incoming : current;
  }

  static Future<List<ArtistDirectoryEntry>> fetchHomeArtistsRandomized({
    int limit = 12,
    DateTime? now,
    bool hydrateMediaFallbacks = false,
  }) async {
    final today = now ?? DateTime.now();
    final seed = _dailySeed(today);

    final merged = <ArtistDirectoryEntry>[];
    final byKey = <String, int>{};

    Future<void> addFromTable(String table, int fetchLimit) async {
      try {
        final rows = await _supabase
            .from(table)
            .select('id, email, display_name, profile, pricing, city, state, created_at')
            .order('created_at', ascending: false)
            .limit(fetchLimit * 4);

        if (rows.isEmpty) return;

        final allEntries = <ArtistDirectoryEntry>[];
        for (final rawRow in rows) {
          final row = Map<String, dynamic>.from(rawRow as Map);
          final id = (row['id'] ?? '').toString().trim();
          if (id.isEmpty) continue;
          final entry = _fromDoc(id, row);
          if (entry != null) allEntries.add(entry);
        }

        allEntries.sort(
          (a, b) => _stableHash('${a.id}|$seed').compareTo(
            _stableHash('${b.id}|$seed'),
          ),
        );

        for (final entry in allEntries) {
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
          if (merged.length >= limit) return;
        }
      } catch (_) {}
    }

    final perCollectionLimit = (limit * 2).clamp(8, 40);
    await addFromTable('artist', perCollectionLimit);
    if (merged.length < limit) {
      await addFromTable('client_artist', perCollectionLimit);
    }

    if (merged.length < limit) {
      final all = await fetchAllArtists(hydrateMediaFallbacks: false);
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

    return merged.take(limit).toList(growable: false);
  }

  static Future<List<ArtistDirectoryEntry>> fetchAllArtists({
    bool hydrateMediaFallbacks = true,
    int maxDocsPerCollection = _defaultMaxDocsPerCollection,
  }) async {
    final merged = <ArtistDirectoryEntry>[];
    final byKey = <String, int>{};

    Future<void> addFromTable(String table) async {
      var offset = 0;
      while (offset < maxDocsPerCollection) {
        final remaining = maxDocsPerCollection - offset;
        final pageSize = remaining < _defaultPageSize ? remaining : _defaultPageSize;
        try {
          final rows = await _supabase
              .from(table)
              .select('id, email, display_name, profile, pricing, city, state, created_at')
              .range(offset, offset + pageSize - 1);

          if (rows.isEmpty) break;

          for (final rawRow in rows) {
            final row = Map<String, dynamic>.from(rawRow as Map);
            final id = (row['id'] ?? '').toString().trim();
            if (id.isEmpty) continue;
            final entry = _fromDoc(id, row);
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

          if ((rows as List).length < pageSize) break;
          offset += pageSize;
        } catch (_) {
          break;
        }
      }
    }

    await addFromTable('artist');
    await addFromTable('client_artist');

    merged.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return merged;
  }

  static int _dailySeed(DateTime d) =>
      (d.year * 10000) + (d.month * 100) + d.day;

  static int _stableHash(String value) {
    var h = 5381;
    for (final c in value.codeUnits) {
      h = ((h << 5) + h) ^ c;
    }
    return h & 0x7fffffff;
  }

  static ArtistDirectoryEntry? _fromDoc(String id, Map<String, dynamic> data) {
    final profile = (data['profile'] as Map<String, dynamic>?) ?? const {};
    final address = (data['address'] as Map<String, dynamic>?) ?? const {};
    final pricing = (data['pricing'] as Map<String, dynamic>?) ?? const {};
    final credentials =
        (data['credentials'] as Map<String, dynamic>?) ?? const {};
    final artist = (data['artist'] as Map<String, dynamic>?) ?? const {};
    final artistPricing =
        (artist['pricing'] as Map<String, dynamic>?) ?? const {};
    final artistCredentials =
        (artist['credentials'] as Map<String, dynamic>?) ?? const {};
    final portfolio = (data['portfolio'] as Map<String, dynamic>?) ?? const {};
    final artistPortfolio =
        (artist['portfolio'] as Map<String, dynamic>?) ?? const {};
    final ascension = (data['ascension'] as Map<String, dynamic>?) ?? const {};
    final sponsorshipRequest =
        (data['sponsorshipRequest'] as Map<String, dynamic>?) ?? const {};

    String firstNonEmpty(List<dynamic> values) {
      for (final raw in values) {
        final text = _cleanAvatarValue((raw ?? '').toString());
        if (text.isNotEmpty) return text;
      }
      return '';
    }

    int asInt(dynamic raw, int fallback) {
      if (raw is int) return raw;
      if (raw is num) return raw.round();
      return int.tryParse((raw ?? '').toString()) ?? fallback;
    }

    double asRating(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse((raw ?? '').toString().trim()) ?? 0;
    }

    bool asBool(dynamic raw, bool fallback) {
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      final text = (raw ?? '').toString().trim().toLowerCase();
      if (text == 'true' || text == '1' || text == 'yes') return true;
      if (text == 'false' || text == '0' || text == 'no') return false;
      return fallback;
    }

    List<String> collectImageUrls(List<dynamic> rawList) {
      final out = <String>[];
      for (final raw in rawList) {
        if (raw is String) {
          final v = raw.trim();
          if (_isSupportedImageRef(v)) {
            out.add(v);
          }
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
          if (_isSupportedImageRef(candidate)) {
            out.add(candidate);
          }
        }
      }
      return out;
    }

    final rawName = firstNonEmpty([
      profile['displayName'],
      profile['nameOrStudio'],
      data['panel_displayName'],
      data['panel_nameOrStudio'],
      data['displayName'],
      data['name'],
    ]);

    final email = firstNonEmpty([data['email']]);
    final name = rawName.isNotEmpty
        ? rawName
        : (email.isNotEmpty
              ? email.split('@').first.trim()
              : id.trim().isNotEmpty
              ? id.trim()
              : 'Artist');
    final city = firstNonEmpty([address['city'], data['panel_city']]);
    final state = firstNonEmpty([address['state'], data['panel_state']]);
    final minBudget = asInt(
      pricing['minPrice'] ??
          artistPricing['minPrice'] ??
          data['panel_minPrice'],
      50,
    );
    final maxBudget = asInt(
      pricing['maxPrice'] ??
          artistPricing['maxPrice'] ??
          data['panel_maxPrice'],
      200,
    );
    final credentialRaw = firstNonEmpty([
      credentials['nailTechType'],
      artistCredentials['nailTechType'],
      data['panel_nailTechType'],
    ]).toLowerCase();
    final credential = credentialRaw == 'student'
        ? 'Student or unlicensed nail technician'
        : 'Professional Nail Technician';
    final avatarUrl = firstNonEmpty([
      profile['photoUrl'],
      profile['avatarUrl'],
      profile['profileImageUrl'],
      profile['profilePhotoUrl'],
      profile['photoURL'],
      profile['avatarURL'],
      profile['profilePhoto'],
      data['panel_profileImageUrl'],
      data['profileImageUrl'],
      data['profilePhotoUrl'],
      data['profilePhoto'],
      data['panel_avatarUrl'],
      data['panel_photoUrl'],
      data['photoUrl'],
      data['avatarUrl'],
      data['photoURL'],
      data['avatarURL'],
      (data['basic'] as Map<String, dynamic>?)?['profileImageUrl'],
      (data['basic'] as Map<String, dynamic>?)?['avatarUrl'],
      (data['basic'] as Map<String, dynamic>?)?['photoUrl'],
      (data['basic'] as Map<String, dynamic>?)?['profilePhotoUrl'],
      (data['basic'] as Map<String, dynamic>?)?['profilePhoto'],
      (artist['profile'] as Map<String, dynamic>?)?['photoUrl'],
      (artist['profile'] as Map<String, dynamic>?)?['avatarUrl'],
      (artist['profile'] as Map<String, dynamic>?)?['profileImageUrl'],
      (artist['profile'] as Map<String, dynamic>?)?['profilePhotoUrl'],
      (artist['profile'] as Map<String, dynamic>?)?['profilePhoto'],
      artist['photoUrl'],
      artist['avatarUrl'],
      artist['profileImageUrl'],
      artist['profilePhotoUrl'],
      artist['profilePhoto'],
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
      data['panel_projectNotes'],
      portfolio['projectNotes'],
      artistPortfolio['projectNotes'],
      profile['projectNotes'],
      profile['notes'],
      artist['projectNotes'],
    ]);
    final stats = (data['stats'] as Map<String, dynamic>?) ?? const {};
    final profileStats =
        (profile['stats'] as Map<String, dynamic>?) ?? const {};
    final rating = asRating(
      stats['rating'] ??
          stats['averageRating'] ??
          profileStats['rating'] ??
          profileStats['averageRating'] ??
          profile['rating'] ??
          data['rating'] ??
          data['averageRating'] ??
          data['panel_rating'],
    );
    final portfolioImages = <String>[
      // Canonical source used across registration + manage profile.
      ...collectImageUrls(
        (data['portfolioImages'] as List<dynamic>?) ?? const [],
      ),
      ...collectImageUrls(
        (data['panel_artist_portfolioImages'] as List<dynamic>?) ?? const [],
      ),
      ...collectImageUrls(
        (data['panel_portfolioImages'] as List<dynamic>?) ?? const [],
      ),

      // Legacy/fallback sources.
      ...collectImageUrls((portfolio['images'] as List<dynamic>?) ?? const []),
      ...collectImageUrls((portfolio['items'] as List<dynamic>?) ?? const []),
      ...collectImageUrls(
        (data['portfolioItems'] as List<dynamic>?) ?? const [],
      ),
      ...collectImageUrls(
        (artistPortfolio['images'] as List<dynamic>?) ?? const [],
      ),
      ...collectImageUrls(
        (artistPortfolio['items'] as List<dynamic>?) ?? const [],
      ),
      ...collectImageUrls(
        (artist['portfolioImages'] as List<dynamic>?) ?? const [],
      ),
      ...collectImageUrls(
        (artist['portfolioItems'] as List<dynamic>?) ?? const [],
      ),
    ];
    final dedupedPortfolio = <String>[];
    final seenUrls = <String>{};
    for (final url in portfolioImages) {
      if (seenUrls.add(url)) dedupedPortfolio.add(url);
    }
    final acceptsDirectRequests = asBool(
      data['panel_directRequestsEnabled'] ??
          data['panel_artist_directRequestsEnabled'] ??
          (data['availability']
              as Map<String, dynamic>?)?['directRequestsEnabled'] ??
          profile['directRequestsEnabled'] ??
          (data['artist'] as Map<String, dynamic>?)?['directRequestsEnabled'] ??
          (artist['availability']
              as Map<String, dynamic>?)?['directRequestsEnabled'] ??
          artist['directRequestsEnabled'],
      false,
    );
    final acceptsNfcRequests = asBool(
      data['panel_nfcRequestEnabled'] ??
          (data['availability']
              as Map<String, dynamic>?)?['nfcRequestEnabled'] ??
          (data['profile'] as Map<String, dynamic>?)?['nfcRequestEnabled'] ??
          (data['artist'] as Map<String, dynamic>?)?['nfcRequestEnabled'] ??
          (artist['availability']
              as Map<String, dynamic>?)?['nfcRequestEnabled'] ??
          artist['nfcRequestEnabled'],
      false,
    );
    final tierLabel = _resolveTierLabel(<Object?>[
      data['sponsorshipTier'],
      data['panel_ascensionLevel'],
      profile['ascensionTier'],
      ascension['tier'],
      ascension['levelName'],
      sponsorshipRequest['tier'],
    ]);

    return ArtistDirectoryEntry(
      id: id,
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
      final value = (raw ?? '').toString().trim().toLowerCase();
      if (value == 'goldsmith') return 'Goldsmith';
      if (value == 'crowned') return 'Crowned';
      if (value == 'maker') return 'Maker';
    }
    return 'Maker';
  }

  static String _cleanAvatarValue(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';
    final lower = text.toLowerCase();
    if (lower.startsWith('assets/')) return '';
    if (lower.contains('profile_placeholder')) return '';
    if (lower.contains('avatar_placeholder')) return '';
    return text;
  }
}
