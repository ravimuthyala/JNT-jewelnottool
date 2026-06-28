// lib/pages/artist_history_page.dart
import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/client_request_v2.dart';
import '../services/artist_requests_repository.dart';
import '../services/storage_url_resolver.dart';
import '../theme/app_colors.dart';
import 'artist_delivered_request_sheet.dart';
import 'artist_profile_page.dart';
import 'artist_reviews_page.dart';
import 'notifications_page.dart';
import 'simple_status_request_sheet.dart';
import '../widgets/artist_profile_avatar_icon.dart';
import '../widgets/notification_bell_button.dart';

class ArtistHistoryPage extends StatefulWidget {
  const ArtistHistoryPage({
    super.key,
    this.onBackHome,
    this.onOpenNotifications,
    this.onManageProfile,
    this.onOpenInbox,
    this.onOpenHistory,
    this.onOpenCalendar,
    this.onOpenArtist,
    this.onSignOut,
    this.showExtendedAvatarMenu = false,
    this.hideHistoryMenuItem = false,
    this.hideCalendarMenuItem = false,
    this.showBottomNav = false,
    this.bottomNavIndex = 4,
    this.onNavTap,
  });

  final VoidCallback? onBackHome;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onManageProfile;
  final VoidCallback? onOpenInbox;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenArtist;
  final VoidCallback? onSignOut;
  final bool showExtendedAvatarMenu;
  final bool hideHistoryMenuItem;
  final bool hideCalendarMenuItem;
  final bool showBottomNav;
  final int bottomNavIndex;
  final ValueChanged<int>? onNavTap;

  @override
  State<ArtistHistoryPage> createState() => _ArtistHistoryPageState();
}

class _ArtistHistoryPageState extends State<ArtistHistoryPage> {
  ArtistHistoryFilter _filter = ArtistHistoryFilter.all;
  bool _isLoadingDb = true;

  final List<ClientRequestV2> _all = <ClientRequestV2>[];
  RealtimeChannel? _requestsChannel;

  @override
  void initState() {
    super.initState();
    _loadHistoryFromDb();
    _listenRealtime();
  }

  @override
  void dispose() {
    _requestsChannel?.unsubscribe();
    super.dispose();
  }

