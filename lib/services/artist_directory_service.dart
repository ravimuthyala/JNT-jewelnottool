import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

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

  static Future<QuerySnapshot<Map<String, dynamic>>> _safeCollectionPage(
    CollectionReference<Map<String, dynamic>> ref, {
    required int limit,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) {
    var query = ref.limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    return query.get();
  }

  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _fetchCollectionPaged({
    required FirebaseFirestore db,
    required String collection,
    int pageSize = _defaultPageSize,
    int maxDocs = _defaultMaxDocsPerCollection,
  }) async {
    final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    DocumentSnapshot<Map<String, dynamic>>? cursor;
    final safePageSize = pageSize.clamp(50, 400);
    final safeMaxDocs = maxDocs.clamp(100, 5000);

    while (docs.length < safeMaxDocs) {
      final remaining = safeMaxDocs - docs.length;
      final page = await _safeCollectionPage(
        db.collection(collection),
        limit: remaining < safePageSize ? remaining : safePageSize,
        startAfter: cursor,
      );
      if (page.docs.isEmpty) break;
      docs.addAll(page.docs);
      cursor = page.docs.last;
      if (page.docs.length < safePageSize) break;
    }

    return docs;
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
    final db = FirebaseFirestore.instance;
    final today = now ?? DateTime.now();
    final seed = _dailySeed(today);
    final start = (seed % 10000) / 10000.0;

    final merged = <ArtistDirectoryEntry>[];
    final byKey = <String, int>{};

    void addAllFromDocs(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    ) {
      for (final doc in docs) {
        final entry = _fromDoc(doc.id, doc.data());
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
        if (merged.length >= limit) return;
      }
    }

    try {
      final perCollectionLimit = (limit * 2).clamp(8, 40);
      final artistDocs = await _queryRandomWindow(
        db: db,
        collection: 'artist',
        start: start,
        limit: perCollectionLimit,
      );
      final clientArtistDocs = await _queryRandomWindow(
        db: db,
        collection: 'client_artist',
        start: start,
        limit: perCollectionLimit,
      );

      addAllFromDocs(artistDocs);
      if (merged.length < limit) {
        addAllFromDocs(clientArtistDocs);
      }
    } catch (_) {
      // Fallback below
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

    final limited = merged.take(limit).toList(growable: false);
    if (!hydrateMediaFallbacks) {
      return limited;
    }
    return _hydrateMissingPortfolios(limited);
  }

  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _queryRandomWindow({
    required FirebaseFirestore db,
    required String collection,
    required double start,
    required int limit,
  }) async {
    final first = await db
        .collection(collection)
        .where('randKey', isGreaterThanOrEqualTo: start)
        .orderBy('randKey')
        .limit(limit)
        .get();

    if (first.docs.length >= limit) return first.docs;

    final remaining = limit - first.docs.length;
    final second = await db
        .collection(collection)
        .where('randKey', isLessThan: start)
        .orderBy('randKey')
        .limit(remaining)
        .get();

    return <QueryDocumentSnapshot<Map<String, dynamic>>>[
      ...first.docs,
      ...second.docs,
    ];
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

  static Future<List<ArtistDirectoryEntry>> fetchAllArtists({
    bool hydrateMediaFallbacks = true,
    int maxDocsPerCollection = _defaultMaxDocsPerCollection,
  }) async {
    final db = FirebaseFirestore.instance;
    final artistDocs = await _fetchCollectionPaged(
      db: db,
      collection: 'artist',
      maxDocs: maxDocsPerCollection,
    );
    final clientArtistDocs = await _fetchCollectionPaged(
      db: db,
      collection: 'client_artist',
      maxDocs: maxDocsPerCollection,
    );

    final merged = <ArtistDirectoryEntry>[];
    final byKey = <String, int>{};

    void addAll(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
      for (final doc in docs) {
        final data = doc.data();
        final entry = _fromDoc(doc.id, data);
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

    addAll(artistDocs);
    addAll(clientArtistDocs);

    merged.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (!hydrateMediaFallbacks) {
      return merged;
    }
    return _hydrateMissingPortfolios(merged);
  }

  static Future<List<ArtistDirectoryEntry>> _hydrateMissingPortfolios(
    List<ArtistDirectoryEntry> entries,
  ) async {
    if (entries.isEmpty) return entries;
    final hydrated = await Future.wait(
      entries.map((entry) async {
        var next = entry;
        if (next.portfolioImages.isEmpty) {
          final fallback =
              await _loadPortfolioItemsFromSubcollection(
                next.id,
                email: next.email,
              ).timeout(
                const Duration(seconds: 6),
                onTimeout: () => const <String>[],
              );
          if (fallback.isNotEmpty) {
            next = next.copyWith(portfolioImages: fallback);
          }
        }
        if (next.avatarUrl.trim().isEmpty) {
          final avatar = await _loadAvatarFromStorage(
            next.id,
          ).timeout(const Duration(seconds: 6), onTimeout: () => '');
          if (avatar.trim().isNotEmpty) {
            next = next.copyWith(avatarUrl: avatar.trim());
          }
        }
        return next;
      }),
    );
    return hydrated;
  }

  static Future<String> _loadAvatarFromStorage(String uid) async {
    final db = FirebaseFirestore.instance;
    final ids = <String>{uid.trim()}..removeWhere((e) => e.isEmpty);

    // Try to discover canonical uid/doc ids by email/uid matches too.
    Future<void> addDocIds(String collection) async {
      for (final id in ids.toList(growable: false)) {
        try {
          final doc = await db.collection(collection).doc(id).get();
          if (doc.exists) ids.add(doc.id);
        } catch (_) {}
      }
    }

    await addDocIds('artist');
    await addDocIds('client_artist');

    final exactFiles = <String>[];
    for (final id in ids) {
      exactFiles.addAll(<String>[
        'artists/$id/profile/avatar.jpg',
        'artists/$id/profile/avatar.jpeg',
        'artists/$id/profile/avatar.png',
        'artists/$id/profile/avatar.webp',
        'client_artists/$id/profile/avatar.jpg',
        'client_artists/$id/profile/avatar.jpeg',
        'client_artists/$id/profile/avatar.png',
        'client_artists/$id/profile/avatar.webp',
      ]);
    }

    for (final path in exactFiles) {
      try {
        final url = await FirebaseStorage.instance.ref(path).getDownloadURL();
        if (url.trim().isNotEmpty) return url.trim();
      } catch (_) {}
    }

    // Avoid broad listAll fallback on missing folders; it can trigger repeated
    // Storage 404s on mobile and destabilize request flows.
    return '';
  }

  static Future<List<String>> _loadPortfolioItemsFromSubcollection(
    String uid, {
    String? email,
  }) async {
    final db = FirebaseFirestore.instance;
    final urls = <String>[];
    final docIds = <String>{uid.trim()}..removeWhere((e) => e.isEmpty);
    final normalizedEmail = (email ?? '').trim().toLowerCase();

    bool accepts(String v) => _isSupportedImageRef(v);

    void collect(dynamic raw) {
      if (raw == null) return;
      if (raw is String) {
        final v = raw.trim();
        if (v.isNotEmpty && accepts(v)) urls.add(v);
        return;
      }
      if (raw is List) {
        for (final item in raw) {
          collect(item);
        }
        return;
      }
      if (raw is Map) {
        collect(raw['imageUrl']);
        collect(raw['downloadUrl']);
        collect(raw['url']);
        collect(raw['image']);
        collect(raw['storagePath']);
        collect(raw['path']);
        collect(raw['filePath']);
        collect(raw['fullPath']);
      }
    }

    Future<void> addIdsFromEmail(String collection) async {
      if (normalizedEmail.isEmpty) return;
      try {
        final q = await db
            .collection(collection)
            .where('email', isEqualTo: normalizedEmail)
            .limit(6)
            .get()
            .timeout(const Duration(seconds: 4));
        for (final doc in q.docs) {
          final id = doc.id.trim();
          if (id.isNotEmpty) docIds.add(id);
        }
      } catch (_) {}
    }

    for (final collection in const <String>['artist', 'client_artist']) {
      await addIdsFromEmail(collection);
    }

    for (final collection in const <String>['artist', 'client_artist']) {
      for (final id in docIds) {
        try {
          final doc = await db
              .collection(collection)
              .doc(id)
              .get()
              .timeout(const Duration(seconds: 4));
          if (!doc.exists) continue;
          final data = doc.data() ?? const <String, dynamic>{};
          collect(data['portfolioImages']);
          collect(data['panel_portfolioImages']);
          collect(data['panel_artist_portfolioImages']);
          collect(data['portfolioItems']);
          collect(data['portfolio']);
          collect(data['artist']);
        } catch (_) {}
      }
    }

    for (final collection in const <String>['artist', 'client_artist']) {
      for (final id in docIds) {
        try {
          final snap = await db
              .collection(collection)
              .doc(id)
              .collection('portfolio_items')
              .limit(24)
              .get()
              .timeout(const Duration(seconds: 4));
          for (final doc in snap.docs) {
            collect(doc.data());
          }
          if (urls.length >= 24) break;
        } catch (_) {}
      }
      if (urls.length >= 24) break;
    }

    // Do not fallback to Storage listAll when Firestore data is absent.
    // Missing folders can cause repeated 404 spam and degrade app stability.

    final dedup = <String>[];
    final seen = <String>{};
    for (final v in urls) {
      if (seen.add(v)) dedup.add(v);
    }
    return dedup;
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
    final rating = asRating(
      stats['rating'] ??
          stats['averageRating'] ??
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
