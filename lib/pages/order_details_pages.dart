import 'dart:io';

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/supabase_firebase_compat.dart';
import '../theme/app_colors.dart';
import '../services/notifications_service.dart';
import 'request_chat_page.dart';
import 'track_order_page.dart';

final Set<String> _designReminderCheckInFlight = <String>{};

/// If you already have this model elsewhere, you can delete this class
/// and import the correct model file instead.
/// But to keep this file self-contained + compile, we accept `dynamic order`.
/// (We only read simple fields with fallback.)
class _OrderSafe {
  final String sourceCollection;
  final String id;
  final String orderNumber;
  final String? brandName;
  final String? campaignName;
  final String title;
  final String subtitle;
  final bool hasAssignedArtist;
  final String orderType;
  final List<_OrderGroupClient> groupClients;
  final DateTime? createdAt;
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
  final String imageAsset;
  final int? artistAcceptedAmount;
  final String paymentStatus;
  final String paymentLink;
  final String selectedArtistName;
  final DateTime? paidAt;
  final List<String> artistCompletedPhotos;
  final String completionReviewStatus;
  final String completionDeclineReason;
  final String completionDeclineDescription;
  final DateTime? completionDeclinedAt;
  final String designApprovalStatus;
  final DateTime? designApprovedAt;
  final DateTime? designSubmittedAt;
  final DateTime? designApprovalDueAt;
  final DateTime? designReminderSentAt;
  final List<String> designPreviewPhotos;
  final String clientEmail;
  final String acceptedByArtistEmail;
  final List<String> declinedByClientEmails;
  final List<String> declinedByArtistEmails;
  final String artistName;
  final String artistProfileImage;
  final double? clientRating;
  final String clientReviewText;
  final DateTime? clientReviewSubmittedAt;
  final String shippedByCourier;
  final String trackingNumber;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;

  const _OrderSafe({
    required this.sourceCollection,
    required this.id,
    required this.orderNumber,
    required this.brandName,
    required this.campaignName,
    required this.title,
    required this.subtitle,
    required this.hasAssignedArtist,
    required this.orderType,
    required this.groupClients,
    required this.createdAt,
    required this.clientDescription,
    required this.cancelReason,
    required this.inspirationPhotos,
    required this.needByDisplay,
    required this.nailShape,
    required this.nailLength,
    required this.budgetMin,
    required this.budgetMax,
    required this.leftHandDimensions,
    required this.rightHandDimensions,
    required this.imageAsset,
    required this.artistAcceptedAmount,
    required this.paymentStatus,
    required this.paymentLink,
    required this.selectedArtistName,
    required this.paidAt,
    required this.artistCompletedPhotos,
    required this.completionReviewStatus,
    required this.completionDeclineReason,
    required this.completionDeclineDescription,
    required this.completionDeclinedAt,
    required this.designApprovalStatus,
    required this.designApprovedAt,
    required this.designSubmittedAt,
    required this.designApprovalDueAt,
    required this.designReminderSentAt,
    required this.designPreviewPhotos,
    required this.clientEmail,
    required this.acceptedByArtistEmail,
    required this.declinedByClientEmails,
    required this.declinedByArtistEmails,
    required this.artistName,
    required this.artistProfileImage,
    required this.clientRating,
    required this.clientReviewText,
    required this.clientReviewSubmittedAt,
    required this.shippedByCourier,
    required this.trackingNumber,
    required this.shippedAt,
    required this.deliveredAt,
  });

  static _OrderSafe from(dynamic o) {
    String s(dynamic v, String fb) =>
        (v is String && v.trim().isNotEmpty) ? v : fb;
    double? d(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse((v ?? '').toString().trim());
    }

    DateTime? dt(dynamic v) {
      if (v is DateTime) return v;
      if (v is Timestamp) return v.toDate();
      return null;
    }

    final detailMap = o is Map ? (o['details'] as Map?) : null;
    final payloadMap = detailMap is Map ? (detailMap['payload'] as Map?) : null;
    final requestDetailsMap = payloadMap is Map
        ? (payloadMap['requestDetails'] as Map?)
        : null;
    final orderMap = payloadMap is Map ? (payloadMap['order'] as Map?) : null;
    final designMap = payloadMap is Map
        ? (payloadMap['designApproval'] as Map?)
        : null;
    List<String> collectPhotoRefs(List<dynamic> values) {
      final out = <String>[];
      final seen = <String>{};
      void addValue(dynamic value) {
        if (value == null) return;
        if (value is String) {
          final s = value.trim();
          if (s.isNotEmpty && seen.add(s)) out.add(s);
          return;
        }
        if (value is Iterable) {
          for (final item in value) {
            addValue(item);
          }
          return;
        }
        if (value is Map) {
          final map = Map<String, dynamic>.from(value);
          const keys = <String>[
            'url',
            'downloadUrl',
            'downloadURL',
            'photoUrl',
            'imageUrl',
            'image',
            'path',
            'storagePath',
            'fullPath',
            'ref',
            'photo',
            'src',
            'uri',
          ];
          for (final key in keys) {
            if (map.containsKey(key)) addValue(map[key]);
          }
          map.forEach((k, v) {
            final lower = k.toString().toLowerCase();
            if (lower.contains('photo') ||
                lower.contains('image') ||
                lower.contains('inspiration') ||
                lower.contains('preview') ||
                lower.endsWith('url') ||
                lower.endsWith('path')) {
              addValue(v);
            }
          });
        }
      }

      for (final value in values) {
        addValue(value);
      }
      return out;
    }

    List<String> listOrEmpty(dynamic v) {
      if (v is List) return List<String>.from(v.whereType<String>());
      return const <String>[];
    }

    List<String> normalizedEmailList(dynamic v) => listOrEmpty(v)
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(growable: false);

    return _OrderSafe(
      sourceCollection: s(o?.sourceCollection, 'Client_Custom_Requests'),
      id: s(o?.id, 'order'),
      orderNumber: s(o?.orderNumber, ''),
      brandName: s(o?.brandName, ''),
      campaignName: s(o?.campaignName, ''),
      title: s(o?.title, 'Artist'),
      subtitle: s(o?.subtitle, ''),
      hasAssignedArtist: o?.hasAssignedArtist is bool
          ? (o.hasAssignedArtist as bool)
          : true,
      orderType: s(o?.orderType, 'single'),
      groupClients: _groupClientList(o?.groupClients),
      createdAt: o?.createdAt is DateTime ? o.createdAt as DateTime : null,
      clientDescription: s(o?.clientDescription, ''),
      cancelReason: s(o?.cancelReason, ''),
      inspirationPhotos: collectPhotoRefs([
        o?.inspirationPhotos,
        payloadMap?['brandInspirationPhotos'],
        payloadMap?['inspirationPhotos'],
        payloadMap?['clientImages'],
        payloadMap?['photos'],
        payloadMap?['inspirationPhoto'],
        payloadMap?['inspirationPhotoUrl'],
        payloadMap?['previewImage'],
        payloadMap?['previewImageAsset'],
        requestDetailsMap?['brandInspirationPhotos'],
        requestDetailsMap?['inspirationPhotos'],
        requestDetailsMap?['clientImages'],
        requestDetailsMap?['photos'],
        requestDetailsMap?['inspirationPhoto'],
        requestDetailsMap?['inspirationPhotoUrl'],
        requestDetailsMap?['inspirationPhotoUrls'],
        requestDetailsMap?['inspirationPhotoRefs'],
        requestDetailsMap?['previewImage'],
        requestDetailsMap?['previewImageAsset'],
        orderMap?['brandInspirationPhotos'],
        orderMap?['inspirationPhotos'],
        orderMap?['clientImages'],
        orderMap?['photos'],
        orderMap?['inspirationPhoto'],
        orderMap?['inspirationPhotoUrl'],
        orderMap?['previewImage'],
        orderMap?['previewImageAsset'],
      ]),
      needByDisplay: s(o?.needByDisplay, ''),
      nailShape: s(o?.nailShape, ''),
      nailLength: s(o?.nailLength, ''),
      budgetMin: o?.budgetMin is int ? o.budgetMin as int : null,
      budgetMax: o?.budgetMax is int ? o.budgetMax as int : null,
      leftHandDimensions: _dimsMap(o?.leftHandDimensions),
      rightHandDimensions: _dimsMap(o?.rightHandDimensions),
      imageAsset: s(o?.imageAsset, 'assets/images/order_thumb_1.png'),
      artistAcceptedAmount: o?.artistAcceptedAmount is int
          ? o.artistAcceptedAmount as int
          : null,
      paymentStatus: s(o?.paymentStatus, ''),
      paymentLink: s(o?.paymentLink, ''),
      selectedArtistName: s(
        o?.selectedArtistName ??
            o?.selectedArtist ??
            payloadMap?['selectedArtistName'] ??
            payloadMap?['selectedArtist'],
        '',
      ),
      paidAt: o?.paidAt is DateTime ? o.paidAt as DateTime : null,
      artistCompletedPhotos: o?.artistCompletedPhotos is List
          ? List<String>.from(
              (o.artistCompletedPhotos as List).whereType<String>(),
            )
          : const [],
      completionReviewStatus: s(o?.completionReviewStatus, ''),
      completionDeclineReason: s(o?.completionDeclineReason, ''),
      completionDeclineDescription: s(o?.completionDeclineDescription, ''),
      completionDeclinedAt: dt(o?.completionDeclinedAt),
      designApprovalStatus: s(
        o?.designApprovalStatus ?? o?.clientDesignApprovalStatus,
        '',
      ),
      designApprovedAt: dt(o?.designApprovedAt ?? o?.clientDesignApprovedAt),
      designSubmittedAt: dt(o?.designSubmittedAt ?? designMap?['submittedAt']),
      designApprovalDueAt: dt(o?.designApprovalDueAt ?? designMap?['dueAt']),
      designReminderSentAt: dt(
        o?.designReminderSentAt ?? designMap?['reminderSentAt'],
      ),
      designPreviewPhotos: listOrEmpty(
        o?.designPreviewPhotos ?? designMap?['previewPhotos'],
      ),
      clientEmail: s(o?.clientEmail, ''),
      acceptedByArtistEmail: s(o?.acceptedByArtistEmail, ''),
      declinedByClientEmails: normalizedEmailList(
        o?.declinedByClientEmails ??
            o?['declinedByClientEmails'] ??
            (payloadMap is Map ? payloadMap['declinedByClientEmails'] : null),
      ),
      declinedByArtistEmails: normalizedEmailList(
        o?.declinedByArtistEmails ??
            o?['declinedByArtistEmails'] ??
            (payloadMap is Map ? payloadMap['declinedByArtistEmails'] : null),
      ),
      artistName: s(o?.artistName, ''),
      artistProfileImage: s(o?.artistProfileImage, ''),
      clientRating: d(o?.rating),
      clientReviewText: s(o?.reviewText, ''),
      clientReviewSubmittedAt: dt(o?.reviewSubmittedAt),
      shippedByCourier: s(o?.shippedByCourier, ''),
      trackingNumber: s(o?.trackingNumber, ''),
      shippedAt: dt(o?.shippedAt),
      deliveredAt: dt(o?.deliveredAt),
    );
  }

  static Map<String, String> _dimsMap(dynamic value) {
    if (value is! Map) return const <String, String>{};
    String readAny(List<String> keys) {
      for (final key in keys) {
        final raw = value[key];
        final text = (raw ?? '').toString().trim();
        if (text.isNotEmpty) return text;
      }
      return '';
    }

    // Supports both legacy keys (thumb/index/...) and newer keys that may
    // be persisted as lThumb/rThumb when hand data is flattened.
    final thumb = readAny(const ['thumb', 'lThumb', 'rThumb']);
    final index = readAny(const ['index', 'lIndex', 'rIndex']);
    final middle = readAny(const ['middle', 'lMiddle', 'rMiddle']);
    final ring = readAny(const ['ring', 'lRing', 'rRing']);
    final pinky = readAny(const ['pinky', 'lPinky', 'rPinky']);

    return <String, String>{
      'thumb': thumb,
      'index': index,
      'middle': middle,
      'ring': ring,
      'pinky': pinky,
    };
  }

  static List<_OrderGroupClient> _groupClientList(dynamic value) {
    if (value is! List) return const <_OrderGroupClient>[];
    final items = <_OrderGroupClient>[];
    String s(dynamic v) => (v ?? '').toString().trim();

    for (final entry in value) {
      if (entry is _OrderGroupClient) {
        items.add(entry);
        continue;
      }
      if (entry is Map) {
        items.add(
          _OrderGroupClient(
            clientId: s(entry['clientId']),
            clientName: s(entry['clientName']),
            clientEmail: s(entry['clientEmail']),
            nailShape: s(entry['nailShape']),
            nailLength: s(entry['nailLength']),
            leftHandDimensions: _dimsMap(entry['leftHandDimensions']),
            rightHandDimensions: _dimsMap(entry['rightHandDimensions']),
          ),
        );
        continue;
      }
      items.add(
        _OrderGroupClient(
          clientId: s(entry?.clientId),
          clientName: s(entry?.clientName),
          clientEmail: s(entry?.clientEmail),
          nailShape: s(entry?.nailShape),
          nailLength: s(entry?.nailLength),
          leftHandDimensions: _dimsMap(entry?.leftHandDimensions),
          rightHandDimensions: _dimsMap(entry?.rightHandDimensions),
        ),
      );
    }
    return items;
  }
}

class _OrderGroupClient {
  const _OrderGroupClient({
    this.clientId = '',
    this.clientName = '',
    this.clientEmail = '',
    this.nailShape = '',
    this.nailLength = '',
    this.leftHandDimensions = const <String, String>{},
    this.rightHandDimensions = const <String, String>{},
  });

  final String clientId;
  final String clientName;
  final String clientEmail;
  final String nailShape;
  final String nailLength;
  final Map<String, String> leftHandDimensions;
  final Map<String, String> rightHandDimensions;
}

/// ------------------------
/// SHIPPED ORDER DETAILS (UI like your screenshot)
/// ------------------------
class ShippedOrderDetailsPage extends StatelessWidget {
  const ShippedOrderDetailsPage({
    super.key,
    required this.order,
    this.isBrandViewer = false,
  });
  final dynamic order;
  final bool isBrandViewer;

  @override
  Widget build(BuildContext context) {
    final o = _OrderSafe.from(order);

    return _BaseOrderDetails(
      title: 'Order Details',
      statusPillText: 'Shipped',
      statusPillColor: AppColors.balletSlippers,
      statusPillIcon: Icons.local_shipping_rounded,
      statusPillIconColor: AppColors.blackCat,
      order: o,
      isBrandViewer: isBrandViewer,
      showRightPanel: false,
      rightPanel: const SizedBox.shrink(),
    );
  }
}

/// ------------------------
/// IN PROGRESS DETAILS
/// ------------------------
class InProgressOrderDetailsPage extends StatelessWidget {
  const InProgressOrderDetailsPage({
    super.key,
    required this.order,
    this.isBrandViewer = false,
  });
  final dynamic order;
  final bool isBrandViewer;

  @override
  Widget build(BuildContext context) {
    final o = _OrderSafe.from(order);

    return _BaseOrderDetails(
      title: 'Order Details',
      statusPillText: 'In Progress',
      statusPillColor: AppColors.balletSlippers,
      statusPillIcon: Icons.timelapse_rounded,
      statusPillIconColor: const Color(0xFFD36B77),
      order: o,
      isBrandViewer: isBrandViewer,
      rightPanel: const _ProgressCard(
        steps: [
          _StepItem('Accepted', true),
          _StepItem('Designing', true),
          _StepItem('Packaging', false),
          _StepItem('Shipped', false),
        ],
      ),
    );
  }
}

/// ------------------------
/// IN REVIEW DETAILS
/// ------------------------
class InReviewOrderDetailsPage extends StatelessWidget {
  const InReviewOrderDetailsPage({
    super.key,
    required this.order,
    this.isBrandViewer = false,
  });
  final dynamic order;
  final bool isBrandViewer;

