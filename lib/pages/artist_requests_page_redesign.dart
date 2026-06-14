import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../theme/app_colors.dart';
import 'artist_accepted_request_sheet.dart';
import 'artist_designing_request_sheet.dart';
import '../models/client_request_v2.dart';
import 'artist_completed_request_sheet.dart';
import 'artist_shipped_request_sheet.dart';
import 'simple_status_request_sheet.dart';
import 'client_request_details_page.dart';
import '../services/artist_requests_repository.dart';
import '../services/ascension_service.dart';
import '../services/notifications_service.dart';
import '../services/shipping_qr_helper.dart';
import '../services/supabase_firebase_compat.dart';
import 'artist_profile_page.dart';
import 'artist_inbox_page.dart';
import 'artist_reviews_page.dart';
import 'notifications_page.dart';
import '../utils/scenario_4_1.dart';
import '../utils/scenario_4_3.dart';
import '../widgets/artist_profile_avatar_icon.dart';
import '../widgets/notification_bell_button.dart';
import '../widgets/company_client_request_card.dart';

double _reqScale(BuildContext context) {
  final w = MediaQuery.of(context).size.width;
  if (w < 360) return 0.85;
  if (w < 390) return 0.9;
  return 0.95; // slightly smaller even on normal phones
}

bool shouldShowScenario21ToArtist({
  required bool clientAccepted,
  required bool isDirectRequest,
  required String selectedArtistEmail,
  required String viewerArtistEmail,
}) {
  if (!clientAccepted) return false;
  if (!isDirectRequest) return true;
  final selected = selectedArtistEmail.trim().toLowerCase();
  final viewer = viewerArtistEmail.trim().toLowerCase();
  if (selected.isEmpty || viewer.isEmpty) return false;
  return selected == viewer;
}

bool shouldShowScenario31ToArtistPool({
  required bool clientAccepted,
  required String requestStatus,
  required String acceptedByArtistEmail,
  required String viewerArtistEmail,
}) {
  if (!clientAccepted) return false;
  final normalizedStatus = requestStatus.trim().toLowerCase();
  final owner = acceptedByArtistEmail.trim().toLowerCase();
  final viewer = viewerArtistEmail.trim().toLowerCase();
  if (owner.isNotEmpty) return owner == viewer;
  return normalizedStatus == 'in_review' || normalizedStatus == 'pending';
}

/// ----------------------------------------------
/// Redesigned Artist Requests Page (UI v2)
/// - Search bar
/// - Filters: Direct / Inspo only
/// - Budget preset from profile (editable + range)
/// - Shipping time filter (estimator stub: uses client+artist location fields)
/// - Sort: Newest / Soonest needed / Higher budget
/// - Tabs: In Review, Designing, Completed, Shipped
/// ----------------------------------------------
class ArtistRequestsPageRedesign extends StatefulWidget {
  const ArtistRequestsPageRedesign({
    super.key,
    this.initialBudgetMin = 15,
    this.initialBudgetMax = 5000,
    this.artistLocation = '',
    this.showBottomNav = false,
    this.bottomNavIndex = 2,
    this.onNavTap,
    this.onOpenNotifications,
    this.onManageProfile,
    this.onOpenInbox,
    this.onOpenHistory,
    this.onOpenCalendar,
    this.onOpenArtist,
    this.onSignOut,
    this.clientArtistMenuStyle = false,
    this.showProfileMenuItem = false,
    this.showOnlyCurrentClientRequests = false,
    this.showOnlyCompanyRequests = false,
  });

  final int initialBudgetMin;
  final int initialBudgetMax;

  /// Used by shipping estimator when available.
  final String artistLocation;
  final bool showBottomNav;
  final int bottomNavIndex;
  final ValueChanged<int>? onNavTap;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onManageProfile;
  final VoidCallback? onOpenInbox;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenArtist;
  final VoidCallback? onSignOut;
  final bool clientArtistMenuStyle;
  final bool showProfileMenuItem;
  final bool showOnlyCurrentClientRequests;
  final bool showOnlyCompanyRequests;

  @override
  State<ArtistRequestsPageRedesign> createState() =>
      _ArtistRequestsPageRedesignState();
}

