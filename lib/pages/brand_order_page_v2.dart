import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/client_profile_models.dart';
import '../theme/app_colors.dart';
import '../services/client_custom_request_repository.dart';
import '../services/notifications_service.dart';
import '../services/supabase_firebase_compat.dart';
import '../widgets/company_shell_chrome.dart';
import '../widgets/client_profile_avatar_icon.dart';
import '../widgets/notification_bell_button.dart';
import 'client_custom_request_page.dart';
import 'notifications_page.dart';
import 'track_order_page.dart';
import 'brand_order_details_page_v2.dart';

class BrandOrderPageV2 extends StatefulWidget {
  const BrandOrderPageV2({
    super.key,
    required this.profile,
    required this.companyName,
    this.onBackHome,
    this.showCompanyChrome = true,
    this.onOpenProfile,
    this.onOpenHistory,
    this.onOpenCalendar,
    this.onOpenArtist,
    this.onLogout,
    this.showExtendedAvatarMenu = false,
    this.showProfileMenu = false,
    this.bottomNavIndex = 3,
    this.onNavTap,
  });

  final ClientProfileDraft profile;
  final VoidCallback? onBackHome;
  final String companyName;
  final bool showCompanyChrome;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenArtist;
  final Future<void> Function()? onLogout;
  final bool showExtendedAvatarMenu;
  final bool showProfileMenu;
  final int bottomNavIndex;
  final ValueChanged<int>? onNavTap;

  @override
  State<BrandOrderPageV2> createState() => _BrandOrderPageV2State();
}

class _BrandOrderPageV2State extends State<BrandOrderPageV2> {
  OrdersFilter _filter = OrdersFilter.all;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _submittedRequestsSub;
  List<ClientOrder> _submittedOrders = const [];
  @override
  void initState() {
    super.initState();
    _subscribeSubmittedOrders();
  }