  @override
  Widget build(BuildContext context) {
    final o = _OrderSafe.from(order);

    return _BaseOrderDetails(
      title: 'Order Details',
      statusPillText: 'Pending',
      statusPillColor: AppColors.balletSlippers,
      statusPillIcon: Icons.hourglass_bottom_rounded,
      statusPillIconColor: Colors.black.withOpacity(0.65),
      order: o,
      isBrandViewer: isBrandViewer,
      rightPanel: const _InfoCard(
        title: 'Waiting for artist',
        lines: [
          'Artist is reviewing your request.',
          'You’ll get an update soon.',
        ],
      ),
    );
  }
}

/// ------------------------
/// NEW ORDER DETAILS
/// ------------------------
class NewOrderDetailsPage extends StatelessWidget {
  const NewOrderDetailsPage({
    super.key,
    required this.order,
    this.isBrandViewer = false,
  });
  final dynamic order;
  final bool isBrandViewer;

  @override
  Widget build(BuildContext context) {
    final o = _OrderSafe.from(order);

    return _BaseOrderDetails(
      title: 'Order Details',
      statusPillText: 'New',
      statusPillColor: AppColors.balletSlippers,
      statusPillIcon: Icons.fiber_new_rounded,
      statusPillIconColor: Colors.black.withOpacity(0.65),
      order: o,
      isBrandViewer: isBrandViewer,
      rightPanel: const SizedBox.shrink(),
    );
  }
}

/// ------------------------
/// Shared base layout
/// ------------------------
class _BaseOrderDetails extends StatelessWidget {
  const _BaseOrderDetails({
    required this.title,
    required this.statusPillText,
    required this.statusPillColor,
    required this.statusPillIcon,
    required this.statusPillIconColor,
    required this.order,
    this.isBrandViewer = false,
    required this.rightPanel,
    this.showRightPanel = true,
    this.onCancelledChat,
    this.onCancelledResubmit,
    this.onExpiredChat,
    this.onExpiredResubmit,
  });

  final String title;
  final String statusPillText;
  final Color statusPillColor;
  final IconData statusPillIcon;
  final Color statusPillIconColor;

  final _OrderSafe order;
  final bool isBrandViewer;
  final Widget rightPanel;
  final bool showRightPanel;
  final VoidCallback? onCancelledChat;
  final Future<void> Function()? onCancelledResubmit;
  final VoidCallback? onExpiredChat;
  final Future<void> Function()? onExpiredResubmit;