class _ArtistRequestsPageRedesignState extends State<ArtistRequestsPageRedesign>
    with SingleTickerProviderStateMixin {
  static const int _realtimeWatchLimitPerCollection = 8;

  // Search + sort
  final _searchCtrl = TextEditingController();
  String _sort = 'Newest';

  // Toggle filters
  final bool _inspoOnly = false;
  bool _directOnly = false;
  bool _groupOnly = false;
  final LayerLink _budgetLink = LayerLink();
  final LayerLink _shipLink = LayerLink();

  OverlayEntry? _dropdownEntry;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _clientRequestsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _companyRequestsSub;

  void _closeDropdown() {
    _dropdownEntry?.remove();
    _dropdownEntry = null;
  }

  // Budget
  late RangeValues _budgetRange;
  late final TextEditingController _budgetMinCtrl;
  late final TextEditingController _budgetMaxCtrl;
  final GlobalKey _budgetKey = GlobalKey();
  final GlobalKey _shipKey = GlobalKey();
  // Shipping time filter
  ShipTimeFilter _shipFilter = ShipTimeFilter.any;

  // Tabs (8 statuses)
  late final TabController _tabCtrl;

  bool _isLoadingDb = false;
  bool _loadRequestsInFlight = false;
  bool _hasLoadedRequests = false;
  bool _initialLoadScheduled = false;
  bool _realtimeBound = false;
  final List<ClientRequestV2> _all = [];
  String _currentArtistNameLower = '';
  String _currentArtistDisplayNameLower = '';
  String _currentArtistEmailLocalLower = '';
  bool _currentArtistIsLicensed = true;
  bool _currentArtistBrandEligible = false;
  TextStyle _t(
    double size, {
    FontWeight w = FontWeight.w700,
    Color? c,
    double? h,
  }) {
    final s = _reqScale(context);
    return TextStyle(
      fontSize: (size + 2) * s,
      fontWeight: w,
      color: c ?? AppColors.blackCat.withOpacity(0.90),
      height: h,
    );
  }

  int _countForAllActive() {
    return _all
        .where(
          (r) =>
              r.status != RequestStatusV2.delivered &&
              r.status != RequestStatusV2.declined &&
              r.status != RequestStatusV2.expired &&
              r.status != RequestStatusV2.cancelled,
        )
        .where(_applySharedFilters)
        .length;
  }

  int _countForStatus(RequestStatusV2 status) {
    return _all
        .where((r) => r.status == status)
        .where(_applySharedFilters)
        .length;
  }

  int _countForDesigningTab() {
    return _all
        .where(
          (r) =>
              r.status == RequestStatusV2.designing ||
              r.status == RequestStatusV2.accepted,
        )
        .where(_applySharedFilters)
        .length;
  }

  bool _matchesSearch(ClientRequestV2 r) {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    return r.clientName.toLowerCase().contains(q) ||
        r.title.toLowerCase().contains(q) ||
        r.subtitle.toLowerCase().contains(q) ||
        r.id.toLowerCase().contains(q);
  }

  bool _matchesDirect(ClientRequestV2 r) => !_directOnly || r.isDirectRequest;

  bool _matchesInspo(ClientRequestV2 r) =>
      !_inspoOnly || r.hasInspo || r.clientImages.isNotEmpty;
  bool _matchesGroup(ClientRequestV2 r) =>
      !_groupOnly || r.orderType == RequestOrderTypeV2.group;
  bool _matchesBudget(ClientRequestV2 r) {
    final minBudget = _budgetRange.start.round();
    final maxBudget = _budgetRange.end.round();
    final normalizedMin = r.budgetMin <= r.budgetMax
        ? r.budgetMin
        : r.budgetMax;
    final normalizedMax = r.budgetMin <= r.budgetMax
        ? r.budgetMax
        : r.budgetMin;
    return normalizedMax >= minBudget && normalizedMin <= maxBudget;
  }

  bool _matchesShipTime(ClientRequestV2 r) {
    return true;
  }

  bool get _hasActiveFilters {
    final minPreset = widget.initialBudgetMin.clamp(15, 5000);
    final maxPreset = widget.initialBudgetMax.clamp(15, 5000);
    final defaultStart = minPreset <= maxPreset ? minPreset : maxPreset;
    final defaultEnd = minPreset <= maxPreset ? maxPreset : minPreset;
    final budgetChanged =
        _budgetRange.start.round() != defaultStart ||
        _budgetRange.end.round() != defaultEnd;
    return _directOnly || _groupOnly || budgetChanged || _sort != 'Newest';
  }

  void _clearFilters() {
    final minPreset = widget.initialBudgetMin.clamp(15, 5000);
    final maxPreset = widget.initialBudgetMax.clamp(15, 5000);
    final start = minPreset <= maxPreset ? minPreset : maxPreset;
    final end = minPreset <= maxPreset ? maxPreset : minPreset;
    setState(() {
      _directOnly = false;
      _groupOnly = false;
      _budgetRange = RangeValues(start.toDouble(), end.toDouble());
      _budgetMinCtrl.text = start.toString();
      _budgetMaxCtrl.text = end.toString();
      _sort = 'Newest';
      _shipFilter = ShipTimeFilter.any;
    });
  }

  bool _applySharedFilters(ClientRequestV2 r) {
    return _matchesSearch(r) &&
        _matchesDirect(r) &&
        _matchesGroup(r) &&
        _matchesBudget(r) &&
        _matchesShipTime(r);
  }

  @override
  void initState() {
    super.initState();

    _tabCtrl = TabController(length: 5, vsync: this);

    final minPreset = widget.initialBudgetMin.clamp(15, 5000);
    final maxPreset = widget.initialBudgetMax.clamp(15, 5000);
    final start = minPreset <= maxPreset ? minPreset : maxPreset;
    final end = minPreset <= maxPreset ? maxPreset : minPreset;

    _budgetRange = RangeValues(start.toDouble(), end.toDouble());
    _budgetMinCtrl = TextEditingController(text: start.toString());
    _budgetMaxCtrl = TextEditingController(text: end.toString());
    if (!widget.showOnlyCurrentClientRequests) {
      unawaited(_loadCurrentArtistIdentity());
    }
    // Load on explicit user action to avoid startup OOM from large legacy docs.
  }

  Future<void> _loadCurrentArtistIdentity() async {
    final email = (FirebaseAuth.instance.currentUser?.email ?? '')
        .trim()
        .toLowerCase();
    _currentArtistDisplayNameLower =
        (FirebaseAuth.instance.currentUser?.displayName ?? '')
            .trim()
            .toLowerCase();
    _currentArtistEmailLocalLower = email.contains('@')
        ? email.split('@').first.trim().toLowerCase()
        : '';
    if (email.isEmpty) return;

    String readName(Map<String, dynamic> data) {
      final profile =
          (data['profile'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final candidates = <Object?>[
        data['name'],
        data['displayName'],
        profile['name'],
        profile['displayName'],
      ];
      for (final raw in candidates) {
        final v = (raw ?? '').toString().trim();
        if (v.isNotEmpty) return v.toLowerCase();
      }
      return '';
    }

    bool readIsLicensed(Map<String, dynamic> data) {
      String pullNailTechType() {
        final profile =
            (data['profile'] as Map<String, dynamic>?) ??
            const <String, dynamic>{};
        final credentials =
            (data['credentials'] as Map<String, dynamic>?) ??
            const <String, dynamic>{};
        final nestedCredentials =
            (profile['credentials'] as Map<String, dynamic>?) ??
            const <String, dynamic>{};
        final candidateValues = <Object?>[
          credentials['nailTechType'],
          nestedCredentials['nailTechType'],
          profile['nailTechType'],
          data['panel_nailTechType'],
          data['nailTechType'],
          data['credential'],
        ];
        for (final raw in candidateValues) {
          final value = (raw ?? '').toString().trim();
          if (value.isNotEmpty) return value;
        }
        return '';
      }

      final type = pullNailTechType().toLowerCase();
      if (type.isEmpty) return true;
      final isUnlicensed =
          type.contains('student') ||
          type.contains('non-licensed') ||
          type.contains('unlicensed');
      return !isUnlicensed;
    }

    bool readBrandEligibility(Map<String, dynamic> data) {
      final ascension =
          (data['ascension'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final profile =
          (data['profile'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final sponsorshipRequest =
          (data['sponsorshipRequest'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final tierCandidates = <Object?>[
        ascension['tier'],
        ascension['levelName'],
        data['sponsorshipTier'],
        sponsorshipRequest['tier'],
        profile['ascensionTier'],
        data['panel_ascensionLevel'],
      ];
      for (final raw in tierCandidates) {
        final tier = (raw ?? '').toString().trim().toLowerCase();
        if (tier == 'goldsmith' || tier == 'crowned') return true;
      }
      final sponsorshipEligible = ascension['sponsorshipEligible'];
      if (sponsorshipEligible is bool) return sponsorshipEligible;
      final pointsRaw =
          ascension['points'] ??
          data['panel_ascensionPoints'] ??
          data['ascensionPoints'];
      final points = pointsRaw is num
          ? pointsRaw.toInt()
          : int.tryParse((pointsRaw ?? '').toString()) ?? 0;
      return points >= AscensionService.goldsmithMin;
    }

    for (final collection in const <String>['artist', 'client_artist']) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection(collection)
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          final doc = snap.docs.first;
          final artistData = doc.data();
          _currentArtistNameLower = readName(artistData);
          _currentArtistIsLicensed = readIsLicensed(artistData);
          _currentArtistBrandEligible = readBrandEligibility(artistData);
          unawaited(
            _syncAscensionForArtistDoc(
              doc.reference,
              artistEmail: email,
              currentData: artistData,
            ),
          );
          break;
        }
      } catch (_) {}
    }
    if (mounted) {
      await _loadRequestsFromDb();
    }
  }

  Future<void> _syncAscensionForArtistDoc(
    DocumentReference<Map<String, dynamic>> ref, {
    required String artistEmail,
    required Map<String, dynamic> currentData,
  }) async {
    try {
      final previousPointsRaw =
          (currentData['ascension'] as Map<String, dynamic>?)?['points'];
      final previousPoints = previousPointsRaw is num
          ? previousPointsRaw.toInt()
          : int.tryParse((previousPointsRaw ?? '').toString()) ?? 0;
      final portfolioUploads =
          (currentData['portfolioItems'] as List<dynamic>?)?.length ??
          (currentData['portfolioImages'] as List<dynamic>?)?.length ??
          0;
      final snapshot = await AscensionService.calculateForArtist(
        db: FirebaseFirestore.instance,
        artistEmail: artistEmail,
        portfolioUploads: portfolioUploads,
      );
      if (!mounted) return;
      setState(() {
        _currentArtistBrandEligible = snapshot.sponsorshipEligible;
      });
      final computedPayload = AscensionService.buildAscensionPayload(snapshot);
      final override = await AscensionService.readActiveOverride(
        db: FirebaseFirestore.instance,
        artistDocPath: ref.path,
        artistEmail: artistEmail,
      );
      final finalPayload = AscensionService.applyOverrideToPayload(
        payload: computedPayload,
        override: override,
      );
      final stabilizedPayload = AscensionService.preserveExistingAdminOverride(
        payload: finalPayload,
        artistData: currentData,
      );
      final finalPoints = (stabilizedPayload['points'] is num)
          ? (stabilizedPayload['points'] as num).toInt()
          : snapshot.points;
      final finalLevel = (stabilizedPayload['levelName'] ?? snapshot.level)
          .toString();
      final finalEligibility = stabilizedPayload['sponsorshipEligible'] == true;
      if (mounted) {
        setState(() {
          _currentArtistBrandEligible = finalEligibility;
        });
      }
      await ref.set({
        'ascension': stabilizedPayload,
        'panel_ascensionPoints': finalPoints,
        'panel_ascensionLevel': finalLevel,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await AscensionService.persistAdminCollections(
        db: FirebaseFirestore.instance,
        artistRef: ref,
        artistEmail: artistEmail,
        artistName: _currentArtistNameLower,
        ascensionPayload: stabilizedPayload,
        previousPoints: previousPoints,
      );
    } catch (_) {}
  }

  Future<void> _syncAscensionForCurrentArtist() async {
    final email = (FirebaseAuth.instance.currentUser?.email ?? '')
        .trim()
        .toLowerCase();
    if (email.isEmpty) return;

    for (final collection in const <String>['artist', 'client_artist']) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection(collection)
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (snap.docs.isEmpty) continue;
        final doc = snap.docs.first;
        await _syncAscensionForArtistDoc(
          doc.reference,
          artistEmail: email,
          currentData: doc.data(),
        );
        return;
      } catch (_) {}
    }
  }

  void _listenClientRequestsRealtime() {
    _clientRequestsSub?.cancel();
    _companyRequestsSub?.cancel();
    _clientRequestsSub = FirebaseFirestore.instance
        .collection('Client_Custom_Requests')
        .limit(_realtimeWatchLimitPerCollection)
        .snapshots()
        .listen((snapshot) {
          unawaited(_handlePaidStatusNotifications(snapshot));
          _loadRequestsFromDb();
        });
    _companyRequestsSub = FirebaseFirestore.instance
        .collection('Company_Custom_Requests')
        .limit(_realtimeWatchLimitPerCollection)
        .snapshots()
        .listen((_) {
          _loadRequestsFromDb();
        });
  }

  Future<void> _handlePaidStatusNotifications(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    final artistEmail = (FirebaseAuth.instance.currentUser?.email ?? '')
        .trim()
        .toLowerCase();
    if (artistEmail.isEmpty) return;

    for (final change in snapshot.docChanges) {
      if (change.type != DocumentChangeType.modified) continue;
      final data = change.doc.data();
      if (data == null) continue;

      final paymentStatus = ((data['paymentStatus'] ?? '') as Object)
          .toString()
          .trim()
          .toLowerCase();
      if (paymentStatus != 'paid') continue;
      final currentStatus = ((data['status'] ?? '') as Object)
          .toString()
          .trim()
          .toLowerCase();
      if (currentStatus != 'accepted') continue;

      final acceptedBy = ((data['acceptedByArtistEmail'] ?? '') as Object)
          .toString()
          .trim()
          .toLowerCase();
      if (acceptedBy != artistEmail) continue;

      if (data['paymentNotifiedArtist'] == true) continue;

      final docRef = change.doc.reference;
      final orderNumber = ((data['orderNumber'] ?? '') as Object).toString();

      await NotificationsService.createUserNotification(
        receiverEmail: artistEmail,
        title: 'Payment Done',
        body: orderNumber.trim().isEmpty
            ? 'Client completed payment for your accepted request.'
            : 'Payment completed for order $orderNumber.',
        type: 'payment_done',
        orderId: change.doc.id,
        orderNumber: orderNumber,
        sourceCollection: 'Client_Custom_Requests',
      );

      final batch = FirebaseFirestore.instance.batch();
      batch.set(docRef, {
        'status': 'designing',
        'paymentNotifiedArtist': true,
        'paymentNotifiedArtistAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.set(docRef.collection('details').doc('payload'), {
        'status': 'designing',
      }, SetOptions(merge: true));
      await batch.commit();
    }
  }

  Future<void> _loadRequestsFromDb() async {
    if (_loadRequestsInFlight) return;
    _loadRequestsInFlight = true;
    if (!_realtimeBound) {
      _listenClientRequestsRealtime();
      _realtimeBound = true;
    }
    if (mounted && !_isLoadingDb) {
      setState(() => _isLoadingDb = true);
    }
    try {
      final dbRequests = await ArtistRequestsRepository.fetchActiveRequests();
      final hydratedRequests = await _expireCompanyPoolRequestsIfNeeded(
        dbRequests,
      );
      final currentArtistEmail =
          (FirebaseAuth.instance.currentUser?.email ?? '').trim().toLowerCase();
      final currentClientEmail =
          (FirebaseAuth.instance.currentUser?.email ?? '').trim().toLowerCase();
      if (!mounted) return;

      setState(() {
        _all
          ..clear()
          ..addAll(
            hydratedRequests.where((r) {
              if (widget.showOnlyCompanyRequests &&
                  r.sourceCollection != 'Company_Custom_Requests') {
                return false;
              }
              if (widget.showOnlyCurrentClientRequests) {
                return _isVisibleToCurrentClient(
                  request: r,
                  clientEmail: currentClientEmail,
                );
              }
              if (widget.showOnlyCompanyRequests) {
                return _isVisibleInCompanyClientPool(
                  request: r,
                  clientEmail: currentClientEmail,
                );
              }
              return _isVisibleToArtist(
                request: r,
                artistEmail: currentArtistEmail,
              );
            }),
          );
        _isLoadingDb = false;
        _hasLoadedRequests = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingDb = false);
    } finally {
      _loadRequestsInFlight = false;
    }
  }

  Future<List<ClientRequestV2>> _expireCompanyPoolRequestsIfNeeded(
    List<ClientRequestV2> requests,
  ) async {
    final now = DateTime.now();
    final updated = <ClientRequestV2>[];

    for (final request in requests) {
      final shouldExpire =
          request.sourceCollection == 'Company_Custom_Requests' &&
          request.acceptedByArtistEmail.trim().isEmpty &&
          request.status != RequestStatusV2.expired &&
          request.status != RequestStatusV2.cancelled &&
          request.status != RequestStatusV2.declined &&
          request.status != RequestStatusV2.delivered &&
          request.status != RequestStatusV2.shipped &&
          now.isAfter(
            DateTime(
              request.neededBy.year,
              request.neededBy.month,
              request.neededBy.day,
            ).add(const Duration(days: 1)),
          );

      if (!shouldExpire) {
        updated.add(request);
        continue;
      }

      try {
        final docRef = FirebaseFirestore.instance
            .collection(request.sourceCollection)
            .doc(request.id);
        final batch = FirebaseFirestore.instance.batch();
        batch.set(docRef, {
          'status': 'expired',
          'expiredAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        batch.set(docRef.collection('details').doc('payload'), {
          'status': 'expired',
          'expiredAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await batch.commit();
        updated.add(request.copyWith(status: RequestStatusV2.expired));
      } catch (_) {
        updated.add(request);
      }
    }

    return updated;
  }

  @override
  void dispose() {
    _closeDropdown();
    _clientRequestsSub?.cancel();
    _companyRequestsSub?.cancel();
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    _budgetMinCtrl.dispose();
    _budgetMaxCtrl.dispose();
    super.dispose();
  }

  bool _isVisibleToArtist({
    required ClientRequestV2 request,
    required String artistEmail,
  }) {
    final isCompanyRequest =
        request.sourceCollection == 'Company_Custom_Requests';
    final hasClientAccepted = request.acceptedByClientEmail.trim().isNotEmpty;
    if (isCompanyRequest &&
        !shouldShowScenario41ToDirectArtist(
          clientAccepted: hasClientAccepted,
          isDirectRequest: request.isDirectRequest,
          selectedArtistEmail: request.selectedArtistEmail,
          acceptedByArtistEmail: request.acceptedByArtistEmail,
          viewerArtistEmail: artistEmail,
        )) {
      return false;
    }
    if (isCompanyRequest &&
        request.status == RequestStatusV2.inReview &&
        !_currentArtistBrandEligible) {
      return false;
    }

    final ownedBy = request.acceptedByArtistEmail.trim().toLowerCase();
    final isOwnedByCurrentArtist =
        artistEmail.isNotEmpty && ownedBy == artistEmail;
    final declinedByCurrentArtist =
        artistEmail.isNotEmpty &&
        request.declinedByArtistEmails.contains(artistEmail);

    bool matchesSelectedArtistName() {
      final selected = request.selectedArtist.trim().toLowerCase();
      if (selected.isEmpty) return false;
      return selected == _currentArtistNameLower ||
          selected == _currentArtistDisplayNameLower ||
          selected == _currentArtistEmailLocalLower;
    }

    bool isCurrentArtistDirectTarget() {
      final directTargetEmail = request.selectedArtistEmail
          .trim()
          .toLowerCase();
      if (directTargetEmail.isNotEmpty && artistEmail.isNotEmpty) {
        return directTargetEmail == artistEmail;
      }
      return matchesSelectedArtistName();
    }

    switch (request.status) {
      case RequestStatusV2.inReview:
        final isBrandGroupOrder =
            request.sourceCollection == 'Company_Custom_Requests' &&
            request.orderType == RequestOrderTypeV2.group;
        if (isBrandGroupOrder && !request.groupClientsAllResponded) {
          return false;
        }
        if (!request.allowNonLicensed && !_currentArtistIsLicensed) {
          return false;
        }
        final hiddenByDirectTarget =
            request.isDirectRequest && !isCurrentArtistDirectTarget();
        return !declinedByCurrentArtist && !hiddenByDirectTarget;
      case RequestStatusV2.accepted:
      case RequestStatusV2.designing:
      case RequestStatusV2.completed:
      case RequestStatusV2.shipped:
      case RequestStatusV2.delivered:
        return ownedBy.isEmpty || isOwnedByCurrentArtist;
      case RequestStatusV2.declined:
      case RequestStatusV2.cancelled:
      case RequestStatusV2.expired:
        return ownedBy.isEmpty || isOwnedByCurrentArtist;
    }
  }

  bool _isVisibleToCurrentClient({
    required ClientRequestV2 request,
    required String clientEmail,
  }) {
    final email = clientEmail.trim().toLowerCase();
    if (email.isEmpty) return false;
    return request.clientEmail.trim().toLowerCase() == email;
  }

  bool _isVisibleInCompanyClientPool({
    required ClientRequestV2 request,
    required String clientEmail,
  }) {
    final viewerEmail = clientEmail.trim().toLowerCase();
    final acceptedByClient = request.acceptedByClientEmail.trim().toLowerCase();
    final declinedByClient = request.declinedByClientEmails
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    final selectedClientEmail = request.selectedClientEmail
        .trim()
        .toLowerCase();
    final selectedGroupClientEmails = request.selectedGroupClientEmails
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    final isPoolOpen = request.openToClientPool;

    // Once accepted by any client, it should move to Orders and leave Requests.
    if (acceptedByClient.isNotEmpty) return false;

    if (!isPoolOpen) {
      if (viewerEmail.isEmpty) return false;
      if (request.orderType == RequestOrderTypeV2.group) {
        return selectedGroupClientEmails.contains(viewerEmail);
      }
      if (selectedClientEmail.isEmpty) return false;
      return selectedClientEmail == viewerEmail;
    }

    if (request.status == RequestStatusV2.inReview) {
      if (declinedByClient.contains(viewerEmail)) return false;
      return true;
    }
    return false;
  }

  // ----------------------------
  // Filtering + sorting
  // ----------------------------
  List<ClientRequestV2> _filteredForTab(int tabIndex) {
    bool isActiveTab(ClientRequestV2 r) {
      // ✅ ALL = everything EXCEPT Delivered/Declined/Expired/Cancelled
      if (tabIndex == 0) {
        return r.status != RequestStatusV2.delivered &&
            r.status != RequestStatusV2.declined &&
            r.status != RequestStatusV2.expired &&
            r.status != RequestStatusV2.cancelled;
      }

      // ✅ Other tabs
      if (tabIndex == 1) return r.status == RequestStatusV2.inReview;
      if (tabIndex == 2) {
        return r.status == RequestStatusV2.designing ||
            r.status == RequestStatusV2.accepted;
      }
      if (tabIndex == 3) return r.status == RequestStatusV2.completed;
      if (tabIndex == 4) return r.status == RequestStatusV2.shipped;

      return false;
    }

    final list = _all.where(isActiveTab).where(_applySharedFilters).toList();

    // Sort
    if (_sort == 'Newest') {
      list.sort((a, b) => b.neededBy.compareTo(a.neededBy));
    } else if (_sort == 'Soonest needed') {
      list.sort((a, b) => a.neededBy.compareTo(b.neededBy));
    } else if (_sort == 'Higher budget') {
      list.sort((a, b) => b.budgetMax.compareTo(a.budgetMax));
    }

    return list;
  }

  // ----------------------------
  // Shipping estimator (stub)
  // Replace this with real geo logic later:
  // - distance between artist and client
  // - carrier SLA based on distance
  // ----------------------------
  int _estimateShipDays({
    required String artistLocation,
    required String clientLocation,
  }) {
    // Very small heuristic just to behave realistically:
    final a = artistLocation.toLowerCase();
    final c = clientLocation.toLowerCase();

    // same state-ish hint => faster
    if ((a.contains('ca') && c.contains('ca')) ||
        (a.contains('los') && c.contains('san'))) {
      return 2;
    }
    // nearby southwest-ish
    if ((a.contains('ca') && (c.contains('az') || c.contains('nv')))) {
      return 3;
    }
    return 5;
  }

  void _syncBudgetFromText() {
    final min =
        int.tryParse(_budgetMinCtrl.text.trim()) ?? _budgetRange.start.round();
    final max =
        int.tryParse(_budgetMaxCtrl.text.trim()) ?? _budgetRange.end.round();
    final a = min.clamp(15, 5000).toDouble();
    final b = max.clamp(15, 5000).toDouble();
    final start = a <= b ? a : b;
    final end = a <= b ? b : a;
    setState(() => _budgetRange = RangeValues(start, end));
  }

  // ----------------------------
  // Header actions (same as others)
  // ----------------------------
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
            const ArtistProfilePage(showBottomNav: true, bottomNavIndex: 1),
      ),
    );
  }

  void _openInbox() {
    if (widget.onOpenInbox != null) {
      widget.onOpenInbox!.call();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ArtistInboxPage()),
    );
  }

  void _openHistory() {
    if (widget.onOpenHistory != null) {
      widget.onOpenHistory!.call();
    }
  }

  void _openCalendar() {
    if (widget.onOpenCalendar != null) {
      widget.onOpenCalendar!.call();
    }
  }

  void _openArtist() {
    if (widget.onOpenArtist != null) {
      widget.onOpenArtist!.call();
    }
  }

  void _openReviews() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ArtistReviewsPage()),
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

  Widget _avatarMenu() {
    return PopupMenuButton<_HeaderAvatarAction>(
      tooltip: '',
      position: PopupMenuPosition.under,
      elevation: 12,
      color: AppColors.snow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      onSelected: (v) {
        switch (v) {
          case _HeaderAvatarAction.profile:
            _openManageProfile();
            break;
          case _HeaderAvatarAction.history:
            _openHistory();
            break;
          case _HeaderAvatarAction.calendar:
            _openCalendar();
            break;
          case _HeaderAvatarAction.artist:
            _openArtist();
            break;
          case _HeaderAvatarAction.reviews:
            _openReviews();
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
      itemBuilder: (_) => [
        if (widget.clientArtistMenuStyle || widget.showProfileMenuItem)
          const PopupMenuItem(
            value: _HeaderAvatarAction.profile,
            child: _HeaderMenuRow(icon: Icons.person_outline, label: 'Profile'),
          ),
        if (widget.clientArtistMenuStyle)
          const PopupMenuItem(
            value: _HeaderAvatarAction.history,
            child: _HeaderMenuRow(icon: Icons.history, label: 'History'),
          ),
        if (widget.clientArtistMenuStyle)
          const PopupMenuItem(
            value: _HeaderAvatarAction.calendar,
            child: _HeaderMenuRow(
              icon: Icons.calendar_month_outlined,
              label: 'Calendar',
            ),
          ),
        if (widget.clientArtistMenuStyle)
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
        if (widget.clientArtistMenuStyle || widget.showProfileMenuItem)
          const PopupMenuDivider(),
        PopupMenuItem(
          value: _HeaderAvatarAction.signOut,
          child: _HeaderMenuRow(
            icon: Icons.logout_rounded,
            label: 'Logout',
            color: widget.clientArtistMenuStyle ? AppColors.blackCat : null,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _reqScale(context);
    return Scaffold(
      backgroundColor: AppColors.snow,

      // HEADER (same style as your other pages)
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

      body: Column(
        children: [
          // Top controls area
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Column(
              children: [
                if (!widget.showOnlyCompanyRequests) _searchWithFilterButton(),
                if (!widget.showOnlyCompanyRequests) ...[
                  const SizedBox(height: 12),
                  // Status tabs
                  _statusTabs(),
                ],
              ],
            ),
          ),

          if (widget.showOnlyCompanyRequests)
            Expanded(child: _tabList(0))
          else
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                // OLD
                // children: List.generate(8, (i) => _tabList(i)),

                // NEW
                children: List.generate(5, (i) => _tabList(i)),
              ),
            ),
        ],
      ),
      bottomNavigationBar: widget.showBottomNav
          ? BottomNavigationBar(
              currentIndex: widget.bottomNavIndex,
              selectedItemColor: AppColors.deepPlum,
              unselectedItemColor: Colors.black.withOpacity(0.35),
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

  // ----------------------------
  // UI components
  // ----------------------------
  Widget _searchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.blackCat.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        style: _t(13, w: FontWeight.w800, c: Colors.black.withOpacity(0.9)),
        controller: _searchCtrl,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Search by client, title, ID',
          hintStyle: _t(
            12,
            w: FontWeight.w400,
            c: AppColors.blackCat.withOpacity(0.45),
          ),
          prefixIcon: Icon(
            Icons.search,
            color: AppColors.blackCat.withOpacity(0.45),
            size: 18,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ), // was 14
        ),
      ),
    );
  }

  Widget _searchWithFilterButton() {
    return Row(
      children: [
        Expanded(child: _searchBar()),
        const SizedBox(width: 10),
        InkWell(
          borderRadius: BorderRadius.zero,
          onTap: _openFiltersModal,
          child: Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: _hasActiveFilters
                  ? AppColors.alabaster.withOpacity(0.75)
                  : AppColors.snow,
              borderRadius: BorderRadius.zero,
              border: Border.all(color: AppColors.blackCatBorderLight),
              boxShadow: [
                BoxShadow(
                  color: AppColors.blackCat.withOpacity(0.03),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.filter_alt_outlined,
                  size: 20,
                  color: AppColors.blackCat.withOpacity(0.75),
                ),
                if (_hasActiveFilters)
                  Positioned(
                    top: 9,
                    right: 9,
                    child: Container(
                      height: 7,
                      width: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.blackCat,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openFiltersModal() async {
    bool directOnly = _directOnly;
    bool groupOnly = _groupOnly;
    RangeValues budgetRange = _budgetRange;
    String sort = _sort;
    final minCtrl = TextEditingController(
      text: budgetRange.start.round().toString(),
    );
    final maxCtrl = TextEditingController(
      text: budgetRange.end.round().toString(),
    );

    RangeValues normalizedBudgetFromText() {
      final min =
          int.tryParse(minCtrl.text.trim()) ?? budgetRange.start.round();
      final max = int.tryParse(maxCtrl.text.trim()) ?? budgetRange.end.round();
      final clampedMin = min.clamp(15, 5000);
      final clampedMax = max.clamp(15, 5000);
      final start = clampedMin <= clampedMax ? clampedMin : clampedMax;
      final end = clampedMin <= clampedMax ? clampedMax : clampedMin;
      return RangeValues(start.toDouble(), end.toDouble());
    }

    void applyTextBudget(StateSetter setModalState) {
      final next = normalizedBudgetFromText();
      setModalState(() {
        budgetRange = next;
      });
    }

    final result = await showDialog<_RequestFilterResult>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: AppColors.snow,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          child: StatefulBuilder(
            builder: (modalContext, setModalState) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.filter_alt_outlined,
                          size: 18,
                          color: AppColors.blackCat,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Filter',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.blackCat,
                            ),
                          ),
                        ),
                        IconButton(
                          color: AppColors.blackCat,
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _filterChip(
                            label: 'Direct Request',
                            icon: Icons.verified_user_outlined,
                            selected: directOnly,
                            onTap: () =>
                                setModalState(() => directOnly = !directOnly),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _filterChip(
                            label: 'Group Order',
                            icon: Icons.attach_file_rounded,
                            selected: groupOnly,
                            onTap: () =>
                                setModalState(() => groupOnly = !groupOnly),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Budget',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.blackCat.withOpacity(0.8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minCtrl,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            style: const TextStyle(
                              color: AppColors.blackCat,
                              fontWeight: FontWeight.w700,
                            ),
                            cursorColor: AppColors.blackCat,
                            decoration: _miniDec(prefix: '\$', hint: 'Min'),
                            onSubmitted: (_) => applyTextBudget(setModalState),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: maxCtrl,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            style: const TextStyle(
                              color: AppColors.blackCat,
                              fontWeight: FontWeight.w700,
                            ),
                            cursorColor: AppColors.blackCat,
                            decoration: _miniDec(prefix: '\$', hint: 'Max'),
                            onSubmitted: (_) => applyTextBudget(setModalState),
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(modalContext).copyWith(
                        activeTrackColor: AppColors.blackCat,
                        inactiveTrackColor: AppColors.blackCat.withOpacity(
                          0.18,
                        ),
                        thumbColor: AppColors.blackCat,
                        overlayColor: Colors.transparent,
                        rangeThumbShape: const RoundRangeSliderThumbShape(
                          enabledThumbRadius: 8,
                        ),
                        valueIndicatorColor: AppColors.blackCat,
                        valueIndicatorTextStyle: const TextStyle(
                          color: AppColors.snow,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: RangeSlider(
                        values: budgetRange,
                        min: 15,
                        max: 5000,
                        divisions: 4985,
                        labels: RangeLabels(
                          '\$${budgetRange.start.round()}',
                          '\$${budgetRange.end.round()}',
                        ),
                        onChanged: (v) {
                          minCtrl.text = v.start.round().toString();
                          maxCtrl.text = v.end.round().toString();
                          setModalState(() {
                            budgetRange = v;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Sort',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.blackCat.withOpacity(0.8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.snow,
                        borderRadius: BorderRadius.zero,
                        border: Border.all(
                          color: AppColors.blackCatBorderLight,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: sort,
                          dropdownColor: AppColors.snow,
                          style: TextStyle(
                            color: AppColors.blackCat,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.blackCat.withOpacity(0.7),
                          ),
                          isExpanded: true,
                          items: [
                            DropdownMenuItem(
                              value: 'Newest',
                              child: Text(
                                'Sort: Newest',
                                style: TextStyle(color: AppColors.blackCat),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Soonest needed',
                              child: Text(
                                'Sort: Soonest needed',
                                style: TextStyle(color: AppColors.blackCat),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Higher budget',
                              child: Text(
                                'Sort: Higher budget',
                                style: TextStyle(color: AppColors.blackCat),
                              ),
                            ),
                          ],
                          onChanged: (v) =>
                              setModalState(() => sort = v ?? 'Newest'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.blackCat.withOpacity(
                                0.16,
                              ),
                              foregroundColor: AppColors.blackCat,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                              side: const BorderSide(
                                color: AppColors.blackCatBorderLight,
                              ),
                              elevation: 0,
                            ),
                            onPressed: () {
                              final minPreset = widget.initialBudgetMin.clamp(
                                20,
                                1500,
                              );
                              final maxPreset = widget.initialBudgetMax.clamp(
                                20,
                                1500,
                              );
                              final start = minPreset <= maxPreset
                                  ? minPreset
                                  : maxPreset;
                              final end = minPreset <= maxPreset
                                  ? maxPreset
                                  : minPreset;
                              minCtrl.text = start.toString();
                              maxCtrl.text = end.toString();
                              setModalState(() {
                                directOnly = false;
                                groupOnly = false;
                                sort = 'Newest';
                                budgetRange = RangeValues(
                                  start.toDouble(),
                                  end.toDouble(),
                                );
                              });
                            },
                            child: const Text(
                              'Clear',
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                fontFamily: 'Arial',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.blackCat,
                              foregroundColor: AppColors.snow,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                            ),
                            child: const Text('Apply'),
                            onPressed: () {
                              final normalized = normalizedBudgetFromText();
                              Navigator.pop(
                                dialogContext,
                                _RequestFilterResult(
                                  directOnly: directOnly,
                                  groupOnly: groupOnly,
                                  sort: sort,
                                  budgetRange: normalized,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    minCtrl.dispose();
    maxCtrl.dispose();

    if (result == null || !mounted) return;
    setState(() {
      _directOnly = result.directOnly;
      _groupOnly = result.groupOnly;
      _sort = result.sort;
      _budgetRange = result.budgetRange;
      _budgetMinCtrl.text = result.budgetRange.start.round().toString();
      _budgetMaxCtrl.text = result.budgetRange.end.round().toString();
    });
  }

  Widget _toggleChip({
    required String label,
    required bool value,
    required VoidCallback onTap,
    bool leadingCheck = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.zero,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.snow,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: AppColors.blackCatBorderLight),
          boxShadow: [
            BoxShadow(
              color: AppColors.blackCat.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (leadingCheck) ...[
              Icon(
                value ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 16,
                color: value
                    ? AppColors.blackCat
                    : AppColors.blackCat.withOpacity(0.35),
              ),
              const SizedBox(width: 8),
            ] else ...[
              Icon(
                value ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 16,
                color: value
                    ? AppColors.blackCat
                    : AppColors.blackCat.withOpacity(0.35),
              ),
              const SizedBox(width: 8),
            ],
            Text(label, style: _t(12, w: FontWeight.w400)),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: AppColors.blackCat.withOpacity(0.45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.zero,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.alabaster.withOpacity(0.7)
              : AppColors.snow,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: AppColors.blackCatBorderLight),
          boxShadow: [
            BoxShadow(
              color: AppColors.blackCat.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.blackCat),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.blackCat,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusTab(String label, int count, bool isActive) {
    final s = _reqScale(context);

    final labelColor = AppColors.blackCat;

    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5 * s,
              color: labelColor,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12.5 * s,
              color: AppColors.blackCat,
            ),
          ),
        ],
      ),
    );
  }

  ClientRequestV2 _getById(String id) => _all.firstWhere((e) => e.id == id);

  void _replaceById(String id, ClientRequestV2 updated) {
    final i = _all.indexWhere((e) => e.id == id);
    if (i == -1) return;
    setState(() => _all[i] = updated);
  }

  Future<ClientRequestV2> _hydrateRequestForDetails(
    ClientRequestV2 request,
  ) async {
    try {
      final hydrated = await ArtistRequestsRepository.fetchRequestById(
        sourceCollection: request.sourceCollection,
        requestId: request.id,
      );
      if (hydrated == null) return request;
      if (mounted) _replaceById(request.id, hydrated);
      return hydrated;
    } catch (_) {
      return request;
    }
  }

  void _moveToStatus(String id, RequestStatusV2 status) {
    final r = _getById(id);
    _replaceById(id, r.copyWith(status: status));
  }

  Future<bool> _persistArtistAcceptance(
    ClientRequestV2 request,
    _AcceptResult accepted,
  ) async {
    final total = accepted.yourPrice + accepted.shipping + accepted.extra;
    final normalizedTotal = double.parse(total.toStringAsFixed(2));
    final roundedTotal = normalizedTotal.round();
    Future<bool> persistToDoc(
      DocumentReference<Map<String, dynamic>> docRef,
    ) async {
      final snap = await docRef.get();
      if (!snap.exists) return false;
      final data = snap.data() ?? const <String, dynamic>{};
      final detailSnap = await docRef
          .collection('details')
          .doc('payload')
          .get();
      final detailData = detailSnap.data() ?? const <String, dynamic>{};
      final orderData =
          (detailData['order'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final currentStatus =
          ((data['status'] ?? detailData['status'] ?? '') as Object)
              .toString()
              .trim()
              .toLowerCase();
      final alreadyAcceptedBy = <String>{
        ((data['acceptedByArtistEmail'] ?? '') as Object)
            .toString()
            .trim()
            .toLowerCase(),
        ((orderData['acceptedByArtistEmail'] ?? '') as Object)
            .toString()
            .trim()
            .toLowerCase(),
        (((detailData['acceptance']
                        as Map<String, dynamic>?)?['acceptedByArtistEmail'] ??
                    '')
                as Object)
            .toString()
            .trim()
            .toLowerCase(),
      }..removeWhere((e) => e.isEmpty);
      if (alreadyAcceptedBy.isNotEmpty) {
        return false;
      }
      if (currentStatus == 'designing' ||
          currentStatus == 'completed' ||
          currentStatus == 'shipped' ||
          currentStatus == 'delivered' ||
          currentStatus == 'cancelled' ||
          currentStatus == 'canceled' ||
          currentStatus == 'expired') {
        return false;
      }

      String firstNonEmpty(List<Object?> values) {
        for (final value in values) {
          final text = (value ?? '').toString().trim();
          if (text.isNotEmpty) return text;
        }
        return '';
      }

      final batch = FirebaseFirestore.instance.batch();
      batch.set(docRef, {
        'status': 'designing',
        'updatedAt': FieldValue.serverTimestamp(),
        'artistAcceptedAt': FieldValue.serverTimestamp(),
        'brandStatus': 'in_progress',
        'clientStatus': 'in_progress',
        'artistStatus': 'designing',
        'acceptedByArtistEmail':
            (FirebaseAuth.instance.currentUser?.email ?? '')
                .trim()
                .toLowerCase(),
        'artistFinalAmount': normalizedTotal,
        'paymentStatus': 'pending',
        'paymentLink':
            'jnt://payment?order=${request.id}&collection=${request.sourceCollection}',
        'artistQuote': {
          'yourPrice': accepted.yourPrice,
          'shipping': accepted.shipping,
          'extra': accepted.extra,
          'total': normalizedTotal,
        },
      }, SetOptions(merge: true));

      final detailRef = docRef.collection('details').doc('payload');
      batch.set(detailRef, {
        'artistQuote': {
          'yourPrice': accepted.yourPrice,
          'shipping': accepted.shipping,
          'extra': accepted.extra,
          'total': normalizedTotal,
        },
        'acceptance': {
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
          'acceptedByArtistEmail':
              (FirebaseAuth.instance.currentUser?.email ?? '')
                  .trim()
                  .toLowerCase(),
        },
        'status': 'designing',
        'roleStatuses': {
          'brand': 'in_progress',
          'client': 'in_progress',
          'artist': 'designing',
        },
        'payment': {
          'status': 'pending',
          'paymentLink':
              'jnt://payment?order=${request.id}&collection=${request.sourceCollection}',
          'requestedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));

      await batch.commit();

      final orderNumber = request.orderNumber.trim().isNotEmpty
          ? request.orderNumber.trim()
          : request.id;
      final amountText = '\$${roundedTotal.toString()}';
      final now = DateTime.now();
      final acceptedOn =
          '${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}/${now.year}';
      final artistLabel =
          (FirebaseAuth.instance.currentUser?.displayName ?? '')
              .trim()
              .isNotEmpty
          ? (FirebaseAuth.instance.currentUser!.displayName!).trim()
          : ((FirebaseAuth.instance.currentUser?.email ?? 'artist')
                    .split('@')
                    .first
                    .trim()
                    .isNotEmpty
                ? (FirebaseAuth.instance.currentUser?.email ?? 'artist')
                      .split('@')
                      .first
                      .trim()
                : 'Artist');
      final artistNotifyEmail = (FirebaseAuth.instance.currentUser?.email ?? '')
          .trim()
          .toLowerCase();
      final clientReceiver = firstNonEmpty(<Object?>[
        request.clientEmail,
        data['clientEmail'],
        data['email'],
        data['requesterEmail'],
        data['createdByEmail'],
        orderData['clientEmail'],
        orderData['email'],
        orderData['requesterEmail'],
      ]).toLowerCase();
      if (request.sourceCollection == 'Company_Custom_Requests') {
        final brandName = firstNonEmpty(<Object?>[
          data['companyName'],
          data['brandName'],
          request.clientName,
        ]);
        final campaignName = firstNonEmpty(<Object?>[
          data['campaignName'],
          data['title'],
          request.title,
        ]);
        var acceptedClientName = firstNonEmpty(<Object?>[
          data['acceptedClientName'],
          data['selectedClient'],
          request.selectedClient,
          data['clientName'],
        ]);
        if (acceptedClientName.trim().isEmpty) {
          acceptedClientName = 'Client';
        }
        final acceptedClientEmail = firstNonEmpty(<Object?>[
          data['acceptedByClientEmail'],
          data['clientEmail'],
          request.acceptedByClientEmail,
          clientReceiver,
        ]).toLowerCase();
        final acceptedGroupClientEmails = <String>{
          ...((data['acceptedGroupClientEmails'] as List<dynamic>?) ??
                  const <dynamic>[])
              .whereType<String>()
              .map((e) => e.trim().toLowerCase())
              .where((e) => e.isNotEmpty),
          ...((detailData['acceptedGroupClientEmails'] as List<dynamic>?) ??
                  const <dynamic>[])
              .whereType<String>()
              .map((e) => e.trim().toLowerCase())
              .where((e) => e.isNotEmpty),
        };
        final groupOrderMap =
            (detailData['groupOrder'] as Map<String, dynamic>?) ??
            const <String, dynamic>{};
        final groupClientRaw =
            (groupOrderMap['clients'] as List<dynamic>?) ?? const <dynamic>[];
        final acceptedGroupClientNames = groupClientRaw
            .whereType<Map>()
            .where((raw) {
              final email = (raw['clientEmail'] ?? '')
                  .toString()
                  .trim()
                  .toLowerCase();
              return email.isNotEmpty &&
                  acceptedGroupClientEmails.contains(email);
            })
            .map((raw) => (raw['clientName'] ?? '').toString().trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList(growable: false);
        final isGroupBrandOrder = request.orderType == RequestOrderTypeV2.group;
        final groupClientSummary =
            isGroupBrandOrder && acceptedGroupClientNames.isNotEmpty
            ? acceptedGroupClientNames.join(', ')
            : acceptedClientName;
        final brandRecipientEmails =
            await NotificationsService.resolveBrandRecipientEmails(
              rootData: data,
              detailsData: detailData,
              orderData: orderData,
              excludeEmails: <String>[acceptedClientEmail, artistNotifyEmail],
            );

        for (final brandCompanyEmail in brandRecipientEmails) {
          await NotificationsService.createUserNotification(
            receiverEmail: brandCompanyEmail,
            title: 'Artist Accepted Brand Request',
            body: scenario41BrandReceiveOnArtistAcceptance(
              artistName: artistLabel,
              campaignName: campaignName,
              orderRef: orderNumber,
              clientName: groupClientSummary,
            ),
            type: 'brand_request_accepted_by_artist',
            orderId: request.id,
            orderNumber: orderNumber,
            sourceCollection: request.sourceCollection,
          );
        }
        await NotificationsService.notifyAdmins(
          title: 'Artist Accepted Brand Request',
          body:
              '$artistLabel has accepted $brandName $campaignName brand request $orderNumber for $groupClientSummary.',
          type: 'admin_brand_request_accepted_by_artist',
          orderId: request.id,
          orderNumber: orderNumber,
          sourceCollection: request.sourceCollection,
        );
        final acceptedClientTargets = <String>{
          if (acceptedClientEmail.isNotEmpty) acceptedClientEmail,
          ...acceptedGroupClientEmails,
        };
        for (final targetEmail in acceptedClientTargets) {
          await NotificationsService.createUserNotification(
            receiverEmail: targetEmail,
            title: 'Brand Request Accepted',
            body: scenario41DirectClientReceiveOnArtistAcceptance(
              campaignName: campaignName,
              orderRef: orderNumber,
              artistName: artistLabel,
            ),
            type: 'client_brand_request_accepted_by_artist',
            orderId: request.id,
            orderNumber: orderNumber,
            sourceCollection: request.sourceCollection,
          );
        }
      } else {
        if (clientReceiver.isNotEmpty) {
          await NotificationsService.createUserNotification(
            receiverEmail: clientReceiver,
            title: 'Request Accepted',
            body:
                'Great news! $artistLabel accepted your request. Final amount: $amountText',
            type: 'request_accepted_designing',
            orderId: request.id,
            orderNumber: orderNumber,
            sourceCollection: request.sourceCollection,
          );
        }
      }
      return true;
    }

    final directRef = FirebaseFirestore.instance
        .collection(request.sourceCollection)
        .doc(request.id);
    if (await persistToDoc(directRef)) return true;

    final orderNo = request.orderNumber.trim();
    if (orderNo.isNotEmpty) {
      final fallbackCollections = <String>[
        'Client_Custom_Requests',
        'Company_Custom_Requests',
      ];
      for (final collection in fallbackCollections) {
        final query = await FirebaseFirestore.instance
            .collection(collection)
            .where('orderNumber', isEqualTo: orderNo)
            .limit(1)
            .get();
        if (query.docs.isEmpty) continue;
        if (await persistToDoc(query.docs.first.reference)) return true;
      }
    }

    return false;
  }

  void _removeRequestLocally(String id) {
    setState(() {
      _all.removeWhere((r) => r.id == id);
    });
  }

  Future<void> _persistStatusUpdate({
    required ClientRequestV2 request,
    required String status,
    Map<String, dynamic> summaryExtra = const <String, dynamic>{},
    Map<String, dynamic> detailsExtra = const <String, dynamic>{},
  }) async {
    final normalized = status.trim().toLowerCase();
    final roleSummaryDefaults = _roleStatusSummaryDefaultsFor(normalized);
    final roleDetailsDefaults = _roleStatusDetailsDefaultsFor(normalized);

    final summaryPayload = <String, dynamic>{
      'status': normalized,
      'updatedAt': FieldValue.serverTimestamp(),
      ...roleSummaryDefaults,
      ...summaryExtra,
    };

    final detailsPayload = <String, dynamic>{
      'status': normalized,
      ...roleDetailsDefaults,
      ...detailsExtra,
    };

    // If caller provided partial roleStatuses, merge with defaults so both keys exist.
    final existingRoleStatuses = detailsPayload['roleStatuses'];
    if (existingRoleStatuses is Map) {
      detailsPayload['roleStatuses'] = <String, dynamic>{
        ...(roleDetailsDefaults['roleStatuses'] as Map<String, dynamic>? ??
            const <String, dynamic>{}),
        ...existingRoleStatuses.cast<String, dynamic>(),
      };
    }

    final docRef = FirebaseFirestore.instance
        .collection(request.sourceCollection)
        .doc(request.id);
    final batch = FirebaseFirestore.instance.batch();
    batch.set(docRef, summaryPayload, SetOptions(merge: true));
    batch.set(
      docRef.collection('details').doc('payload'),
      detailsPayload,
      SetOptions(merge: true),
    );
    await batch.commit();

    if (normalized == 'completed' ||
        normalized == 'shipped' ||
        normalized == 'delivered') {
      unawaited(_syncAscensionForCurrentArtist());
    }
  }

  Map<String, dynamic> _roleStatusSummaryDefaultsFor(String status) {
    switch (status) {
      case 'completed':
        return const <String, dynamic>{
          'clientStatus': 'In Progress',
          'artistStatus': 'Completed',
        };
      case 'shipped':
        return const <String, dynamic>{
          'clientStatus': 'Shipped',
          'artistStatus': 'Shipped',
        };
      case 'delivered':
        return const <String, dynamic>{
          'clientStatus': 'Delivered',
          'artistStatus': 'Delivered',
        };
      case 'designing':
      case 'in_progress':
      case 'in progress':
        return const <String, dynamic>{
          'clientStatus': 'In Progress',
          'artistStatus': 'Designing',
        };
      case 'in_review':
      case 'in review':
        return const <String, dynamic>{
          'clientStatus': 'Pending',
          'artistStatus': 'In Review',
        };
      case 'cancelled':
      case 'canceled':
        return const <String, dynamic>{
          'clientStatus': 'Cancelled',
          'artistStatus': 'Cancelled',
        };
      case 'declined':
        return const <String, dynamic>{
          'clientStatus': 'Declined',
          'artistStatus': 'Declined',
        };
      case 'expired':
        return const <String, dynamic>{
          'clientStatus': 'Expired',
          'artistStatus': 'Expired',
        };
      default:
        return const <String, dynamic>{};
    }
  }

  Map<String, dynamic> _roleStatusDetailsDefaultsFor(String status) {
    switch (status) {
      case 'completed':
        return const <String, dynamic>{
          'clientStatus': 'In Progress',
          'artistStatus': 'Completed',
          'roleStatuses': <String, dynamic>{
            'client': 'in_progress',
            'artist': 'completed',
          },
        };
      case 'shipped':
        return const <String, dynamic>{
          'clientStatus': 'Shipped',
          'artistStatus': 'Shipped',
          'roleStatuses': <String, dynamic>{
            'client': 'shipped',
            'artist': 'shipped',
          },
        };
      case 'delivered':
        return const <String, dynamic>{
          'clientStatus': 'Delivered',
          'artistStatus': 'Delivered',
          'roleStatuses': <String, dynamic>{
            'client': 'delivered',
            'artist': 'delivered',
          },
        };
      case 'designing':
      case 'in_progress':
      case 'in progress':
        return const <String, dynamic>{
          'clientStatus': 'In Progress',
          'artistStatus': 'Designing',
          'roleStatuses': <String, dynamic>{
            'client': 'in_progress',
            'artist': 'designing',
          },
        };
      case 'in_review':
      case 'in review':
        return const <String, dynamic>{
          'clientStatus': 'Pending',
          'artistStatus': 'In Review',
          'roleStatuses': <String, dynamic>{
            'client': 'pending',
            'artist': 'in_review',
          },
        };
      case 'cancelled':
      case 'canceled':
        return const <String, dynamic>{
          'clientStatus': 'Cancelled',
          'artistStatus': 'Cancelled',
          'roleStatuses': <String, dynamic>{
            'client': 'cancelled',
            'artist': 'cancelled',
          },
        };
      case 'declined':
        return const <String, dynamic>{
          'clientStatus': 'Declined',
          'artistStatus': 'Declined',
          'roleStatuses': <String, dynamic>{
            'client': 'declined',
            'artist': 'declined',
          },
        };
      case 'expired':
        return const <String, dynamic>{
          'clientStatus': 'Expired',
          'artistStatus': 'Expired',
          'roleStatuses': <String, dynamic>{
            'client': 'expired',
            'artist': 'expired',
          },
        };
      default:
        return const <String, dynamic>{};
    }
  }

  Future<void> _persistArtistDecline(ClientRequestV2 request) async {
    final artistEmail = (FirebaseAuth.instance.currentUser?.email ?? '')
        .trim()
        .toLowerCase();
    if (artistEmail.isEmpty) {
      throw Exception('Missing signed-in artist email.');
    }

    final docRef = FirebaseFirestore.instance
        .collection(request.sourceCollection)
        .doc(request.id);
    final releaseDirectToPool =
        request.isDirectRequest && request.fallbackToPool;
    final cancelDirectRequest =
        request.isDirectRequest && !request.fallbackToPool;
    String firstNonEmpty(List<Object?> values, {String fallback = ''}) {
      for (final value in values) {
        final text = (value ?? '').toString().trim();
        if (text.isNotEmpty) return text;
      }
      return fallback;
    }

    final batch = FirebaseFirestore.instance.batch();
    const artistCancelReasonText = 'Artist declined the request';
    final artistCancelReason = artistCancelReasonText;
    batch.set(docRef, {
      'updatedAt': FieldValue.serverTimestamp(),
      'declinedByArtistEmails': FieldValue.arrayUnion(<String>[artistEmail]),
      if (releaseDirectToPool) 'status': 'in_review',
      if (releaseDirectToPool) 'clientStatus': 'pending',
      if (releaseDirectToPool) 'artistStatus': 'in_review',
      if (releaseDirectToPool) 'directArtistStatus': 'declined',
      if (releaseDirectToPool) 'artistPoolStatus': 'in_review',
      if (releaseDirectToPool) 'openToArtistPool': true,
      if (cancelDirectRequest) 'status': 'cancelled',
      if (cancelDirectRequest) 'clientStatus': 'cancelled',
      if (cancelDirectRequest) 'artistStatus': 'cancelled',
      if (cancelDirectRequest) 'cancelReason': artistCancelReason,
      if (cancelDirectRequest) 'cancelledAt': FieldValue.serverTimestamp(),
      if (releaseDirectToPool) 'isDirectRequest': false,
      if (releaseDirectToPool) 'selectedArtist': '',
      if (releaseDirectToPool) 'selectedArtistEmail': '',
      if (releaseDirectToPool) 'fallbackToPool': true,
      if (releaseDirectToPool)
        'directRequestReleasedToPoolAt': FieldValue.serverTimestamp(),
      if (releaseDirectToPool)
        'directRequestReleasedByArtistEmail': artistEmail,
    }, SetOptions(merge: true));
    batch.set(docRef.collection('details').doc('payload'), {
      if (releaseDirectToPool) 'status': 'in_review',
      if (cancelDirectRequest) 'status': 'cancelled',
      if (releaseDirectToPool)
        'roleStatuses': {'client': 'pending', 'artist': 'in_review'},
      if (cancelDirectRequest)
        'roleStatuses': {'client': 'cancelled', 'artist': 'cancelled'},
      'declinedByArtistEmails': FieldValue.arrayUnion(<String>[artistEmail]),
      'artistDecline': {
        'artistEmail': artistEmail,
        'declinedAt': FieldValue.serverTimestamp(),
        'status': releaseDirectToPool ? 'released_to_pool' : 'declined',
        'reason': releaseDirectToPool
            ? 'Declined by selected artist and released to artist pool'
            : 'Declined by artist',
      },
      if (cancelDirectRequest)
        'cancellation': {
          'reason': artistCancelReason,
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelledBy': 'artist',
        },
      if (releaseDirectToPool)
        'order': {
          'selectedArtist': '',
          'selectedArtistEmail': '',
          'isDirectRequest': false,
          'fallbackToPool': true,
        },
      if (releaseDirectToPool)
        'directRequestReleasedToPoolAt': FieldValue.serverTimestamp(),
      if (releaseDirectToPool)
        'directRequestReleasedByArtistEmail': artistEmail,
      if (releaseDirectToPool)
        'routing': {
          'directArtistStatus': 'declined',
          'artistPoolStatus': 'in_review',
          'releasedToArtistPoolAt': FieldValue.serverTimestamp(),
        },
    }, SetOptions(merge: true));
    await batch.commit();

    if (releaseDirectToPool) {
      final rootSnap = await docRef.get();
      final rootData = rootSnap.data() ?? const <String, dynamic>{};
      final detailsSnap = await docRef
          .collection('details')
          .doc('payload')
          .get();
      final detailsData = detailsSnap.data() ?? const <String, dynamic>{};
      final orderData =
          (detailsData['order'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final orderRef = request.orderNumber.trim().isNotEmpty
          ? request.orderNumber.trim()
          : request.id;
      final brandName = firstNonEmpty(<Object?>[
        rootData['companyName'],
        rootData['brandName'],
        request.brandName,
        request.clientName,
      ], fallback: 'Brand');
      final campaignName = firstNonEmpty(<Object?>[
        rootData['campaignName'],
        rootData['title'],
        request.title,
      ], fallback: 'Campaign');
      final artistName =
          (FirebaseAuth.instance.currentUser?.displayName ?? '')
              .trim()
              .isNotEmpty
          ? (FirebaseAuth.instance.currentUser?.displayName ?? '').trim()
          : artistEmail.split('@').first;
      final acceptedClientName = firstNonEmpty(<Object?>[
        rootData['acceptedClientName'],
        rootData['selectedClient'],
        request.acceptedClientName,
        request.selectedClient,
        'Client',
      ], fallback: 'Client');

      final brandRecipientEmails =
          await NotificationsService.resolveBrandRecipientEmails(
            rootData: rootData,
            detailsData: detailsData,
            orderData: orderData,
            excludeEmails: <String>[artistEmail],
          );

      for (final brandCompanyEmail in brandRecipientEmails) {
        await NotificationsService.createUserNotification(
          receiverEmail: brandCompanyEmail,
          title: 'Brand Request Declined',
          body: scenario43BrandReceiveOnDirectArtistDecline(
            artistName: artistName,
            brandName: brandName,
            campaignName: campaignName,
            orderRef: orderRef,
            clientName: acceptedClientName,
          ),
          type: 'brand_request_declined_by_direct_artist',
          orderId: request.id,
          orderNumber: request.orderNumber,
          sourceCollection: request.sourceCollection,
        );
      }

      await NotificationsService.notifyArtistsForBrandClientAcceptedRequest(
        clientName: acceptedClientName,
        brandName: brandName,
        campaignName: campaignName,
        isDirectRequest: false,
        selectedArtistEmail: '',
        selectedArtistName: '',
        orderId: request.id,
        sourceCollection: request.sourceCollection,
        orderNumber: request.orderNumber,
        allowNonLicensed: request.allowNonLicensed,
        excludeArtistEmails: <String>[artistEmail],
      );
    }

    if (cancelDirectRequest && request.clientEmail.trim().isNotEmpty) {
      final artistName =
          (FirebaseAuth.instance.currentUser?.displayName ?? '').trim().isEmpty
          ? (FirebaseAuth.instance.currentUser?.email ?? 'Artist')
                .split('@')
                .first
          : (FirebaseAuth.instance.currentUser?.displayName ?? '').trim();
      await NotificationsService.createUserNotification(
        receiverEmail: request.clientEmail.trim().toLowerCase(),
        title: 'Request Cancelled',
        body: 'Declined by Artist $artistName',
        type: 'direct_request_declined_cancelled',
        orderId: request.id,
        orderNumber: request.orderNumber,
        sourceCollection: request.sourceCollection,
      );
    }
  }

  Future<void> _persistClientPoolResponse({
    required ClientRequestV2 request,
    required bool accept,
  }) async {
    final clientEmail = (FirebaseAuth.instance.currentUser?.email ?? '')
        .trim()
        .toLowerCase();
    if (clientEmail.isEmpty) {
      throw Exception('Missing signed-in client email.');
    }
    if (request.sourceCollection != 'Company_Custom_Requests') {
      throw Exception('Only company requests can be accepted/cancelled here.');
    }
    final selectedClientEmail = request.selectedClientEmail
        .trim()
        .toLowerCase();
    final selectedGroupClientEmails = request.selectedGroupClientEmails
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    String firstNonEmpty(List<Object?> values, {String fallback = ''}) {
      for (final value in values) {
        final text = (value ?? '').toString().trim();
        if (text.isNotEmpty) return text;
      }
      return fallback;
    }

    if (!request.openToClientPool &&
        (request.orderType == RequestOrderTypeV2.group
            ? !selectedGroupClientEmails.contains(clientEmail)
            : (selectedClientEmail.isNotEmpty &&
                  selectedClientEmail != clientEmail))) {
      throw Exception(
        'Only the designated client can respond to this request.',
      );
    }

    if (!accept) {
      if (request.openToClientPool) {
        await _persistStatusUpdate(
          request: request,
          status: 'in_review',
          summaryExtra: <String, dynamic>{
            'declinedByClientEmails': FieldValue.arrayUnion(<String>[
              clientEmail,
            ]),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          detailsExtra: <String, dynamic>{
            'declinedByClientEmails': FieldValue.arrayUnion(<String>[
              clientEmail,
            ]),
            'lastClientDeclinedAt': FieldValue.serverTimestamp(),
          },
        );
        return;
      }
      await _persistStatusUpdate(
        request: request,
        status: 'in_review',
        summaryExtra: <String, dynamic>{
          'openToClientPool': true,
          'acceptedByClientEmail': '',
          'brandStatus': 'pending',
          'clientStatus': 'pending',
          'artistStatus': 'pending',
          'directClientStatus': 'declined',
          'clientPoolStatus': 'pending',
          'declinedByClientEmails': FieldValue.arrayUnion(<String>[
            clientEmail,
          ]),
        },
        detailsExtra: <String, dynamic>{
          'openToClientPool': true,
          'declinedByClientEmails': FieldValue.arrayUnion(<String>[
            clientEmail,
          ]),
          'acceptance': <String, dynamic>{'acceptedByClientEmail': ''},
          'roleStatuses': <String, dynamic>{
            'brand': 'pending',
            'client': 'pending',
            'artist': 'pending',
          },
          'routing': <String, dynamic>{
            'directClientStatus': 'declined',
            'clientPoolStatus': 'pending',
            'releasedToClientPoolAt': FieldValue.serverTimestamp(),
          },
        },
      );
      return;
    }

    final clientData = await _loadAcceptingClientData(clientEmail);
    final clientName = (clientData['name'] as String? ?? '').trim();
    final clientProfileImage = (clientData['profileImage'] as String? ?? '')
        .trim();
    final nailShape = (clientData['nailShape'] as String? ?? '').trim();
    final nailLength = (clientData['nailLength'] as String? ?? '').trim();
    final nailDimensions =
        (clientData['nailDimensions'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final rootSnap = await FirebaseFirestore.instance
        .collection(request.sourceCollection)
        .doc(request.id)
        .get();
    final rootData = rootSnap.data() ?? const <String, dynamic>{};
    final detailsSnap = await rootSnap.reference
        .collection('details')
        .doc('payload')
        .get();
    final detailsData = detailsSnap.data() ?? const <String, dynamic>{};
    final orderData =
        (detailsData['order'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final brandName = firstNonEmpty(<Object?>[
      rootData['companyName'],
      rootData['brandName'],
      request.clientName,
    ], fallback: 'Brand company');
    final campaignName = firstNonEmpty(<Object?>[
      rootData['campaignName'],
      rootData['title'],
      request.title,
    ], fallback: 'Campaign');
    final brandRecipientEmails =
        await NotificationsService.resolveBrandRecipientEmails(
          rootData: rootData,
          detailsData: detailsData,
          orderData: orderData,
          excludeEmails: <String>[clientEmail],
        );

    await _persistStatusUpdate(
      request: request,
      status: 'pending',
      summaryExtra: <String, dynamic>{
        'acceptedByClientEmail': clientEmail,
        'acceptedByClientAt': FieldValue.serverTimestamp(),
        'brandStatus': 'pending',
        'clientStatus': 'pending',
        'artistStatus': 'in_review',
        'directArtistStatus': 'in_review',
        if (clientName.isNotEmpty) 'acceptedClientName': clientName,
        if (clientProfileImage.isNotEmpty)
          'clientProfileImage': clientProfileImage,
        if (clientProfileImage.isNotEmpty)
          'clientProfilePic': clientProfileImage,
        if (nailShape.isNotEmpty) 'nailShape': nailShape,
        if (nailLength.isNotEmpty) 'nailLength': nailLength,
      },
      detailsExtra: <String, dynamic>{
        'acceptance': <String, dynamic>{
          'acceptedByClientEmail': clientEmail,
          'acceptedByClientAt': FieldValue.serverTimestamp(),
        },
        'clientProfileSnapshot': <String, dynamic>{
          'basic': <String, dynamic>{
            if (clientName.isNotEmpty) 'name': clientName,
            'email': clientEmail,
            if (clientProfileImage.isNotEmpty)
              'profileImageUrl': clientProfileImage,
            if (clientProfileImage.isNotEmpty) 'avatarUrl': clientProfileImage,
          },
        },
        'nailPreferences': <String, dynamic>{
          if (nailShape.isNotEmpty) 'shape': nailShape,
          if (nailLength.isNotEmpty) 'length': nailLength,
          'dimensions': nailDimensions,
        },
        'roleStatuses': <String, dynamic>{
          'brand': 'pending',
          'client': 'pending',
          'artist': 'in_review',
        },
      },
    );

    final acceptedClientName = clientName.isNotEmpty ? clientName : 'Client';
    final normalizedOrderNumber = request.orderNumber.trim().isNotEmpty
        ? request.orderNumber.trim()
        : request.id;
    for (final brandCompanyEmail in brandRecipientEmails) {
      await NotificationsService.createUserNotification(
        receiverEmail: brandCompanyEmail,
        title: 'Brand Request Accepted',
        body:
            '$acceptedClientName has accepted your $campaignName brand request $normalizedOrderNumber',
        type: 'brand_request_accepted_by_client',
        orderId: request.id,
        orderNumber: request.orderNumber,
        sourceCollection: request.sourceCollection,
      );
    }

    await NotificationsService.notifyAdmins(
      title: 'Brand Request Accepted',
      body:
          '$acceptedClientName has accepted the $brandName $campaignName brand request $normalizedOrderNumber',
      type: 'admin_brand_request_accepted_by_client',
      orderId: request.id,
      orderNumber: request.orderNumber,
      sourceCollection: request.sourceCollection,
    );

    await NotificationsService.notifyArtistsForBrandClientAcceptedRequest(
      clientName: acceptedClientName,
      brandName: brandName,
      campaignName: campaignName,
      isDirectRequest: request.isDirectRequest,
      selectedArtistEmail: request.selectedArtistEmail.trim().toLowerCase(),
      orderId: request.id,
      sourceCollection: request.sourceCollection,
      orderNumber: request.orderNumber,
      allowNonLicensed: request.allowNonLicensed,
    );
  }

  Future<Map<String, dynamic>> _loadAcceptingClientData(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return const <String, dynamic>{};

    String first(Map<String, dynamic> source, List<String> keys) {
      for (final key in keys) {
        final value = (source[key] ?? '').toString().trim();
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    Future<Map<String, dynamic>> readFrom(String collection) async {
      final snap = await FirebaseFirestore.instance
          .collection(collection)
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return const <String, dynamic>{};
      final data = snap.docs.first.data();
      final profile = (data['profile'] as Map<String, dynamic>?) ?? const {};
      final basic = (data['basic'] as Map<String, dynamic>?) ?? const {};
      final nail =
          (data['nailPreferences'] as Map<String, dynamic>?) ?? const {};
      final dimensions =
          (nail['dimensions'] as Map<String, dynamic>?) ?? const {};

      return <String, dynamic>{
        'name': first(data, const ['displayName', 'name']).isNotEmpty
            ? first(data, const ['displayName', 'name'])
            : (first(profile, const ['name', 'displayName']).isNotEmpty
                  ? first(profile, const ['name', 'displayName'])
                  : first(basic, const ['name', 'displayName'])),
        'profileImage':
            first(data, const ['profileImageUrl', 'avatarUrl']).isNotEmpty
            ? first(data, const ['profileImageUrl', 'avatarUrl'])
            : (first(profile, const [
                    'profileImageUrl',
                    'avatarUrl',
                    'photoUrl',
                  ]).isNotEmpty
                  ? first(profile, const [
                      'profileImageUrl',
                      'avatarUrl',
                      'photoUrl',
                    ])
                  : first(basic, const [
                      'profileImageUrl',
                      'avatarUrl',
                      'photoUrl',
                    ])),
        'nailShape': first(nail, const ['shape']),
        'nailLength': first(nail, const ['length']),
        'nailDimensions': <String, dynamic>{
          'lThumb': dimensions['lThumb'],
          'lIndex': dimensions['lIndex'],
          'lMiddle': dimensions['lMiddle'],
          'lRing': dimensions['lRing'],
          'lPinky': dimensions['lPinky'],
          'rThumb': dimensions['rThumb'],
          'rIndex': dimensions['rIndex'],
          'rMiddle': dimensions['rMiddle'],
          'rRing': dimensions['rRing'],
          'rPinky': dimensions['rPinky'],
        },
      };
    }

    try {
      final fromClient = await readFrom('client');
      if (fromClient.isNotEmpty) return fromClient;
      final fromClientArtist = await readFrom('client_artist');
      if (fromClientArtist.isNotEmpty) return fromClientArtist;
    } catch (_) {}

    return const <String, dynamic>{};
  }

  Widget _budgetChip() {
    final label =
        '\$${_budgetRange.start.round()} - \$${_budgetRange.end.round()}';
    final minPreset = widget.initialBudgetMin.clamp(15, 5000);
    final maxPreset = widget.initialBudgetMax.clamp(15, 5000);
    final defaultStart = minPreset <= maxPreset ? minPreset : maxPreset;
    final defaultEnd = minPreset <= maxPreset ? maxPreset : minPreset;
    final isSelected =
        _budgetRange.start.round() != defaultStart ||
        _budgetRange.end.round() != defaultEnd;

    return CompositedTransformTarget(
      link: _budgetLink,
      child: InkWell(
        borderRadius: BorderRadius.zero,
        onTap: () {
          if (_dropdownEntry != null) {
            _closeDropdown();
          } else {
            _showBudgetDropdown();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.alabaster.withOpacity(0.7)
                : AppColors.snow,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: AppColors.blackCatBorderLight),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.attach_money_rounded,
                size: 16,
                color: AppColors.blackCat.withOpacity(0.70),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: _t(12, w: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: AppColors.blackCat.withOpacity(0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBudgetDropdown() {
    void apply(RangeValues v) {
      setState(() {
        _budgetRange = v;
        _budgetMinCtrl.text = v.start.round().toString();
        _budgetMaxCtrl.text = v.end.round().toString();
      });
      _closeDropdown();
    }

    _showDropdown(
      link: _budgetLink,
      child: _DropdownCard(
        width: 240,
        children: [
          _DropItem(
            text: '\$15 - \$200',
            onTap: () => apply(const RangeValues(15, 200)),
          ),
          _DropItem(
            text: '\$201 - \$500',
            onTap: () => apply(const RangeValues(201, 500)),
          ),
          _DropItem(
            text: '\$501 - \$1000',
            onTap: () => apply(const RangeValues(501, 1000)),
          ),
          _DropItem(
            text: '\$1001 - \$2000',
            onTap: () => apply(const RangeValues(1001, 2000)),
          ),
          _DropItem(
            text: '\$2001 - \$3000',
            onTap: () => apply(const RangeValues(2001, 3000)),
          ),
          _DropItem(
            text: '\$3001 - \$4000',
            onTap: () => apply(const RangeValues(3001, 4000)),
          ),
          _DropItem(
            text: '\$4001 - \$5000',
            onTap: () => apply(const RangeValues(4001, 5000)),
          ),
        ],
      ),
    );
  }

  Future<void> _openBudgetMenu() async {
    final pos = _popupPosition(_budgetKey);

    final selected = await showMenu<RangeValues>(
      context: context,
      position: pos,
      color: AppColors.snow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      items: const [
        PopupMenuItem(value: RangeValues(20, 100), child: Text('\$20 - \$100')),
        PopupMenuItem(
          value: RangeValues(101, 200),
          child: Text('\$101 - \$200'),
        ),
        PopupMenuItem(
          value: RangeValues(201, 500),
          child: Text('\$201 - \$500'),
        ),
        PopupMenuItem(
          value: RangeValues(501, 1000),
          child: Text('\$501 - \$1000'),
        ),
        PopupMenuItem(
          value: RangeValues(1001, 1500),
          child: Text('\$1001 - \$1500'),
        ),
      ],
    );

    if (selected != null) {
      setState(() => _budgetRange = selected);
      _budgetMinCtrl.text = selected.start.round().toString();
      _budgetMaxCtrl.text = selected.end.round().toString();
    }
  }

  Future<void> _openAcceptedDetails(ClientRequestV2 r) async {
    final shipDays = _estimateShipDays(
      artistLocation: widget.artistLocation,
      clientLocation: r.clientLocation,
    );

    await showAcceptedRequestSheet(
      context: context,
      request: r,
      shipDays: shipDays,
      onClose: () {}, // sheet already calls Navigator.pop internally
      onMarkCompleted: (completed, artistPhotos) async =>
          _handleMarkCompleted(r, completed, artistPhotos),
    );
  }

  Future<void> _openDesigningDetails(ClientRequestV2 r) async {
    final shipDays = _estimateShipDays(
      artistLocation: widget.artistLocation,
      clientLocation: r.clientLocation,
    );

    await showArtistDesigningRequestSheet(
      context: context,
      request: r,
      shipDays: shipDays,
      onClose: () {},
      onMarkCompleted: (completed, artistPhotos) async =>
          _handleMarkCompleted(r, completed, artistPhotos),
    );
  }

  Future<void> _handleMarkCompleted(
    ClientRequestV2 r,
    bool completed,
    List<String> artistPhotos,
  ) async {
    if (!completed) return;
    final summaryPhotos = artistPhotos
        .where((p) => p.trim().isNotEmpty && !p.trim().startsWith('data:'))
        .toList(growable: false);
    try {
      _moveToStatus(r.id, RequestStatusV2.completed);
      final currentUser = FirebaseAuth.instance.currentUser;
      final artistId = (currentUser?.uid ?? '').trim();
      final artistEmail = (currentUser?.email ?? '').trim();
      final artistNotifyEmail = artistEmail.toLowerCase();
      final orderNumber = r.orderNumber.trim().isNotEmpty
          ? r.orderNumber
          : r.id;
      final shipping = buildShippingPayload(
        collectionName: r.sourceCollection,
        orderDocId: r.id,
        orderNumber: orderNumber,
        artistId: artistId,
        artistEmail: artistEmail,
        shippingAddressDifferentFromProfile:
            r.shippingAddressDifferentFromProfile,
        shippingStreet: r.shippingStreet,
        shippingCity: r.shippingCity,
        shippingState: r.shippingState,
        shippingZip: r.shippingZip,
        shippingCountry: r.shippingCountry,
      );
      await _persistStatusUpdate(
        request: r,
        status: 'completed',
        summaryExtra: {
          // Keep root summary lightweight; full payload stays in details.
          'artistCompletedPhotos': summaryPhotos,
          'artistCompletedPhotoCount': artistPhotos.length,
          'completionReviewStatus': 'pending_client',
          'artistCompletedAt': FieldValue.serverTimestamp(),
          'artistStatus': 'Completed',
          'clientStatus': 'In Progress',
          'shippingStatus': 'label_ready',
          'shippingLabelQrData': shipping['qrCode'],
          'shippingLabelReady': true,
          'shipping': shipping,
          'completedArt': <String, dynamic>{
            'imageUrls': artistPhotos,
            'uploadedAt': FieldValue.serverTimestamp(),
            'uploadedByArtistId': artistId,
            'uploadedByArtistEmail': artistEmail,
          },
        },
        detailsExtra: {
          'roleStatuses': <String, dynamic>{
            'client': 'in_progress',
            'artist': 'completed',
          },
          'artistCompletion': {
            'artistPhotos': artistPhotos,
            'reviewStatus': 'pending_client',
            'submittedAt': FieldValue.serverTimestamp(),
          },
          'shippingStatus': 'label_ready',
          'shippingLabelQrData': shipping['qrCode'],
          'shippingLabelReady': true,
          'shipping': shipping,
          'completedArt': <String, dynamic>{
            'imageUrls': artistPhotos,
            'uploadedAt': FieldValue.serverTimestamp(),
            'uploadedByArtistId': artistId,
            'uploadedByArtistEmail': artistEmail,
          },
        },
      );
      final clientEmail = r.clientEmail.trim().toLowerCase();
      final isBrandRequest =
          r.sourceCollection == 'Company_Custom_Requests' ||
          orderNumber.toUpperCase().startsWith('BE-') ||
          orderNumber.toUpperCase().startsWith('BR-');
      final brandCtx = isBrandRequest
          ? await _loadBrandNotificationContext(r)
          : const <String, String>{};
      final campaignName = (brandCtx['campaignName'] ?? '').trim().isNotEmpty
          ? brandCtx['campaignName']!
          : (r.title.trim().isEmpty ? 'Campaign' : r.title.trim());
      final acceptedClientName =
          (brandCtx['acceptedClientName'] ?? '').trim().isNotEmpty
          ? brandCtx['acceptedClientName']!
          : (r.acceptedClientName.trim().isEmpty
                ? (r.clientName.trim().isEmpty ? 'Client' : r.clientName.trim())
                : r.acceptedClientName.trim());
      final brandCompanyName = (brandCtx['brandName'] ?? '').trim().isNotEmpty
          ? brandCtx['brandName']!
          : (r.brandName.trim().isEmpty ? 'Brand' : r.brandName.trim());
      final brandEmail = (brandCtx['brandEmail'] ?? '').trim().toLowerCase();
      final brandEmails = (brandCtx['brandEmailsCsv'] ?? '')
          .split(',')
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty && e.contains('@'))
          .toSet();
      if (brandEmail.isNotEmpty) {
        brandEmails.add(brandEmail);
      }
      final acceptedClientEmail = (brandCtx['acceptedClientEmail'] ?? '')
          .trim()
          .toLowerCase();
      final artistName =
          (FirebaseAuth.instance.currentUser?.displayName ?? '')
              .trim()
              .isNotEmpty
          ? (FirebaseAuth.instance.currentUser?.displayName ?? '').trim()
          : (FirebaseAuth.instance.currentUser?.email ?? 'Artist')
                .split('@')
                .first;
      if (isBrandRequest) {
        for (final receiver in brandEmails) {
          await NotificationsService.createUserNotification(
            receiverEmail: receiver,
            title: 'Brand Request Completed',
            body:
                '$artistName has completed your $campaignName brand request $orderNumber for $acceptedClientName',
            type: 'brand_request_completed_brand',
            orderId: r.id,
            orderNumber: orderNumber,
            sourceCollection: r.sourceCollection,
          );
        }
        if (acceptedClientEmail.isNotEmpty) {
          await NotificationsService.createUserNotification(
            receiverEmail: acceptedClientEmail,
            title: 'Brand Request Completed',
            body:
                'Your $campaignName Brand request $orderNumber is completed by $artistName',
            type: 'brand_request_completed_client',
            orderId: r.id,
            orderNumber: orderNumber,
            sourceCollection: r.sourceCollection,
          );
        }
        await NotificationsService.notifyAdmins(
          title: 'Brand Request Completed',
          body:
              '$artistName has completed $brandCompanyName $campaignName brand request $orderNumber for $acceptedClientName',
          type: 'brand_request_completed_admin',
          orderId: r.id,
          orderNumber: orderNumber,
          sourceCollection: r.sourceCollection,
        );
        return;
      }

      if (clientEmail.isNotEmpty) {
        final orderNo = r.orderNumber.trim().isNotEmpty ? r.orderNumber : r.id;
        await NotificationsService.createUserNotification(
          receiverEmail: clientEmail,
          title: 'Order Completed',
          body:
              'Your nails are done! 💅 $artistName just uploaded your final look.',
          type: 'order_completed_by_artist',
          orderId: r.id,
          orderNumber: orderNo,
          sourceCollection: r.sourceCollection,
        );
        await NotificationsService.queueEmail(
          to: clientEmail,
          subject: 'Please Review Your Completed Nail Design',
          text:
              'Your artist completed order $orderNo and uploaded photos. Please open your order details to Accept or Decline before shipping.',
          html:
              '<p>Your artist completed order <b>$orderNo</b> and uploaded photos.</p>'
              '<p>Please open your order details to <b>Accept</b> or <b>Decline</b> before shipping.</p>',
        );
        try {
          final doc = await FirebaseFirestore.instance
              .collection(r.sourceCollection)
              .doc(r.id)
              .get();
          final phone = ((doc.data()?['clientPhone'] ?? '') as Object)
              .toString()
              .trim();
          if (phone.isNotEmpty) {
            await NotificationsService.queueSms(
              to: phone,
              text:
                  'JNT: Your completed design for order $orderNo is ready for review. Please accept or decline in the app.',
            );
          }
        } catch (_) {
          // Best-effort SMS; ignore missing/invalid phone fields.
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to complete order: $e')));
    }
  }

  String _normalizeImagePath(String raw) {
    var p = raw.trim();
    if (p.isEmpty) return '';
    if (p.startsWith('assets/')) {
      final rest = p.substring('assets/'.length);
      final decodedRest = _decodeUriSafelyRepeatedly(rest).trim();
      final lower = decodedRest.toLowerCase();
      if (lower.startsWith('data:') ||
          lower.startsWith('blob:') ||
          lower.startsWith('http://') ||
          lower.startsWith('https://') ||
          lower.startsWith('content://') ||
          lower.startsWith('file://')) {
        return decodedRest;
      }
    }
    p = _decodeUriSafelyRepeatedly(p).trim();
    if (p.startsWith('assets/')) {
      final rest = p.substring('assets/'.length);
      final decodedRest = _decodeUriSafelyRepeatedly(rest).trim();
      final lower = decodedRest.toLowerCase();
      if (lower.startsWith('data:') ||
          lower.startsWith('blob:') ||
          lower.startsWith('http://') ||
          lower.startsWith('https://') ||
          lower.startsWith('content://') ||
          lower.startsWith('file://')) {
        return decodedRest;
      }
    }
    return p;
  }

  Future<Map<String, String>> _loadBrandNotificationContext(
    ClientRequestV2 r,
  ) async {
    String firstNonEmpty(List<Object?> values, {String fallback = ''}) {
      for (final value in values) {
        final text = (value ?? '').toString().trim();
        if (text.isNotEmpty) return text;
      }
      return fallback;
    }

    final doc = await FirebaseFirestore.instance
        .collection(r.sourceCollection)
        .doc(r.id)
        .get();
    final data = doc.data() ?? const <String, dynamic>{};
    final detailSnap = await doc.reference
        .collection('details')
        .doc('payload')
        .get();
    final detailData = detailSnap.data() ?? const <String, dynamic>{};
    final orderData =
        (detailData['order'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final acceptanceData =
        (detailData['acceptance'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};

    String normalizeEmail(Object? value) =>
        (value ?? '').toString().trim().toLowerCase();

    final companyUid = firstNonEmpty(<Object?>[
      data['companyUid'],
      detailData['companyUid'],
      orderData['companyUid'],
    ]);
    Map<String, dynamic> companyData = const <String, dynamic>{};
    if (companyUid.trim().isNotEmpty) {
      try {
        final companySnap = await FirebaseFirestore.instance
            .collection('company')
            .doc(companyUid.trim())
            .get();
        companyData = companySnap.data() ?? const <String, dynamic>{};
      } catch (_) {}
    }

    final brandRecipientEmails =
        await NotificationsService.resolveBrandRecipientEmails(
          rootData: <String, dynamic>{...data, ...companyData},
          detailsData: <String, dynamic>{...detailData, ...acceptanceData},
          orderData: orderData,
        );

    final brandEmail = brandRecipientEmails.isNotEmpty
        ? brandRecipientEmails.first
        : '';

    final acceptedClientEmail = firstNonEmpty(<Object?>[
      data['acceptedByClientEmail'],
      data['selectedClientEmail'],
      detailData['selectedClientEmail'],
      orderData['selectedClientEmail'],
      (detailData['acceptance']
          as Map<String, dynamic>?)?['acceptedByClientEmail'],
      (detailData['acceptance']
          as Map<String, dynamic>?)?['selectedClientEmail'],
      r.acceptedByClientEmail,
      r.selectedClientEmail,
    ]).toLowerCase();

    final brandName = firstNonEmpty(<Object?>[
      data['companyName'],
      data['brandName'],
      orderData['companyName'],
      r.brandName,
      r.clientName,
    ], fallback: 'Brand');
    final campaignName = firstNonEmpty(<Object?>[
      data['campaignName'],
      data['title'],
      orderData['campaignName'],
      orderData['title'],
      r.title,
    ], fallback: 'Campaign');
    final acceptedClientName = firstNonEmpty(<Object?>[
      data['acceptedClientName'],
      data['selectedClient'],
      orderData['selectedClient'],
      (detailData['acceptance']
          as Map<String, dynamic>?)?['acceptedClientName'],
      (detailData['acceptance']
          as Map<String, dynamic>?)?['selectedClientName'],
      r.acceptedClientName,
      r.selectedClient,
      r.clientName,
    ], fallback: 'Client');

    return <String, String>{
      'brandEmail': brandEmail,
      'brandEmailsCsv': brandRecipientEmails.join(','),
      'acceptedClientEmail': acceptedClientEmail,
      'brandName': brandName,
      'campaignName': campaignName,
      'acceptedClientName': acceptedClientName,
    };
  }

  Future<void> _openCompletedDetails(ClientRequestV2 r) async {
    final shipDays = _estimateShipDays(
      artistLocation: widget.artistLocation,
      clientLocation: r.clientLocation,
    );

    await showCompletedRequestSheet(
      context: context,
      request: r,
      shipDays: shipDays,
      onClose: () => Navigator.pop(context),

      // ✅ UPDATED signature + uses shippedDate
      onMarkShipped:
          ({
            required String courier,
            required String tracking,
            required DateTime shippedDate,
          }) async {
            // 1) update local UI immediately
            final updated = r.copyWith(
              status: RequestStatusV2.shipped,
              shippedByCourier: courier,
              trackingNumber: tracking,

              // ✅ NEW: use selected shipped date from sheet
              shippedAt: shippedDate,
            );
            _replaceById(r.id, updated);
            await _persistStatusUpdate(
              request: r,
              status: 'shipped',
              summaryExtra: {
                'shippedByCourier': courier,
                'trackingNumber': tracking,
                'shippedAt': Timestamp.fromDate(shippedDate),
              },
              detailsExtra: {
                'shipment': {
                  'courier': courier,
                  'trackingNumber': tracking,
                  'shippedAt': Timestamp.fromDate(shippedDate),
                },
              },
            );
            final clientEmail = r.clientEmail.trim().toLowerCase();
            final orderRef = r.orderNumber.trim().isNotEmpty
                ? r.orderNumber.trim()
                : r.id;
            final isBrandRequest =
                r.sourceCollection == 'Company_Custom_Requests' ||
                orderRef.toUpperCase().startsWith('BE-') ||
                orderRef.toUpperCase().startsWith('BR-');
            final brandCtx = isBrandRequest
                ? await _loadBrandNotificationContext(r)
                : const <String, String>{};
            final campaignName =
                (brandCtx['campaignName'] ?? '').trim().isNotEmpty
                ? brandCtx['campaignName']!
                : (r.title.trim().isEmpty ? 'Campaign' : r.title.trim());
            final acceptedClientName =
                (brandCtx['acceptedClientName'] ?? '').trim().isNotEmpty
                ? brandCtx['acceptedClientName']!
                : (r.acceptedClientName.trim().isEmpty
                      ? (r.clientName.trim().isEmpty
                            ? 'Client'
                            : r.clientName.trim())
                      : r.acceptedClientName.trim());
            final brandCompanyName =
                (brandCtx['brandName'] ?? '').trim().isNotEmpty
                ? brandCtx['brandName']!
                : (r.brandName.trim().isEmpty ? 'Brand' : r.brandName.trim());
            final brandEmail = (brandCtx['brandEmail'] ?? '')
                .trim()
                .toLowerCase();
            final brandEmails = (brandCtx['brandEmailsCsv'] ?? '')
                .split(',')
                .map((e) => e.trim().toLowerCase())
                .where((e) => e.isNotEmpty && e.contains('@'))
                .toSet();
            if (brandEmail.isNotEmpty) {
              brandEmails.add(brandEmail);
            }
            final acceptedClientEmail = (brandCtx['acceptedClientEmail'] ?? '')
                .trim()
                .toLowerCase();
            final artistName =
                (FirebaseAuth.instance.currentUser?.displayName ?? '')
                    .trim()
                    .isNotEmpty
                ? (FirebaseAuth.instance.currentUser?.displayName ?? '').trim()
                : (FirebaseAuth.instance.currentUser?.email ?? 'Artist')
                      .split('@')
                      .first;
            final shippedOnText =
                '${shippedDate.month.toString().padLeft(2, '0')}/${shippedDate.day.toString().padLeft(2, '0')}/${shippedDate.year}';
            final shippedMessage =
                '$artistName has shipped your $campaignName on $shippedOnText';
            if (isBrandRequest) {
              for (final receiver in brandEmails) {
                await NotificationsService.createUserNotification(
                  receiverEmail: receiver,
                  title: 'Brand Request Shipped',
                  body: shippedMessage,
                  type: 'brand_request_shipped_brand',
                  orderId: r.id,
                  orderNumber: r.orderNumber,
                  sourceCollection: r.sourceCollection,
                );
              }
              if (acceptedClientEmail.isNotEmpty) {
                await NotificationsService.createUserNotification(
                  receiverEmail: acceptedClientEmail,
                  title: 'Brand Request Shipped',
                  body: shippedMessage,
                  type: 'brand_request_shipped_client',
                  orderId: r.id,
                  orderNumber: r.orderNumber,
                  sourceCollection: r.sourceCollection,
                );
              }
              await NotificationsService.notifyAdmins(
                title: 'Brand Request Shipped',
                body:
                    '$artistName has shipped $brandCompanyName $campaignName brand request $orderRef to $acceptedClientName',
                type: 'brand_request_shipped_admin',
                orderId: r.id,
                orderNumber: r.orderNumber,
                sourceCollection: r.sourceCollection,
              );
              return;
            }
            if (clientEmail.isNotEmpty) {
              final trackingUrl =
                  'https://jnt-app-c3097.web.app/open-app?type=track-order&orderId=${Uri.encodeComponent(r.id)}';
              await NotificationsService.createUserNotification(
                receiverEmail: clientEmail,
                title: 'Order Shipped',
                body: shippedMessage,
                type: 'order_shipped',
                orderId: r.id,
                orderNumber: r.orderNumber,
                sourceCollection: r.sourceCollection,
              );
              await NotificationsService.queueTemplatedEmail(
                to: clientEmail,
                templateName: 'client_order_shipped',
                data: <String, dynamic>{
                  'clientName': r.clientName.trim().isEmpty
                      ? 'Client'
                      : r.clientName.trim(),
                  'orderId': orderRef,
                  'orderNumber': orderRef,
                  'carrierName': courier,
                  'trackingNumber': tracking,
                  'estimatedDelivery': '',
                  'trackingUrl': trackingUrl,
                },
              );
            }
          },
    );
  }

  Future<void> _openShippedDetails(ClientRequestV2 r) async {
    await showShippedRequestSheet(
      context: context,
      request: r,
      onClose: () => Navigator.pop(context),
      onMarkDelivered: () async {
        // 1) update local UI
        final updated = r.copyWith(
          status: RequestStatusV2.delivered,
          deliveredAt: DateTime.now(),
        );
        _replaceById(r.id, updated);
        await _persistStatusUpdate(
          request: r,
          status: 'delivered',
          summaryExtra: {'deliveredAt': FieldValue.serverTimestamp()},
        );
        final clientEmail = r.clientEmail.trim().toLowerCase();
        final orderRef = r.orderNumber.trim().isNotEmpty
            ? r.orderNumber.trim()
            : r.id;
        final isBrandRequest =
            r.sourceCollection == 'Company_Custom_Requests' ||
            orderRef.toUpperCase().startsWith('BE-') ||
            orderRef.toUpperCase().startsWith('BR-');
        final brandCtx = isBrandRequest
            ? await _loadBrandNotificationContext(r)
            : const <String, String>{};
        final campaignName = (brandCtx['campaignName'] ?? '').trim().isNotEmpty
            ? brandCtx['campaignName']!
            : (r.title.trim().isEmpty ? 'Campaign' : r.title.trim());
        final acceptedClientName =
            (brandCtx['acceptedClientName'] ?? '').trim().isNotEmpty
            ? brandCtx['acceptedClientName']!
            : (r.acceptedClientName.trim().isEmpty
                  ? (r.clientName.trim().isEmpty
                        ? 'Client'
                        : r.clientName.trim())
                  : r.acceptedClientName.trim());
        final brandEmail = (brandCtx['brandEmail'] ?? '').trim().toLowerCase();
        final brandEmails = (brandCtx['brandEmailsCsv'] ?? '')
            .split(',')
            .map((e) => e.trim().toLowerCase())
            .where((e) => e.isNotEmpty && e.contains('@'))
            .toSet();
        if (brandEmail.isNotEmpty) {
          brandEmails.add(brandEmail);
        }
        final acceptedClientEmail = (brandCtx['acceptedClientEmail'] ?? '')
            .trim()
            .toLowerCase();
        final artistEmail = (FirebaseAuth.instance.currentUser?.email ?? '')
            .trim()
            .toLowerCase();
        brandEmails.remove(acceptedClientEmail);
        if (isBrandRequest) {
          for (final receiver in brandEmails) {
            await NotificationsService.createUserNotification(
              receiverEmail: receiver,
              title: 'Brand Request Delivered',
              body:
                  'Delivered: $campaignName brand request $orderRef to $acceptedClientName',
              type: 'brand_request_delivered_brand',
              orderId: r.id,
              orderNumber: r.orderNumber,
              sourceCollection: r.sourceCollection,
            );
          }
          if (artistEmail.isNotEmpty) {
            await NotificationsService.createUserNotification(
              receiverEmail: artistEmail,
              title: 'Brand Request Delivered',
              body:
                  'You marked $campaignName brand request $orderRef as delivered to $acceptedClientName',
              type: 'brand_request_delivered_artist',
              orderId: r.id,
              orderNumber: r.orderNumber,
              sourceCollection: r.sourceCollection,
            );
          }
          if (acceptedClientEmail.isNotEmpty) {
            await NotificationsService.createUserNotification(
              receiverEmail: acceptedClientEmail,
              title: 'Brand Request Delivered',
              body:
                  'Your $campaignName Brand request $orderRef has been delivered',
              type: 'brand_request_delivered_client',
              orderId: r.id,
              orderNumber: r.orderNumber,
              sourceCollection: r.sourceCollection,
            );
          }
          await NotificationsService.notifyArtistPoolBrandDelivered(
            clientName: acceptedClientName,
            campaignName: campaignName,
            orderId: r.id,
            sourceCollection: r.sourceCollection,
            orderNumber: r.orderNumber,
            excludeArtistEmails: artistEmail.isEmpty
                ? const <String>[]
                : <String>[artistEmail],
          );
          await NotificationsService.notifyAdmins(
            title: 'Brand Request Delivered',
            body:
                'Delivered: $campaignName brand request $orderRef to $acceptedClientName',
            type: 'brand_request_delivered_admin',
            orderId: r.id,
            orderNumber: r.orderNumber,
            sourceCollection: r.sourceCollection,
          );
          return;
        }
        if (clientEmail.isNotEmpty) {
          final artistName = r.selectedArtist.trim().isNotEmpty
              ? r.selectedArtist.trim()
              : (r.acceptedByArtistEmail.trim().isNotEmpty
                    ? r.acceptedByArtistEmail.trim().split('@').first
                    : 'Your artist');
          final deliveredDate = DateTime.now().toIso8601String();
          final tracking = r.trackingNumber?.trim().isNotEmpty == true
              ? r.trackingNumber!.trim()
              : (r.shippingLabelTrackingNumber.trim().isNotEmpty
                    ? r.shippingLabelTrackingNumber.trim()
                    : '');
          final reviewUrl =
              'https://jnt-app-c3097.web.app/open-app?type=review-order&orderId=${Uri.encodeComponent(r.id)}';
          final appLink =
              'https://jnt-app-c3097.web.app/open-app?type=order-details&orderId=${Uri.encodeComponent(r.id)}';
          final deepLink = reviewUrl;
          await NotificationsService.createUserNotification(
            receiverEmail: clientEmail,
            title: 'Order Delivered: Review & Tip',
            body:
                'Your order has been delivered. Open the app to leave a rating, comments, and tip your artist.',
            type: 'delivered_review_prompt',
            orderId: r.id,
            orderNumber: r.orderNumber,
            sourceCollection: r.sourceCollection,
            extra: <String, dynamic>{
              'deepLink': deepLink,
              'action': 'review_tip',
            },
          );
          await NotificationsService.queueTemplatedEmail(
            to: clientEmail,
            templateName: 'client_order_delivered_review_tip',
            data: <String, dynamic>{
              'clientName': r.clientName.trim().isEmpty
                  ? 'Client'
                  : r.clientName.trim(),
              'orderId': orderRef,
              'artistName': artistName,
              'deliveredDate': deliveredDate,
              'trackingNumber': tracking,
              'reviewUrl': reviewUrl,
              'tip10Url': '$reviewUrl&tip=10',
              'tip15Url': '$reviewUrl&tip=15',
              'tip20Url': '$reviewUrl&tip=20',
              'appLink': appLink,
            },
          );
        }
      },
    );
  }

  Future<void> _openBudgetSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.blackCat,
      isScrollControlled: true,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          decoration: const BoxDecoration(
            color: AppColors.alabaster,
            borderRadius: BorderRadius.zero,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 5,
                width: 54,
                decoration: BoxDecoration(
                  color: AppColors.blackCat.withOpacity(0.12),
                  borderRadius: BorderRadius.zero,
                ),
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Budget',
                  style: TextStyle(fontWeight: FontWeight.w400, fontSize: 12),
                ),
              ),
              const SizedBox(height: 10),

              // Text fields
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _budgetMinCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _syncBudgetFromText(),
                      decoration: _miniDec(prefix: '\$', hint: 'Min'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _budgetMaxCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _syncBudgetFromText(),
                      decoration: _miniDec(prefix: '\$', hint: 'Max'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Slider
              RangeSlider(
                values: _budgetRange,
                min: 15,
                max: 5000,
                divisions: 4985,
                activeColor: AppColors.blackCat,
                labels: RangeLabels(
                  '\$${_budgetRange.start.round()}',
                  '\$${_budgetRange.end.round()}',
                ),
                onChanged: (v) {
                  setState(() => _budgetRange = v);
                  _budgetMinCtrl.text = _budgetRange.start.round().toString();
                  _budgetMaxCtrl.text = _budgetRange.end.round().toString();
                },
              ),

              const SizedBox(height: 8),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blackCat,
                    foregroundColor: AppColors.snow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Apply',
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      fontFamily: 'Arial',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openCancelledDetails(ClientRequestV2 r) async {
    await showSimpleStatusRequestSheet(
      context: context,
      request: r,
      status: SimpleRequestStatus.cancelled,
      // pick whatever date you track; fallback is ok for now
      date: DateTime.now(),
    );
  }

  Future<void> _openDeclinedDetails(ClientRequestV2 r) async {
    await showSimpleStatusRequestSheet(
      context: context,
      request: r,
      status: SimpleRequestStatus.declined,
      date: DateTime.now(),
    );
  }

  Future<void> _openExpiredDetails(ClientRequestV2 r) async {
    await showSimpleStatusRequestSheet(
      context: context,
      request: r,
      status: SimpleRequestStatus.expired,
      date: DateTime.now(),
    );
  }

  Widget _shippingChip() {
    final label = switch (_shipFilter) {
      ShipTimeFilter.any => 'Ship Time',
      ShipTimeFilter.upTo2Days => 'Up to 2 days',
      ShipTimeFilter.upTo3Days => 'Up to 3 days',
      ShipTimeFilter.upTo5Days => 'Up to 5 days',
    };

    return CompositedTransformTarget(
      link: _shipLink,
      child: InkWell(
        borderRadius: BorderRadius.zero,
        onTap: () {
          if (_dropdownEntry != null) {
            _closeDropdown();
          } else {
            _showShipDropdown();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.snow,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: AppColors.blackCatBorderLight),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.local_shipping_outlined,
                size: 16,
                color: AppColors.blackCat.withOpacity(0.70),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: _t(12, w: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: AppColors.blackCat.withOpacity(0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDropdown({
    required LayerLink link,
    required Widget child,
    double yOffset = 8,
  }) {
    _closeDropdown();

    _dropdownEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // tap outside to close
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeDropdown,
                behavior: HitTestBehavior.translucent,
                child: const SizedBox(),
              ),
            ),

            // anchored dropdown
            CompositedTransformFollower(
              link: link,
              showWhenUnlinked: false,
              offset: Offset(0, yOffset),
              child: Material(color: AppColors.blackCat, child: child),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_dropdownEntry!);
  }

  void _showShipDropdown() {
    _showDropdown(
      link: _shipLink,
      child: _DropdownCard(
        width: 220, // tweak as you like
        children: [
          _DropItem(
            text: 'Any',
            onTap: () {
              setState(() => _shipFilter = ShipTimeFilter.any);
              _closeDropdown();
            },
          ),
          _DropItem(
            text: 'Up to 2 days',
            onTap: () {
              setState(() => _shipFilter = ShipTimeFilter.upTo2Days);
              _closeDropdown();
            },
          ),
          _DropItem(
            text: 'Up to 3 days',
            onTap: () {
              setState(() => _shipFilter = ShipTimeFilter.upTo3Days);
              _closeDropdown();
            },
          ),
          _DropItem(
            text: 'Up to 5 days',
            onTap: () {
              setState(() => _shipFilter = ShipTimeFilter.upTo5Days);
              _closeDropdown();
            },
          ),
        ],
      ),
    );
  }

  RelativeRect _popupPosition(GlobalKey key) {
    final renderBox = key.currentContext!.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

    final topLeft = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final size = renderBox.size;

    // show menu just under the chip
    return RelativeRect.fromRect(
      Rect.fromLTWH(topLeft.dx, topLeft.dy + size.height + 6, size.width, 0),
      Offset.zero & overlay.size,
    );
  }

  Future<void> _openShipMenu() async {
    final pos = _popupPosition(_shipKey);

    final selected = await showMenu<ShipTimeFilter>(
      context: context,
      position: pos,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      items: const [
        PopupMenuItem(value: ShipTimeFilter.any, child: Text('Any')),
        PopupMenuItem(
          value: ShipTimeFilter.upTo2Days,
          child: Text('Up to 2 days'),
        ),
        PopupMenuItem(
          value: ShipTimeFilter.upTo3Days,
          child: Text('Up to 3 days'),
        ),
        PopupMenuItem(
          value: ShipTimeFilter.upTo5Days,
          child: Text('Up to 5 days'),
        ),
      ],
    );

    if (selected != null) setState(() => _shipFilter = selected);
  }

  Future<void> _openInReviewDetails(ClientRequestV2 r) async {
    final request = await _hydrateRequestForDetails(r);
    if (!mounted) return;

    if (widget.showOnlyCompanyRequests) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: AppColors.blackCat,
        builder: (_) => ClientRequestDetailsPage(
          request: request,
          declineLabel: 'Decline',
          acceptLabel: 'Accept',
          onDecline: () async {
            Navigator.pop(context);
            try {
              await _persistClientPoolResponse(request: request, accept: false);
              _removeRequestLocally(request.id);
              unawaited(_loadRequestsFromDb());
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to cancel request: $e')),
              );
            }
          },
          onAccept: () async {
            try {
              await _persistClientPoolResponse(request: request, accept: true);
              if (!mounted) return;
              Navigator.pop(context);
              _replaceById(
                request.id,
                request.copyWith(
                  status: RequestStatusV2.inReview,
                  acceptedByClientEmail:
                      (FirebaseAuth.instance.currentUser?.email ?? '')
                          .trim()
                          .toLowerCase(),
                ),
              );
              unawaited(_loadRequestsFromDb());
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to accept request: $e')),
              );
            }
          },
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.blackCat,
      builder: (_) => InReviewDetailsSheet(
        request: request,
        onDecline: () async {
          Navigator.pop(context);
          try {
            _removeRequestLocally(request.id);
            await _persistArtistDecline(request);
            unawaited(_loadRequestsFromDb());
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to decline request: $e')),
            );
          }
        },
        onAccept: () async {
          final accepted = await showModalBottomSheet<_AcceptResult>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            useRootNavigator: true,
            backgroundColor: AppColors.blackCat,
            builder: (_) => AcceptRequestDialogV2(
              budgetMin: request.budgetMin,
              budgetMax: request.budgetMax,
            ),
          );

          if (accepted != null) {
            try {
              final persisted = await _persistArtistAcceptance(
                request,
                accepted,
              );
              if (!persisted) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Could not update request in database.'),
                  ),
                );
                return;
              }

              if (!mounted) return;
              Navigator.pop(context);
              final acceptedTotal =
                  accepted.yourPrice + accepted.shipping + accepted.extra;
              _replaceById(
                request.id,
                request.copyWith(
                  status: RequestStatusV2.designing,
                  artistFinalAmount: double.parse(
                    acceptedTotal.toStringAsFixed(2),
                  ),
                ),
              );
              _loadRequestsFromDb();
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to accept request: $e')),
              );
            }
          }
        },
      ),
    );
  }

  Future<ShipTimeFilter?> _openShipSheet() async {
    return showModalBottomSheet<ShipTimeFilter>(
      context: context,
      backgroundColor: AppColors.blackCat,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          decoration: const BoxDecoration(
            color: AppColors.alabaster,
            borderRadius: BorderRadius.zero,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 5,
                width: 54,
                decoration: BoxDecoration(
                  color: AppColors.blackCat.withOpacity(0.12),
                  borderRadius: BorderRadius.zero,
                ),
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Shipping time',
                  style: TextStyle(fontWeight: FontWeight.w400, fontSize: 12),
                ),
              ),
              const SizedBox(height: 10),
              _sheetOption('Any', ShipTimeFilter.any),
              _sheetOption('Up to 2 days', ShipTimeFilter.upTo2Days),
              _sheetOption('Up to 3 days', ShipTimeFilter.upTo3Days),
              _sheetOption('Up to 5 days', ShipTimeFilter.upTo5Days),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _sheetOption(String label, ShipTimeFilter v) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      tileColor: AppColors.snow,
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => Navigator.pop(context, v),
    );
  }

  Widget _sortChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          style: _t(
            12,
            w: FontWeight.w700,
            c: AppColors.blackCat.withOpacity(0.85),
          ),
          value: _sort,
          isExpanded: true,
          borderRadius: BorderRadius.zero,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.blackCat.withOpacity(0.5),
          ),
          items: const [
            DropdownMenuItem(value: 'Newest', child: Text('Sort: Newest')),
            DropdownMenuItem(
              value: 'Soonest needed',
              child: Text('Sort: Soonest needed'),
            ),
            DropdownMenuItem(
              value: 'Higher budget',
              child: Text('Sort: Higher budget'),
            ),
          ],
          onChanged: (v) => setState(() => _sort = v ?? 'Newest'),
        ),
      ),
    );
  }

  InputDecoration _miniDec({String? prefix, String? hint}) {
    return InputDecoration(
      prefixText: prefix,
      prefixStyle: TextStyle(
        color: AppColors.blackCat.withOpacity(0.78),
        fontWeight: FontWeight.w600,
      ),
      hintText: hint,
      hintStyle: TextStyle(
        color: AppColors.blackCat.withOpacity(0.45),
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: AppColors.snow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _statusTabs() {
    final activeIndex = _tabCtrl.index;
    return TabBar(
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      controller: _tabCtrl,
      dividerColor: Colors.transparent,
      labelPadding: const EdgeInsets.only(left: 0, right: 14),
      onTap: (_) => setState(() {}),
      indicator: const UnderlineTabIndicator(
        borderSide: BorderSide(color: AppColors.alabaster, width: 3),
      ),
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      labelColor: AppColors.blackCat,
      unselectedLabelColor: AppColors.blackCat,
      tabs: [
        _statusTab(
          'All',
          _countForAllActive(), // ✅ new helper below
          activeIndex == 0,
        ),
        _statusTab(
          'In Review',
          _countForStatus(RequestStatusV2.inReview),
          activeIndex == 1,
        ),
        _statusTab('Designing', _countForDesigningTab(), activeIndex == 2),
        _statusTab(
          'Completed',
          _countForStatus(RequestStatusV2.completed),
          activeIndex == 3,
        ),
        _statusTab(
          'Shipped',
          _countForStatus(RequestStatusV2.shipped),
          activeIndex == 4,
        ),

        // -------------------------------------------------
        // KEEP THESE BUT COMMENTED (per your request)
        // -------------------------------------------------
        /*
          _statusTab(
            'Delivered',
            _countForStatus(RequestStatusV2.delivered),
            activeIndex == 5,
          ),
          _statusTab(
            'Declined',
            _countForStatus(RequestStatusV2.declined),
            activeIndex == 6,
          ),
          _statusTab(
            'Cancelled',
            _countForStatus(RequestStatusV2.cancelled),
            activeIndex == 7,
          ),
          _statusTab(
            'Expired',
            _countForStatus(RequestStatusV2.expired),
            activeIndex == 8,
          ),
          */
      ],
    );
  }

  Widget _tabList(int tabIndex) {
    if (!_hasLoadedRequests && !_isLoadingDb && _all.isEmpty) {
      if (!_initialLoadScheduled) {
        _initialLoadScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(_loadRequestsFromDb());
        });
      }
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_isLoadingDb && _all.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    final items = _filteredForTab(tabIndex);

    if (items.isEmpty) {
      return Center(
        child: Text(
          'No requests in this status',
          style: TextStyle(
            color: AppColors.blackCat.withOpacity(0.55),
            fontWeight: FontWeight.w400,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _requestCard(items[i]),
    );
  }

  bool _truthyNfcValue(Object? value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value.toString().trim().toLowerCase();
    return normalized == 'true' ||
        normalized == 'yes' ||
        normalized == '1' ||
        normalized == 'selected' ||
        normalized == 'requested' ||
        normalized == 'enabled';
  }

  Map<String, dynamic> _asStringMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
  }

  bool _isNfcKey(String key) {
    final normalized = key.trim().toLowerCase();
    return normalized == 'nfc' ||
        normalized == 'hasnfc' ||
        normalized == 'nfcenabled' ||
        normalized == 'nfcselected' ||
        normalized == 'nfcrequested' ||
        normalized == 'nfccount' ||
        normalized.endsWith('nfc') ||
        normalized.contains('nfc');
  }

  bool _isNfcEligibleKey(String key) {
    final normalized = key.trim().toLowerCase();
    return normalized == 'nfceligible' ||
        normalized == 'eligiblefornfc' ||
        normalized == 'nfceligibleclient' ||
        normalized == 'hasnfceligibility';
  }

  bool _containsRequestedNfc(Object? value) {
    if (value == null) return false;
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString();
        final entryValue = entry.value;
        if (_isNfcKey(key) && _truthyNfcValue(entryValue)) return true;
        if (entryValue is Map || entryValue is List) {
          if (_containsRequestedNfc(entryValue)) return true;
        }
      }
      return false;
    }
    if (value is List) {
      for (final item in value) {
        if (_containsRequestedNfc(item)) return true;
      }
    }
    return false;
  }

  bool _containsExplicitNfcEligible(Object? value) {
    if (value == null) return false;
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString();
        final entryValue = entry.value;
        if (_isNfcEligibleKey(key) && _truthyNfcValue(entryValue)) return true;
        if (entryValue is Map || entryValue is List) {
          if (_containsExplicitNfcEligible(entryValue)) return true;
        }
      }
      return false;
    }
    if (value is List) {
      for (final item in value) {
        if (_containsExplicitNfcEligible(item)) return true;
      }
    }
    return false;
  }

  double? _nfcDimensionMm(Object? value) {
    final cleaned = (value ?? '')
        .toString()
        .replaceAll(RegExp(r'[^0-9.]'), '')
        .trim();
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  bool _hasEligibleDimension(Object? value) {
    const dimensionKeys = <String>{
      'thumb',
      'index',
      'middle',
      'ring',
      'pinky',
      'lthumb',
      'lindex',
      'lmiddle',
      'lring',
      'lpinky',
      'rthumb',
      'rindex',
      'rmiddle',
      'rring',
      'rpinky',
    };
    if (value == null) return false;
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString().trim().toLowerCase();
        final entryValue = entry.value;
        if (dimensionKeys.contains(key) &&
            (_nfcDimensionMm(entryValue) ?? 0) >= 8) {
          return true;
        }
        if (entryValue is Map || entryValue is List) {
          if (_hasEligibleDimension(entryValue)) return true;
        }
      }
      return false;
    }
    if (value is List) {
      for (final item in value) {
        if (_hasEligibleDimension(item)) return true;
      }
    }
    return false;
  }

  bool _mapHasEligibleSelectedNfcFinger(Map<String, dynamic> map) {
    bool selectedFor(String key) {
      final nfc = map['nfc'];
      if (_truthyNfcValue(map['${key}Nfc'])) return true;
      if (nfc is Map) {
        return _truthyNfcValue(nfc[key]) || _truthyNfcValue(nfc['${key}Nfc']);
      }
      return false;
    }

    bool eligibleSelected(String key) {
      final valueMm = _nfcDimensionMm(map[key]);
      return selectedFor(key) && valueMm != null && valueMm >= 8;
    }

    for (final key in const <String>[
      'lThumb',
      'lIndex',
      'lMiddle',
      'lRing',
      'lPinky',
      'rThumb',
      'rIndex',
      'rMiddle',
      'rRing',
      'rPinky',
      'thumb',
      'index',
      'middle',
      'ring',
      'pinky',
    ]) {
      if (eligibleSelected(key)) return true;
    }
    return false;
  }

  bool _hasEligibleSelectedNfcFinger(Object? value) {
    if (value == null) return false;
    if (value is Map) {
      final map = _asStringMap(value);
      if (_mapHasEligibleSelectedNfcFinger(map)) return true;
      for (final entryValue in map.values) {
        if (entryValue is Map || entryValue is List) {
          if (_hasEligibleSelectedNfcFinger(entryValue)) return true;
        }
      }
      return false;
    }
    if (value is List) {
      for (final item in value) {
        if (_hasEligibleSelectedNfcFinger(item)) return true;
      }
    }
    return false;
  }

  bool _requestModelHasEligibleDimension(ClientRequestV2 request) {
    return (_nfcDimensionMm(request.leftHand.thumb) ?? 0) >= 8 ||
        (_nfcDimensionMm(request.leftHand.index) ?? 0) >= 8 ||
        (_nfcDimensionMm(request.leftHand.middle) ?? 0) >= 8 ||
        (_nfcDimensionMm(request.leftHand.ring) ?? 0) >= 8 ||
        (_nfcDimensionMm(request.leftHand.pinky) ?? 0) >= 8 ||
        (_nfcDimensionMm(request.rightHand.thumb) ?? 0) >= 8 ||
        (_nfcDimensionMm(request.rightHand.index) ?? 0) >= 8 ||
        (_nfcDimensionMm(request.rightHand.middle) ?? 0) >= 8 ||
        (_nfcDimensionMm(request.rightHand.ring) ?? 0) >= 8 ||
        (_nfcDimensionMm(request.rightHand.pinky) ?? 0) >= 8;
  }

  Future<bool> _requestHasNfc(ClientRequestV2 request) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection(request.sourceCollection)
          .doc(request.id);
      final rootSnap = await docRef.get();
      final rootData = rootSnap.data() ?? const <String, dynamic>{};
      final detailsSnap = await docRef
          .collection('details')
          .doc('payload')
          .get();
      final detailsData = detailsSnap.data() ?? const <String, dynamic>{};

      final requested =
          _containsRequestedNfc(rootData) || _containsRequestedNfc(detailsData);
      if (!requested) return false;

      // Preferred: if the submitted payload has per-finger NFC flags, show the
      // card chip only when one of those selected fingers is actually 8mm+.
      if (_hasEligibleSelectedNfcFinger(rootData) ||
          _hasEligibleSelectedNfcFinger(detailsData)) {
        return true;
      }

      // Fallback for older saved requests: require explicit eligibility or a
      // stored/profile nail dimension of 8mm+ before showing NFC.
      final eligible =
          _containsExplicitNfcEligible(rootData) ||
          _containsExplicitNfcEligible(detailsData) ||
          _hasEligibleDimension(rootData) ||
          _hasEligibleDimension(detailsData) ||
          _requestModelHasEligibleDimension(request);

      return eligible;
    } catch (_) {
      return false;
    }
  }

  Widget _nfcChip(BuildContext context) {
    final s = _reqScale(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: const BoxDecoration(
        color: AppColors.balletSlippers,
        borderRadius: BorderRadius.zero,
      ),
      child: Text(
        'NFC',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 11 * s,
          color: AppColors.blackCat,
          height: 1.05,
        ),
      ),
    );
  }

  Widget _requestCard(ClientRequestV2 r) {
    if (widget.showOnlyCompanyRequests) {
      return _companyRequestCard(r);
    }
    final s = _reqScale(context);
    final isInReview = r.status == RequestStatusV2.inReview;

    return InkWell(
      borderRadius: BorderRadius.zero,
      onTap: () {
        if (r.status == RequestStatusV2.inReview) {
          _openInReviewDetails(r);
        } else if (r.status == RequestStatusV2.accepted ||
            r.status == RequestStatusV2.designing) {
          _openDesigningDetails(r);
        } else if (r.status == RequestStatusV2.completed) {
          _openCompletedDetails(r);
        } else if (r.status == RequestStatusV2.shipped) {
          _openShippedDetails(r);
        }

        // -------------------------------------------------
        // KEEP THESE BUT COMMENTED (per your request)
        // -------------------------------------------------
        /*
        else if (r.status == RequestStatusV2.delivered) {
          showDeliveredRequestSheet(context: context, request: r);
        } else if (r.status == RequestStatusV2.cancelled) {
          _openCancelledDetails(r);
        } else if (r.status == RequestStatusV2.declined) {
          _openDeclinedDetails(r);
        } else if (r.status == RequestStatusV2.expired) {
          _openExpiredDetails(r);
        }
        */
      },

      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.snow,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: AppColors.blackCatBorderLight),
          boxShadow: [
            BoxShadow(
              color: AppColors.blackCat.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Avatar stacked above name (left column)
            SizedBox(width: 62, child: Column(children: [_clientAvatar(r, s)])),

            const SizedBox(width: 12),

            // Middle content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // title row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.sourceCollection == 'Company_Custom_Requests' &&
                                  r.brandName.trim().isNotEmpty
                              ? r.brandName.trim()
                              : r.clientName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14 * s,
                            color: AppColors.blackCat,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (r.sourceCollection == 'Company_Custom_Requests') ...[
                    const SizedBox(height: 4),
                    Text(
                      r.title.trim().isEmpty ? 'Campaign' : r.title.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.blackCat.withOpacity(0.72),
                        fontWeight: FontWeight.w500,
                        fontSize: 12.5 * s,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.blackCat),
                        color: AppColors.snow,
                      ),
                      child: Text(
                        'Brand Request',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 10.5 * s,
                          color: AppColors.blackCat,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'Order # ${r.orderNumber.trim().isNotEmpty ? r.orderNumber.trim() : r.id}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.blackCat.withOpacity(0.72),
                      fontWeight: FontWeight.w500,
                      fontSize: 12.5 * s,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Need by ${_formatNeedBy(r.neededBy)}',
                    style: TextStyle(
                      color: AppColors.blackCat.withOpacity(0.72),
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5 * s,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      const Icon(
                        Icons.attach_money_rounded,
                        size: 16,
                        color: AppColors.blackCat,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '\$${r.budgetMin} - \$${r.budgetMax}',
                          style: _t(
                            11.5,
                            w: FontWeight.w700,
                            c: AppColors.blackCat,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        size: 16,
                        color: AppColors.blackCat,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          r.isDirectRequest ? 'Direct' : 'Standard',
                          style: _t(
                            11.5,
                            w: FontWeight.w700,
                            c: AppColors.blackCat,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.groups_2_outlined,
                        size: 16,
                        color: AppColors.blackCat,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          r.orderType == RequestOrderTypeV2.group
                              ? 'Group Order'
                              : 'Single Order',
                          style: _t(
                            11.5,
                            w: FontWeight.w700,
                            c: AppColors.blackCat,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Right preview image + status text
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  r.status.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.blackCat,
                    fontSize: 14 * s,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: Container(
                    height: 64,
                    width: 84,
                    color: AppColors.blackCat.withOpacity(0.05),
                    child: _requestPreviewImage(r),
                  ),
                ),
                FutureBuilder<bool>(
                  future: _requestHasNfc(r),
                  builder: (context, snapshot) {
                    if (snapshot.data != true) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _nfcChip(context),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _companyRequestCard(ClientRequestV2 r) {
    final s = _reqScale(context);
    final displayStatus = _companyRequestStatus(r);
    return FutureBuilder<bool>(
      future: _requestHasNfc(r),
      builder: (context, snapshot) {
        return CompanyClientRequestCard(
          request: r,
          scale: s,
          displayStatus: displayStatus,
          needByLabel: _shortDate(r.neededBy),
          submittedLabel: _shortDate(r.submittedAt ?? r.neededBy),
          avatar: _clientAvatar(r, s),
          previewImage: _requestPreviewImage(r),
          showNfcChip: snapshot.data == true,
          onTap: () {
            if (r.status == RequestStatusV2.inReview) {
              _openInReviewDetails(r);
            } else if (r.status == RequestStatusV2.accepted ||
                r.status == RequestStatusV2.designing) {
              _openDesigningDetails(r);
            } else if (r.status == RequestStatusV2.completed) {
              _openCompletedDetails(r);
            } else if (r.status == RequestStatusV2.shipped) {
              _openShippedDetails(r);
            }
          },
        );
      },
    );
  }

  Widget _clientAvatar(ClientRequestV2 r, double s) {
    final photo = r.clientProfileImage.trim();

    Widget initialFallback() {
      final letter = r.clientName.isEmpty ? 'C' : r.clientName[0].toUpperCase();
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.balletSlippers,
          borderRadius: BorderRadius.zero,
        ),
        alignment: Alignment.center,
        child: Text(
          letter,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16 * s,
            color: AppColors.blackCat,
          ),
        ),
      );
    }

    Widget boxedImage(ImageProvider provider) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.zero,
          image: DecorationImage(image: provider, fit: BoxFit.cover),
        ),
      );
    }

    Widget imageFromPath(String path) {
      final p = _normalizeImagePath(path);
      final dataBytes = _decodeDataImageBytes(p);
      final isNetwork =
          p.startsWith('http://') ||
          p.startsWith('https://') ||
          p.startsWith('blob:') ||
          p.startsWith('content://');
      final isAsset = p.startsWith('assets/');
      final isFileUri = p.startsWith('file://');
      final isFilePath = !kIsWeb && (p.startsWith('/') || p.contains(':\\'));
      final isStorageRef = _looksLikeStorageRef(p);

      if (p.startsWith('gs://') || isStorageRef) {
        return FutureBuilder<String>(
          future: p.startsWith('gs://')
              ? StorageUrlResolver.resolve(p).then((v) => v ?? '')
              : StorageUrlResolver.resolve(p).then((v) => v ?? ''),
          builder: (_, snap) {
            final url = snap.data?.trim() ?? '';
            if (url.isNotEmpty) return boxedImage(NetworkImage(url));
            return FutureBuilder<Uint8List?>(
              future: _readStorageBytes(p),
              builder: (_, bytesSnap) {
                final bytes = bytesSnap.data;
                if (bytes == null || bytes.isEmpty) return initialFallback();
                return boxedImage(MemoryImage(bytes));
              },
            );
          },
        );
      }

      if (dataBytes != null) {
        return boxedImage(MemoryImage(dataBytes));
      }

      if (isNetwork) {
        return boxedImage(NetworkImage(p));
      }

      if (isAsset) {
        return boxedImage(AssetImage(p));
      }

      if (isFileUri || isFilePath) {
        final localPath = isFileUri ? p.replaceFirst('file://', '') : p;
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.zero,
            image: DecorationImage(
              image: FileImage(File(localPath)),
              fit: BoxFit.cover,
            ),
          ),
        );
      }

      return initialFallback();
    }

    return Container(
      height: 46,
      width: 46,
      decoration: BoxDecoration(
        color: AppColors.balletSlippers,
        borderRadius: BorderRadius.zero,
      ),
      clipBehavior: Clip.antiAlias,
      child: photo.isNotEmpty ? imageFromPath(photo) : initialFallback(),
    );
  }

  Widget _requestPreviewImage(ClientRequestV2 r) {
    String pickFirstPhoto(List<String> images, String fallback) {
      for (final raw in images) {
        final s = raw.trim();
        if (s.isNotEmpty) return s;
      }
      return fallback.trim();
    }

    final trimmed = _normalizeImagePath(
      pickFirstPhoto(r.clientImages, r.previewImageAsset),
    );
    final dataBytes = _decodeDataImageBytes(trimmed);
    final isNet =
        trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('gs://') ||
        trimmed.startsWith('blob:') ||
        trimmed.startsWith('content://');
    final isAsset = trimmed.startsWith('assets/');
    final isFileUri = trimmed.startsWith('file://');
    final isFilePath =
        !kIsWeb && (trimmed.startsWith('/') || trimmed.contains(':\\'));
    final isStorageRef = _looksLikeStorageRef(trimmed);

    if (trimmed.startsWith('gs://') || isStorageRef) {
      return FutureBuilder<String>(
        future: trimmed.startsWith('gs://')
            ? StorageUrlResolver.resolve(trimmed).then((v) => v ?? '')
            : StorageUrlResolver.resolve(trimmed).then((v) => v ?? ''),
        builder: (_, snap) {
          final url = snap.data?.trim() ?? '';
          if (url.isNotEmpty) {
            return Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Icon(
                Icons.image_outlined,
                color: AppColors.blackCat.withOpacity(0.35),
              ),
            );
          }
          return FutureBuilder<Uint8List?>(
            future: _readStorageBytes(trimmed),
            builder: (_, bytesSnap) {
              final bytes = bytesSnap.data;
              if (bytes == null || bytes.isEmpty) {
                return Icon(
                  Icons.image_outlined,
                  color: AppColors.blackCat.withOpacity(0.35),
                );
              }
              return Image.memory(
                bytes,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  Icons.image_outlined,
                  color: AppColors.blackCat.withOpacity(0.35),
                ),
              );
            },
          );
        },
      );
    }
    if (dataBytes != null) {
      return Image.memory(
        dataBytes,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Icon(
          Icons.image_outlined,
          color: AppColors.blackCat.withOpacity(0.35),
        ),
      );
    }
    if (isNet) {
      return Image.network(
        trimmed,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Icon(
          Icons.image_outlined,
          color: AppColors.blackCat.withOpacity(0.35),
        ),
      );
    }

    if (isAsset) {
      return Image.asset(
        trimmed,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Icon(
          Icons.image_outlined,
          color: AppColors.blackCat.withOpacity(0.35),
        ),
      );
    }

    if (isFileUri || isFilePath) {
      final localPath = isFileUri
          ? trimmed.replaceFirst('file://', '')
          : trimmed;
      return Image.file(
        File(localPath),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Icon(
          Icons.image_outlined,
          color: AppColors.blackCat.withOpacity(0.35),
        ),
      );
    }

    return Center(
      child: Icon(
        Icons.image_outlined,
        color: AppColors.blackCat.withOpacity(0.35),
      ),
    );
  }

  Widget _pill(String text, {required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.blackCat),
          const SizedBox(width: 6),
          Text(
            text,
            style: _t(11.5, w: FontWeight.w700, c: AppColors.blackCat),
          ),
        ],
      ),
    );
  }

  Widget _countPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.blackCat.withOpacity(0.06),
        borderRadius: BorderRadius.zero,
      ),
      child: Text(
        text,
        style: _t(
          11.5,
          w: FontWeight.w700,
          c: AppColors.blackCat.withOpacity(0.8),
        ),
      ),
    );
  }

  String _formatNeedBy(DateTime d) {
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
    final wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1];
    return '$wd, ${months[d.month - 1]} ${d.day}';
  }

  String _shortDate(DateTime d) {
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
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _companyRequestStatus(ClientRequestV2 r) {
    if (r.status == RequestStatusV2.inReview &&
        r.acceptedByClientEmail.trim().isEmpty) {
      return 'Pending';
    }
    if (r.acceptedByClientEmail.trim().isNotEmpty &&
        r.acceptedByArtistEmail.trim().isEmpty) {
      return 'In Review';
    }
    return r.status.label;
  }
}

// ----------------------------------------------
// Enums / Models for this page (keep isolated)
// ----------------------------------------------
enum ShipTimeFilter { any, upTo2Days, upTo3Days, upTo5Days }

class InReviewDetailsSheet extends StatelessWidget {
  const InReviewDetailsSheet({
    super.key,
    required this.request,
    required this.onDecline,
    required this.onAccept,
    this.declineLabel = 'Decline',
    this.acceptLabel = 'Accept',
  });

  final ClientRequestV2 request;
  final VoidCallback onDecline;
  final Future<void> Function() onAccept;
  final String declineLabel;
  final String acceptLabel;
  bool _hasHeroProfileImage() {
    final path = _heroPhotoSource().trim();
    return path.isNotEmpty;
  }

  String _heroPhotoSource() {
    final profile = request.clientProfileImage.trim();
    final isBrandRequest =
        request.sourceCollection == 'Company_Custom_Requests';
    if (profile.isNotEmpty) {
      if (!isBrandRequest) return profile;
      final normalizedProfile = _normalizeImagePath(
        profile,
      ).trim().toLowerCase();
      final blocked = <String>{
        _normalizeImagePath(request.previewImageAsset).trim().toLowerCase(),
        ...request.clientImages.map(
          (e) => _normalizeImagePath(e).trim().toLowerCase(),
        ),
      }..removeWhere((e) => e.isEmpty);
      if (!blocked.contains(normalizedProfile)) return profile;
    }
    return '';
  }

  Future<List<String>> _modalPhotoCandidates() async {
    final out = <String>[];
    bool looksDirectRenderable(String raw) {
      final v = _normalizeImagePath(raw).trim().toLowerCase();
      if (v.isEmpty) return false;
      if (v.startsWith('http://') ||
          v.startsWith('https://') ||
          v.startsWith('gs://') ||
          v.startsWith('data:image/') ||
          v.startsWith('blob:') ||
          v.startsWith('content://') ||
          v.startsWith('file://') ||
          v.startsWith('assets/')) {
        return true;
      }
      return false;
    }

    Future<String> resolveIfNeeded(String raw) async {
      final normalized = _normalizeImagePath(raw).trim();
      if (normalized.isEmpty) return '';
      if (looksDirectRenderable(normalized)) return normalized;
      if (normalized.startsWith('gs://') ||
          normalized.contains('client_custom_requests/') ||
          normalized.contains('company_custom_requests/') ||
          normalized.contains('firebasestorage.googleapis.com') ||
          normalized.contains('/o/')) {
        final resolved = await StorageUrlResolver.resolve(normalized);
        final cleaned = (resolved ?? '').trim();
        if (cleaned.isNotEmpty) return cleaned;
      }
      if (normalized.endsWith('.jpg') ||
          normalized.endsWith('.jpeg') ||
          normalized.endsWith('.png') ||
          normalized.endsWith('.webp') ||
          normalized.endsWith('.heic') ||
          normalized.endsWith('.gif')) {
        final resolved = await StorageUrlResolver.resolve(normalized);
        final cleaned = (resolved ?? '').trim();
        if (cleaned.isNotEmpty) return cleaned;
      }
      return '';
    }

    Future<bool> canRenderPhoto(String raw) async {
      final normalized = _normalizeImagePath(raw).trim();
      if (normalized.isEmpty) return false;

      if (normalized.startsWith('data:image/')) {
        final bytes = _decodeDataImageBytes(normalized);
        if (bytes == null || bytes.isEmpty) return false;
        final decoded = img.decodeImage(bytes);
        return decoded != null && decoded.width > 1 && decoded.height > 1;
      }

      if (normalized.startsWith('gs://') || _looksLikeStorageRef(normalized)) {
        final bytes = await _readStorageBytes(normalized);
        if (bytes == null || bytes.isEmpty) return false;
        final decoded = img.decodeImage(bytes);
        return decoded != null && decoded.width > 1 && decoded.height > 1;
      }

      if (normalized.startsWith('http://') ||
          normalized.startsWith('https://')) {
        try {
          final uri = Uri.parse(normalized);
          final client = HttpClient()
            ..connectionTimeout = const Duration(seconds: 5);
          final request = await client.getUrl(uri);
          final response = await request.close();
          if (response.statusCode < 200 || response.statusCode >= 300) {
            client.close(force: true);
            return false;
          }
          final bytes = await response.fold<BytesBuilder>(
            BytesBuilder(),
            (builder, data) => builder..add(data),
          );
          client.close(force: true);
          final data = bytes.takeBytes();
          if (data.isEmpty) return false;
          final decoded = img.decodeImage(data);
          return decoded != null && decoded.width > 1 && decoded.height > 1;
        } catch (_) {
          return false;
        }
      }

      return true;
    }

    for (final raw in request.clientImages) {
      final resolved = await resolveIfNeeded(raw);
      if (resolved.isEmpty) continue;
      if (!await canRenderPhoto(resolved)) continue;
      final normalized = resolved.toLowerCase();
      if (!out.any((existing) => existing.toLowerCase() == normalized)) {
        out.add(resolved);
      }
    }

    if (out.isEmpty) {
      final preview = await resolveIfNeeded(request.previewImageAsset);
      if (preview.isNotEmpty && await canRenderPhoto(preview)) {
        out.add(preview);
      }
    }
    return out;
  }

  String _initialLetter() {
    final name = request.clientName.trim();
    if (name.isEmpty) return 'C';
    return name[0].toUpperCase();
  }

  Future<_RequestNfcDetails> _loadRequestedNfcDetails() async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection(request.sourceCollection)
          .doc(request.id);
      final rootSnap = await docRef.get();
      final rootData = rootSnap.data() ?? const <String, dynamic>{};
      final detailsSnap = await docRef
          .collection('details')
          .doc('payload')
          .get();
      final detailsData = detailsSnap.data() ?? const <String, dynamic>{};

      Map<String, dynamic> asMap(Object? value) {
        if (value is Map<String, dynamic>) return value;
        if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
        return const <String, dynamic>{};
      }

      List<dynamic> asList(Object? value) {
        if (value is List) return value;
        return const <dynamic>[];
      }

      final mainCandidates = <Map<String, dynamic>>[
        asMap(asMap(detailsData['nailPreferences'])['dimensions']),
        asMap(asMap(rootData['nailPreferences'])['dimensions']),
        asMap(asMap(detailsData['apiNailMeasurements'])['dimensions']),
        asMap(asMap(rootData['apiNailMeasurements'])['dimensions']),
      ];

      var main = _FingerNfcSelection.empty();
      for (final candidate in mainCandidates) {
        final parsed = _FingerNfcSelection.fromDimensionsMap(candidate);
        if (parsed.anySelected) {
          main = parsed;
          break;
        }
      }

      final groupBySlot = <int, _FingerNfcSelection>{};
      final groupSources = <dynamic>[
        asMap(detailsData['groupOrder'])['clients'],
        asMap(rootData['groupOrder'])['clients'],
        detailsData['groupClients'],
        rootData['groupClients'],
      ];

      for (final source in groupSources) {
        for (final rawClient in asList(source)) {
          final client = asMap(rawClient);
          if (client.isEmpty) continue;
          final slotIndex = _parseInt(client['slotIndex']);
          if (slotIndex == null || slotIndex <= 0) continue;

          final candidateMaps = <Map<String, dynamic>>[
            asMap(asMap(client['savedNails'])['dimensions']),
            asMap(asMap(client['draftNails'])['dimensions']),
            asMap(asMap(client['nailPreferences'])['dimensions']),
            asMap(client['dimensions']),
          ];
          for (final candidate in candidateMaps) {
            final parsed = _FingerNfcSelection.fromDimensionsMap(candidate);
            if (parsed.anySelected) {
              groupBySlot[slotIndex] = parsed;
              break;
            }
          }
        }
      }

      return _RequestNfcDetails(main: main, groupBySlotIndex: groupBySlot);
    } catch (_) {
      return _RequestNfcDetails.empty();
    }
  }

  static int? _parseInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString().trim());
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).viewPadding.bottom;
    final maxH = MediaQuery.of(context).size.height * 0.92;
    final isGroupOrder = request.orderType == RequestOrderTypeV2.group;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxH),
        decoration: const BoxDecoration(
          color: AppColors.snow,
          borderRadius: BorderRadius.zero,
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              height: 5,
              width: 54,
              decoration: BoxDecoration(
                color: AppColors.blackCat.withOpacity(0.12),
                borderRadius: BorderRadius.zero,
              ),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  _topHero(context),
                  const SizedBox(height: 10),
                  _sectionTitle('Description'),
                  const SizedBox(height: 8),
                  Text(
                    request.bio.trim().isEmpty ? '-' : request.bio.trim(),
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 14.5,
                      height: 1.35,
                      color: AppColors.blackCat.withOpacity(0.90),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Divider(
                    height: 1,
                    color: AppColors.blackCatBorderLight,
                  ),
                  const SizedBox(height: 12),
                  if (isGroupOrder) ...[
                    _sectionTitle('Client Measurements'),
                    const SizedBox(height: 10),
                    FutureBuilder<_RequestNfcDetails>(
                      future: _loadRequestedNfcDetails(),
                      builder: (context, snapshot) {
                        return _groupOrderClientsTabs(
                          snapshot.data ?? _RequestNfcDetails.empty(),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    if (request.sourceCollection == 'Company_Custom_Requests')
                      _brandClientDetailsBlock(),
                    _sectionTitle('Nail Dimensions (mm)'),
                    const SizedBox(height: 10),
                    FutureBuilder<_RequestNfcDetails>(
                      future: _loadRequestedNfcDetails(),
                      builder: (context, snapshot) {
                        final nfc = snapshot.data ?? _RequestNfcDetails.empty();
                        return LayoutBuilder(
                          builder: (context, c) {
                            final maxCardW = (c.maxWidth - 8) / 2;

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: maxCardW,
                                  child: _handCardCentered(
                                    'Left Hand',
                                    request.leftHand,
                                    nfc: nfc.main.left,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: maxCardW,
                                  child: _handCardCentered(
                                    'Right Hand',
                                    request.rightHand,
                                    nfc: nfc.main.right,
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _softBoxCompact(
                            Row(
                              children: [
                                Text(
                                  'Nail Shape',
                                  style: TextStyle(
                                    color: AppColors.blackCat.withOpacity(0.78),
                                    fontWeight: FontWeight.w400,
                                    fontSize: 14.5,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  request.nailShape.trim().isEmpty
                                      ? '-'
                                      : request.nailShape,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14.5,
                                    color: AppColors.blackCat,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _softBoxCompact(
                            Row(
                              children: [
                                Text(
                                  'Nail Length',
                                  style: TextStyle(
                                    color: AppColors.blackCat.withOpacity(0.78),
                                    fontWeight: FontWeight.w400,
                                    fontSize: 14.5,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  request.nailLength.trim().isEmpty
                                      ? '-'
                                      : _prettyLength(request.nailLength),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14.5,
                                    color: AppColors.blackCat,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  const Divider(
                    height: 1,
                    color: AppColors.blackCatBorderLight,
                  ),
                  const SizedBox(height: 12),

                  // ✅ Photos stay after
                  _sectionTitle(
                    request.sourceCollection == 'Company_Custom_Requests'
                        ? 'Uploaded Photo (Brand)'
                        : 'Uploaded Photos (Client)',
                  ),
                  const SizedBox(height: 10),
                  FutureBuilder<List<String>>(
                    future: _modalPhotoCandidates(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const SizedBox(
                          height: 120,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final modalPhotos = snapshot.data ?? const <String>[];
                      if (modalPhotos.isEmpty) {
                        return _softBox(
                          Row(
                            children: [
                              Icon(
                                Icons.image_outlined,
                                color: AppColors.blackCat.withOpacity(0.45),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                request.sourceCollection ==
                                        'Company_Custom_Requests'
                                    ? 'No photos uploaded by Brand'
                                    : 'No images uploaded',
                                style: TextStyle(
                                  color: AppColors.blackCat.withOpacity(0.82),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return _photosGrid(context, modalPhotos);
                    },
                  ),
                ],
              ),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + safeBottom),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 132,
                    height: 52,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.blackCat.withOpacity(0.16),
                        foregroundColor: AppColors.blackCat,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                        side: BorderSide(
                          color: AppColors.blackCat.withOpacity(0.30),
                        ),
                      ),
                      onPressed: onDecline,
                      child: Text(
                        declineLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontFamily: 'Arial',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 132,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blackCat,
                        foregroundColor: AppColors.snow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                        elevation: 0,
                      ),
                      onPressed: onAccept,
                      child: Text(
                        acceptLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontFamily: 'Arial',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _lengthHint(String len) {
    final v = len.trim().toLowerCase();
    if (v == 'short') return ' (Just past tip)';
    if (v == 'medium') return ' (About 2–3mm past tip)';
    if (v == 'long') return ' (Noticeably past tip)';
    if (v == 'xlong' || v == 'xl' || v == 'extra long') return ' (Very long)';
    return '';
  }

  static Widget _handCardCentered(
    String title,
    NailDimensionsV2 d, {
    Map<String, bool> nfc = const <String, bool>{},
  }) {
    return _softBox(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
                color: AppColors.blackCat,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _dimRow('Thumb', d.thumb, nfcRequested: nfc['thumb'] == true),
          _dimRow('Index', d.index, nfcRequested: nfc['index'] == true),
          _dimRow('Middle', d.middle, nfcRequested: nfc['middle'] == true),
          _dimRow('Ring', d.ring, nfcRequested: nfc['ring'] == true),
          _dimRow('Pinky', d.pinky, nfcRequested: nfc['pinky'] == true),
        ],
      ),
    );
  }

  static Widget _sectionTitle(String t) => Text(
    t,
    style: const TextStyle(
      fontWeight: FontWeight.w800,
      fontSize: 15,
      color: AppColors.blackCat,
    ),
  );

  static Widget _kvRow(String label, String value) {
    final v = value.trim().isEmpty ? '-' : value.trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.blackCat.withOpacity(0.58),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            v,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
          ),
        ),
      ],
    );
  }

  static Widget _softBox(Widget child) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
      ),
      child: child,
    );
  }

  static Widget _softBoxCompact(Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
      ),
      child: child,
    );
  }

  static String _lengthSubtitle(String l) {
    switch (l.toLowerCase()) {
      case 'short':
        return 'Just past tip';
      case 'medium':
        return 'Classic';
      case 'long':
        return 'Extended';
      case 'extra long':
        return 'Statement';
      case 'xl':
        return 'Maximum';
      default:
        return '';
    }
  }

  static String _prettyLength(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return v;
    final lower = v.toLowerCase();
    if (lower == 'short') return 'Short';
    if (lower == 'medium') return 'Medium';
    if (lower == 'long') return 'Long';
    if (lower == 'extralong' ||
        lower == 'extra long' ||
        lower == 'xlong' ||
        lower == 'xl' ||
        lower == 'xllong') {
      return 'Extra Long';
    }
    return v[0].toUpperCase() + v.substring(1);
  }

  static Widget _infoPillRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
  }) {
    final s = _reqScale(context);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 12 * s),
      decoration: BoxDecoration(
        color: AppColors.balletSlippers,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.blackCat.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 18 * s, color: AppColors.blackCat.withOpacity(0.75)),
          SizedBox(width: 10 * s),

          Text(
            '$label ',
            style: TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: 14 * s,
              color: AppColors.blackCat.withOpacity(0.55),
            ),
          ),

          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 14 * s,
                color: AppColors.blackCat.withOpacity(0.90),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _handCard(String title, NailDimensionsV2 d) {
    return _softBox(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          _dimRow('Thumb', d.thumb),
          _dimRow('Index', d.index),
          _dimRow('Middle', d.middle),
          _dimRow('Ring', d.ring),
          _dimRow('Pinky', d.pinky),
        ],
      ),
    );
  }

  static Widget _dimRow(String k, String v, {bool nfcRequested = false}) {
    final value = v.trim().isEmpty ? '-' : v.trim();
    final valueMm = _dimensionValueMm(value);
    final showNfcChip = nfcRequested && valueMm != null && valueMm >= 8;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              k,
              style: TextStyle(
                color: AppColors.blackCat.withOpacity(0.82),
                fontWeight: FontWeight.w400,
                fontSize: 13.5,
              ),
            ),
          ),
          if (showNfcChip) ...[_nfcDimensionChip(), const SizedBox(width: 6)],
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13.5,
              color: AppColors.blackCat,
            ),
          ),
        ],
      ),
    );
  }

  static double? _dimensionValueMm(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9.]'), '').trim();
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  static Widget _nfcDimensionChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: const BoxDecoration(
        color: AppColors.balletSlippers,
        borderRadius: BorderRadius.zero,
      ),
      child: const Text(
        'NFC',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: AppColors.blackCat,
          height: 1.0,
        ),
      ),
    );
  }

  Widget _topHero(BuildContext context) {
    final s = _reqScale(context);
    final isBrandRequest =
        request.sourceCollection == 'Company_Custom_Requests';
    final campaignName = request.title.trim().isEmpty
        ? 'Campaign'
        : request.title.trim();
    final displayName = isBrandRequest && request.brandName.trim().isNotEmpty
        ? request.brandName.trim()
        : request.clientName;

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Column(
            children: [
              const SizedBox(height: 12),

              // Avatar (center)
              SizedBox(
                height: 78 * s,
                width: 78 * s,
                child: _hasHeroProfileImage()
                    ? ClipRRect(
                        borderRadius: BorderRadius.zero,
                        child: _heroAvatar(s),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.zero,
                          color: AppColors.balletSlippers,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _initialLetter(),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 22 * s,
                            color: AppColors.blackCat,
                          ),
                        ),
                      ),
              ),

              const SizedBox(height: 12),

              // Name
              Text(
                displayName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 16 * s,
                  color: AppColors.blackCat,
                ),
              ),
              if (isBrandRequest) ...[
                const SizedBox(height: 4),
                Text(
                  campaignName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13.5 * s,
                    color: AppColors.blackCat.withOpacity(0.72),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.blackCat),
                    color: AppColors.snow,
                  ),
                  child: Text(
                    'Brand Request',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11 * s,
                      color: AppColors.blackCat,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'Order # ${request.orderNumber.trim().isNotEmpty ? request.orderNumber.trim() : request.id}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.blackCat.withOpacity(0.78),
                  fontWeight: FontWeight.w500,
                  fontSize: 12.5 * s,
                ),
              ),

              const SizedBox(height: 12),

              _requestTypePills(context),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                          color: AppColors.blackCat,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Need by: ${_needByLabel(request.neededBy)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5 * s,
                              color: AppColors.blackCat,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12 * s),
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.attach_money_rounded,
                          size: 18,
                          color: AppColors.blackCat,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            'Budget: \$${request.budgetMin} to \$${request.budgetMax}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5 * s,
                              color: AppColors.blackCat,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.blackCatBorderLight),
            ],
          ),
        ),

        // Close icon top-right
        Positioned(
          right: 6,
          top: 6,
          child: InkWell(
            borderRadius: BorderRadius.zero,
            onTap: () => Navigator.pop(context),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                Icons.close_rounded,
                size: 18 * s,
                color: AppColors.blackCat,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _brandClientDetailsBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, color: AppColors.blackCatBorderLight),
        const SizedBox(height: 10),
        _sectionTitle('Client Details'),
        const SizedBox(height: 10),
        Row(
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: ClipRRect(
                borderRadius: BorderRadius.zero,
                child: _clientDetailsAvatar(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                request.acceptedClientName.trim().isEmpty
                    ? 'Client'
                    : request.acceptedClientName.trim(),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.blackCat,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Divider(height: 1, color: AppColors.blackCatBorderLight),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _clientDetailsAvatar() {
    final acceptedPhoto = request.acceptedClientProfileImage.trim();
    if (_canUseAcceptedClientAvatar(acceptedPhoto)) {
      final normalized = _normalizeImagePath(acceptedPhoto);
      final bytes = _decodeDataImageBytes(normalized);
      if (bytes != null) {
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _clientDetailsAvatarFallback(),
        );
      }
      if (normalized.startsWith('http://') ||
          normalized.startsWith('https://')) {
        return Image.network(
          normalized,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _clientDetailsAvatarFallback(),
        );
      }
    }
    return _clientDetailsAvatarFallback();
  }

  bool _canUseAcceptedClientAvatar(String raw) {
    final photo = raw.trim();
    if (photo.isEmpty) return false;
    final normalizedPhoto = _normalizeImagePath(photo).trim().toLowerCase();
    if (normalizedPhoto.isEmpty) return false;

    final blocked = <String>{
      _normalizeImagePath(_heroPhotoSource()).trim().toLowerCase(),
      _normalizeImagePath(request.previewImageAsset).trim().toLowerCase(),
      _normalizeImagePath(request.clientProfileImage).trim().toLowerCase(),
    }..removeWhere((e) => e.isEmpty);

    // Prevent brand/header images from being reused as the client avatar.
    if (blocked.contains(normalizedPhoto)) return false;
    return true;
  }

  Widget _clientDetailsAvatarFallback() {
    final name = request.acceptedClientName.trim().isNotEmpty
        ? request.acceptedClientName.trim()
        : 'Client';
    final letter = name[0].toUpperCase();
    return Container(
      color: AppColors.balletSlippers,
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: AppColors.blackCat,
        ),
      ),
    );
  }

  Widget _requestTypePills(BuildContext context) {
    final s = _reqScale(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: _requestTypePill(
            context: context,
            text: request.isDirectRequest
                ? 'Direct Request'
                : 'Standard Request',
            icon: request.isDirectRequest
                ? Icons.arrow_outward_rounded
                : Icons.arrow_forward_rounded,
            alignEnd: true,
          ),
        ),
        SizedBox(width: 12 * s),
        Container(
          width: 1,
          height: 18 * s,
          color: AppColors.blackCatBorderLight,
        ),
        SizedBox(width: 12 * s),
        Flexible(
          child: _requestTypePill(
            context: context,
            text: request.orderType == RequestOrderTypeV2.group
                ? 'Group Order'
                : 'Single Order',
            icon: request.orderType == RequestOrderTypeV2.group
                ? Icons.groups_2_outlined
                : Icons.person_outline_rounded,
            alignEnd: false,
          ),
        ),
      ],
    );
  }

  Widget _requestTypePill({
    required BuildContext context,
    required String text,
    required IconData icon,
    required bool alignEnd,
  }) {
    final s = _reqScale(context);

    return Row(
      mainAxisAlignment: alignEnd
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        Icon(icon, size: 16 * s, color: AppColors.blackCat),
        SizedBox(width: 8 * s),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5 * s,
              color: AppColors.blackCat,
            ),
          ),
        ),
      ],
    );
  }

  Widget _groupOrderClientsTabs(_RequestNfcDetails nfcDetails) {
    final tabs = _orderClientsForTabs(nfcDetails);
    if (tabs.isEmpty) {
      return _softBox(
        Text(
          'No client measurements found for this order.',
          style: TextStyle(
            color: AppColors.blackCat.withOpacity(0.65),
            fontWeight: FontWeight.w400,
            fontSize: 13.5,
          ),
        ),
      );
    }

    return DefaultTabController(
      length: tabs.length,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.snow,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: AppColors.blackCatBorderLight),
        ),
        child: Column(
          children: [
            Container(
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.blackCat,
                unselectedLabelColor: AppColors.blackCat,
                indicatorColor: AppColors.alabaster,
                indicatorWeight: 3,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13.5,
                ),
                tabs: tabs
                    .map(
                      (c) => Tab(
                        text: c.name.trim().isEmpty ? 'Client' : c.name.trim(),
                      ),
                    )
                    .toList(),
              ),
            ),
            SizedBox(
              height: 315,
              child: TabBarView(
                children: tabs.map((c) => _clientMeasurementsTab(c)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _clientMeasurementsTab(_OrderClientTabData client) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            Expanded(
              child: _softBoxCompact(
                Row(
                  children: [
                    Text(
                      'Nail Shape',
                      style: TextStyle(
                        color: AppColors.blackCat.withOpacity(0.78),
                        fontWeight: FontWeight.w400,
                        fontSize: 13.5,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      client.nailShape.trim().isEmpty ? '-' : client.nailShape,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13.5,
                        color: AppColors.blackCat,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _softBoxCompact(
                Row(
                  children: [
                    Text(
                      'Nail Length',
                      style: TextStyle(
                        color: AppColors.blackCat.withOpacity(0.78),
                        fontWeight: FontWeight.w400,
                        fontSize: 13.5,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      client.nailLength.trim().isEmpty
                          ? '-'
                          : _prettyLength(client.nailLength),
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13.5,
                        color: AppColors.blackCat,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _handCardCentered(
                'Left Hand',
                client.leftHand,
                nfc: client.nfc.left,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _handCardCentered(
                'Right Hand',
                client.rightHand,
                nfc: client.nfc.right,
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<_OrderClientTabData> _orderClientsForTabs(
    _RequestNfcDetails nfcDetails,
  ) {
    final acceptedEmails = request.acceptedGroupClientEmails
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    if (request.groupClients.isNotEmpty) {
      return request.groupClients
          .where((c) {
            final email = c.clientEmail.trim().toLowerCase();
            return acceptedEmails.isNotEmpty && acceptedEmails.contains(email);
          })
          .map((c) {
            final name = c.clientName.trim().isNotEmpty
                ? c.clientName.trim()
                : (c.clientId.trim().isNotEmpty
                      ? c.clientId.trim()
                      : 'Client ${c.slotIndex}');
            return _OrderClientTabData(
              name: name,
              nailShape: c.nailShape,
              nailLength: c.nailLength,
              leftHand: c.leftHand,
              rightHand: c.rightHand,
              nfc:
                  nfcDetails.groupBySlotIndex[c.slotIndex] ??
                  _FingerNfcSelection.empty(),
            );
          })
          .toList(growable: false);
    }

    return <_OrderClientTabData>[
      _OrderClientTabData(
        name: request.clientName,
        nailShape: request.nailShape,
        nailLength: request.nailLength,
        leftHand: request.leftHand,
        rightHand: request.rightHand,
        nfc: nfcDetails.main,
      ),
    ];
  }

  Widget _heroAvatar(double s) {
    final photo = _heroPhotoSource().trim();

    Widget initialFallback() => Center(
      child: Text(
        request.clientName.isEmpty ? 'C' : request.clientName[0].toUpperCase(),
        style: TextStyle(fontWeight: FontWeight.w400, fontSize: 16 * s),
      ),
    );

    Widget fitCover(Widget child) {
      return SizedBox.expand(child: child);
    }

    if (photo.isEmpty) return initialFallback();

    final p = _normalizeImagePath(photo);
    final dataBytes = _decodeDataImageBytes(p);
    final isNetwork =
        p.startsWith('http://') ||
        p.startsWith('https://') ||
        p.startsWith('gs://') ||
        p.startsWith('blob:') ||
        p.startsWith('content://');
    final isAsset = p.startsWith('assets/');
    final isFileUri = p.startsWith('file://');
    final isFilePath = !kIsWeb && (p.startsWith('/') || p.contains(':\\'));
    final isStorageRef = _looksLikeStorageRef(p);

    if (p.startsWith('gs://') || isStorageRef || isNetwork) {
      return FutureBuilder<String>(
        future: StorageUrlResolver.resolve(p).then((v) {
          final resolved = (v ?? '').trim();
          if (resolved.isNotEmpty) return resolved;
          if (p.startsWith('http://') || p.startsWith('https://')) return p;
          return '';
        }),
        builder: (_, snap) {
          final url = snap.data?.trim() ?? '';
          if (url.isNotEmpty) {
            return fitCover(
              Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => initialFallback(),
              ),
            );
          }
          return FutureBuilder<Uint8List?>(
            future: _readStorageBytes(p),
            builder: (_, bytesSnap) {
              final bytes = bytesSnap.data;
              if (bytes == null || bytes.isEmpty) return initialFallback();
              return fitCover(
                Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => initialFallback(),
                ),
              );
            },
          );
        },
      );
    }
    if (dataBytes != null) {
      return fitCover(
        Image.memory(
          dataBytes,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => initialFallback(),
        ),
      );
    }
    // Network URLs are resolved above through StorageUrlResolver for mobile.
    if (isAsset) {
      return fitCover(
        Image.asset(
          p,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => initialFallback(),
        ),
      );
    }
    if (isFileUri || isFilePath) {
      final localPath = isFileUri ? p.replaceFirst('file://', '') : p;
      return fitCover(
        Image.file(
          File(localPath),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => initialFallback(),
        ),
      );
    }
    return initialFallback();
  }

  String _normalizeImagePath(String raw) {
    var p = raw.trim();
    if (p.isEmpty) return '';
    if (p.startsWith('assets/')) {
      final rest = p.substring('assets/'.length);
      final decodedRest = _decodeUriSafelyRepeatedly(rest).trim();
      final lower = decodedRest.toLowerCase();
      if (lower.startsWith('data:') ||
          lower.startsWith('blob:') ||
          lower.startsWith('http://') ||
          lower.startsWith('https://') ||
          lower.startsWith('content://') ||
          lower.startsWith('file://')) {
        return decodedRest;
      }
    }
    p = _decodeUriSafelyRepeatedly(p).trim();
    if (p.startsWith('assets/')) {
      final rest = p.substring('assets/'.length);
      final decodedRest = _decodeUriSafelyRepeatedly(rest).trim();
      final lower = decodedRest.toLowerCase();
      if (lower.startsWith('data:') ||
          lower.startsWith('blob:') ||
          lower.startsWith('http://') ||
          lower.startsWith('https://') ||
          lower.startsWith('content://') ||
          lower.startsWith('file://')) {
        return decodedRest;
      }
    }
    return p;
  }

  bool _looksLikeStorageRef(String value) {
    final v = value.trim().toLowerCase();
    if (v.isEmpty) return false;
    if (v.startsWith('http://') ||
        v.startsWith('https://') ||
        v.startsWith('gs://') ||
        v.startsWith('data:') ||
        v.startsWith('blob:') ||
        v.startsWith('content://') ||
        v.startsWith('file://') ||
        v.startsWith('assets/') ||
        v.startsWith('/')) {
      return false;
    }
    if (v.contains(':\\')) return false;
    return v.contains('/');
  }

  Widget _photosGrid(BuildContext context, List<String> images) {
    Widget imageFor(String raw) {
      final path = _normalizeImagePath(raw);
      final dataBytes = _decodeDataImageBytes(path);
      final isNetwork =
          path.startsWith('http://') ||
          path.startsWith('https://') ||
          path.startsWith('gs://') ||
          path.startsWith('blob:') ||
          path.startsWith('content://');
      final isAsset = path.startsWith('assets/');
      final isFileUri = path.startsWith('file://');
      final isFilePath =
          !kIsWeb && (path.startsWith('/') || path.contains(':\\'));
      final isStorageRef = _looksLikeStorageRef(path);

      if (path.startsWith('gs://') || isStorageRef || isNetwork) {
        return FutureBuilder<String>(
          future: StorageUrlResolver.resolve(path).then((v) {
            final resolved = (v ?? '').trim();
            if (resolved.isNotEmpty) return resolved;
            if (path.startsWith('http://') || path.startsWith('https://')) {
              return path;
            }
            return '';
          }),
          builder: (_, snap) {
            final url = snap.data?.trim() ?? '';
            return FutureBuilder<Uint8List?>(
              future: _readImageBytes(path, resolvedUrl: url),
              builder: (_, bytesSnap) {
                final bytes = bytesSnap.data;
                if (bytes == null || bytes.isEmpty)
                  return Container(
                    color: AppColors.blackCat.withOpacity(0.05),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.blackCat.withOpacity(0.35),
                    ),
                  );
                return Image.memory(bytes, fit: BoxFit.cover);
              },
            );
          },
        );
      }
      if (dataBytes != null) {
        return Image.memory(
          dataBytes,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            color: AppColors.blackCat.withOpacity(0.05),
            alignment: Alignment.center,
            child: Icon(
              Icons.broken_image_outlined,
              color: AppColors.blackCat.withOpacity(0.35),
            ),
          ),
        );
      }
      // Network URLs are resolved above through StorageUrlResolver for mobile.
      if (isAsset) {
        return Image.asset(
          path,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            color: AppColors.blackCat.withOpacity(0.05),
            alignment: Alignment.center,
            child: Icon(
              Icons.broken_image_outlined,
              color: AppColors.blackCat.withOpacity(0.35),
            ),
          ),
        );
      }
      if (isFileUri || isFilePath) {
        final localPath = isFileUri ? path.replaceFirst('file://', '') : path;
        return Image.file(
          File(localPath),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            color: AppColors.blackCat.withOpacity(0.05),
            alignment: Alignment.center,
            child: Icon(
              Icons.broken_image_outlined,
              color: AppColors.blackCat.withOpacity(0.35),
            ),
          ),
        );
      }
      return Container(
        color: AppColors.blackCat.withOpacity(0.05),
        alignment: Alignment.center,
        child: Icon(
          Icons.image_not_supported_outlined,
          color: AppColors.blackCat.withOpacity(0.35),
        ),
      );
    }

    final valid = images
        .map((e) => _normalizeImagePath(e).trim())
        .where((e) => e.isNotEmpty)
        .map((e) => e.replaceAll(RegExp(r'\s+'), ' '))
        .toList();

    final unique = <String>[];
    for (final item in valid) {
      final key = item.toLowerCase();
      if (unique.any((existing) => existing.toLowerCase() == key)) continue;
      unique.add(item);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final tileSize = ((constraints.maxWidth - 24) / 4).clamp(70.0, 112.0);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: unique.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            mainAxisExtent: tileSize,
          ),
          itemBuilder: (context, i) {
            final path = unique[i];
            return InkWell(
              borderRadius: BorderRadius.zero,
              onTap: () => _openImagePreview(context, path),
              child: ClipRRect(
                borderRadius: BorderRadius.zero,
                child: SizedBox.expand(child: imageFor(path)),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openImagePreview(BuildContext context, String imagePath) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        backgroundColor: AppColors.snow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: Stack(
          children: [
            AspectRatio(aspectRatio: 1, child: _previewImageForPath(imagePath)),
            Positioned(
              right: 6,
              top: 6,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewImageForPath(String raw) {
    final path = _normalizeImagePath(raw);
    final dataBytes = _decodeDataImageBytes(path);
    final isNetwork =
        path.startsWith('http://') ||
        path.startsWith('https://') ||
        path.startsWith('gs://') ||
        path.startsWith('blob:') ||
        path.startsWith('content://');
    final isAsset = path.startsWith('assets/');
    final isFileUri = path.startsWith('file://');
    final isFilePath =
        !kIsWeb && (path.startsWith('/') || path.contains(':\\'));
    final isStorageRef = _looksLikeStorageRef(path);

    Widget broken() => Container(
      color: AppColors.blackCat.withOpacity(0.05),
      alignment: Alignment.center,
      child: Icon(
        Icons.broken_image_outlined,
        color: AppColors.blackCat.withOpacity(0.35),
      ),
    );

    if (path.startsWith('gs://') || isStorageRef || isNetwork) {
      return FutureBuilder<String>(
        future: StorageUrlResolver.resolve(path).then((v) {
          final resolved = (v ?? '').trim();
          if (resolved.isNotEmpty) return resolved;
          if (path.startsWith('http://') || path.startsWith('https://')) {
            return path;
          }
          return '';
        }),
        builder: (_, snap) {
          final url = snap.data?.trim() ?? '';
          return FutureBuilder<Uint8List?>(
            future: _readImageBytes(path, resolvedUrl: url),
            builder: (_, bytesSnap) {
              final bytes = bytesSnap.data;
              if (bytes == null || bytes.isEmpty) return broken();
              return Image.memory(bytes, fit: BoxFit.contain);
            },
          );
        },
      );
    }
    if (dataBytes != null) {
      return Image.memory(
        dataBytes,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => broken(),
      );
    }
    // Network URLs are resolved above through StorageUrlResolver for mobile.
    if (isAsset) {
      return Image.asset(
        path,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => broken(),
      );
    }
    if (isFileUri || isFilePath) {
      final localPath = isFileUri ? path.replaceFirst('file://', '') : path;
      return Image.file(
        File(localPath),
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => broken(),
      );
    }
    return broken();
  }

  static String _needByLabel(DateTime d) {
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
    const wds = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${wds[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }
}

String _decodeUriSafelyRepeatedly(String value) {
  var out = value;
  for (var i = 0; i < 3; i++) {
    try {
      final decoded = Uri.decodeFull(out);
      if (decoded == out) break;
      out = decoded;
    } catch (_) {
      break;
    }
  }
  return out;
}

bool _looksLikeStorageRef(String value) {
  final v = value.trim().toLowerCase();
  if (v.isEmpty) return false;
  if (v.startsWith('http://') ||
      v.startsWith('https://') ||
      v.startsWith('gs://') ||
      v.startsWith('data:') ||
      v.startsWith('blob:') ||
      v.startsWith('content://') ||
      v.startsWith('file://') ||
      v.startsWith('assets/') ||
      v.startsWith('/')) {
    return false;
  }
  if (v.contains(':\\')) return false;
  return v.contains('/');
}

Future<Uint8List?> _readStorageBytes(String value) async {
  final v = value.trim();
  if (v.isEmpty) return null;
  try {
    if (v.startsWith('gs://')) {
      return await FirebaseStorage.instance
          .refFromURL(v)
          .getData(4 * 1024 * 1024);
    }
    if (_looksLikeStorageRef(v)) {
      return await FirebaseStorage.instance.ref(v).getData(4 * 1024 * 1024);
    }
  } catch (_) {}
  return null;
}

Future<Uint8List?> _readImageBytes(
  String value, {
  String resolvedUrl = '',
}) async {
  final v = value.trim();
  if (v.isEmpty) return null;
  if (v.startsWith('data:image/')) {
    return _decodeDataImageBytes(v);
  }
  if (v.startsWith('gs://') || _looksLikeStorageRef(v)) {
    return _readStorageBytes(v);
  }
  final url = resolvedUrl.trim().isNotEmpty ? resolvedUrl.trim() : v;
  if (url.startsWith('http://') || url.startsWith('https://')) {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        client.close(force: true);
        return null;
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
      }
      client.close(force: true);
      return builder.takeBytes();
    } catch (_) {
      return null;
    }
  }
  if (v.startsWith('file://') ||
      (!kIsWeb && (v.startsWith('/') || v.contains(':\\')))) {
    final localPath = v.startsWith('file://')
        ? v.replaceFirst('file://', '')
        : v;
    try {
      final file = File(localPath);
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }
  return null;
}

Uint8List? _decodeDataImageBytes(String value) {
  final src = value.trim();
  if (!src.startsWith('data:image/')) return null;
  final comma = src.indexOf(',');
  if (comma <= 0 || comma >= src.length - 1) return null;
  try {
    return base64Decode(src.substring(comma + 1));
  } catch (_) {
    return null;
  }
}

class _OrderClientTabData {
  const _OrderClientTabData({
    required this.name,
    required this.nailShape,
    required this.nailLength,
    required this.leftHand,
    required this.rightHand,
    required this.nfc,
  });

  final String name;
  final String nailShape;
  final String nailLength;
  final NailDimensionsV2 leftHand;
  final NailDimensionsV2 rightHand;
  final _FingerNfcSelection nfc;
}

class _RequestNfcDetails {
  const _RequestNfcDetails({
    required this.main,
    required this.groupBySlotIndex,
  });

  factory _RequestNfcDetails.empty() => const _RequestNfcDetails(
    main: _FingerNfcSelection(),
    groupBySlotIndex: <int, _FingerNfcSelection>{},
  );

  final _FingerNfcSelection main;
  final Map<int, _FingerNfcSelection> groupBySlotIndex;
}

class _FingerNfcSelection {
  const _FingerNfcSelection({
    this.lThumb = false,
    this.lIndex = false,
    this.lMiddle = false,
    this.lRing = false,
    this.lPinky = false,
    this.rThumb = false,
    this.rIndex = false,
    this.rMiddle = false,
    this.rRing = false,
    this.rPinky = false,
  });

  factory _FingerNfcSelection.empty() => const _FingerNfcSelection();

  factory _FingerNfcSelection.fromDimensionsMap(Map<String, dynamic> map) {
    bool b(Object? value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      final text = (value ?? '').toString().trim().toLowerCase();
      return text == 'true' || text == 'yes' || text == '1';
    }

    Object? nfcValue(String key) {
      final nfc = map['nfc'];
      if (nfc is Map) {
        return map['${key}Nfc'] ?? nfc[key];
      }
      return map['${key}Nfc'];
    }

    return _FingerNfcSelection(
      lThumb: b(nfcValue('lThumb')),
      lIndex: b(nfcValue('lIndex')),
      lMiddle: b(nfcValue('lMiddle')),
      lRing: b(nfcValue('lRing')),
      lPinky: b(nfcValue('lPinky')),
      rThumb: b(nfcValue('rThumb')),
      rIndex: b(nfcValue('rIndex')),
      rMiddle: b(nfcValue('rMiddle')),
      rRing: b(nfcValue('rRing')),
      rPinky: b(nfcValue('rPinky')),
    );
  }

  final bool lThumb;
  final bool lIndex;
  final bool lMiddle;
  final bool lRing;
  final bool lPinky;
  final bool rThumb;
  final bool rIndex;
  final bool rMiddle;
  final bool rRing;
  final bool rPinky;

  bool get anySelected =>
      lThumb ||
      lIndex ||
      lMiddle ||
      lRing ||
      lPinky ||
      rThumb ||
      rIndex ||
      rMiddle ||
      rRing ||
      rPinky;

  Map<String, bool> get left => <String, bool>{
    'thumb': lThumb,
    'index': lIndex,
    'middle': lMiddle,
    'ring': lRing,
    'pinky': lPinky,
  };

  Map<String, bool> get right => <String, bool>{
    'thumb': rThumb,
    'index': rIndex,
    'middle': rMiddle,
    'ring': rRing,
    'pinky': rPinky,
  };
}

class _RequestFilterResult {
  const _RequestFilterResult({
    required this.directOnly,
    required this.groupOnly,
    required this.sort,
    required this.budgetRange,
  });

  final bool directOnly;
  final bool groupOnly;
  final String sort;
  final RangeValues budgetRange;
}

class _AcceptResult {
  final double yourPrice;
  final double shipping;
  final double extra;
  const _AcceptResult({
    required this.yourPrice,
    required this.shipping,
    required this.extra,
  });
}

class AcceptRequestDialogV2 extends StatefulWidget {
  const AcceptRequestDialogV2({
    super.key,
    required this.budgetMin,
    required this.budgetMax,
  });

  final int budgetMin;
  final int budgetMax;

  @override
  State<AcceptRequestDialogV2> createState() => _AcceptRequestDialogV2State();
}

class _AcceptRequestDialogV2State extends State<AcceptRequestDialogV2> {
  late final TextEditingController _yourPriceCtrl;
  late final TextEditingController _shippingCtrl;

  @override
  void initState() {
    super.initState();
    final mid = ((widget.budgetMin + widget.budgetMax) / 2).round();
    _yourPriceCtrl = TextEditingController(text: mid.toStringAsFixed(0));
    _shippingCtrl = TextEditingController(text: '10');
  }

  @override
  void dispose() {
    _yourPriceCtrl.dispose();
    _shippingCtrl.dispose();
    super.dispose();
  }

  double _toNum(String v) => double.tryParse(v.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isNarrow = media.size.width < 360;
    final range = '\$${widget.budgetMin} - \$${widget.budgetMax}';
    final total = _toNum(_yourPriceCtrl.text) + _toNum(_shippingCtrl.text);
    final exceedsBudget = total > widget.budgetMax;
    final bottomInset = media.viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(maxHeight: media.size.height * 0.78),
          decoration: const BoxDecoration(
            color: AppColors.snow,
            borderRadius: BorderRadius.zero,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Accept',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.blackCat,
                    fontFamily: 'Arial',
                  ),
                ),
                const SizedBox(height: 12),
                _row('Price Range', range),
                const SizedBox(height: 8),
                _fieldRow('Your Price', _yourPriceCtrl, prefix: '\$'),
                const SizedBox(height: 8),
                _fieldRow(
                  'Shipping + Extra',
                  _shippingCtrl,
                  prefix: '\$',
                  enabled: false,
                ),
                const SizedBox(height: 10),
                _row('Total', '\$${total.toStringAsFixed(2)}'),
                if (exceedsBudget) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Total exceeds client budget range.',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: AppColors.blackCat.withOpacity(
                              0.16,
                            ),
                            foregroundColor: AppColors.blackCat,
                            side: BorderSide(
                              color: AppColors.blackCat.withOpacity(0.30),
                            ),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: isNarrow ? 11 : 12,
                              fontFamily: 'Arial',
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.blackCat,
                            foregroundColor: AppColors.snow,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                            elevation: 0,
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: exceedsBudget
                              ? null
                              : () {
                                  Navigator.pop(
                                    context,
                                    _AcceptResult(
                                      yourPrice: _toNum(_yourPriceCtrl.text),
                                      shipping: _toNum(_shippingCtrl.text),
                                      extra: 0,
                                    ),
                                  );
                                },
                          child: Text(
                            'Accept',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: isNarrow ? 11 : 12,
                              fontFamily: 'Arial',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String a, String b) {
    return Row(
      children: [
        Expanded(
          child: Text(
            a,
            style: TextStyle(
              color: AppColors.blackCat.withOpacity(0.65),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        Text(
          b,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ],
    );
  }

  Widget _fieldRow(
    String label,
    TextEditingController c, {
    String prefix = '',
    bool enabled = true,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.blackCat.withOpacity(0.65),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 110,
          child: TextField(
            controller: c,
            enabled: enabled,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixText: prefix,
              filled: true,
              fillColor: AppColors.snow,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(
                  color: AppColors.blackCat.withOpacity(0.06),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(
                  color: AppColors.blackCat.withOpacity(0.06),
                ),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: AppColors.blackCat, width: 1.2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DropdownCard extends StatelessWidget {
  const _DropdownCard({required this.children, this.width = 220});

  final List<Widget> children;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      margin: const EdgeInsets.only(left: 0),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.blackCat.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _DropItem extends StatelessWidget {
  const _DropItem({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.blackCat.withOpacity(0.45),
            ),
          ],
        ),
      ),
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
    final resolvedColor = color ?? AppColors.blackCat;
    return Row(
      children: [
        Icon(icon, size: 18, color: resolvedColor),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: resolvedColor,
          ),
        ),
      ],
    );
  }
}
