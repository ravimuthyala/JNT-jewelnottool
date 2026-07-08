import 'dart:math' as math;

/// One shared source of truth for JNT Ascension calculations.
///
/// IMPORTANT: This engine uses the weighted stage points from the
/// JNT Ascension economics document. Points are earned only when each
/// stage occurs. They are NOT granted all at once.
///
/// Stage points:
/// - Completed order: 25 * 100% = 25.0
/// - On-time delivery: 10 * 85% = 8.5
/// - 5-star client review: 15 * 60% = 9.0
/// - Repeat client order: 20 * 30% = 6.0
/// - Portfolio upload: 5 * 5% = 0.25, displayed as 0.3
///
/// Portfolio upload points are awarded once per completed order that has
/// at least one uploaded artwork/design photo. They are NOT awarded per photo.
/// Example: if an artist uploads 6 completion photos for the same order,
/// that counts as 1 portfolio-upload event, not 6.
///
/// Blended expected points per full order cycle = 48.8.
class JntAscensionEngine {
  const JntAscensionEngine._();

  static const double averageOrderValue = 125.0;
  static const double platformTakeRate = 0.20;
  static const int activeArtistOrdersPerMonth = 8;
  static const double jntRevenuePerOrder = 25.0;

  static const double makerMinPoints = 0.0;
  static const double goldsmithMinPoints = 1000.0;
  static const double crownedMinPoints = 9750.0;
  static const double crownedMinJntRevenue = 5000.0;

  // Raw business point values before frequency weighting.
  static const double rawCompleteOrderPoints = 25.0;
  static const double rawOnTimeDeliveryPoints = 10.0;
  static const double rawFiveStarReviewPoints = 15.0;
  static const double rawRepeatClientOrderPoints = 20.0;
  static const double rawPortfolioUploadPoints = 5.0;

  // Frequency assumptions from the JNT Ascension document.
  static const double completeOrderFrequency = 1.00;
  static const double onTimeDeliveryFrequency = 0.85;
  static const double fiveStarReviewFrequency = 0.60;
  static const double repeatClientOrderFrequency = 0.30;
  static const double portfolioUploadFrequency = 0.05;

  // Weighted points earned when each stage occurs in the app.
  static const double pointsCompleteOrder = 25.0;
  static const double pointsOnTimeDelivery = 8.5;
  static const double pointsFiveStarReview = 9.0;
  static const double pointsRepeatClientOrder = 6.0;

  // 5 raw points * 5% frequency = 0.25 actual points.
  // UI formatting may display this as 0.3, but calculations use 0.25.
  static const double pointsPortfolioUpload =
      rawPortfolioUploadPoints * portfolioUploadFrequency;

  static const double expectedCompleteOrderPoints = pointsCompleteOrder;
  static const double expectedOnTimeDeliveryPoints = pointsOnTimeDelivery;
  static const double expectedFiveStarReviewPoints = pointsFiveStarReview;
  static const double expectedRepeatClientOrderPoints = pointsRepeatClientOrder;
  static const double expectedPortfolioUploadPoints = pointsPortfolioUpload;
  static const double blendedAveragePointsPerOrder = 48.8;

