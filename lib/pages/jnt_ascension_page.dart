// ignore_for_file: unnecessary_non_null_assertion

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/client_request_v2.dart';
import '../services/artist_requests_repository.dart';
import '../utils/jnt_ascension_engine.dart';
import '../theme/app_colors.dart';
import '../widgets/jnt_modal_app_bar.dart';

class JntAscensionPage extends StatefulWidget {
  const JntAscensionPage({super.key});

  @override
  State<JntAscensionPage> createState() => _JntAscensionPageState();
}

class _JntAscensionPageState extends State<JntAscensionPage> {
  static const int goldsmithMin = 1000;
  static const int crownedMin = 9750;
  static const String _emptyValue = '';

  RealtimeChannel? _artistChannel;
  RealtimeChannel? _requestsChannel;
  String _artistCollection = _emptyValue;
  Map<String, dynamic> _artistData = const <String, dynamic>{};
  _AscTab _activeTab = _AscTab.activity;
  bool _syncingAscension = false;
  bool _artistLoaded = false;
  bool _initialAscensionResolved = false;
  bool _hasServerSnapshot = false;
  String _currentArtistEmail = _emptyValue;
  String _currentArtistId = _emptyValue;
  int _portfolioUploads = 0;
  _AscensionStageSummary _stageSummary = const _AscensionStageSummary.empty();

  @override
  void initState() {
    super.initState();
    _bindArtist();
  }