  static String _firstNonEmpty(List<Object?> values, {String fallback = ''}) {
    for (final value in values) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString().trim());
  }

  static Future<_AcceptedArtistMeta> _loadAcceptedArtistMeta(
    _OrderSafe order,
  ) async {
    final fallback = _AcceptedArtistMeta(
      name: order.artistName.trim(),
      profileImage: order.artistProfileImage.trim(),
    );
    final email = order.acceptedByArtistEmail.trim().toLowerCase();
    if (email.isEmpty) return fallback;

    final db = FirebaseFirestore.instance;
    for (final collection in const <String>['artist', 'client_artist']) {
      final snap = await db
          .collection(collection)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) continue;

      final data = snap.docs.first.data();
      final profile = (data['profile'] as Map<String, dynamic>?) ?? const {};
      final basic = (data['basic'] as Map<String, dynamic>?) ?? const {};
      final address = (data['address'] as Map<String, dynamic>?) ?? const {};
      final stats = (data['stats'] as Map<String, dynamic>?) ?? const {};

      final name = _firstNonEmpty([
        order.artistName,
        profile['displayName'],
        profile['name'],
        basic['displayName'],
        basic['name'],
        data['panel_displayName'],
        data['displayName'],
        data['name'],
      ]);
      final image = _firstNonEmpty([
        order.artistProfileImage,
        profile['profileImageUrl'],
        profile['avatarUrl'],
        profile['profileImagePath'],
        basic['profileImageUrl'],
        basic['avatarUrl'],
        data['panel_profileImageUrl'],
        data['profileImageUrl'],
        data['avatarUrl'],
      ]);
      final city = _firstNonEmpty([
        address['city'],
        profile['city'],
        data['panel_city'],
        data['city'],
      ]);
      final state = _firstNonEmpty([
        address['state'],
        profile['state'],
        data['panel_state'],
        data['state'],
      ]);
      final rating = _asDouble(stats['rating']) ?? _asDouble(data['rating']);

      return _AcceptedArtistMeta(
        name: name,
        profileImage: image,
        city: city,
        state: state,
        rating: rating,
      );
    }

    return fallback;
  }

  void _openRequestChat(BuildContext context) {
    final clientEmail = order.clientEmail.trim().toLowerCase();
    final artistEmail = order.acceptedByArtistEmail.trim().toLowerCase();
    if (clientEmail.isEmpty || artistEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Chat unavailable until both client and artist are assigned.',
          ),
        ),
      );
      return;
    }
    final currentName = (FirebaseAuth.instance.currentUser?.displayName ?? '')
        .trim();
    final fallbackCurrentName = (FirebaseAuth.instance.currentUser?.email ?? '')
        .trim();
    final clientName = currentName.isNotEmpty
        ? currentName
        : (fallbackCurrentName.contains('@')
              ? fallbackCurrentName.split('@').first
              : 'Client');
    showRequestChatModal(
      context: context,
      requestId: order.id,
      clientEmail: clientEmail,
      artistEmail: artistEmail,
      clientName: clientName,
      artistName: order.artistName.trim(),
    );
  }

  void _openAiSupportChat(BuildContext context) {
    final clientEmail = order.clientEmail.trim().toLowerCase();
    if (clientEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat unavailable for this order.')),
      );
      return;
    }
    final currentName = (FirebaseAuth.instance.currentUser?.displayName ?? '')
        .trim();
    final fallbackCurrentName = (FirebaseAuth.instance.currentUser?.email ?? '')
        .trim();
    final clientName = currentName.isNotEmpty
        ? currentName
        : (fallbackCurrentName.contains('@')
              ? fallbackCurrentName.split('@').first
              : 'Client');
    showRequestChatModal(
      context: context,
      requestId: '${order.id}-ai-support',
      clientEmail: clientEmail,
      artistEmail: 'ai.chatbot@jnt.com',
      clientName: clientName,
      artistName: 'JNT AI Assistant',
    );
  }

  List<String> _declineInfoLines() {
    final clientDeclined = order.declinedByClientEmails.isNotEmpty;
    final artistDeclined = order.declinedByArtistEmails.isNotEmpty;
    if (!clientDeclined && !artistDeclined) return const <String>[];

    if (clientDeclined && artistDeclined) {
      return const <String>[
        'Direct client declined this brand request.',
        'Direct artist declined this brand request.',
      ];
    }
    if (clientDeclined) {
      return const <String>['Direct client declined this brand request.'];
    }
    return const <String>['Direct artist declined this brand request.'];
  }

  Widget _declineInfoSection() {
    final lines = _declineInfoLines();
    if (lines.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Decline Information',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            fontFamily: 'ArialBold',
            color: AppColors.blackCat,
          ),
        ),
        const SizedBox(height: 8),
        for (final line in lines) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: AppColors.blackCat,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  line,
                  style: TextStyle(
                    color: AppColors.blackCat.withOpacity(0.85),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
          if (line != lines.last) const SizedBox(height: 6),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSubmittedStatus =
        statusPillText == 'New' ||
        statusPillText == 'In Review' ||
        statusPillText == 'Pending';
    final isCancelledStatus = statusPillText == 'Cancelled';
    final isExpiredStatus = statusPillText == 'Expired';
    final isClosedHistoryStatus = isCancelledStatus || isExpiredStatus;
    final isBrandRequest =
        order.sourceCollection.trim() == 'Company_Custom_Requests';
    final acceptedArtistMetaFuture = _loadAcceptedArtistMeta(order);

    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: AppBar(
        backgroundColor: AppColors.alabaster,
        surfaceTintColor: AppColors.alabaster,
        elevation: 0,
        title: ExcludeSemantics(
          child: Image.asset(
            'assets/images/jnt_logo_black.png',
            height: 50,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          Semantics(
            button: true,
            label: 'Close order details',
            hint: 'Double tap to close',
            onTap: () => Navigator.pop(context),
            child: ExcludeSemantics(
              child: IconButton(
                tooltip: 'Close order details',
                autofocus: MediaQuery.of(context).accessibleNavigation,
                icon: const Icon(Icons.close_rounded, size: 26),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
        leading: const SizedBox.shrink(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
        children: [
          if (isCancelledStatus) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.blackCat,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cancelled: This order has been cancelled. If you were charged, refund will be processed.',
                    style: TextStyle(
                      color: AppColors.blackCat,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Text(
                'Placed on: ${_placedOnText()}',
                style: TextStyle(
                  color: AppColors.blackCat,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  fontFamily: 'ArialBold',
                ),
              ),
              const Spacer(),
              Text(
                statusPillText,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppColors.blackCat,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isBrandRequest) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.balletSlippers,
                  borderRadius: BorderRadius.zero,
                  border: Border.all(color: AppColors.blackCatBorderLight),
                ),
                child: const Text(
                  'Brand Request',
                  style: TextStyle(
                    color: AppColors.blackCat,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Arial',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ] else
            const SizedBox(height: 12),

          if (isSubmittedStatus)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: Colors.black.withOpacity(0.60),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Artist is not assigned yet. Once your submitted request is accepted, artist details and messaging will appear here.',
                    style: TextStyle(
                      color: AppColors.blackCat,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),

          if (isBrandViewer &&
              isBrandRequest &&
              isSubmittedStatus &&
              _declineInfoLines().isNotEmpty) ...[
            const SizedBox(height: 12),
            _declineInfoSection(),
          ],

          if (!isSubmittedStatus && !isClosedHistoryStatus)
            _Card(
              child: FutureBuilder<_AcceptedArtistMeta>(
                future: acceptedArtistMetaFuture,
                builder: (context, snapshot) {
                  final meta =
                      snapshot.data ??
                      _AcceptedArtistMeta(
                        name: order.artistName.trim(),
                        profileImage: order.artistProfileImage.trim(),
                      );
                  final displayName = meta.name.trim().isEmpty
                      ? 'Artist'
                      : meta.name.trim();
                  final rating = meta.rating;
                  final location = [
                    meta.city.trim(),
                    meta.state.trim(),
                  ].where((e) => e.isNotEmpty).join(', ');

                  return Row(
                    children: [
                      Container(
                        height: 56,
                        width: 56,
                        decoration: BoxDecoration(
                          color: AppColors.blackCat.withOpacity(0.06),
                          borderRadius: BorderRadius.zero,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _artistAvatarWithFallback(
                          name: displayName,
                          raw: meta.profileImage,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            if (rating != null || location.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (rating != null) ...[
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 18,
                                      color: AppColors.alabaster,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      rating.toStringAsFixed(1),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                        color: AppColors.blackCat.withOpacity(
                                          0.85,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (rating != null &&
                                      location.isNotEmpty) ...[
                                    const SizedBox(width: 10),
                                  ],
                                  if (location.isNotEmpty)
                                    Flexible(
                                      child: Text(
                                        location,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w400,
                                          color: AppColors.blackCat.withOpacity(
                                            0.55,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              'Artist assigned to your request',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: AppColors.blackCat,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

          if (!isSubmittedStatus &&
              !isClosedHistoryStatus &&
              statusPillText != 'In Progress' &&
              statusPillText != 'Shipped' &&
              statusPillText != 'Delivered' &&
              order.artistName.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _Card(child: _artistWorkingInfoCard()),
          ],

          if (!isClosedHistoryStatus) const SizedBox(height: 14),

          if (isCancelledStatus) ...[
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reason for Cancellation',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    order.cancelReason.trim().isNotEmpty
                        ? order.cancelReason.trim()
                        : 'No reason provided.',
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.82),
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else if (isExpiredStatus) ...[
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reason for Expiration',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    order.cancelReason.trim().isNotEmpty
                        ? order.cancelReason.trim()
                        : 'This request expired before an artist could complete acceptance and confirmation in time.',
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.82),
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Common reasons:',
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.82),
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '1. No artist accepted the request before the need-by timeline.\n'
                    '2. The request was not confirmed in time.\n'
                    '3. Required details needed to proceed were incomplete.',
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.82),
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else if (order.clientDescription.trim().isNotEmpty) ...[
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      fontFamily: 'ArialBold',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    order.clientDescription.trim(),
                    style: TextStyle(
                      color: AppColors.blackCat.withOpacity(0.82),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      height: 1.25,
                      fontFamily: 'Arial',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (isCancelledStatus) ...[
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      fontFamily: 'ArialBold',
                      color: AppColors.blackCat,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    order.clientDescription.trim().isNotEmpty
                        ? order.clientDescription.trim()
                        : 'No description provided.',
                    style: TextStyle(
                      color: AppColors.blackCat.withOpacity(0.82),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      fontFamily: 'Arial',
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Divider(color: AppColors.blackCat.withOpacity(0.08)),
                  const SizedBox(height: 8),
                  const Text(
                    'Uploaded Photos',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      fontFamily: 'ArialBold',
                      color: AppColors.blackCat,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SubmittedPhotosStrip(
                    paths: order.inspirationPhotos,
                    fallbackOrderId: order.id,
                    fallbackOrderNumber: order.orderNumber,
                    sourceCollection: order.sourceCollection,
                    enableFirestoreFallback: true,
                  ),
                  const SizedBox(height: 14),
                  Divider(color: AppColors.blackCat.withOpacity(0.08)),
                  const SizedBox(height: 8),
                  const Text(
                    'Order Details',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      fontFamily: 'ArialBold',
                      color: AppColors.blackCat,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (order.sourceCollection.trim() ==
                      'Company_Custom_Requests') ...[
                    _bullet('Brand Name', _valueOrDash(order.brandName ?? '')),
                    _bullet(
                      'Campaign Name',
                      _valueOrDash(order.campaignName ?? ''),
                    ),
                  ],
                  _bullet('Need by', _valueOrDash(order.needByDisplay)),
                  _bullet('Request Artist', _requestArtistDisplay()),
                  // Keep in code per request, but hide from UI:
                  // _bullet('Status', statusPillText),
                  const SizedBox(height: 5),
                  _nailDimensionsRightAligned(),
                  const SizedBox(height: 8),
                  Divider(color: Colors.black.withOpacity(0.08)),
                  const SizedBox(height: 5),
                  _paymentSection(context),
                ],
              ),
            ),
          ] else ...[
            _SubmittedPhotosStrip(
              paths: order.inspirationPhotos,
              fallbackOrderId: order.id,
              fallbackOrderNumber: order.orderNumber,
              sourceCollection: order.sourceCollection,
              enableFirestoreFallback: true,
            ),

            const SizedBox(height: 14),

            _Card(child: _orderDetailsWithRightNailDimensions()),

            const SizedBox(height: 14),
            if (statusPillText == 'Shipped' ||
                statusPillText == 'Delivered') ...[
              _Card(child: _shippingInformationSection(context)),
              const SizedBox(height: 14),
            ],
            if (statusPillText != 'In Progress' && statusPillText != 'Shipped')
              _Card(child: _paymentSection(context)),
            if (statusPillText == 'Delivered' || statusPillText == 'Shipped')
              const SizedBox(height: 14),
            if (statusPillText == 'In Progress') ...[
              if (order.artistCompletedPhotos.isNotEmpty) ...[
                _Card(child: _artistCompletedArtSection()),
                const SizedBox(height: 12),
              ],

              _Card(child: _finalAcceptedAmountSection()),
              const SizedBox(height: 12),

              SizedBox(
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blackCat.withValues(alpha: 0.78),
                    foregroundColor: AppColors.snow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => _openRequestChat(context),
                  child: const Text(
                    'Chat',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Arial',
                    ),
                  ),
                ),
              ),
            ],

            if (statusPillText == 'Shipped' ||
                statusPillText == 'Delivered') ...[
              if (order.artistCompletedPhotos.isNotEmpty) ...[
                _Card(child: _artistCompletedArtSection()),
                const SizedBox(height: 12),
              ],

              _Card(child: _finalAcceptedAmountSection()),
              const SizedBox(height: 12),
              if (statusPillText == 'Delivered') ...[
                _Card(child: rightPanel),
                const SizedBox(height: 12),
              ],

              Center(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blackCat,
                      foregroundColor: AppColors.snow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      int popCount = 0;
                      Navigator.of(context).popUntil((route) {
                        return popCount++ >= 2 || route.isFirst;
                      });
                    },
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
          if (isClosedHistoryStatus) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  fit: FlexFit.loose,
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.blackCat.withValues(
                          alpha: 0.78,
                        ),
                        foregroundColor: AppColors.snow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                        side: const BorderSide(color: AppColors.blackCat),
                      ),
                      onPressed: () {
                        if (isCancelledStatus) {
                          (onCancelledChat ?? () => _openAiSupportChat(context))
                              .call();
                          return;
                        }
                        (onExpiredChat ??
                                onCancelledChat ??
                                () => _openAiSupportChat(context))
                            .call();
                      },
                      child: const Text(
                        'Chat',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          fontFamily: 'Arial',
                          color: AppColors.snow,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  fit: FlexFit.loose,
                  child: SizedBox(
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
                      onPressed: isCancelledStatus
                          ? ((onCancelledResubmit ?? onExpiredResubmit) == null
                                ? null
                                : () =>
                                      (onCancelledResubmit ??
                                              onExpiredResubmit)!
                                          .call())
                          : ((onExpiredResubmit ?? onCancelledResubmit) == null
                                ? null
                                : () =>
                                      (onExpiredResubmit ??
                                              onCancelledResubmit)!
                                          .call()),
                      child: const Text(
                        'Resubmit',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (isSubmittedStatus) ...[
            const SizedBox(height: 14),
            Center(
              child: SizedBox(
                height: 50,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.blackCat,
                    foregroundColor: AppColors.snow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                    side: const BorderSide(color: AppColors.blackCat),
                  ),
                  onPressed: () async {
                    final result = await showDialog<_CancelOrderResult>(
                      context: context,
                      barrierDismissible: true,
                      builder: (_) => const _CancelOrderDialog(),
                    );

                    if (!context.mounted || result == null) return;

                    if (!result.confirm) {
                      Navigator.of(context).pop();
                      return;
                    }

                    try {
                      final docRef = FirebaseFirestore.instance
                          .collection('Client_Custom_Requests')
                          .doc(order.id);
                      final snap = await docRef.get();
                      var activeRef = docRef;
                      var rootData = snap.data() ?? const <String, dynamic>{};
                      if (!snap.exists) {
                        final companyRef = FirebaseFirestore.instance
                            .collection('Company_Custom_Requests')
                            .doc(order.id);
                        final companySnap = await companyRef.get();
                        if (companySnap.exists) {
                          activeRef = companyRef;
                          rootData =
                              companySnap.data() ?? const <String, dynamic>{};
                        }
                      }
                      final detailsSnap = await activeRef
                          .collection('details')
                          .doc('payload')
                          .get();
                      final detailsData =
                          detailsSnap.data() ?? const <String, dynamic>{};

                      String firstNonEmpty(
                        List<Object?> values, {
                        String fallback = '',
                      }) {
                        for (final value in values) {
                          final text = (value ?? '').toString().trim();
                          if (text.isNotEmpty) return text;
                        }
                        return fallback;
                      }

                      final sourceCollection = activeRef.parent.id;
                      final isBrandRequest =
                          sourceCollection == 'Company_Custom_Requests';
                      final isOpenClientPool =
                          rootData['openToClientPool'] == true ||
                          detailsData['openToClientPool'] == true ||
                          ((detailsData['order'] is Map
                                  ? (detailsData['order']
                                        as Map)['openToClientPool']
                                  : null) ==
                              true);
                      final acceptedArtistEmail = firstNonEmpty(<Object?>[
                        rootData['acceptedByArtistEmail'],
                        (detailsData['acceptance'] is Map
                            ? (detailsData['acceptance']
                                  as Map)['acceptedByArtistEmail']
                            : null),
                      ]).toLowerCase();
                      final artistAccepted = acceptedArtistEmail.isNotEmpty;
                      final shouldReopenPool =
                          isBrandRequest && isOpenClientPool && !artistAccepted;
                      final selectedReason = result.reason.trim();
                      final normalizedSelectedReason = selectedReason.isNotEmpty
                          ? selectedReason
                          : 'Change in plans';
                      if (normalizedSelectedReason.isEmpty) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cancellation reason is required.'),
                          ),
                        );
                        return;
                      }
                      final normalizedReason = normalizedSelectedReason;
                      final currentClientEmail =
                          (FirebaseAuth.instance.currentUser?.email ?? '')
                              .trim()
                              .toLowerCase();

                      await activeRef.set({
                        'status': shouldReopenPool ? 'in_review' : 'cancelled',
                        if (isBrandRequest) 'brandStatus': 'cancelled',
                        'clientStatus': 'cancelled',
                        'artistStatus': shouldReopenPool
                            ? 'in_review'
                            : 'cancelled',
                        if (shouldReopenPool) 'acceptedByClientEmail': '',
                        if (shouldReopenPool && currentClientEmail.isNotEmpty)
                          'declinedByClientEmails': FieldValue.arrayUnion(
                            <String>[currentClientEmail],
                          ),
                        'updatedAt': FieldValue.serverTimestamp(),
                        'cancelledAt': FieldValue.serverTimestamp(),
                        'cancelReason': normalizedReason,
                      }, SetOptions(merge: true));
                      await activeRef.collection('details').doc('payload').set({
                        'status': shouldReopenPool ? 'in_review' : 'cancelled',
                        'roleStatuses': {
                          if (isBrandRequest) 'brand': 'cancelled',
                          'client': 'cancelled',
                          'artist': shouldReopenPool
                              ? 'in_review'
                              : 'cancelled',
                        },
                        if (shouldReopenPool)
                          'acceptance': {'acceptedByClientEmail': ''},
                        if (shouldReopenPool && currentClientEmail.isNotEmpty)
                          'declinedByClientEmails': FieldValue.arrayUnion(
                            <String>[currentClientEmail],
                          ),
                        'cancellation': {
                          'reason': normalizedReason,
                          'cancelledAt': FieldValue.serverTimestamp(),
                          'cancelledBy': 'client',
                        },
                      }, SetOptions(merge: true));

                      await _notifyArtistsOnClientCancellation(
                        reason: normalizedReason,
                        rootData: rootData,
                        detailsData: detailsData,
                        sourceCollection: sourceCollection,
                      );

                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to cancel order: $e')),
                      );
                    }
                  },
                  child: const Text(
                    'Cancel Order',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                      fontFamily: 'Arial',
                      color: AppColors.snow,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _artistCompletedArtSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Artist Completed Art',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            fontFamily: 'ArialBold',
            color: AppColors.blackCat,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 120,
          child: _SubmittedPhotosStrip(paths: order.artistCompletedPhotos),
        ),
      ],
    );
  }

  Widget _paymentSection(BuildContext context) {
    final normalizedStatus = order.paymentStatus.trim().toLowerCase();
    final isPaid =
        normalizedStatus == 'paid' || normalizedStatus == 'completed';
    final isPending =
        !isPaid &&
        (statusPillText == 'In Progress' || order.artistAcceptedAmount != null);
    final header = isPaid
        ? 'Payment Completed'
        : isPending
        ? 'Payment Pending'
        : 'Payment Range';
    final amount =
        (order.artistAcceptedAmount ?? order.budgetMax ?? order.budgetMin);
    final rangeText = _budgetText();
    final amountText = amount == null ? rangeText : '\$$amount';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          header,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              isPaid
                  ? 'Paid Amount:'
                  : isPending
                  ? 'Amount Due:'
                  : 'Range:',
              style: TextStyle(
                color: Colors.black,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
            const Spacer(),
            Text(
              isPending || isPaid ? amountText : rangeText,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.blackCat,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          isPaid
              ? 'Paid on: ${_dateText(order.paidAt) ?? _placedOnText()}'
              : isPending
              ? 'Awaiting client payment confirmation.'
              : 'Final amount will be confirmed by artist acceptance.',
          style: TextStyle(
            color: AppColors.blackCat,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
        if (!isPaid && isPending && order.paymentLink.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Payment link has been sent to your notifications and email.',
            style: TextStyle(
              color: Colors.black.withOpacity(0.55),
              fontWeight: FontWeight.w400,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blackCat,
                foregroundColor: AppColors.snow,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                elevation: 0,
              ),
              onPressed: () => _simulatePayment(context),
              child: const Text(
                'Pay Now (Simulated)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _artistWorkingInfoCard() {
    return Row(
      children: [
        Container(
          height: 50,
          width: 50,
          decoration: BoxDecoration(
            color: AppColors.balletSlippers,
            borderRadius: BorderRadius.zero,
          ),
          clipBehavior: Clip.antiAlias,
          child: _artistProfileImage(order.artistProfileImage),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.artistName.trim(),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Artist working on your nail art',
                style: TextStyle(
                  color: AppColors.blackCat,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _finalAcceptedAmountSection() {
    final amount = order.artistAcceptedAmount;
    final text = amount == null ? '-' : '\$$amount';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Final Amount',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppColors.blackCat,
            fontFamily: 'ArialBold',
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              'Accepted by artist:',
              style: TextStyle(
                color: AppColors.blackCat,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.blackCat,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _shippingInformationSection(BuildContext context) {
    final courier = order.shippedByCourier.trim().isEmpty
        ? '-'
        : order.shippedByCourier.trim();
    final tracking = order.trackingNumber.trim().isEmpty
        ? '-'
        : order.trackingNumber.trim();
    final shippedOn = _dateText(order.shippedAt) ?? '-';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Shipping Information',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppColors.blackCat,
            fontFamily: 'ArialBold',
          ),
        ),
        const SizedBox(height: 10),
        _bullet('Courier', courier),
        _bullet('Shipping Date', shippedOn),
        _bullet('Tracking #', tracking),
        if (statusPillText == 'Shipped') ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: OutlinedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blackCat,
                foregroundColor: AppColors.snow,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TrackOrderPage(order: order),
                  ),
                );
              },
              child: const Text(
                'Track Order',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.snow,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _notifyArtistsOnClientCancellation({
    required String reason,
    required Map<String, dynamic> rootData,
    required Map<String, dynamic> detailsData,
    required String sourceCollection,
  }) async {
    String firstNonEmpty(List<Object?> values, {String fallback = ''}) {
      for (final value in values) {
        final text = (value ?? '').toString().trim();
        if (text.isNotEmpty) return text;
      }
      return fallback;
    }

    final targets = <String>{};
    String readEmail(Object? v) => (v ?? '').toString().trim().toLowerCase();

    final isBrandRequest = sourceCollection == 'Company_Custom_Requests';
    final campaignName = firstNonEmpty(<Object?>[
      rootData['campaignName'],
      rootData['title'],
      detailsData['campaignName'],
    ], fallback: 'Campaign');
    final brandCompany = firstNonEmpty(<Object?>[
      rootData['companyName'],
      rootData['brandName'],
      detailsData['companyName'],
    ], fallback: 'Brand Company');
    final orderRef = firstNonEmpty(<Object?>[
      rootData['orderNumber'],
      detailsData['orderNumber'],
      order.id,
    ], fallback: order.id);
    final clientName = firstNonEmpty(<Object?>[
      rootData['acceptedClientName'],
      rootData['clientName'],
      (detailsData['clientProfileSnapshot'] is Map
          ? ((detailsData['clientProfileSnapshot'] as Map)['basic'] is Map
                ? ((detailsData['clientProfileSnapshot'] as Map)['basic']
                      as Map)['name']
                : null)
          : null),
      FirebaseAuth.instance.currentUser?.displayName,
      'Client',
    ], fallback: 'Client');

    final acceptedBy = readEmail(rootData['acceptedByArtistEmail']);
    if (acceptedBy.isNotEmpty) targets.add(acceptedBy);

    final selectedByRoot = readEmail(rootData['selectedArtistEmail']);
    if (selectedByRoot.isNotEmpty) targets.add(selectedByRoot);

    final orderMeta =
        (detailsData['order'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final selectedByDetails = readEmail(orderMeta['selectedArtistEmail']);
    if (selectedByDetails.isNotEmpty) targets.add(selectedByDetails);

    final isDirect =
        (rootData['isDirectRequest'] == true) ||
        (orderMeta['isDirectRequest'] == true);
    if (!isDirect) {
      bool isBrandEligibleArtist(Map<String, dynamic> data) {
        final profile =
            (data['profile'] as Map<String, dynamic>?) ??
            const <String, dynamic>{};
        final ascension =
            (data['ascension'] as Map<String, dynamic>?) ??
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
        final eligibleCandidates = <Object?>[
          ascension['sponsorshipEligible'],
          data['panel_brandEligible'],
          profile['sponsorshipEligible'],
        ];
        for (final raw in eligibleCandidates) {
          if (raw == true) return true;
          if (raw is num && raw != 0) return true;
          if ((raw ?? '').toString().trim().toLowerCase() == 'true') {
            return true;
          }
        }
        return false;
      }

      for (final collection in const <String>['artist', 'client_artist']) {
        try {
          final snap = await FirebaseFirestore.instance
              .collection(collection)
              .get();
          for (final doc in snap.docs) {
            final data = doc.data();
            if (isBrandRequest && !isBrandEligibleArtist(data)) continue;
            final email = readEmail(data['email']);
            if (email.isNotEmpty) targets.add(email);
          }
        } catch (_) {}
      }
    }

    if (isBrandRequest) {
      final brandRecipientEmails =
          await NotificationsService.resolveBrandRecipientEmails(
            rootData: rootData,
            detailsData: detailsData,
          );
      for (final brandEmail in brandRecipientEmails) {
        try {
          await NotificationsService.createUserNotification(
            receiverEmail: brandEmail,
            title: 'Brand Request Cancelled',
            body:
                '$clientName cancelled your $campaignName brand request $orderRef $reason',
            type: 'brand_request_cancelled_by_client',
            orderId: order.id,
            orderNumber: orderRef,
            sourceCollection: sourceCollection,
          );
        } catch (_) {}
      }

      await NotificationsService.notifyAdmins(
        title: 'Brand Request Cancelled',
        body:
            '$clientName cancelled the $brandCompany $campaignName brand request $orderRef $reason',
        type: 'admin_brand_request_cancelled_by_client',
        orderId: order.id,
        orderNumber: orderRef,
        sourceCollection: sourceCollection,
      );
    }

    for (final email in targets) {
      try {
        await NotificationsService.createUserNotification(
          receiverEmail: email,
          title: isBrandRequest
              ? 'Brand Request Cancelled'
              : 'Client Cancelled Request',
          body: isBrandRequest
              ? '$clientName cancelled the $brandCompany $campaignName brand request $orderRef $reason'
              : 'Client has cancelled the request. Reason: $reason',
          type: isBrandRequest
              ? 'artist_pool_brand_request_cancelled_by_client'
              : 'client_cancelled_request',
          orderId: order.id,
          orderNumber: orderRef,
          sourceCollection: sourceCollection,
        );
      } catch (_) {}
    }
  }

  Widget _designApprovalSection(BuildContext context) {
    final status = order.designApprovalStatus.trim().toLowerCase();
    final approved = status == 'approved';
    final pending = status == 'pending';
    final hasPreviewPhotos = order.designPreviewPhotos.isNotEmpty;
    final approvedOn = _dateText(order.designApprovedAt);
    if (pending) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureDesignApprovalReminderIfDue(context);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Design Approval',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          approved
              ? 'You accepted the finalized design.'
              : (pending
                    ? 'Your artist shared a design preview. Accept it to let the artist start production.'
                    : 'Your artist will upload a design preview here for your approval.'),
          style: TextStyle(
            color: Colors.black.withOpacity(0.60),
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
        if (hasPreviewPhotos) ...[
          const SizedBox(height: 10),
          if (order.inspirationPhotos.isNotEmpty) ...[
            const Text(
              'Uploaded Photos (Client)',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                fontFamily: 'ArialBold',
                color: AppColors.blackCat,
              ),
            ),
            const SizedBox(height: 10),
            _SubmittedPhotosStrip(
              paths: order.inspirationPhotos,
              fallbackOrderId: order.id,
              fallbackOrderNumber: order.orderNumber,
              sourceCollection: order.sourceCollection,
              enableFirestoreFallback: true,
            ),
            const SizedBox(height: 14),
          ],
        ],
        if (pending) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8FB),
              borderRadius: BorderRadius.zero,
              border: Border.all(color: AppColors.blackCatBorderLight),
            ),
            child: Text(
              _designDueText(),
              style: TextStyle(
                color: Colors.black.withOpacity(0.65),
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        if (approved)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7F2),
              borderRadius: BorderRadius.zero,
              border: Border.all(color: const Color(0xFFB9DEC9)),
            ),
            child: Text(
              approvedOn == null ? 'Accepted' : 'Accepted on $approvedOn',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2E8B57),
              ),
            ),
          )
        else
          SizedBox(
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blackCat,
                foregroundColor: AppColors.snow,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                elevation: 0,
              ),
              onPressed: () => _clientAcceptDesign(context),
              child: const Text(
                'Accept Design',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ],
    );
  }

  String _designDueText() {
    final due = order.designApprovalDueAt;
    if (due == null) return 'Please accept within 1 day.';
    final now = DateTime.now();
    if (due.isBefore(now)) {
      return 'Please accept as soon as possible. A reminder notification was sent.';
    }
    final hours = due.difference(now).inHours;
    if (hours <= 1) return 'Please accept within the next hour.';
    return 'Please accept within ${hours}h.';
  }

  Future<void> _ensureDesignApprovalReminderIfDue(BuildContext context) async {
    final orderId = order.id.trim();
    if (orderId.isEmpty) return;
    if (_designReminderCheckInFlight.contains(orderId)) return;
    _designReminderCheckInFlight.add(orderId);
    try {
      final docRef = FirebaseFirestore.instance
          .collection('Client_Custom_Requests')
          .doc(orderId);
      final snap = await docRef.get();
      final data = snap.data() ?? const <String, dynamic>{};
      final status = ((data['designApprovalStatus'] ?? '') as Object)
          .toString()
          .trim()
          .toLowerCase();
      if (status == 'approved') return;
      final dueTs = data['designApprovalDueAt'] is Timestamp
          ? data['designApprovalDueAt'] as Timestamp
          : null;
      final reminderSent = data['designReminderSentAt'] != null;
      if (dueTs == null || reminderSent) return;
      if (!DateTime.now().isAfter(dueTs.toDate())) return;

      final receiver = order.clientEmail.trim().toLowerCase();
      if (receiver.isNotEmpty) {
        await NotificationsService.createUserNotification(
          receiverEmail: receiver,
          title: 'Reminder: Approve Your Nail Design',
          body:
              'Please review and accept your design so the artist can begin working on your order.',
          type: 'design_approval_reminder',
          orderId: order.id,
          sourceCollection: 'Client_Custom_Requests',
        );
      }

      await docRef.set({
        'designReminderSentAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await docRef.collection('details').doc('payload').set({
        'designApproval': {'reminderSentAt': FieldValue.serverTimestamp()},
      }, SetOptions(merge: true));
    } catch (_) {
      // Ignore reminder failures to avoid interrupting order details UX.
    } finally {
      _designReminderCheckInFlight.remove(orderId);
    }
  }

  Widget _artistProfileImage(String raw) {
    final src = raw.trim();
    if (src.isEmpty) {
      return _artistProfilePlaceholder();
    }
    if (src.startsWith('assets/')) {
      return Image.asset(
        src,
        height: 56,
        width: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _artistProfilePlaceholder(),
      );
    }
    return Image.network(
      src,
      height: 56,
      width: 56,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _artistProfilePlaceholder(),
    );
  }

  Widget _artistProfilePlaceholder() {
    return Container(
      height: 56,
      width: 56,
      color: AppColors.balletSlippers,
      alignment: Alignment.center,
      child: Icon(Icons.person_outline, color: Colors.black.withOpacity(0.5)),
    );
  }

  Widget _artistAvatarWithFallback({
    required String name,
    required String raw,
  }) {
    final src = raw.trim();
    if (src.isEmpty) {
      return Container(
        color: AppColors.balletSlippers,
        alignment: Alignment.center,
        child: Text(
          name.trim().isEmpty ? 'A' : name.trim().substring(0, 1).toUpperCase(),
          style: TextStyle(
            color: Colors.black.withOpacity(0.65),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      );
    }
    if (src.startsWith('assets/')) {
      return Image.asset(
        src,
        height: 56,
        width: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _artistProfilePlaceholder(),
      );
    }
    return Image.network(
      src,
      height: 56,
      width: 56,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _artistProfilePlaceholder(),
    );
  }

  /*Widget _clientReviewSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Completed Set Review',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          'Artist uploaded completed set photos. Please accept or decline.',
          style: TextStyle(
            color: Colors.black.withOpacity(0.6),
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 120,
          child: _SubmittedPhotosStrip(paths: order.artistCompletedPhotos),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                onPressed: () => _clientDeclineCompletedProject(context),
                child: const Text('Decline'),
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
                onPressed: () => _clientAcceptCompletedProject(context),
                child: const Text('Accept'),
              ),
            ),
          ],
        ),
      ],
    );
  }*/

  /*Widget _clientReviewAcceptedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Completed Set Review',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          'Artist uploaded completed set photos.',
          style: TextStyle(
            color: Colors.black.withOpacity(0.6),
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 120,
          child: _SubmittedPhotosStrip(paths: order.artistCompletedPhotos),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF7F2),
            borderRadius: BorderRadius.zero,
            border: Border.all(color: const Color(0xFFB9DEC9)),
          ),
          child: const Text(
            'Accepted',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2E8B57),
            ),
          ),
        ),
      ],
    );
  }*/

  /*Widget _completionDeclineSection() {
    final declinedDateText = _dateText(order.completionDeclinedAt) ?? '—';
    final raw = order.completionDeclineReason.trim();
    final tokens = raw
        .split(RegExp(r'\s*[|,]\s*'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    String otherReason = '';
    final regularReasons = <String>[];
    for (final t in tokens) {
      final m = RegExp(
        r'^Other\s*:\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(t);
      if (m != null) {
        final extracted = (m.group(1) ?? '').trim();
        if (extracted.isNotEmpty) otherReason = extracted;
      } else {
        regularReasons.add(t);
      }
    }

    final reasonText = regularReasons.isNotEmpty
        ? regularReasons.join(', ')
        : (otherReason.isNotEmpty ? 'Other' : 'No reason provided.');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Decline Reason',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 10),
        _bullet('Reason to decline', reasonText),
        if (otherReason.isNotEmpty) _bullet('Other reason', otherReason),
        _bullet('Date declined', declinedDateText),
      ],
    );
  }*/

  /*Future<void> _clientAcceptCompletedProject(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(
          'Accept Completed Set',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Do you confirm the uploaded set is approved for shipping?',
          style: TextStyle(fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'No',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blackCat,
              foregroundColor: AppColors.snow,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Yes, Accept',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      final isPaid = const {
        'paid',
        'completed',
      }.contains(order.paymentStatus.trim().toLowerCase());
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final generatedTracking =
          'JNT${(nowMs % 1000000000).toString().padLeft(9, '0')}';
      final generatedCarrier = 'USPS';
      final generatedPdfUrl =
          'jnt://shipping/label?order=${order.id}&download=1';
      final generatedQrData =
          'jnt://shipping/scan?order=${order.id}&tracking=$generatedTracking';

      final docRef = FirebaseFirestore.instance
          .collection('Client_Custom_Requests')
          .doc(order.id);
      await docRef.set({
        'completionReviewStatus': 'approved',
        'completionReviewedAt': FieldValue.serverTimestamp(),
        'shippingLabelReady': isPaid,
        'shippingLabelCarrier': isPaid ? generatedCarrier : '',
        'shippingLabelTrackingNumber': isPaid ? generatedTracking : '',
        'shippingLabelPdfUrl': isPaid ? generatedPdfUrl : '',
        'shippingLabelQrData': isPaid ? generatedQrData : '',
        'shippingLabelCreatedAt': isPaid ? FieldValue.serverTimestamp() : null,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await docRef.collection('details').doc('payload').set({
        'artistCompletion': {
          'reviewStatus': 'approved',
          'reviewedAt': FieldValue.serverTimestamp(),
        },
        'shippingLabel': {
          'ready': isPaid,
          'carrier': isPaid ? generatedCarrier : '',
          'trackingNumber': isPaid ? generatedTracking : '',
          'pdfUrl': isPaid ? generatedPdfUrl : '',
          'qrData': isPaid ? generatedQrData : '',
          'createdAt': isPaid ? FieldValue.serverTimestamp() : null,
        },
      }, SetOptions(merge: true));

      final artistEmail = order.acceptedByArtistEmail.trim().toLowerCase();
      if (artistEmail.isNotEmpty) {
        await NotificationsService.createUserNotification(
          receiverEmail: artistEmail,
          title: isPaid
              ? 'Client Approved - Ready to Ship'
              : 'Client Approved - Awaiting Payment',
          body: isPaid
              ? 'Client approved and paid. Shipping label is ready with tracking auto-filled.'
              : 'Client approved the completed set. Shipping label will be generated once payment is completed.',
          type: 'client_approved_shipping',
          orderId: order.id,
          sourceCollection: 'Client_Custom_Requests',
        );
      }

      if (!context.mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to accept completed set: $e')),
      );
    }
  }*/

  Future<void> _clientAcceptDesign(BuildContext context) async {
    if (order.designPreviewPhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Design preview is not available yet.')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(
          'Accept Design',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Do you approve this finalized design and allow the artist to start work?',
          style: TextStyle(fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'No',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blackCat,
              foregroundColor: AppColors.snow,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Yes, Accept',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      final docRef = FirebaseFirestore.instance
          .collection('Client_Custom_Requests')
          .doc(order.id);

      await docRef.set({
        'designApprovalStatus': 'approved',
        'designApprovedAt': FieldValue.serverTimestamp(),
        'clientDesignApprovalStatus': 'approved',
        'clientDesignApprovedAt': FieldValue.serverTimestamp(),
        'designReminderSentAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await docRef.collection('details').doc('payload').set({
        'designApproval': {
          'status': 'approved',
          'approvedAt': FieldValue.serverTimestamp(),
          'approvedByClient': true,
          'reminderSentAt': null,
        },
      }, SetOptions(merge: true));

      final artistEmail = order.acceptedByArtistEmail.trim().toLowerCase();
      if (artistEmail.isNotEmpty) {
        await NotificationsService.createUserNotification(
          receiverEmail: artistEmail,
          title: 'Design Approved by Client',
          body: 'Client approved the finalized design. You can begin work.',
          type: 'design_approved',
          orderId: order.id,
          sourceCollection: 'Client_Custom_Requests',
        );
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Design accepted. Artist notified.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to accept design: $e')));
    }
  }

  Future<void> _clientDeclineCompletedProject(BuildContext context) async {
    final otherReasonCtrl = TextEditingController();
    final selectedReasons = <String>{};
    const otherOption = 'Other (please specify)';
    String? modalError;
    const groupedReasons = <String, List<String>>{
      'Design & Accuracy': <String>[
        'The design does not match my original request',
        'Colors are different from what I approved',
        'Nail shape is incorrect',
        'Nail length is incorrect',
        'Missing design elements/details',
        'Overall design feels different from inspiration photos',
      ],
      'Measurements & Fit': <String>[
        'Nail measurements look incorrect',
        'Size does not match my profile measurements',
      ],
      'Quality Concerns': <String>[
        'Finish looks uneven',
        'Embellishments are misplaced',
        'Art details look incomplete',
        'Quality does not meet expectations',
      ],
      'Communication / Revision': <String>[
        'I requested changes that were not applied',
        'I would like minor revisions before shipping',
      ],
      'Other': <String>['I changed my mind about the design', otherOption],
    };

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            title: const Text(
              'Decline Completed Set',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select a decline reason:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.black.withOpacity(0.75),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...groupedReasons.entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 6),
                          Text(
                            entry.key,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          ...entry.value.map((reason) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                checkboxTheme: const CheckboxThemeData(
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity(
                                    horizontal: -4,
                                    vertical: -4,
                                  ),
                                ),
                              ),
                              child: Transform.scale(
                                scale: 0.9,
                                child: CheckboxListTile(
                                  dense: true,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  contentPadding: EdgeInsets.zero,
                                  visualDensity: const VisualDensity(
                                    horizontal: -4,
                                    vertical: -4,
                                  ),
                                  title: Text(
                                    reason,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  value: selectedReasons.contains(reason),
                                  onChanged: (checked) {
                                    setStateDialog(() {
                                      if (checked == true) {
                                        selectedReasons.add(reason);
                                      } else {
                                        selectedReasons.remove(reason);
                                      }
                                      modalError = null;
                                    });
                                  },
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    }),
                    if (selectedReasons.contains(otherOption)) ...[
                      TextField(
                        controller: otherReasonCtrl,
                        onChanged: (_) {
                          if (modalError != null) {
                            setStateDialog(() {
                              modalError = null;
                            });
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Other reason',
                          hintText: 'Enter custom reason',
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (modalError != null) ...[
                      Text(
                        modalError!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blackCat,
                  foregroundColor: AppColors.snow,
                ),
                onPressed: () {
                  if (selectedReasons.isEmpty) {
                    setStateDialog(() {
                      modalError = 'Please select at least one decline reason.';
                    });
                    return;
                  }
                  if (selectedReasons.contains(otherOption) &&
                      otherReasonCtrl.text.trim().isEmpty) {
                    setStateDialog(() {
                      modalError = 'Please specify the other reason.';
                    });
                    return;
                  }
                  setStateDialog(() {
                    modalError = null;
                  });
                  Navigator.of(context).pop(true);
                },
                child: const Text(
                  'Submit Decline',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
                ),
              ),
            ],
          );
        },
      ),
    );

    final orderedSelectedReasons = groupedReasons.values
        .expand((v) => v)
        .where(selectedReasons.contains)
        .toList(growable: false);
    final reason = orderedSelectedReasons
        .map(
          (r) => r == otherOption ? 'Other: ${otherReasonCtrl.text.trim()}' : r,
        )
        .join(', ')
        .trim();
    otherReasonCtrl.dispose();
    if (ok != true || !context.mounted) return;

    try {
      final docRef = FirebaseFirestore.instance
          .collection('Client_Custom_Requests')
          .doc(order.id);
      await docRef.set({
        'status': 'designing',
        'completionReviewStatus': 'declined',
        'completionDeclineReason': reason,
        'completionDeclineDescription': '',
        'completionDeclinedAt': FieldValue.serverTimestamp(),
        'completionReviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await docRef.collection('details').doc('payload').set({
        'status': 'designing',
        'artistCompletion': {
          'reviewStatus': 'declined',
          'declineReason': reason,
          'declineDescription': '',
          'reviewedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));

      final artistEmail = order.acceptedByArtistEmail.trim().toLowerCase();
      if (artistEmail.isNotEmpty) {
        await NotificationsService.createUserNotification(
          receiverEmail: artistEmail,
          title: 'Completed Set Declined',
          body:
              'Client declined the completed set. Please redo and resubmit. Reason: $reason',
          type: 'client_declined_redo',
          orderId: order.id,
          sourceCollection: 'Client_Custom_Requests',
        );
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Declined. Artist notified and order moved back to Designing.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to decline completed set: $e')),
      );
    }
  }

  Future<void> _simulatePayment(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(
          'Simulate Payment',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Mark this order as paid for testing?',
          style: TextStyle(fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blackCat,
              foregroundColor: AppColors.snow,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Mark Paid',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final docRef = FirebaseFirestore.instance
          .collection('Client_Custom_Requests')
          .doc(order.id);
      final snap = await docRef.get();
      final data = snap.data() ?? const <String, dynamic>{};
      final acceptedByArtistEmail =
          ((data['acceptedByArtistEmail'] ?? '') as Object).toString().trim();
      final orderNumber = ((data['orderNumber'] ?? '') as Object)
          .toString()
          .trim();

      await docRef.set({
        if (((data['status'] ?? '') as Object)
                .toString()
                .trim()
                .toLowerCase() ==
            'accepted')
          'status': 'designing',
        'paymentStatus': 'paid',
        'paidAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'paymentNotifiedArtist': acceptedByArtistEmail.isNotEmpty,
        if (acceptedByArtistEmail.isNotEmpty)
          'paymentNotifiedArtistAt': FieldValue.serverTimestamp(),
        'payment': {
          'status': 'paid',
          'paidAt': FieldValue.serverTimestamp(),
          'paymentLink': order.paymentLink,
        },
      }, SetOptions(merge: true));

      await docRef.collection('details').doc('payload').set({
        if (((data['status'] ?? '') as Object)
                .toString()
                .trim()
                .toLowerCase() ==
            'accepted')
          'status': 'designing',
        'payment': {
          'status': 'paid',
          'paidAt': FieldValue.serverTimestamp(),
          'paymentLink': order.paymentLink,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (acceptedByArtistEmail.isNotEmpty) {
        await NotificationsService.createUserNotification(
          receiverEmail: acceptedByArtistEmail,
          title: 'Payment Done',
          body: orderNumber.isEmpty
              ? 'Client completed payment for your accepted request.'
              : 'Payment completed for order $orderNumber.',
          type: 'payment_done',
          orderId: order.id,
          orderNumber: orderNumber,
          sourceCollection: 'Client_Custom_Requests',
        );
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment marked as completed (simulated).'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to simulate payment: $e')));
    }
  }

  String? _dateText(DateTime? date) {
    if (date == null) return null;
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<_RequestNfcDetails> _loadRequestNfcDetails() async {
    final id = order.id.trim();
    if (id.isEmpty) return _RequestNfcDetails.empty();

    final collection = order.sourceCollection.trim().isEmpty
        ? 'Client_Custom_Requests'
        : order.sourceCollection.trim();

    Map<String, dynamic> asMap(dynamic value) {
      if (value is Map<String, dynamic>) {
        return Map<String, dynamic>.from(value);
      }
      if (value is Map) {
        return value.map((key, value) => MapEntry(key.toString(), value));
      }
      return <String, dynamic>{};
    }

    try {
      var doc = await FirebaseFirestore.instance
          .collection(collection)
          .doc(id)
          .get();
      if (!doc.exists && collection != 'Client_Custom_Requests') {
        doc = await FirebaseFirestore.instance
            .collection('Client_Custom_Requests')
            .doc(id)
            .get();
      }
      if (!doc.exists && collection != 'Company_Custom_Requests') {
        doc = await FirebaseFirestore.instance
            .collection('Company_Custom_Requests')
            .doc(id)
            .get();
      }

      final root = doc.data() ?? const <String, dynamic>{};
      Map<String, dynamic> details = const <String, dynamic>{};
      if (doc.exists) {
        final detailsSnap = await doc.reference
            .collection('details')
            .doc('payload')
            .get();
        details = detailsSnap.data() ?? const <String, dynamic>{};
      }
      final payload = asMap(details['payload']).isNotEmpty
          ? asMap(details['payload'])
          : details;
      return _RequestNfcDetails.fromMaps(root: root, details: payload);
    } catch (_) {
      return _RequestNfcDetails.empty();
    }
  }

  Widget _orderDetailsWithRightNailDimensions() {
    final isGroupOrder =
        order.orderType.trim().toLowerCase() == 'group' ||
        order.groupClients.isNotEmpty;

    Widget detailsBlock() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Details',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 10),
          if (order.sourceCollection.trim() == 'Company_Custom_Requests') ...[
            _bullet('Brand Name', _valueOrDash(order.brandName ?? '')),
            _bullet('Campaign Name', _valueOrDash(order.campaignName ?? '')),
          ],
          _bullet('Need by', _valueOrDash(order.needByDisplay)),
          _bullet('Request Artist', _requestArtistDisplay()),
          // Keep in code per request, but hide from UI:
          // _bullet('Status', statusPillText),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        detailsBlock(),
        const SizedBox(height: 10),
        isGroupOrder
            ? _groupClientMeasurementsSection()
            : _nailDimensionsRightAligned(),
      ],
    );
  }

  Widget _groupClientMeasurementsSection() {
    return FutureBuilder<_RequestNfcDetails>(
      future: _loadRequestNfcDetails(),
      builder: (context, snapshot) {
        final nfc = snapshot.data ?? _RequestNfcDetails.empty();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Client Measurements',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
            ),
            const SizedBox(height: 8),
            _LocalGroupClientMeasurementsTabs(
              clients: _groupClientTabsData(nfc),
              currentViewerEmail:
                  FirebaseAuth.instance.currentUser?.email ?? '',
            ),
          ],
        );
      },
    );
  }

  List<_ClientMeasurementTabData> _groupClientTabsData(_RequestNfcDetails nfc) {
    final tabs = <_ClientMeasurementTabData>[];
    final seen = <String>{};
    final viewerEmail =
        FirebaseAuth.instance.currentUser?.email?.trim().toLowerCase() ?? '';
    for (var i = 0; i < order.groupClients.length; i++) {
      final client = order.groupClients[i];
      final name = client.clientName.trim().isEmpty
          ? 'Client'
          : client.clientName.trim();
      final dedupeKey = client.clientId.trim().isNotEmpty
          ? client.clientId.trim().toLowerCase()
          : name.toLowerCase();
      if (seen.contains(dedupeKey)) continue;
      seen.add(dedupeKey);
      tabs.add(
        _ClientMeasurementTabData(
          name: name,
          clientEmail: client.clientEmail,
          nailShape: client.nailShape,
          nailLength: client.nailLength,
          leftHand: client.leftHandDimensions,
          rightHand: client.rightHandDimensions,
          nfc: nfc.groupBySlotIndex[i + 1] ?? _FingerNfcSelection.empty(),
        ),
      );
      if (tabs.length >= 16) break;
    }
    if (tabs.isEmpty) {
      tabs.add(
        _ClientMeasurementTabData(
          name: 'Client',
          clientEmail: '',
          nailShape: order.nailShape,
          nailLength: order.nailLength,
          leftHand: order.leftHandDimensions,
          rightHand: order.rightHandDimensions,
          nfc: nfc.main,
        ),
      );
    }
    final isBrandRequest =
        order.sourceCollection.trim() == 'Company_Custom_Requests';
    if (isBrandRequest && !isBrandViewer && viewerEmail.isNotEmpty) {
      final viewerTabs = tabs
          .where(
            (client) => client.clientEmail.trim().toLowerCase() == viewerEmail,
          )
          .toList(growable: false);
      if (viewerTabs.isNotEmpty) {
        return viewerTabs;
      }
      return tabs.take(1).toList(growable: false);
    }
    return tabs;
  }

  Widget _nailDimensionsRightAligned() {
    return FutureBuilder<_RequestNfcDetails>(
      future: _loadRequestNfcDetails(),
      builder: (context, snapshot) {
        final nfc = snapshot.data ?? _RequestNfcDetails.empty();
        return _nailDimensionsContent(
          leftHand: order.leftHandDimensions,
          rightHand: order.rightHandDimensions,
          nailShape: order.nailShape,
          nailLength: order.nailLength,
          nfc: nfc.main,
        );
      },
    );
  }

  Widget _nailDimensionsContent({
    required Map<String, String> leftHand,
    required Map<String, String> rightHand,
    required String nailShape,
    required String nailLength,
    required _FingerNfcSelection nfc,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            'Nail Dimensions',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              fontFamily: 'ArialBold',
              color: AppColors.blackCat,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _measurementSummaryRow(
          nailShape: _valueOrDash(nailShape),
          nailLength: _valueOrDash(_prettyLength(nailLength)),
        ),
        const SizedBox(height: 10),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final left = _dimensionHandCard('Left Hand', leftHand, nfc.left);
            final right = _dimensionHandCard(
              'Right Hand',
              rightHand,
              nfc.right,
            );
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: left),
                const SizedBox(width: 10),
                Expanded(child: right),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _measurementSummaryRow({
    required String nailShape,
    required String nailLength,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _measurementSummaryItem('Nail Shape', nailShape)),
        const SizedBox(width: 10),
        Expanded(child: _measurementSummaryItem('Nail Length', nailLength)),
      ],
    );
  }

  Widget _measurementSummaryItem(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          flex: 0,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.blackCat.withOpacity(0.70),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'Arial',
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.blackCat,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFamily: 'ArialBold',
            ),
          ),
        ),
      ],
    );
  }

  Widget _metaValueCard(String label, String value) {
    return _measurementSummaryItem(label, value);
  }

  Widget _dimensionHandCard(
    String title,
    Map<String, String> map,
    Map<String, bool> nfc,
  ) {
    String value(String key) {
      final raw = (map[key] ?? '').trim();
      return raw.isEmpty || raw == '-' ? '-' : '$raw mm';
    }

    bool showNfc(String key) {
      final raw = (map[key] ?? '').trim();
      final valueMm = double.tryParse(raw.replaceAll(RegExp(r'[^0-9.]'), ''));
      return nfc[key] == true && valueMm != null && valueMm >= 8;
    }

    Widget row(String label, String key) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                      style: TextStyle(
                        color: AppColors.blackCat,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Arial',
                      ),
                    ),
                  ),
                  if (showNfc(key)) ...[
                    const SizedBox(width: 6),
                    _nfcDimensionChip(),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              value(key),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: 'ArialBold',
                color: AppColors.blackCat,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            fontFamily: 'ArialBold',
            color: AppColors.blackCat,
          ),
        ),
        const SizedBox(height: 8),
        row('Thumb', 'thumb'),
        row('Index', 'index'),
        row('Middle', 'middle'),
        row('Ring', 'ring'),
        row('Pinky', 'pinky'),
      ],
    );
  }

  static Widget _nfcDimensionChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.balletSlippers,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.blackCatBorderLight),
      ),
      child: const Text(
        'NFC',
        style: TextStyle(
          color: AppColors.blackCat,
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          fontFamily: 'Arial',
        ),
      ),
    );
  }

  static Widget _bullet(String k, String v) {
    final cleanValue = v.trim().isEmpty ? '-' : v.trim();
    return Semantics(
      label: '$k, $cleanValue',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                color: AppColors.blackCat.withOpacity(0.75),
                fontWeight: FontWeight.w400,
                fontSize: 14,
              ),
              children: [
                TextSpan(
                  text: '$k: ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: cleanValue),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _valueOrDash(String v) => v.trim().isEmpty ? '-' : v.trim();

  String _requestArtistDisplay() {
    final raw = order.selectedArtistName.trim();
    if (raw.isEmpty) return 'N/A';
    final lower = raw.toLowerCase();
    if (lower == 'artist' ||
        lower == 'select one' ||
        lower == 'n/a' ||
        lower == '-') {
      return 'N/A';
    }
    return raw;
  }

  String _prettyLength(String raw) {
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

  String _budgetText() {
    final min = order.budgetMin;
    final max = order.budgetMax;
    if (min == null && max == null) return '-';
    if (min != null && max != null) return '\$$min - \$$max';
    if (min != null) return '\$$min';
    return '\$${max!}';
  }

  String _placedOnText() {
    final dt = order.createdAt;
    if (dt == null) return '-';
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
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

class _RequestNfcDetails {
  const _RequestNfcDetails({
    required this.main,
    required this.groupBySlotIndex,
  });

  final _FingerNfcSelection main;
  final Map<int, _FingerNfcSelection> groupBySlotIndex;

  factory _RequestNfcDetails.empty() {
    return const _RequestNfcDetails(
      main: _FingerNfcSelection.emptyConst,
      groupBySlotIndex: <int, _FingerNfcSelection>{},
    );
  }

  factory _RequestNfcDetails.fromMaps({
    required Map<String, dynamic> root,
    required Map<String, dynamic> details,
  }) {
    Map<String, dynamic> asMap(dynamic value) {
      if (value is Map<String, dynamic>) {
        return Map<String, dynamic>.from(value);
      }
      if (value is Map) {
        return value.map((key, value) => MapEntry(key.toString(), value));
      }
      return <String, dynamic>{};
    }

    final rootNailPrefs = asMap(root['nailPreferences']);
    final detailNailPrefs = asMap(details['nailPreferences']);
    final snapshot = asMap(details['clientProfileSnapshot']);
    final snapshotNailPrefs = asMap(snapshot['nailPreferences']);
    final mainDimensions = <String, dynamic>{
      ...asMap(snapshotNailPrefs['dimensions']),
      ...asMap(rootNailPrefs['dimensions']),
      ...asMap(detailNailPrefs['dimensions']),
      ...asMap(root['dimensions']),
      ...asMap(details['dimensions']),
    };

    final groupBySlot = <int, _FingerNfcSelection>{};
    final groupOrder = <String, dynamic>{
      ...asMap(root['groupOrder']),
      ...asMap(details['groupOrder']),
    };
    final rawClients = groupOrder['clients'] is List
        ? groupOrder['clients'] as List
        : (details['groupClients'] is List
              ? details['groupClients'] as List
              : (root['groupClients'] is List
                    ? root['groupClients'] as List
                    : const []));

    for (var i = 0; i < rawClients.length; i++) {
      final client = asMap(rawClients[i]);
      final draft = asMap(client['draftNails']);
      final saved = asMap(client['savedNails']);
      final nailPrefs = asMap(client['nailPreferences']);
      final dimensions = <String, dynamic>{
        ...asMap(saved['dimensions']),
        ...asMap(draft['dimensions']),
        ...asMap(nailPrefs['dimensions']),
        ...asMap(client['dimensions']),
      };
      final slotIndex = _intValue(client['slotIndex']) ?? (i + 1);
      groupBySlot[slotIndex] = _FingerNfcSelection.fromDimensions(dimensions);
    }

    return _RequestNfcDetails(
      main: _FingerNfcSelection.fromDimensions(mainDimensions),
      groupBySlotIndex: groupBySlot,
    );
  }

  static int? _intValue(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse((raw ?? '').toString().trim());
  }
}

class _FingerNfcSelection {
  const _FingerNfcSelection({required this.left, required this.right});

  static const emptyConst = _FingerNfcSelection(
    left: <String, bool>{},
    right: <String, bool>{},
  );

  final Map<String, bool> left;
  final Map<String, bool> right;

  factory _FingerNfcSelection.empty() => emptyConst;

  factory _FingerNfcSelection.fromDimensions(Map<String, dynamic> dimensions) {
    bool truthy(dynamic value) {
      if (value == true) return true;
      if (value is num) return value != 0;
      final text = (value ?? '').toString().trim().toLowerCase();
      return text == 'true' ||
          text == 'yes' ||
          text == '1' ||
          text == 'selected';
    }

    dynamic nfcValue(String key) {
      final nfc = dimensions['nfc'];
      if (nfc is Map) {
        return dimensions['${key}Nfc'] ?? nfc[key] ?? nfc['${key}Nfc'];
      }
      return dimensions['${key}Nfc'] ?? dimensions[key];
    }

    return _FingerNfcSelection(
      left: <String, bool>{
        'thumb': truthy(nfcValue('lThumb')),
        'index': truthy(nfcValue('lIndex')),
        'middle': truthy(nfcValue('lMiddle')),
        'ring': truthy(nfcValue('lRing')),
        'pinky': truthy(nfcValue('lPinky')),
      },
      right: <String, bool>{
        'thumb': truthy(nfcValue('rThumb')),
        'index': truthy(nfcValue('rIndex')),
        'middle': truthy(nfcValue('rMiddle')),
        'ring': truthy(nfcValue('rRing')),
        'pinky': truthy(nfcValue('rPinky')),
      },
    );
  }
}

class _ClientMeasurementTabData {
  const _ClientMeasurementTabData({
    required this.name,
    required this.clientEmail,
    required this.nailShape,
    required this.nailLength,
    required this.leftHand,
    required this.rightHand,
    required this.nfc,
  });

  final String name;
  final String clientEmail;
  final String nailShape;
  final String nailLength;
  final Map<String, String> leftHand;
  final Map<String, String> rightHand;
  final _FingerNfcSelection nfc;
}

class _LocalGroupClientMeasurementsTabs extends StatefulWidget {
  const _LocalGroupClientMeasurementsTabs({
    required this.clients,
    this.currentViewerEmail = '',
  });

  final List<_ClientMeasurementTabData> clients;
  final String currentViewerEmail;

  @override
  State<_LocalGroupClientMeasurementsTabs> createState() =>
      _LocalGroupClientMeasurementsTabsState();
}

class _LocalGroupClientMeasurementsTabsState
    extends State<_LocalGroupClientMeasurementsTabs> {
  int _selectedIndex = 0;

  int _viewerOwnedIndex() {
    final viewerEmail = widget.currentViewerEmail.trim().toLowerCase();
    if (viewerEmail.isEmpty) return -1;
    for (var index = 0; index < widget.clients.length; index++) {
      final clientEmail = widget.clients[index].clientEmail
          .trim()
          .toLowerCase();
      if (clientEmail.isNotEmpty && clientEmail == viewerEmail) {
        return index;
      }
    }
    return -1;
  }

  bool _isViewerOwnedTab(_ClientMeasurementTabData client) {
    final viewerEmail = widget.currentViewerEmail.trim().toLowerCase();
    final clientEmail = client.clientEmail.trim().toLowerCase();
    return viewerEmail.isNotEmpty &&
        clientEmail.isNotEmpty &&
        viewerEmail == clientEmail;
  }

  @override
  void didUpdateWidget(covariant _LocalGroupClientMeasurementsTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    final viewerIndex = _viewerOwnedIndex();
    if (viewerIndex >= 0) {
      _selectedIndex = viewerIndex;
    } else if (_selectedIndex >= widget.clients.length) {
      _selectedIndex = widget.clients.isEmpty ? 0 : widget.clients.length - 1;
    }
  }

  @override
  void initState() {
    super.initState();
    final viewerIndex = _viewerOwnedIndex();
    if (viewerIndex >= 0) {
      _selectedIndex = viewerIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.clients.isEmpty) return const SizedBox.shrink();
    final safeIndex = _selectedIndex
        .clamp(0, widget.clients.length - 1)
        .toInt();
    final selected = widget.clients[safeIndex];
    final selectedOwned = _isViewerOwnedTab(selected);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: widget.clients.asMap().entries.map((entry) {
                final selectedTab = entry.key == _selectedIndex;
                return InkWell(
                  onTap: () => setState(() => _selectedIndex = entry.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: selectedTab
                              ? AppColors.balletSlippers
                              : AppColors.blackCatBorderLight,
                          width: selectedTab ? 2 : 1,
                        ),
                      ),
                    ),
                    child: Text(
                      entry.value.name,
                      style: TextStyle(
                        color: selectedTab
                            ? AppColors.blackCat
                            : AppColors.blackCat.withOpacity(0.62),
                        fontSize: 12,
                        fontWeight: selectedTab
                            ? FontWeight.w700
                            : FontWeight.w600,
                        fontFamily: selectedTab ? 'ArialBold' : 'Arial',
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: _LocalMeasurementsBody(
              client: selected,
              showMeasurements:
                  selectedOwned || widget.currentViewerEmail.trim().isEmpty,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalMeasurementsBody extends StatelessWidget {
  const _LocalMeasurementsBody({
    required this.client,
    required this.showMeasurements,
  });

  final _ClientMeasurementTabData client;
  final bool showMeasurements;

  String _valueOrDash(String value) =>
      value.trim().isEmpty ? '-' : value.trim();

  String _prettyLength(String raw) {
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

  @override
  Widget build(BuildContext context) {
    if (!showMeasurements) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.snow,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: AppColors.blackCatBorderLight),
        ),
        child: const Text(
          'Only your own client measurements are visible here.',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _summaryRow(
          nailShape: _valueOrDash(client.nailShape),
          nailLength: _valueOrDash(_prettyLength(client.nailLength)),
        ),
        const SizedBox(height: 10),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final left = _handCard(
              'Left Hand',
              client.leftHand,
              client.nfc.left,
            );
            final right = _handCard(
              'Right Hand',
              client.rightHand,
              client.nfc.right,
            );
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: left),
                const SizedBox(width: 10),
                Expanded(child: right),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _summaryRow({required String nailShape, required String nailLength}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _summaryItem('Nail Shape', nailShape)),
        const SizedBox(width: 10),
        Expanded(child: _summaryItem('Nail Length', nailLength)),
      ],
    );
  }

  Widget _summaryItem(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          flex: 0,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.blackCat.withOpacity(0.70),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'Arial',
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.blackCat,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFamily: 'ArialBold',
            ),
          ),
        ),
      ],
    );
  }

  Widget _metaCard(String label, String value) {
    return _summaryItem(label, value);
  }

  Widget _handCard(
    String title,
    Map<String, String> map,
    Map<String, bool> nfc,
  ) {
    String value(String key) {
      final raw = (map[key] ?? '').trim();
      return raw.isEmpty || raw == '-' ? '-' : '$raw mm';
    }

    bool showNfc(String key) {
      final raw = (map[key] ?? '').trim();
      final valueMm = double.tryParse(raw.replaceAll(RegExp(r'[^0-9.]'), ''));
      return nfc[key] == true && valueMm != null && valueMm >= 8;
    }

    Widget row(String label, String key) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                      style: TextStyle(
                        color: AppColors.blackCat,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Arial',
                      ),
                    ),
                  ),
                  if (showNfc(key)) ...[const SizedBox(width: 6), _nfcChip()],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              value(key),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: 'ArialBold',
                color: AppColors.blackCat,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            fontFamily: 'ArialBold',
            color: AppColors.blackCat,
          ),
        ),
        const SizedBox(height: 8),
        row('Thumb', 'thumb'),
        row('Index', 'index'),
        row('Middle', 'middle'),
        row('Ring', 'ring'),
        row('Pinky', 'pinky'),
      ],
    );
  }

  Widget _nfcChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.balletSlippers,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.blackCatBorderLight),
      ),
      child: const Text(
        'NFC',
        style: TextStyle(
          color: AppColors.blackCat,
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          fontFamily: 'Arial',
        ),
      ),
    );
  }
}

/// ------------------------
/// Right panels
/// ------------------------
class _QrShippingCard extends StatelessWidget {
  const _QrShippingCard({
    required this.tracking,
    required this.carrierLine,
    required this.buttonText,
    required this.onTap,
  });

  final String tracking;
  final String carrierLine;
  final String buttonText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
      ),
      child: Column(
        children: [
          Container(
            height: 96,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.blackCat.withOpacity(0.04),
              borderRadius: BorderRadius.zero,
            ),
            alignment: Alignment.center,
            child: const Text(
              'QR',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            tracking,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            carrierLine,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black.withOpacity(0.6),
              fontWeight: FontWeight.w400,
              fontSize: 12,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blackCat,
                foregroundColor: AppColors.snow,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                elevation: 0,
              ),
              onPressed: onTap,
              child: Text(
                buttonText,
                style: const TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.steps});
  final List<_StepItem> steps;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: 'Progress',
      lines: steps.map((s) => '${s.done ? "✓" : "•"} ${s.label}').toList(),
    );
  }
}

class _StepItem {
  final String label;
  final bool done;
  const _StepItem(this.label, this.done);
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.lines,
    this.backgroundColor = AppColors.snow,
    this.textColor = AppColors.blackCat,
  });
  final String title;
  final List<String> lines;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(height: 8),
          ...lines.map(
            (l) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                l,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w400,
                  fontSize: 11.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.title, required this.image});
  final String title;
  final String image;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.zero,
            child: Image.asset(
              image,
              height: 92,
              width: 150,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 92,
                width: 150,
                color: Colors.black.withOpacity(0.06),
                alignment: Alignment.center,
                child: Icon(
                  Icons.image_outlined,
                  color: Colors.black.withOpacity(0.35),
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
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

class _CancelOrderResult {
  const _CancelOrderResult({required this.confirm, required this.reason});
  final bool confirm;
  final String reason;
}

class _CancelOrderDialog extends StatefulWidget {
  const _CancelOrderDialog();

  @override
  State<_CancelOrderDialog> createState() => _CancelOrderDialogState();
}

class _CancelOrderDialogState extends State<_CancelOrderDialog> {
  final TextEditingController _reasonCtrl = TextEditingController();
  String _selected = 'Change in plans';

  static const List<String> _reasons = [
    'Change in plans',
    'Budget concerns',
    'Unsatisfied with progress',
    'Other',
  ];

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          color: AppColors.snow,
          borderRadius: BorderRadius.zero,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Center(
                child: Container(
                  height: 74,
                  width: 74,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.balletSlippers,
                    border: Border.all(
                      color: AppColors.blackCat.withOpacity(0.06),
                    ),
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: 38,
                    color: AppColors.blackCat.withOpacity(0.55),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Cancel Order?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Are you certain you want to cancel this order?\nThis will alert the artist and stop any progress made so far.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.blackCat,
                    fontSize: 13,
                    height: 1.35,
                    fontFamily: 'Arial',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Reason for Cancellation',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'ArialBold',
                ),
              ),
              const SizedBox(height: 10),
              ..._reasons.map(
                (r) => RadioListTile<String>(
                  value: r,
                  groupValue: _selected,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: AppColors.blackCat,
                  title: Text(r, style: const TextStyle(fontSize: 13)),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _selected = v);
                  },
                ),
              ),
              TextField(
                controller: _reasonCtrl,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter your reason...',
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.snow,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 36,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(
                      color: AppColors.blackCat.withOpacity(0.08),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(
                      color: AppColors.blackCat.withOpacity(0.08),
                    ),
                  ),
                ),
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.3,
                  fontFamily: 'Arial',
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.blackCat.withValues(
                            alpha: 0.72,
                          ),
                          foregroundColor: AppColors.snow,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.of(context).pop(
                            const _CancelOrderResult(
                              confirm: false,
                              reason: '',
                            ),
                          );
                        },
                        child: const Text(
                          'Keep Order',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.blackCat,
                          foregroundColor: AppColors.snow,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        onPressed: () {
                          final typed = _reasonCtrl.text.trim();
                          final reason = typed.isNotEmpty ? typed : _selected;
                          Navigator.of(context).pop(
                            _CancelOrderResult(confirm: true, reason: reason),
                          );
                        },
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                        ),
                        label: const Text(
                          'Yes, Cancel Order',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
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
    );
  }
}

class _SubmittedPhotosStrip extends StatelessWidget {
  const _SubmittedPhotosStrip({
    required this.paths,
    this.fallbackOrderId = '',
    this.fallbackOrderNumber = '',
    this.sourceCollection = 'Client_Custom_Requests',
    this.enableFirestoreFallback = false,
  });
  final List<String> paths;
  final String fallbackOrderId;
  final String fallbackOrderNumber;
  final String sourceCollection;
  final bool enableFirestoreFallback;

  static List<String> _collectPhotoRefs(List<dynamic> values) {
    final out = <String>[];
    final seen = <String>{};
    void addValue(dynamic value) {
      if (value == null) return;
      if (value is String) {
        final s = value.trim();
        if (s.isNotEmpty && seen.add(s)) out.add(s);
        return;
      }
      if (value is Iterable) {
        for (final item in value) {
          addValue(item);
        }
        return;
      }
      if (value is Map) {
        final map = Map<String, dynamic>.from(value);
        const keys = <String>[
          'url',
          'downloadUrl',
          'downloadURL',
          'photoUrl',
          'imageUrl',
          'image',
          'path',
          'storagePath',
          'fullPath',
          'ref',
          'photo',
          'src',
          'uri',
        ];
        for (final key in keys) {
          if (map.containsKey(key)) addValue(map[key]);
        }
        map.forEach((k, v) {
          final key = k.toString().toLowerCase();
          if (key.contains('photo') ||
              key.contains('image') ||
              key.contains('inspiration') ||
              key.contains('preview') ||
              key.endsWith('url') ||
              key.endsWith('path')) {
            addValue(v);
          }
        });
      }
    }

    for (final value in values) {
      addValue(value);
    }
    return out;
  }

  Future<List<String>> _loadFallbackPhotos() async {
    final orderId = fallbackOrderId.trim();
    if (orderId.isEmpty) return const <String>[];
    final collection = sourceCollection.trim().isEmpty
        ? 'Client_Custom_Requests'
        : sourceCollection.trim();
    var doc = await FirebaseFirestore.instance
        .collection(collection)
        .doc(orderId)
        .get();
    if (!doc.exists) {
      final orderNo = fallbackOrderNumber.trim();
      if (orderNo.isNotEmpty) {
        final query = await FirebaseFirestore.instance
            .collection(collection)
            .where('orderNumber', isEqualTo: orderNo)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          doc = query.docs.first;
        }
      }
    }
    if (!doc.exists) return const <String>[];
    final root = doc.data() ?? const <String, dynamic>{};
    final detail = await doc.reference
        .collection('details')
        .doc('payload')
        .get();
    final details = detail.data() ?? const <String, dynamic>{};
    final payload = (details['payload'] as Map<String, dynamic>?) ?? details;
    final requestDetails =
        (payload['requestDetails'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final order =
        (payload['order'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    return _collectPhotoRefs(<dynamic>[
      payload['brandInspirationPhotos'],
      payload['inspirationPhotos'],
      payload['clientImages'],
      payload['photos'],
      payload['inspirationPhoto'],
      payload['inspirationPhotoUrl'],
      requestDetails['brandInspirationPhotos'],
      requestDetails['inspirationPhotos'],
      requestDetails['clientImages'],
      requestDetails['photos'],
      requestDetails['inspirationPhoto'],
      requestDetails['inspirationPhotoUrl'],
      requestDetails['inspirationPhotoUrls'],
      requestDetails['inspirationPhotoRefs'],
      order['brandInspirationPhotos'],
      order['inspirationPhotos'],
      order['clientImages'],
      order['photos'],
      order['inspirationPhoto'],
      order['inspirationPhotoUrl'],
      root['brandInspirationPhotos'],
      root['inspirationPhotos'],
      root['clientImages'],
      root['photos'],
      root['inspirationPhoto'],
      root['inspirationPhotoUrl'],
    ]);
  }

  void _openImagePreview(
    BuildContext context,
    String path,
    int index,
    int total,
    Widget Function(String path) imageForPath,
  ) {
    final closeFocusNode = FocusNode(debugLabel: 'closeOrderPhotoPreview');

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          if (MediaQuery.of(dialogContext).accessibleNavigation) {
            closeFocusNode.requestFocus();
          }
        });

        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(8),
          child: Stack(
            children: [
              Positioned.fill(
                child: Semantics(
                  image: true,
                  label:
                      'Order photo ${index + 1} of $total preview. Pinch to zoom.',
                  child: ExcludeSemantics(
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4,
                      child: Center(child: imageForPath(path)),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Focus(
                  focusNode: closeFocusNode,
                  child: Semantics(
                    button: true,
                    label: 'Close image preview',
                    hint: 'Double tap to close',
                    onTap: () => Navigator.of(dialogContext).pop(),
                    child: ExcludeSemantics(
                      child: IconButton(
                        tooltip: 'Close image preview',
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.snow,
                          size: 34,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      if (closeFocusNode.hasFocus) {
        closeFocusNode.unfocus();
      }
      closeFocusNode.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final renderable = paths
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList(growable: false);

    if (renderable.isEmpty) {
      if (enableFirestoreFallback && fallbackOrderId.trim().isNotEmpty) {
        return FutureBuilder<List<String>>(
          future: _loadFallbackPhotos(),
          builder: (context, snap) {
            final fetched = (snap.data ?? const <String>[])
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList(growable: false);
            if (fetched.isNotEmpty) {
              return _SubmittedPhotosStrip(paths: fetched);
            }
            return Text(
              'No photos were uploaded by client.',
              style: TextStyle(
                color: Colors.black.withOpacity(0.62),
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            );
          },
        );
      }
      return Text(
        'No photos were uploaded by client.',
        style: TextStyle(
          color: Colors.black.withOpacity(0.62),
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      );
    }

    Future<bool> canRenderPath(String path) async {
      String p = path.trim();
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

      final isNetwork =
          p.startsWith('http://') ||
          p.startsWith('https://') ||
          p.startsWith('blob:') ||
          p.startsWith('content://');
      final isDataImage = p.startsWith('data:image/');
      final isAsset = p.startsWith('assets/');
      final isFileUri = p.startsWith('file://');
      final isFilePath = !kIsWeb && (p.startsWith('/') || p.contains(':\\'));

      try {
        if (isDataImage) {
          final comma = p.indexOf(',');
          if (comma <= 0) return false;
          final b64 = p.substring(comma + 1).trim();
          base64Decode(b64);
          return true;
        }
        if (isNetwork) {
          final imageProvider = NetworkImage(p);
          await precacheImage(imageProvider, context);
          return true;
        }
        if (isAsset) {
          final imageProvider = AssetImage(p);
          await precacheImage(imageProvider, context);
          return true;
        }
        if (isFileUri || isFilePath) {
          final localPath = isFileUri ? p.replaceFirst('file://', '') : p;
          final imageProvider = FileImage(File(localPath));
          await precacheImage(imageProvider, context);
          return true;
        }

        final resolved = await StorageUrlResolver.resolve(p);
        if ((resolved ?? '').trim().isEmpty) return false;
        final imageProvider = NetworkImage(resolved!.trim());
        await precacheImage(imageProvider, context);
        return true;
      } catch (_) {
        return false;
      }
    }

    Widget imageForPath(String path) {
      String p = path.trim();
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

      Widget broken() => Icon(
        Icons.broken_image_outlined,
        color: AppColors.blackCat.withOpacity(0.35),
      );

      final isNetwork =
          p.startsWith('http://') ||
          p.startsWith('https://') ||
          p.startsWith('blob:') ||
          p.startsWith('content://');
      final isDataImage = p.startsWith('data:image/');
      final isAsset = p.startsWith('assets/');
      final isFileUri = p.startsWith('file://');
      final isFilePath = !kIsWeb && (p.startsWith('/') || p.contains(':\\'));

      if (isDataImage) {
        try {
          final comma = p.indexOf(',');
          if (comma > 0) {
            final b64 = p.substring(comma + 1).trim();
            final bytes = base64Decode(b64);
            return Image.memory(
              bytes,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => broken(),
            );
          }
        } catch (_) {}
        return broken();
      }
      if (isNetwork) {
        return Image.network(
          p,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => broken(),
        );
      }
      if (isAsset) {
        return Image.asset(
          p,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => broken(),
        );
      }
      if (isFileUri || isFilePath) {
        final localPath = isFileUri ? p.replaceFirst('file://', '') : p;
        return Image.file(
          File(localPath),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => broken(),
        );
      }

      return FutureBuilder<String>(
        future: StorageUrlResolver.resolve(p).then((v) => v ?? ''),
        builder: (_, snap) {
          final url = (snap.data ?? '').trim();
          if (url.isEmpty) return broken();
          return Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => broken(),
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final tileSize = ((constraints.maxWidth - 24) / 4).clamp(72.0, 110.0);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: renderable.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            mainAxisExtent: tileSize,
          ),
          itemBuilder: (context, index) {
            final path = renderable[index];
            return FutureBuilder<bool>(
              future: canRenderPath(path),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return SizedBox(width: tileSize, height: tileSize);
                }
                if (snap.data != true) return const SizedBox.shrink();
                return Semantics(
                  button: true,
                  label: 'Order photo ${index + 1} of ${renderable.length}',
                  hint: 'Double tap to open image preview',
                  onTap: () => _openImagePreview(
                    context,
                    path,
                    index,
                    renderable.length,
                    imageForPath,
                  ),
                  child: ExcludeSemantics(
                    child: ClipRRect(
                      borderRadius: BorderRadius.zero,
                      child: InkWell(
                        onTap: () => _openImagePreview(
                          context,
                          path,
                          index,
                          renderable.length,
                          imageForPath,
                        ),
                        child: Container(
                          width: tileSize,
                          height: tileSize,
                          color: AppColors.blackCat.withOpacity(0.04),
                          child: imageForPath(path),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

enum _ReviewChannel { inApp, email, text, both }

class _ClientContactPrefs {
  const _ClientContactPrefs({
    required this.name,
    required this.email,
    required this.phone,
    required this.channel,
  });

  final String name;
  final String email;
  final String phone;
  final _ReviewChannel channel;
}

class _DeliveredReviewPanel extends StatefulWidget {
  const _DeliveredReviewPanel({required this.order});
  final _OrderSafe order;

  @override
  State<_DeliveredReviewPanel> createState() => _DeliveredReviewPanelState();
}

class _DeliveredReviewPanelState extends State<_DeliveredReviewPanel> {
  late final TextEditingController _commentCtrl;
  late final TextEditingController _customTipCtrl;
  late double _rating;
  bool _saving = false;
  bool _promptProcessed = false;
  String _promptChannelLabel = '';
  DateTime? _submittedAt;
  int? _selectedTipPercent;
  double _submittedTipAmount = 0;
  String _submittedComment = '';

  String _textOrEmpty(Object? raw) => (raw ?? '').toString().trim();
  String get _orderCollection {
    final raw = widget.order.sourceCollection.trim();
    return raw.isEmpty ? 'Client_Custom_Requests' : raw;
  }

  @override
  void initState() {
    super.initState();
    _rating = (widget.order.clientRating ?? 0).clamp(0, 5).toDouble();
    _commentCtrl = TextEditingController(text: widget.order.clientReviewText);
    _submittedComment = widget.order.clientReviewText.trim();
    _customTipCtrl = TextEditingController();
    _submittedAt = widget.order.clientReviewSubmittedAt;
    _loadLatestReviewFromDb();
    _ensureReviewPromptSent();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _customTipCtrl.dispose();
    super.dispose();
  }

  String get _reviewDeepLink =>
      'jnt://orders/review?orderId=${widget.order.id}&action=review_tip';

  double get _tipBaseAmount {
    final accepted = widget.order.artistAcceptedAmount;
    if (accepted != null && accepted > 0) return accepted.toDouble();
    final budgetMax = widget.order.budgetMax;
    if (budgetMax != null && budgetMax > 0) return budgetMax.toDouble();
    final budgetMin = widget.order.budgetMin;
    if (budgetMin != null && budgetMin > 0) return budgetMin.toDouble();
    return 0;
  }

  double get _customTipAmount {
    final parsed = double.tryParse(_customTipCtrl.text.trim()) ?? 0;
    if (parsed.isNaN || parsed.isInfinite) return 0;
    return parsed < 0 ? 0 : parsed;
  }

  double get _calculatedTip {
    if (_selectedTipPercent != null) {
      return (_tipBaseAmount * _selectedTipPercent!) / 100.0;
    }
    return _customTipAmount;
  }

  Future<void> _ensureReviewPromptSent() async {
    try {
      if ((widget.order.clientRating ?? 0) > 0 || _submittedAt != null) {
        if (!mounted) return;
        setState(() => _promptProcessed = true);
        return;
      }
      final ref = FirebaseFirestore.instance
          .collection(_orderCollection)
          .doc(widget.order.id);
      final snap = await ref.get();
      final data = snap.data() ?? const <String, dynamic>{};
      if (data['clientReviewPromptSentAt'] != null) {
        if (!mounted) return;
        setState(() {
          _promptProcessed = true;
          _promptChannelLabel = _textOrEmpty(data['clientReviewPromptChannel']);
        });
        return;
      }

      final prefs = await _loadClientContactPrefs();
      final channelLabel = await _sendPromptByPreference(prefs);
      await ref.set({
        'clientReviewPromptSentAt': FieldValue.serverTimestamp(),
        'clientReviewPromptChannel': channelLabel,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await ref.collection('details').doc('payload').set({
        'clientReviewPrompt': {
          'sentAt': FieldValue.serverTimestamp(),
          'channel': channelLabel,
        },
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _promptProcessed = true;
        _promptChannelLabel = channelLabel;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _promptProcessed = true);
    }
  }

  Future<_ClientContactPrefs> _loadClientContactPrefs() async {
    final auth = FirebaseAuth.instance.currentUser;
    final email = (auth?.email ?? '').trim().toLowerCase();
    final uid = (auth?.uid ?? '').trim();
    final db = FirebaseFirestore.instance;

    DocumentSnapshot<Map<String, dynamic>>? found;
    if (uid.isNotEmpty) {
      final c = await db.collection('client').doc(uid).get();
      if (c.exists) {
        found = c;
      } else {
        final ca = await db.collection('client_artist').doc(uid).get();
        if (ca.exists) found = ca;
      }
    }
    if (found == null && email.isNotEmpty) {
      final q1 = await db
          .collection('client')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (q1.docs.isNotEmpty) {
        found = q1.docs.first;
      } else {
        final q2 = await db
            .collection('client_artist')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (q2.docs.isNotEmpty) found = q2.docs.first;
      }
    }

    final data = found?.data() ?? const <String, dynamic>{};
    final profile =
        (data['profile'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final prefs =
        (data['preferences'] as Map<String, dynamic>?) ??
        (profile['preferences'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};

    String pick(List<Object?> values) {
      for (final value in values) {
        final text = (value ?? '').toString().trim();
        if (text.isNotEmpty) return text;
      }
      return '';
    }

    final phone = pick([
      data['phone'],
      profile['phone'],
      data['contactPhone'],
      prefs['phone'],
    ]);
    final channelRaw = pick([
      data['communicationPreference'],
      data['preferredCommunication'],
      data['communicationChannel'],
      profile['communicationPreference'],
      profile['preferredCommunication'],
      prefs['communicationPreference'],
      prefs['preferredCommunication'],
      prefs['channel'],
    ]);

    return _ClientContactPrefs(
      name: pick([
        data['name'],
        data['displayName'],
        profile['name'],
        profile['displayName'],
      ]),
      email: pick([email, data['email'], profile['email']]).toLowerCase(),
      phone: phone,
      channel: _normalizeReviewChannel(channelRaw),
    );
  }

  _ReviewChannel _normalizeReviewChannel(String raw) {
    final v = raw.trim().toLowerCase();
    if (v.contains('both') || v.contains('all')) return _ReviewChannel.both;
    final hasEmail = v.contains('email');
    final hasText = v.contains('sms') || v.contains('text');
    if (hasEmail && hasText) return _ReviewChannel.both;
    if (hasText) return _ReviewChannel.text;
    if (hasEmail) return _ReviewChannel.email;
    if (v.contains('inapp') || v.contains('in_app')) {
      return _ReviewChannel.inApp;
    }
    return _ReviewChannel.email;
  }

  Future<String> _sendPromptByPreference(_ClientContactPrefs prefs) async {
    final channels = <String>{'in-app'};
    final deepLink = _reviewDeepLink;
    final body =
        'Your order has been delivered. Please leave a quick review and tip in the app.';
    final clientName = prefs.name.trim().isEmpty ? 'there' : prefs.name.trim();
    final orderId = widget.order.id;
    final artworkTitle = widget.order.subtitle.trim().isNotEmpty
        ? widget.order.subtitle.trim()
        : (widget.order.title.trim().isNotEmpty
              ? widget.order.title.trim()
              : 'Custom Artwork');
    final artistName = widget.order.artistName.trim().isNotEmpty
        ? widget.order.artistName.trim()
        : 'Your Artist';
    final deliveredOn = _formatDeliveryDate(widget.order.deliveredAt);
    final orderLink = 'jnt://orders/details?orderId=${widget.order.id}';
    final reviewLink = '$deepLink&target=review';
    final tipLink = '$deepLink&target=tip';
    final emailText =
        'Hi $clientName,\n\n'
        'Your custom artwork is ready! Your order has been successfully delivered.\n\n'
        'Order Summary\n'
        'Order ID: $orderId\n'
        'Artwork: $artworkTitle\n'
        'Artist: $artistName\n'
        'Delivered On: $deliveredOn\n\n'
        'View Your Artwork\n'
        'Click below to view or download your artwork:\n'
        '$orderLink\n\n'
        'Leave a Review\n'
        'Tell us about your experience and help the artist grow:\n'
        '$reviewLink\n\n'
        'Add a Tip (Optional)\n'
        'Loved the work? You can support your artist with a tip:\n'
        '$tipLink\n\n'
        'If you have any questions or need help, simply reply to this email.\n\n'
        'Thank you for choosing JNT!\n\n'
        'Best regards,\n'
        'Team JNT\n\n'
        'Support: support@jnt.com';
    if (prefs.email.isNotEmpty) {
      await NotificationsService.createUserNotification(
        receiverEmail: prefs.email,
        title: 'Review & Tip Your Artist',
        body: body,
        type: 'delivered_review_prompt',
        orderId: widget.order.id,
        sourceCollection: _orderCollection,
        extra: <String, dynamic>{'deepLink': deepLink, 'action': 'review_tip'},
      );
    }

    if ((prefs.channel == _ReviewChannel.email ||
            prefs.channel == _ReviewChannel.both) &&
        prefs.email.isNotEmpty) {
      await NotificationsService.queueEmail(
        to: prefs.email,
        subject: 'Your order has been delivered',
        text: emailText,
      );
      channels.add('email');
    }

    if ((prefs.channel == _ReviewChannel.text ||
            prefs.channel == _ReviewChannel.both) &&
        prefs.phone.trim().isNotEmpty) {
      await NotificationsService.queueSms(
        to: prefs.phone.trim(),
        text:
            'JNT: Your order was delivered. Open the app to leave your review and tip.',
      );
      channels.add('text');
    }

    return channels.join(', ');
  }

  String _formatDeliveryDate(DateTime? value) {
    if (value == null) return '-';
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
    return '${months[value.month - 1]} ${value.day}, ${value.year}';
  }

  double? _asDouble(Object? raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse((raw ?? '').toString().trim());
  }

  int _asNonNegativeInt(Object? raw) {
    if (raw is num) return raw.round().clamp(0, 1000000000);
    final parsed = int.tryParse((raw ?? '').toString().trim());
    if (parsed == null) return 0;
    return parsed.clamp(0, 1000000000);
  }

  Future<DocumentReference<Map<String, dynamic>>?> _resolveArtistDocRef(
    String artistEmail,
  ) async {
    final email = artistEmail.trim().toLowerCase();
    if (email.isEmpty) return null;
    final db = FirebaseFirestore.instance;

    for (final collection in const <String>['artist', 'client_artist']) {
      final query = await db
          .collection(collection)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) return query.docs.first.reference;
    }
    return null;
  }

  Future<bool> _submitReview() async {
    if (_rating <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating.')),
      );
      return false;
    }
    setState(() => _saving = true);
    try {
      Future<void> bestEffort(Future<void> Function() action) async {
        try {
          await action();
        } catch (_) {}
      }

      final comment = _commentCtrl.text.trim();
      final tipAmount = _calculatedTip;
      final tipPercent = _selectedTipPercent;
      final customTipAmount = _selectedTipPercent == null
          ? _customTipAmount
          : 0;
      final db = FirebaseFirestore.instance;
      final ref = db.collection(_orderCollection).doc(widget.order.id);
      final artistEmail = widget.order.acceptedByArtistEmail
          .trim()
          .toLowerCase();
      final artistRef = await _resolveArtistDocRef(artistEmail);
      double? previousRatingValue;

      await db.runTransaction((tx) async {
        final orderSnap = await tx.get(ref);
        final orderData = orderSnap.data() ?? const <String, dynamic>{};
        final prevRating =
            _asDouble(orderData['clientRating']) ??
            _asDouble(
              (orderData['clientReview'] as Map<String, dynamic>?)?['rating'],
            );
        previousRatingValue = prevRating;

        tx.set(ref, {
          'clientRating': _rating,
          'clientReviewText': comment,
          'clientReviewSubmittedAt': FieldValue.serverTimestamp(),
          'clientTipAmount': tipAmount,
          'clientTipPercent': tipPercent,
          'clientTipCustomAmount': customTipAmount,
          'clientTipSubmittedAt': tipAmount > 0
              ? FieldValue.serverTimestamp()
              : null,
          'updatedAt': FieldValue.serverTimestamp(),
          'clientReview': {
            'rating': _rating,
            'comment': comment,
            'submittedAt': FieldValue.serverTimestamp(),
          },
          'clientTip': {
            'amount': tipAmount,
            'percent': tipPercent,
            'customAmount': customTipAmount,
            'fundingSource': 'bank_account',
            'submittedAt': tipAmount > 0 ? FieldValue.serverTimestamp() : null,
          },
        }, SetOptions(merge: true));
      });

      await ref.collection('details').doc('payload').set({
        'clientReview': {
          'rating': _rating,
          'comment': comment,
          'submittedAt': FieldValue.serverTimestamp(),
        },
        'clientTip': {
          'amount': tipAmount,
          'percent': tipPercent,
          'customAmount': customTipAmount,
          'fundingSource': 'bank_account',
          'submittedAt': tipAmount > 0 ? FieldValue.serverTimestamp() : null,
        },
      }, SetOptions(merge: true));

      if (artistRef != null) {
        await bestEffort(() async {
          final artistSnap = await artistRef.get();
          final artistData = artistSnap.data() ?? const <String, dynamic>{};
          final stats =
              (artistData['stats'] as Map<String, dynamic>?) ??
              const <String, dynamic>{};
          final currentCount = _asNonNegativeInt(
            stats['reviewCount'] ??
                stats['reviews'] ??
                artistData['reviewCount'] ??
                artistData['reviews'] ??
                artistData['panel_reviews'],
          );
          final currentRating =
              _asDouble(
                stats['rating'] ??
                    stats['averageRating'] ??
                    artistData['rating'] ??
                    artistData['averageRating'] ??
                    artistData['panel_rating'],
              ) ??
              0.0;
          final hadPrevious = (previousRatingValue ?? 0) > 0;
          final safeCount = currentCount <= 0
              ? (hadPrevious ? 1 : 0)
              : currentCount;
          final nextCount = hadPrevious ? safeCount : (safeCount + 1);
          final nextRating = currentRating >= _rating ? currentRating : _rating;

          await artistRef.set({
            'stats': {
              'rating': nextRating,
              'averageRating': nextRating,
              'reviewCount': nextCount,
              'reviews': nextCount,
            },
            'rating': nextRating,
            'averageRating': nextRating,
            'reviewCount': nextCount,
            'reviews': nextCount,
            'panel_rating': nextRating,
            'panel_reviews': nextCount,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        });
      }

      if (tipAmount > 0) {
        await bestEffort(() async {
          await FirebaseFirestore.instance.collection('tip_payout_queue').add({
            'orderId': widget.order.id,
            'orderNumber': widget.order.orderNumber,
            'sourceCollection': _orderCollection,
            'artistEmail': artistEmail,
            'artistName': widget.order.artistName,
            'clientEmail': (FirebaseAuth.instance.currentUser?.email ?? '')
                .trim()
                .toLowerCase(),
            'tipAmount': tipAmount,
            'tipPercent': tipPercent,
            'customTipAmount': customTipAmount,
            'fundingSource': 'bank_account',
            'status': 'queued',
            'createdAt': FieldValue.serverTimestamp(),
          });
        });
      }
      if (artistEmail.isNotEmpty) {
        await bestEffort(() async {
          await NotificationsService.createUserNotification(
            receiverEmail: artistEmail,
            title: 'New Client Review',
            body:
                'A client left a ${_rating.toStringAsFixed(1)} star review on a delivered order.',
            type: 'client_review_submitted',
            orderId: widget.order.id,
            sourceCollection: _orderCollection,
          );
        });
        if (tipAmount > 0) {
          await bestEffort(() async {
            await NotificationsService.createUserNotification(
              receiverEmail: artistEmail,
              title: 'New Client Tip',
              body:
                  'A client sent you a tip of \$${tipAmount.toStringAsFixed(2)} on a delivered order.',
              type: 'client_tip_submitted',
              orderId: widget.order.id,
              sourceCollection: _orderCollection,
            );
          });
        }
      }

      await bestEffort(() async {
        await NotificationsService.notifyAdmins(
          title: 'Client Review Submitted',
          body:
              'Client submitted a ${_rating.toStringAsFixed(1)} star review for delivered order ${widget.order.id} (Artist: ${widget.order.artistName}).',
          type: 'admin_client_review_submitted',
          orderId: widget.order.id,
          orderNumber: widget.order.id,
          sourceCollection: _orderCollection,
          extra: <String, dynamic>{'rating': _rating, 'tipAmount': tipAmount},
        );
      });

      final clientEmail = (FirebaseAuth.instance.currentUser?.email ?? '')
          .trim()
          .toLowerCase();
      if (clientEmail.isNotEmpty) {
        await bestEffort(() async {
          await NotificationsService.createUserNotification(
            receiverEmail: clientEmail,
            title: 'Order Completed',
            body:
                'You completed your order review successfully. Thank you for your feedback.',
            type: 'client_order_completed',
            orderId: widget.order.id,
            sourceCollection: _orderCollection,
          );
        });
      }

      if (!mounted) return false;
      setState(() {
        _submittedAt = DateTime.now();
        _submittedTipAmount = tipAmount;
        _submittedComment = comment;
      });
      _loadLatestReviewFromDb();
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to submit review: $e')));
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _loadLatestReviewFromDb() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection(_orderCollection)
          .doc(widget.order.id)
          .get();
      final data = snap.data() ?? const <String, dynamic>{};
      final review =
          (data['clientReview'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final tip =
          (data['clientTip'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final submittedAtRaw =
          data['clientReviewSubmittedAt'] ?? review['submittedAt'];
      DateTime? submittedAt;
      if (submittedAtRaw is Timestamp) submittedAt = submittedAtRaw.toDate();

      final latestRating =
          _asDouble(data['clientRating']) ??
          _asDouble(review['rating']) ??
          _rating;
      final latestComment =
          (data['clientReviewText'] ?? review['comment'] ?? '')
              .toString()
              .trim();
      final latestTipAmount =
          _asDouble(data['clientTipAmount']) ?? _asDouble(tip['amount']) ?? 0;
      final latestTipPercentRaw = data['clientTipPercent'] ?? tip['percent'];
      final latestTipPercent = latestTipPercentRaw is num
          ? latestTipPercentRaw.toInt()
          : int.tryParse((latestTipPercentRaw ?? '').toString().trim());

      if (!mounted) return;
      setState(() {
        _rating = latestRating.clamp(0, 5).toDouble();
        _submittedComment = latestComment;
        _submittedTipAmount = latestTipAmount < 0 ? 0 : latestTipAmount;
        _selectedTipPercent = latestTipPercent;
        _submittedAt = submittedAt ?? _submittedAt;
      });
    } catch (_) {}
  }

  Widget _tipOptionChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.zero,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.blackCat : AppColors.snow,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: AppColors.blackCatLight),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.snow : AppColors.blackCat,
          ),
        ),
      ),
    );
  }

  Future<void> _openReviewTipModal() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            Widget star(int index) {
              final selected = _rating >= index;
              return IconButton(
                onPressed: () {
                  setState(() => _rating = index.toDouble());
                  modalSetState(() {});
                },
                icon: Icon(
                  selected ? Icons.star_rounded : Icons.star_border_rounded,
                  color: selected ? const Color(0xFFFFB000) : Colors.black54,
                  size: 26,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 2),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              );
            }

            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final calculatedTip = _calculatedTip;

            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.snow,
                  borderRadius: BorderRadius.zero,
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Review & Tip Your Artist',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Rate your delivered order, leave comments, and add an optional tip.',
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.62),
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text(
                              'Artist Review Rating',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ...List<Widget>.generate(5, (i) => star(i + 1)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _commentCtrl,
                          minLines: 3,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'Write a quick review (optional)',
                            isDense: true,
                            filled: true,
                            fillColor: AppColors.snow,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                color: AppColors.blackCat.withOpacity(0.08),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                color: AppColors.blackCat.withOpacity(0.08),
                              ),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                color: AppColors.blackCat,
                                width: 1.4,
                              ),
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.3,
                            fontFamily: 'Arial',
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Tip (optional)',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _tipOptionChip(
                              label: '5%',
                              selected: _selectedTipPercent == 5,
                              onTap: () {
                                setState(() => _selectedTipPercent = 5);
                                modalSetState(() {});
                              },
                            ),
                            _tipOptionChip(
                              label: '10%',
                              selected: _selectedTipPercent == 10,
                              onTap: () {
                                setState(() => _selectedTipPercent = 10);
                                modalSetState(() {});
                              },
                            ),
                            _tipOptionChip(
                              label: '15%',
                              selected: _selectedTipPercent == 15,
                              onTap: () {
                                setState(() => _selectedTipPercent = 15);
                                modalSetState(() {});
                              },
                            ),
                            _tipOptionChip(
                              label: '20%',
                              selected: _selectedTipPercent == 20,
                              onTap: () {
                                setState(() => _selectedTipPercent = 20);
                                modalSetState(() {});
                              },
                            ),
                            _tipOptionChip(
                              label: 'Custom',
                              selected: _selectedTipPercent == null,
                              onTap: () {
                                setState(() => _selectedTipPercent = null);
                                modalSetState(() {});
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_selectedTipPercent == null)
                          TextField(
                            controller: _customTipCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) => modalSetState(() {}),
                            decoration: InputDecoration(
                              hintText: 'Custom tip amount (\$)',
                              isDense: true,
                              filled: true,
                              fillColor: AppColors.snow,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.zero,
                                borderSide: BorderSide(
                                  color: AppColors.blackCat.withOpacity(0.08),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.zero,
                                borderSide: BorderSide(
                                  color: AppColors.blackCat.withOpacity(0.08),
                                ),
                              ),
                              focusedBorder: const OutlineInputBorder(
                                borderRadius: BorderRadius.zero,
                                borderSide: BorderSide(
                                  color: AppColors.blackCat,
                                  width: 1.4,
                                ),
                              ),
                            ),
                            style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.6,
                              fontFamily: 'Arial',
                            ),
                          ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F0FA),
                            borderRadius: BorderRadius.zero,
                          ),
                          child: Text(
                            'Tip total: \$${calculatedTip.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.blackCat,
                              foregroundColor: AppColors.snow,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                              elevation: 0,
                            ),
                            onPressed: _saving
                                ? null
                                : () async {
                                    final success = await _submitReview();
                                    if (success) {
                                      final localNav = Navigator.of(
                                        sheetContext,
                                      );
                                      if (localNav.canPop()) {
                                        localNav.pop();
                                      } else {
                                        Navigator.of(
                                          sheetContext,
                                          rootNavigator: true,
                                        ).pop();
                                      }
                                    }
                                  },
                            child: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _submittedAt == null
                                        ? 'Submit Review & Tip'
                                        : 'Update Review & Tip',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Delivered',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          'Delivered successfully. Add an Artist Review Rating and optional tip (charged from your bank account).',
          style: TextStyle(
            color: Colors.black.withOpacity(0.62),
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
        if (_submittedAt == null &&
            _rating <= 0 &&
            _promptProcessed &&
            _promptChannelLabel.isNotEmpty) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Text(
              'Review prompt sent via: $_promptChannelLabel',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        if (_submittedAt != null || _rating > 0) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F0FA),
              borderRadius: BorderRadius.zero,
            ),
            child: Text(
              'Your Review: ${_rating.toStringAsFixed(1)}★'
              '${_submittedComment.isEmpty ? '' : ' • $_submittedComment'}'
              '${_submittedTipAmount > 0 ? ' • Tip \$${_submittedTipAmount.toStringAsFixed(2)}' : ''}',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Center(
          child: SizedBox(
            height: 42,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blackCat,
                foregroundColor: AppColors.snow,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                elevation: 0,
              ),
              onPressed: _openReviewTipModal,
              child: Text(
                _submittedAt == null
                    ? 'Rate & Tip Artist'
                    : 'Edit Review & Tip',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// ------------------------
/// DELIVERED ORDER DETAILS
/// ------------------------
class _AcceptedArtistMeta {
  const _AcceptedArtistMeta({
    this.name = '',
    this.profileImage = '',
    this.city = '',
    this.state = '',
    this.rating,
  });

  final String name;
  final String profileImage;
  final String city;
  final String state;
  final double? rating;
}

class DeliveredOrderDetailsPage extends StatelessWidget {
  const DeliveredOrderDetailsPage({
    super.key,
    required this.order,
    this.isBrandViewer = false,
  });
  final dynamic order;
  final bool isBrandViewer;

  @override
  Widget build(BuildContext context) {
    final o = _OrderSafe.from(order);

    return _BaseOrderDetails(
      title: 'Order Details',
      statusPillText: 'Delivered',
      statusPillColor: AppColors.balletSlippers,
      statusPillIcon: Icons.check_circle_rounded,
      statusPillIconColor: const Color(0xFF2E8B57),
      order: o,
      isBrandViewer: isBrandViewer,
      rightPanel: _DeliveredReviewPanel(order: o),
    );
  }
}

/// ------------------------
/// EXPIRED ORDER DETAILS
/// ------------------------
class ExpiredOrderDetailsPage extends StatelessWidget {
  const ExpiredOrderDetailsPage({
    super.key,
    required this.order,
    this.isBrandViewer = false,
    this.onChat,
    this.onResubmit,
  });
  final dynamic order;
  final bool isBrandViewer;
  final VoidCallback? onChat;
  final Future<void> Function()? onResubmit;

  @override
  Widget build(BuildContext context) {
    final o = _OrderSafe.from(order);

    return _BaseOrderDetails(
      title: 'Order Details',
      statusPillText: 'Expired',
      statusPillColor: AppColors.balletSlippers,
      statusPillIcon: Icons.warning_rounded,
      statusPillIconColor: const Color(0xFFB65A1E),
      order: o,
      isBrandViewer: isBrandViewer,
      showRightPanel: false,
      rightPanel: _InfoCard(
        title: 'Expired',
        lines: const [
          'This order expired.',
          'You can place a new request anytime.',
        ],
        backgroundColor: AppColors.balletSlippers,
        textColor: AppColors.blackCat,
      ),
      onExpiredChat: onChat,
      onExpiredResubmit: onResubmit,
      onCancelledChat: onChat,
      onCancelledResubmit: onResubmit,
    );
  }
}

/// ------------------------
/// CANCELLED ORDER DETAILS
/// ------------------------
class CancelledOrderDetailsPage extends StatelessWidget {
  const CancelledOrderDetailsPage({
    super.key,
    required this.order,
    this.isBrandViewer = false,
    this.onChat,
    this.onResubmit,
  });
  final dynamic order;
  final bool isBrandViewer;
  final VoidCallback? onChat;
  final Future<void> Function()? onResubmit;

  @override
  Widget build(BuildContext context) {
    final o = _OrderSafe.from(order);

    return _BaseOrderDetails(
      title: 'Order Details',
      statusPillText: 'Cancelled',
      statusPillColor: AppColors.balletSlippers,
      statusPillIcon: Icons.cancel_rounded,
      statusPillIconColor: const Color(0xFF6B6B6B),
      order: o,
      isBrandViewer: isBrandViewer,
      showRightPanel: false,
      rightPanel: const SizedBox.shrink(),
      onCancelledChat: onChat,
      onCancelledResubmit: onResubmit,
    );
  }
}
