import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';
import '../services/notifications_service.dart';
import 'request_chat_page.dart';
import 'track_order_page.dart';

/// If you already have this model elsewhere, you can delete this class
/// and import the correct model file instead.
/// But to keep this file self-contained + compile, we accept `dynamic order`.
/// (We only read simple fields with fallback.)
class _OrderSafe {
  final String id;
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
    required this.id,
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

    return _OrderSafe(
      id: s(o?.id, 'order'),
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
        detailMap?['brandInspirationPhotos'],
        detailMap?['inspirationPhotos'],
        detailMap?['clientImages'],
        detailMap?['photos'],
        detailMap?['inspirationPhoto'],
        detailMap?['inspirationPhotoUrl'],
        detailMap?['inspirationPhotoUrls'],
        detailMap?['inspirationPhotoRefs'],
        detailMap?['previewImage'],
        detailMap?['previewImageAsset'],
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
    Map<String, dynamic> asMap(dynamic input) {
      if (input is Map<String, dynamic>)
        return Map<String, dynamic>.from(input);
      if (input is Map) {
        return input.map((key, value) => MapEntry(key.toString(), value));
      }
      return const <String, dynamic>{};
    }

    final source = asMap(value);
    if (source.isEmpty) return const <String, String>{};
    final nested = asMap(source['dimensions']);
    final map = nested.isNotEmpty ? nested : source;

    String readAny(List<String> keys) {
      for (final key in keys) {
        final raw = map[key];
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

    Map<String, dynamic> asMap(dynamic input) {
      if (input is Map<String, dynamic>)
        return Map<String, dynamic>.from(input);
      if (input is Map) {
        return input.map((key, value) => MapEntry(key.toString(), value));
      }
      return const <String, dynamic>{};
    }

    Map<String, String> dimsFrom(dynamic source, {required bool left}) {
      final map = asMap(source);
      if (map.isEmpty) return const <String, String>{};
      String dim(dynamic raw) {
        final text = (raw ?? '').toString().trim();
        return text.isEmpty ? '-' : text;
      }

      String pick(String preferred, String fallback) =>
          dim(map[preferred] ?? map[fallback]);
      if (left) {
        return <String, String>{
          'thumb': pick('lThumb', 'thumb'),
          'index': pick('lIndex', 'index'),
          'middle': pick('lMiddle', 'middle'),
          'ring': pick('lRing', 'ring'),
          'pinky': pick('lPinky', 'pinky'),
        };
      }
      return <String, String>{
        'thumb': pick('rThumb', 'thumb'),
        'index': pick('rIndex', 'index'),
        'middle': pick('rMiddle', 'middle'),
        'ring': pick('rRing', 'ring'),
        'pinky': pick('rPinky', 'pinky'),
      };
    }

    for (final entry in value) {
      if (entry is _OrderGroupClient) {
        items.add(entry);
        continue;
      }
      if (entry is Map) {
        final map = asMap(entry);
        final savedNails = asMap(map['savedNails']);
        final draftNails = asMap(map['draftNails']);
        final nailPreferences = asMap(map['nailPreferences']);
        final nailSource = savedNails.isNotEmpty
            ? savedNails
            : (draftNails.isNotEmpty ? draftNails : nailPreferences);
        items.add(
          _OrderGroupClient(
            clientId: s(map['clientId']),
            clientName: s(map['clientName']),
            clientEmail: s(map['clientEmail']),
            responseStatus: s(
              map['responseStatus'] ??
                  map['clientResponseStatus'] ??
                  map['status'],
            ),
            nailShape: s(nailSource['shape'] ?? map['nailShape']),
            nailLength: s(nailSource['length'] ?? map['nailLength']),
            leftHandDimensions: dimsFrom(
              map['leftHandDimensions'] ??
                  nailSource['leftHandDimensions'] ??
                  nailSource['dimensions'] ??
                  map['dimensions'],
              left: true,
            ),
            rightHandDimensions: dimsFrom(
              map['rightHandDimensions'] ??
                  nailSource['rightHandDimensions'] ??
                  nailSource['dimensions'] ??
                  map['dimensions'],
              left: false,
            ),
          ),
        );
        continue;
      }
      items.add(
        _OrderGroupClient(
          clientId: s(entry?.clientId),
          clientName: s(entry?.clientName),
          clientEmail: s(entry?.clientEmail),
          responseStatus: s(
            entry?.responseStatus ??
                entry?.clientResponseStatus ??
                entry?.status,
          ),
          nailShape: s(entry?.nailShape ?? entry?.shape),
          nailLength: s(entry?.nailLength ?? entry?.length),
          leftHandDimensions: dimsFrom(
            entry?.leftHandDimensions ??
                entry?.savedNails ??
                entry?.draftNails ??
                entry?.nailPreferences ??
                entry?.dimensions,
            left: true,
          ),
          rightHandDimensions: dimsFrom(
            entry?.rightHandDimensions ??
                entry?.savedNails ??
                entry?.draftNails ??
                entry?.nailPreferences ??
                entry?.dimensions,
            left: false,
          ),
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
    this.responseStatus = '',
    this.nailShape = '',
    this.nailLength = '',
    this.leftHandDimensions = const <String, String>{},
    this.rightHandDimensions = const <String, String>{},
  });

  final String clientId;
  final String clientName;
  final String clientEmail;
  final String responseStatus;
  final String nailShape;
  final String nailLength;
  final Map<String, String> leftHandDimensions;
  final Map<String, String> rightHandDimensions;
}

/// ------------------------
/// SHIPPED ORDER DETAILS (UI like your screenshot)
/// ------------------------
class ShippedOrderDetailsPage extends StatelessWidget {
  const ShippedOrderDetailsPage({super.key, required this.order});
  final dynamic order;

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
      showRightPanel: false,
      rightPanel: const SizedBox.shrink(),
    );
  }
}

/// ------------------------
/// IN PROGRESS DETAILS
/// ------------------------
class InProgressOrderDetailsPage extends StatelessWidget {
  const InProgressOrderDetailsPage({super.key, required this.order});
  final dynamic order;

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
  const InReviewOrderDetailsPage({super.key, required this.order});
  final dynamic order;

  @override
  Widget build(BuildContext context) {
    final o = _OrderSafe.from(order);

    return _BaseOrderDetails(
      title: 'Order Details',
      statusPillText: 'In Review',
      statusPillColor: AppColors.balletSlippers,
      statusPillIcon: Icons.hourglass_bottom_rounded,
      statusPillIconColor: Colors.black.withValues(alpha: 0.65),
      order: o,
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
  const NewOrderDetailsPage({super.key, required this.order});
  final dynamic order;

  @override
  Widget build(BuildContext context) {
    final o = _OrderSafe.from(order);

    return _BaseOrderDetails(
      title: 'Order Details',
      statusPillText: 'Pending',
      statusPillColor: AppColors.balletSlippers,
      statusPillIcon: Icons.fiber_new_rounded,
      statusPillIconColor: Colors.black.withValues(alpha: 0.65),
      order: o,
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

  @override
  Widget build(BuildContext context) {
    final isSubmittedStatus =
        statusPillText == 'Pending' || statusPillText == 'In Review';
    final isCancelledStatus = statusPillText == 'Cancelled';
    final isExpiredStatus = statusPillText == 'Expired';
    final isClosedHistoryStatus = isCancelledStatus || isExpiredStatus;
    final acceptedArtistMetaFuture = _loadAcceptedArtistMeta(order);

    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: AppBar(
        backgroundColor: AppColors.alabaster,
        surfaceTintColor: AppColors.alabaster,
        elevation: 0,
        title: Image.asset(
          'assets/images/jnt_logo_black.png',
          height: 50,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 26),
            onPressed: () => Navigator.pop(context),
          ),
        ],
        leading: const SizedBox.shrink(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
        children: [
          if (isCancelledStatus) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.balletSlippers,
                borderRadius: BorderRadius.zero,
                border: Border.all(color: AppColors.blackCatBorderLight),
              ),
              child: Row(
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

          const SizedBox(height: 12),

          if (isSubmittedStatus)
            _Card(
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: Colors.black.withValues(alpha: 0.60),
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
                ],
              ),
            )
          else if (!isClosedHistoryStatus)
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
                          color: AppColors.blackCat.withValues(alpha: 0.06),
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
                                        color: AppColors.blackCat.withValues(alpha: 
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
                                          color: AppColors.blackCat.withValues(alpha: 
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
                      color: Colors.black.withValues(alpha: 0.82),
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
                      color: Colors.black.withValues(alpha: 0.82),
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Common reasons:',
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.82),
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
                      color: Colors.black.withValues(alpha: 0.82),
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
                    'Brand Description',
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
                      color: AppColors.blackCat.withValues(alpha: 0.82),
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
                    'Brand Description',
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
                      color: AppColors.blackCat.withValues(alpha: 0.82),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      fontFamily: 'Arial',
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Divider(color: AppColors.blackCat.withValues(alpha: 0.08)),
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
                  _SubmittedPhotosStrip(paths: order.inspirationPhotos),
                  const SizedBox(height: 14),
                  Divider(color: AppColors.blackCat.withValues(alpha: 0.08)),
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
                  _bullet('Campaign Name', _valueOrDash(order.title)),
                  _bullet('Need by', _valueOrDash(order.needByDisplay)),
                  _bullet('Budget', _budgetText()),
                  _bullet('Request Artist', _requestArtistDisplay()),
                  // Keep in code per request, but hide from UI:
                  // _bullet('Status', statusPillText),
                  const SizedBox(height: 8),
                  Divider(color: Colors.black.withValues(alpha: 0.08)),
                  const SizedBox(height: 5),
                  _paymentSection(context),
                ],
              ),
            ),
          ] else ...[
            _SubmittedPhotosStrip(paths: order.inspirationPhotos),

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
            if (statusPillText == 'In Progress') ...[
              _Card(child: _finalAcceptedAmountSection()),
              const SizedBox(height: 12),
              SizedBox(
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
                    _openRequestChat(context);
                  },
                  child: const Text(
                    'Chat',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
            if (statusPillText == 'Shipped') ...[
              _Card(child: _finalAcceptedAmountSection()),
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
                        backgroundColor: AppColors.balletSlippers,
                        foregroundColor: AppColors.blackCat,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                        side: BorderSide(color: AppColors.blackCatBorderLight),
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
                          fontSize: 12.5,
                          fontFamily: 'Arial',
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  fit: FlexFit.loose,
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
                              .collection('Company_Custom_Requests')
                              .doc(order.id);
                          final snap = await docRef.get();
                          final rootData =
                              snap.data() ?? const <String, dynamic>{};
                          final detailsSnap = await docRef
                              .collection('details')
                              .doc('payload')
                              .get();
                          final detailsData =
                              detailsSnap.data() ?? const <String, dynamic>{};

                          final cancelReason = result.reason.trim();
                          final cancelledAt = Timestamp.now();
                          List<dynamic> cancelGroupClients(dynamic value) {
                            if (value is! List) return const <dynamic>[];
                            return value
                                .map((entry) {
                                  if (entry is! Map) return entry;
                                  final item = Map<String, dynamic>.from(entry);
                                  item['responseStatus'] = 'cancelled';
                                  item['clientResponseStatus'] = 'cancelled';
                                  item['status'] = 'cancelled';
                                  item['cancelReason'] = cancelReason;
                                  item['cancelledAt'] = cancelledAt;
                                  item['updatedAt'] = cancelledAt;
                                  return item;
                                })
                                .toList(growable: false);
                          }

                          final updatedGroupClients = cancelGroupClients(
                            rootData['groupClients'],
                          );
                          final updatedGroupOrder =
                              (detailsData['groupOrder']
                                  as Map<String, dynamic>?) ??
                              const <String, dynamic>{};
                          final updatedGroupOrderClients = cancelGroupClients(
                            updatedGroupOrder['clients'],
                          );

                          await docRef.set({
                            'status': 'cancelled',
                            'updatedAt': FieldValue.serverTimestamp(),
                            'cancelledAt': cancelledAt,
                            'cancelReason': cancelReason,
                            if (updatedGroupClients.isNotEmpty)
                              'groupClients': updatedGroupClients,
                          }, SetOptions(merge: true));
                          await docRef.collection('details').doc('payload').set(
                            {
                              'status': 'cancelled',
                              if (updatedGroupOrderClients.isNotEmpty)
                                'groupOrder': {
                                  ...updatedGroupOrder,
                                  'clients': updatedGroupOrderClients,
                                },
                              'cancellation': {
                                'reason': cancelReason,
                                'cancelledAt': cancelledAt,
                                'cancelledBy': 'client',
                              },
                            },
                            SetOptions(merge: true),
                          );

                          await _notifyOnBrandCancellation(
                            reason: cancelReason,
                            rootData: rootData,
                            detailsData: detailsData,
                          );

                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Order cancelled successfully.'),
                            ),
                          );
                          Navigator.of(context).pop();
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to cancel order: $e'),
                            ),
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
            ),
          ],
        ],
      ),
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
              color: Colors.black.withValues(alpha: 0.55),
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

