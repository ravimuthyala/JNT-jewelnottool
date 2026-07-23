import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/client_request_v2.dart';
import '../services/artist_requests_repository.dart';
import '../theme/app_colors.dart';
import '../utils/date_format_utils.dart';
import '../utils/jnt_ascension_engine.dart';
import '../widgets/artist_profile_avatar_icon.dart';
import '../widgets/jnt_standard_app_bar.dart';
import 'jnt_ascension_page.dart';
import 'artist_reviews_page.dart';
import 'notifications_page.dart';

class ArtistEarningsPage extends StatefulWidget {
  const ArtistEarningsPage({
    super.key,
    this.onOpenNotifications,
    this.onOpenInbox,
    this.onSignOut,
    this.onManageProfile,
    this.onOpenHistory,
    this.onOpenCalendar,
    this.onOpenArtist,
    this.onOpenReviews,
    this.clientArtistMenuStyle = false,
    this.showBottomNav = false,
    this.showCampaignsTab = false,
    this.bottomNavCurrentIndex = 0,
    this.onBottomNavTap,
  });

  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenInbox;
  final VoidCallback? onSignOut;
  final VoidCallback? onManageProfile;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenArtist;
  final VoidCallback? onOpenReviews;
  final bool clientArtistMenuStyle;
  final bool showBottomNav;
  final bool showCampaignsTab;
  final int bottomNavCurrentIndex;
  final ValueChanged<int>? onBottomNavTap;

  @override
  State<ArtistEarningsPage> createState() => _ArtistEarningsPageState();
}

class _ArtistEarningsPageState extends State<ArtistEarningsPage> {
  bool _isLoading = true;
  _EarningsRange _range = _EarningsRange.allTime;
  final List<ClientRequestV2> _allVisible = <ClientRequestV2>[];

  RealtimeChannel? _requestsChannel;
  int _portfolioUploads = 0;
  _AscensionStageSummary _stageSummary = const _AscensionStageSummary.empty();
  Map<String, dynamic> _ascensionData = const <String, dynamic>{
    'tier': 'maker',
    'points': 0,
    'pointsToNextTier': 1000,
    'nextTierLabel': 'Goldsmith',
  };

  @override
  void initState() {
    super.initState();
    _bindRealtimeChannel();
    _loadAscensionFromSupabase();
    _reload();
  }

  @override
  void dispose() {
    _requestsChannel?.unsubscribe();
    super.dispose();
  }

