import '../utils/jnt_ascension_engine.dart';

enum ArtistAscensionTier { maker, goldsmith, crowned }

class ArtistAscensionState {
  const ArtistAscensionState({
    required this.tier,
    required this.points,
    required this.pointsToNextTier,
    required this.nextTierLabel,
    required this.prioritySearch,
    required this.sponsorshipEligible,
    required this.insuranceEligible,
    required this.generatedTags,
    required this.unlockedPerks,
    this.completedOrders = 0,
    this.onTimeDeliveries = 0,
    this.fiveStarReviews = 0,
    this.repeatClientOrders = 0,
    this.portfolioUploads = 0,
    this.artistGmv = 0,
    this.jntRevenue = 0,
    this.crownedPointsQualified = false,
    this.crownedRevenueQualified = false,
    this.jntRevenueToCrowned = 0,
    this.crownedPointsOnlyMessage = '',
  });

  final ArtistAscensionTier tier;
  final double points;
  final double pointsToNextTier;
  final String nextTierLabel;
  final bool prioritySearch;
  final bool sponsorshipEligible;
  final bool insuranceEligible;
  final List<String> generatedTags;
  final List<String> unlockedPerks;
  final int completedOrders;
  final int onTimeDeliveries;
  final int fiveStarReviews;
  final int repeatClientOrders;
  final int portfolioUploads;
  final double artistGmv;
  final double jntRevenue;
  final bool crownedPointsQualified;
  final bool crownedRevenueQualified;
  final double jntRevenueToCrowned;
  final String crownedPointsOnlyMessage;

  int get currentPoints => points.round();
  int get lifetimeOrders => completedOrders;
  double get artistGMV => artistGmv;
  String get tierKey => tier.name;
  String get tierLabel => _tierLabel(tier);
  String get nextTier => nextTierLabel;
  bool get isMaker => tier == ArtistAscensionTier.maker;
  bool get isGoldsmith => tier == ArtistAscensionTier.goldsmith;
  bool get isCrowned => tier == ArtistAscensionTier.crowned;

  double get progress {
    if (tier == ArtistAscensionTier.crowned) return 1;
    if (tier == ArtistAscensionTier.maker) {
      return (points / JntAscensionEngine.goldsmithMinPoints).clamp(0.0, 1.0);
    }
    return (points / JntAscensionEngine.crownedMinPoints).clamp(0.0, 1.0);
  }
}

class ArtistAscensionResult {
  const ArtistAscensionResult({
    required this.tier,
    required this.points,
    required this.prioritySearch,
    required this.sponsorshipEligible,
    required this.insuranceEligible,
    required this.generatedTags,
    required this.unlockedPerks,
    required this.pointsToNextTier,
    required this.nextTier,
    this.artistGmv = 0,
    this.jntRevenue = 0,
    this.crownedPointsQualified = false,
    this.crownedRevenueQualified = false,
    this.jntRevenueToCrowned = 0,
    this.crownedPointsOnlyMessage = '',
  });

  final String tier; // maker | goldsmith | crowned
  final double points;
  final bool prioritySearch;
  final bool sponsorshipEligible;
  final bool insuranceEligible;
  final List<String> generatedTags;
  final List<String> unlockedPerks;
  final double pointsToNextTier;
  final String nextTier;
  final double artistGmv;
  final double jntRevenue;
  final bool crownedPointsQualified;
  final bool crownedRevenueQualified;
  final double jntRevenueToCrowned;
  final String crownedPointsOnlyMessage;
}

ArtistAscensionState artistAscensionFromDoc(Map<String, dynamic> data) {
  final ascension = _asMap(data['ascension']);
  final metrics = _asMap(ascension['metrics']);
  final economics = _asMap(ascension['economics']);
  final margin = _asMap(economics['margin']);

  final completedOrders = _readInt([
    metrics['completedOrders'],
    metrics['ordersCompleted'],
    metrics['completed_orders'],
    ascension['completedOrders'],
    data['completedOrders'],
    data['ordersCompleted'],
  ]);
  final onTimeDeliveries = _readInt([
    metrics['onTimeDeliveries'],
    metrics['on_time_deliveries'],
    ascension['onTimeDeliveries'],
    data['onTimeDeliveries'],
  ]);
  final fiveStarReviews = _readInt([
    metrics['fiveStarReviews'],
    metrics['five_star_reviews'],
    ascension['fiveStarReviews'],
    data['fiveStarReviews'],
  ]);
  final repeatClientOrders = _readInt([
    metrics['repeatClientOrders'],
    metrics['repeat_client_orders'],
    ascension['repeatClientOrders'],
    data['repeatClientOrders'],
  ]);
  final portfolioUploads = _readInt([
    metrics['portfolioUploads'],
    metrics['portfolio_uploads'],
    ascension['portfolioUploads'],
    data['portfolioUploads'],
    data['portfolioCount'],
  ]);

  final storedPoints = _readInt([
    ascension['points'],
    ascension['totalPoints'],
    metrics['points'],
    data['ascensionPoints'],
    data['points'],
  ]);

  final double artistGmv = _readDouble([
    metrics['artistGmv'],
    metrics['artistGMV'],
    metrics['gmv'],
    ascension['artistGmv'],
    data['artistGmv'],
    data['gmv'],
  ]);

  final double storedJntRevenue = _readDouble([
    metrics['jntRevenue'],
    ascension['jntRevenue'],
    margin['jntRevenue'],
    data['jntRevenue'],
  ]);

  final hasActivity = completedOrders > 0 ||
      onTimeDeliveries > 0 ||
      fiveStarReviews > 0 ||
      repeatClientOrders > 0 ||
      portfolioUploads > 0;

  if (hasActivity) {
    final calculated = JntAscensionEngine.calculate(
      completedOrders: completedOrders,
      onTimeDeliveries: onTimeDeliveries,
      fiveStarReviews: fiveStarReviews,
      repeatClientOrders: repeatClientOrders,
      portfolioUploads: portfolioUploads,
      artistGmv: artistGmv,
    );
    return _stateFromEngine(calculated);
  }

  final fallback = calculateArtistAscension(
    storedPoints,
    artistGmv: artistGmv,
    jntRevenue: storedJntRevenue,
  );
  return _stateFromResult(fallback);
}