  void _listenRealtime() {
    _requestsChannel?.unsubscribe();
    _requestsChannel = Supabase.instance.client
        .channel('artist_history_requests')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'client_custom_requests',
          callback: (_) => _loadHistoryFromDb(),
        )
        .subscribe((status, [error]) {
          if (error != null) {
            debugPrint('Artist history realtime error: $error');
          }
        });
  }

  Future<void> _loadHistoryFromDb() async {
    try {
      final allRequests = await ArtistRequestsRepository.fetchAllRequests();
      final currentArtistEmail =
          (Supabase.instance.client.auth.currentUser?.email ?? '').trim().toLowerCase();
      unawaited(
        _syncArtistRatingFromReviews(
          allRequests,
          artistEmail: currentArtistEmail,
        ),
      );
      if (!mounted) return;

      setState(() {
        _all
          ..clear()
          ..addAll(
            allRequests.where(
              (r) =>
                  _isHistoryStatus(r, currentArtistEmail) &&
                  _isVisibleToArtist(
                    request: r,
                    artistEmail: currentArtistEmail,
                  ),
            ),
          );
        _all.sort(
          (a, b) =>
              _historyDateForStatus(b).compareTo(_historyDateForStatus(a)),
        );
        _isLoadingDb = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingDb = false);
    }
  }

  Future<void> _syncArtistRatingFromReviews(
    List<ClientRequestV2> allRequests, {
    required String artistEmail,
  }) async {
    final reviewedDelivered = allRequests
        .where((r) {
          if (r.status != RequestStatusV2.delivered) return false;
          final rating = r.clientRating ?? 0;
          if (rating <= 0) return false;
          return _isVisibleToArtist(request: r, artistEmail: artistEmail);
        })
        .toList(growable: false);

    if (reviewedDelivered.isEmpty) return;

    final highestRating = reviewedDelivered
        .map((r) => r.clientRating ?? 0)
        .fold<double>(0, (max, value) => value > max ? value : max)
        .clamp(0, 5);
    final reviewCount = reviewedDelivered.length;

    final supabase = Supabase.instance.client;
    final uid = (supabase.auth.currentUser?.id ?? '').trim();
    final email =
        (supabase.auth.currentUser?.email ?? '').trim().toLowerCase();
    if (uid.isEmpty && email.isEmpty) return;

    Map<String, dynamic>? artistRow;
    String? artistTable;
    for (final table in const <String>['artist', 'client_artist']) {
      try {
        Map<String, dynamic>? row;
        if (uid.isNotEmpty) {
          row = await supabase
              .from(table)
              .select('id, email, display_name, name, profile')
              .eq('id', uid)
              .maybeSingle();
        }
        if (row == null && email.isNotEmpty) {
          row = await supabase
              .from(table)
              .select('id, email, display_name, name, profile')
              .eq('email', email)
              .maybeSingle();
        }
        if (row != null) {
          artistRow = row;
          artistTable = table;
          break;
        }
      } catch (_) {}
    }

    if (artistRow == null || artistTable == null) return;

    final rowId = (artistRow['id'] ?? '').toString().trim();
    if (rowId.isEmpty) return;

    final existingProfile =
        (artistRow['profile'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final existingStats =
        (existingProfile['stats'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final existingRating =
        ((existingStats['rating'] ??
                    existingProfile['rating'] ??
                    artistRow['rating'])
                as num?)
            ?.toDouble() ??
        0;
    final existingCount =
        ((existingStats['reviewCount'] ??
                    existingStats['reviews'] ??
                    existingProfile['reviewCount'])
                as num?)
            ?.toInt() ??
        0;
    final ratingUnchanged = (existingRating - highestRating).abs() < 0.0001;
    if (ratingUnchanged && existingCount == reviewCount) return;

    final updatedProfile = <String, dynamic>{
      ...existingProfile,
      'stats': <String, dynamic>{
        ...existingStats,
        'rating': highestRating,
        'averageRating': highestRating,
        'reviewCount': reviewCount,
        'reviews': reviewCount,
      },
      'rating': highestRating,
      'averageRating': highestRating,
      'reviewCount': reviewCount,
      'reviews': reviewCount,
    };

    try {
      await supabase
          .from(artistTable)
          .update({
            'profile': updatedProfile,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', rowId);
    } catch (e) {
      debugPrint('_syncArtistRatingFromReviews Supabase update failed: $e');
    }
  }

  bool _isArtistDeclinedForHistory(
    ClientRequestV2 request,
    String artistEmail,
  ) {
    if (artistEmail.isEmpty) return false;
    final artistDeclined = request.declinedByArtistEmails.contains(artistEmail);
    if (!artistDeclined) return false;
    return request.status == RequestStatusV2.inReview ||
        request.status == RequestStatusV2.cancelled;
  }

  bool _isHistoryStatus(ClientRequestV2 request, String artistEmail) {
    return request.status == RequestStatusV2.delivered ||
        request.status == RequestStatusV2.declined ||
        request.status == RequestStatusV2.expired ||
        request.status == RequestStatusV2.cancelled ||
        _isArtistDeclinedForHistory(request, artistEmail);
  }

  bool _isVisibleToArtist({
    required ClientRequestV2 request,
    required String artistEmail,
  }) {
    final ownedBy = request.acceptedByArtistEmail.trim().toLowerCase();
    final selectedBy = request.selectedArtistEmail.trim().toLowerCase();
    final resolvedOwner = ownedBy.isNotEmpty ? ownedBy : selectedBy;
    final isOwnedByCurrentArtist =
        artistEmail.isNotEmpty && resolvedOwner == artistEmail;
    if (_isArtistDeclinedForHistory(request, artistEmail)) {
      return true;
    }
    return resolvedOwner.isEmpty || isOwnedByCurrentArtist;
  }

  DateTime _historyDateForStatus(ClientRequestV2 r) {
    switch (r.status) {
      case RequestStatusV2.delivered:
        return r.deliveredAt ?? r.shippedAt ?? r.neededBy;
      case RequestStatusV2.declined:
        return r.completionDeclinedAt ?? r.neededBy;
      case RequestStatusV2.expired:
      case RequestStatusV2.cancelled:
      default:
        return r.neededBy;
    }
  }

  String _statusTextForHistory(ClientRequestV2 r) {
    final d = _historyDateForStatus(r);
    final currentArtistEmail = (Supabase.instance.client.auth.currentUser?.email ?? '')
        .trim()
        .toLowerCase();
    if (_isArtistDeclinedForHistory(r, currentArtistEmail)) {
      return 'Declined ${_monthShort(d.month)} ${d.day}';
    }
    switch (r.status) {
      case RequestStatusV2.delivered:
        return 'Delivered ${_monthShort(d.month)} ${d.day}';
      case RequestStatusV2.declined:
        return 'Declined ${_monthShort(d.month)} ${d.day}';
      case RequestStatusV2.expired:
        return 'Expired ${_monthShort(d.month)} ${d.day}';
      case RequestStatusV2.cancelled:
        return 'Cancelled ${_monthShort(d.month)} ${d.day}';
      default:
        return r.status.label;
    }
  }

  ArtistOrderLiteStatus _toLiteStatus(RequestStatusV2 s) {
    switch (s) {
      case RequestStatusV2.delivered:
        return ArtistOrderLiteStatus.delivered;
      case RequestStatusV2.declined:
        return ArtistOrderLiteStatus.declined;
      case RequestStatusV2.expired:
        return ArtistOrderLiteStatus.expired;
      case RequestStatusV2.cancelled:
      default:
        return ArtistOrderLiteStatus.cancelled;
    }
  }

  ArtistOrderLiteStatus _historyLiteStatus(ClientRequestV2 r) {
    final currentArtistEmail = (Supabase.instance.client.auth.currentUser?.email ?? '')
        .trim()
        .toLowerCase();
    if (_isArtistDeclinedForHistory(r, currentArtistEmail)) {
      return ArtistOrderLiteStatus.declined;
    }
    return _toLiteStatus(r.status);
  }

  String _pickCardImage(ClientRequestV2 r) {
    final profile = r.clientProfileImage.trim();

    if (profile.startsWith('http://') || profile.startsWith('https://')) {
      return profile;
    }

    return '';
  }

  String _historyReasonForStatus(ClientRequestV2 r) {
    final currentArtistEmail = (Supabase.instance.client.auth.currentUser?.email ?? '')
        .trim()
        .toLowerCase();
    if (_isArtistDeclinedForHistory(r, currentArtistEmail)) {
      final reason = r.declineReason.trim().isNotEmpty
          ? r.declineReason.trim()
          : r.completionDeclineReason.trim();
      return reason.isNotEmpty ? reason : 'Declined by artist';
    }
    switch (r.status) {
      case RequestStatusV2.declined:
        final reason = r.declineReason.trim().isNotEmpty
            ? r.declineReason.trim()
            : r.completionDeclineReason.trim();
        return reason.isNotEmpty ? reason : 'Declined by artist';
      case RequestStatusV2.cancelled:
        final reason = r.cancelReason.trim();
        return reason.isNotEmpty ? reason : 'Cancelled by user';
      case RequestStatusV2.expired:
        return 'Request expired';
      default:
        return r.title;
    }
  }

  List<ArtistOrderLite> get _historyItems {
    return _all
        .map(
          (r) => ArtistOrderLite(
            id: r.id,
            clientName: _isBrandRequest(r)
                ? (r.brandName.trim().isNotEmpty
                      ? r.brandName.trim()
                      : r.clientName)
                : r.clientName,
            title: r.title,
            subtitle: _isBrandRequest(r) ? r.title : _historyReasonForStatus(r),
            isBrandRequest: _isBrandRequest(r),
            status: _historyLiteStatus(r),
            statusText: _statusTextForHistory(r),
            imageAsset: _pickCardImage(r),
            budgetMin: r.budgetMin,
            budgetMax: r.budgetMax,
            carrier: r.shippedByCourier,
            shippedAt: r.shippedAt,
            deliveredAt: r.deliveredAt,
            clientPhotos: const [],
            artistPhotos: const [],
          ),
        )
        .toList(growable: false);
  }

  bool _isBrandRequest(ClientRequestV2 r) {
    final source = r.sourceCollection.trim();
    final orderNo = r.orderNumber.trim().toUpperCase();
    return source == 'Company_Custom_Requests' ||
        orderNo.startsWith('BE-') ||
        orderNo.startsWith('BR-');
  }

  List<ClientRequestV2> get _filteredRequests {
    switch (_filter) {
      case ArtistHistoryFilter.all:
        return _all;
      case ArtistHistoryFilter.delivered:
        return _all
            .where((r) => r.status == RequestStatusV2.delivered)
            .toList(growable: false);
      case ArtistHistoryFilter.declined:
        return _all
            .where((r) {
              final currentArtistEmail =
                  (Supabase.instance.client.auth.currentUser?.email ?? '')
                      .trim()
                      .toLowerCase();
              return r.status == RequestStatusV2.declined ||
                  _isArtistDeclinedForHistory(r, currentArtistEmail);
            })
            .toList(growable: false);
      case ArtistHistoryFilter.expired:
        return _all
            .where((r) => r.status == RequestStatusV2.expired)
            .toList(growable: false);
      case ArtistHistoryFilter.cancelled:
        return _all
            .where((r) => r.status == RequestStatusV2.cancelled)
            .toList(growable: false);
    }
  }

  int _countForFilter(ArtistHistoryFilter filter) {
    final currentArtistEmail = (Supabase.instance.client.auth.currentUser?.email ?? '')
        .trim()
        .toLowerCase();
    switch (filter) {
      case ArtistHistoryFilter.all:
        return _all.length;
      case ArtistHistoryFilter.delivered:
        return _all.where((r) => r.status == RequestStatusV2.delivered).length;
      case ArtistHistoryFilter.declined:
        return _all
            .where(
              (r) =>
                  r.status == RequestStatusV2.declined ||
                  _isArtistDeclinedForHistory(r, currentArtistEmail),
            )
            .length;
      case ArtistHistoryFilter.expired:
        return _all.where((r) => r.status == RequestStatusV2.expired).length;
      case ArtistHistoryFilter.cancelled:
        return _all.where((r) => r.status == RequestStatusV2.cancelled).length;
    }
  }

  Future<void> _openHistoryPopup(
    BuildContext context,
    ClientRequestV2 request,
  ) async {
    final currentArtistEmail = (Supabase.instance.client.auth.currentUser?.email ?? '')
        .trim()
        .toLowerCase();
    if (_isArtistDeclinedForHistory(request, currentArtistEmail)) {
      await showSimpleStatusRequestSheet(
        context: context,
        request: request,
        status: SimpleRequestStatus.declined,
        date: _historyDateForStatus(request),
      );
      return;
    }

    if (request.status == RequestStatusV2.delivered) {
      await showDeliveredRequestSheet(context: context, request: request);
      return;
    }

    late final SimpleRequestStatus simpleStatus;
    switch (request.status) {
      case RequestStatusV2.declined:
        simpleStatus = SimpleRequestStatus.declined;
        break;
      case RequestStatusV2.expired:
        simpleStatus = SimpleRequestStatus.expired;
        break;
      case RequestStatusV2.cancelled:
      default:
        simpleStatus = SimpleRequestStatus.cancelled;
        break;
    }

    await showSimpleStatusRequestSheet(
      context: context,
      request: request,
      status: simpleStatus,
      date: _historyDateForStatus(request),
    );
  }

  void _openNotifications() {
    if (widget.onOpenNotifications != null) {
      widget.onOpenNotifications!.call();
      return;
    }
    NotificationsPage.showAsModal(context);
  }

  void _openManageProfile() {
    if (widget.onManageProfile != null) {
      widget.onManageProfile!.call();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const ArtistProfilePage(showBottomNav: true, bottomNavIndex: 3),
      ),
    );
  }

  Future<void> _signOut() async {
    if (widget.onSignOut != null) {
      widget.onSignOut!.call();
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  void _openHistoryFromMenu() {
    widget.onOpenHistory?.call();
  }

  void _openCalendarFromMenu() {
    widget.onOpenCalendar?.call();
  }

  void _openArtistFromMenu() {
    widget.onOpenArtist?.call();
  }

  void _openReviewsFromMenu() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ArtistReviewsPage()),
    );
  }

  Widget _avatarMenu() {
    return PopupMenuButton<_HeaderAvatarAction>(
      tooltip: '',
      position: PopupMenuPosition.under,
      elevation: 12,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      onSelected: (v) {
        switch (v) {
          case _HeaderAvatarAction.profile:
            _openManageProfile();
            break;
          case _HeaderAvatarAction.history:
            _openHistoryFromMenu();
            break;
          case _HeaderAvatarAction.calendar:
            _openCalendarFromMenu();
            break;
          case _HeaderAvatarAction.artist:
            _openArtistFromMenu();
            break;
          case _HeaderAvatarAction.reviews:
            _openReviewsFromMenu();
            break;
          case _HeaderAvatarAction.signOut:
            _signOut();
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
      itemBuilder: (_) {
        if (!widget.showExtendedAvatarMenu) {
          return const [
            PopupMenuItem(
              value: _HeaderAvatarAction.signOut,
              child: _HeaderMenuRow(
                icon: Icons.logout_rounded,
                label: 'Logout',
              ),
            ),
          ];
        }
        return [
          const PopupMenuItem(
            value: _HeaderAvatarAction.profile,
            child: _HeaderMenuRow(icon: Icons.person_outline, label: 'Profile'),
          ),
          if (!widget.hideHistoryMenuItem)
            const PopupMenuItem(
              value: _HeaderAvatarAction.history,
              child: _HeaderMenuRow(icon: Icons.history, label: 'History'),
            ),
          if (!widget.hideCalendarMenuItem)
            const PopupMenuItem(
              value: _HeaderAvatarAction.calendar,
              child: _HeaderMenuRow(
                icon: Icons.calendar_month_outlined,
                label: 'Calendar',
              ),
            ),
          const PopupMenuItem(
            value: _HeaderAvatarAction.artist,
            child: _HeaderMenuRow(icon: Icons.brush_outlined, label: 'Artist'),
          ),
          const PopupMenuItem(
            value: _HeaderAvatarAction.reviews,
            child: _HeaderMenuRow(
              icon: Icons.star_outline_rounded,
              label: 'Reviews',
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: _HeaderAvatarAction.signOut,
            child: _HeaderMenuRow(
              icon: Icons.logout_rounded,
              label: 'Logout',
              color: AppColors.blackCat,
            ),
          ),
        ];
      },
    );
  }

  String _monthShort(int m) {
    const months = [
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
    return months[(m - 1).clamp(0, 11)];
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRequests;
    final items = _historyItems;
    final byId = <String, ArtistOrderLite>{
      for (final item in items) item.id: item,
    };
    final brandRequests = filtered
        .where(_isBrandRequest)
        .toList(growable: false);
    final clientRequests = filtered
        .where((r) => !_isBrandRequest(r))
        .toList(growable: false);

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
                    onTap: _openNotifications,
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
                  _avatarMenu(),
                ],
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
        children: [
          _HistoryTabs(
            selected: _filter,
            onChanged: (f) => setState(() => _filter = f),
            allCount: _countForFilter(ArtistHistoryFilter.all),
            deliveredCount: _countForFilter(ArtistHistoryFilter.delivered),
            declinedCount: _countForFilter(ArtistHistoryFilter.declined),
            expiredCount: _countForFilter(ArtistHistoryFilter.expired),
            cancelledCount: _countForFilter(ArtistHistoryFilter.cancelled),
          ),
          const SizedBox(height: 16),
          if (_isLoadingDb && filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (filtered.isEmpty)
            _Card(
              child: Column(
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 46,
                    color: AppColors.blackCat.withValues(alpha: 0.35),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'No history found',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Only real-time delivered, declined, expired, and cancelled orders appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.blackCat.withValues(alpha: 0.60),
                      fontWeight: FontWeight.w400,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            _HistorySection(
              title: 'Brand Requests',
              requests: brandRequests,
              byId: byId,
              onTap: (r) => _openHistoryPopup(context, r),
            ),
            const SizedBox(height: 14),
            _HistorySection(
              title: 'Client Requests',
              requests: clientRequests,
              byId: byId,
              onTap: (r) => _openHistoryPopup(context, r),
            ),
          ],
        ],
      ),
      bottomNavigationBar: widget.showBottomNav
          ? BottomNavigationBar(
              currentIndex: widget.bottomNavIndex,
              selectedItemColor: AppColors.blackCat,
              unselectedItemColor: AppColors.blackCat.withValues(alpha: 0.35),
              type: BottomNavigationBarType.fixed,
              onTap: (i) {
                if (widget.onNavTap != null) {
                  widget.onNavTap!(i);
                  return;
                }
                if (i != widget.bottomNavIndex) {
                  Navigator.pop(context);
                }
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_filled),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.add_circle_outline),
                  label: 'Design',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.inbox_outlined),
                  label: 'Requests',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_month_outlined),
                  label: 'Calendar',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.history),
                  label: 'History',
                ),
              ],
            )
          : null,
    );
  }
}

enum ArtistHistoryFilter { all, delivered, declined, expired, cancelled }

class _HistoryTabs extends StatelessWidget {
  const _HistoryTabs({
    required this.selected,
    required this.onChanged,
    required this.allCount,
    required this.deliveredCount,
    required this.declinedCount,
    required this.expiredCount,
    required this.cancelledCount,
  });
  final ArtistHistoryFilter selected;
  final ValueChanged<ArtistHistoryFilter> onChanged;
  final int allCount;
  final int deliveredCount;
  final int declinedCount;
  final int expiredCount;
  final int cancelledCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _tab('All', allCount, ArtistHistoryFilter.all),
            _tab('Delivered', deliveredCount, ArtistHistoryFilter.delivered),
            _tab('Declined', declinedCount, ArtistHistoryFilter.declined),
            _tab('Expired', expiredCount, ArtistHistoryFilter.expired),
            _tab('Cancelled', cancelledCount, ArtistHistoryFilter.cancelled),
          ],
        ),
      ),
    );
  }

  Widget _tab(String label, int count, ArtistHistoryFilter value) {
    final isSelected = selected == value;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '$label $count',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? AppColors.blackCat
                    : AppColors.blackCat.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2.5,
              width: isSelected ? 24 : 0,
              decoration: BoxDecoration(
                color: AppColors.blackCat,
                borderRadius: BorderRadius.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.order, required this.onTap});
  final ArtistOrderLite order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.zero,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Thumb(
              imageAsset: order.imageAsset,
              fallbackLetter: order.clientName.trim().isEmpty
                  ? 'C'
                  : order.clientName.trim()[0].toUpperCase(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          order.clientName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.blackCat,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _HistoryStatusChip(status: order.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.blackCat,
                      fontWeight: FontWeight.w400,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    order.statusText,
                    style: TextStyle(
                      color: AppColors.blackCat.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w400,
                      fontSize: 13.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({this.imageAsset, required this.fallbackLetter});
  final String? imageAsset;
  final String fallbackLetter;
  static const double _thumbSize = 56;
  static const int _thumbDecode = 256;

  String _normalizeImagePath(String raw) {
    var p = raw.trim();
    if (p.isEmpty) return '';
    if (p.startsWith('assets/')) {
      final rest = p.substring('assets/'.length);
      final decodedRest = Uri.decodeFull(rest);
      if (rest.startsWith('data:') ||
          rest.startsWith('blob:') ||
          decodedRest.startsWith('data:') ||
          decodedRest.startsWith('blob:') ||
          decodedRest.startsWith('http://') ||
          decodedRest.startsWith('https://')) {
        p = decodedRest;
      }
    }
    if (p.startsWith('data%3A') ||
        p.startsWith('blob%3A') ||
        p.startsWith('http%3A') ||
        p.startsWith('https%3A')) {
      p = Uri.decodeFull(p);
    }
    return p;
  }

  @override
  Widget build(BuildContext context) {
    final raw = imageAsset?.trim().isNotEmpty == true ? imageAsset!.trim() : '';
    final p = _normalizeImagePath(raw);

    final isNetwork = p.startsWith('http://') || p.startsWith('https://');
    final isAsset = p.startsWith('assets/');
    final isFileUri = p.startsWith('file://');
    final isFilePath = !kIsWeb && (p.startsWith('/') || p.contains(':\\'));

    Widget fallback() => Container(
      height: _thumbSize,
      width: _thumbSize,
      decoration: BoxDecoration(
        color: AppColors.balletSlippers,
        borderRadius: BorderRadius.zero,
      ),
      alignment: Alignment.center,
      child: Text(
        fallbackLetter.trim().isEmpty ? 'C' : fallbackLetter.trim(),
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 20,
          color: AppColors.blackCat,
        ),
      ),
    );

    Widget image;
    if (isNetwork || (kIsWeb && !isAsset)) {
      image = Image.network(
        p,
        height: _thumbSize,
        width: _thumbSize,
        fit: BoxFit.cover,
        cacheWidth: _thumbDecode,
        cacheHeight: _thumbDecode,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, _, _) => fallback(),
      );
    } else if (isAsset) {
      image = Image.asset(
        p,
        height: _thumbSize,
        width: _thumbSize,
        fit: BoxFit.cover,
        cacheWidth: _thumbDecode,
        cacheHeight: _thumbDecode,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, _, _) => fallback(),
      );
    } else if (isFileUri || isFilePath) {
      final localPath = isFileUri ? p.replaceFirst('file://', '') : p;
      image = Image.file(
        File(localPath),
        height: _thumbSize,
        width: _thumbSize,
        fit: BoxFit.cover,
        cacheWidth: _thumbDecode,
        cacheHeight: _thumbDecode,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, _, _) => fallback(),
      );
    } else {
      image = FutureBuilder<String>(
        future: StorageUrlResolver.resolve(p).then((v) => v ?? ''),
        builder: (_, snap) {
          final url = (snap.data ?? '').trim();
          if (url.isEmpty) return fallback();
          return Image.network(
            url,
            height: _thumbSize,
            width: _thumbSize,
            fit: BoxFit.cover,
            cacheWidth: _thumbDecode,
            cacheHeight: _thumbDecode,
            filterQuality: FilterQuality.low,
            errorBuilder: (_, _, _) => fallback(),
          );
        },
      );
    }

    return ClipRRect(borderRadius: BorderRadius.zero, child: image);
  }
}