  void _bindRealtimeChannel() {
    _requestsChannel?.unsubscribe();
    _requestsChannel = Supabase.instance.client
        .channel('artist_earnings_requests')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'client_custom_requests',
          callback: (_) => _reload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'company_custom_requests',
          callback: (_) => _reload(),
        )
        .subscribe((status, [error]) {
          if (error != null) {
            debugPrint('Artist earnings realtime error: $error');
          }
        });
  }

  Future<Map<String, dynamic>?> _loadCurrentArtistRow() async {
    final supabase = Supabase.instance.client;
    final uid = (supabase.auth.currentUser?.id ?? '').trim();
    final email = (supabase.auth.currentUser?.email ?? '').trim().toLowerCase();

    for (final table in const ['client_artist', 'artist']) {
      try {
        if (uid.isNotEmpty) {
          final row = await supabase
              .from(table)
              .select()
              .eq('id', uid)
              .maybeSingle();
          if (row != null) return Map<String, dynamic>.from(row);
        }
      } catch (_) {}
    }
    for (final table in const ['client_artist', 'artist']) {
      try {
        if (email.isNotEmpty) {
          final row = await supabase
              .from(table)
              .select()
              .eq('email', email)
              .maybeSingle();
          if (row != null) return Map<String, dynamic>.from(row);
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> _loadAscensionFromSupabase() async {
    try {
      final row = await _loadCurrentArtistRow();
      if (row == null || !mounted) return;
      final profile = (row['profile'] as Map<String, dynamic>?) ?? {};
      final portfolioUploads = _portfolioUploadCount(row, profile);
      if (!mounted) return;
      setState(() {
        _portfolioUploads = portfolioUploads;
        if (_allVisible.isEmpty) {
          _ascensionData = _ascensionSummaryFromProfile(profile);
          _stageSummary = const _AscensionStageSummary.empty();
        } else {
          _stageSummary = _buildStageSummary(_allVisible);
          _ascensionData = _stageSummary.result.toAscensionMap();
        }
      });
    } catch (_) {
      // keep defaults
    }
  }

  Future<void> _reload() async {
    try {
      final currentArtistEmail =
          (Supabase.instance.client.auth.currentUser?.email ?? '')
              .trim()
              .toLowerCase();
      final currentArtistId =
          (Supabase.instance.client.auth.currentUser?.id ?? '').trim();
      final all = await ArtistRequestsRepository.fetchAllRequests();
      if (!mounted) return;

      final visible = all
          .where(
            (r) => _isVisibleToArtist(
              request: r,
              artistEmail: currentArtistEmail,
              artistId: currentArtistId,
            ),
          )
          .toList(growable: false);

      setState(() {
        _allVisible
          ..clear()
          ..addAll(visible);
        _stageSummary = _buildStageSummary(visible);
        _ascensionData = _stageSummary.result.toAscensionMap();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
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

  bool _isPaid(ClientRequestV2 r) {
    final status = r.paymentStatus.trim().toLowerCase();
    return status == 'paid' || status == 'completed';
  }

  double _amount(ClientRequestV2 r) {
    final acceptedAmount = r.artistFinalAmount;
    if (acceptedAmount != null && acceptedAmount > 0) {
      return acceptedAmount;
    }
    final artistMax = r.artistBudgetMax;
    if (artistMax != null && artistMax > 0) return artistMax.toDouble();
    final artistMin = r.artistBudgetMin;
    if (artistMin != null && artistMin > 0) return artistMin.toDouble();
    final min = r.budgetMin;
    final max = r.budgetMax;
    final value = max > 0 ? max : min;
    return value.toDouble();
  }

  DateTime _earningDate(ClientRequestV2 r) {
    return r.deliveredAt ?? r.shippedAt ?? r.neededBy;
  }

  DateTime? _rangeStart(DateTime now) {
    switch (_range) {
      case _EarningsRange.last30Days:
        return now.subtract(const Duration(days: 30));
      case _EarningsRange.last90Days:
        return now.subtract(const Duration(days: 90));
      case _EarningsRange.last365Days:
        return now.subtract(const Duration(days: 365));
      case _EarningsRange.allTime:
        return null;
    }
  }

  List<ClientRequestV2> get _inRange {
    final now = DateTime.now();
    final start = _rangeStart(now);
    if (start == null) return List<ClientRequestV2>.from(_allVisible);
    return _allVisible.where((r) => !_earningDate(r).isBefore(start)).toList();
  }

  _EarningsSummary get _summary {
    final inRange = _inRange;
    final paid = inRange.where(_isPaid).toList(growable: false);

    final totalPaid = paid.fold<double>(0, (sum, r) => sum + _amount(r));
    final currentMonthStart = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      1,
    );
    final monthPaid = paid
        .where((r) => !_earningDate(r).isBefore(currentMonthStart))
        .fold<double>(0, (sum, r) => sum + _amount(r));

    final pendingPayment = inRange
        .where((r) => !_isPaid(r))
        .where(
          (r) =>
              r.status == RequestStatusV2.accepted ||
              r.status == RequestStatusV2.designing ||
              r.status == RequestStatusV2.completed ||
              r.status == RequestStatusV2.shipped ||
              r.status == RequestStatusV2.delivered,
        )
        .fold<double>(0, (sum, r) => sum + _amount(r));

    final deliveredPaid = inRange
        .where(
          (r) => r.status == RequestStatusV2.delivered || r.deliveredAt != null,
        )
        .length;
    final avg = paid.isEmpty ? 0.0 : totalPaid / paid.length;

    final paidSorted = List<ClientRequestV2>.from(paid)
      ..sort((a, b) => _earningDate(b).compareTo(_earningDate(a)));

    return _EarningsSummary(
      totalEarnings: totalPaid,
      monthEarnings: monthPaid,
      paidOrders: paid.length,
      pendingAmount: pendingPayment,
      averageOrder: avg,
      deliveredPaidOrders: deliveredPaid,
      paidAmountInRange: totalPaid,
      unpaidAmountInRange: pendingPayment,
      recentPaidOrders: paidSorted.take(8).toList(growable: false),
      rangeLabel: _formatDateRange(inRange),
    );
  }

  String _formatDateRange(List<ClientRequestV2> items) {
    if (items.isEmpty) return 'No data';
    final sorted = List<ClientRequestV2>.from(items)
      ..sort((a, b) => _earningDate(a).compareTo(_earningDate(b)));
    final first = _earningDate(sorted.first);
    final last = _earningDate(sorted.last);
    return '${_formatDate(first)} - ${_formatDate(last)}';
  }

  String _formatDate(DateTime d) => formatDateMdy(d);

  String _formatShortDate(DateTime d) => formatDateMdy(d);

  String _money(double v) => '\$${v.toStringAsFixed(2)}';

  int _portfolioUploadCount(
    Map<String, dynamic> row,
    Map<String, dynamic> profile,
  ) {
    int countList(Object? raw) => raw is List ? raw.length : 0;
    bool hasText(Object? raw) => (raw ?? '').toString().trim().isNotEmpty;

    final portfolio = row['portfolio'];
    final profilePortfolio = profile['portfolio'];
    final values = <Object?>[
      row['portfolioItems'],
      row['portfolioImages'],
      row['previousProjects'],
      row['samplePhotos'],
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
      profile['profileImageUrl'],
      profile['profileImagePath'],
      profile['avatarUrl'],
      profile['photoUrl'],
      profile['imageUrl'],
    ].any(hasText);

    return best > 0 ? best : (hasProfilePhoto ? 1 : 0);
  }

  bool _isAscensionCompletedOrder(ClientRequestV2 r) {
    return r.status == RequestStatusV2.completed ||
        r.status == RequestStatusV2.shipped ||
        r.status == RequestStatusV2.delivered ||
        r.shippedAt != null ||
        r.deliveredAt != null ||
        r.artistImages.isNotEmpty;
  }

  DateTime _ascensionOrderDate(ClientRequestV2 r) {
    return r.deliveredAt ?? r.shippedAt ?? r.neededBy;
  }

  bool _isOnTimeDelivery(ClientRequestV2 r) {
    final shippedAt = r.shippedAt;
    if (shippedAt == null) return false;
    final due = r.neededBy;
    final dueEndOfDay = DateTime(due.year, due.month, due.day, 23, 59, 59);
    return !shippedAt.isAfter(dueEndOfDay);
  }

  bool _isFiveStarReview(ClientRequestV2 r) {
    final rating = r.clientRating;
    if (rating == null) return false;
    return rating >= 5;
  }

  String _repeatClientKey(ClientRequestV2 r) {
    final email = r.clientEmail.trim().toLowerCase();
    if (email.isNotEmpty) return email;
    return r.clientName.trim().toLowerCase();
  }

  _AscensionStageSummary _buildStageSummary(List<ClientRequestV2> requests) {
    final completed = requests
        .where(_isAscensionCompletedOrder)
        .toList(growable: false);
    final completedSorted = List<ClientRequestV2>.from(
      completed,
    )..sort((a, b) => _ascensionOrderDate(a).compareTo(_ascensionOrderDate(b)));

    final seenClients = <String>{};
    final repeatClientRequestIds = <String>{};
    for (final request in completedSorted) {
      final key = _repeatClientKey(request);
      if (key.isEmpty) continue;
      if (seenClients.contains(key)) {
        repeatClientRequestIds.add(request.id);
      } else {
        seenClients.add(key);
      }
    }

    final onTime = completed.where(_isOnTimeDelivery).toList(growable: false);
    final fiveStar = completed.where(_isFiveStarReview).toList(growable: false);
    final repeat = completed
        .where((request) => repeatClientRequestIds.contains(request.id))
        .toList(growable: false);
    final delivered = completed
        .where(
          (request) =>
              request.status == RequestStatusV2.delivered ||
              request.deliveredAt != null,
        )
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
        if (!_ascensionOrderDate(r).isBefore(monthStart))
          JntAscensionEngine.pointsCompleteOrder.toDouble(),
      for (final r in onTime)
        if (!r.shippedAt!.isBefore(monthStart))
          JntAscensionEngine.pointsOnTimeDelivery.toDouble(),
      for (final r in fiveStar)
        if (!(r.clientReviewSubmittedAt ?? _ascensionOrderDate(r)).isBefore(
          monthStart,
        ))
          JntAscensionEngine.pointsFiveStarReview.toDouble(),
      for (final r in repeat)
        if (!_ascensionOrderDate(r).isBefore(monthStart))
          JntAscensionEngine.pointsRepeatClientOrder.toDouble(),
    ].fold<double>(0, (sum, value) => sum + value);

    return _AscensionStageSummary(
      result: result,
      completedOrders: completed.length,
      completedOrderPoints: result.completedOrderPoints,
      onTimeDeliveries: onTime.length,
      onTimeDeliveryPoints: result.onTimeDeliveryPoints,
      fiveStarReviews: fiveStar.length,
      fiveStarReviewPoints: result.fiveStarReviewPoints,
      repeatClientOrders: repeat.length,
      repeatClientOrderPoints: result.repeatClientOrderPoints,
      portfolioUploads: _portfolioUploads,
      portfolioUploadPoints: result.portfolioUploadPoints,
      deliveredOrders: delivered.length,
      artistGmv: artistGmv,
      jntRevenue: result.jntRevenue,
      thisMonthPoints: thisMonthPoints,
    );
  }

  Map<String, dynamic> _ascensionSummaryFromProfile(
    Map<String, dynamic> profile,
  ) {
    double asDouble(Object? raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse((raw ?? '').toString().trim()) ?? 0;
    }

    String firstNonEmpty(List<Object?> values) {
      for (final raw in values) {
        final text = (raw ?? '').toString().trim();
        if (text.isNotEmpty) return text;
      }
      return '';
    }

    final ascension =
        (profile['ascension'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final points = asDouble(
      ascension['points'] ??
          profile['panel_ascensionPoints'] ??
          profile['ascensionPoints'],
    );
    final tierRaw = firstNonEmpty([
      ascension['tier'],
      profile['panel_ascensionLevel'],
      profile['ascensionTier'],
    ]).toLowerCase();

    String tier;
    if (tierRaw == 'maker' || tierRaw == 'goldsmith' || tierRaw == 'crowned') {
      tier = tierRaw;
    } else if (points >= 9750) {
      tier = 'crowned';
    } else if (points >= 1000) {
      tier = 'goldsmith';
    } else {
      tier = 'maker';
    }

    double pointsToNext;
    String nextTierLabel;
    if (points >= 9750) {
      pointsToNext = 0;
      nextTierLabel = 'Crowned';
      tier = 'crowned';
    } else if (points >= 1000) {
      pointsToNext = 9750 - points;
      nextTierLabel = 'Crowned';
      tier = 'goldsmith';
    } else {
      pointsToNext = 1000 - points;
      nextTierLabel = 'Goldsmith';
      tier = 'maker';
    }

    return <String, dynamic>{
      'tier': tier,
      'points': points,
      'pointsToNextTier': pointsToNext < 0 ? 0 : pointsToNext,
      'nextTierLabel': nextTierLabel,
    };
  }

  double _asDoubleSafe(Object? raw, {double fallback = 0}) {
    if (raw is num) return raw.toDouble();
    final parsed = double.tryParse((raw ?? '').toString().trim());
    return parsed ?? fallback;
  }

  List<_MonthTrendPoint> _lastSixMonthPaidTrend() {
    final now = DateTime.now();
    final startMonth = DateTime(now.year, now.month - 5, 1);
    final buckets = <DateTime, double>{
      for (int i = 0; i < 6; i++)
        DateTime(startMonth.year, startMonth.month + i, 1): 0,
    };
    for (final request in _allVisible.where(_isPaid)) {
      final d = _earningDate(request);
      final monthKey = DateTime(d.year, d.month, 1);
      if (!buckets.containsKey(monthKey)) continue;
      buckets[monthKey] = (buckets[monthKey] ?? 0) + _amount(request);
    }
    const shortMonths = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return buckets.entries
        .map(
          (e) => _MonthTrendPoint(
            label: shortMonths[e.key.month - 1],
            value: e.value,
          ),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: 'Artist earnings',
      child: Scaffold(
        backgroundColor: AppColors.snow,
        appBar: JntStandardAppBar(
          onNotifications:
              widget.onOpenNotifications ??
              () {
                NotificationsPage.showAsModal(context);
              },
          trailing: _AvatarMenu(
            onManageProfile: widget.onManageProfile,
            onOpenHistory: widget.onOpenHistory,
            onOpenCalendar: widget.onOpenCalendar,
            onOpenArtist: widget.onOpenArtist,
            onOpenReviews: widget.onOpenReviews,
            clientArtistMenuStyle: widget.clientArtistMenuStyle,
            onSignOut:
                widget.onSignOut ??
                () {
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/', (route) => false);
                },
          ),
        ),
        bottomNavigationBar: widget.showBottomNav
            ? BottomNavigationBar(
                backgroundColor: AppColors.balletSlippers,
                currentIndex: widget.bottomNavCurrentIndex,
                onTap: widget.onBottomNavTap,
                type: BottomNavigationBarType.fixed,
                selectedItemColor: AppColors.blackCat,
                unselectedItemColor: Colors.black.withValues(alpha: 0.55),
                items: [
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined),
                    activeIcon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.add_circle_outline),
                    activeIcon: Icon(Icons.add_circle),
                    label: 'Design',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.inbox_outlined),
                    activeIcon: Icon(Icons.inbox),
                    label: 'Requests',
                  ),
                  if (widget.showCampaignsTab)
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.campaign_outlined),
                      activeIcon: Icon(Icons.campaign),
                      label: 'Campaigns',
                    ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.receipt_long_outlined),
                    activeIcon: Icon(Icons.receipt_long),
                    label: 'Orders',
                  ),
                  if (!widget.showCampaignsTab)
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.attach_money_outlined),
                      activeIcon: Icon(Icons.attach_money),
                      label: 'Earnings',
                    ),
                ],
              )
            : null,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : ScrollConfiguration(
                behavior: const _NoGlowScrollBehavior(),
                child: ListView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                  children: [
                    _TotalEarningsCard(
                      total: summary.totalEarnings,
                      deltaLabel: '${_money(summary.monthEarnings)} this month',
                    ),
                    const SizedBox(height: 12),
                    _AscensionSummaryCard(
                      tier: (_ascensionData['tier'] ?? 'maker').toString(),
                      points: _asDoubleSafe(_ascensionData['points']),
                      pointsToNextTier: _asDoubleSafe(
                        _ascensionData['pointsToNextTier'],
                        fallback: 1000,
                      ),
                      nextTierLabel:
                          (_ascensionData['nextTierLabel'] ?? 'Goldsmith')
                              .toString(),
                      onViewAscension: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const JntAscensionPage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _AscensionStagesCard(summary: _stageSummary),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            summary.rangeLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.blackCat.withValues(alpha: 0.70),
                            ),
                          ),
                        ),
                        _RangeDropdown(
                          value: _range,
                          onChanged: (v) => setState(() => _range = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const _SectionLabel(title: 'Money in'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'Paid Earning',
                            value: _money(summary.totalEarnings),
                            subtitle: '${summary.paidOrders} paid orders',
                            icon: Icons.attach_money_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            title: 'Pending Earning',
                            value: _money(summary.pendingAmount),
                            subtitle: 'Awaiting payment',
                            icon: Icons.schedule_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const _SectionLabel(title: 'Performance'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'Average order',
                            value: _money(summary.averageOrder),
                            subtitle: 'Paid order average',
                            icon: Icons.analytics_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            title: 'Orders delivered',
                            value: '${summary.deliveredPaidOrders}',
                            subtitle: 'Delivered successfully',
                            icon: Icons.check_circle_outline_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _PerformanceTrendCard(points: _lastSixMonthPaidTrend()),
                    const SizedBox(height: 12),
                    _BreakdownCard(
                      paidAmount: summary.paidAmountInRange,
                      unpaidAmount: summary.unpaidAmountInRange,
                    ),
                    const SizedBox(height: 12),
                    _RecentPayoutsCard(
                      items: summary.recentPaidOrders
                          .map(
                            (r) => _PayoutItem(
                              amount: _amount(r),
                              dateLabel: _formatShortDate(_earningDate(r)),
                              note: r.orderNumber.trim().isEmpty
                                  ? r.id
                                  : r.orderNumber.trim(),
                              statusLabel: r.status.label,
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class _MonthTrendPoint {
  const _MonthTrendPoint({required this.label, required this.value});
  final String label;
  final double value;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PerformanceTrendCard extends StatelessWidget {
  const _PerformanceTrendCard({required this.points});
  final List<_MonthTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final maxValue = points.fold<double>(
      0,
      (max, p) => p.value > max ? p.value : max,
    );
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Last 6 months',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: points
                  .map(
                    (p) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: ((p.value / safeMax) * 84)
                                  .clamp(6.0, 84.0)
                                  .toDouble(),
                              decoration: BoxDecoration(
                                color: AppColors.balletSlippers,
                                borderRadius: BorderRadius.zero,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              p.label,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.blackCat.withValues(
                                  alpha: 0.65,
                                ),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarMenu extends StatelessWidget {
  const _AvatarMenu({
    required this.onSignOut,
    this.onManageProfile,
    this.onOpenHistory,
    this.onOpenCalendar,
    this.onOpenArtist,
    this.onOpenReviews,
    this.clientArtistMenuStyle = false,
  });

  final VoidCallback onSignOut;
  final VoidCallback? onManageProfile;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenArtist;
  final VoidCallback? onOpenReviews;
  final bool clientArtistMenuStyle;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_AvatarAction>(
      tooltip: 'Account menu',
      position: PopupMenuPosition.under,
      elevation: 12,
      color: AppColors.snow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      onSelected: (v) {
        switch (v) {
          case _AvatarAction.profile:
            onManageProfile?.call();
            break;
          case _AvatarAction.history:
            onOpenHistory?.call();
            break;
          case _AvatarAction.calendar:
            onOpenCalendar?.call();
            break;
          case _AvatarAction.artist:
            onOpenArtist?.call();
            break;
          case _AvatarAction.reviews:
            if (onOpenReviews != null) {
              onOpenReviews?.call();
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ArtistReviewsPage()),
              );
            }
            break;
          case _AvatarAction.signOut:
            onSignOut();
            break;
        }
      },
      child: SizedBox(
        height: JntHeaderMetrics.avatarSize,
        width: JntHeaderMetrics.avatarSize,
        child: ClipRRect(
          borderRadius: BorderRadius.zero,
          child: const ArtistProfileAvatarIcon(
            size: JntHeaderMetrics.avatarSize,
          ),
        ),
      ),
      itemBuilder: (_) => [
        if (clientArtistMenuStyle)
          const PopupMenuItem(
            value: _AvatarAction.profile,
            child: _MenuRow(icon: Icons.person_outline, label: 'Profile'),
          ),
        if (clientArtistMenuStyle)
          const PopupMenuItem(
            value: _AvatarAction.history,
            child: _MenuRow(icon: Icons.history, label: 'History'),
          ),
        if (clientArtistMenuStyle)
          const PopupMenuItem(
            value: _AvatarAction.calendar,
            child: _MenuRow(
              icon: Icons.calendar_month_outlined,
              label: 'Calendar',
            ),
          ),
        if (clientArtistMenuStyle)
          const PopupMenuItem(
            value: _AvatarAction.artist,
            child: _MenuRow(icon: Icons.brush_outlined, label: 'Artist'),
          ),
        const PopupMenuItem(
          value: _AvatarAction.reviews,
          child: _MenuRow(icon: Icons.star_outline_rounded, label: 'Reviews'),
        ),
        if (clientArtistMenuStyle) const PopupMenuDivider(),
        PopupMenuItem(
          value: _AvatarAction.signOut,
          child: _MenuRow(
            icon: Icons.logout_rounded,
            label: 'Logout',
            color: clientArtistMenuStyle ? AppColors.blackCat : null,
          ),
        ),
      ],
    );
  }
}

enum _AvatarAction { profile, history, calendar, artist, reviews, signOut }

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.color});
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color ?? AppColors.blackCat),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _TotalEarningsCard extends StatelessWidget {
  const _TotalEarningsCard({required this.total, required this.deltaLabel});

  final double total;
  final String deltaLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.zero,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.blackCat, AppColors.blackCatLight],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Earnings',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.snow.withValues(alpha: 0.92),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '\$${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.snow,
                    fontSize: 30,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  deltaLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.snow.withValues(alpha: 0.90),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AscensionStageSummary {
  const _AscensionStageSummary({
    required this.result,
    required this.completedOrders,
    required this.completedOrderPoints,
    required this.onTimeDeliveries,
    required this.onTimeDeliveryPoints,
    required this.fiveStarReviews,
    required this.fiveStarReviewPoints,
    required this.repeatClientOrders,
    required this.repeatClientOrderPoints,
    required this.portfolioUploads,
    required this.portfolioUploadPoints,
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
      completedOrderPoints = 0,
      onTimeDeliveries = 0,
      onTimeDeliveryPoints = 0,
      fiveStarReviews = 0,
      fiveStarReviewPoints = 0,
      repeatClientOrders = 0,
      repeatClientOrderPoints = 0,
      portfolioUploads = 0,
      portfolioUploadPoints = 0,
      deliveredOrders = 0,
      artistGmv = 0,
      jntRevenue = 0,
      thisMonthPoints = 0;

  final JntAscensionResult result;
  final int completedOrders;
  final double completedOrderPoints;
  final int onTimeDeliveries;
  final double onTimeDeliveryPoints;
  final int fiveStarReviews;
  final double fiveStarReviewPoints;
  final int repeatClientOrders;
  final double repeatClientOrderPoints;
  final int portfolioUploads;
  final double portfolioUploadPoints;
  final int deliveredOrders;
  final double artistGmv;
  final double jntRevenue;
  final double thisMonthPoints;
}

class _AscensionStagesCard extends StatelessWidget {
  const _AscensionStagesCard({required this.summary});

  final _AscensionStageSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Ascension stages',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.blackCat,
                  ),
                ),
              ),
              Text(
                'This month: +${summary.thisMonthPoints.toStringAsFixed(2)} pts',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                  color: AppColors.blackCat.withValues(alpha: 0.58),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _stageRow(
            icon: Icons.check_circle_outline_rounded,
            title: 'Completed orders',
            subtitle: '${summary.completedOrders} order(s) × 25 pts',
            points: summary.completedOrderPoints,
          ),
          _stageRow(
            icon: Icons.local_shipping_outlined,
            title: 'On-time shipments',
            subtitle: '${summary.onTimeDeliveries} shipment(s) × 8.5 pts',
            points: summary.onTimeDeliveryPoints,
          ),
          _stageRow(
            icon: Icons.star_outline_rounded,
            title: '5-star client reviews',
            subtitle: '${summary.fiveStarReviews} review(s) × 9 pts',
            points: summary.fiveStarReviewPoints,
          ),
          _stageRow(
            icon: Icons.repeat_rounded,
            title: 'Repeat client orders',
            subtitle: '${summary.repeatClientOrders} repeat order(s) × 6 pts',
            points: summary.repeatClientOrderPoints,
          ),
          _stageRow(
            icon: Icons.person_pin_outlined,
            title: 'Profile / portfolio upload',
            subtitle: '${summary.portfolioUploads} upload(s) × 0.3 pts',
            points: summary.portfolioUploadPoints,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _stageRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required double points,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 9),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.blackCat),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: AppColors.blackCat,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                    color: AppColors.blackCat.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '+${points.toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: Color(0xFF14823A),
            ),
          ),
        ],
      ),
    );
  }
}

class _AscensionSummaryCard extends StatelessWidget {
  const _AscensionSummaryCard({
    required this.tier,
    required this.points,
    required this.pointsToNextTier,
    required this.nextTierLabel,
    required this.onViewAscension,
  });

  final String tier;
  final double points;
  final double pointsToNextTier;
  final String nextTierLabel;
  final VoidCallback onViewAscension;

  String get _tierLabel {
    switch (tier.trim().toLowerCase()) {
      case 'goldsmith':
        return 'Goldsmith';
      case 'crowned':
        return 'Crowned';
      default:
        return 'Maker';
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = pointsToNextTier == 0
        ? 'You have reached the highest JNT Ascension tier.'
        : '${pointsToNextTier.toStringAsFixed(2)} pts to $nextTierLabel';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.star_rounded, color: AppColors.blackCat, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'JNT Ascension',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 5),
                Text(
                  '$_tierLabel · ${points.toStringAsFixed(2)} pts',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.blackCat,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppColors.blackCat.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onViewAscension,
            style: TextButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: AppColors.blackCat,
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            child: const Text('View Ascension'),
          ),
        ],
      ),
    );
  }
}