  @override
  void dispose() {
    _artistChannel?.unsubscribe();
    _requestsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _bindArtist() async {
    final supabase = Supabase.instance.client;
    final email = (supabase.auth.currentUser?.email ?? _emptyValue).trim().toLowerCase();
    final uid = (supabase.auth.currentUser?.id ?? _emptyValue).trim();
    if (email.isEmpty && uid.isEmpty) return;
    _currentArtistEmail = email;
    _currentArtistId = uid;

    Map<String, dynamic>? matchedRow;
    String matchedCollection = _emptyValue;

    for (final collection in const <String>['client_artist', 'artist']) {
      try {
        if (uid.isNotEmpty) {
          final row = await supabase.from(collection).select().eq('id', uid).maybeSingle();
          if (row != null) {
            matchedRow = Map<String, dynamic>.from(row);
            matchedCollection = collection;
            break;
          }
        }
      } catch (_) {}
    }

    if (matchedRow == null) {
      for (final collection in const <String>['client_artist', 'artist']) {
        try {
          if (email.isNotEmpty) {
            final row = await supabase.from(collection).select().eq('email', email).maybeSingle();
            if (row != null) {
              matchedRow = Map<String, dynamic>.from(row);
              matchedCollection = collection;
              break;
            }
          }
        } catch (_) {}
      }
    }

    if (matchedRow == null) return;
    _artistCollection = matchedCollection;
    if (mounted) {
      setState(() {
        _artistData = _flattenArtistRow(matchedRow!);
        _portfolioUploads = _portfolioUploadCount(matchedRow!, _artistData);
        _artistLoaded = true;
        _hasServerSnapshot = true;
      });
    }
    unawaited(_syncAscension(email, matchedCollection));
    _subscribeArtistRealtime(email, uid, matchedCollection);
    _subscribeRequestRealtime();
  }

  void _subscribeArtistRealtime(String email, String uid, String collection) {
    _artistChannel?.unsubscribe();
    _requestsChannel?.unsubscribe();
    _artistChannel = Supabase.instance.client
        .channel('jnt_ascension_artist_$collection')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: collection,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: uid.isNotEmpty ? 'id' : 'email',
            value: uid.isNotEmpty ? uid : email,
          ),
          callback: (payload) {
            if (!mounted) return;
            setState(() {
              _artistData = _flattenArtistRow(
                Map<String, dynamic>.from(payload.newRecord),
              );
              _portfolioUploads = _portfolioUploadCount(
                Map<String, dynamic>.from(payload.newRecord),
                _artistData,
              );
              _hasServerSnapshot = true;
            });
          },
        )
        .subscribe();
  }

  static Map<String, dynamic> _flattenArtistRow(Map<String, dynamic> row) {
    final profile = (row['profile'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final profileAscension = (profile['ascension'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    return <String, dynamic>{
      ...row,
      if (profileAscension.isNotEmpty && !row.containsKey('ascension'))
        'ascension': profileAscension,
      if (profile['ascensionTier'] != null && !row.containsKey('panel_ascensionLevel'))
        'panel_ascensionLevel': profile['ascensionTier'],
      if (profile['ascensionPoints'] != null && !row.containsKey('panel_ascensionPoints'))
        'panel_ascensionPoints': profile['ascensionPoints'],
    };
  }

  Future<void> _syncAscension(String email, String collection) async {
    if (_syncingAscension) return;
    _syncingAscension = true;
    try {
      final all = await ArtistRequestsRepository.fetchAllRequests();
      final visible = all
          .where(
            (request) => _isVisibleToArtist(
              request: request,
              artistEmail: email,
              artistId: _currentArtistId,
            ),
          )
          .toList(growable: false);
      final stageSummary = _buildStageSummary(visible);
      final ascension = stageSummary.result.toAscensionMap();
      if (!mounted) return;
      setState(() {
        _stageSummary = stageSummary;
        _artistData = <String, dynamic>{
          ..._artistData,
          'ascension': ascension,
          'panel_ascensionLevel': ascension['tier'],
          'panel_ascensionPoints': ascension['points'],
        };
        _initialAscensionResolved = true;
      });
    } catch (_) {
      if (mounted && !_initialAscensionResolved) {
        setState(() => _initialAscensionResolved = true);
      }
    } finally {
      _syncingAscension = false;
    }
  }

  void _subscribeRequestRealtime() {
    _requestsChannel?.unsubscribe();
    _requestsChannel = Supabase.instance.client
        .channel('jnt_ascension_requests')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'client_custom_requests',
          callback: (_) {
            final email = _currentArtistEmail;
            if (email.isNotEmpty && _artistCollection.isNotEmpty) {
              unawaited(_syncAscension(email, _artistCollection));
            }
          },
        )
        .subscribe();
  }

  int _portfolioUploadCount(
    Map<String, dynamic> row,
    Map<String, dynamic> flattened,
  ) {
    int countList(Object? raw) => raw is List ? raw.length : 0;
    bool hasText(Object? raw) => (raw ?? _emptyValue).toString().trim().isNotEmpty;
    final profile =
        (row['profile'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final portfolio = row['portfolio'];
    final profilePortfolio = profile['portfolio'];
    final values = <Object?>[
      row['portfolioItems'],
      row['portfolioImages'],
      row['previousProjects'],
      row['samplePhotos'],
      flattened['portfolioItems'],
      flattened['portfolioImages'],
      profile['portfolioItems'],
      profile['portfolioImages'],
      profile['previousProjects'],
      profile['samplePhotos'],
      if (portfolio is Map) portfolio['items'],
      if (portfolio is Map) portfolio['images'],
      if (profilePortfolio is Map) profilePortfolio['items'],
      if (profilePortfolio is Map) profilePortfolio['images'],
    ];
    var best = 0;
    for (final value in values) {
      final count = countList(value);
      if (count > best) best = count;
    }

    final hasProfilePhoto = <Object?>[
      row['profileImageUrl'],
      row['profile_image_url'],
      row['avatarUrl'],
      row['avatar_url'],
      row['photoUrl'],
      row['photo_url'],
      row['imageUrl'],
      row['image_url'],
      row['artistProfileImage'],
      row['artist_profile_image'],
      flattened['profileImageUrl'],
      flattened['avatarUrl'],
      profile['profileImageUrl'],
      profile['profileImagePath'],
      profile['avatarUrl'],
      profile['photoUrl'],
      profile['imageUrl'],
    ].any(hasText);

    return best > 0 ? best : (hasProfilePhoto ? 1 : 0);
  }

  bool _isVisibleToArtist({
    required ClientRequestV2 request,
    required String artistEmail,
    required String artistId,
  }) {
    final ownedBy = request.acceptedByArtistEmail.trim().toLowerCase();
    final isOwnedByCurrentArtist =
        artistEmail.isNotEmpty && ownedBy == artistEmail;
    final declinedByCurrentArtist =
        artistEmail.isNotEmpty &&
        request.declinedByArtistEmails.contains(artistEmail);

    switch (request.status) {
      case RequestStatusV2.inReview:
        return !declinedByCurrentArtist && isOwnedByCurrentArtist;
      case RequestStatusV2.accepted:
      case RequestStatusV2.designing:
      case RequestStatusV2.completed:
      case RequestStatusV2.shipped:
      case RequestStatusV2.delivered:
      case RequestStatusV2.declined:
      case RequestStatusV2.cancelled:
      case RequestStatusV2.expired:
        return isOwnedByCurrentArtist;
    }
  }

  bool _isAscensionCompletedOrder(ClientRequestV2 request) {
    return request.status == RequestStatusV2.completed ||
        request.status == RequestStatusV2.shipped ||
        request.status == RequestStatusV2.delivered ||
        request.shippedAt != null ||
        request.deliveredAt != null ||
        request.artistImages.isNotEmpty;
  }

  double _amount(ClientRequestV2 request) {
    final acceptedAmount = request.artistFinalAmount;
    if (acceptedAmount != null && acceptedAmount > 0) {
      return acceptedAmount;
    }
    final artistMax = request.artistBudgetMax;
    if (artistMax != null && artistMax > 0) return artistMax.toDouble();
    final artistMin = request.artistBudgetMin;
    if (artistMin != null && artistMin > 0) return artistMin.toDouble();
    final fallback = request.budgetMax > 0 ? request.budgetMax : request.budgetMin;
    return fallback.toDouble();
  }

  DateTime _orderDate(ClientRequestV2 request) {
    return request.deliveredAt ?? request.shippedAt ?? request.neededBy;
  }

  bool _isOnTimeDelivery(ClientRequestV2 request) {
    final shippedAt = request.shippedAt;
    if (shippedAt == null) return false;
    final due = request.neededBy;
    final dueEndOfDay = DateTime(due.year, due.month, due.day, 23, 59, 59);
    return !shippedAt.isAfter(dueEndOfDay);
  }

  bool _isFiveStarReview(ClientRequestV2 request) {
    final rating = request.clientRating;
    if (rating == null) return false;
    return rating >= 5;
  }

  String _repeatClientKey(ClientRequestV2 request) {
    final email = request.clientEmail.trim().toLowerCase();
    if (email.isNotEmpty) return email;
    return request.clientName.trim().toLowerCase();
  }

  _AscensionStageSummary _buildStageSummary(List<ClientRequestV2> requests) {
    final completed = requests
        .where(_isAscensionCompletedOrder)
        .toList(growable: false);
    final completedSorted = List<ClientRequestV2>.from(completed)
      ..sort((a, b) => _orderDate(a).compareTo(_orderDate(b)));

    final seenClients = <String>{};
    final repeatIds = <String>{};
    for (final request in completedSorted) {
      final key = _repeatClientKey(request);
      if (key.isEmpty) continue;
      if (seenClients.contains(key)) {
        repeatIds.add(request.id);
      } else {
        seenClients.add(key);
      }
    }

    final onTime = completed.where(_isOnTimeDelivery).toList(growable: false);
    final fiveStar = completed.where(_isFiveStarReview).toList(growable: false);
    final repeat = completed
        .where((request) => repeatIds.contains(request.id))
        .toList(growable: false);
    final delivered = completed
        .where((request) => request.status == RequestStatusV2.delivered || request.deliveredAt != null)
        .toList(growable: false);
    final artistGmv = completed.fold<double>(0, (sum, r) => sum + _amount(r));

    final result = JntAscensionEngine.calculate(
      completedOrders: completed.length,
      onTimeDeliveries: onTime.length,
      fiveStarReviews: fiveStar.length,
      repeatClientOrders: repeat.length,
      portfolioUploads: _portfolioUploads,
      artistGmv: artistGmv,
    );

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final thisMonthPoints = <double>[
      for (final r in completed)
        if (!_orderDate(r).isBefore(monthStart))
          JntAscensionEngine.pointsCompleteOrder.toDouble(),
      for (final r in onTime)
        if (!r.shippedAt!.isBefore(monthStart))
          JntAscensionEngine.pointsOnTimeDelivery.toDouble(),
      for (final r in fiveStar)
        if (!(r.clientReviewSubmittedAt ?? _orderDate(r)).isBefore(monthStart))
          JntAscensionEngine.pointsFiveStarReview.toDouble(),
      for (final r in repeat)
        if (!_orderDate(r).isBefore(monthStart))
          JntAscensionEngine.pointsRepeatClientOrder.toDouble(),
    ].fold<double>(0, (sum, value) => sum + value);

    return _AscensionStageSummary(
      result: result,
      completedOrders: completed.length,
      onTimeDeliveries: onTime.length,
      fiveStarReviews: fiveStar.length,
      repeatClientOrders: repeat.length,
      portfolioUploads: _portfolioUploads,
      deliveredOrders: delivered.length,
      artistGmv: artistGmv,
      jntRevenue: result.jntRevenue,
      thisMonthPoints: thisMonthPoints,
    );
  }

  String _firstNonEmpty(List<Object?> values) {
    for (final v in values) {
      final s = (v ?? _emptyValue).toString().trim();
      if (s.isNotEmpty) return s;
    }
    return _emptyValue;
  }

  double _asDouble(Object? raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse((raw ?? _emptyValue).toString().trim()) ?? 0;
  }

  String _fmtPoints(num value) => value.toDouble().toStringAsFixed(2);

  String _fmtSignedPoints(num value) => '+${value.toDouble().toStringAsFixed(2)}';

  String _fmtTierThreshold(num value) => value.toDouble().toStringAsFixed(2);

  int _asInt(Object? raw) {
    return _asDouble(raw).round();
  }

  String get _artistName {
    final profile =
        (_artistData['profile'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final email = (Supabase.instance.client.auth.currentUser?.email ?? _emptyValue)
        .trim()
        .toLowerCase();
    final emailName = email.contains('@') ? email.split('@').first : email;
    return _firstNonEmpty([
      profile['displayName'],
      profile['studioName'],
      _artistData['panel_displayName'],
      _artistData['panel_studioName'],
      _artistData['displayName'],
      _artistData['name'],
      Supabase.instance.client.auth.currentUser?.userMetadata?['display_name'] as String?,
      emailName,
      'Artist',
    ]);
  }

  double get _currentPoints {
    final ascension =
        (_artistData['ascension'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final stats =
        (_artistData['stats'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    return _asDouble(
      ascension['points'] ??
          _artistData['panel_ascensionPoints'] ??
          _artistData['ascensionPoints'] ??
          ascension['totalPoints'] ??
          stats['points'],
    );
  }

  _AscLevel? _levelFromStoredTier() {
    final ascension =
        (_artistData['ascension'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final profile =
        (_artistData['profile'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final raw = _firstNonEmpty([
      _artistData['sponsorshipTier'],
      _artistData['panel_ascensionLevel'],
      profile['ascensionTier'],
      ascension['tier'],
      ascension['levelName'],
      ascension['label'],
    ]).toLowerCase();
    if (raw == 'crowned') return _AscLevel.crowned;
    if (raw == 'goldsmith') return _AscLevel.goldsmith;
    if (raw == 'maker') return _AscLevel.maker;
    return null;
  }

  _AscLevel get _currentLevel => _levelFromStoredTier() ?? _levelForPoints(_currentPoints);

  double get _effectivePointsForProgress {
    final points = _currentPoints;
    switch (_currentLevel) {
      case _AscLevel.crowned:
        return points < crownedMin ? crownedMin.toDouble() : points;
      case _AscLevel.goldsmith:
        return points < goldsmithMin ? goldsmithMin.toDouble() : points;
      case _AscLevel.maker:
        return points;
    }
  }

  int _readMetricInt(String key) {
    final ascension =
        (_artistData['ascension'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final metrics =
        (ascension['metrics'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    return _asInt(metrics[key]);
  }

  bool _readMetricBool(String key) {
    final ascension =
        (_artistData['ascension'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final metrics =
        (ascension['metrics'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final raw = metrics[key];
    if (raw is bool) return raw;
    final text = (raw ?? _emptyValue).toString().trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'yes';
  }

  double _readMetricNum(String key) {
    final ascension =
        (_artistData['ascension'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final metrics =
        (ascension['metrics'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final raw = metrics[key];
    if (raw is num) return raw.toDouble();
    return double.tryParse((raw ?? _emptyValue).toString().trim()) ?? 0;
  }

  double get artistGmv {
    final stored = _readMetricNum('artistGmv');
    return stored > 0 ? stored : _stageSummary.artistGmv;
  }

  double get jntRevenue {
    final stored = _readMetricNum('jntRevenue');
    return stored > 0 ? stored : _stageSummary.jntRevenue;
  }

  double get artistEarnings {
    final stored = _readMetricNum('artistEarnings');
    if (stored > 0) return stored;
    final derived = artistGmv - jntRevenue;
    return derived > 0 ? derived : 0;
  }

  bool get isGoldsmith => _currentLevel == _AscLevel.goldsmith;

  bool get crownedPointsQualified => _readMetricBool('crownedPointsQualified');

  bool get crownedRevenueQualified => _readMetricBool('crownedRevenueQualified');

  double get jntRevenueToCrowned => _readMetricNum('jntRevenueToCrowned');

  _AscLevel _levelForPoints(double pts) {
    final jntRevenue = _readMetricNum('jntRevenue');
    if (pts >= crownedMin &&
        jntRevenue >= JntAscensionEngine.crownedMinJntRevenue) {
      return _AscLevel.crowned;
    }
    if (pts >= goldsmithMin) return _AscLevel.goldsmith;
    return _AscLevel.maker;
  }

  double get _nextTierTarget {
    final points = _effectivePointsForProgress;
    if (points < goldsmithMin) return goldsmithMin.toDouble();
    if (points < crownedMin) return crownedMin.toDouble();
    return crownedMin.toDouble();
  }

  _AscLevel get _nextTierLevel {
    final points = _effectivePointsForProgress;
    if (points < goldsmithMin) return _AscLevel.goldsmith;
    if (points < crownedMin) return _AscLevel.crowned;
    return _AscLevel.crowned;
  }

  double get _pointsToNextTier {
    final remaining = _nextTierTarget - _effectivePointsForProgress;
    return remaining < 0 ? 0 : remaining;
  }

  double get _progressAcrossTiers {
    return (_effectivePointsForProgress / crownedMin).clamp(0, 1).toDouble();
  }

  List<_PointActivityItem> get _activityItems {
    final completedOrders = _readMetricInt('completedOrders');
    final fiveStarReviews = _readMetricInt('fiveStarReviews');
    final onTimeDeliveries = _readMetricInt('onTimeDeliveries');
    final repeatClientOrders = _readMetricInt('repeatClientOrders');
    final portfolioUploads = _readMetricInt('portfolioUploads');
    final items = <_PointActivityItem>[
      _PointActivityItem(
        title: 'Completed orders',
        subtitle: '$completedOrders order(s) × 25 pts',
        points: completedOrders * JntAscensionEngine.pointsCompleteOrder,
      ),
      _PointActivityItem(
        title: '5-star client reviews',
        subtitle: '$fiveStarReviews review(s) × 9 pts',
        points: fiveStarReviews * JntAscensionEngine.pointsFiveStarReview,
      ),
      _PointActivityItem(
        title: 'On-time delivery',
        subtitle: '$onTimeDeliveries shipment(s) × 8.5 pts',
        points: onTimeDeliveries * JntAscensionEngine.pointsOnTimeDelivery,
      ),
      _PointActivityItem(
        title: 'Repeat client order',
        subtitle: '$repeatClientOrders repeat order(s) × 6 pts',
        points: repeatClientOrders * JntAscensionEngine.pointsRepeatClientOrder,
      ),
      _PointActivityItem(
        title: 'Portfolio upload',
        subtitle: '$portfolioUploads upload(s) × 0.3 pts',
        points: portfolioUploads * JntAscensionEngine.pointsPortfolioUpload,
      ),
    ];
    return items;
  }

  @override
  Widget build(BuildContext context) {
    if (!_artistLoaded || !_hasServerSnapshot || !_initialAscensionResolved) {
      return Scaffold(
        backgroundColor: AppColors.snow,
        appBar: JntModalAppBar(
          onClose: () => Navigator.of(context).pop(),
          closeTooltip: 'Close JNT Ascension',
          title: const Text(
            'JNT Ascension',
            style: TextStyle(
              color: AppColors.blackCat,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ),
        body: const Center(
          child: SizedBox(
            height: 28,
            width: 28,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ),
      );
    }

    final level = _currentLevel;
    final nextLevel = _nextTierLevel;

    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: JntModalAppBar(
        onClose: () => Navigator.of(context).pop(),
        closeTooltip: 'Close JNT Ascension',
        title: const Text(
          'JNT Ascension',
          style: TextStyle(
            color: AppColors.blackCat,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _headerCard(level: level, nextLevel: nextLevel),
              const SizedBox(height: 14),
              _tabs(),
              const SizedBox(height: 14),
              if (_activeTab == _AscTab.activity) _activityTab(),
              if (_activeTab == _AscTab.tiers) _tiersTab(level),
              if (_activeTab == _AscTab.earnPoints) _earnPointsTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerCard({required _AscLevel level, required _AscLevel nextLevel}) {
    final initial = _artistName.trim().isEmpty
        ? 'A'
        : _artistName.trim().substring(0, 1).toUpperCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A1A), Color(0xFF3A2A1E)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 60,
                width: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.balletSlippers,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                    color: Color(0xFF1F160E),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${level.label}  ·  ${_fmtPoints(_currentPoints)} pts',
                      style: const TextStyle(
                        color: Color(0xFFE2BE83),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Text(
                'Maker',
                style: TextStyle(
                  color: Color(0xFFE2BE83),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Spacer(),
              Text(
                'Goldsmith',
                style: TextStyle(
                  color: Color(0xFF90939A),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Spacer(),
              Text(
                'Crowned',
                style: TextStyle(
                  color: Color(0xFF90939A),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: _progressAcrossTiers,
                  backgroundColor: const Color(0xFF5C5954),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFFE2BE83),
                  ),
                ),
              ),
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final knobX = constraints.maxWidth * _progressAcrossTiers;
                    return Stack(
                      children: [
                        Positioned(
                          left: (constraints.maxWidth * (goldsmithMin / crownedMin)) - 1,
                          top: 0,
                          bottom: 0,
                          child: Container(width: 2, color: const Color(0xAA2F2F2F)),
                        ),
                        Positioned(
                          left: (knobX - 7).clamp(0, constraints.maxWidth - 14),
                          top: -4,
                          child: Container(
                            height: 14,
                            width: 14,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2BE83),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.black,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (level == _AscLevel.crowned)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x22E2BE83),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x66E2BE83)),
                ),
                child: const Column(
                  children: [
                    Text(
                      'Crowned Status Achieved',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Insurance reimbursement unlocked',
                      style: TextStyle(
                        color: Color(0xFFE2BE83),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Center(
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: _fmtPoints(_pointsToNextTier),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 30,
                      ),
                    ),
                    TextSpan(
                      text: ' points to ${nextLevel.label}',
                      style: const TextStyle(
                        color: Color(0xFFC4A87A),
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

        ],
      ),
    );
  }

  Widget _tabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.alabaster,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _tabButton(_AscTab.activity, 'Activity'),
          _tabButton(_AscTab.tiers, 'Tiers'),
          _tabButton(_AscTab.earnPoints, 'Earn Points'),
        ],
      ),
    );
  }

  Widget _tabButton(_AscTab tab, String label) {
    final selected = _activeTab == tab;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeTab = tab),
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected ? AppColors.blackCat : AppColors.blackCatLight,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _activityTab() {
    final orders = _readMetricInt('completedOrders');
    final deliveredOrders = _stageSummary.deliveredOrders;
    final currentTier = _currentLevel.label;


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Recent Points',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Text(
              'This month: ${_fmtSignedPoints(_stageSummary.thisMonthPoints)} pts',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF8A8F98),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final item in _activityItems) _activityRow(item),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0EAE0),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFD9C9B4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.insights_outlined, color: Color(0xFF7C838E)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "At your current pace, you'll reach ${_nextTierLevel.label} in about ${(_pointsToNextTier / JntAscensionEngine.blendedAveragePointsPerOrder).ceil().clamp(0, 9999)} completed orders.",
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF3A3025),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE4E4E4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Completed orders: $orders',
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: Color(0xFF4E545E),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Delivered orders: $deliveredOrders',
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: Color(0xFF4E545E),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Artist GMV: \$${artistGmv.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: Color(0xFF4E545E),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Artist earnings: \$${artistEarnings.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: Color(0xFF4E545E),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'JNT revenue: \$${jntRevenue.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: Color(0xFF4E545E),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Current tier: $currentTier',
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: Color(0xFF4E545E),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Points to next tier: ${_fmtPoints(_pointsToNextTier)}',
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: Color(0xFF4E545E),
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (isGoldsmith &&
                  crownedPointsQualified &&
                  !crownedRevenueQualified) ...[
                const SizedBox(height: 6),
                Text(
                  '\$${jntRevenueToCrowned.toStringAsFixed(0)} JNT revenue remaining to unlock Crowned benefits.',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: Color(0xFF3A3025),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _activityRow(_PointActivityItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            height: 8,
            width: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFCFAE78),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8A8F98),
                  ),
                ),
              ],
            ),
          ),
          Text(
            _fmtSignedPoints(item.points),
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF14823A),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tiersTab(_AscLevel currentLevel) {
    return Column(
      children: [
        _tierCard(
          _AscLevel.maker,
          '${_fmtTierThreshold(0)}-${_fmtTierThreshold(999)} pts',
          currentLevel == _AscLevel.maker,
        ),
        const SizedBox(height: 10),
        _tierCard(
          _AscLevel.goldsmith,
          '${_fmtTierThreshold(1000)}-${_fmtTierThreshold(9749)} pts',
          currentLevel == _AscLevel.goldsmith,
        ),
        const SizedBox(height: 10),
        _tierCard(
          _AscLevel.crowned,
          '${_fmtTierThreshold(9750)}+ pts',
          currentLevel == _AscLevel.crowned,
        ),
      ],
    );
  }

  Widget _tierCard(_AscLevel level, String range, bool isCurrent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent ? const Color(0xFFCDAF78) : const Color(0xFFE3E3E3),
          width: isCurrent ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F1EA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(level.icon, style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  level.label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isCurrent ? Colors.black : const Color(0xFF8B8B8B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  range,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8A8F98),
                  ),
                ),
              ],
            ),
          ),
          if (isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF0E6D7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'CURRENT',
                style: TextStyle(
                  color: Color(0xFFC69445),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _earnPointsTab() {
    const earnItems = <_EarnRuleItem>[
      _EarnRuleItem('Complete an order', '+25 pts', Icons.check),
      _EarnRuleItem('On-time delivery', '+10 pts', Icons.timer_outlined),
      _EarnRuleItem('5-star client review', '+15 pts', Icons.star),
      _EarnRuleItem('Repeat client order', '+20 pts', Icons.refresh),
      _EarnRuleItem(
        'Portfolio upload',
        '+5 pts',
        Icons.arrow_upward_rounded,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How to earn',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          'Points are awarded in stages as orders move through completion, shipping, delivery, review, and repeat-client activity.',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF6F7580),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 10) / 2;
            final compact = cardWidth < 170;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: earnItems.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: compact ? 1.24 : 1.42,
              ),
              itemBuilder: (_, i) {
                final item = earnItems[i];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE3E3E3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 34,
                        width: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(item.icon, size: 18),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 14 : 15,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        item.points,
                        style: TextStyle(
                          fontSize: compact ? 19 : 22,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0D7E38),
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}


class _AscensionStageSummary {
  const _AscensionStageSummary({
    required this.result,
    required this.completedOrders,
    required this.onTimeDeliveries,
    required this.fiveStarReviews,
    required this.repeatClientOrders,
    required this.portfolioUploads,
    required this.deliveredOrders,
    required this.artistGmv,
    required this.jntRevenue,
    required this.thisMonthPoints,
  });

  const _AscensionStageSummary.empty()
      : result = const JntAscensionResult(
          tier: 'maker',
          tierLabel: 'Maker',
          points: 0,
          completedOrders: 0,
          onTimeDeliveries: 0,
          fiveStarReviews: 0,
          repeatClientOrders: 0,
          portfolioUploads: 0,
          artistGmv: 0,
          jntRevenue: 0,
          completedOrderPoints: 0,
          onTimeDeliveryPoints: 0,
          fiveStarReviewPoints: 0,
          repeatClientOrderPoints: 0,
          portfolioUploadPoints: 0,
          crownedPointsQualified: false,
          crownedRevenueQualified: false,
          jntRevenueToCrowned: 5000,
          prioritySearch: false,
          sponsorshipEligible: false,
          insuranceEligible: false,
          pointsToNextTier: 1000,
          nextTier: 'goldsmith',
          nextTierLabel: 'Goldsmith',
          generatedTags: <String>['Maker'],
          unlockedPerks: <String>[
            'Welcome gift',
            'Group orders',
            'Learning & development',
          ],
          crownedPointsOnlyMessage: '',
        ),
        completedOrders = 0,
        onTimeDeliveries = 0,
        fiveStarReviews = 0,
        repeatClientOrders = 0,
        portfolioUploads = 0,
        deliveredOrders = 0,
        artistGmv = 0,
        jntRevenue = 0,
        thisMonthPoints = 0;

  final JntAscensionResult result;
  final int completedOrders;
  final int onTimeDeliveries;
  final int fiveStarReviews;
  final int repeatClientOrders;
  final int portfolioUploads;
  final int deliveredOrders;
  final double artistGmv;
  final double jntRevenue;
  final double thisMonthPoints;
}

enum _AscTab { activity, tiers, earnPoints }

enum _AscLevel {
  maker('Maker', '✦'),
  goldsmith('Goldsmith', '◆'),
  crowned('Crowned', '♕');

  const _AscLevel(this.label, this.icon);
  final String label;
  final String icon;
}

class _PointActivityItem {
  const _PointActivityItem({
    required this.title,
    required this.subtitle,
    required this.points,
  });

  final String title;
  final String subtitle;
  final double points;
}

class _EarnRuleItem {
  const _EarnRuleItem(this.title, this.points, this.icon);

  final String title;
  final String points;
  final IconData icon;
}