  static JntAscensionResult calculate({
    required int completedOrders,
    required int onTimeDeliveries,
    required int fiveStarReviews,
    required int repeatClientOrders,
    required int portfolioUploads,
    required double artistGmv,
    double platformTakeRate = JntAscensionEngine.platformTakeRate,
  }) {
    final safeCompletedOrders = math.max(0, completedOrders);
    final safeOnTimeDeliveries = math.max(0, onTimeDeliveries);
    final safeFiveStarReviews = math.max(0, fiveStarReviews);
    final safeRepeatClientOrders = math.max(0, repeatClientOrders);
    // `portfolioUploads` can come from older/frontend/admin code as a raw
    // photo count. Ascension rules should count portfolio upload once per
    // completed client/brand order that has artwork uploaded, not once per
    // photo. Capping by completed orders prevents 10 uploaded photos on one
    // order from becoming 10 portfolio-upload awards.
    final safeRawPortfolioUploads = math.max(0, portfolioUploads);
    final safePortfolioUploads = math.min(
      safeRawPortfolioUploads,
      safeCompletedOrders,
    );
    final safeArtistGmv = artistGmv.isFinite && artistGmv > 0 ? artistGmv : 0.0;
    final safeTakeRate = platformTakeRate.isFinite && platformTakeRate > 0
        ? platformTakeRate
        : JntAscensionEngine.platformTakeRate;

    final double completedOrderPoints =
        safeCompletedOrders * pointsCompleteOrder;
    final double onTimeDeliveryPoints =
        safeOnTimeDeliveries * pointsOnTimeDelivery;
    final double fiveStarReviewPoints =
        safeFiveStarReviews * pointsFiveStarReview;
    final double repeatClientOrderPoints =
        safeRepeatClientOrders * pointsRepeatClientOrder;
    final double portfolioUploadPoints =
        safePortfolioUploads * pointsPortfolioUpload;

    final double totalPoints = completedOrderPoints +
        onTimeDeliveryPoints +
        fiveStarReviewPoints +
        repeatClientOrderPoints +
        portfolioUploadPoints;

    final double jntRevenue = safeArtistGmv * safeTakeRate;
    final crownedPointsQualified = totalPoints >= crownedMinPoints;
    final crownedRevenueQualified = jntRevenue >= crownedMinJntRevenue;

    final tier = _tierFor(points: totalPoints, jntRevenue: jntRevenue);
    final nextTier = _nextTierFor(tier);
    final pointsToNextTier = _pointsToNextTier(tier: tier, points: totalPoints);
    final jntRevenueToCrowned =
        math.max(0.0, crownedMinJntRevenue - jntRevenue);

    return JntAscensionResult(
      tier: tier,
      tierLabel: labelForTier(tier),
      points: totalPoints,
      completedOrders: safeCompletedOrders,
      onTimeDeliveries: safeOnTimeDeliveries,
      fiveStarReviews: safeFiveStarReviews,
      repeatClientOrders: safeRepeatClientOrders,
      portfolioUploads: safePortfolioUploads,
      artistGmv: safeArtistGmv,
      jntRevenue: jntRevenue,
      completedOrderPoints: completedOrderPoints,
      onTimeDeliveryPoints: onTimeDeliveryPoints,
      fiveStarReviewPoints: fiveStarReviewPoints,
      repeatClientOrderPoints: repeatClientOrderPoints,
      portfolioUploadPoints: portfolioUploadPoints,
      crownedPointsQualified: crownedPointsQualified,
      crownedRevenueQualified: crownedRevenueQualified,
      jntRevenueToCrowned: jntRevenueToCrowned,
      prioritySearch: tier == 'goldsmith' || tier == 'crowned',
      sponsorshipEligible: tier == 'goldsmith' || tier == 'crowned',
      insuranceEligible: tier == 'crowned',
      pointsToNextTier: pointsToNextTier,
      nextTier: nextTier,
      nextTierLabel: labelForTier(nextTier),
      generatedTags: _tagsForTier(tier),
      unlockedPerks: _perksForTier(tier),
      crownedPointsOnlyMessage:
          crownedPointsQualified && !crownedRevenueQualified
              ? 'Crowned points achieved. \$${jntRevenueToCrowned.toStringAsFixed(0)} JNT revenue remaining.'
              : '',
    );
  }

  static String _tierFor({required double points, required double jntRevenue}) {
    if (points >= crownedMinPoints && jntRevenue >= crownedMinJntRevenue) {
      return 'crowned';
    }
    if (points >= goldsmithMinPoints) return 'goldsmith';
    return 'maker';
  }

  static double _pointsToNextTier({required String tier, required double points}) {
    if (tier == 'maker') return math.max(0.0, goldsmithMinPoints - points);
    if (tier == 'goldsmith') return math.max(0.0, crownedMinPoints - points);
    return 0.0;
  }

  static String _nextTierFor(String tier) {
    if (tier == 'maker') return 'goldsmith';
    if (tier == 'goldsmith') return 'crowned';
    return 'crowned';
  }

  static String labelForTier(String tier) {
    switch (tier.trim().toLowerCase()) {
      case 'crowned':
        return 'Crowned';
      case 'goldsmith':
        return 'Goldsmith';
      default:
        return 'Maker';
    }
  }

  static String formatPoints(num value) {
    return value.toDouble().toStringAsFixed(2);
  }