ArtistAscensionResult calculateArtistAscension(
  num points, {
  double artistGmv = 0,
  double jntRevenue = 0,
}) {
  final double safePoints = points < 0 ? 0.0 : points.toDouble();
  final double safeArtistGmv = artistGmv.isFinite && artistGmv > 0 ? artistGmv : 0.0;
  final double resolvedJntRevenue = jntRevenue > 0
      ? jntRevenue.toDouble()
      : safeArtistGmv * JntAscensionEngine.platformTakeRate;

  final crownedPointsQualified = safePoints >= JntAscensionEngine.crownedMinPoints;
  final crownedRevenueQualified = resolvedJntRevenue >= JntAscensionEngine.crownedMinJntRevenue;

  String tier;
  double pointsToNextTier;
  String nextTier;
  if (crownedPointsQualified && crownedRevenueQualified) {
    tier = 'crowned';
    pointsToNextTier = 0.0;
    nextTier = 'Top Tier Reached';
  } else if (safePoints >= JntAscensionEngine.goldsmithMinPoints) {
    tier = 'goldsmith';
    pointsToNextTier = safePoints >= JntAscensionEngine.crownedMinPoints
        ? 0.0
        : (JntAscensionEngine.crownedMinPoints - safePoints).toDouble();
    nextTier = 'Crowned';
  } else {
    tier = 'maker';
    pointsToNextTier =
        (JntAscensionEngine.goldsmithMinPoints - safePoints).toDouble();
    nextTier = 'Goldsmith';
  }

  final generatedTags = _tagsForTier(tier);
  final unlockedPerks = _perksForTier(tier);
  final double jntRevenueToCrowned =
      (JntAscensionEngine.crownedMinJntRevenue - resolvedJntRevenue)
          .clamp(0.0, JntAscensionEngine.crownedMinJntRevenue)
          .toDouble();

  return ArtistAscensionResult(
    tier: tier,
    points: safePoints,
    prioritySearch: tier == 'goldsmith' || tier == 'crowned',
    sponsorshipEligible: tier == 'goldsmith' || tier == 'crowned',
    insuranceEligible: tier == 'crowned',
    generatedTags: generatedTags,
    unlockedPerks: unlockedPerks,
    pointsToNextTier: pointsToNextTier,
    nextTier: nextTier,
    artistGmv: safeArtistGmv,
    jntRevenue: resolvedJntRevenue,
    crownedPointsQualified: crownedPointsQualified,
    crownedRevenueQualified: crownedRevenueQualified,
    jntRevenueToCrowned: jntRevenueToCrowned,
    crownedPointsOnlyMessage: crownedPointsQualified && !crownedRevenueQualified
        ? 'Crowned points achieved. \$${jntRevenueToCrowned.toStringAsFixed(0)} JNT revenue remaining.'
        : '',
  );
}

ArtistAscensionResult calculateArtistAscensionFromActivity({
  required int completedOrders,
  required int onTimeDeliveries,
  required int fiveStarReviews,
  required int repeatClientOrders,
  required int portfolioUploads,
  required double artistGmv,
}) {
  final result = JntAscensionEngine.calculate(
    completedOrders: completedOrders,
    onTimeDeliveries: onTimeDeliveries,
    fiveStarReviews: fiveStarReviews,
    repeatClientOrders: repeatClientOrders,
    portfolioUploads: portfolioUploads,
    artistGmv: artistGmv,
  );

  return ArtistAscensionResult(
    tier: result.tier,
    points: result.points,
    prioritySearch: result.prioritySearch,
    sponsorshipEligible: result.sponsorshipEligible,
    insuranceEligible: result.insuranceEligible,
    generatedTags: result.generatedTags,
    unlockedPerks: result.unlockedPerks,
    pointsToNextTier: result.pointsToNextTier,
    nextTier: result.nextTierLabel,
    artistGmv: result.artistGmv,
    jntRevenue: result.jntRevenue,
    crownedPointsQualified: result.crownedPointsQualified,
    crownedRevenueQualified: result.crownedRevenueQualified,
    jntRevenueToCrowned: result.jntRevenueToCrowned,
    crownedPointsOnlyMessage: result.crownedPointsOnlyMessage,
  );
}

