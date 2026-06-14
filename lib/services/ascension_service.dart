import 'supabase_firebase_compat.dart';

class AscensionSnapshot {
  const AscensionSnapshot({
    required this.points,
    required this.level,
    required this.sponsorshipEligible,
    required this.completedOrders,
    required this.onTimeDeliveries,
    required this.fiveStarReviews,
    required this.repeatClientOrders,
    required this.portfolioUploads,
    required this.jntRevenue,
    required this.artistGmv,
    required this.artistEarnings,
    required this.crownedPointsQualified,
    required this.crownedRevenueQualified,
    required this.jntRevenueToCrowned,
    required this.ordersToRevenueCrowned,
    required this.insuranceReimbursementEligible,
    required this.blendedAveragePointsPerOrder,
    required this.ordersToGoldsmith,
    required this.ordersToCrowned,
    required this.annualOrders,
    required this.annualArtistGmv,
    required this.annualArtistEarnings,
    required this.annualJntRevenue,
    required this.annualPerkCost,
    required this.netMarginAfterPerks,
    required this.marginPercent,
  });

  final int points;
  final String level;
  final bool sponsorshipEligible;
  final int completedOrders;
  final int onTimeDeliveries;
  final int fiveStarReviews;
  final int repeatClientOrders;
  final int portfolioUploads;
  final double jntRevenue;
  final double artistGmv;
  final double artistEarnings;
  final bool crownedPointsQualified;
  final bool crownedRevenueQualified;
  final double jntRevenueToCrowned;
  final int ordersToRevenueCrowned;
  final bool insuranceReimbursementEligible;
  final double blendedAveragePointsPerOrder;
  final int ordersToGoldsmith;
  final int ordersToCrowned;
  final int annualOrders;
  final double annualArtistGmv;
  final double annualArtistEarnings;
  final double annualJntRevenue;
  final double annualPerkCost;
  final double netMarginAfterPerks;
  final double marginPercent;
}

class AscensionService {
  static const int makerMax = 999;
  static const int goldsmithMin = 1000;
  static const int goldsmithMax = 9749;
  static const int crownedMin = 9750;
  static const double crownedRevenueMin = 5000;

  static const double aov = 125;
  static const double takeRate = 0.20;
  static const double jntRevPerOrder = aov * takeRate;
  static const double artistEarningsPerOrder = 100;

  static const int pointsCompleteOrder = 25;
  static const int pointsOnTimeDelivery = 10;
  static const int pointsFiveStarReview = 15;
  static const int pointsRepeatClientOrder = 20;
  static const int pointsPortfolioUpload = 5;

  static const double frequencyCompleteOrder = 1.00;
  static const double frequencyOnTimeDelivery = 0.85;
  static const double frequencyFiveStarReview = 0.60;
  static const double frequencyRepeatClientOrder = 0.30;
  static const double frequencyPortfolioUpload = 0.05;

  static const double blendedAveragePointsPerOrder = 48.8;
  static const double makerAnnualPerkCost = 170;
  static const double goldsmithAnnualPerkCost = 470;
  static const double crownedAnnualPerkCost = 1070;
  static const double weightedPointsCompleteOrder = 25.0;
  static const double weightedPointsOnTimeDelivery = 8.5;
  static const double weightedPointsFiveStarReview = 9.0;
  static const double weightedPointsRepeatClientOrder = 6.0;
  static const double weightedPointsPortfolioUpload = 0.3;

  static const String currentCollection = 'ascension_current';
  static const String auditCollection = 'ascension_audit_logs';
  static const String overridesCollection = 'ascension_overrides';

