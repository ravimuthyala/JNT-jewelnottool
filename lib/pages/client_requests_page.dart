import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/client_request_v2.dart';
import '../services/artist_requests_repository.dart';
import '../services/notifications_service.dart';
import '../services/storage_url_resolver.dart';
import '../theme/app_colors.dart';
import '../utils/scenario_4_1.dart';
import '../widgets/company_client_request_card.dart';
import '../widgets/client_profile_avatar_icon.dart';
import '../widgets/notification_bell_button.dart';
import 'client_request_details_page.dart';
import 'notifications_page.dart';

bool shouldShowScenario31ToDirectClient({
  required bool openToClientPool,
  required RequestOrderTypeV2 orderType,
  required String selectedClientEmail,
  required List<String> selectedGroupClientEmails,
  required String viewerEmail,
}) {
  return shouldShowScenario41ToDirectClient(
    openToClientPool: openToClientPool,
    orderType: orderType,
    selectedClientEmail: selectedClientEmail,
    selectedGroupClientEmails: selectedGroupClientEmails,
    viewerEmail: viewerEmail,
  );
}

class ClientRequestsPage extends StatefulWidget {
  const ClientRequestsPage({
    super.key,
    this.onOpenNotifications,
    this.onOpenProfile,
    this.onLogout,
    this.showProfileMenuItem = true,
  });

  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onLogout;
  final bool showProfileMenuItem;

  @override
  State<ClientRequestsPage> createState() => _ClientRequestsPageState();
}