class _RangeDropdown extends StatelessWidget {
  const _RangeDropdown({required this.value, required this.onChanged});

  final _EarningsRange value;
  final ValueChanged<_EarningsRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_EarningsRange>(
      onSelected: onChanged,
      color: AppColors.snow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      itemBuilder: (_) => _EarningsRange.values
          .map(
            (v) =>
                PopupMenuItem<_EarningsRange>(value: v, child: Text(v.label)),
          )
          .toList(growable: false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.snow,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: AppColors.blackCatBorderLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value.label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.blackCat.withValues(alpha: 0.55),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: AppColors.blackCat.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 24),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: AppColors.blackCat.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.blackCat.withValues(alpha: 0.55),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.paidAmount, required this.unpaidAmount});

  final double paidAmount;
  final double unpaidAmount;

  @override
  Widget build(BuildContext context) {
    final total = paidAmount + unpaidAmount;
    final paidPct = total <= 0 ? 0.0 : paidAmount / total;
    final unpaidPct = total <= 0 ? 0.0 : unpaidAmount / total;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Earnings Breakdown',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: AppColors.blackCat.withValues(alpha: 0.90),
            ),
          ),
          const SizedBox(height: 12),
          _row('Paid', paidAmount),
          const SizedBox(height: 8),
          _bar(paidPct, AppColors.blackCat),
          const SizedBox(height: 12),
          _row('Pending', unpaidAmount),
          const SizedBox(height: 8),
          _bar(unpaidPct, AppColors.balletSlippers),
        ],
      ),
    );
  }

  Widget _row(String label, double amount) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _bar(double pct, Color color) {
    return Container(
      height: 10,
      decoration: BoxDecoration(
        color: AppColors.alabaster,
        borderRadius: BorderRadius.zero,
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: pct.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.zero,
          ),
        ),
      ),
    );
  }
}

