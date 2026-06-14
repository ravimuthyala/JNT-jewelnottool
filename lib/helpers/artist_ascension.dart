import 'package:cloud_firestore/cloud_firestore.dart';

enum ArtistAscensionTier { maker, goldsmith, crowned }

const int completedOrderPoints = 25;
const int onTimeDeliveryPoints = 10;
const int fiveStarClientReviewPoints = 15;
const int repeatClientOrderPoints = 20;
const int portfolioUploadPoints = 5;

class ArtistAscensionState {
  const ArtistAscensionState({
    required this.tier,
    required this.points,
    required this.lifetimeOrders,
    required this.artistGMV,
    required this.jntRevenue,
    required this.prioritySearch,
    required this.sponsorshipEligible,
    required this.insuranceEligible,
    this.lastTierUpdatedAt,
  });

  final ArtistAscensionTier tier;
  final int points;
  final int lifetimeOrders;
  final double artistGMV;
  final double jntRevenue;
  final bool prioritySearch;
  final bool sponsorshipEligible;
  final bool insuranceEligible;
  final Timestamp? lastTierUpdatedAt;

  static const ArtistAscensionState defaults = ArtistAscensionState(
    tier: ArtistAscensionTier.maker,
    points: 0,
    lifetimeOrders: 0,
    artistGMV: 0,
    jntRevenue: 0,
    prioritySearch: false,
    sponsorshipEligible: false,
    insuranceEligible: false,
  );
}

ArtistAscensionState calculateArtistAscension(int points) {
  if (points >= 9750) {
    return ArtistAscensionState(
      tier: ArtistAscensionTier.crowned,
      points: points,
      lifetimeOrders: 0,
      artistGMV: 0,
      jntRevenue: 0,
      prioritySearch: true,
      sponsorshipEligible: true,
      insuranceEligible: true,
    );
  }
  if (points >= 1000) {
    return ArtistAscensionState(
      tier: ArtistAscensionTier.goldsmith,
      points: points,
      lifetimeOrders: 0,
      artistGMV: 0,
      jntRevenue: 0,
      prioritySearch: true,
      sponsorshipEligible: true,
      insuranceEligible: false,
    );
  }
  return ArtistAscensionState(
    tier: ArtistAscensionTier.maker,
    points: points,
    lifetimeOrders: 0,
    artistGMV: 0,
    jntRevenue: 0,
    prioritySearch: false,
    sponsorshipEligible: false,
    insuranceEligible: false,
  );
}

ArtistAscensionState artistAscensionFromDoc(Map<String, dynamic>? artistDoc) {
  final root = artistDoc ?? const <String, dynamic>{};
  final ascension =
      (root['ascension'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
  final profile =
      (root['profile'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

  int readInt(Object? value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString().trim()) ?? fallback;
  }

  double readDouble(Object? value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString().trim()) ?? fallback;
  }

  bool readBool(Object? value, {bool fallback = false}) {
    if (value is bool) return value;
    final text = (value ?? '').toString().trim().toLowerCase();
    if (text == 'true') return true;
    if (text == 'false') return false;
    return fallback;
  }

  ArtistAscensionTier parseTier(Object? raw) {
    final value = (raw ?? '').toString().trim().toLowerCase();
    switch (value) {
      case 'crowned':
        return ArtistAscensionTier.crowned;
      case 'goldsmith':
        return ArtistAscensionTier.goldsmith;
      default:
        return ArtistAscensionTier.maker;
    }
  }

  final points = readInt(ascension['points']);
  final derived = calculateArtistAscension(points);
  final tierFromFields = parseTier(
    (root['sponsorshipTier'] ?? '').toString().trim().isNotEmpty
        ? root['sponsorshipTier']
        : (root['panel_ascensionLevel'] ?? '').toString().trim().isNotEmpty
        ? root['panel_ascensionLevel']
        : (profile['ascensionTier'] ?? '').toString().trim().isNotEmpty
        ? profile['ascensionTier']
        : (ascension['tier'] ?? '').toString().trim().isNotEmpty
        ? ascension['tier']
        : profile['ascensionTier'],
  );
  final explicitTier =
      tierFromFields == ArtistAscensionTier.maker &&
          (ascension['tier'] ?? root['panel_ascensionLevel'] ?? root['sponsorshipTier'] ?? profile['ascensionTier'] ?? '')
              .toString()
              .trim()
              .isEmpty
      ? derived.tier
      : tierFromFields;
  final tier = explicitTier;

  return ArtistAscensionState(
    tier: tier,
    points: points,
    lifetimeOrders: readInt(ascension['lifetimeOrders']),
    artistGMV: readDouble(ascension['artistGMV']),
    jntRevenue: readDouble(ascension['jntRevenue']),
    prioritySearch: ascension.containsKey('prioritySearch')
        ? readBool(ascension['prioritySearch'])
        : derived.prioritySearch,
    sponsorshipEligible: ascension.containsKey('sponsorshipEligible')
        ? readBool(ascension['sponsorshipEligible'])
        : (tier == ArtistAscensionTier.goldsmith ||
              tier == ArtistAscensionTier.crowned
          ? true
          : derived.sponsorshipEligible),
    insuranceEligible: ascension.containsKey('insuranceEligible')
        ? readBool(ascension['insuranceEligible'])
        : derived.insuranceEligible,
    lastTierUpdatedAt: ascension['lastTierUpdatedAt'] is Timestamp
        ? ascension['lastTierUpdatedAt'] as Timestamp
        : null,
  );
}