  static Future<AscensionSnapshot> calculateForArtist({
    required FirebaseFirestore db,
    required String artistEmail,
    required int portfolioUploads,
  }) async {
    final email = artistEmail.trim().toLowerCase();
    if (email.isEmpty) {
      return const AscensionSnapshot(
        points: 0,
        level: 'Maker',
        sponsorshipEligible: false,
        completedOrders: 0,
        onTimeDeliveries: 0,
        fiveStarReviews: 0,
        repeatClientOrders: 0,
        portfolioUploads: 0,
        jntRevenue: 0,
        artistGmv: 0,
        artistEarnings: 0,
        crownedPointsQualified: false,
        crownedRevenueQualified: false,
        jntRevenueToCrowned: crownedRevenueMin,
        ordersToRevenueCrowned: 200,
        insuranceReimbursementEligible: false,
        blendedAveragePointsPerOrder: blendedAveragePointsPerOrder,
        ordersToGoldsmith: 21,
        ordersToCrowned: 200,
        annualOrders: 0,
        annualArtistGmv: 0,
        annualArtistEarnings: 0,
        annualJntRevenue: 0,
        annualPerkCost: makerAnnualPerkCost,
        netMarginAfterPerks: -makerAnnualPerkCost,
        marginPercent: 0,
      );
    }

    final collections = <String>[
      'Client_Custom_Requests',
      'Company_Custom_Requests',
    ];
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = [];
    for (final c in collections) {
      final snap = await db
          .collection(c)
          .where('acceptedByArtistEmail', isEqualTo: email)
          .get();
      docs.addAll(snap.docs);
    }

    var completedOrders = 0;
    var annualCompletedOrders = 0;
    var onTimeDeliveries = 0;
    var fiveStarReviews = 0;
    var repeatClientOrders = 0;
    final clientOrderCounts = <String, int>{};
    final annualWindowStart = DateTime.now().subtract(
      const Duration(days: 365),
    );

    for (final doc in docs) {
      final data = doc.data();
      final status = (data['status'] ?? '').toString().trim().toLowerCase();
      final isCompleted =
          status == 'completed' || status == 'shipped' || status == 'delivered';
      if (!isCompleted) continue;

      completedOrders += 1;
      final completionDate = _resolveCompletionDate(data);
      if (completionDate != null && !completionDate.isBefore(annualWindowStart)) {
        annualCompletedOrders += 1;
      }

      final clientKey = await _resolveClientIdentityKey(
        db: db,
        requestDoc: doc.reference,
        rootData: data,
      );
      if (clientKey.isNotEmpty) {
        final existing = clientOrderCounts[clientKey] ?? 0;
        clientOrderCounts[clientKey] = existing + 1;
        if (existing >= 1) {
          repeatClientOrders += 1;
        }
      }

      final ratingRaw = data['clientRating'];
      final rating = ratingRaw is num
          ? ratingRaw.toDouble()
          : double.tryParse(ratingRaw?.toString() ?? '');
      if (rating != null && rating >= 5) {
        fiveStarReviews += 1;
      }

      DateTime? needBy;
      final needByRaw = data['needBy'];
      if (needByRaw is Timestamp) needBy = needByRaw.toDate();

      DateTime? deliveredAt;
      final deliveredRaw = data['deliveredAt'] ?? data['completedAt'];
      if (deliveredRaw is Timestamp) deliveredAt = deliveredRaw.toDate();

      if (needBy != null && deliveredAt != null) {
        final due = DateTime(needBy.year, needBy.month, needBy.day, 23, 59, 59);
        if (!deliveredAt.isAfter(due)) {
          onTimeDeliveries += 1;
        }
      }
    }

    final calculatedPoints =
        (completedOrders * weightedPointsCompleteOrder) +
        (onTimeDeliveries * weightedPointsOnTimeDelivery) +
        (fiveStarReviews * weightedPointsFiveStarReview) +
        (repeatClientOrders * weightedPointsRepeatClientOrder) +
        (portfolioUploads * weightedPointsPortfolioUpload);
    final points = calculatedPoints.round();

    final jntRevenue = completedOrders * jntRevPerOrder;
    final crownedPointsQualified = points >= crownedMin;
    final crownedRevenueQualified = jntRevenue >= crownedRevenueMin;
    final level = (crownedPointsQualified && crownedRevenueQualified)
        ? 'Crowned'
        : (points >= goldsmithMin ? 'Goldsmith' : 'Maker');
    final jntRevenueToCrowned = (crownedRevenueMin - jntRevenue).clamp(
      0,
      crownedRevenueMin,
    );
    final ordersToRevenueCrowned = (jntRevenueToCrowned / jntRevPerOrder).ceil();

    final ordersToGoldsmith = (goldsmithMin / blendedAveragePointsPerOrder)
        .ceil();
    final ordersToCrowned = (crownedMin / blendedAveragePointsPerOrder).ceil();
    final annualOrders = annualCompletedOrders;
    final annualArtistGmv = annualOrders * aov;
    final annualArtistEarnings = annualOrders * artistEarningsPerOrder;
    final annualJntRevenue = annualOrders * jntRevPerOrder;
    final annualPerkCost = switch (level) {
      'Crowned' => crownedAnnualPerkCost,
      'Goldsmith' => goldsmithAnnualPerkCost,
      _ => makerAnnualPerkCost,
    };
    final netMarginAfterPerks = annualJntRevenue - annualPerkCost;
    final marginPercent = annualJntRevenue > 0
        ? netMarginAfterPerks / annualJntRevenue
        : 0.0;

    return AscensionSnapshot(
      points: points,
      level: level,
      sponsorshipEligible: points >= goldsmithMin,
      completedOrders: completedOrders,
      onTimeDeliveries: onTimeDeliveries,
      fiveStarReviews: fiveStarReviews,
      repeatClientOrders: repeatClientOrders,
      portfolioUploads: portfolioUploads,
      jntRevenue: jntRevenue,
      artistGmv: completedOrders * aov,
      artistEarnings: completedOrders * artistEarningsPerOrder,
      crownedPointsQualified: crownedPointsQualified,
      crownedRevenueQualified: crownedRevenueQualified,
      jntRevenueToCrowned: jntRevenueToCrowned.toDouble(),
      ordersToRevenueCrowned: ordersToRevenueCrowned,
      insuranceReimbursementEligible: level == 'Crowned',
      blendedAveragePointsPerOrder: blendedAveragePointsPerOrder,
      ordersToGoldsmith: ordersToGoldsmith,
      ordersToCrowned: ordersToCrowned,
      annualOrders: annualOrders,
      annualArtistGmv: annualArtistGmv,
      annualArtistEarnings: annualArtistEarnings,
      annualJntRevenue: annualJntRevenue,
      annualPerkCost: annualPerkCost,
      netMarginAfterPerks: netMarginAfterPerks,
      marginPercent: marginPercent,
    );
  }