  @override
  void didUpdateWidget(covariant BrandOrderPageV2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.basic.email != widget.profile.basic.email) {
      _subscribeSubmittedOrders();
    }
  }

  @override
  void dispose() {
    _submittedRequestsSub?.cancel();
    super.dispose();
  }

  void _subscribeSubmittedOrders() {
    _submittedRequestsSub?.cancel();
    final authEmail = (FirebaseAuth.instance.currentUser?.email ?? '')
        .trim()
        .toLowerCase();
    final profileEmail = widget.profile.basic.email.trim().toLowerCase();
    final effectiveEmail = profileEmail.isNotEmpty ? profileEmail : authEmail;
    final profileName = widget.profile.basic.name.trim();
    final effectiveName = profileName.isNotEmpty
        ? profileName
        : widget.companyName.trim();
    final uid = (FirebaseAuth.instance.currentUser?.uid ?? '').trim();
    _submittedRequestsSub = FirebaseFirestore.instance
        .collection('Company_Custom_Requests')
        .snapshots()
        .listen((snap) {
          unawaited(
            _handleCompanyRequestsSnapshot(
              snap: snap,
              authEmail: authEmail,
              effectiveEmail: effectiveEmail,
              effectiveName: effectiveName,
              uid: uid,
            ),
          );
        });
  }

  Future<void> _handleCompanyRequestsSnapshot({
    required QuerySnapshot<Map<String, dynamic>> snap,
    required String authEmail,
    required String effectiveEmail,
    required String effectiveName,
    required String uid,
  }) async {
    bool matches(Map<String, dynamic> data) {
      final requestType = (data['requestType'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final allowedTypes = <String>{
        '',
        'companycustomrequest',
        'brandcustomrequest',
        'brandrequest',
        'direct',
        'direct to client',
        'direct to artist',
        'standard',
      };
      if (!allowedTypes.contains(requestType)) {
        return false;
      }
      final docUid =
          (data['companyUid'] ??
                  data['requesterUid'] ??
                  data['createdByUid'] ??
                  data['uid'] ??
                  '')
              .toString()
              .trim();
      final companyEmail = (data['companyEmail'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final clientEmail = (data['clientEmail'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final companyName = (data['companyName'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final clientName = (data['clientName'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      if (uid.isNotEmpty && docUid == uid) return true;
      if (effectiveEmail.isNotEmpty &&
          (companyEmail == effectiveEmail || clientEmail == effectiveEmail)) {
        return true;
      }
      if (authEmail.isNotEmpty &&
          (companyEmail == authEmail || clientEmail == authEmail)) {
        return true;
      }
      if (effectiveName.isNotEmpty &&
          (companyName == effectiveName || clientName == effectiveName)) {
        return true;
      }
      return false;
    }

    final matchedDocs = snap.docs
        .where((doc) => matches(doc.data()))
        .toList(growable: false);
    if (kDebugMode) {
      debugPrint(
        '[BrandOrderPage] company requests snapshot total=${snap.docs.length} matched=${matchedDocs.length}',
      );
    }
    final summaries = await Future.wait(
      matchedDocs.map(SubmittedClientRequestSummary.fromDocWithDetails),
    );
    final filteredItems = summaries
        .where(_isVisibleInCompanyOrders)
        .toList(growable: false);
    await _syncExpiredRequests(filteredItems);
    final orders = filteredItems.map(_mapSubmittedRequestToOrder).toList()
      ..sort(
        (a, b) => (b.createdAt ?? DateTime(1970)).compareTo(
          a.createdAt ?? DateTime(1970),
        ),
      );
    if (!mounted) return;
    setState(() => _submittedOrders = orders);
  }

  bool _isVisibleInCompanyOrders(SubmittedClientRequestSummary req) {
    return req.sourceCollection == 'Company_Custom_Requests';
  }

  Future<void> _syncExpiredRequests(
    List<SubmittedClientRequestSummary> items,
  ) async {
    const expirationReason =
        'Request was not accepted by artist, and it is past due.';
    final now = DateTime.now();
    for (final req in items) {
      final raw = req.status.trim().toLowerCase();
      final terminal =
          raw == 'expired' ||
          raw == 'cancelled' ||
          raw == 'canceled' ||
          raw == 'declined' ||
          raw == 'delivered' ||
          raw == 'shipped';
      if (terminal) continue;
      final sourceCollection = req.sourceCollection.trim();
      final isBrandRequest = sourceCollection == 'Company_Custom_Requests';
      final artistAccepted = req.acceptedByArtistEmail.trim().isNotEmpty;
      if (artistAccepted) continue;
      final due = req.needBy;
      if (due == null) continue;
      final pastDue = now.isAfter(
        DateTime(due.year, due.month, due.day).add(const Duration(days: 1)),
      );
      if (!pastDue) continue;

      try {
        final collection = req.sourceCollection.trim().isNotEmpty
            ? req.sourceCollection.trim()
            : 'Client_Custom_Requests';
        final ref = FirebaseFirestore.instance
            .collection(collection)
            .doc(req.id);
        final snap = await ref.get();
        final current = snap.data() ?? const <String, dynamic>{};
        String firstNonEmpty(List<Object?> values, {String fallback = ''}) {
          for (final value in values) {
            final text = (value ?? '').toString().trim();
            if (text.isNotEmpty) return text;
          }
          return fallback;
        }

        final acceptedClientEmail = firstNonEmpty(<Object?>[
          current['acceptedByClientEmail'],
          req.acceptedByClientEmail,
        ]).toLowerCase();
        final currentStatus = ((current['status'] ?? '') as Object)
            .toString()
            .trim()
            .toLowerCase();
        if (currentStatus == 'expired' &&
            current['expiredNotifiedClient'] == true &&
            (!isBrandRequest ||
                (current['expiredNotifiedBrandAdmin'] == true &&
                    (acceptedClientEmail.isEmpty ||
                        current['expiredNotifiedAcceptedClient'] == true)))) {
          continue;
        }
        await ref.set({
          'status': 'expired',
          'expiredAt': FieldValue.serverTimestamp(),
          'expiredNotifiedClient': true,
          if (isBrandRequest) 'expiredNotifiedBrandAdmin': true,
          if (isBrandRequest && acceptedClientEmail.isNotEmpty)
            'expiredNotifiedAcceptedClient': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await ref.collection('details').doc('payload').set({
          'status': 'expired',
          if (isBrandRequest) 'expiredReason': expirationReason,
        }, SetOptions(merge: true));

        if (!isBrandRequest && (req.clientEmail).trim().isNotEmpty) {
          await NotificationsService.createUserNotification(
            receiverEmail: req.clientEmail.trim().toLowerCase(),
            title: 'Request Expired',
            body: 'Your request is expired. Please resubmit',
            type: 'request_expired',
            orderId: req.id,
            orderNumber: req.orderNumber,
            sourceCollection: collection,
          );
        }

        if (isBrandRequest) {
          final campaignName = firstNonEmpty(<Object?>[
            current['campaignName'],
            current['title'],
            req.campaignName,
          ], fallback: 'Campaign');
          final brandCompany = firstNonEmpty(<Object?>[
            current['companyName'],
            current['brandName'],
            req.contactName,
          ], fallback: 'Brand Company');
          final orderRef = req.orderNumber.trim().isNotEmpty
              ? req.orderNumber.trim()
              : req.id;

          final brandRecipientEmails =
              await NotificationsService.resolveBrandRecipientEmails(
                rootData: current,
                excludeEmails: <String>[acceptedClientEmail],
              );

          for (final brandEmail in brandRecipientEmails) {
            await NotificationsService.createUserNotification(
              receiverEmail: brandEmail,
              title: 'Brand Request Expired',
              body:
                  'Your $campaignName brand request $orderRef has been expired $expirationReason',
              type: 'brand_request_expired',
              orderId: req.id,
              orderNumber: req.orderNumber,
              sourceCollection: collection,
              extra: const <String, dynamic>{'reason': expirationReason},
            );
          }

          if (acceptedClientEmail.isNotEmpty) {
            await NotificationsService.createUserNotification(
              receiverEmail: acceptedClientEmail,
              title: 'Brand Request Expired',
              body:
                  'Your $brandCompany $campaignName brand request $orderRef has been expired $expirationReason',
              type: 'client_brand_request_expired',
              orderId: req.id,
              orderNumber: req.orderNumber,
              sourceCollection: collection,
              extra: const <String, dynamic>{'reason': expirationReason},
            );
          }

          await NotificationsService.notifyAdmins(
            title: 'Brand Request Expired',
            body:
                '$brandCompany $campaignName brand request $orderRef has been expired $expirationReason',
            type: 'admin_brand_request_expired',
            orderId: req.id,
            orderNumber: req.orderNumber,
            sourceCollection: collection,
            extra: const <String, dynamic>{'reason': expirationReason},
          );
        }
      } catch (_) {}
    }
  }

  ClientOrder _mapSubmittedRequestToOrder(SubmittedClientRequestSummary req) {
    final submittedAt = req.clientSubmittedAt;
    final submittedText = submittedAt == null
        ? 'Submitted'
        : 'Submitted ${_monthShort(submittedAt.month)} ${submittedAt.day}';
    final campaignName = req.campaignName.trim().isNotEmpty
        ? req.campaignName.trim()
        : 'Campaign';
    final contactName = req.contactName.trim().isNotEmpty
        ? req.contactName.trim()
        : (widget.profile.basic.name.trim().isNotEmpty
              ? widget.profile.basic.name.trim()
              : widget.companyName.trim().isNotEmpty
              ? widget.companyName.trim()
              : 'Contact');

    final mappedStatus = _resolveOrderStatus(req);
    final acceptedFinalAmount = req.artistFinalAmount;
    final hasAcceptedFinalAmount =
        acceptedFinalAmount != null &&
        acceptedFinalAmount > 0 &&
        (mappedStatus == OrderStatus.inProgress ||
            mappedStatus == OrderStatus.shipped ||
            mappedStatus == OrderStatus.delivered);
    final acceptedAmountInt = hasAcceptedFinalAmount
        ? acceptedFinalAmount.round()
        : null;

    final statusText = _statusLabelForCard(
      req: req,
      status: mappedStatus,
      submittedFallback: submittedText,
    );
    final selectedArtistName = _normalizeSelectedArtistName(req.selectedArtist);

    return ClientOrder(
      id: req.id,
      orderNumber: req.orderNumber,
      title: campaignName,
      subtitle: contactName,
      hasAssignedArtist: selectedArtistName.isNotEmpty,
      orderType: req.orderType,
      groupClients: req.groupClients
          .map(
            (client) => OrderClientMeasurement(
              clientId: client.clientId,
              clientName: client.clientName,
              clientEmail: client.clientEmail,
              responseStatus: client.responseStatus,
              nailShape: client.nailShape,
              nailLength: client.nailLength,
              leftHandDimensions: client.leftHandDimensions,
              rightHandDimensions: client.rightHandDimensions,
            ),
          )
          .toList(growable: false),
      clientDescription: req.description.isNotEmpty
          ? req.description
          : req.descriptionPreview,
      cancelReason: req.cancelReason,
      inspirationPhotos: req.inspirationPhotos,
      needByDisplay: req.needByDisplay,
      nailShape: req.nailShape,
      nailLength: req.nailLength,
      budgetMin: req.budgetMin,
      budgetMax: req.budgetMax,
      leftHandDimensions: req.leftHandDimensions,
      rightHandDimensions: req.rightHandDimensions,
      status: mappedStatus,
      expectedOrDeliveredText: statusText,
      imageAsset: _safeCardAvatar(profileImage: req.clientProfileImage),
      artistName: req.acceptedByArtistName.isNotEmpty
          ? req.acceptedByArtistName
          : req.selectedArtist,
      selectedArtistName: selectedArtistName,
      artistProfileImage: req.artistProfileImage,
      createdAt: submittedAt,
      artistAcceptedAmount: acceptedAmountInt,
      paymentStatus: req.paymentStatus,
      paymentLink: req.paymentLink,
      paidAt: req.paidAt,
      clientProfileImage: req.clientProfileImage,
      artistCompletedPhotos: req.artistCompletedPhotos,
      completionReviewStatus: req.completionReviewStatus,
      completionDeclineReason: req.completionDeclineReason,
      completionDeclineDescription: req.completionDeclineDescription,
      completionDeclinedAt: req.completionDeclinedAt,
      designApprovalStatus: req.designApprovalStatus,
      designApprovedAt: req.designApprovedAt,
      clientDesignApprovedAt: req.designApprovedAt,
      designSubmittedAt: req.designSubmittedAt,
      designApprovalDueAt: req.designApprovalDueAt,
      designReminderSentAt: req.designReminderSentAt,
      designPreviewPhotos: req.designPreviewPhotos,
      clientEmail: req.clientEmail,
      acceptedByArtistEmail: req.acceptedByArtistEmail,
      directClientStatus: req.directClientStatus,
      rating: req.clientRating,
      reviewText: req.clientReviewText,
      reviewSubmittedAt: req.clientReviewSubmittedAt,
      cancelledAt: req.cancelledAt,
      needBy: req.needBy,
      shippedByCourier: req.shippedByCourier,
      trackingNumber: req.trackingNumber,
      shippedAt: req.shippedAt,
      deliveredAt: req.deliveredAt,
    );
  }

  String _normalizeSelectedArtistName(String raw) {
    final name = raw.trim();
    if (name.isEmpty) return '';
    final lower = name.toLowerCase();
    if (lower == 'artist' ||
        lower == 'select one' ||
        lower == 'n/a' ||
        lower == '-') {
      return '';
    }
    return name;
  }

  OrderStatus _resolveOrderStatus(SubmittedClientRequestSummary req) {
    final mapped = _statusFromRequestStatus(req.status);
    if (mapped == OrderStatus.cancelled ||
        mapped == OrderStatus.declined ||
        mapped == OrderStatus.shipped ||
        mapped == OrderStatus.delivered ||
        mapped == OrderStatus.inProgress ||
        mapped == OrderStatus.expired) {
      return mapped;
    }

    final accepted =
        req.acceptedByArtistEmail.trim().isNotEmpty ||
        (req.artistFinalAmount != null && req.artistFinalAmount! > 0);
    final due = req.needBy;
    final isPastDue =
        due != null &&
        DateTime.now().isAfter(
          DateTime(due.year, due.month, due.day).add(const Duration(days: 1)),
        );
    if (!accepted && isPastDue) {
      return OrderStatus.expired;
    }
    return mapped;
  }

  String _statusLabelForCard({
    required SubmittedClientRequestSummary req,
    required OrderStatus status,
    required String submittedFallback,
  }) {
    if (status == OrderStatus.expired) {
      final due = req.needBy;
      if (due != null) {
        return 'Expired ${_monthShort(due.month)} ${due.day}, ${due.year}';
      }
      return 'Expired';
    }

    if (status == OrderStatus.cancelled) {
      final cancelledAt = req.cancelledAt;
      final when = cancelledAt == null
          ? 'Cancelled'
          : 'Cancelled ${_monthShort(cancelledAt.month)} ${cancelledAt.day}, ${cancelledAt.year}';
      final reason = req.cancelReason.trim();
      if (reason.isNotEmpty) {
        return '$when • Reason: $reason';
      }
      return when;
    }

    return submittedFallback;
  }

  String _pickProfileImage(String raw) {
    final p = raw.trim();
    if (p.isEmpty) return '';
    if (p.startsWith('http://') ||
        p.startsWith('https://') ||
        p.startsWith('gs://') ||
        p.startsWith('company_custom_requests/') ||
        p.startsWith('company/') ||
        p.startsWith('clients/') ||
        p.startsWith('client_custom_requests/') ||
        p.startsWith('artists/') ||
        p.startsWith('client_artists/') ||
        p.startsWith('blob:') ||
        p.startsWith('data:') ||
        p.startsWith('content://') ||
        p.startsWith('file://') ||
        p.startsWith('assets/')) {
      return p;
    }
    if (!p.contains('://') && p.contains('/')) {
      return p;
    }
    if (!kIsWeb && (p.startsWith('/') || p.contains(':\\'))) {
      return p;
    }
    return '';
  }

  String _safeCardAvatar({required String profileImage}) {
    return _pickProfileImage(profileImage);
  }

  OrderStatus _statusFromRequestStatus(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'pending':
      case 'submitted':
      case 'new':
      case 'new_request':
      case 'newrequest':
        return OrderStatus.newOrder;
      case 'in_review':
      case 'in review':
      case 'inreview':
        return OrderStatus.newOrder;
      case 'in_progress':
      case 'in progress':
      case 'inprogress':
      case 'accepted':
      case 'designing':
      case 'completed':
        return OrderStatus.inProgress;
      case 'shipped':
        return OrderStatus.shipped;
      case 'delivered':
        return OrderStatus.delivered;
      case 'expired':
        return OrderStatus.expired;
      case 'declined':
        return OrderStatus.declined;
      case 'cancelled':
      case 'canceled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.newOrder;
    }
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

  List<ClientOrder> get _orders {
    return _submittedOrders;
  }

  List<ClientOrder> get _filteredOrders {
    switch (_filter) {
      case OrdersFilter.all:
        return _orders;
      case OrdersFilter.pending:
        return _orders.where(_isSubmittedOrder).toList();
      case OrdersFilter.inProgress:
        return _orders
            .where((o) => o.status == OrderStatus.inProgress)
            .toList();
      case OrdersFilter.shipped:
        return _orders.where((o) => o.status == OrderStatus.shipped).toList();
      case OrdersFilter.delivered:
        return _orders.where((o) => o.status == OrderStatus.delivered).toList();
      case OrdersFilter.cancelledExpired:
        return _orders
            .where(
              (o) =>
                  o.status == OrderStatus.cancelled ||
                  o.status == OrderStatus.expired,
            )
            .toList();
      case OrdersFilter.declined:
        return _orders.where((o) => o.status == OrderStatus.declined).toList();
    }
  }

  bool _isSubmittedOrder(ClientOrder order) =>
      order.status == OrderStatus.newOrder ||
      order.status == OrderStatus.inReview;

  // Pending = Submitted + In Progress + Shipped
  List<ClientOrder> get _pending => _filteredOrders
      .where(
        (o) =>
            _isSubmittedOrder(o) ||
            o.status == OrderStatus.inProgress ||
            o.status == OrderStatus.shipped,
      )
      .toList();

  // Past = Delivered + Expired + Cancelled
  List<ClientOrder> get _past => _filteredOrders
      .where(
        (o) =>
            o.status == OrderStatus.delivered ||
            o.status == OrderStatus.expired ||
            o.status == OrderStatus.cancelled ||
            o.status == OrderStatus.declined,
      )
      .toList();

  void _onAvatarMenuSelected(String value) {
    if (value == 'profile') {
      widget.onOpenProfile?.call();
      return;
    }
    if (value == 'history') {
      widget.onOpenHistory?.call();
      return;
    }
    if (value == 'calendar') {
      widget.onOpenCalendar?.call();
      return;
    }
    if (value == 'artist') {
      widget.onOpenArtist?.call();
      return;
    }
    if (value == 'logout') {
      _logout();
    }
  }

  Future<void> _logout() async {
    if (widget.onLogout != null) {
      await widget.onLogout!.call();
      return;
    }
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.snow,

      // ✅ Header same as Artists page: logo + centered title + notification + avatar menu
      appBar: widget.showCompanyChrome
          ? CompanyHeader(
              companyName: widget.companyName,
              onOpenProfile: widget.onOpenProfile,
              onLogout: widget.onLogout,
            )
          : AppBar(
              backgroundColor: AppColors.alabaster,
              surfaceTintColor: AppColors.alabaster,
              elevation: 0,
              toolbarHeight: 85,
              automaticallyImplyLeading: false,
              leadingWidth: 58,
              leading: NotificationBellButton(
                onTap: () {
                  NotificationsPage.showAsModal(context);
                },
                iconSize: 24,
              ),

              centerTitle: true,
              title: Image.asset(
                'assets/images/jnt_logo_black.png',
                height: 50,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),

              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _AvatarMenu(
                    onSelected: _onAvatarMenuSelected,
                    avatarUrl: widget.profile.basic.profileImageUrl,
                    displayName: widget.profile.basic.name,
                    showProfile: widget.showProfileMenu,
                    showHistory: widget.showExtendedAvatarMenu,
                    showCalendar: widget.showExtendedAvatarMenu,
                    showArtist: widget.showExtendedAvatarMenu,
                  ),
                ),
              ],
            ),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
        children: [
          _FilterTabs(
            selected: _filter,
            counts: <OrdersFilter, int>{
              OrdersFilter.all: _orders.length,
              OrdersFilter.pending: _orders
                  .where(
                    (o) =>
                        o.status == OrderStatus.newOrder ||
                        o.status == OrderStatus.inReview,
                  )
                  .length,
              OrdersFilter.inProgress: _orders
                  .where((o) => o.status == OrderStatus.inProgress)
                  .length,
              OrdersFilter.shipped: _orders
                  .where((o) => o.status == OrderStatus.shipped)
                  .length,
              OrdersFilter.delivered: _orders
                  .where((o) => o.status == OrderStatus.delivered)
                  .length,
              OrdersFilter.cancelledExpired: _orders
                  .where(
                    (o) =>
                        o.status == OrderStatus.cancelled ||
                        o.status == OrderStatus.expired,
                  )
                  .length,
              OrdersFilter.declined: _orders
                  .where((o) => o.status == OrderStatus.declined)
                  .length,
            },
            onChanged: (f) => setState(() => _filter = f),
          ),
          const SizedBox(height: 16),

          if (_pending.isNotEmpty) ...[
            const Text(
              'All Orders',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.blackCat,
              ),
            ),
            const SizedBox(height: 10),
            ..._pending.map(
              (o) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _OrderCard(
                  order: o,
                  showLeadingThumb: widget.showCompanyChrome,
                  onDetails: () => _openOrderDetails(context, o),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          if (_past.isNotEmpty) ...[
            const Text(
              'Past Orders',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.blackCat,
              ),
            ),
            const SizedBox(height: 10),
            ..._past.map(
              (o) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _OrderCard(
                  order: o,
                  showLeadingThumb: widget.showCompanyChrome,
                  onDetails: () => _openOrderDetails(context, o),
                ),
              ),
            ),
          ],

          if (_pending.isEmpty && _past.isEmpty) ...[
            const SizedBox(height: 28),
            _Card(
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 46,
                    color: Colors.black.withOpacity(0.35),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'No orders found',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.blackCat,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Try changing filters or place a new design request.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.blackCat.withOpacity(0.60),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: widget.showCompanyChrome
          ? CompanyBottomNav(
              currentIndex: widget.bottomNavIndex,
              onTap: (i) => widget.onNavTap?.call(i),
            )
          : null,
    );
  }

  void _openOrderDetails(BuildContext context, ClientOrder order) {
    Widget page;

    final sub = order.subtitle.toLowerCase();
    final isNew = sub.contains('new');
    final isInReview = sub.contains('review') || sub.contains('in review');

    switch (order.status) {
      case OrderStatus.newOrder:
        page = NewOrderDetailsPage(order: order);
        break;
      case OrderStatus.inReview:
        page = NewOrderDetailsPage(order: order);
        break;
      case OrderStatus.inProgress:
        page = InProgressOrderDetailsPage(order: order);
        break;
      case OrderStatus.shipped:
        page = ShippedOrderDetailsPage(order: order);
        break;
      case OrderStatus.delivered:
        page = DeliveredOrderDetailsPage(order: order);
        break;
      case OrderStatus.expired:
        page = ExpiredOrderDetailsPage(
          order: order,
          onResubmit: () => _resubmitCancelledOrder(order),
        );
        break;
      case OrderStatus.cancelled:
        page = CancelledOrderDetailsPage(
          order: order,
          onResubmit: () => _resubmitCancelledOrder(order),
        );
        break;
      case OrderStatus.declined:
        page = CancelledOrderDetailsPage(
          order: order,
          onResubmit: () => _resubmitCancelledOrder(order),
        );
        break;
    }

    if (isInReview) page = InReviewOrderDetailsPage(order: order);
    if (isNew) page = NewOrderDetailsPage(order: order);

    showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Order details',
      barrierDismissible: true,
      barrierColor: AppColors.blackCat.withOpacity(0.45),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.zero,
                child: Material(
                  color: AppColors.alabaster,
                  child: SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: page,
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _resubmitCancelledOrder(ClientOrder order) async {
    try {
      final requestRef = FirebaseFirestore.instance
          .collection('Client_Custom_Requests')
          .doc(order.id);
      final rootSnap = await requestRef.get();
      final detailSnap = await requestRef
          .collection('details')
          .doc('payload')
          .get();

      final rootData = rootSnap.data() ?? const <String, dynamic>{};
      final detailData = detailSnap.data() ?? const <String, dynamic>{};

      Map<String, dynamic> asMap(dynamic value) {
        if (value is Map<String, dynamic>) {
          return Map<String, dynamic>.from(value);
        }
        if (value is Map) {
          return value.map((k, v) => MapEntry(k.toString(), v));
        }
        return <String, dynamic>{};
      }

      final requestDetails = <String, dynamic>{
        ...asMap(rootData['requestDetails']),
        ...asMap(detailData['requestDetails']),
      };
      requestDetails['description'] ??=
          detailData['description'] ??
          rootData['description'] ??
          rootData['descriptionPreview'];

      final budget = <String, dynamic>{
        ...asMap(rootData['budget']),
        ...asMap(detailData['budget']),
      };
      budget['min'] ??= rootData['budgetMin'];
      budget['max'] ??= rootData['budgetMax'];

      final orderMap = <String, dynamic>{
        ...asMap(rootData['order']),
        ...asMap(detailData['order']),
      };
      orderMap['type'] ??= detailData['orderType'] ?? rootData['orderType'];
      orderMap['allowNonLicensed'] ??=
          detailData['allowNonLicensed'] ?? rootData['allowNonLicensed'];
      orderMap['selectedArtist'] ??=
          detailData['selectedArtist'] ?? rootData['selectedArtist'];
      orderMap['selectedArtistEmail'] ??=
          detailData['selectedArtistEmail'] ?? rootData['selectedArtistEmail'];
      orderMap['isDirectRequest'] ??=
          detailData['isDirectRequest'] ?? rootData['isDirectRequest'];
      orderMap['fallbackToPool'] ??=
          detailData['fallbackToPool'] ?? rootData['fallbackToPool'];

      final groupOrder = <String, dynamic>{
        ...asMap(rootData['groupOrder']),
        ...asMap(detailData['groupOrder']),
      };
      if (groupOrder['clients'] == null) {
        groupOrder['clients'] =
            orderMap['clients'] ??
            detailData['groupClients'] ??
            rootData['groupClients'];
      }
      groupOrder['isGroupOrder'] ??=
          detailData['isGroupOrder'] ?? rootData['isGroupOrder'];

      final initialRequestData = <String, dynamic>{
        ...rootData,
        ...detailData,
        'requestDetails': requestDetails,
        'budget': budget,
        'order': orderMap,
        'shipping': <String, dynamic>{
          ...asMap(rootData['shipping']),
          ...asMap(detailData['shipping']),
        },
        'groupOrder': groupOrder,
        'nailPreferences': <String, dynamic>{
          ...asMap(rootData['nailPreferences']),
          ...asMap(detailData['nailPreferences']),
        },
        'inspirationPhotos':
            (detailData['inspirationPhotos'] as List<dynamic>?) ??
            (rootData['inspirationPhotos'] as List<dynamic>?) ??
            const <dynamic>[],
      };

      // Keep all prior request data for resubmit, but force Need By to be empty.
      requestDetails.remove('needBy');
      requestDetails.remove('needByDisplay');
      initialRequestData.remove('needBy');
      initialRequestData.remove('needByDisplay');

      if (!mounted) return;
      Navigator.of(context).pop();
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ClientCustomRequestPage(
            profile: widget.profile,
            initialRequestData: initialRequestData,
            onBackHome: () => Navigator.of(context).pop(),
            showBottomNav: true,
            bottomNavIndex: 1,
            onNavTap: widget.onNavTap,
            onOpenProfile: widget.onOpenProfile,
            onOpenHistory: widget.onOpenHistory,
            onOpenCalendar: widget.onOpenCalendar,
            onOpenArtist: widget.onOpenArtist,
            onLogout: widget.onLogout,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load request for resubmit: $e')),
      );
    }
  }
}

/// ✅ Avatar dropdown (Logout)
class _AvatarMenu extends StatelessWidget {
  const _AvatarMenu({
    required this.onSelected,
    this.avatarUrl = '',
    this.displayName = '',
    this.showProfile = true,
    this.showHistory = true,
    this.showCalendar = true,
    this.showArtist = true,
  });
  final ValueChanged<String> onSelected;
  final String avatarUrl;
  final String displayName;
  final bool showProfile;
  final bool showHistory;
  final bool showCalendar;
  final bool showArtist;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '',
      offset: const Offset(0, 55),
      elevation: 8,
      color: AppColors.snow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      onSelected: onSelected,
      itemBuilder: (context) => [
        if (showProfile)
          PopupMenuItem<String>(
            value: 'profile',
            child: Row(
              children: const [
                Icon(Icons.person_outline, size: 22),
                SizedBox(width: 14),
                Text(
                  'Profile',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        if (showHistory)
          PopupMenuItem<String>(
            value: 'history',
            child: Row(
              children: const [
                Icon(Icons.history, size: 22),
                SizedBox(width: 14),
                Text(
                  'History',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        if (showCalendar)
          PopupMenuItem<String>(
            value: 'calendar',
            child: Row(
              children: const [
                Icon(Icons.calendar_month_outlined, size: 22),
                SizedBox(width: 14),
                Text(
                  'Calendar',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        if (showArtist)
          PopupMenuItem<String>(
            value: 'artist',
            child: Row(
              children: const [
                Icon(Icons.brush_outlined, size: 22),
                SizedBox(width: 14),
                Text(
                  'Artist',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        if (showProfile || showHistory || showCalendar || showArtist)
          const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: const [
              Icon(Icons.logout_rounded, size: 22, color: AppColors.blackCat),
              SizedBox(width: 14),
              Text(
                'Logout',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.blackCat,
                ),
              ),
            ],
          ),
        ),
      ],
      child: SizedBox(
        height: 36,
        width: 36,
        child: ClipRRect(
          borderRadius: BorderRadius.zero,
          child: ClientProfileAvatarIcon(
            imageUrl: avatarUrl,
            displayName: displayName,
            size: 36,
          ),
        ),
      ),
    );
  }
}

/// ---------------------------
/// Filter Pills
/// ---------------------------
class _FilterTabs extends StatelessWidget {
  const _FilterTabs({
    required this.selected,
    required this.counts,
    required this.onChanged,
  });

  final OrdersFilter selected;
  final Map<OrdersFilter, int> counts;
  final ValueChanged<OrdersFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _tab('All Orders', OrdersFilter.all),
            _tab('Pending', OrdersFilter.pending),
            _tab('In Progress', OrdersFilter.inProgress),
            _tab('Shipped', OrdersFilter.shipped),
            _tab('Delivered', OrdersFilter.delivered),
            _tab('Cancelled/Expired', OrdersFilter.cancelledExpired),
            _tab('Declined', OrdersFilter.declined),
          ],
        ),
      ),
    );
  }

  Widget _tab(String label, OrdersFilter value) {
    final bool isSelected = selected == value;
    final count = counts[value] ?? 0;

    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.zero,
      hoverColor: AppColors.balletSlippers.withValues(alpha: 0.35),
      splashColor: AppColors.balletSlippers.withValues(alpha: 0.45),
      highlightColor: AppColors.balletSlippers.withValues(alpha: 0.30),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
              child: Text(
                '$label #$count',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w500,
                  fontFamily: 'ArialBold',
                  color: isSelected
                      ? AppColors.blackCat
                      : AppColors.blackCat.withOpacity(0.55),
                ),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 3,
              width: isSelected ? 34 : 0,
              decoration: BoxDecoration(
                color: AppColors.balletSlippers,
                borderRadius: BorderRadius.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------
/// Order Card
/// ---------------------------
class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.onDetails,
    required this.showLeadingThumb,
  });

  final ClientOrder order;
  final VoidCallback onDetails;
  final bool showLeadingThumb;

  @override
  Widget build(BuildContext context) {
    final submittedLabel = order.createdAt == null
        ? 'Submitted -'
        : 'Submitted ${order.createdAt!.month.toString().padLeft(2, '0')}/${order.createdAt!.day.toString().padLeft(2, '0')}/${order.createdAt!.year}';

    return _Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (order.status == OrderStatus.shipped) ...[
                      SizedBox(
                        height: 30,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.blackCat,
                            foregroundColor: AppColors.snow,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TrackOrderPage(order: order),
                              ),
                            );
                          },
                          child: const Text(
                            'Track Order',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: AppColors.snow,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    _StatusChip(status: order.status),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  order.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.blackCat,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    fontStyle: FontStyle.normal,
                    fontFamily: 'Arial',
                  ),
                ),
                const SizedBox(height: 8),
                if (order.orderNumber.trim().isNotEmpty) ...[
                  Text(
                    'Order # : ${order.orderNumber}',
                    style: TextStyle(
                      color: AppColors.blackCat,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      fontFamily: 'Arial',
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'Need By: ${order.needByDisplay.trim().isEmpty ? '-' : order.needByDisplay.trim()}  ',
                  style: TextStyle(
                    color: AppColors.blackCat,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    fontFamily: 'Arial',
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      submittedLabel,
                      style: TextStyle(
                        color: AppColors.blackCat.withOpacity(0.70),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        fontFamily: 'Arial',
                      ),
                    ),
                    const Spacer(),
                    _OrderDetailsLink(onTap: onDetails),
                  ],
                ),
                if (order.artistAcceptedAmount != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Final Amount: \$${order.artistAcceptedAmount}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF2E8B57),
                      fontFamily: 'Arial',
                    ),
                  ),
                ],
                if (!order.expectedOrDeliveredText
                    .trim()
                    .toLowerCase()
                    .startsWith('submitted'))
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      order.expectedOrDeliveredText,
                      style: TextStyle(
                        color: AppColors.blackCat.withOpacity(0.55),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        fontFamily: 'Arial',
                      ),
                    ),
                  ),

                // ✅ Rating (font fix here)
                if (order.status == OrderStatus.delivered &&
                    (order.rating ?? 0) > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _Stars(rating: order.rating ?? 0),
                      const SizedBox(width: 8),
                      Text(
                        (order.rating ?? 0).toStringAsFixed(1),
                        style: const TextStyle(
                          fontWeight: FontWeight.w500, // ✅ match rest of UI
                          fontSize: 12, // ✅ match rest of UI
                          fontFamily: 'Arial',
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.imageAsset});
  final String imageAsset;

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
        p.startsWith('gs%3A') ||
        p.startsWith('blob%3A') ||
        p.startsWith('http%3A') ||
        p.startsWith('https%3A')) {
      p = Uri.decodeFull(p);
    }
    for (var i = 0; i < 2; i++) {
      final decoded = Uri.decodeFull(p);
      if (decoded == p) break;
      p = decoded;
    }
    return p;
  }

  @override
  Widget build(BuildContext context) {
    final p = _normalizeImagePath(imageAsset);
    final isNetwork =
        p.startsWith('http://') ||
        p.startsWith('https://') ||
        p.startsWith('gs://') ||
        p.startsWith('blob:') ||
        p.startsWith('data:') ||
        p.startsWith('content://');
    final isStoragePath = _looksLikeStoragePath(p);
    final isAsset = p.startsWith('assets/');
    final isFileUri = p.startsWith('file://');
    final isFile = !kIsWeb && (p.startsWith('/') || p.contains(':\\'));
    Widget fallback() => Container(
      height: 64,
      width: 64,
      decoration: BoxDecoration(
        color: AppColors.balletSlippers,
        borderRadius: BorderRadius.zero,
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: AppColors.blackCat.withOpacity(0.35),
      ),
    );
    Widget image;
    if (p.startsWith('data:image/')) {
      image = Builder(
        builder: (_) {
          try {
            final comma = p.indexOf(',');
            if (comma > 0) {
              final bytes = base64Decode(p.substring(comma + 1).trim());
              return Image.memory(
                bytes,
                height: 64,
                width: 64,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback(),
              );
            }
          } catch (_) {}
          return fallback();
        },
      );
    } else if (p.startsWith('gs://')) {
      image = FutureBuilder<String>(
        future: StorageUrlResolver.resolve(p).then((v) => v ?? ''),
        builder: (_, snap) {
          final url = snap.data?.trim() ?? '';
          if (url.isEmpty) return fallback();
          return Image.network(
            url,
            height: 64,
            width: 64,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback(),
          );
        },
      );
    } else if (isStoragePath) {
      image = FutureBuilder<String>(
        future: StorageUrlResolver.resolve(p).then((v) => v ?? ''),
        builder: (_, snap) {
          final url = snap.data?.trim() ?? '';
          if (url.isEmpty) return fallback();
          return Image.network(
            url,
            height: 64,
            width: 64,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback(),
          );
        },
      );
    } else if (isNetwork) {
      image = Image.network(
        p,
        height: 64,
        width: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      );
    } else if (isAsset) {
      image = Image.asset(
        p,
        height: 64,
        width: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      );
    } else if (isFileUri || isFile) {
      final localPath = isFileUri ? p.replaceFirst('file://', '') : p;
      image = Image.file(
        File(localPath),
        height: 64,
        width: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      );
    } else {
      image = fallback();
    }
    return ClipRRect(borderRadius: BorderRadius.zero, child: image);
  }

  bool _looksLikeStoragePath(String value) {
    final v = value.trim().toLowerCase();
    if (v.isEmpty) return false;
    if (v.startsWith('/') ||
        v.startsWith('assets/') ||
        v.startsWith('file://') ||
        v.startsWith('http://') ||
        v.startsWith('https://') ||
        v.startsWith('gs://') ||
        v.startsWith('data:') ||
        v.startsWith('blob:') ||
        v.startsWith('content://')) {
      return false;
    }
    if (v.contains(':\\')) return false;
    return v.contains('/');
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    late final String text;
    switch (status) {
      case OrderStatus.newOrder:
        text = 'Pending';
        break;
      case OrderStatus.inReview:
        text = 'In Review';
        break;
      case OrderStatus.inProgress:
        text = 'In Progress';
        break;
      case OrderStatus.shipped:
        text = 'Shipped';
        break;
      case OrderStatus.delivered:
        text = 'Delivered';
        break;
      case OrderStatus.expired:
        text = 'Expired';
        break;
      case OrderStatus.cancelled:
        text = 'Cancelled';
        break;
      case OrderStatus.declined:
        text = 'Declined';
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

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.zero,
      child: Container(
        height: 8,
        color: AppColors.blackCat.withOpacity(0.06),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value,
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFF28B8B),
                    AppColors.blackCat.withOpacity(0.60),
                    const Color(0xFF7BD9A5),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderDetailsLink extends StatelessWidget {
  const _OrderDetailsLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      hoverColor: AppColors.balletSlippers.withValues(alpha: 0.35),
      splashColor: AppColors.balletSlippers.withValues(alpha: 0.45),
      highlightColor: AppColors.balletSlippers.withValues(alpha: 0.30),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Order details',
              style: TextStyle(
                color: AppColors.blackCat.withOpacity(0.55),
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 6),
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

class _Stars extends StatelessWidget {
  const _Stars({required this.rating});
  final double rating;

  @override
  Widget build(BuildContext context) {
    final full = rating.floor().clamp(0, 5);
    return Row(
      children: List.generate(5, (i) {
        final filled = i < full;
        return Icon(
          filled ? Icons.star_rounded : Icons.star_border_rounded,
          size: 14,
          color: filled
              ? const Color(0xFFFFB000)
              : Colors.black.withOpacity(0.22),
        );
      }),
    );
  }
}

/// ---------------------------
/// Shared Card Container
/// ---------------------------
class _Card extends StatelessWidget {
  // ignore: unused_element_parameter
  const _Card({required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCat.withOpacity(0.80)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// ---------------------------
/// Models
/// ---------------------------
enum OrdersFilter {
  all,
  pending,
  inProgress,
  shipped,
  delivered,
  cancelledExpired,
  declined,
}

enum OrderStatus {
  newOrder,
  inReview,
  inProgress,
  shipped,
  delivered,
  expired,
  cancelled,
  declined,
}

class ClientOrder {
  final String id;
  final String orderNumber;
  final String title;
  final String subtitle;
  final bool hasAssignedArtist;
  final String orderType;
  final List<OrderClientMeasurement> groupClients;
  final String clientDescription;
  final String cancelReason;
  final List<String> inspirationPhotos;
  final String needByDisplay;
  final String nailShape;
  final String nailLength;
  final int? budgetMin;
  final int? budgetMax;
  final Map<String, String> leftHandDimensions;
  final Map<String, String> rightHandDimensions;
  final OrderStatus status;
  final String expectedOrDeliveredText;
  final DateTime? createdAt;
  final int? artistAcceptedAmount;
  final String paymentStatus;
  final String paymentLink;
  final DateTime? paidAt;
  final String clientProfileImage;
  final List<String> artistCompletedPhotos;
  final String completionReviewStatus;
  final String completionDeclineReason;
  final String completionDeclineDescription;
  final DateTime? completionDeclinedAt;
  final String designApprovalStatus;
  final DateTime? designApprovedAt;
  final DateTime? clientDesignApprovedAt;
  final DateTime? designSubmittedAt;
  final DateTime? designApprovalDueAt;
  final DateTime? designReminderSentAt;
  final List<String> designPreviewPhotos;
  final String clientEmail;
  final String acceptedByArtistEmail;
  final String directClientStatus;
  final String artistName;
  final String selectedArtistName;
  final String artistProfileImage;
  final DateTime? cancelledAt;
  final DateTime? needBy;
  final String shippedByCourier;
  final String trackingNumber;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;

  /// 0..1 progress for in-progress only
  final double? progress;

  /// rating for delivered only
  final double? rating;
  final String reviewText;
  final DateTime? reviewSubmittedAt;

  final String imageAsset;

  const ClientOrder({
    required this.id,
    this.orderNumber = '',
    required this.title,
    required this.subtitle,
    this.hasAssignedArtist = true,
    this.orderType = 'single',
    this.groupClients = const <OrderClientMeasurement>[],
    this.clientDescription = '',
    this.cancelReason = '',
    this.inspirationPhotos = const [],
    this.needByDisplay = '',
    this.nailShape = '',
    this.nailLength = '',
    this.budgetMin,
    this.budgetMax,
    this.leftHandDimensions = const {},
    this.rightHandDimensions = const {},
    required this.status,
    required this.expectedOrDeliveredText,
    required this.imageAsset,
    this.createdAt,
    this.artistAcceptedAmount,
    this.paymentStatus = '',
    this.paymentLink = '',
    this.paidAt,
    this.clientProfileImage = '',
    this.artistCompletedPhotos = const [],
    this.completionReviewStatus = '',
    this.completionDeclineReason = '',
    this.completionDeclineDescription = '',
    this.completionDeclinedAt,
    this.designApprovalStatus = '',
    this.designApprovedAt,
    this.clientDesignApprovedAt,
    this.designSubmittedAt,
    this.designApprovalDueAt,
    this.designReminderSentAt,
    this.designPreviewPhotos = const [],
    this.clientEmail = '',
    this.acceptedByArtistEmail = '',
    this.directClientStatus = '',
    this.artistName = '',
    this.selectedArtistName = '',
    this.artistProfileImage = '',
    this.cancelledAt,
    this.needBy,
    this.shippedByCourier = '',
    this.trackingNumber = '',
    this.shippedAt,
    this.deliveredAt,
    this.progress,
    this.rating,
    this.reviewText = '',
    this.reviewSubmittedAt,
  });
}

class OrderClientMeasurement {
  final String clientId;
  final String clientName;
  final String clientEmail;
  final String responseStatus;
  final String nailShape;
  final String nailLength;
  final Map<String, String> leftHandDimensions;
  final Map<String, String> rightHandDimensions;

  const OrderClientMeasurement({
    this.clientId = '',
    this.clientName = '',
    this.clientEmail = '',
    this.responseStatus = '',
    this.nailShape = '',
    this.nailLength = '',
    this.leftHandDimensions = const <String, String>{},
    this.rightHandDimensions = const <String, String>{},
  });
}