class _RecentPayoutsCard extends StatelessWidget {
  const _RecentPayoutsCard({required this.items});

  final List<_PayoutItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Paid Orders',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: AppColors.blackCat.withValues(alpha: 0.90),
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(
              'No paid orders in this range.',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: AppColors.blackCat.withValues(alpha: 0.60),
              ),
            ),
          ...items.map((e) => _PayoutTile(item: e)),
        ],
      ),
    );
  }
}

class _PayoutTile extends StatelessWidget {
  const _PayoutTile({required this.item});
  final _PayoutItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.snow,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: AppColors.blackCatBorderLight),
        ),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: AppColors.balletSlippers,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.attach_money_rounded,
                color: AppColors.blackCat.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\$${item.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.dateLabel} - ${item.note}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppColors.blackCat.withValues(alpha: 0.60),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              item.statusLabel,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: AppColors.blackCat.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _EarningsRange {
  last30Days('Last 30 Days'),
  last90Days('Last 90 Days'),
  last365Days('Last 365 Days'),
  allTime('All Time');

  const _EarningsRange(this.label);
  final String label;
}

class _EarningsSummary {
  const _EarningsSummary({
    required this.totalEarnings,
    required this.monthEarnings,
    required this.paidOrders,
    required this.pendingAmount,
    required this.averageOrder,
    required this.deliveredPaidOrders,
    required this.paidAmountInRange,
    required this.unpaidAmountInRange,
    required this.recentPaidOrders,
    required this.rangeLabel,
  });

  final double totalEarnings;
  final double monthEarnings;
  final int paidOrders;
  final double pendingAmount;
  final double averageOrder;
  final int deliveredPaidOrders;
  final double paidAmountInRange;
  final double unpaidAmountInRange;
  final List<ClientRequestV2> recentPaidOrders;
  final String rangeLabel;
}

class _PayoutItem {
  const _PayoutItem({
    required this.amount,
    required this.dateLabel,
    required this.note,
    required this.statusLabel,
  });

  final double amount;
  final String dateLabel;
  final String note;
  final String statusLabel;
}