  Future<void> _notifyOnBrandCancellation({
    required String reason,
    required Map<String, dynamic> rootData,
    required Map<String, dynamic> detailsData,
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
    final brandCompany = firstNonEmpty(<Object?>[
      rootData['companyName'],
      rootData['brandName'],
      detailsData['companyName'],
    ], fallback: 'Brand Company');
    final campaignName = firstNonEmpty(<Object?>[
      rootData['campaignName'],
      rootData['title'],
      detailsData['campaignName'],
    ], fallback: 'Campaign');
    final orderRef = firstNonEmpty(<Object?>[
      rootData['orderNumber'],
      detailsData['orderNumber'],
      order.id,
    ], fallback: order.id);
    final acceptedClientEmail = firstNonEmpty(<Object?>[
      rootData['acceptedByClientEmail'],
      (detailsData['acceptance'] is Map
          ? (detailsData['acceptance'] as Map)['acceptedByClientEmail']
          : null),
    ]).toLowerCase();
    final clientName = firstNonEmpty(<Object?>[
      rootData['acceptedClientName'],
      rootData['clientName'],
      (detailsData['clientProfileSnapshot'] is Map
          ? ((detailsData['clientProfileSnapshot'] as Map)['basic'] is Map
                ? ((detailsData['clientProfileSnapshot'] as Map)['basic']
                      as Map)['name']
                : null)
          : null),
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

    final groupClients = <Map<String, dynamic>>[];
    if (rootData['groupClients'] is List) {
      for (final raw in (rootData['groupClients'] as List)) {
        if (raw is Map) groupClients.add(Map<String, dynamic>.from(raw));
      }
    }
    if (groupClients.isEmpty &&
        (detailsData['groupOrder'] as Map<String, dynamic>?)?['clients']
            is List) {
      for (final raw
          in ((detailsData['groupOrder'] as Map)['clients'] as List)) {
        if (raw is Map) groupClients.add(Map<String, dynamic>.from(raw));
      }
    }
    if (groupClients.isEmpty && acceptedClientEmail.isNotEmpty) {
      groupClients.add({
        'clientEmail': acceptedClientEmail,
        'clientName': clientName,
        'responseStatus': 'accepted',
      });
    }

    bool isRejectedStatus(String status) {
      final normalized = status.trim().toLowerCase();
      return normalized == 'declined' || normalized == 'rejected';
    }

    final eligibleClients = groupClients
        .where((client) {
          final email = readEmail(client['clientEmail']);
          if (email.isEmpty) return false;
          return !isRejectedStatus(
            (client['responseStatus'] ??
                    client['clientResponseStatus'] ??
                    client['status'])
                .toString(),
          );
        })
        .map(
          (client) => <String, String>{
            'email': readEmail(client['clientEmail']),
            'name': firstNonEmpty(<Object?>[
              client['clientName'],
              client['name'],
              'Client',
            ], fallback: 'Client'),
          },
        )
        .toList(growable: false);

    final isDirect =
        (rootData['isDirectRequest'] == true) ||
        (orderMeta['isDirectRequest'] == true);
    if (!isDirect) {
      bool isBrandEligibleArtist(Map<String, dynamic> data) {
        final profile = (data['profile'] as Map<String, dynamic>?) ?? const {};
        final ascension =
            (data['ascension'] as Map<String, dynamic>?) ?? const {};
        final sponsorshipRequest =
            (data['sponsorshipRequest'] as Map<String, dynamic>?) ?? const {};
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
            if (!isBrandEligibleArtist(data)) continue;
            final email = readEmail(data['email']);
            if (email.isNotEmpty) targets.add(email);
          }
        } catch (_) {}
      }
    }

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
              '**$brandCompany** cancelled your Campaign: **$campaignName** **$orderRef** **$reason**',
          type: 'brand_request_cancelled_by_brand',
          orderId: order.id,
          orderNumber: orderRef,
          sourceCollection: 'Company_Custom_Requests',
        );
      } catch (_) {}
    }

    await NotificationsService.notifyAdmins(
      title: 'Brand Request Cancelled',
      body:
          '**$brandCompany** cancelled Campaign **$campaignName** **$orderRef** **$reason**',
      type: 'admin_brand_request_cancelled_by_brand',
      orderId: order.id,
      orderNumber: orderRef,
      sourceCollection: 'Company_Custom_Requests',
    );

    for (final client in eligibleClients) {
      final email = client['email'] ?? '';
      if (email.isEmpty) continue;
      try {
        await NotificationsService.createUserNotification(
          receiverEmail: email,
          title: 'Brand Request Cancelled',
          body:
              'Your Campaign **$campaignName** **$orderRef** has been cancelled **$reason** by **$brandCompany**',
          type: 'client_brand_request_cancelled_by_brand',
          orderId: order.id,
          orderNumber: orderRef,
          sourceCollection: 'Company_Custom_Requests',
        );
      } catch (_) {}
    }

    for (final targetEmail in targets) {
      for (final client in eligibleClients) {
        final resolvedClientName = (client['name'] ?? '').trim().isNotEmpty
            ? client['name']!
            : 'Client';
        try {
          await NotificationsService.createUserNotification(
            receiverEmail: targetEmail,
            title: 'Brand Request Cancelled',
            body:
                '**$brandCompany** cancelled Campaign **$campaignName** **$orderRef** **$reason** for **$resolvedClientName**',
            type: 'artist_pool_brand_request_cancelled_by_brand',
            orderId: order.id,
            orderNumber: orderRef,
            sourceCollection: 'Company_Custom_Requests',
          );
        } catch (_) {}
      }
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
      child: Icon(Icons.person_outline, color: Colors.black.withValues(alpha: 0.5)),
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
            color: Colors.black.withValues(alpha: 0.65),
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
            color: Colors.black.withValues(alpha: 0.6),
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
            color: Colors.black.withValues(alpha: 0.6),
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
          .collection('Company_Custom_Requests')
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
          sourceCollection: 'Company_Custom_Requests',
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
          .collection('Company_Custom_Requests')
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
          sourceCollection: 'Company_Custom_Requests',
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

  Widget _orderDetailsWithRightNailDimensions() {
    Widget detailsBlock() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Details',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 10),
          _bullet('Campaign Name', _valueOrDash(order.title)),
          _bullet('Need by', _valueOrDash(order.needByDisplay)),
          _bullet('Budget', _budgetText()),
          _bullet('Request Artist', _requestArtistDisplay()),
          _bullet('Accepted Clients', _acceptedClientsDisplay()),
          // Keep in code per request, but hide from UI:
          // _bullet('Status', statusPillText),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [detailsBlock()],
        );
      },
    );
  }

  String _acceptedClientsDisplay() {
    final accepted = order.groupClients
        .where(
          (client) => client.responseStatus.trim().toLowerCase() == 'accepted',
        )
        .map((client) => client.clientName.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    if (accepted.isNotEmpty) {
      return accepted.toSet().join(', ');
    }
    return '-';
  }

  static Widget _bullet(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            color: AppColors.blackCat.withValues(alpha: 0.75),
            fontWeight: FontWeight.w400,
            fontSize: 14,
          ),
          children: [
            TextSpan(
              text: '$k: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: v),
          ],
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
            color: Colors.black.withValues(alpha: 0.04),
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
                      color: AppColors.blackCat.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: 38,
                    color: AppColors.blackCat.withValues(alpha: 0.55),
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
              RadioGroup<String>(
                groupValue: _selected,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selected = value);
                },
                child: Column(
                  children: [
                    ..._reasons.map(
                      (r) => RadioListTile<String>(
                        value: r,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        activeColor: AppColors.blackCat,
                        selected: _selected == r,
                        title: Text(r, style: const TextStyle(fontSize: 13)),
                      ),
                    ),
                  ],
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
                      color: AppColors.blackCat.withValues(alpha: 0.08),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(
                      color: AppColors.blackCat.withValues(alpha: 0.08),
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
  const _SubmittedPhotosStrip({required this.paths});
  final List<String> paths;

  @override
  Widget build(BuildContext context) {
    final renderable = paths
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList(growable: false);

    if (renderable.isEmpty) {
      return Text(
        'No photos were uploaded by client.',
        style: TextStyle(
          color: Colors.black.withValues(alpha: 0.62),
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      );
    }

    ImageProvider providerFor(String path) {
      var p = path.trim();
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
      if (p.startsWith('http://') ||
          p.startsWith('https://') ||
          p.startsWith('blob:') ||
          p.startsWith('data:') ||
          p.startsWith('content://')) {
        return NetworkImage(p);
      }
      if (p.startsWith('assets/')) {
        return AssetImage(p);
      }
      if (p.startsWith('file://')) {
        final localPath = p.replaceFirst('file://', '');
        if (kIsWeb) {
          return NetworkImage(p);
        }
        return FileImage(File(localPath));
      }
      if (kIsWeb) {
        return NetworkImage(p);
      }
      return FileImage(File(p));
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
            final provider = providerFor(path);
            return FutureBuilder<void>(
              future: precacheImage(provider, context),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return SizedBox(width: tileSize, height: tileSize);
                }
                if (snap.hasError) return const SizedBox.shrink();
                return ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: InkWell(
                    onTap: () {
                      showDialog<void>(
                        context: context,
                        builder: (_) => Dialog(
                          backgroundColor: Colors.black,
                          insetPadding: const EdgeInsets.all(8),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: InteractiveViewer(
                                  minScale: 0.8,
                                  maxScale: 4,
                                  child: Center(
                                    child: Image(
                                      image: provider,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, _, _) =>
                                          const SizedBox.shrink(),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(
                                    Icons.close,
                                    color: AppColors.snow,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: tileSize,
                      height: tileSize,
                      color: AppColors.blackCat.withValues(alpha: 0.04),
                      child: Image(
                        image: provider,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
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
  bool _autoModalOpened = false;

  String _textOrEmpty(Object? raw) => (raw ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _rating = (widget.order.clientRating ?? 0).clamp(0, 5).toDouble();
    _commentCtrl = TextEditingController(text: widget.order.clientReviewText);
    _customTipCtrl = TextEditingController();
    _submittedAt = widget.order.clientReviewSubmittedAt;
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
          .collection('Company_Custom_Requests')
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
      _maybeAutoOpenReviewModal();
    } catch (_) {
      if (!mounted) return;
      setState(() => _promptProcessed = true);
      _maybeAutoOpenReviewModal();
    }
  }

  void _maybeAutoOpenReviewModal() {
    if (!mounted || _autoModalOpened) return;
    if (_submittedAt != null || (widget.order.clientRating ?? 0) > 0) return;
    _autoModalOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openReviewTipModal();
    });
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
        sourceCollection: 'Company_Custom_Requests',
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
      final comment = _commentCtrl.text.trim();
      final tipAmount = _calculatedTip;
      final tipPercent = _selectedTipPercent;
      final customTipAmount = _selectedTipPercent == null
          ? _customTipAmount
          : 0;
      final db = FirebaseFirestore.instance;
      final ref = db.collection('Company_Custom_Requests').doc(widget.order.id);
      final artistEmail = widget.order.acceptedByArtistEmail
          .trim()
          .toLowerCase();
      final artistRef = await _resolveArtistDocRef(artistEmail);

      await db.runTransaction((tx) async {
        final orderSnap = await tx.get(ref);
        final orderData = orderSnap.data() ?? const <String, dynamic>{};
        final prevRating =
            _asDouble(orderData['clientRating']) ??
            _asDouble(
              (orderData['clientReview'] as Map<String, dynamic>?)?['rating'],
            );

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
            'submittedAt': tipAmount > 0 ? FieldValue.serverTimestamp() : null,
          },
        }, SetOptions(merge: true));

        if (artistRef != null) {
          final artistSnap = await tx.get(artistRef);
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

          final hadPrevious = (prevRating ?? 0) > 0;
          final safeCount = currentCount <= 0
              ? (hadPrevious ? 1 : 0)
              : currentCount;
          final nextCount = hadPrevious ? safeCount : (safeCount + 1);
          final nextRating = currentRating >= _rating ? currentRating : _rating;

          tx.set(artistRef, {
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
        }
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
          'submittedAt': tipAmount > 0 ? FieldValue.serverTimestamp() : null,
        },
      }, SetOptions(merge: true));

      if (artistEmail.isNotEmpty) {
        await NotificationsService.createUserNotification(
          receiverEmail: artistEmail,
          title: 'New Client Review',
          body:
              'A client left a ${_rating.toStringAsFixed(1)} star review on a delivered order.',
          type: 'client_review_submitted',
          orderId: widget.order.id,
          sourceCollection: 'Company_Custom_Requests',
        );
        if (tipAmount > 0) {
          await NotificationsService.createUserNotification(
            receiverEmail: artistEmail,
            title: 'New Client Tip',
            body:
                'A client sent you a tip of \$${tipAmount.toStringAsFixed(2)} on a delivered order.',
            type: 'client_tip_submitted',
            orderId: widget.order.id,
            sourceCollection: 'Company_Custom_Requests',
          );
        }
      }

      if (!mounted) return false;
      setState(() => _submittedAt = DateTime.now());
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Review saved. Thank you!')));
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
                            color: Colors.black.withValues(alpha: 0.62),
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text(
                              'Rating',
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
                                color: AppColors.blackCat.withValues(alpha: 0.08),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                color: AppColors.blackCat.withValues(alpha: 0.08),
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
                                  color: AppColors.blackCat.withValues(alpha: 0.08),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.zero,
                                borderSide: BorderSide(
                                  color: AppColors.blackCat.withValues(alpha: 0.08),
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
                                    if (success && mounted) {
                                      Navigator.of(context).pop();
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
          'Delivered successfully. Please rate your order and add an optional tip.',
          style: TextStyle(
            color: Colors.black.withValues(alpha: 0.62),
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
        if (_promptProcessed && _promptChannelLabel.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F0FA),
              borderRadius: BorderRadius.zero,
            ),
            child: Text(
              'Review prompt sent via: $_promptChannelLabel',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
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
              _submittedAt == null ? 'Rate & Tip Artist' : 'Edit Review & Tip',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
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
  const DeliveredOrderDetailsPage({super.key, required this.order});
  final dynamic order;

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
    this.onChat,
    this.onResubmit,
  });
  final dynamic order;
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
    this.onChat,
    this.onResubmit,
  });
  final dynamic order;
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
      showRightPanel: false,
      rightPanel: const SizedBox.shrink(),
      onCancelledChat: onChat,
      onCancelledResubmit: onResubmit,
    );
  }
}