class _ClientRequestsPageState extends State<ClientRequestsPage> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _companySub;
  bool _loading = true;
  List<ClientRequestV2> _items = const <ClientRequestV2>[];
  final Set<String> _hiddenRequestIds = <String>{};
  String _headerAvatarUrl = '';
  String _headerDisplayName = '';
  bool _currentClientIsBrandPartner = false;

  bool _isBrandPartnerClient(Map<String, dynamic> data) {
    String norm(Object? value) => (value ?? '').toString().trim().toLowerCase();
    final profile = (data['profile'] as Map<String, dynamic>?) ?? const {};
    final basic = (data['basic'] as Map<String, dynamic>?) ?? const {};
    final client = (data['client'] as Map<String, dynamic>?) ?? const {};
    final ascension = (data['ascension'] as Map<String, dynamic>?) ?? const {};
    final profileAscension =
        (profile['ascension'] as Map<String, dynamic>?) ?? const {};
    final basicAscension =
        (basic['ascension'] as Map<String, dynamic>?) ?? const {};
    final clientAscension =
        (client['ascension'] as Map<String, dynamic>?) ?? const {};

    bool hasTag(Object? raw) {
      if (raw is! List) return false;
      for (final item in raw) {
        final value = norm(item).replaceAll('_', ' ');
        if (value == 'brand partner' ||
            value == 'ambassador' ||
            value == '1m followers' ||
            value == '1m+ followers') {
          return true;
        }
      }
      return false;
    }

    final statuses = <String>[
      norm(ascension['status']),
      norm(profileAscension['status']),
      norm(basicAscension['status']),
      norm(clientAscension['status']),
      norm(data['status']),
      norm(data['partnerStatus']),
      norm(data['tier']),
      norm(profile['status']),
      norm(profile['partnerStatus']),
      norm(profile['tier']),
      norm(basic['status']),
      norm(basic['partnerStatus']),
      norm(basic['tier']),
    ];
    for (final status in statuses) {
      final normalized = status.replaceAll('_', ' ');
      if (normalized == 'brand partner' ||
          normalized.contains('brand partner') ||
          normalized == 'ambassador' ||
          normalized.contains('ambassador')) {
        return true;
      }
    }

    final boolFlags = <Object?>[
      data['brandPartner'],
      data['isBrandPartner'],
      data['panel_brandPartner'],
      profile['brandPartner'],
      profile['isBrandPartner'],
      basic['brandPartner'],
      basic['isBrandPartner'],
      client['brandPartner'],
      client['isBrandPartner'],
    ];
    for (final raw in boolFlags) {
      if (raw is bool && raw) return true;
      final text = norm(raw);
      if (text == 'true' || text == '1' || text == 'yes') return true;
    }

    bool followersAtLeast1M(Map<String, dynamic> map) {
      final possibleCounts = <Object?>[
        map['followers'],
        map['followerCount'],
        map['followersCount'],
        map['socialFollowers'],
        map['socialFollowerCount'],
      ];
      for (final value in possibleCounts) {
        if (value is num && value >= 1000000) return true;
        final parsed = num.tryParse((value ?? '').toString());
        if (parsed != null && parsed >= 1000000) return true;
      }
      final label = norm(
        map['followersLabel'] ??
            map['followerMilestone'] ??
            map['followersTier'],
      );
      return label.contains('1m');
    }

    final approvalSignals = <String>[
      norm(data['brandPartnerStatus']),
      norm(data['brandPartnerApproval']),
      norm(data['adminOverride']),
      norm(data['override']),
      norm(profile['brandPartnerStatus']),
      norm(profile['brandPartnerApproval']),
      norm(profile['adminOverride']),
      norm(profile['override']),
      norm(basic['brandPartnerStatus']),
      norm(basic['brandPartnerApproval']),
      norm(basic['adminOverride']),
      norm(basic['override']),
      norm(client['brandPartnerStatus']),
      norm(client['brandPartnerApproval']),
      norm(client['adminOverride']),
      norm(client['override']),
    ];
    final hasAdminOverride = approvalSignals.any(
      (v) => v == 'approved' || v == 'true' || v == '1' || v == 'yes',
    );

    final hasFollowers1M =
        followersAtLeast1M(data) ||
        followersAtLeast1M(profile) ||
        followersAtLeast1M(basic) ||
        followersAtLeast1M(client) ||
        followersAtLeast1M(ascension) ||
        followersAtLeast1M(profileAscension) ||
        followersAtLeast1M(basicAscension) ||
        followersAtLeast1M(clientAscension);
    if (hasAdminOverride || hasFollowers1M) return true;

    return hasTag(data['accountTags']) ||
        hasTag(profile['accountTags']) ||
        hasTag(basic['accountTags']) ||
        hasTag(client['accountTags']);
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadHeaderIdentity());
    _listenRequests();
  }

  @override
  void dispose() {
    _companySub?.cancel();
    super.dispose();
  }

  Future<void> _loadHeaderIdentity() async {
    final auth = FirebaseAuth.instance.currentUser;
    final uid = (auth?.uid ?? '').trim();
    final email = (auth?.email ?? '').trim().toLowerCase();
    String pick(Map<String, dynamic> data, List<String> keys) {
      for (final key in keys) {
        final value = (data[key] ?? '').toString().trim();
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    Future<Map<String, dynamic>?> readFrom(String collection) async {
      if (uid.isNotEmpty) {
        final byId = await FirebaseFirestore.instance
            .collection(collection)
            .doc(uid)
            .get();
        if (byId.exists) return byId.data();
      }
      if (email.isNotEmpty) {
        final byEmail = await FirebaseFirestore.instance
            .collection(collection)
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (byEmail.docs.isNotEmpty) return byEmail.docs.first.data();
      }
      return null;
    }

    for (final c in const <String>['client', 'client_artist']) {
      final data = await readFrom(c);
      if (data == null) continue;
      final profile = (data['profile'] as Map<String, dynamic>?) ?? const {};
      final basic = (data['basic'] as Map<String, dynamic>?) ?? const {};
      final avatar =
          pick(data, const ['profileImageUrl', 'avatarUrl']).isNotEmpty
          ? pick(data, const ['profileImageUrl', 'avatarUrl'])
          : (pick(profile, const [
                  'profileImageUrl',
                  'avatarUrl',
                  'photoUrl',
                ]).isNotEmpty
                ? pick(profile, const [
                    'profileImageUrl',
                    'avatarUrl',
                    'photoUrl',
                  ])
                : pick(basic, const [
                    'profileImageUrl',
                    'avatarUrl',
                    'photoUrl',
                  ]));
      final name = pick(data, const ['displayName', 'name']).isNotEmpty
          ? pick(data, const ['displayName', 'name'])
          : (pick(profile, const ['name', 'displayName']).isNotEmpty
                ? pick(profile, const ['name', 'displayName'])
                : pick(basic, const ['name', 'displayName']));
      if (!mounted) return;
      setState(() {
        _headerAvatarUrl = avatar;
        _headerDisplayName = name;
      });
      break;
    }
  }

  void _listenRequests() {
    _companySub?.cancel();
    _companySub = FirebaseFirestore.instance
        .collection('Company_Custom_Requests')
        .snapshots()
        .listen((_) {
          unawaited(_reload());
        });
    unawaited(_reload());
  }

  Future<void> _reload() async {
    try {
      final currentClientEmail =
          (FirebaseAuth.instance.currentUser?.email ?? '').trim().toLowerCase();
      if (currentClientEmail.isEmpty) {
        if (!mounted) return;
        setState(() {
          _items = const <ClientRequestV2>[];
          _loading = false;
        });
        return;
      }
      _currentClientIsBrandPartner = await _isCurrentClientBrandPartner(
        currentClientEmail,
      );
      if (!_currentClientIsBrandPartner) {
        if (!mounted) return;
        setState(() {
          _items = const <ClientRequestV2>[];
          _loading = false;
        });
        return;
      }

      final all = await ArtistRequestsRepository.fetchAllRequests();
      final filtered =
          all
              .where((r) => r.sourceCollection == 'Company_Custom_Requests')
              .where((r) => !_hiddenRequestIds.contains(r.id))
              .where(
                (r) => _isVisibleForClient(
                  request: r,
                  clientEmail: currentClientEmail,
                ),
              )
              .toList(growable: false)
            ..sort((a, b) => a.neededBy.compareTo(b.neededBy));

      if (!mounted) return;
      setState(() {
        _items = filtered;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items = const <ClientRequestV2>[];
        _loading = false;
      });
    }
  }

  Future<bool> _isCurrentClientBrandPartner(String clientEmail) async {
    final normalized = clientEmail.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    for (final collection in const <String>['client', 'client_artist']) {
      try {
        final byEmail = await FirebaseFirestore.instance
            .collection(collection)
            .where('email', isEqualTo: normalized)
            .limit(1)
            .get();
        if (byEmail.docs.isNotEmpty &&
            _isBrandPartnerClient(byEmail.docs.first.data())) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  bool _isVisibleForClient({
    required ClientRequestV2 request,
    required String clientEmail,
  }) {
    final viewerEmail = clientEmail.trim().toLowerCase();
    if (viewerEmail.isEmpty) return false;

    final isOpenForClientReview =
        request.status == RequestStatusV2.inReview ||
        request.status == RequestStatusV2.accepted;
    if (!isOpenForClientReview) return false;

    final clientResponseStatus = request.clientResponseStatus
        .trim()
        .toLowerCase();
    if (request.orderType == RequestOrderTypeV2.single &&
        (clientResponseStatus == 'accepted' ||
            clientResponseStatus == 'declined')) {
      return false;
    }

    final acceptedByClient = request.acceptedByClientEmail.trim().toLowerCase();

    final isGroupOrder = request.orderType == RequestOrderTypeV2.group;
    final acceptedGroupClients = request.acceptedGroupClientEmails
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();

    if (!isGroupOrder && acceptedByClient == viewerEmail) {
      return false;
    }

    if (isGroupOrder && acceptedGroupClients.contains(viewerEmail)) {
      return false;
    }

    final declinedByClient = request.declinedByClientEmails
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    if (declinedByClient.contains(viewerEmail)) return false;

    // The client who created/submitted the request should not see it
    // in their own incoming client-pool request list.
    final creatorEmail = request.clientEmail.trim().toLowerCase();
    if (creatorEmail.isNotEmpty && creatorEmail == viewerEmail) return false;

    return shouldShowScenario41ToDirectClient(
      openToClientPool: request.openToClientPool,
      orderType: request.orderType,
      selectedClientEmail: request.selectedClientEmail,
      selectedGroupClientEmails: request.selectedGroupClientEmails,
      viewerEmail: viewerEmail,
    );
  }

  Future<bool> _requestRequiresNfc(ClientRequestV2 request) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection(request.sourceCollection)
          .doc(request.id);
      final rootSnap = await docRef.get();
      final root = rootSnap.data() ?? const <String, dynamic>{};
      final detailsSnap = await docRef
          .collection('details')
          .doc('payload')
          .get();
      final details = detailsSnap.data() ?? const <String, dynamic>{};
      return _requestRequiresNfcFromMaps(root, details);
    } catch (_) {
      return false;
    }
  }

  bool _requestRequiresNfcFromMaps(
    Map<String, dynamic> root,
    Map<String, dynamic> details,
  ) {
    bool truthy(Object? value) {
      if (value == null) return false;
      if (value is bool) return value;
      if (value is num) return value != 0;
      final text = value.toString().trim().toLowerCase();
      return text == 'true' || text == '1' || text == 'yes' || text == 'y';
    }

    Map<String, dynamic> asMap(Object? value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        return value.map((key, val) => MapEntry(key.toString(), val));
      }
      return const <String, dynamic>{};
    }

    final payload = asMap(details['payload']).isNotEmpty
        ? asMap(details['payload'])
        : details;
    final requestDetails = asMap(payload['requestDetails']).isNotEmpty
        ? asMap(payload['requestDetails'])
        : asMap(details['requestDetails']);
    final order = asMap(payload['order']).isNotEmpty
        ? asMap(payload['order'])
        : asMap(details['order']);
    final nfc = asMap(payload['nfc']).isNotEmpty
        ? asMap(payload['nfc'])
        : (asMap(details['nfc']).isNotEmpty
              ? asMap(details['nfc'])
              : asMap(root['nfc']));

    final candidates = <Object?>[
      root['requiresNfc'],
      root['requiresNFC'],
      root['nfcRequired'],
      root['isNfcRequired'],
      root['hasNfc'],
      root['hasNFC'],
      root['nfcEnabled'],
      details['requiresNfc'],
      details['requiresNFC'],
      details['nfcRequired'],
      details['isNfcRequired'],
      details['hasNfc'],
      details['hasNFC'],
      payload['requiresNfc'],
      payload['requiresNFC'],
      payload['nfcRequired'],
      payload['isNfcRequired'],
      payload['hasNfc'],
      payload['hasNFC'],
      requestDetails['requiresNfc'],
      requestDetails['requiresNFC'],
      requestDetails['nfcRequired'],
      requestDetails['isNfcRequired'],
      requestDetails['hasNfc'],
      requestDetails['hasNFC'],
      order['requiresNfc'],
      order['requiresNFC'],
      order['nfcRequired'],
      order['isNfcRequired'],
      order['hasNfc'],
      order['hasNFC'],
      nfc['required'],
      nfc['enabled'],
      nfc['requiresNfc'],
      nfc['hasNfc'],
    ];
    return candidates.any(truthy);
  }

  Widget _nfcRequiredBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.balletSlippers.withValues(alpha: 0.92),
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.nfc_rounded, size: 14, color: AppColors.blackCat),
          SizedBox(width: 4),
          Text(
            'NFC',
            style: TextStyle(
              color: AppColors.blackCat,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              fontFamily: 'Arial',
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(ClientRequestV2 request) {
    return 'Pending';
  }

  String _needByLabel(DateTime date) {
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
    return '${months[(date.month - 1).clamp(0, 11)]} ${date.day}, ${date.year}';
  }

  String _submittedLabel(DateTime date) {
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
    return '${months[(date.month - 1).clamp(0, 11)]} ${date.day}, ${date.year}';
  }

  String _acceptByLabel(DateTime date) {
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
    return '${months[(date.month - 1).clamp(0, 11)]} ${date.day}, ${date.year}';
  }

  Future<void> _openDetails(ClientRequestV2 request) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return ClientRequestDetailsPage(
          request: request,
          onDecline: () async {
            await _respondToBrandRequest(request: request, accept: false);

            if (mounted) {
              setState(() {
                _hiddenRequestIds.add(request.id);
                _items = _items.where((item) => item.id != request.id).toList();
              });
            }

            await _reload();

            if (sheetContext.mounted) Navigator.of(sheetContext).pop();
          },
          onAccept: () async {
            await _respondToBrandRequest(request: request, accept: true);

            if (mounted) {
              setState(() {
                _hiddenRequestIds.add(request.id);
                _items = _items.where((item) => item.id != request.id).toList();
              });
            }

            await _reload();

            if (sheetContext.mounted) Navigator.of(sheetContext).pop();
          },
        );
      },
    );
  }

  Future<void> _respondToBrandRequest({
    required ClientRequestV2 request,
    required bool accept,
  }) async {
    final clientEmail = (FirebaseAuth.instance.currentUser?.email ?? '')
        .trim()
        .toLowerCase();
    if (clientEmail.isEmpty) {
      throw Exception('Missing signed-in client email.');
    }

    final selectedClientEmail = request.selectedClientEmail
        .trim()
        .toLowerCase();
    final selectedGroupClientEmails = request.selectedGroupClientEmails
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();

    if (!request.openToClientPool &&
        (request.orderType == RequestOrderTypeV2.group
            ? !selectedGroupClientEmails.contains(clientEmail)
            : (selectedClientEmail.isNotEmpty &&
                  selectedClientEmail != clientEmail))) {
      throw Exception('Only the designated client can respond.');
    }

    final isGroupOrder = request.orderType == RequestOrderTypeV2.group;

    Set<String> normList(Object? raw) {
      if (raw is! List) return <String>{};
      return raw
          .whereType<String>()
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toSet();
    }

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
    final brandRecipientEmails =
        await NotificationsService.resolveBrandRecipientEmails(
          rootData: rootData,
          detailsData: detailsData,
          orderData: orderData,
          excludeEmails: <String>[clientEmail],
        );
    DateTime? requestAcceptByDate(Object? value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    final brandRequestAcceptBy =
        requestAcceptByDate(rootData['requestAcceptBy']) ??
        requestAcceptByDate(detailsData['requestAcceptBy']) ??
        requestAcceptByDate(orderData['requestAcceptBy']) ??
        DateTime(
          request.neededBy.year,
          request.neededBy.month,
          request.neededBy.day,
        ).subtract(const Duration(days: 5));
    final brandRequestTimedOut =
        request.sourceCollection == 'Company_Custom_Requests' &&
        DateTime.now().isAfter(
          DateTime(
            brandRequestAcceptBy.year,
            brandRequestAcceptBy.month,
            brandRequestAcceptBy.day,
          ).add(const Duration(days: 1)),
        ) &&
        request.acceptedByClientEmail.trim().isEmpty &&
        request.declinedByClientEmails.isEmpty;

    if (brandRequestTimedOut) {
      final acceptByLabel = _firstNonEmpty(<Object?>[
        rootData['requestAcceptByDisplay'],
        detailsData['requestAcceptByDisplay'],
        orderData['requestAcceptByDisplay'],
      ], fallback: _monthDayYear(brandRequestAcceptBy));
      final cancellationReason =
          'Request was not accepted/rejected by $acceptByLabel';
      await _persistStatusUpdate(
        request: request,
        status: 'cancelled',
        summaryExtra: <String, dynamic>{
          'cancelReason': cancellationReason,
          'cancelledAt': FieldValue.serverTimestamp(),
        },
        detailsExtra: <String, dynamic>{
          'cancelReason': cancellationReason,
          'cancelledAt': FieldValue.serverTimestamp(),
        },
      );
      return;
    }

    final selected = request.selectedGroupClientEmails
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    var accepted = <String>{
      ...request.acceptedGroupClientEmails
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty),
      ...normList(rootData['acceptedGroupClientEmails']),
      ...normList(detailsData['acceptedGroupClientEmails']),
    };
    var declined = <String>{
      ...request.declinedByClientEmails
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty),
      ...normList(rootData['declinedByClientEmails']),
      ...normList(detailsData['declinedByClientEmails']),
    };

    if (!accept) {
      if (isGroupOrder && !request.openToClientPool) {
        accepted.remove(clientEmail);
        declined.add(clientEmail);
        final responded = <String>{...accepted, ...declined};
        final allResponded =
            selected.isNotEmpty && selected.every(responded.contains);
        final artistStatus = allResponded ? 'in_review' : 'pending';
        final overallStatus = allResponded
            ? (accepted.isNotEmpty ? 'accepted' : 'declined')
            : 'pending';

        await _persistStatusUpdate(
          request: request,
          status: overallStatus,
          summaryExtra: <String, dynamic>{
            'acceptedByClientEmail': '',
            if (!isGroupOrder) 'clientResponseStatus': 'declined',
            'acceptedGroupClientEmails': accepted.toList(growable: false),
            'declinedByClientEmails': declined.toList(growable: false),
            'groupClientsAllResponded': allResponded,
            'brandStatus': 'pending',
            'clientStatus': overallStatus,
            'artistStatus': artistStatus,
            'directArtistStatus': artistStatus,
          },
          detailsExtra: <String, dynamic>{
            'acceptedGroupClientEmails': accepted.toList(growable: false),
            if (!isGroupOrder) 'clientResponseStatus': 'declined',
            'declinedByClientEmails': declined.toList(growable: false),
            'groupClientsAllResponded': allResponded,
            'acceptance': const <String, dynamic>{'acceptedByClientEmail': ''},
            'roleStatuses': <String, dynamic>{
              'brand': 'pending',
              'client': overallStatus,
              'artist': artistStatus,
            },
            'routing': <String, dynamic>{'directArtistStatus': artistStatus},
          },
        );
        return;
      }

      if (request.openToClientPool) {
        await _persistStatusUpdate(
          request: request,
          status: 'in_review',
          summaryExtra: <String, dynamic>{
            'acceptedByClientEmail': '',
            if (!isGroupOrder) 'clientResponseStatus': 'declined',
            'declinedByClientEmails': FieldValue.arrayUnion(<String>[
              clientEmail,
            ]),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          detailsExtra: <String, dynamic>{
            'declinedByClientEmails': FieldValue.arrayUnion(<String>[
              clientEmail,
            ]),
            if (!isGroupOrder) 'clientResponseStatus': 'declined',
            'acceptance': const <String, dynamic>{'acceptedByClientEmail': ''},
            'lastClientDeclinedAt': FieldValue.serverTimestamp(),
          },
        );
      } else {
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
            'acceptance': const <String, dynamic>{'acceptedByClientEmail': ''},
            'roleStatuses': const <String, dynamic>{
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
      }
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
    accepted = <String>{...accepted, clientEmail};
    declined = <String>{...declined}..remove(clientEmail);
    final responded = <String>{...accepted, ...declined};
    final allResponded =
        !isGroupOrder ||
        (selected.isNotEmpty && selected.every(responded.contains));
    final allAccepted =
        !isGroupOrder ||
        (selected.isNotEmpty && selected.every(accepted.contains));
    final artistStatus = allResponded ? 'in_review' : 'pending';
    final overallStatus = allResponded
        ? (accepted.isNotEmpty ? 'accepted' : 'declined')
        : 'pending';
    List<dynamic>? updatedGroupClients;
    if (isGroupOrder) {
      final groupOrderMap =
          (detailsData['groupOrder'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final rawClients =
          (groupOrderMap['clients'] as List<dynamic>?) ?? const <dynamic>[];
      updatedGroupClients = rawClients
          .map((raw) {
            if (raw is! Map) return raw;
            final item = Map<String, dynamic>.from(raw);
            final itemEmail = (item['clientEmail'] ?? '')
                .toString()
                .trim()
                .toLowerCase();
            if (itemEmail != clientEmail) return item;
            item['responseStatus'] = 'accepted';
            item['acceptedAt'] = Timestamp.now();
            item['clientName'] = clientName.isNotEmpty
                ? clientName
                : item['clientName'];
            item['savedNails'] = <String, dynamic>{
              if (nailShape.isNotEmpty) 'shape': nailShape,
              if (nailLength.isNotEmpty) 'length': nailLength,
              'dimensions': nailDimensions,
            };
            return item;
          })
          .toList(growable: false);
    }

    await _persistStatusUpdate(
      request: request,
      status: 'pending',
      summaryExtra: <String, dynamic>{
        'acceptedByClientEmail': clientEmail,
        if (!isGroupOrder) 'clientResponseStatus': 'accepted',
        if (!isGroupOrder) 'openToClientPool': false,
        if (!isGroupOrder) 'clientPoolStatus': 'accepted',
        'acceptedByClientAt': FieldValue.serverTimestamp(),
        'acceptedGroupClientEmails': accepted.toList(growable: false),
        'declinedByClientEmails': declined.toList(growable: false),
        'groupClientsAllResponded': allResponded,
        'brandStatus': 'pending',
        'clientStatus': 'pending',
        'artistStatus': artistStatus,
        'directArtistStatus': artistStatus,
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
          if (!isGroupOrder) 'clientResponseStatus': 'accepted',
        },
        if (!isGroupOrder) 'openToClientPool': false,
        if (!isGroupOrder) 'clientPoolStatus': 'accepted',
        if (!isGroupOrder) 'clientResponseStatus': 'accepted',
        'acceptedGroupClientEmails': accepted.toList(growable: false),
        'declinedByClientEmails': declined.toList(growable: false),
        'groupClientsAllResponded': allResponded,
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
          'artist': artistStatus,
        },
        'routing': <String, dynamic>{'directArtistStatus': artistStatus},
        if (updatedGroupClients != null)
          'groupOrder': <String, dynamic>{'clients': updatedGroupClients},
      },
    );
    final campaignName = _firstNonEmpty(<Object?>[
      rootData['campaignName'],
      rootData['title'],
      request.title,
    ], fallback: 'Campaign');
    final brandName = _firstNonEmpty(<Object?>[
      rootData['companyName'],
      rootData['brandName'],
      request.clientName,
    ], fallback: 'Brand');
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

    if (allResponded && allAccepted) {
      final summaryNames = <String>[];
      if (isGroupOrder) {
        final groupDetails =
            (detailsData['groupOrder'] as Map<String, dynamic>?) ??
            const <String, dynamic>{};
        final rawClients =
            (groupDetails['clients'] as List<dynamic>?) ?? const <dynamic>[];
        for (final raw in rawClients) {
          if (raw is! Map) continue;
          final email = (raw['clientEmail'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          final name = (raw['clientName'] ?? '').toString().trim();
          if (email.isEmpty || name.isEmpty) continue;
          if (accepted.contains(email) && !summaryNames.contains(name)) {
            summaryNames.add(name);
          }
        }
      }
      final groupClientSummary = summaryNames.isNotEmpty
          ? summaryNames.join(', ')
          : acceptedClientName;
      await NotificationsService.notifyArtistsForBrandClientAcceptedRequest(
        clientName: groupClientSummary,
        brandName: brandName,
        campaignName: campaignName,
        isDirectRequest: request.isDirectRequest,
        selectedArtistEmail: request.selectedArtistEmail.trim().toLowerCase(),
        selectedArtistName: request.selectedArtist.trim(),
        orderId: request.id,
        sourceCollection: request.sourceCollection,
        orderNumber: request.orderNumber,
        allowNonLicensed: request.allowNonLicensed,
      );
    }
  }

  String _monthDayYear(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$month/$day/${date.year}';
  }

  Future<void> _persistStatusUpdate({
    required ClientRequestV2 request,
    required String status,
    Map<String, dynamic> summaryExtra = const <String, dynamic>{},
    Map<String, dynamic> detailsExtra = const <String, dynamic>{},
  }) async {
    final requestRef = FirebaseFirestore.instance
        .collection(request.sourceCollection)
        .doc(request.id);

    final batch = FirebaseFirestore.instance.batch();
    batch.set(requestRef, <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      ...summaryExtra,
    }, SetOptions(merge: true));
    batch.set(
      requestRef.collection('details').doc('payload'),
      <String, dynamic>{'status': status, ...detailsExtra},
      SetOptions(merge: true),
    );
    await batch.commit();
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
      final profileNail =
          (profile['nailPreferences'] as Map<String, dynamic>?) ?? const {};
      final dimensions =
          (nail['dimensions'] as Map<String, dynamic>?) ?? const {};
      final profileDimensions =
          (profileNail['dimensions'] as Map<String, dynamic>?) ?? const {};

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
        'nailShape': first(nail, const ['shape']).isNotEmpty
            ? first(nail, const ['shape'])
            : first(profileNail, const ['shape']),
        'nailLength': first(nail, const ['length']).isNotEmpty
            ? first(nail, const ['length'])
            : first(profileNail, const ['length']),
        'nailDimensions': <String, dynamic>{
          'lThumb': dimensions['lThumb'] ?? profileDimensions['lThumb'],
          'lIndex': dimensions['lIndex'] ?? profileDimensions['lIndex'],
          'lMiddle': dimensions['lMiddle'] ?? profileDimensions['lMiddle'],
          'lRing': dimensions['lRing'] ?? profileDimensions['lRing'],
          'lPinky': dimensions['lPinky'] ?? profileDimensions['lPinky'],
          'rThumb': dimensions['rThumb'] ?? profileDimensions['rThumb'],
          'rIndex': dimensions['rIndex'] ?? profileDimensions['rIndex'],
          'rMiddle': dimensions['rMiddle'] ?? profileDimensions['rMiddle'],
          'rRing': dimensions['rRing'] ?? profileDimensions['rRing'],
          'rPinky': dimensions['rPinky'] ?? profileDimensions['rPinky'],
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

  String _firstNonEmpty(List<Object?> values, {String fallback = ''}) {
    for (final value in values) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_loading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_items.isEmpty) {
      content = Center(
        child: Text(
          'No brand requests available',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.blackCat.withValues(alpha: 0.6),
          ),
        ),
      );
    } else {
      final directRequests = _items
          .where(
            (r) =>
                !r.openToClientPool &&
                (r.selectedClientEmail.trim().isNotEmpty ||
                    r.selectedGroupClientEmails.isNotEmpty),
          )
          .toList(growable: false);
      final openRequests = _items
          .where((r) => r.openToClientPool)
          .toList(growable: false);

      Widget requestCard(ClientRequestV2 request) {
        final card = Semantics(
          button: true,
          label: 'Open request details for ${request.clientName}',
          child: InkWell(
            borderRadius: BorderRadius.zero,
            onTap: () => _openDetails(request),
            child: CompanyClientRequestCard(
              request: request,
              scale: 1.0,
              displayStatus: _statusLabel(request),
              needByLabel: _needByLabel(request.neededBy),
              submittedLabel: _submittedLabel(
                request.submittedAt ?? request.neededBy,
              ),
              acceptByLabel:
                  request.sourceCollection == 'Company_Custom_Requests'
                      ? _acceptByLabel(
                          DateTime(
                            request.neededBy.year,
                            request.neededBy.month,
                            request.neededBy.day,
                          ).subtract(const Duration(days: 5)),
                        )
                      : '',
              avatar: _avatarWidget(request),
              previewImage: _previewWidget(request),
              showDirectChip:
                  request.isDirectRequest &&
                  !request.openToClientPool &&
                  request.orderType == RequestOrderTypeV2.single,
              onTap: () => _openDetails(request),
            ),
          ),
        );

        return FutureBuilder<bool>(
          future: _requestRequiresNfc(request),
          builder: (context, snap) {
            final requiresNfc = snap.data ?? false;
            if (!requiresNfc) return card;
            return Stack(
              children: [
                card,
                Positioned(top: 10, right: 10, child: _nfcRequiredBadge()),
              ],
            );
          },
        );
      }

      Widget sectionTitle(String title) {
        return Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.blackCat,
          ),
        );
      }

      Widget emptyText(String text) {
        return Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: AppColors.blackCat.withValues(alpha: 0.6),
          ),
        );
      }

      content = ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          sectionTitle('Direct Request'),
          const SizedBox(height: 8),
          if (directRequests.isEmpty)
            emptyText('No direct requests available.')
          else ...[
            for (var i = 0; i < directRequests.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              requestCard(directRequests[i]),
            ],
          ],
          const SizedBox(height: 18),
          sectionTitle('Open Request'),
          const SizedBox(height: 8),
          if (openRequests.isEmpty)
            emptyText('No open requests available.')
          else ...[
            for (var i = 0; i < openRequests.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              requestCard(openRequests[i]),
            ],
          ],
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: AppBar(
        backgroundColor: AppColors.alabaster,
        surfaceTintColor: AppColors.alabaster,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        toolbarHeight: 85,
        leadingWidth: 58,
        leading: NotificationBellButton(
          onTap: () {
            if (widget.onOpenNotifications != null) {
              widget.onOpenNotifications!.call();
            } else {
              NotificationsPage.showAsModal(context);
            }
          },
          iconSize: 24,
        ),
        title: Image.asset(
          'assets/images/jnt_logo_black.png',
          height: 52,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _AvatarMenu(
              onSelected: _onAvatarMenuSelected,
              displayName: _headerDisplayName.isNotEmpty
                  ? _headerDisplayName
                  : (FirebaseAuth.instance.currentUser?.displayName ?? '')
                        .trim(),
              avatarUrl: _headerAvatarUrl,
            ),
          ),
        ],
      ),
      body: content,
    );
  }

  Future<void> _onAvatarMenuSelected(String choice) async {
    if (choice == 'profile') {
      widget.onOpenProfile?.call();
      return;
    }
    if (choice == 'logout') {
      if (widget.onLogout != null) {
        widget.onLogout!.call();
        return;
      }
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  Widget _avatarWidget(ClientRequestV2 request) {
    final path = request.clientProfileImage.trim();
    if (path.isEmpty) {
      return const Icon(Icons.business, color: AppColors.blackCat);
    }
    return _imageFromPath(path, fallback: const Icon(Icons.business));
  }

  Future<String> _loadPreviewImagePath(ClientRequestV2 request) async {
    String pickBest(Iterable<String> values) {
      final list = values
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
      for (final item in list) {
        final v = item.trim().toLowerCase();
        if (v.startsWith('http://') ||
            v.startsWith('https://') ||
            v.startsWith('gs://') ||
            v.startsWith('assets/') ||
            v.startsWith('data:') ||
            v.startsWith('blob:') ||
            v.startsWith('content://') ||
            v.contains('/')) {
          return item.trim();
        }
      }
      return list.isEmpty ? '' : list.first.trim();
    }

    final fromModel = pickBest(<String>[
      ...request.clientImages.map((e) => e.trim()),
      request.previewImageAsset.trim(),
    ]);
    if (fromModel.isNotEmpty) return fromModel;

    Map<String, dynamic> asMap(dynamic value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        return value.map((key, value) => MapEntry(key.toString(), value));
      }
      return const <String, dynamic>{};
    }

    List<String> collectPhotos(List<Object?> sources) {
      final out = <String>{};
      void add(dynamic value) {
        if (value == null) return;
        if (value is String) {
          final v = value.trim();
          if (v.isNotEmpty) out.add(v);
          return;
        }
        if (value is List) {
          for (final item in value) {
            add(item);
          }
          return;
        }
        if (value is Map) {
          final map = Map<String, dynamic>.from(value);
          for (final key in const <String>[
            'imageUrl',
            'downloadUrl',
            'downloadURL',
            'url',
            'photoUrl',
            'image',
            'photo',
            'path',
            'storagePath',
            'fullPath',
            'ref',
            'src',
            'uri',
          ]) {
            add(map[key]);
          }
          map.forEach((key, value) {
            final lower = key.toString().toLowerCase();
            if (lower.contains('photo') ||
                lower.contains('image') ||
                lower.contains('inspiration') ||
                lower.contains('preview') ||
                lower.endsWith('url') ||
                lower.endsWith('path')) {
              add(value);
            }
          });
        }
      }

      for (final source in sources) {
        add(source);
      }
      return out.toList(growable: false);
    }

    try {
      final docRef = FirebaseFirestore.instance
          .collection(request.sourceCollection)
          .doc(request.id);
      final rootSnap = await docRef.get();
      final root = rootSnap.data() ?? const <String, dynamic>{};
      final detailsSnap = await docRef
          .collection('details')
          .doc('payload')
          .get();
      final details = detailsSnap.data() ?? const <String, dynamic>{};
      final payload = asMap(details['payload']).isNotEmpty
          ? asMap(details['payload'])
          : details;
      final requestDetails = asMap(payload['requestDetails']).isNotEmpty
          ? asMap(payload['requestDetails'])
          : asMap(details['requestDetails']);
      final recovered = pickBest(
        collectPhotos(<Object?>[
          root['previewImage'],
          root['previewImageAsset'],
          root['brandInspirationPhotos'],
          root['inspirationPhotos'],
          root['inspirationPhotoUrls'],
          root['inspirationPhotoRefs'],
          root['photos'],
          root['clientImages'],
          payload['previewImage'],
          payload['previewImageAsset'],
          payload['brandInspirationPhotos'],
          payload['inspirationPhotos'],
          payload['inspirationPhotoUrls'],
          payload['inspirationPhotoRefs'],
          payload['photos'],
          payload['clientImages'],
          requestDetails['previewImage'],
          requestDetails['previewImageAsset'],
          requestDetails['brandInspirationPhotos'],
          requestDetails['inspirationPhotos'],
          requestDetails['inspirationPhotoUrls'],
          requestDetails['inspirationPhotoRefs'],
          requestDetails['photos'],
          requestDetails['clientImages'],
        ]),
      );
      if (recovered.isNotEmpty) return recovered;
    } catch (_) {}

    return '';
  }

  Widget _previewWidget(ClientRequestV2 request) {
    const fallback = Icon(Icons.image_outlined, color: AppColors.blackCat);
    return FutureBuilder<String>(
      future: _loadPreviewImagePath(request),
      builder: (_, snap) {
        final first = (snap.data ?? '').trim();
        if (first.isEmpty) return fallback;
        return _imageFromPath(first, fallback: fallback);
      },
    );
  }

  Widget _imageFromPath(String raw, {required Widget fallback}) {
    var path = raw.trim();
    for (var i = 0; i < 3; i++) {
      final decoded = Uri.decodeFull(path);
      if (decoded == path) break;
      path = decoded.trim();
    }
    if (path.isEmpty) return fallback;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    if (path.startsWith('data:image/')) {
      try {
        final comma = path.indexOf(',');
        if (comma > 0) {
          final bytes = base64Decode(path.substring(comma + 1).trim());
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          );
        }
      } catch (_) {}
      return fallback;
    }
    if (path.startsWith('gs://')) {
      return FutureBuilder<String>(
        future: StorageUrlResolver.resolve(path).then((v) => v ?? ''),
        builder: (_, snap) {
          final url = snap.data?.trim() ?? '';
          if (url.isEmpty) return fallback;
          return Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          );
        },
      );
    }
    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    if (!path.startsWith('http') &&
        !path.startsWith('assets/') &&
        !path.startsWith('gs://') &&
        !path.startsWith('data:') &&
        !path.startsWith('blob:') &&
        !path.startsWith('content://') &&
        (path.contains('/') || path.contains('\\'))) {
      return FutureBuilder<String>(
        future: StorageUrlResolver.resolve(path).then((v) => v ?? ''),
        builder: (_, snap) {
          final url = snap.data?.trim() ?? '';
          if (url.isEmpty) return fallback;
          return Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          );
        },
      );
    }
    final isFile = path.startsWith('/') || path.contains(':\\');
    if (isFile) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    return fallback;
  }
}

class _AvatarMenu extends StatelessWidget {
  const _AvatarMenu({
    required this.onSelected,
    this.avatarUrl = '',
    this.displayName = '',
  });

  final ValueChanged<String> onSelected;
  final String avatarUrl;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '',
      offset: const Offset(0, 55),
      elevation: 8,
      color: AppColors.snow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      onSelected: onSelected,
      itemBuilder: (context) => const [
        PopupMenuItem<String>(
          value: 'profile',
          child: Row(
            children: [
              Icon(Icons.person_outline, size: 22),
              SizedBox(width: 14),
              Text(
                'Profile',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
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
