import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/ascension_service.dart';
import '../theme/app_colors.dart';

class JntAscensionPage extends StatefulWidget {
  const JntAscensionPage({super.key});

  @override
  State<JntAscensionPage> createState() => _JntAscensionPageState();
}

class _JntAscensionPageState extends State<JntAscensionPage> {
  static const int goldsmithMin = 1000;
  static const int crownedMin = 9750;

  RealtimeChannel? _artistChannel;
  String _artistCollection = '';
  Map<String, dynamic> _artistData = const <String, dynamic>{};
  _AscTab _activeTab = _AscTab.activity;
  bool _syncingAscension = false;
  bool _artistLoaded = false;
  bool _initialAscensionResolved = false;
  bool _hasServerSnapshot = false;

  @override
  void initState() {
    super.initState();
    _bindArtist();
  }

  @override
  void dispose() {
    _artistChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _bindArtist() async {
    final supabase = Supabase.instance.client;
    final email = (supabase.auth.currentUser?.email ?? '').trim().toLowerCase();
    if (email.isEmpty) return;

    for (final collection in const <String>['artist', 'client_artist']) {
      try {
        final row = await supabase
            .from(collection)
            .select()
            .eq('email', email)
            .maybeSingle();
        if (row != null) {
          _artistCollection = collection;
          if (mounted) {
            setState(() {
              _artistData = _flattenArtistRow(row);
              _artistLoaded = true;
              _hasServerSnapshot = true;
            });
          }
          unawaited(_syncAscension(email, collection));
          _subscribeArtistRealtime(email, collection);
          break;
        }
      } catch (_) {}
    }
  }

  void _subscribeArtistRealtime(String email, String collection) {
    _artistChannel?.unsubscribe();
    _artistChannel = Supabase.instance.client
        .channel('jnt_ascension_artist_$collection')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: collection,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'email',
            value: email,
          ),
          callback: (payload) {
            if (!mounted) return;
            setState(() {
              _artistData = _flattenArtistRow(
                Map<String, dynamic>.from(payload.newRecord),
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
      final portfolioItems =
          (_artistData['portfolioItems'] as List<dynamic>?)?.length ??
          (_artistData['portfolioImages'] as List<dynamic>?)?.length ??
          0;
      final ascension =
          (_artistData['ascension'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final previousPointsRaw = ascension['points'];
      final previousPoints = previousPointsRaw is num
          ? previousPointsRaw.toInt()
          : int.tryParse((previousPointsRaw ?? '').toString()) ?? 0;
      final snapshot = await AscensionService.calculateForArtist(
        artistEmail: email,
        portfolioUploads: portfolioItems,
      );
      final computedPayload = AscensionService.buildAscensionPayload(snapshot);
      final override = await AscensionService.readActiveOverride(
        artistDocPath: email,
        artistEmail: email,
      );
      final finalPayload = AscensionService.applyOverrideToPayload(
        payload: computedPayload,
        override: override,
      );
      final stabilizedPayload = AscensionService.preserveExistingAdminOverride(
        payload: finalPayload,
        artistData: _artistData,
      );
      await AscensionService.persistAdminCollections(
        artistEmail: email,
        artistCollection: collection,
        artistName: _artistName,
        ascensionPayload: stabilizedPayload,
        previousPoints: previousPoints,
      );
    } catch (_) {
    } finally {
      _syncingAscension = false;
      if (mounted && !_initialAscensionResolved) {
        setState(() => _initialAscensionResolved = true);
      }
    }
  }

  String _firstNonEmpty(List<Object?> values) {
    for (final v in values) {
      final s = (v ?? '').toString().trim();
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  int _asInt(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.round();
    return int.tryParse((raw ?? '').toString().trim()) ?? 0;
  }

  String get _artistName {
    final profile =
        (_artistData['profile'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final email = (Supabase.instance.client.auth.currentUser?.email ?? '')
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

  int get _currentPoints {
    final ascension =
        (_artistData['ascension'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final stats =
        (_artistData['stats'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    return _asInt(
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

  int get _effectivePointsForProgress {
    final points = _currentPoints;
    switch (_currentLevel) {
      case _AscLevel.crowned:
        return points < crownedMin ? crownedMin : points;
      case _AscLevel.goldsmith:
        return points < goldsmithMin ? goldsmithMin : points;
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
    final text = (raw ?? '').toString().trim().toLowerCase();
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
    return double.tryParse((raw ?? '').toString().trim()) ?? 0;
  }

  _AscLevel _levelForPoints(int pts) {
    if (pts >= crownedMin) return _AscLevel.crowned;
    if (pts >= goldsmithMin) return _AscLevel.goldsmith;
    return _AscLevel.maker;
  }

  int get _nextTierTarget {
    final points = _effectivePointsForProgress;
    if (points < goldsmithMin) return goldsmithMin;
    if (points < crownedMin) return crownedMin;
    return crownedMin;
  }

  _AscLevel get _nextTierLevel {
    final points = _effectivePointsForProgress;
    if (points < goldsmithMin) return _AscLevel.goldsmith;
    if (points < crownedMin) return _AscLevel.crowned;
    return _AscLevel.crowned;
  }

  int get _pointsToNextTier {
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
        subtitle: 'Recent progress',
        points:
            completedOrders * AscensionService.weightedPointsCompleteOrder,
      ),
      _PointActivityItem(
        title: '5-star client reviews',
        subtitle: 'Recent progress',
        points:
            fiveStarReviews * AscensionService.weightedPointsFiveStarReview,
      ),
      _PointActivityItem(
        title: 'On-time delivery',
        subtitle: 'Delivery consistency',
        points:
            onTimeDeliveries * AscensionService.weightedPointsOnTimeDelivery,
      ),
      _PointActivityItem(
        title: 'Repeat client order',
        subtitle: 'Returning clients',
        points:
            repeatClientOrders *
            AscensionService.weightedPointsRepeatClientOrder,
      ),
      _PointActivityItem(
        title: 'Portfolio upload',
        subtitle: 'Design showcase',
        points:
            portfolioUploads * AscensionService.weightedPointsPortfolioUpload,
      ),
    ];
    return items;
  }

  @override
  Widget build(BuildContext context) {
    if (!_artistLoaded || !_hasServerSnapshot || !_initialAscensionResolved) {
      return Scaffold(
        backgroundColor: AppColors.snow,
        appBar: AppBar(
          backgroundColor: AppColors.alabaster,
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: false,
          title: const Text(
            'JNT Ascension',
            style: TextStyle(
              color: AppColors.blackCat,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          actions: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded, color: AppColors.blackCat),
            ),
          ],
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
      appBar: AppBar(
        backgroundColor: AppColors.alabaster,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          'JNT Ascension',
          style: TextStyle(
            color: AppColors.blackCat,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: AppColors.blackCat),
          ),
        ],
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
    final crownedPointsQualified = _readMetricBool('crownedPointsQualified');
    final crownedRevenueQualified = _readMetricBool('crownedRevenueQualified');
    final jntRevenueToCrowned = _readMetricNum('jntRevenueToCrowned');

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
                      '${level.label}  ·  $_currentPoints pts',
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
                      text: '$_pointsToNextTier',
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
          if (crownedPointsQualified && !crownedRevenueQualified) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Points qualified — \$${jntRevenueToCrowned.toStringAsFixed(0)} JNT revenue needed for Crowned.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFE2BE83),
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
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
    final artistGmv = orders * AscensionService.aov;
    final artistEarnings = orders * AscensionService.artistEarningsPerOrder;
    final jntRevenue = orders * AscensionService.jntRevPerOrder;
    final currentTier = _currentLevel.label;
    final isGoldsmith = currentTier.toLowerCase() == 'goldsmith';
    final crownedPointsQualified = _effectivePointsForProgress >= crownedMin;
    final crownedRevenueQualified =
        jntRevenue >= AscensionService.crownedRevenueMin;
    final jntRevenueToCrowned = (AscensionService.crownedRevenueMin - jntRevenue)
        .clamp(0, AscensionService.crownedRevenueMin);

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
              'This month: +${_activityItems.fold<double>(0, (s, e) => s + e.points).toStringAsFixed(1)} pts',
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
                  "At your current pace, you'll reach ${_nextTierLevel.label} in about ${(_pointsToNextTier / AscensionService.blendedAveragePointsPerOrder).ceil()} completed orders.",
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
                'Points to next tier: $_pointsToNextTier',
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
            '+${item.points.toStringAsFixed(1)}',
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
          '0-999 pts',
          currentLevel == _AscLevel.maker,
        ),
        const SizedBox(height: 10),
        _tierCard(
          _AscLevel.goldsmith,
          '1000-9749 pts',
          currentLevel == _AscLevel.goldsmith,
        ),
        const SizedBox(height: 10),
        _tierCard(
          _AscLevel.crowned,
          '9750+ pts + \$5,000 JNT revenue',
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
      _EarnRuleItem('On-time delivery', '+8.5 pts', Icons.timer_outlined),
      _EarnRuleItem('5-star client review', '+9 pts', Icons.star),
      _EarnRuleItem('Repeat client order', '+6 pts', Icons.refresh),
      _EarnRuleItem(
        'Portfolio upload',
        '+0.3 pts',
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
          'Points are frequency-weighted based on expected artist activity.',
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