class _HistoryStatusChip extends StatelessWidget {
  const _HistoryStatusChip({required this.status});
  final ArtistOrderLiteStatus status;

  @override
  Widget build(BuildContext context) {
    late String text;

    switch (status) {
      case ArtistOrderLiteStatus.delivered:
        text = 'Delivered';
        break;
      case ArtistOrderLiteStatus.declined:
        text = 'Declined';
        break;
      case ArtistOrderLiteStatus.expired:
        text = 'Expired';
        break;
      case ArtistOrderLiteStatus.cancelled:
        text = 'Cancelled';
        break;
    }

    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 14,
        color: AppColors.blackCat,
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.blackCat.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

// Kept for compatibility with any existing imports/usages.
enum ArtistOrderLiteStatus { delivered, declined, expired, cancelled }

@immutable
class ArtistOrderLite {
  final String id;
  final String clientName;
  final String title;
  final String subtitle;
  final ArtistOrderLiteStatus status;
  final String statusText;
  final String? imageAsset;

  final int budgetMin;
  final int budgetMax;
  final String? carrier;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;

  final List<String> clientPhotos;
  final List<String> artistPhotos;
  final bool isBrandRequest;

  const ArtistOrderLite({
    required this.id,
    required this.clientName,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.statusText,
    this.imageAsset,
    required this.budgetMin,
    required this.budgetMax,
    this.carrier,
    this.shippedAt,
    this.deliveredAt,
    this.clientPhotos = const [],
    this.artistPhotos = const [],
    this.isBrandRequest = false,
  });
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({
    required this.title,
    required this.requests,
    required this.byId,
    required this.onTap,
  });

  final String title;
  final List<ClientRequestV2> requests;
  final Map<String, ArtistOrderLite> byId;
  final ValueChanged<ClientRequestV2> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title (${requests.length})',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: AppColors.blackCat,
          ),
        ),
        const SizedBox(height: 10),
        if (requests.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'No $title found.',
              style: TextStyle(
                color: AppColors.blackCat.withValues(alpha: 0.55),
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          )
        else
          ...requests.map((r) {
            final lite = byId[r.id];
            if (lite == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _HistoryCard(order: lite, onTap: () => onTap(r)),
            );
          }),
      ],
    );
  }
}

enum _HeaderAvatarAction {
  profile,
  history,
  calendar,
  artist,
  reviews,
  signOut,
}

class _HeaderMenuRow extends StatelessWidget {
  const _HeaderMenuRow({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color ?? AppColors.blackCat),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: color ?? AppColors.blackCat,
          ),
        ),
      ],
    );
  }
}