ArtistAscensionState _stateFromEngine(JntAscensionResult result) {
  return ArtistAscensionState(
    tier: _tierFromString(result.tier),
    points: result.points,
    pointsToNextTier: result.pointsToNextTier,
    nextTierLabel: result.nextTierLabel,
    prioritySearch: result.prioritySearch,
    sponsorshipEligible: result.sponsorshipEligible,
    insuranceEligible: result.insuranceEligible,
    generatedTags: result.generatedTags,
    unlockedPerks: result.unlockedPerks,
    completedOrders: result.completedOrders,
    onTimeDeliveries: result.onTimeDeliveries,
    fiveStarReviews: result.fiveStarReviews,
    repeatClientOrders: result.repeatClientOrders,
    portfolioUploads: result.portfolioUploads,
    artistGmv: result.artistGmv,
    jntRevenue: result.jntRevenue,
    crownedPointsQualified: result.crownedPointsQualified,
    crownedRevenueQualified: result.crownedRevenueQualified,
    jntRevenueToCrowned: result.jntRevenueToCrowned,
    crownedPointsOnlyMessage: result.crownedPointsOnlyMessage,
  );
}

ArtistAscensionState _stateFromResult(ArtistAscensionResult result) {
  return ArtistAscensionState(
    tier: _tierFromString(result.tier),
    points: result.points,
    pointsToNextTier: result.pointsToNextTier,
    nextTierLabel: result.nextTier,
    prioritySearch: result.prioritySearch,
    sponsorshipEligible: result.sponsorshipEligible,
    insuranceEligible: result.insuranceEligible,
    generatedTags: result.generatedTags,
    unlockedPerks: result.unlockedPerks,
    artistGmv: result.artistGmv,
    jntRevenue: result.jntRevenue,
    crownedPointsQualified: result.crownedPointsQualified,
    crownedRevenueQualified: result.crownedRevenueQualified,
    jntRevenueToCrowned: result.jntRevenueToCrowned,
    crownedPointsOnlyMessage: result.crownedPointsOnlyMessage,
  );
}

ArtistAscensionTier _tierFromString(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'crowned':
      return ArtistAscensionTier.crowned;
    case 'goldsmith':
      return ArtistAscensionTier.goldsmith;
    default:
      return ArtistAscensionTier.maker;
  }
}

String _tierLabel(ArtistAscensionTier tier) {
  switch (tier) {
    case ArtistAscensionTier.crowned:
      return 'Crowned';
    case ArtistAscensionTier.goldsmith:
      return 'Goldsmith';
    case ArtistAscensionTier.maker:
      return 'Maker';
  }
}

List<String> _tagsForTier(String tier) {
  switch (tier) {
    case 'crowned':
      return const [
        'Crowned',
        'Priority Search',
        'Sponsorship Eligible',
        'Insurance Eligible',
      ];
    case 'goldsmith':
      return const [
        'Goldsmith',
        'Priority Search',
        'Sponsorship Eligible',
      ];
    default:
      return const ['Maker'];
  }
}

List<String> _perksForTier(String tier) {
  switch (tier) {
    case 'crowned':
      return const [
        'Welcome gift',
        'Group orders',
        'Learning & development',
        'Sponsorship requests',
        'Priority in search',
        'Annual elite conference',
        'Insurance reimbursement eligibility',
      ];
    case 'goldsmith':
      return const [
        'Welcome gift',
        'Group orders',
        'Learning & development',
        'Sponsorship requests',
        'Priority in search',
        'Annual elite conference',
      ];
    default:
      return const [
        'Welcome gift',
        'Group orders',
        'Learning & development',
      ];
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
  return const <String, dynamic>{};
}

int _readInt(List<Object?> values) {
  for (final value in values) {
    if (value == null) continue;
    if (value is int) return value;
    if (value is num) return value.round();
    final parsed = int.tryParse(value.toString().trim());
    if (parsed != null) return parsed;
  }
  return 0;
}

double _readDouble(List<Object?> values) {
  for (final value in values) {
    if (value == null) continue;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    final cleaned = value.toString().replaceAll(RegExp(r'[^0-9.\-]'), '').trim();
    final parsed = double.tryParse(cleaned);
    if (parsed != null) return parsed;
  }
  return 0.0;
}
