import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../models/client_request_v2.dart';
import '../services/artist_requests_repository.dart';
import '../services/notifications_service.dart';
import '../theme/app_colors.dart';
import '../utils/scenario_4_3.dart';
import '../widgets/artist_profile_avatar_icon.dart';
import '../widgets/notification_bell_button.dart';
import 'artist_requests_page_redesign.dart' show InReviewDetailsSheet;
import 'artist_reviews_page.dart';
import 'notifications_page.dart';
import 'dart:typed_data';

const int _maxInlineAvatarBytes = 12 * 1024 * 1024;

Uint8List? _tryDecodeInlineImage(
  String src, {
  int maxBytes = _maxInlineAvatarBytes,
}) {
  final value = src.trim();
  if (!value.startsWith('data:image/')) return null;
  final comma = value.indexOf(',');
  if (comma <= 0 || comma >= value.length - 1) return null;
  try {
    final bytes = base64Decode(value.substring(comma + 1));
    if (bytes.isEmpty || bytes.lengthInBytes > maxBytes) return null;
    return bytes;
  } catch (_) {
    return null;
  }
}

class ArtistHomePage extends StatefulWidget {
  const ArtistHomePage({
    super.key,
    required this.onOpenRequests,
    required this.onManageProfile,
    required this.onOpenInbox,
    required this.onSignOut,
    required this.onOpenEarnings,
    required this.onOpenHistory,
    required this.onOpenInProgress,
    this.headerBottom,
  });

  final VoidCallback onOpenRequests;
  final VoidCallback onManageProfile;
  final VoidCallback onOpenInbox;
  final VoidCallback onSignOut;
  final VoidCallback onOpenEarnings;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenInProgress;
  final Widget? headerBottom;

  @override
  State<ArtistHomePage> createState() => _ArtistHomePageState();
}

class _ArtistHomePageState extends State<ArtistHomePage> {
  bool _online = true;
  bool _isLoading = true;

  RealtimeChannel? _requestsChannel;

  int _newRequests = 0;
  int _inProgress = 0;
  int _inboxCount = 0;
  int _deliveredCount = 0;
  double _earnings = 0;

  List<ClientRequestV2> _recentRequests = const <ClientRequestV2>[];
  String _artistDisplayName = '';
  bool _identityLoaded = false;

  @override
  void initState() {
    super.initState();
    _bindRealtime();
    _reloadDashboard();
  }

  @override
  void dispose() {
    _requestsChannel?.unsubscribe();
    super.dispose();
  }