  static List<String> _tagsForTier(String tier) {
    switch (tier) {
      case 'crowned':
        return const ['Crowned', 'Priority Search', 'Sponsorship Eligible', 'Insurance Eligible'];
      case 'goldsmith':
        return const ['Goldsmith', 'Priority Search', 'Sponsorship Eligible'];
      default:
        return const ['Maker'];
    }
  }

  static List<String> _perksForTier(String tier) {
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
        return const ['Welcome gift', 'Group orders', 'Learning & development'];
    }
  }
}

class JntAscensionResult {
  const JntAscensionResult({
    required this.tier,
    required this.tierLabel,
    required this.points,
    required this.completedOrders,
    required this.onTimeDeliveries,
    required this.fiveStarReviews,
    required this.repeatClientOrders,
    required this.portfolioUploads,
    required this.artistGmv,
    required this.jntRevenue,
    required this.completedOrderPoints,
    required this.onTimeDeliveryPoints,
    required this.fiveStarReviewPoints,
    required this.repeatClientOrderPoints,
    required this.portfolioUploadPoints,
    required this.crownedPointsQualified,
    required this.crownedRevenueQualified,
    required this.jntRevenueToCrowned,
    required this.prioritySearch,
    required this.sponsorshipEligible,
    required this.insuranceEligible,
    required this.pointsToNextTier,
    required this.nextTier,
    required this.nextTierLabel,
    required this.generatedTags,
    required this.unlockedPerks,
    required this.crownedPointsOnlyMessage,
  });

  final String tier;
  final String tierLabel;
  final double points;
  final int completedOrders;
  final int onTimeDeliveries;
  final int fiveStarReviews;
  final int repeatClientOrders;
  final int portfolioUploads;
  final double artistGmv;
  final double jntRevenue;
  final double completedOrderPoints;
  final double onTimeDeliveryPoints;
  final double fiveStarReviewPoints;
  final double repeatClientOrderPoints;
  final double portfolioUploadPoints;
  final bool crownedPointsQualified;
  final bool crownedRevenueQualified;
  final double jntRevenueToCrowned;
  final bool prioritySearch;
  final bool sponsorshipEligible;
  final bool insuranceEligible;
  final double pointsToNextTier;
  final String nextTier;
  final String nextTierLabel;
  final List<String> generatedTags;
  final List<String> unlockedPerks;
  final String crownedPointsOnlyMessage;

  Map<String, dynamic> toAscensionMap() {
    return <String, dynamic>{
      'tier': tier,
      'tierLabel': tierLabel,
      'points': points,
      'totalPoints': points,
      'pointsDisplay': JntAscensionEngine.formatPoints(points),
      'pointsToNextTier': pointsToNextTier,
      'pointsToNextTierDisplay': JntAscensionEngine.formatPoints(pointsToNextTier),
      'nextTier': nextTier,
      'nextTierLabel': nextTierLabel,
      'prioritySearch': prioritySearch,
      'sponsorshipEligible': sponsorshipEligible,
      'insuranceEligible': insuranceEligible,
      'generatedTags': generatedTags,
      'unlockedPerks': unlockedPerks,
      'crownedPointsQualified': crownedPointsQualified,
      'crownedRevenueQualified': crownedRevenueQualified,
      'jntRevenueToCrowned': jntRevenueToCrowned,
      'crownedPointsOnlyMessage': crownedPointsOnlyMessage,
      'metrics': <String, dynamic>{
        'completedOrders': completedOrders,
        'onTimeDeliveries': onTimeDeliveries,
        'fiveStarReviews': fiveStarReviews,
        'repeatClientOrders': repeatClientOrders,
        'portfolioUploads': portfolioUploads,
        'artistGmv': artistGmv,
        'jntRevenue': jntRevenue,
        'points': points,
        'completedOrderPoints': completedOrderPoints,
        'onTimeDeliveryPoints': onTimeDeliveryPoints,
        'fiveStarReviewPoints': fiveStarReviewPoints,
        'repeatClientOrderPoints': repeatClientOrderPoints,
        'portfolioUploadPoints': portfolioUploadPoints,
        'crownedPointsQualified': crownedPointsQualified,
        'crownedRevenueQualified': crownedRevenueQualified,
        'jntRevenueToCrowned': jntRevenueToCrowned,
      },
    };
  }
}
