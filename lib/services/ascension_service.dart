import 'package:supabase_flutter/supabase_flutter.dart';

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

  final double points;
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

  static const double pointsCompleteOrder = 25;
  static const double pointsOnTimeDelivery = 10;
  static const double pointsFiveStarReview = 15;
  static const double pointsRepeatClientOrder = 20;
  static const double pointsPortfolioUpload = 5;

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

  static Future<AscensionSnapshot> calculateForArtist({
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

    final supabase = Supabase.instance.client;

    // client_custom_requests: client_rating and need_by are in summary JSONB
    final clientRows = await supabase
        .from('client_custom_requests')
        .select('status, delivered_at, shipped_at, updated_at, created_at, summary, details, client_email')
        .eq('accepted_by_artist_email', email)
        .inFilter('status', ['completed', 'shipped', 'delivered']);

    // company_custom_requests: all fields are real columns
    final companyRows = await supabase
        .from('company_custom_requests')
        .select('status, client_rating, need_by, delivered_at, shipped_at, updated_at, created_at, client_email, payload')
        .eq('accepted_by_artist_email', email)
        .inFilter('status', ['completed', 'shipped', 'delivered']);

    final allRows = <Map<String, dynamic>>[
      for (final r in clientRows) _normalizeClientRequestRow(r),
      for (final r in companyRows) _normalizeCompanyRequestRow(r),
    ];

    var completedOrders = 0;
    var annualCompletedOrders = 0;
    var onTimeDeliveries = 0;
    var fiveStarReviews = 0;
    var repeatClientOrders = 0;
    final clientOrderCounts = <String, int>{};
    final annualWindowStart = DateTime.now().subtract(const Duration(days: 365));

    for (final data in allRows) {
      completedOrders += 1;
      final completionDate = _resolveCompletionDate(data);
      if (completionDate != null && !completionDate.isBefore(annualWindowStart)) {
        annualCompletedOrders += 1;
      }

      final clientKey = _resolveClientIdentityKey(data);
      if (clientKey.isNotEmpty) {
        final existing = clientOrderCounts[clientKey] ?? 0;
        clientOrderCounts[clientKey] = existing + 1;
        if (existing >= 1) repeatClientOrders += 1;
      }

      final ratingRaw = data['clientRating'] ?? data['client_rating'];
      final rating = ratingRaw is num
          ? ratingRaw.toDouble()
          : double.tryParse(ratingRaw?.toString() ?? '');
      if (rating != null && rating >= 5) fiveStarReviews += 1;

      final needByRaw = data['needBy'] ?? data['need_by'];
      DateTime? needBy;
      if (needByRaw is String) needBy = DateTime.tryParse(needByRaw);

      final deliveredRaw = data['deliveredAt'] ?? data['delivered_at'] ?? data['completedAt'];
      DateTime? deliveredAt;
      if (deliveredRaw is String) deliveredAt = DateTime.tryParse(deliveredRaw);

      if (needBy != null && deliveredAt != null) {
        final due = DateTime(needBy.year, needBy.month, needBy.day, 23, 59, 59);
        if (!deliveredAt.isAfter(due)) onTimeDeliveries += 1;
      }
    }

    final calculatedPoints =
        (completedOrders * weightedPointsCompleteOrder) +
        (onTimeDeliveries * weightedPointsOnTimeDelivery) +
        (fiveStarReviews * weightedPointsFiveStarReview) +
        (repeatClientOrders * weightedPointsRepeatClientOrder) +
        (portfolioUploads * weightedPointsPortfolioUpload);
    final points = calculatedPoints;

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

    final ordersToGoldsmith = (goldsmithMin / blendedAveragePointsPerOrder).ceil();
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
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  static Future<Map<String, dynamic>?> readActiveOverride({
    required String artistDocPath,
    required String artistEmail,
  }) async {
    final supabase = Supabase.instance.client;

    Map<String, dynamic> normRow(Map<String, dynamic> row) => <String, dynamic>{
      ...row,
      'levelName': row['level_name'] ?? row['levelName'],
      'tierName': row['tier_name'] ?? row['tierName'],
      'sponsorshipTier': row['sponsorship_tier'] ?? row['sponsorshipTier'],
      'sponsorshipEligible': row['sponsorship_eligible'] ?? row['sponsorshipEligible'],
      'updatedAt': row['updated_at'] ?? row['updatedAt'],
    };

    bool looksLikeUsableOverride(Map<String, dynamic> data) {
      if (data['active'] == true) return true;
      final tierLike = _firstNonEmptyString(<Object?>[
        data['levelName'],
        data['tier'],
        data['level'],
        data['tierName'],
        data['sponsorshipTier'],
      ]);
      if (_normalizeTier(tierLike).isNotEmpty) return true;
      return data['points'] is num;
    }

    final keyFromPath = _overrideDocIdFromPath(artistDocPath);
    final email = artistEmail.trim().toLowerCase();
    final docsToTry = <String>{keyFromPath, email};

    for (final docId in docsToTry) {
      if (docId.isEmpty) continue;
      final row = await supabase
          .from('ascension_overrides')
          .select()
          .eq('id', docId)
          .maybeSingle();
      if (row == null) continue;
      final data = normRow(row);
      if (looksLikeUsableOverride(data)) return data;
    }

    if (email.isNotEmpty) {
      final rows = await supabase
          .from('ascension_overrides')
          .select()
          .eq('artist_email', email)
          .limit(20);
      for (final row in rows) {
        final data = normRow(row);
        if (looksLikeUsableOverride(data)) return data;
      }
    }

    if (artistDocPath.trim().isNotEmpty) {
      final normalizedPath = artistDocPath.trim().toLowerCase();
      final byPath = await supabase
          .from('ascension_overrides')
          .select()
          .eq('artist_doc_path', artistDocPath.trim())
          .limit(20);
      for (final row in byPath) {
        final data = normRow(row);
        if (looksLikeUsableOverride(data)) return data;
      }
      final byPathLower = await supabase
          .from('ascension_overrides')
          .select()
          .eq('artist_doc_path_lower', normalizedPath)
          .limit(20);
      for (final row in byPathLower) {
        final data = normRow(row);
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
      next['points'] = (override['points'] as num).toDouble();
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
    double? existingPoints() {
      final candidates = <Object?>[
        ascension['points'],
        artistData['panel_ascensionPoints'],
        artistData['ascensionPoints'],
      ];
      for (final raw in candidates) {
        if (raw is num) return raw.toDouble();
        final parsed = double.tryParse((raw ?? '').toString().trim());
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
    metrics['jntRevenueToCrowned'] = 0.0;
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
    required String artistEmail,
    required String artistCollection,
    required String artistName,
    required Map<String, dynamic> ascensionPayload,
    required double previousPoints,
  }) async {
    final supabase = Supabase.instance.client;
    final email = artistEmail.trim().toLowerCase();
    final docId = _overrideDocIdFromPath('$artistCollection/$email');
    final now = DateTime.now().toIso8601String();

    await supabase.from('ascension_current').upsert(<String, dynamic>{
      'id': docId,
      'artist_doc_path': '$artistCollection/$email',
      'artist_id': email,
      'artist_email': email,
      'artist_name': artistName.trim(),
      'ascension': ascensionPayload,
      'updated_at': now,
    });

    final nextPoints = (ascensionPayload['points'] as num?)?.toDouble() ?? 0.0;
    if (nextPoints != previousPoints) {
      await supabase.from('ascension_audit_logs').insert(<String, dynamic>{
        'artist_doc_path': '$artistCollection/$email',
        'artist_id': email,
        'artist_email': email,
        'artist_name': artistName.trim(),
        'previous_points': previousPoints,
        'new_points': nextPoints,
        'new_tier': (ascensionPayload['tier'] ?? '').toString(),
        'sponsorship_eligible': ascensionPayload['sponsorshipEligible'] == true,
        'source': 'auto_sync',
        'created_at': now,
      });
    }

    final tier = (ascensionPayload['tier'] ?? '').toString().trim();
    final eligible = ascensionPayload['sponsorshipEligible'] == true;
    final row = await supabase
        .from(artistCollection)
        .select('profile')
        .eq('email', email)
        .maybeSingle();
    final currentProfile = Map<String, dynamic>.from(
      (row?['profile'] as Map?) ?? const <String, dynamic>{},
    );
    await supabase.from(artistCollection).update(<String, dynamic>{
      'profile': <String, dynamic>{
        ...currentProfile,
        'ascension': ascensionPayload,
        'ascensionTier': tier,
        'ascensionPoints': nextPoints,
        'sponsorshipEligible': eligible,
      },
      'updated_at': now,
    }).eq('email', email);
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

  static Map<String, dynamic> _normalizeClientRequestRow(Map<String, dynamic> row) {
    final summary = Map<String, dynamic>.from((row['summary'] as Map?) ?? const <String, dynamic>{});
    final details = Map<String, dynamic>.from((row['details'] as Map?) ?? const <String, dynamic>{});
    return <String, dynamic>{
      ...row,
      ...summary,
      '_details': details,
      if (row['client_email'] != null && !summary.containsKey('clientEmail'))
        'clientEmail': row['client_email'],
    };
  }

  static Map<String, dynamic> _normalizeCompanyRequestRow(Map<String, dynamic> row) {
    final payload = Map<String, dynamic>.from((row['payload'] as Map?) ?? const <String, dynamic>{});
    return <String, dynamic>{
      ...row,
      ...payload,
      if (row['client_email'] != null) 'clientEmail': row['client_email'],
      if (row['client_rating'] != null) 'clientRating': row['client_rating'],
      if (row['need_by'] != null) 'needBy': row['need_by'],
      if (row['delivered_at'] != null) 'deliveredAt': row['delivered_at'],
      if (row['shipped_at'] != null) 'shippedAt': row['shipped_at'],
      if (row['updated_at'] != null) 'updatedAt': row['updated_at'],
      if (row['created_at'] != null) 'createdAt': row['created_at'],
      '_details': const <String, dynamic>{},
    };
  }

  static String _resolveClientIdentityKey(Map<String, dynamic> data) {
    final orderMap = (data['order'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final acceptanceMap = (data['acceptance'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final clientProfileSnapshot = (data['clientProfileSnapshot'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final basicSnapshot = (clientProfileSnapshot['basic'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    final rootIdentity = _normalizeIdentity(_firstNonEmptyString(<Object?>[
      data['clientUid'],
      data['acceptedByClientUid'],
      data['clientId'],
      data['clientEmail'],
      data['client_email'],
      data['acceptedByClientEmail'],
      data['selectedClientEmail'],
      orderMap['selectedClientEmail'],
      acceptanceMap['acceptedByClientEmail'],
      basicSnapshot['email'],
    ]));
    if (rootIdentity.isNotEmpty) return rootIdentity;

    final detailData = (data['_details'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final detailOrder = (detailData['order'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final detailAcceptance = (detailData['acceptance'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final detailClientSnapshot = (detailData['clientProfileSnapshot'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final detailBasic = (detailClientSnapshot['basic'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    final detailIdentity = _normalizeIdentity(_firstNonEmptyString(<Object?>[
      detailData['clientUid'],
      detailData['acceptedByClientUid'],
      detailData['clientId'],
      detailData['clientEmail'],
      detailData['acceptedByClientEmail'],
      detailData['selectedClientEmail'],
      detailOrder['selectedClientEmail'],
      detailAcceptance['acceptedByClientEmail'],
      detailBasic['email'],
    ]));
    if (detailIdentity.isNotEmpty) return detailIdentity;

    final fallbackName = _normalizeIdentity(_firstNonEmptyString(<Object?>[
      data['clientName'],
      data['acceptedByClientName'],
      basicSnapshot['name'],
    ]));
    if (fallbackName.isNotEmpty) return 'name:$fallbackName';
    return '';
  }

  static DateTime? _resolveCompletionDate(Map<String, dynamic> data) {
    DateTime? asDate(Object? raw) {
      if (raw is String) return DateTime.tryParse(raw);
      return null;
    }

    return asDate(data['deliveredAt'] ?? data['delivered_at']) ??
        asDate(data['completedAt'] ?? data['completed_at']) ??
        asDate(data['shippedAt'] ?? data['shipped_at']) ??
        asDate(data['updatedAt'] ?? data['updated_at']) ??
        asDate(data['createdAt'] ?? data['created_at']);
  }
}