  void _bindRealtime() {
    _requestsChannel?.unsubscribe();
    _requestsChannel = Supabase.instance.client
        .channel('artist_home_requests')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'client_custom_requests',
          callback: (_) => _reloadDashboard(),
        )
        .subscribe((status, [error]) {
          if (error != null) {
            debugPrint('Artist home realtime error: $error');
          }
        });
  }

  Future<void> _loadArtistIdentity() async {
    if (_identityLoaded && _artistDisplayName.isNotEmpty) return;

    final supabase = Supabase.instance.client;
    final uid = (supabase.auth.currentUser?.id ?? '').trim();
    final email =
        (supabase.auth.currentUser?.email ?? '').trim().toLowerCase();
    if (uid.isEmpty && email.isEmpty) return;

    Map<String, dynamic>? row;
    for (final table in const <String>['artist', 'client_artist']) {
      try {
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
        if (row != null) break;
      } catch (_) {}
    }

    String firstNonEmpty(List<Object?> values) {
      for (final raw in values) {
        final text = (raw ?? '').toString().trim();
        if (text.isNotEmpty) return text;
      }
      return '';
    }

    final data = row ?? const <String, dynamic>{};
    final profile =
        (data['profile'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final nextName = firstNonEmpty([
      profile['displayName'],
      profile['studioName'],
      data['displayName'],
      data['display_name'],
      data['name'],
      (supabase.auth.currentUser?.userMetadata?['display_name'] as String?),
      email.contains('@') ? email.split('@').first : email,
      'A',
    ]);
    if (!mounted) return;
    setState(() {
      _artistDisplayName = nextName;
      _identityLoaded = true;
    });
  }

  Future<void> _reloadDashboard() async {
    try {
      await _loadArtistIdentity();
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

      final newRequests = visible
          .where((r) => r.status == RequestStatusV2.inReview)
          .length;

      final inProgress = visible
          .where(
            (r) =>
                r.status == RequestStatusV2.accepted ||
                r.status == RequestStatusV2.designing ||
                r.status == RequestStatusV2.completed ||
                r.status == RequestStatusV2.shipped,
          )
          .length;

      final deliveredCount = visible
          .where((r) => r.status == RequestStatusV2.delivered)
          .length;

      final recent =
          visible.where((r) => r.status == RequestStatusV2.inReview).toList()
            ..sort((a, b) => b.neededBy.compareTo(a.neededBy));

      final paidEarnings = visible
          .where((r) {
            final p = r.paymentStatus.trim().toLowerCase();
            return p == 'paid' || p == 'completed';
          })
          .fold<double>(0, (sum, r) => sum + r.budgetMax.toDouble());

      setState(() {
        _newRequests = newRequests;
        _inProgress = inProgress;
        _deliveredCount = deliveredCount;
        _recentRequests = recent;
        _earnings = paidEarnings;
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
    final directTargetEmail = request.selectedArtistEmail.trim().toLowerCase();
    final isOwnedByCurrentArtist =
        artistEmail.isNotEmpty && ownedBy == artistEmail;
    final declinedByCurrentArtist =
        artistEmail.isNotEmpty &&
        request.declinedByArtistEmails.contains(artistEmail);

    switch (request.status) {
      case RequestStatusV2.inReview:
        final hiddenByDirectTarget =
            request.isDirectRequest &&
            directTargetEmail.isNotEmpty &&
            artistEmail.isNotEmpty &&
            directTargetEmail != artistEmail;
        return !declinedByCurrentArtist && !hiddenByDirectTarget;
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

  void _openNotifications() {
    NotificationsPage.showAsModal(context);
  }

  String _shortDate(DateTime d) {
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
    return '${months[d.month - 1]} ${d.day}';
  }

  void _applyResolvedInReviewLocally(String requestId) {
    setState(() {
      _recentRequests = _recentRequests
          .where((r) => r.id != requestId)
          .toList(growable: false);
      if (_newRequests > 0) {
        _newRequests -= 1;
      }
    });
  }

  Future<void> _persistArtistDecline(ClientRequestV2 request) async {
    final artistEmail = (Supabase.instance.client.auth.currentUser?.email ?? '')
        .trim()
        .toLowerCase();
    if (artistEmail.isEmpty) throw Exception('Missing signed-in artist email.');

    final selectedArtistByName = request.selectedArtist.trim().toLowerCase();
    final selectedArtistEmail = request.selectedArtistEmail.trim().toLowerCase();
    final artistDisplayNameLower = _artistDisplayName.trim().toLowerCase();
    final artistEmailLocalLower = artistEmail.contains('@')
        ? artistEmail.split('@').first.trim().toLowerCase()
        : '';
    final isNameMatch =
        selectedArtistByName.isNotEmpty &&
        (selectedArtistByName == artistDisplayNameLower ||
            selectedArtistByName == artistEmailLocalLower);
    final isDirectForCurrentArtist =
        request.isDirectRequest &&
        ((selectedArtistEmail.isNotEmpty &&
                selectedArtistEmail == artistEmail) ||
            (selectedArtistEmail.isEmpty && isNameMatch));
    final releaseDirectToPool =
        isDirectForCurrentArtist && request.fallbackToPool;
    final cancelDirectRequest =
        isDirectForCurrentArtist && !request.fallbackToPool;
    const artistCancelReason = 'Declined by selected artist';

    final supabase = Supabase.instance.client;

    // Atomic array append via SQL RPC — eliminates read + race condition.
    await supabase.rpc('append_declined_artist', params: {
      'request_id': request.id,
      'artist_email': artistEmail,
    });

    if (releaseDirectToPool || cancelDirectRequest) {
      final statusUpdates = <String, dynamic>{};
      if (releaseDirectToPool) {
        statusUpdates['status'] = 'in_review';
        statusUpdates['client_status'] = 'pending';
        statusUpdates['artist_status'] = 'in_review';
        statusUpdates['is_direct_request'] = false;
        statusUpdates['selected_artist'] = '';
        statusUpdates['selected_artist_email'] = '';
      }
      if (cancelDirectRequest) {
        statusUpdates['status'] = 'cancelled';
        statusUpdates['client_status'] = 'cancelled';
        statusUpdates['artist_status'] = 'cancelled';
        statusUpdates['cancel_reason'] = artistCancelReason;
        statusUpdates['cancelled_at'] = DateTime.now().toIso8601String();
      }
      await supabase
          .from('client_custom_requests')
          .update(statusUpdates)
          .eq('id', request.id);
    }

    // Firestore mirror (fire-and-forget for backward compat)
    unawaited(
      _mirrorDeclineToFirestore(
        request: request,
        artistEmail: artistEmail,
        releaseDirectToPool: releaseDirectToPool,
        cancelDirectRequest: cancelDirectRequest,
        artistCancelReason: artistCancelReason,
      ).catchError((_) {}),
    );

    // Notifications — use request fields directly; no Firestore doc reads needed
    String _firstNE(List<Object?> values, {String fallback = ''}) {
      for (final v in values) {
        final t = (v ?? '').toString().trim();
        if (t.isNotEmpty) return t;
      }
      return fallback;
    }

    final artistName = _firstNE([
      Supabase.instance.client.auth.currentUser?.userMetadata?['display_name'],
    ], fallback: artistEmail.split('@').first);

    if (releaseDirectToPool) {
      final orderRef = _firstNE([request.orderNumber], fallback: request.id);
      final brandName =
          _firstNE([request.brandName, request.clientName], fallback: 'Brand');
      final campaignName = _firstNE([request.title], fallback: 'Campaign');
      final acceptedClientName = _firstNE(
        [request.acceptedClientName, request.selectedClient],
        fallback: 'Client',
      );

      final brandRecipientEmails =
          await NotificationsService.resolveBrandRecipientEmails(
            rootData: <String, dynamic>{
              'requesterEmail': request.clientEmail,
              'companyEmail': request.clientEmail,
            },
            excludeEmails: <String>[artistEmail],
          );

      for (final brandEmail in brandRecipientEmails) {
        await NotificationsService.createUserNotification(
          receiverEmail: brandEmail,
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

  Future<void> _mirrorDeclineToFirestore({
    required ClientRequestV2 request,
    required String artistEmail,
    required bool releaseDirectToPool,
    required bool cancelDirectRequest,
    required String artistCancelReason,
  }) async {
    final docRef = FirebaseFirestore.instance
        .collection(request.sourceCollection)
        .doc(request.id);
    final batch = FirebaseFirestore.instance.batch();
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
  }

  Future<bool> _persistArtistAcceptance(
    ClientRequestV2 request,
    _HomeAcceptResult accepted,
  ) async {
    final total = accepted.yourPrice + accepted.shipping + accepted.extra;
    final normalizedTotal = double.parse(total.toStringAsFixed(2));
    final roundedTotal = normalizedTotal.round();
    final artistEmail = (Supabase.instance.client.auth.currentUser?.email ?? '')
        .trim()
        .toLowerCase();
    final paymentLink =
        'jnt://payment?order=${request.id}&collection=${request.sourceCollection}';
    final now = DateTime.now().toIso8601String();

    final supabase = Supabase.instance.client;

    // Find the row in Supabase (try ID first, then orderNumber fallback)
    Map<String, dynamic>? existingRow = await supabase
        .from('client_custom_requests')
        .select('id, details')
        .eq('id', request.id)
        .maybeSingle();
    if (existingRow == null && request.orderNumber.trim().isNotEmpty) {
      existingRow = await supabase
          .from('client_custom_requests')
          .select('id, details')
          .eq('order_number', request.orderNumber.trim())
          .maybeSingle();
    }
    if (existingRow == null) return false;

    final rowId = (existingRow['id'] as String?) ?? request.id;
    final currentDetails =
        (existingRow['details'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};

    // Supabase write (primary)
    await supabase.from('client_custom_requests').update({
      'status': 'designing',
      'client_status': 'in_progress',
      'artist_status': 'designing',
      'accepted_by_artist_email': artistEmail,
      'artist_final_amount': normalizedTotal,
      'payment_status': 'pending',
      'payment_link': paymentLink,
      'updated_at': now,
      'details': {
        ...currentDetails,
        'artistQuote': {
          'yourPrice': accepted.yourPrice,
          'shipping': accepted.shipping,
          'extra': accepted.extra,
          'total': normalizedTotal,
        },
        'acceptance': {
          'status': 'accepted',
          'acceptedAt': now,
          'acceptedByArtistEmail': artistEmail,
        },
        'payment': {
          ...((currentDetails['payment'] as Map<String, dynamic>?) ??
              const <String, dynamic>{}),
          'status': 'pending',
          'paymentLink': paymentLink,
          'requestedAt': now,
        },
      },
    }).eq('id', rowId);

    // Firestore mirror (fire-and-forget for backward compat)
    unawaited(
      _mirrorAcceptanceToFirestore(
        request: request,
        artistEmail: artistEmail,
        normalizedTotal: normalizedTotal,
        paymentLink: paymentLink,
        accepted: accepted,
      ).catchError((_) {}),
    );

    // Notifications — use request fields directly
    String _firstNE(List<Object?> values) {
      for (final v in values) {
        final t = (v ?? '').toString().trim();
        if (t.isNotEmpty) return t;
      }
      return '';
    }

    final orderNumber =
        request.orderNumber.trim().isNotEmpty ? request.orderNumber.trim() : rowId;
    final amountText = '\$${roundedTotal.toString()}';
    final artistName = _firstNE([
      Supabase.instance.client.auth.currentUser?.userMetadata?['display_name'],
      artistEmail.split('@').first,
    ]);
    final clientReceiver =
        _firstNE([request.clientEmail]).toLowerCase();
    if (clientReceiver.isNotEmpty) {
      await NotificationsService.createUserNotification(
        receiverEmail: clientReceiver,
        title: 'Request Accepted',
        body: 'Great news! $artistName accepted your request. Final amount: $amountText',
        type: 'request_accepted_designing',
        orderId: rowId,
        orderNumber: orderNumber,
        sourceCollection: request.sourceCollection,
      );
    }
    if (request.sourceCollection == 'Company_Custom_Requests' &&
        artistEmail.isNotEmpty) {
      final campaignName = _firstNE([request.title]);
      var acceptedClientName =
          _firstNE([request.acceptedClientName, request.selectedClient]);
      if (acceptedClientName.isEmpty) acceptedClientName = 'Client';
      await NotificationsService.createUserNotification(
        receiverEmail: artistEmail,
        title: 'Brand Request Accepted',
        body: 'You accepted $campaignName brand request $orderNumber for $acceptedClientName.',
        type: 'artist_brand_request_accepted_self',
        orderId: rowId,
        orderNumber: orderNumber,
        sourceCollection: request.sourceCollection,
      );
    }
    return true;
  }

  Future<void> _mirrorAcceptanceToFirestore({
    required ClientRequestV2 request,
    required String artistEmail,
    required double normalizedTotal,
    required String paymentLink,
    required _HomeAcceptResult accepted,
  }) async {
    final docRef = FirebaseFirestore.instance
        .collection(request.sourceCollection)
        .doc(request.id);
    final snap = await docRef.get();
    if (!snap.exists) return;
    final batch = FirebaseFirestore.instance.batch();
    batch.set(docRef, {
      'status': 'designing',
      'updatedAt': FieldValue.serverTimestamp(),
      'artistAcceptedAt': FieldValue.serverTimestamp(),
      'acceptedByArtistEmail': artistEmail,
      'brandStatus': 'in_progress',
      'clientStatus': 'in_progress',
      'artistStatus': 'designing',
      'artistFinalAmount': normalizedTotal,
      'paymentStatus': 'pending',
      'paymentLink': paymentLink,
      'artistQuote': {
        'yourPrice': accepted.yourPrice,
        'shipping': accepted.shipping,
        'extra': accepted.extra,
        'total': normalizedTotal,
      },
    }, SetOptions(merge: true));
    batch.set(docRef.collection('details').doc('payload'), {
      'artistQuote': {
        'yourPrice': accepted.yourPrice,
        'shipping': accepted.shipping,
        'extra': accepted.extra,
        'total': normalizedTotal,
      },
      'acceptance': {
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
        'acceptedByArtistEmail': artistEmail,
      },
      'status': 'designing',
      'roleStatuses': {
        'brand': 'in_progress',
        'client': 'in_progress',
        'artist': 'designing',
      },
      'payment': {
        'status': 'pending',
        'paymentLink': paymentLink,
        'requestedAt': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> _openRecentRequest(ClientRequestV2 request) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InReviewDetailsSheet(
        request: request,
        onDecline: () async {
          Navigator.pop(context);
          try {
            _applyResolvedInReviewLocally(request.id);
            await _persistArtistDecline(request);
            unawaited(_reloadDashboard());
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to decline request: $e')),
            );
          }
        },
        onAccept: () async {
          final accepted = await showDialog<_HomeAcceptResult>(
            context: context,
            barrierDismissible: true,
            builder: (_) => _HomeAcceptRequestDialog(
              budgetMin: request.budgetMin,
              budgetMax: request.budgetMax,
            ),
          );
          if (accepted == null) return;

          try {
            final persisted = await _persistArtistAcceptance(request, accepted);
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
            _applyResolvedInReviewLocally(request.id);
            unawaited(_reloadDashboard());
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to accept request: $e')),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(85),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/jnt_logo_1.png',
                  height: 50,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const SizedBox(width: 40, height: 40),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Welcome',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.blackCat.withValues(alpha: 0.55),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _artistDisplayName.trim().isEmpty
                            ? 'Artist'
                            : _artistDisplayName.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                NotificationBellButton(onTap: _openNotifications, iconSize: 24),
                const SizedBox(width: 6),
                _avatarMenu(),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (widget.headerBottom != null) widget.headerBottom!,
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              children: [
                _OverviewCard(
                  online: _online,
                  onToggleOnline: (v) => setState(() => _online = v),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _QuickTile(
                        title: 'New Requests',
                        value: _isLoading ? '...' : '$_newRequests',
                        icon: Icons.fiber_new_rounded,
                        onTap: widget.onOpenRequests,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickTile(
                        title: 'In Progress',
                        value: _isLoading ? '...' : '$_inProgress',
                        icon: Icons.timelapse_rounded,
                        onTap: widget.onOpenInProgress,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _QuickTile(
                        title: 'Inbox',
                        value: _isLoading ? '...' : '$_inboxCount',
                        icon: Icons.mail_outline_rounded,
                        onTap: widget.onOpenInbox,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickTile(
                        title: 'Earnings',
                        value: _isLoading ? '...' : _money(_earnings),
                        icon: Icons.attach_money_rounded,
                        onTap: widget.onOpenEarnings,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Delivered Orders',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.blackCat.withValues(alpha: 0.90),
                  ),
                ),
                const SizedBox(height: 10),
                _SoftCard(
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_shipping_outlined,
                        color: AppColors.blackCat.withValues(alpha: 0.65),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _isLoading
                              ? 'Loading delivered orders...'
                              : '$_deliveredCount delivered orders in your history.',
                          style: TextStyle(
                            color: AppColors.blackCat.withValues(alpha: 0.70),
                            fontWeight: FontWeight.w400,
                            fontSize: 11.5,
                            height: 1.25,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: widget.onOpenHistory,
                        borderRadius: BorderRadius.zero,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.blackCat.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.zero,
                            border: Border.all(
                              color: AppColors.blackCat.withValues(alpha: 0.06),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Text(
                                'History',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: AppColors.blackCat.withValues(
                                  alpha: 0.55,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'In Review Requests',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.blackCat.withValues(alpha: 0.90),
                  ),
                ),
                const SizedBox(height: 10),
                if (_isLoading)
                  _SoftCard(
                    child: Text(
                      'Loading requests...',
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 11.5,
                        color: AppColors.blackCat.withValues(alpha: 0.65),
                      ),
                    ),
                  )
                else if (_recentRequests.isEmpty)
                  _SoftCard(
                    child: Text(
                      'No in review requests yet.',
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 11.5,
                        color: AppColors.blackCat.withValues(alpha: 0.65),
                      ),
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _recentRequests.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          mainAxisExtent: 160,
                        ),
                    itemBuilder: (context, index) {
                      final r = _recentRequests[index];
                      return _RecentRequestTile(
                        clientName: r.clientName,
                        statusText: r.status.label,
                        neededByText: _shortDate(r.neededBy),
                        avatarPath: r.clientProfileImage,
                        requestTypeText: r.isDirectRequest
                            ? 'Direct'
                            : 'Standard',
                        orderTypeText: r.orderType == RequestOrderTypeV2.group
                            ? 'Group Order'
                            : 'Single Order',
                        onTap: () => _openRecentRequest(r),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    widget.onSignOut();
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
          case _HeaderAvatarAction.reviews:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ArtistReviewsPage()),
            );
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
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: _HeaderAvatarAction.reviews,
          child: _HeaderMenuRow(
            icon: Icons.star_outline_rounded,
            label: 'Reviews',
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: _HeaderAvatarAction.signOut,
          child: _HeaderMenuRow(icon: Icons.logout_rounded, label: 'Logout'),
        ),
      ],
    );
  }

  String _money(double v) => '\$${v.toStringAsFixed(2)}';

  /*Widget _avatarContent() {
    Widget letterFallback() {
      final n = _artistDisplayName.trim();
      final letter = n.isEmpty ? 'A' : n.substring(0, 1).toUpperCase();
      return Container(
        color: AppColors.snow,
        alignment: Alignment.center,
        child: Text(
          letter,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.blackCat.withValues(alpha: 0.78),
          ),
        ),
      );
    }

    final src = _artistAvatarUrl.trim();
    if (src.isEmpty) {
      return FutureBuilder<String>(
        future: _resolveStorageAvatarFallback(),
        builder: (context, snapshot) {
          if (!snapshot.hasData &&
              snapshot.connectionState != ConnectionState.done) {
            return _avatarLoadingPlaceholder();
          }
          final resolved = (snapshot.data ?? '').trim();
          if (resolved.isEmpty) return letterFallback();
          return Image.network(
            resolved,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => letterFallback(),
          );
        },
      );
    }
    if (src.startsWith('data:image/')) {
      final bytes = _tryDecodeInlineImage(src);
      if (bytes == null) return letterFallback();
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => letterFallback(),
      );
    }
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return Image.network(
        src,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => FutureBuilder<String>(
          future: _resolveStorageAvatarFallback(),
          builder: (context, snapshot) {
            final resolved = (snapshot.data ?? '').trim();
            if (resolved.isEmpty) return letterFallback();
            return Image.network(
              resolved,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => letterFallback(),
            );
          },
        ),
      );
    }
    if (src.startsWith('gs://') ||
        src.startsWith('artists/') ||
        src.startsWith('client_artists/')) {
      return FutureBuilder<String>(
        future: _resolveStorageAvatarUrl(src),
        builder: (context, snapshot) {
          if (!snapshot.hasData &&
              snapshot.connectionState != ConnectionState.done) {
            return _avatarLoadingPlaceholder();
          }
          final resolved = (snapshot.data ?? '').trim();
          if (resolved.isEmpty) return letterFallback();
          return Image.network(
            resolved,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => FutureBuilder<String>(
              future: _resolveStorageAvatarFallback(),
              builder: (context, snapshot) {
                final fallbackSrc = (snapshot.data ?? '').trim();
                if (fallbackSrc.isEmpty) return letterFallback();
                return Image.network(
                  fallbackSrc,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => letterFallback(),
                );
              },
            ),
          );
        },
      );
    }
    return letterFallback();
  }*/

  /*Future<String> _resolveStorageAvatarUrl(String raw) async {
    final value = raw.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    try {
      if (value.startsWith('gs://')) {
        return await FirebaseStorage.instance
            .refFromURL(value)
            .getDownloadURL();
      }
      if (value.startsWith('artists/') || value.startsWith('client_artists/')) {
        return await FirebaseStorage.instance.ref(value).getDownloadURL();
      }
    } catch (_) {}
    return '';
  }*/

  /*Future<String> _resolveStorageAvatarFallback() async {
    final uid = (Supabase.instance.client.auth.currentUser?.id ?? '').trim();
    if (uid.isEmpty) return '';
    final candidates = <String>[
      'artists/$uid/profile/avatar.jpg',
      'artists/$uid/profile/avatar.jpeg',
      'artists/$uid/profile/avatar.png',
      'artists/$uid/profile/avatar.webp',
      'client_artists/$uid/profile/avatar.jpg',
      'client_artists/$uid/profile/avatar.jpeg',
      'client_artists/$uid/profile/avatar.png',
      'client_artists/$uid/profile/avatar.webp',
    ];
    for (final path in candidates) {
      try {
        final url = await FirebaseStorage.instance
            .ref(path)
            .getDownloadURL()
            .timeout(const Duration(seconds: 4));
        if (url.trim().isNotEmpty) return url.trim();
      } catch (_) {}
    }
    final folders = <String>[
      'artists/$uid/profile',
      'client_artists/$uid/profile',
    ];
    for (final folder in folders) {
      try {
        final listed = await FirebaseStorage.instance
            .ref(folder)
            .listAll()
            .timeout(const Duration(seconds: 4));
        for (final item in listed.items) {
          final name = item.name.toLowerCase();
          if (!(name.endsWith('.jpg') ||
              name.endsWith('.jpeg') ||
              name.endsWith('.png') ||
              name.endsWith('.webp'))) {
            continue;
          }
          final url = await item.getDownloadURL().timeout(
            const Duration(seconds: 4),
          );
          if (url.trim().isNotEmpty) return url.trim();
        }
      } catch (_) {}
    }
    return '';
  }*/
}

Widget _buildAnyRequestAvatar(String src, {required Widget fallback}) {
  final value = src.trim();
  if (value.isEmpty) return fallback;

  if (value.startsWith('data:image/')) {
    final bytes = _tryDecodeInlineImage(value);
    if (bytes == null) return fallback;
    return Image.memory(
      bytes,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    );
  }

  if (value.startsWith('http://') || value.startsWith('https://')) {
    return Image.network(
      value,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    );
  }

  if (value.startsWith('gs://') ||
      value.startsWith('clients/') ||
      value.startsWith('client_artists/')) {
    return FutureBuilder<String>(
      future: _resolveRequestStorageUrl(value),
      builder: (context, snapshot) {
        final resolved = (snapshot.data ?? '').trim();
        if (resolved.isEmpty) {
          return FutureBuilder<Uint8List?>(
            future: _resolveRequestStorageBytes(value),
            builder: (context, bytesSnap) {
              final bytes = bytesSnap.data;
              if (bytes == null || bytes.isEmpty) return fallback;
              return Image.memory(
                bytes,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              );
            },
          );
        }

        return Image.network(
          resolved,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        );
      },
    );
  }

  if (value.startsWith('assets/')) {
    return Image.asset(
      value,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    );
  }

  return fallback;
}

Future<Uint8List?> _resolveRequestStorageBytes(String raw) async {
  final value = raw.trim();
  if (value.isEmpty) return null;
  try {
    if (value.startsWith('gs://')) {
      return await FirebaseStorage.instance
          .refFromURL(value)
          .getData(3 * 1024 * 1024);
    }
    if (value.startsWith('clients/') || value.startsWith('client_artists/')) {
      return await FirebaseStorage.instance.ref(value).getData(3 * 1024 * 1024);
    }
  } catch (_) {}
  return null;
}

Future<String> _resolveRequestStorageUrl(String raw) async {
  final value = raw.trim();
  if (value.isEmpty) return '';
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }
  try {
    if (value.startsWith('gs://')) {
      return await FirebaseStorage.instance.refFromURL(value).getDownloadURL();
    }
    if (value.startsWith('clients/') || value.startsWith('client_artists/')) {
      return await FirebaseStorage.instance.ref(value).getDownloadURL();
    }
  } catch (_) {}
  return '';
}

class _HomeAcceptResult {
  const _HomeAcceptResult({
    required this.yourPrice,
    required this.shipping,
    required this.extra,
  });

  final double yourPrice;
  final double shipping;
  final double extra;
}

class _HomeAcceptRequestDialog extends StatefulWidget {
  const _HomeAcceptRequestDialog({
    required this.budgetMin,
    required this.budgetMax,
  });

  final int budgetMin;
  final int budgetMax;

  @override
  State<_HomeAcceptRequestDialog> createState() =>
      _HomeAcceptRequestDialogState();
}

class _HomeAcceptRequestDialogState extends State<_HomeAcceptRequestDialog> {
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

  double _toNum(String value) => double.tryParse(value.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final range = '\$${widget.budgetMin} - \$${widget.budgetMax}';
    final total = _toNum(_yourPriceCtrl.text) + _toNum(_shippingCtrl.text);
    final exceedsBudget = total > widget.budgetMax;

    return AlertDialog(
      backgroundColor: const Color(0xFFF7F7FB),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      title: const Text(
        'ACCEPT REQUEST',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: AppColors.blackCat,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _acceptRow('Price Range', range),
          const SizedBox(height: 8),
          _acceptField('Your Price', _yourPriceCtrl, prefix: '\$'),
          const SizedBox(height: 8),
          _acceptField(
            'Shipping + Extra',
            _shippingCtrl,
            prefix: '\$',
            enabled: false,
          ),
          const SizedBox(height: 10),
          _acceptRow('Total', '\$${total.toStringAsFixed(2)}'),
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
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      actions: [
        SizedBox(
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blackCat,
              foregroundColor: AppColors.snow,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              elevation: 0,
            ),
            onPressed: exceedsBudget
                ? null
                : () {
                    Navigator.pop(
                      context,
                      _HomeAcceptResult(
                        yourPrice: _toNum(_yourPriceCtrl.text),
                        shipping: _toNum(_shippingCtrl.text),
                        extra: 0,
                      ),
                    );
                  },
            child: const Text(
              'ACCEPT REQUEST',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: AppColors.blackCat.withValues(alpha: 0.6),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _acceptRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.blackCat.withValues(alpha: 0.65),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ],
    );
  }

  Widget _acceptField(
    String label,
    TextEditingController controller, {
    String prefix = '',
    bool enabled = true,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.blackCat.withValues(alpha: 0.65),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 130,
          child: TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              prefixText: prefix,
              filled: true,
              fillColor: AppColors.snow,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: enabled ? (_) => setState(() {}) : null,
          ),
        ),
      ],
    );
  }
}

enum _HeaderAvatarAction { reviews, signOut }

class _HeaderMenuRow extends StatelessWidget {
  const _HeaderMenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.blackCat.withValues(alpha: 0.70)),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.online, required this.onToggleOnline});

  final bool online;
  final ValueChanged<bool> onToggleOnline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: AppColors.blackCat.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today Overview',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.blackCat.withValues(alpha: 0.70),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                height: 8,
                width: 8,
                decoration: BoxDecoration(
                  color: online
                      ? const Color(0xFF2ECC71)
                      : AppColors.blackCatLight,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  online
                      ? 'Status: Online (accepting requests)'
                      : 'Status: Offline',
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 11.5,
                    color: AppColors.blackCat.withValues(alpha: 0.70),
                  ),
                ),
              ),
              Switch(
                value: online,
                onChanged: onToggleOnline,
                activeThumbColor: AppColors.blackCat,
                inactiveThumbColor: AppColors.blackCatLight,
                inactiveTrackColor: AppColors.blackCatLight.withValues(
                  alpha: 0.35,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.zero,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.snow,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: AppColors.blackCat.withValues(alpha: 0.03),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: AppColors.blackCat.withValues(alpha: 0.10),
                borderRadius: BorderRadius.zero,
              ),
              child: Icon(
                icon,
                size: 18,
                color: AppColors.blackCat.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                      color: AppColors.blackCat.withValues(alpha: 0.70),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
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
}

class _RecentRequestTile extends StatelessWidget {
  const _RecentRequestTile({
    required this.clientName,
    required this.statusText,
    required this.neededByText,
    required this.avatarPath,
    required this.requestTypeText,
    required this.orderTypeText,
    required this.onTap,
  });

  final String clientName;
  final String statusText;
  final String neededByText;
  final String avatarPath;
  final String requestTypeText;
  final String orderTypeText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarPath.trim().isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        decoration: BoxDecoration(
          color: AppColors.snow,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: AppColors.blackCat.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: AppColors.blackCat.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.zero,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: hasAvatar
                      ? _buildAnyRequestAvatar(
                          avatarPath,
                          fallback: _initialFallback(clientName),
                        )
                      : _initialFallback(clientName),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    clientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.blackCat.withValues(alpha: 0.45),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: AppColors.blackCat.withValues(alpha: 0.55),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Needed by $neededByText',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 11.5,
                      color: AppColors.blackCat.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _miniChip(Icons.verified_user_outlined, requestTypeText),
                _miniChip(Icons.group_outlined, orderTypeText),
              ],
            ),
            const Spacer(),
            Divider(
              height: 1,
              color: AppColors.blackCat.withValues(alpha: 0.06),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.circle, size: 8, color: Colors.amber.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      color: AppColors.blackCat.withValues(alpha: 0.72),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _initialFallback(String name) {
    final letter = name.trim().isEmpty ? 'C' : name.trim()[0].toUpperCase();

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.blackCat.withValues(alpha: 0.10),
        borderRadius: BorderRadius.zero,
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: AppColors.blackCat,
        ),
      ),
    );
  }

  Widget _miniChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FB),
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: AppColors.blackCat.withValues(alpha: 0.55),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 10.5,
              color: AppColors.blackCat.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: AppColors.blackCat.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}
