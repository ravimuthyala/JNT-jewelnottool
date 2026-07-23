import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/client_profile_models.dart';
import '../theme/app_colors.dart';
import '../services/client_custom_request_repository.dart';
import '../utils/date_format_utils.dart';
import '../services/notifications_service.dart';
import '../widgets/company_shell_chrome.dart';
import '../widgets/client_profile_avatar_icon.dart';
import '../widgets/jnt_standard_app_bar.dart';
import 'client_custom_request_page.dart';
import 'notifications_page.dart';
import 'track_order_page.dart';
import 'brand_order_details_page.dart';

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
  RealtimeChannel? _submittedRequestsChannel;
  List<ClientOrder> _submittedOrders = const [];

  SupabaseClient get _client => Supabase.instance.client;

  User? get _currentUser => _client.auth.currentUser;

  String get _currentUid => (_currentUser?.id ?? '').trim();

  String get _currentEmail => (_currentUser?.email ?? '').trim().toLowerCase();

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  String _firstNonEmpty(List<Object?> values, {String fallback = ''}) {
    for (final value in values) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  String firstNonEmpty(List<Object?> values, {String fallback = ''}) {
    return _firstNonEmpty(values, fallback: fallback);
  }

  String _snakeLookup(Map<String, dynamic> row, String key) {
    final lower = key.toLowerCase();
    return row.keys.firstWhere(
      (candidate) => candidate.toLowerCase() == lower,
      orElse: () => key,
    );
  }

  dynamic _rowValue(
    Map<String, dynamic> row,
    List<String> keys, {
    Map<String, dynamic>? payload,
    Map<String, dynamic>? details,
  }) {
    for (final key in keys) {
      final rowKey = _snakeLookup(row, key);
      if (row.containsKey(rowKey) && row[rowKey] != null) {
        final value = row[rowKey];
        if (value is String && value.trim().isEmpty) continue;
        return value;
      }
      if (payload != null && payload.containsKey(key) && payload[key] != null) {
        final value = payload[key];
        if (value is String && value.trim().isEmpty) continue;
        return value;
      }
      if (details != null && details.containsKey(key) && details[key] != null) {
        final value = details[key];
        if (value is String && value.trim().isEmpty) continue;
        return value;
      }
    }
    return null;
  }

  String _rowString(
    Map<String, dynamic> row,
    List<String> keys, {
    Map<String, dynamic>? payload,
    Map<String, dynamic>? details,
    String fallback = '',
  }) {
    return _firstNonEmpty(
      keys
          .map(
            (key) => _rowValue(row, [key], payload: payload, details: details),
          )
          .toList(growable: false),
      fallback: fallback,
    );
  }

  Map<String, dynamic> _normalizeBrandOrderIdentifierRow(
    Map<String, dynamic> row,
  ) {
    final normalized = Map<String, dynamic>.from(row);
    final payload = _asMap(normalized['payload']);
    final details = _asMap(normalized['details']);
    final requestDetails = _asMap(details['requestDetails']);
    final order = _asMap(details['order']);

    final canonicalOrderNumber = _firstNonEmpty([
      normalized['order_number'],
      normalized['orderNumber'],
      payload['order_number'],
      payload['orderNumber'],
      details['order_number'],
      details['orderNumber'],
      requestDetails['order_number'],
      requestDetails['orderNumber'],
      order['order_number'],
      order['orderNumber'],
      normalized['request_number'],
      normalized['requestNumber'],
      payload['request_number'],
      payload['requestNumber'],
      details['request_number'],
      details['requestNumber'],
      requestDetails['request_number'],
      requestDetails['requestNumber'],
      order['request_number'],
      order['requestNumber'],
    ]);

    if (canonicalOrderNumber.isEmpty) return normalized;

    normalized['order_number'] = canonicalOrderNumber;
    normalized['orderNumber'] = canonicalOrderNumber;
    normalized['request_number'] = canonicalOrderNumber;
    normalized['requestNumber'] = canonicalOrderNumber;

    return normalized;
  }

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
    if (_submittedRequestsChannel != null) {
      unawaited(_client.removeChannel(_submittedRequestsChannel!));
    }
    super.dispose();
  }

  Future<void> _subscribeSubmittedOrders() async {
    if (_submittedRequestsChannel != null) {
      unawaited(_client.removeChannel(_submittedRequestsChannel!));
      _submittedRequestsChannel = null;
    }
    final authEmail = _currentEmail;
    final profileEmail = widget.profile.basic.email.trim().toLowerCase();
    final effectiveEmail = profileEmail.isNotEmpty ? profileEmail : authEmail;
    final profileName = widget.profile.basic.name.trim();
    final effectiveName = profileName.isNotEmpty
        ? profileName
        : widget.companyName.trim();
    final uid = _currentUid;
    _submittedRequestsChannel =
        _client.channel('brand-order-company-custom-requests')
          ..onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'company_custom_requests',
            callback: (_) {
              unawaited(
                _loadSubmittedOrders(
                  authEmail: authEmail,
                  effectiveEmail: effectiveEmail,
                  effectiveName: effectiveName,
                  uid: uid,
                ),
              );
            },
          );
    await _submittedRequestsChannel!.subscribe();
    await _loadSubmittedOrders(
      authEmail: authEmail,
      effectiveEmail: effectiveEmail,
      effectiveName: effectiveName,
      uid: uid,
    );
  }

  Future<void> _loadSubmittedOrders({
    required String authEmail,
    required String effectiveEmail,
    required String effectiveName,
    required String uid,
  }) async {
    try {
      final rows = await _client.from('company_custom_requests').select();
      final rowMaps = rows
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
      final matchedRows = rowMaps
          .where(
            (row) => _matchesCompanyRequest(
              row,
              authEmail: authEmail,
              effectiveEmail: effectiveEmail,
              effectiveName: effectiveName,
              uid: uid,
            ),
          )
          .map(_normalizeBrandOrderIdentifierRow)
          .toList(growable: false);
      if (kDebugMode) {
        debugPrint(
          '[BrandOrderPage] company requests rows total=${rowMaps.length} matched=${matchedRows.length}',
        );
      }
      final summaries = await Future.wait(
        matchedRows.map(SubmittedClientRequestSummary.fromSupabaseRow),
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
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[BrandOrderPage] failed to load company requests: $e');
      }
    }
  }

  bool _matchesCompanyRequest(
    Map<String, dynamic> row, {
    required String authEmail,
    required String effectiveEmail,
    required String effectiveName,
    required String uid,
  }) {
    final payload = _asMap(row['payload']);
    final details = _asMap(row['details']);
    final requestType = _firstNonEmpty([
      row['request_type'],
      row['requestType'],
      payload['request_type'],
      payload['requestType'],
      details['request_type'],
      details['requestType'],
    ]).toLowerCase().trim();
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
    if (!allowedTypes.contains(requestType)) return false;
    final docUid = _firstNonEmpty([
      row['company_uid'],
      row['companyUid'],
      row['requester_uid'],
      row['requesterUid'],
      row['created_by_uid'],
      row['createdByUid'],
      row['uid'],
      payload['company_uid'],
      payload['companyUid'],
      details['company_uid'],
      details['companyUid'],
    ]);
    final companyEmail = _rowString(
      row,
      const ['company_email', 'companyEmail'],
      payload: payload,
      details: details,
    ).toLowerCase();
    final clientEmail = _rowString(
      row,
      const ['client_email', 'clientEmail'],
      payload: payload,
      details: details,
    ).toLowerCase();
    final companyName = _rowString(
      row,
      const ['company_name', 'companyName'],
      payload: payload,
      details: details,
    ).toLowerCase();
    final clientName = _rowString(
      row,
      const ['client_name', 'clientName'],
      payload: payload,
      details: details,
    ).toLowerCase();
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
        final row = await _client
            .from('company_custom_requests')
            .select()
            .eq('id', req.id)
            .maybeSingle();
        final current = _asMap(row);
        if (current.isEmpty) continue;
        final payload = _asMap(current['payload']);
        final details = _asMap(current['details']);
        final collection = req.sourceCollection.trim().isNotEmpty
            ? req.sourceCollection.trim()
            : 'Company_Custom_Requests';

        final acceptedClientEmail = firstNonEmpty(<Object?>[
          current['accepted_by_client_email'],
          current['acceptedByClientEmail'],
          req.acceptedByClientEmail,
        ]).toLowerCase();
        final currentStatus = firstNonEmpty([
          current['status'],
          current['client_status'],
          current['brand_status'],
          payload['status'],
          payload['clientStatus'],
          payload['brandStatus'],
          details['status'],
          details['clientStatus'],
          details['brandStatus'],
        ]).toLowerCase();
        if (currentStatus == 'expired' &&
            current['expired_notified_client'] == true &&
            (!isBrandRequest ||
                (current['expired_notified_brand_admin'] == true &&
                    (acceptedClientEmail.isEmpty ||
                        current['expired_notified_accepted_client'] ==
                            true)))) {
          continue;
        }
        final nowIso = now.toIso8601String();
        final updatedPayload = <String, dynamic>{
          ...payload,
          'status': 'expired',
          'expiredAt': nowIso,
          if (isBrandRequest) 'expiredReason': expirationReason,
          'expiredNotifiedClient': true,
          if (isBrandRequest) 'expiredNotifiedBrandAdmin': true,
          if (isBrandRequest && acceptedClientEmail.isNotEmpty)
            'expiredNotifiedAcceptedClient': true,
          'updatedAt': nowIso,
        };
        final updatedDetails = <String, dynamic>{
          ...details,
          'status': 'expired',
          'expiredAt': nowIso,
          if (isBrandRequest) 'expiredReason': expirationReason,
          'expiredNotifiedClient': true,
          if (isBrandRequest) 'expiredNotifiedBrandAdmin': true,
          if (isBrandRequest && acceptedClientEmail.isNotEmpty)
            'expiredNotifiedAcceptedClient': true,
          'updatedAt': nowIso,
        };
        await _client
            .from('company_custom_requests')
            .update({
              'status': 'expired',
              'expired_at': nowIso,
              'expired_notified_client': true,
              if (isBrandRequest) 'expired_notified_brand_admin': true,
              if (isBrandRequest && acceptedClientEmail.isNotEmpty)
                'expired_notified_accepted_client': true,
              'updated_at': nowIso,
              'payload': updatedPayload,
              'details': updatedDetails,
            })
            .eq('id', req.id);

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
        : 'Submitted ${formatDateMdy(submittedAt)}';
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
      jntRevealDateDisplay: req.jntRevealDateDisplay,
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
      selectedClientName: req.selectedClientName,
      selectedClientEmail: req.selectedClientEmail,
      selectedArtistName: selectedArtistName,
      openToClientPool: req.openToClientPool,
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
        return 'Expired ${formatDateMdy(due)}';
      }
      return 'Expired';
    }

    if (status == OrderStatus.cancelled) {
      final cancelledAt = req.cancelledAt;
      final when = cancelledAt == null
          ? 'Cancelled'
          : 'Cancelled ${formatDateMdy(cancelledAt)}';
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
    await _client.auth.signOut();
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
              imageUrl: widget.profile.basic.profileImageUrl,
              onOpenProfile: widget.onOpenProfile,
              onLogout: widget.onLogout,
            )
          : JntStandardAppBar(
              onNotifications: () {
                NotificationsPage.showAsModal(context);
              },
              trailing: _AvatarMenu(
                onSelected: _onAvatarMenuSelected,
                avatarUrl: widget.profile.basic.profileImageUrl,
                displayName: widget.profile.basic.name,
                showProfile: widget.showProfileMenu,
                showHistory: widget.showExtendedAvatarMenu,
                showCalendar: widget.showExtendedAvatarMenu,
                showArtist: widget.showExtendedAvatarMenu,
              ),
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
                    color: AppColors.blackCat.withValues(alpha: 0.35),
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
                      color: AppColors.blackCat.withValues(alpha: 0.60),
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
      barrierColor: AppColors.blackCat.withValues(alpha: 0.45),
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
      final row = await _client
          .from('company_custom_requests')
          .select()
          .eq('id', order.id)
          .maybeSingle();
      final rowData = _asMap(row);
      final rootData = <String, dynamic>{
        ...rowData,
        ..._asMap(rowData['payload']),
      };
      final detailData = _asMap(rowData['details']);

      final requestDetails = <String, dynamic>{
        ..._asMap(rootData['requestDetails']),
        ..._asMap(detailData['requestDetails']),
      };
      requestDetails['description'] ??=
          detailData['description'] ??
          rootData['description'] ??
          rootData['descriptionPreview'];

      final budget = <String, dynamic>{
        ..._asMap(rootData['budget']),
        ..._asMap(detailData['budget']),
      };
      budget['min'] ??= rootData['budgetMin'];
      budget['max'] ??= rootData['budgetMax'];

      final orderMap = <String, dynamic>{
        ..._asMap(rootData['order']),
        ..._asMap(detailData['order']),
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
        ..._asMap(rootData['groupOrder']),
        ..._asMap(detailData['groupOrder']),
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
        'payload': rootData['payload'],
        'details': detailData,
        'requestDetails': requestDetails,
        'budget': budget,
        'order': orderMap,
        'shipping': <String, dynamic>{
          ..._asMap(rootData['shipping']),
          ..._asMap(detailData['shipping']),
        },
        'groupOrder': groupOrder,
        'nailPreferences': <String, dynamic>{
          ..._asMap(rootData['nailPreferences']),
          ..._asMap(detailData['nailPreferences']),
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
        height: JntHeaderMetrics.avatarSize,
        width: JntHeaderMetrics.avatarSize,
        child: ClipRRect(
          borderRadius: BorderRadius.zero,
          child: ClientProfileAvatarIcon(
            imageUrl: avatarUrl,
            displayName: displayName,
            size: JntHeaderMetrics.avatarSize,
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
                      : AppColors.blackCat.withValues(alpha: 0.55),
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
                if (order.jntRevealDateDisplay.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'JNT Reveal Date: ${order.jntRevealDateDisplay.trim()}',
                    style: TextStyle(
                      color: AppColors.blackCat,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      fontFamily: 'Arial',
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      submittedLabel,
                      style: TextStyle(
                        color: AppColors.blackCat.withValues(alpha: 0.70),
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
                        color: AppColors.blackCat.withValues(alpha: 0.55),
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
                color: AppColors.blackCat.withValues(alpha: 0.55),
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.blackCat.withValues(alpha: 0.45),
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
              : AppColors.blackCat.withValues(alpha: 0.22),
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
        border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.80)),
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
  final String jntRevealDateDisplay;
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
  final String selectedClientName;
  final String selectedClientEmail;
  final String selectedArtistName;
  final bool openToClientPool;
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
    this.jntRevealDateDisplay = '',
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
    this.selectedClientName = '',
    this.selectedClientEmail = '',
    this.selectedArtistName = '',
    this.openToClientPool = true,
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