  static Map<String, dynamic> buildAscensionPayload(
    AscensionSnapshot snapshot,
  ) {
    return <String, dynamic>{
      'points': snapshot.points,
      'levelName': snapshot.level,
      'label': snapshot.level,
      'tier': snapshot.level,
      'sponsorshipEligible': snapshot.sponsorshipEligible,
      'thresholds': <String, dynamic>{
        'makerMax': makerMax,
        'goldsmithMin': goldsmithMin,
        'goldsmithMax': goldsmithMax,
        'crownedMin': crownedMin,
      },
      'economics': <String, dynamic>{
        'aov': aov,
        'takeRate': takeRate,
        'jntRevenuePerOrder': jntRevPerOrder,
        'blendedAvgPointsPerOrder': snapshot.blendedAveragePointsPerOrder,
        'ordersToGoldsmith': snapshot.ordersToGoldsmith,
        'ordersToCrowned': snapshot.ordersToCrowned,
        'margin': <String, dynamic>{
          'annualOrders': snapshot.annualOrders,
          'annualArtistGMV': snapshot.annualArtistGmv,
          'annualArtistEarnings': snapshot.annualArtistEarnings,
          'annualJntRevenue': snapshot.annualJntRevenue,
          'annualPerkCost': snapshot.annualPerkCost,
          'netMarginAfterPerks': snapshot.netMarginAfterPerks,
          'marginPercent': snapshot.marginPercent,
        },
      },
      'metrics': <String, dynamic>{
        'completedOrders': snapshot.completedOrders,
        'onTimeDeliveries': snapshot.onTimeDeliveries,
        'fiveStarReviews': snapshot.fiveStarReviews,
        'repeatClientOrders': snapshot.repeatClientOrders,
        'portfolioUploads': snapshot.portfolioUploads,
        'artistGmv': snapshot.artistGmv,
        'jntRevenue': snapshot.jntRevenue,
        'artistEarnings': snapshot.artistEarnings,
        'crownedPointsQualified': snapshot.crownedPointsQualified,
        'crownedRevenueQualified': snapshot.crownedRevenueQualified,
        'jntRevenueToCrowned': snapshot.jntRevenueToCrowned,
        'ordersToRevenueCrowned': snapshot.ordersToRevenueCrowned,
        'insuranceReimbursementEligible':
            snapshot.insuranceReimbursementEligible,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static Future<Map<String, dynamic>?> readActiveOverride({
    required FirebaseFirestore db,
    required String artistDocPath,
    required String artistEmail,
  }) async {
    bool looksLikeUsableOverride(Map<String, dynamic> data) {
      final active = data['active'];
      if (active == true) return true;
      // Some admin tools may not write `active`; accept if a tier override is present.
      final tierLike = _firstNonEmptyString(<Object?>[
        data['levelName'],
        data['tier'],
        data['level'],
        data['tierName'],
        data['sponsorshipTier'],
      ]);
      if (_normalizeTier(tierLike).isNotEmpty) return true;
      // Also accept explicit points override records.
      return data['points'] is num;
    }

    final keyFromPath = _overrideDocIdFromPath(artistDocPath);
    final docsToTry = <String>{keyFromPath, artistEmail.trim().toLowerCase()};
    for (final docId in docsToTry) {
      if (docId.isEmpty) continue;
      final snap = await db.collection(overridesCollection).doc(docId).get();
      if (!snap.exists) continue;
      final data = snap.data() ?? const <String, dynamic>{};
      if (!looksLikeUsableOverride(data)) continue;
      return data;
    }

    // Fallback: support admin overrides saved with random doc IDs.
    final normalizedEmail = artistEmail.trim().toLowerCase();
    final normalizedPath = artistDocPath.trim().toLowerCase();

    if (normalizedEmail.isNotEmpty) {
      final byEmail = await db
          .collection(overridesCollection)
          .where('artistEmail', isEqualTo: normalizedEmail)
          .limit(20)
          .get();
      for (final doc in byEmail.docs) {
        final data = doc.data();
        if (looksLikeUsableOverride(data)) return data;
      }
    }

    if (normalizedPath.isNotEmpty) {
      final byPath = await db
          .collection(overridesCollection)
          .where('artistDocPath', isEqualTo: artistDocPath.trim())
          .limit(20)
          .get();
      for (final doc in byPath.docs) {
        final data = doc.data();
        if (looksLikeUsableOverride(data)) return data;
      }
      final byPathLower = await db
          .collection(overridesCollection)
          .where('artistDocPathLower', isEqualTo: normalizedPath)
          .limit(20)
          .get();
      for (final doc in byPathLower.docs) {
        final data = doc.data();
        if (looksLikeUsableOverride(data)) return data;
      }
    }
    return null;
  }

  static Map<String, dynamic> applyOverrideToPayload({
    required Map<String, dynamic> payload,
    Map<String, dynamic>? override,
  }) {
    if (override == null) return payload;
    final next = Map<String, dynamic>.from(payload);
    if (override['points'] is num) {
      next['points'] = (override['points'] as num).toInt();
    }
    final level = (override['levelName'] ??
            override['tier'] ??
            override['level'] ??
            override['tierName'] ??
            override['sponsorshipTier'] ??
            '')
        .toString()
        .trim();
    if (level.isNotEmpty) {
      next['levelName'] = level;
      next['label'] = level;
      next['tier'] = level;
    }
    if (override['sponsorshipEligible'] is bool) {
      next['sponsorshipEligible'] = override['sponsorshipEligible'];
    }
    next['overrideApplied'] = true;
    next['overrideReason'] = (override['reason'] ?? '').toString().trim();
    next['overrideUpdatedAt'] = override['updatedAt'];
    return _enforceTierDependentConsistency(next);
  }

  static Map<String, dynamic> preserveExistingAdminOverride({
    required Map<String, dynamic> payload,
    required Map<String, dynamic> artistData,
  }) {
    final ascension =
        (artistData['ascension'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final profile =
        (artistData['profile'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};

    final existingTier = _normalizeTier(
      _firstNonEmptyString(<Object?>[
        ascension['tier'],
        ascension['levelName'],
        artistData['panel_ascensionLevel'],
        artistData['sponsorshipTier'],
        profile['ascensionTier'],
      ]),
    );
    if (existingTier.isEmpty) return payload;

    final existingOverrideApplied = ascension['overrideApplied'] == true;
    final existingOverrideReason = (ascension['overrideReason'] ?? '')
        .toString()
        .trim();
    final payloadTier = _normalizeTier(
      _firstNonEmptyString(<Object?>[
        payload['tier'],
        payload['levelName'],
      ]),
    );
    final hasExistingOverride =
        existingOverrideApplied ||
        existingOverrideReason.isNotEmpty ||
        // Admin may only write top-level tier fields; preserve them.
        ((existingTier == 'Goldsmith' || existingTier == 'Crowned') &&
            payloadTier == 'Maker');
    if (!hasExistingOverride) return _enforceTierDependentConsistency(payload);

    final next = Map<String, dynamic>.from(payload);
    int? existingPoints() {
      final candidates = <Object?>[
        ascension['points'],
        artistData['panel_ascensionPoints'],
        artistData['ascensionPoints'],
      ];
      for (final raw in candidates) {
        if (raw is num) return raw.toInt();
        final parsed = int.tryParse((raw ?? '').toString().trim());
        if (parsed != null) return parsed;
      }
      return null;
    }

    next['tier'] = existingTier;
    next['levelName'] = existingTier;
    next['label'] = existingTier;
    final lockedPoints = existingPoints();
    if (lockedPoints != null) {
      next['points'] = lockedPoints;
    }
    next['overrideApplied'] = true;
    next['overrideReason'] = existingOverrideReason.isNotEmpty
        ? existingOverrideReason
        : 'Admin override preserved';
    if (ascension['overrideUpdatedAt'] != null) {
      next['overrideUpdatedAt'] = ascension['overrideUpdatedAt'];
    }
    if (ascension['sponsorshipEligible'] is bool) {
      next['sponsorshipEligible'] = ascension['sponsorshipEligible'];
    } else {
      final lower = existingTier.toLowerCase();
      next['sponsorshipEligible'] = lower == 'goldsmith' || lower == 'crowned';
    }
    return _enforceTierDependentConsistency(next);
  }

  static Map<String, dynamic> _enforceTierDependentConsistency(
    Map<String, dynamic> payload,
  ) {
    final next = Map<String, dynamic>.from(payload);
    final tier = (next['tier'] ?? next['levelName'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final isCrowned = tier == 'crowned';
    if (!isCrowned) return next;

    next['sponsorshipEligible'] = true;

    final metrics = Map<String, dynamic>.from(
      (next['metrics'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
    metrics['crownedPointsQualified'] = true;
    metrics['crownedRevenueQualified'] = true;
    metrics['insuranceReimbursementEligible'] = true;
    metrics['jntRevenueToCrowned'] = 0;
    metrics['ordersToRevenueCrowned'] = 0;
    next['metrics'] = metrics;

    final economics = Map<String, dynamic>.from(
      (next['economics'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
    final margin = Map<String, dynamic>.from(
      (economics['margin'] as Map<String, dynamic>?) ??
          const <String, dynamic>{},
    );
    margin['annualPerkCost'] = crownedAnnualPerkCost;
    final annualRevenueRaw = margin['annualJntRevenue'];
    final annualRevenue = annualRevenueRaw is num
        ? annualRevenueRaw.toDouble()
        : double.tryParse((annualRevenueRaw ?? '').toString()) ?? 0;
    final netMarginAfterPerks = annualRevenue - crownedAnnualPerkCost;
    margin['netMarginAfterPerks'] = netMarginAfterPerks;
    margin['marginPercent'] =
        annualRevenue > 0 ? netMarginAfterPerks / annualRevenue : 0.0;
    economics['margin'] = margin;
    next['economics'] = economics;
    return next;
  }

  static Future<void> persistAdminCollections({
    required FirebaseFirestore db,
    required DocumentReference<Map<String, dynamic>> artistRef,
    required String artistEmail,
    required String artistName,
    required Map<String, dynamic> ascensionPayload,
    required int previousPoints,
  }) async {
    final docId = _overrideDocIdFromPath(artistRef.path);
    await db.collection(currentCollection).doc(docId).set({
      'artistDocPath': artistRef.path,
      'artistId': artistRef.id,
      'artistEmail': artistEmail.trim().toLowerCase(),
      'artistName': artistName.trim(),
      'ascension': ascensionPayload,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final nextPoints = (ascensionPayload['points'] is num)
        ? (ascensionPayload['points'] as num).toInt()
        : 0;
    if (nextPoints != previousPoints) {
      await db.collection(auditCollection).add({
        'artistDocPath': artistRef.path,
        'artistId': artistRef.id,
        'artistEmail': artistEmail.trim().toLowerCase(),
        'artistName': artistName.trim(),
        'previousPoints': previousPoints,
        'newPoints': nextPoints,
        'newTier': (ascensionPayload['tier'] ?? '').toString(),
        'sponsorshipEligible': ascensionPayload['sponsorshipEligible'] == true,
        'source': 'auto_sync',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    final tier = (ascensionPayload['tier'] ?? '').toString().trim();
    final eligible = ascensionPayload['sponsorshipEligible'] == true;
    await artistRef.set({
      'ascension': ascensionPayload,
      'panel_ascensionPoints': nextPoints,
      'panel_ascensionLevel': tier,
      'sponsorshipTier': tier,
      'sponsorshipStatus': eligible ? 'requested' : 'ineligible',
      'sponsorshipRequest': <String, dynamic>{
        'tier': tier,
        'status': eligible ? 'requested' : 'ineligible',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      // Write nested profile flags via dot-path to avoid replacing
      // the existing profile map (name/avatar/bio/etc.).
      'profile.ascensionTier': tier,
      'profile.sponsorshipEligible': eligible,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static String _overrideDocIdFromPath(String path) {
    return path.trim().replaceAll('/', '__').toLowerCase();
  }

  static String _normalizeTier(String raw) {
    final value = raw.trim().toLowerCase();
    if (value == 'maker') return 'Maker';
    if (value == 'goldsmith') return 'Goldsmith';
    if (value == 'crowned') return 'Crowned';
    return '';
  }

  static String _firstNonEmptyString(Iterable<Object?> values) {
    for (final raw in values) {
      final value = (raw ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static String _normalizeIdentity(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) return '';
    return value;
  }

  static Future<String> _resolveClientIdentityKey({
    required FirebaseFirestore db,
    required DocumentReference<Map<String, dynamic>> requestDoc,
    required Map<String, dynamic> rootData,
  }) async {
    final orderMap =
        (rootData['order'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final acceptanceMap =
        (rootData['acceptance'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final clientProfileSnapshot =
        (rootData['clientProfileSnapshot'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final basicSnapshot =
        (clientProfileSnapshot['basic'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};

    // Prefer stable IDs/emails first.
    final rootIdentity = _normalizeIdentity(
      _firstNonEmptyString(<Object?>[
        rootData['clientUid'],
        rootData['acceptedByClientUid'],
        rootData['clientId'],
        rootData['clientEmail'],
        rootData['acceptedByClientEmail'],
        rootData['selectedClientEmail'],
        orderMap['selectedClientEmail'],
        acceptanceMap['acceptedByClientEmail'],
        basicSnapshot['email'],
      ]),
    );
    if (rootIdentity.isNotEmpty) return rootIdentity;

    // Fallback for older/mixed docs where identity may only exist in details.
    try {
      final detailSnap = await requestDoc.collection('details').doc('payload').get();
      final detailData = detailSnap.data() ?? const <String, dynamic>{};
      final detailOrder =
          (detailData['order'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final detailAcceptance =
          (detailData['acceptance'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final detailClientSnapshot =
          (detailData['clientProfileSnapshot'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final detailBasic =
          (detailClientSnapshot['basic'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};

      final detailIdentity = _normalizeIdentity(
        _firstNonEmptyString(<Object?>[
          detailData['clientUid'],
          detailData['acceptedByClientUid'],
          detailData['clientId'],
          detailData['clientEmail'],
          detailData['acceptedByClientEmail'],
          detailData['selectedClientEmail'],
          detailOrder['selectedClientEmail'],
          detailAcceptance['acceptedByClientEmail'],
          detailBasic['email'],
        ]),
      );
      if (detailIdentity.isNotEmpty) return detailIdentity;
    } catch (_) {}

    // Last fallback: deterministic name key so repeated legacy records
    // without email/uid can still be grouped.
    final fallbackName = _normalizeIdentity(
      _firstNonEmptyString(<Object?>[
        rootData['clientName'],
        rootData['acceptedByClientName'],
        basicSnapshot['name'],
      ]),
    );
    if (fallbackName.isNotEmpty) return 'name:$fallbackName';
    return '';
  }

  static DateTime? _resolveCompletionDate(Map<String, dynamic> data) {
    DateTime? asDate(Object? raw) {
      if (raw is Timestamp) return raw.toDate();
      return null;
    }

    return asDate(data['deliveredAt']) ??
        asDate(data['completedAt']) ??
        asDate(data['shippedAt']) ??
        asDate(data['updatedAt']) ??
        asDate(data['createdAt']);
  }
}
