import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/client_request_v2.dart';
import '../services/artist_requests_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/artist_profile_avatar_icon.dart';
import '../widgets/notification_bell_button.dart';
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
    this.clientArtistMenuStyle = false,
  });

  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenInbox;
  final VoidCallback? onSignOut;
  final VoidCallback? onManageProfile;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenArtist;
  final bool clientArtistMenuStyle;

  @override
  State<ArtistEarningsPage> createState() => _ArtistEarningsPageState();
}

class _ArtistEarningsPageState extends State<ArtistEarningsPage> {
  bool _isLoading = true;
  _EarningsRange _range = _EarningsRange.allTime;
  final List<ClientRequestV2> _allVisible = <ClientRequestV2>[];

  RealtimeChannel? _requestsChannel;
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
        .subscribe((status, [error]) {
          if (error != null) {
            debugPrint('Artist earnings realtime error: $error');
          }
        });
  }

  Future<void> _loadAscensionFromSupabase() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      Map<String, dynamic>? row;
      for (final table in const ['artist', 'client_artist']) {
        row = await Supabase.instance.client
            .from(table)
            .select('profile')
            .eq('id', uid)
            .maybeSingle();
        if (row != null) break;
      }
      if (row == null || !mounted) return;
      final profile = (row['profile'] as Map<String, dynamic>?) ?? {};
      if (!mounted) return;
      setState(() => _ascensionData = _ascensionSummaryFromProfile(profile));
    } catch (_) {
      // keep defaults
    }
  }

  Future<void> _reload() async {
    try {
      final currentArtistEmail =
          (Supabase.instance.client.auth.currentUser?.email ?? '').trim().toLowerCase();
      final all = await ArtistRequestsRepository.fetchAllRequests();
      if (!mounted) return;

      final visible = all
          .where(
            (r) =>
                _isVisibleToArtist(request: r, artistEmail: currentArtistEmail),
          )
          .toList(growable: false);

      setState(() {
        _allVisible
          ..clear()
          ..addAll(visible);
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
  }) {
    final ownedBy = request.acceptedByArtistEmail.trim().toLowerCase();
    final isOwnedByCurrentArtist =
        artistEmail.isNotEmpty && ownedBy == artistEmail;
    final declinedByCurrentArtist =
        artistEmail.isNotEmpty &&
        request.declinedByArtistEmails.contains(artistEmail);

    switch (request.status) {
      case RequestStatusV2.inReview:
        return !declinedByCurrentArtist;
      case RequestStatusV2.accepted:
      case RequestStatusV2.designing:
      case RequestStatusV2.completed:
      case RequestStatusV2.shipped:
      case RequestStatusV2.delivered:
      case RequestStatusV2.declined:
      case RequestStatusV2.cancelled:
      case RequestStatusV2.expired:
        return ownedBy.isEmpty || isOwnedByCurrentArtist;
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

    final deliveredPaid = paid
        .where((r) => r.status == RequestStatusV2.delivered)
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

  String _formatDate(DateTime d) {
    const months = <String>[
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
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _formatShortDate(DateTime d) {
    const week = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = <String>[
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
    return '${week[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }

  String _money(double v) => '\$${v.toStringAsFixed(2)}';

  Map<String, dynamic> _ascensionSummaryFromProfile(
    Map<String, dynamic> profile,
  ) {
    int asInt(Object? raw) {
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return int.tryParse((raw ?? '').toString().trim()) ?? 0;
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
    final points = asInt(
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

    int pointsToNext;
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

  int _asIntSafe(Object? raw, {int fallback = 0}) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    final parsed = int.tryParse((raw ?? '').toString().trim());
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
    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(85),
        child: Container(
          color: AppColors.alabaster,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: [
                  NotificationBellButton(
                    onTap:
                        widget.onOpenNotifications ??
                        () {
                          NotificationsPage.showAsModal(context);
                        },
                    iconSize: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Center(
                      child: Image.asset(
                        'assets/images/jnt_logo_black.png',
                        height: 50,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _AvatarMenu(
                    onManageProfile: widget.onManageProfile,
                    onOpenHistory: widget.onOpenHistory,
                    onOpenCalendar: widget.onOpenCalendar,
                    onOpenArtist: widget.onOpenArtist,
                    clientArtistMenuStyle: widget.clientArtistMenuStyle,
                    onSignOut:
                        widget.onSignOut ??
                        () {
                          Navigator.of(
                            context,
                          ).pushNamedAndRemoveUntil('/', (route) => false);
                        },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
                    points: _asIntSafe(_ascensionData['points']),
                    pointsToNextTier: _asIntSafe(
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
                          subtitle: 'Delivered + paid',
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
                                color: AppColors.blackCat.withValues(alpha: 0.65),
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
    this.clientArtistMenuStyle = false,
  });

  final VoidCallback onSignOut;
  final VoidCallback? onManageProfile;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenArtist;
  final bool clientArtistMenuStyle;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_AvatarAction>(
      tooltip: '',
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
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ArtistReviewsPage()),
            );
            break;
          case _AvatarAction.signOut:
            onSignOut();
            break;
        }
      },
      child: SizedBox(
        height: 36,
        width: 36,
        child: ClipRRect(
          borderRadius: BorderRadius.zero,
          child: const ArtistProfileAvatarIcon(size: 36),
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

class _AscensionSummaryCard extends StatelessWidget {
  const _AscensionSummaryCard({
    required this.tier,
    required this.points,
    required this.pointsToNextTier,
    required this.nextTierLabel,
    required this.onViewAscension,
  });

  final String tier;
  final int points;
  final int pointsToNextTier;
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
        : '$pointsToNextTier pts to $nextTierLabel';
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
                  '$_tierLabel · $points pts',
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
              Icon(icon, size: 16, color: AppColors.blackCat.withValues(alpha: 0.55)),
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
