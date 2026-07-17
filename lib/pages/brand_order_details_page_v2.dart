import 'dart:io';

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/profile_table_columns.dart';
import '../theme/app_colors.dart';
import '../services/notifications_service.dart';
import '../services/storage_url_resolver.dart';
import '../widgets/jnt_modal_app_bar.dart';
import 'request_chat_page.dart';
import 'track_order_page.dart';

/// If you already have this model elsewhere, you can delete this class
/// and import the correct model file instead.
/// But to keep this file self-contained + compile, we accept `dynamic order`.
/// (We only read simple fields with fallback.)
class _OrderSafe {
  final String sourceCollection;
  final String id;
  final String orderNumber;
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
  final String jntRevealDateDisplay;
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
  final bool openToClientPool;
  final String selectedClientName;
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
  final String directClientStatus;
  final String directArtistStatus;
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
    required this.jntRevealDateDisplay,
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
    required this.openToClientPool,
    required this.selectedClientName,
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
    required this.directClientStatus,
    required this.directArtistStatus,
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
    dynamic tryRead(dynamic Function() reader) {
      try {
        return reader();
      } catch (_) {
        return null;
      }
    }

    double? d(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse((v ?? '').toString().trim());
    }

    Map<String, dynamic> asMap(dynamic value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        return value.map((k, v) => MapEntry(k.toString(), v));
      }
      return const <String, dynamic>{};
    }

    DateTime? dt(dynamic v) {
      return _parseDate(v);
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
    final nailPrefsSources = <Object?>[
      (o is Map ? o['nailPreferences'] : null),
      payloadMap?['nailPreferences'],
      requestDetailsMap?['nailPreferences'],
      orderMap?['nailPreferences'],
    ];
    final leftHandSources = <Object?>[
      (o is Map ? o['leftHandDimensions'] : null),
      payloadMap?['leftHandDimensions'],
      requestDetailsMap?['leftHandDimensions'],
      orderMap?['leftHandDimensions'],
    ];
    final rightHandSources = <Object?>[
      (o is Map ? o['rightHandDimensions'] : null),
      payloadMap?['rightHandDimensions'],
      requestDetailsMap?['rightHandDimensions'],
      orderMap?['rightHandDimensions'],
    ];
    List<String> listOrEmpty(dynamic v) {
      if (v is List) return List<String>.from(v.whereType<String>());
      return const <String>[];
    }

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
          final keys = <String>[
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
            'value',
          ];
          for (final key in keys) {
            if (value.containsKey(key)) addValue(value[key]);
          }
          value.forEach((k, v) {
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

    Map<String, String> handDimsFromSources(List<Object?> sources) {
      Map<String, String> readFrom(dynamic value) {
        final map = _dimsMap(value);
        if (map.isNotEmpty) return map;
        final nested = asMap(asMap(value)['dimensions']);
        if (nested.isNotEmpty) {
          final nestedDims = _dimsMap(nested);
          if (nestedDims.isNotEmpty) return nestedDims;
        }
        if (value is! Map) return const <String, String>{};
        String pick(String key, {required bool left}) {
          final values = left
              ? <String>[key, 'l${key[0].toUpperCase()}${key.substring(1)}']
              : <String>[key, 'r${key[0].toUpperCase()}${key.substring(1)}'];
          for (final candidate in values) {
            final raw = value[candidate];
            final text = (raw ?? '').toString().trim();
            if (text.isNotEmpty) return text;
          }
          return '';
        }

        return <String, String>{
          'thumb': pick('thumb', left: true),
          'index': pick('index', left: true),
          'middle': pick('middle', left: true),
          'ring': pick('ring', left: true),
          'pinky': pick('pinky', left: true),
        };
      }

      for (final source in sources) {
        final hand = readFrom(source);
        if (hand.isNotEmpty) return hand;
      }
      return const <String, String>{};
    }

    return _OrderSafe(
      sourceCollection: 'Company_Custom_Requests',
      id: s(o?.id, 'order'),
      orderNumber: s(o?.orderNumber, ''),
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
      jntRevealDateDisplay: s(o?.jntRevealDateDisplay, ''),
      nailShape: s(o?.nailShape, ''),
      nailLength: s(o?.nailLength, ''),
      budgetMin: o?.budgetMin is int ? o.budgetMin as int : null,
      budgetMax: o?.budgetMax is int ? o.budgetMax as int : null,
      leftHandDimensions: handDimsFromSources([
        ...leftHandSources,
        ...nailPrefsSources,
      ]),
      rightHandDimensions: handDimsFromSources([
        ...rightHandSources,
        ...nailPrefsSources,
      ]),
      imageAsset: s(o?.imageAsset, 'assets/images/order_thumb_1.png'),
      artistAcceptedAmount: o?.artistAcceptedAmount is int
          ? o.artistAcceptedAmount as int
          : null,
      paymentStatus: s(o?.paymentStatus, ''),
      paymentLink: s(o?.paymentLink, ''),
      openToClientPool: (tryRead(() => (o as dynamic).openToClientPool) is bool)
          ? (tryRead(() => (o as dynamic).openToClientPool) as bool)
          : ((payloadMap?['openToClientPool'] is bool)
                ? (payloadMap?['openToClientPool'] as bool)
                : ((orderMap?['openToClientPool'] is bool)
                      ? (orderMap?['openToClientPool'] as bool)
                      : true)),
      selectedClientName: s(
        tryRead(() => (o as dynamic).selectedClientName) ??
            tryRead(() => (o as dynamic).selectedClient) ??
            payloadMap?['selectedClientName'] ??
            payloadMap?['selectedClient'] ??
            orderMap?['selectedClientName'] ??
            orderMap?['selectedClient'],
        '',
      ),
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
      directClientStatus: s(
        tryRead(() => (o as dynamic).directClientStatus) ??
            payloadMap?['directClientStatus'],
        '',
      ).toLowerCase(),
      directArtistStatus: s(
        tryRead(() => (o as dynamic).directArtistStatus) ??
            payloadMap?['directArtistStatus'],
        '',
      ).toLowerCase(),
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

SupabaseClient get _client => Supabase.instance.client;

User? get _currentUser => _client.auth.currentUser;

String get _currentEmail => (_currentUser?.email ?? '').trim().toLowerCase();

String get _currentName {
  final metadata = _currentUser?.userMetadata;
  return _firstNonEmpty([
    metadata?['name'],
    metadata?['full_name'],
    metadata?['display_name'],
    _currentUser?.email,
  ]);
}

String _firstNonEmpty(List<Object?> values, {String fallback = ''}) {
  for (final value in values) {
    final text = (value ?? '').toString().trim();
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

DateTime? _parseDate(dynamic value) {
  if (value is DateTime) return value;
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.round());
  return null;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, innerValue) => MapEntry(key.toString(), innerValue));
  }
  return const <String, dynamic>{};
}

List<dynamic> _asList(dynamic value) {
  if (value is List<dynamic>) return value;
  if (value is List) return value.toList(growable: false);
  return const <dynamic>[];
}

String _normalizeStorageUrl(dynamic raw) {
  final value = (raw ?? '').toString().trim();
  if (value.isEmpty) return '';
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }
  if (value.startsWith('gs://')) return value;
  if (value.startsWith('data:image/')) return value;
  return value;
}

Future<Map<String, dynamic>?> _supabaseFetchOrderRow(
  String orderId, {
  String orderNumber = '',
}) async {
  final id = orderId.trim();
  if (id.isNotEmpty) {
    try {
      final rows = await _client
          .from('company_custom_requests')
          .select()
          .eq('id', id)
          .limit(1);
      if (rows.isNotEmpty) {
        return Map<String, dynamic>.from(rows.first as Map);
      }
    } catch (_) {}
  }
  final number = orderNumber.trim();
  if (number.isNotEmpty) {
    try {
      final rows = await _client
          .from('company_custom_requests')
          .select()
          .eq('order_number', number)
          .limit(1);
      if (rows.isNotEmpty) {
        return Map<String, dynamic>.from(rows.first as Map);
      }
    } catch (_) {}
  }
  return null;
}

Future<Map<String, dynamic>?> _supabaseFetchArtistRowByEmail(
  String email,
) async {
  final normalized = email.trim().toLowerCase();
  if (normalized.isEmpty) return null;
  for (final table in const <String>['artist', 'client_artist']) {
    try {
      final rows = await _client
          .from(table)
          .select(columnsForProfileTable(table) ?? '*')
          .eq('email', normalized)
          .limit(1);
      if (rows.isNotEmpty) {
        return Map<String, dynamic>.from(rows.first as Map);
      }
    } catch (_) {}
  }
  return null;
}

Future<Map<String, dynamic>?> _supabaseFetchClientRowByEmail(
  String email,
) async {
  final normalized = email.trim().toLowerCase();
  if (normalized.isEmpty) return null;
  for (final table in const <String>['client', 'client_artist']) {
    try {
      final rows = await _client
          .from(table)
          .select(columnsForProfileTable(table) ?? '*')
          .eq('email', normalized)
          .limit(1);
      if (rows.isNotEmpty) {
        return Map<String, dynamic>.from(rows.first as Map);
      }
    } catch (_) {}
  }
  return null;
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
    final hasArtistCompletedArt = o.artistCompletedPhotos.isNotEmpty;

    return _BaseOrderDetails(
      title: 'Order Details',
      statusPillText: hasArtistCompletedArt ? 'Completed' : 'In Progress',
      statusPillColor: hasArtistCompletedArt
          ? const Color(0xFFE3F3E6)
          : AppColors.balletSlippers,
      statusPillIcon: hasArtistCompletedArt
          ? Icons.task_alt_rounded
          : Icons.timelapse_rounded,
      statusPillIconColor: hasArtistCompletedArt
          ? const Color(0xFF2E7D32)
          : const Color(0xFFD36B77),
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
      statusPillIconColor: AppColors.blackCat.withValues(alpha: 0.65),
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
      statusPillIconColor: AppColors.blackCat.withValues(alpha: 0.65),
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

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map(
        (key, innerValue) => MapEntry(key.toString(), innerValue),
      );
    }
    return const <String, dynamic>{};
  }

  static List<dynamic> _asList(dynamic value) {
    if (value is List<dynamic>) return value;
    if (value is List) return value.toList(growable: false);
    return const <dynamic>[];
  }

  SupabaseClient get _client => Supabase.instance.client;

  User? get _currentUser => _client.auth.currentUser;

  String get _currentEmail => (_currentUser?.email ?? '').trim().toLowerCase();

  static Future<_AcceptedArtistMeta> _loadAcceptedArtistMeta(
    _OrderSafe order,
  ) async {
    final fallback = _AcceptedArtistMeta(
      name: order.artistName.trim(),
      profileImage: order.artistProfileImage.trim(),
    );
    final email = order.acceptedByArtistEmail.trim().toLowerCase();
    if (email.isEmpty) return fallback;
    final client = Supabase.instance.client;

    for (final collection in const <String>['artist', 'client_artist']) {
      final rows = await client
          .from(collection)
          .select(columnsForProfileTable(collection) ?? '*')
          .eq('email', email)
          .limit(1);
      if (rows.isEmpty) continue;

      final data = Map<String, dynamic>.from(rows.first as Map);
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
        data['panel_profile_image_url'],
        data['profileImageUrl'],
        data['profile_image_url'],
        data['avatarUrl'],
        data['avatar_url'],
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
    final currentName = _currentName.trim();
    final fallbackCurrentName = _currentEmail.trim();
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
    final currentName = _currentName.trim();
    final fallbackCurrentName = _currentEmail.trim();
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

  bool get _showDirectClientDeclinedBanner =>
      order.directClientStatus.trim().toLowerCase() == 'declined';
  bool get _showDirectArtistDeclinedBanner =>
      order.directArtistStatus.trim().toLowerCase() == 'declined';

  Widget _directClientDeclinedBanner() {
    final clientName = _requestedClientDisplay();
    final resolvedName = clientName == 'N/A' ? '{Client Name}' : clientName;
    final message = 'Direct client $resolvedName declined this brand request.';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          size: 18,
          color: AppColors.blackCat,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              color: AppColors.blackCat,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }

  Widget _directArtistDeclinedBanner() {
    final artistName = _requestArtistDisplay();
    final resolvedName = artistName == 'N/A' ? '{Artist Name}' : artistName;
    final message = 'Direct artist $resolvedName declined this brand request.';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          size: 18,
          color: AppColors.blackCat,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              color: AppColors.blackCat,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSubmittedStatus =
        statusPillText == 'Pending' || statusPillText == 'In Review';
    final isCancelledStatus = statusPillText == 'Cancelled';
    final isExpiredStatus = statusPillText == 'Expired';
    final isClosedHistoryStatus = isCancelledStatus || isExpiredStatus;
    final canCancelBeforeArtistAccept =
        isSubmittedStatus &&
        order.acceptedByArtistEmail.trim().isEmpty &&
        order.artistAcceptedAmount == null;
    final acceptedArtistMetaFuture = _loadAcceptedArtistMeta(order);

    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: JntModalAppBar(
        onClose: () => Navigator.pop(context),
        closeTooltip: 'Close brand order details',
        closeIcon: const Icon(Icons.close_rounded, size: 26),
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

          const SizedBox(height: 12),

          if (isSubmittedStatus)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: AppColors.blackCat.withValues(alpha: 0.60),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Artist is not assigned yet. Once your submitted request is accepted, artist details and messaging will appear here.',
                    style: TextStyle(
                      color: AppColors.blackCat.withValues(alpha: 0.60),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            )
          else
            const SizedBox.shrink(),

          if (isSubmittedStatus && _showDirectClientDeclinedBanner) ...[
            const SizedBox(height: 12),
            _directClientDeclinedBanner(),
          ] else if (isSubmittedStatus && _showDirectArtistDeclinedBanner) ...[
            const SizedBox(height: 12),
            _directArtistDeclinedBanner(),
          ] else if (!isSubmittedStatus && !isClosedHistoryStatus)
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
                        height: 48,
                        width: 48,
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
                                        color: AppColors.blackCat.withValues(
                                          alpha: 0.85,
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
                                          color: AppColors.blackCat.withValues(
                                            alpha: 0.55,
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
                      color: AppColors.blackCat.withValues(alpha: 0.82),
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
                      color: AppColors.blackCat.withValues(alpha: 0.82),
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Common reasons:',
                    style: TextStyle(
                      color: AppColors.blackCat.withValues(alpha: 0.82),
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
                      color: AppColors.blackCat.withValues(alpha: 0.82),
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else if (isCancelledStatus) ...[
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _orderDetailsWithRightNailDimensions(),
                  const SizedBox(height: 14),
                  Divider(color: AppColors.blackCat.withValues(alpha: 0.08)),
                  const SizedBox(height: 5),
                  _paymentSection(context),
                ],
              ),
            ),
          ] else ...[
            if (statusPillText == 'Completed' ||
                statusPillText == 'Shipped' ||
                statusPillText == 'Delivered') ...[
              _Card(
                child: Column(
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
                      child: _SubmittedPhotosStrip(
                        paths: order.artistCompletedPhotos,
                        fallbackOrderId: order.id,
                        fallbackOrderNumber: order.orderNumber,
                        sourceCollection: order.sourceCollection,
                        enableFirestoreFallback: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

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
                  onPressed: () {
                    _openRequestChat(context);
                  },
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
            if (statusPillText == 'Shipped') ...[
              _Card(child: _finalAcceptedAmountSection()),
            ],
            if (statusPillText == 'Delivered') ...[
              _Card(child: _finalAcceptedAmountSection()),
              const SizedBox(height: 12),
              _Card(child: rightPanel),
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
          if (canCancelBeforeArtistAccept) ...[
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
                          final row = await _supabaseFetchOrderRow(
                            order.id,
                            orderNumber: order.orderNumber,
                          );
                          final rootData = row ?? const <String, dynamic>{};
                          final detailsData = _asMap(rootData['details']);

                          final typedReason = result.reason.trim();
                          final selectedReason = typedReason.isNotEmpty
                              ? typedReason
                              : 'Change in plans';
                          if (selectedReason.isEmpty) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Cancellation reason is required.',
                                ),
                              ),
                            );
                            return;
                          }
                          final cancelReason = selectedReason;
                          final cancelledAt = DateTime.now();
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

                          final nowIso = cancelledAt.toIso8601String();
                          final updatedRoot = <String, dynamic>{
                            'status': 'cancelled',
                            'brand_status': 'cancelled',
                            'client_status': 'cancelled',
                            'artist_status': 'cancelled',
                            'direct_client_status': 'cancelled',
                            'direct_artist_status': 'cancelled',
                            if (updatedGroupClients.isNotEmpty)
                              'group_clients': updatedGroupClients,
                            'groupClients': updatedGroupClients,
                            'updated_at': nowIso,
                            'updatedAt': nowIso,
                            'cancelled_at': nowIso,
                            'cancelledAt': nowIso,
                            'cancel_reason': cancelReason,
                            'cancelReason': cancelReason,
                            'cancellation_reason': cancelReason,
                            'cancellationReason': cancelReason,
                            'payload': {
                              ..._asMap(rootData['payload']),
                              'status': 'cancelled',
                              'roleStatuses': {
                                'brand': 'cancelled',
                                'client': 'cancelled',
                                'artist': 'cancelled',
                              },
                              'routing': {
                                'directClientStatus': 'cancelled',
                                'directArtistStatus': 'cancelled',
                              },
                              if (updatedGroupOrderClients.isNotEmpty)
                                'groupOrder': {
                                  ...updatedGroupOrder,
                                  'clients': updatedGroupOrderClients,
                                },
                              'cancellation': {
                                'reason': cancelReason,
                                'cancelledAt': nowIso,
                                'cancelledBy': 'brand',
                              },
                              'updatedAt': nowIso,
                            },
                            'details': {
                              ...detailsData,
                              'status': 'cancelled',
                              'roleStatuses': {
                                'brand': 'cancelled',
                                'client': 'cancelled',
                                'artist': 'cancelled',
                              },
                              'routing': {
                                'directClientStatus': 'cancelled',
                                'directArtistStatus': 'cancelled',
                              },
                              if (updatedGroupOrderClients.isNotEmpty)
                                'groupOrder': {
                                  ...updatedGroupOrder,
                                  'clients': updatedGroupOrderClients,
                                },
                              'cancellation': {
                                'reason': cancelReason,
                                'cancelledAt': nowIso,
                                'cancelledBy': 'brand',
                              },
                              'updatedAt': nowIso,
                            },
                          };
                          await _client
                              .from('company_custom_requests')
                              .update(updatedRoot)
                              .eq('id', order.id);

                          await _notifyOnBrandCancellation(
                            reason: cancelReason,
                            rootData: rootData,
                            detailsData: detailsData,
                          );

                          if (!context.mounted) return;
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
        if (isPaid || isPending)
          Row(
            children: [
              Text(
                isPaid ? 'Paid Amount:' : 'Amount Due:',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const Spacer(),
              Text(
                amountText,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.blackCat,
                ),
              ),
            ],
          )
        else
          FutureBuilder<Map<String, String>>(
            future: _loadBudgetRanges(),
            builder: (_, snap) {
              final ranges = snap.data ?? const <String, String>{};
              final clientRange = (ranges['client'] ?? '').trim().isNotEmpty
                  ? ranges['client']!.trim()
                  : rangeText;
              final artistRange = (ranges['artist'] ?? '').trim().isNotEmpty
                  ? ranges['artist']!.trim()
                  : rangeText;
              return Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        'Client Budget Range:',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        clientRange,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.blackCat,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text(
                        'Artist Budget Range:',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        artistRange,
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
            },
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
              color: AppColors.blackCat.withValues(alpha: 0.55),
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
      rootData['company_name'],
      rootData['brandName'],
      rootData['brand_name'],
      rootData['panel_companyName'],
      rootData['panel_company_name'],
      detailsData['companyName'],
      detailsData['company_name'],
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
    if (groupClients.isEmpty && order.groupClients.isNotEmpty) {
      for (final client in order.groupClients) {
        groupClients.add({
          'clientEmail': client.clientEmail,
          'clientName': client.clientName,
          'responseStatus': client.responseStatus,
        });
      }
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

    final fallbackClientEmails = <String>{
      acceptedClientEmail,
      readEmail(rootData['clientEmail']),
      readEmail(detailsData['clientEmail']),
    }..removeWhere((email) => email.isEmpty);
    final fallbackClientName = firstNonEmpty(<Object?>[
      clientName,
      rootData['clientName'],
      detailsData['clientName'],
      'Client',
    ], fallback: 'Client');
    if (groupClients.isEmpty && fallbackClientEmails.isNotEmpty) {
      eligibleClients.add({
        'email': fallbackClientEmails.first,
        'name': fallbackClientName,
      });
    }

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
        return false;
      }

      for (final collection in const <String>['artist', 'client_artist']) {
        try {
          final rows = await _client
              .from(collection)
              .select(columnsForProfileTable(collection) ?? '*');
          for (final raw in _asList(rows)) {
            final data = _asMap(raw);
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
          orderData: orderMeta,
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
      child: Icon(
        Icons.person_outline,
        color: Colors.black.withValues(alpha: 0.5),
      ),
    );
  }

  Widget _artistAvatarWithFallback({
    required String name,
    required String raw,
  }) {
    final src = raw.trim();
    if (src.isEmpty) {
      return Container(
        height: 56,
        width: 56,
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
      final row = await _supabaseFetchOrderRow(
        order.id,
        orderNumber: order.orderNumber,
      );
      final data = row ?? const <String, dynamic>{};
      final payload = _asMap(data['payload']);
      final details = _asMap(data['details']);
      final acceptedByArtistEmail = _firstNonEmpty([
        data['accepted_by_artist_email'],
        data['acceptedByArtistEmail'],
        payload['acceptedByArtistEmail'],
        details['acceptedByArtistEmail'],
      ]);
      final orderNumber = _firstNonEmpty([
        data['order_number'],
        data['orderNumber'],
        payload['orderNumber'],
        details['orderNumber'],
      ]);
      final currentStatus = _firstNonEmpty([
        data['status'],
        payload['status'],
        details['status'],
      ]).toLowerCase();
      final nowIso = DateTime.now().toIso8601String();
      final paymentMap = <String, dynamic>{
        'status': 'paid',
        'paidAt': nowIso,
        'paymentLink': order.paymentLink,
      };
      final mergedPayload = <String, dynamic>{
        ...payload,
        'status': currentStatus == 'accepted' ? 'designing' : payload['status'],
        'paymentStatus': 'paid',
        'payment_status': 'paid',
        'paidAt': nowIso,
        'paid_at': nowIso,
        'updatedAt': nowIso,
        'updated_at': nowIso,
        'paymentNotifiedArtist': acceptedByArtistEmail.isNotEmpty,
        'payment_notified_artist': acceptedByArtistEmail.isNotEmpty,
        if (acceptedByArtistEmail.isNotEmpty) 'paymentNotifiedArtistAt': nowIso,
        if (acceptedByArtistEmail.isNotEmpty)
          'payment_notified_artist_at': nowIso,
        'payment': paymentMap,
      };
      final mergedDetails = <String, dynamic>{
        ...details,
        'status': currentStatus == 'accepted' ? 'designing' : details['status'],
        'payment': paymentMap,
        'updatedAt': nowIso,
        'updated_at': nowIso,
      };
      await _client
          .from('company_custom_requests')
          .update({
            'status': currentStatus == 'accepted'
                ? 'designing'
                : data['status'],
            'payment_status': 'paid',
            'paymentStatus': 'paid',
            'paid_at': nowIso,
            'paidAt': nowIso,
            'updated_at': nowIso,
            'updatedAt': nowIso,
            'payment_notified_artist': acceptedByArtistEmail.isNotEmpty,
            'paymentNotifiedArtist': acceptedByArtistEmail.isNotEmpty,
            if (acceptedByArtistEmail.isNotEmpty)
              'payment_notified_artist_at': nowIso,
            if (acceptedByArtistEmail.isNotEmpty)
              'paymentNotifiedArtistAt': nowIso,
            'payment': paymentMap,
            'payload': mergedPayload,
            'details': mergedDetails,
          })
          .eq('id', order.id);

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
          _bullet('Description', _valueOrDash(order.clientDescription)),
          _bullet('Need by', _valueOrDash(order.needByDisplay)),
          _bullet('JNT Reveal Date', _valueOrDash(order.jntRevealDateDisplay)),
          _bullet('Requested Client', _requestedClientDisplay()),
          _bullet('Requested Artist', _requestArtistDisplay()),
          _bullet('Accepted Clients', _acceptedClientsDisplay()),
          const SizedBox(height: 10),
          const Text(
            'Uploaded Photos',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
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
            showAll: true,
          ),
          // Keep in code per request, but hide from UI:
          // _bullet('Status', statusPillText),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [detailsBlock()],
    );
  }

  Future<Map<String, String>> _loadBudgetRanges() async {
    String formatRange(int? min, int? max) {
      if (min != null && max != null) return '\$$min - \$$max';
      if (min != null) return '\$$min';
      if (max != null) return '\$$max';
      return '';
    }

    int? asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.round();
      return int.tryParse((v ?? '').toString().trim());
    }

    final fallback = formatRange(order.budgetMin, order.budgetMax);
    try {
      final row = await _supabaseFetchOrderRow(
        order.id,
        orderNumber: order.orderNumber,
      );
      final root = row ?? const <String, dynamic>{};
      final payload = _asMap(root['payload']);
      final detail = _asMap(root['details']);
      final clientBudget = _asMap(root['client_budget'])
        ..addAll(_asMap(root['clientBudget']))
        ..addAll(_asMap(payload['clientBudget']))
        ..addAll(_asMap(detail['clientBudget']));
      final artistBudget = _asMap(root['artist_budget'])
        ..addAll(_asMap(root['artistBudget']))
        ..addAll(_asMap(payload['artistBudget']))
        ..addAll(_asMap(detail['artistBudget']))
        ..addAll(_asMap(payload['budget']))
        ..addAll(_asMap(detail['budget']));

      final clientMin =
          asInt(clientBudget['min']) ??
          asInt(root['client_budget_min']) ??
          asInt(root['clientBudgetMin']);
      final clientMax =
          asInt(clientBudget['max']) ??
          asInt(root['client_budget_max']) ??
          asInt(root['clientBudgetMax']);
      final artistMin =
          asInt(artistBudget['min']) ??
          asInt(root['artist_budget_min']) ??
          asInt(root['artistBudgetMin']) ??
          asInt(root['budgetMin']) ??
          order.budgetMin;
      final artistMax =
          asInt(artistBudget['max']) ??
          asInt(root['artist_budget_max']) ??
          asInt(root['artistBudgetMax']) ??
          asInt(root['budgetMax']) ??
          order.budgetMax;

      final client = formatRange(clientMin, clientMax);
      final artist = formatRange(artistMin, artistMax);
      return <String, String>{
        'client': client.isEmpty ? fallback : client,
        'artist': artist.isEmpty ? fallback : artist,
      };
    } catch (_) {
      return <String, String>{'client': fallback, 'artist': fallback};
    }
  }

  static Widget _bullet(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            color: AppColors.blackCat,
            fontWeight: FontWeight.w400,
            fontSize: 14,
          ),
          children: [
            TextSpan(
              text: '$k: ',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.blackCat,
              ),
            ),
            TextSpan(
              text: v,
              style: const TextStyle(color: AppColors.blackCat),
            ),
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

  String _requestedClientDisplay() {
    final isGroupOrder =
        order.orderType.trim().toLowerCase() == 'group' ||
        order.groupClients.isNotEmpty;
    if (isGroupOrder) {
      final names = order.groupClients
          .map((c) => c.clientName.trim())
          .where((n) => n.isNotEmpty)
          .toList(growable: false);
      if (names.isNotEmpty) {
        return names.toSet().join(', ');
      }
      return 'Group';
    }
    if (order.openToClientPool) return 'N/A';
    final raw = order.selectedClientName.trim();
    if (raw.isEmpty) return 'N/A';
    final lower = raw.toLowerCase();
    if (lower == 'client' ||
        lower == 'select one' ||
        lower == 'n/a' ||
        lower == '-') {
      return 'N/A';
    }
    return raw;
  }

  String _acceptedClientsDisplay() {
    final accepted = order.groupClients
        .where(
          (client) => client.responseStatus.trim().toLowerCase() == 'accepted',
        )
        .map((client) => client.clientName.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    if (accepted.isNotEmpty) return accepted.toSet().join(', ');
    return '-';
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
        border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.12)),
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
  String _error = '';

  static const List<String> _reasons = [
    'Change in plans',
    'Budget concerns',
    'Unsatisfied with progress',
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
                      color: AppColors.blackCat.withValues(alpha: 15),
                    ),
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: 38,
                    color: AppColors.blackCat.withValues(alpha: 140),
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
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _selected = v;
                    _error = '';
                  });
                },
                child: Column(
                  children: _reasons
                      .map(
                        (r) => RadioListTile<String>(
                          value: r,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          activeColor: AppColors.blackCat,
                          title: Text(r, style: const TextStyle(fontSize: 13)),
                        ),
                      )
                      .toList(growable: false),
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
                      color: AppColors.blackCat.withValues(alpha: 20),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(
                      color: AppColors.blackCat.withValues(alpha: 20),
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
                          if (reason.isEmpty) {
                            setState(() => _error = 'Reason is required.');
                            return;
                          }
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
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _error,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
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
    this.sourceCollection = 'Company_Custom_Requests',
    this.enableFirestoreFallback = false,
    this.showAll = false,
  });
  final List<String> paths;
  final String fallbackOrderId;
  final String fallbackOrderNumber;
  final String sourceCollection;
  final bool enableFirestoreFallback;
  final bool showAll;

  static bool _isImageLikePath(String raw) {
    final noQuery = raw.trim().toLowerCase().split('?').first.split('#').first;
    return noQuery.endsWith('.jpg') ||
        noQuery.endsWith('.jpeg') ||
        noQuery.endsWith('.png') ||
        noQuery.endsWith('.webp') ||
        noQuery.endsWith('.gif') ||
        noQuery.endsWith('.heic') ||
        noQuery.endsWith('.heif');
  }

  static bool _isUsablePhotoRef(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return false;
    final lower = s.toLowerCase();

    if (lower == '-' || lower == 'null' || lower == 'none') return false;
    if (lower == '[]' || lower == '{}') return false;
    if (lower.startsWith('blob:')) return false;
    if (lower.startsWith('content://')) return false;
    if (lower.startsWith('data:') && !lower.startsWith('data:image/')) {
      return false;
    }
    if (lower.contains('order_thumb')) return false;
    if (lower.contains('placeholder')) return false;
    if (lower.contains('default_image')) return false;
    if (lower.contains('default-image')) return false;
    if (lower.contains('empty_image')) return false;
    if (lower.contains('empty-image')) return false;
    if (lower.contains('blank')) return false;
    if (lower.contains('spacer')) return false;
    if (lower.contains('transparent')) return false;
    if (lower.contains('no_image')) return false;
    if (lower.contains('no-image')) return false;
    if (lower.contains('no_photo')) return false;
    if (lower.contains('no-photo')) return false;
    if (lower.endsWith('/')) return false;

    if (lower.startsWith('data:image/')) return true;
    if (lower.startsWith('assets/')) return _isImageLikePath(lower);
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return _isImageLikePath(lower);
    }
    if (lower.startsWith('gs://')) return _isImageLikePath(lower);

    return _isImageLikePath(lower);
  }

  bool _isAllowedForDisplay(String raw) => _isUsablePhotoRef(raw);

  static List<String> _collectPhotoRefs(List<dynamic> values) {
    final out = <String>[];
    final seen = <String>{};
    void addValue(dynamic value) {
      if (value == null) return;
      if (value is String) {
        final s = value.trim();
        if (_isUsablePhotoRef(s) && seen.add(s)) out.add(s);
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
          'value',
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

  Future<List<String>> _loadFallbackPhotos() async {
    final orderId = fallbackOrderId.trim();
    if (orderId.isEmpty) return const <String>[];
    final root = await _supabaseFetchOrderRow(
      fallbackOrderId,
      orderNumber: fallbackOrderNumber,
    );
    if (root == null) return const <String>[];
    final payload = _asMap(root['payload']);
    final requestDetails =
        (payload['requestDetails'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final order =
        (payload['order'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final collected = _collectPhotoRefs(<dynamic>[
      payload['brandInspirationPhotos'],
      payload['inspirationPhotos'],
      payload['clientImages'],
      payload['photos'],
      payload['inspirationPhoto'],
      payload['inspirationPhotoUrl'],
      payload['previewImage'],
      payload['previewImageAsset'],
      requestDetails['brandInspirationPhotos'],
      requestDetails['inspirationPhotos'],
      requestDetails['clientImages'],
      requestDetails['photos'],
      requestDetails['inspirationPhoto'],
      requestDetails['inspirationPhotoUrl'],
      requestDetails['inspirationPhotoUrls'],
      requestDetails['inspirationPhotoRefs'],
      requestDetails['previewImage'],
      requestDetails['previewImageAsset'],
      order['brandInspirationPhotos'],
      order['inspirationPhotos'],
      order['clientImages'],
      order['photos'],
      order['inspirationPhoto'],
      order['inspirationPhotoUrl'],
      order['previewImage'],
      order['previewImageAsset'],
      root['brandInspirationPhotos'],
      root['inspirationPhotos'],
      root['clientImages'],
      root['photos'],
      root['inspirationPhoto'],
      root['inspirationPhotoUrl'],
      root['previewImage'],
      root['previewImageAsset'],
    ]);

    String firstNonEmpty(List<Object?> values) {
      for (final value in values) {
        final text = (value ?? '').toString().trim();
        if (text.isNotEmpty) return text;
      }
      return '';
    }

    final companyUid = firstNonEmpty(<Object?>[
      root['companyUid'],
      root['company_uid'],
      root['requesterUid'],
      root['requester_uid'],
      root['createdByUid'],
      root['created_by_uid'],
      root['uid'],
      payload['companyUid'],
      payload['company_uid'],
      payload['requesterUid'],
      payload['requester_uid'],
      payload['createdByUid'],
      payload['created_by_uid'],
      payload['uid'],
    ]);

    final folderRefs = <String>[];
    final baseFolders = <String>[
      if (companyUid.isNotEmpty) 'company-custom-requests/$companyUid/$orderId',
      'company-custom-requests/unknown/$orderId',
    ];
    for (final folder in baseFolders) {
      try {
        final storage = _client.storage.from('company-custom-requests');
        final list = await storage.list(path: folder);
        for (final item in _asList(list)) {
          final name = _firstNonEmpty([
            (() {
              try {
                return item.name;
              } catch (_) {
                return null;
              }
            })(),
            (() {
              try {
                return item.path;
              } catch (_) {
                return null;
              }
            })(),
          ]);
          if (name.isEmpty) continue;
          try {
            final metadata = (item as dynamic).metadata;
            final sizeRaw = metadata is Map ? metadata['size'] : null;
            final sizeText = (sizeRaw ?? '').toString().trim();
            final size = int.tryParse(sizeText);
            if (size != null && size <= 0) continue;
          } catch (_) {}
          final fullPath = '$folder/$name';
          final normalized = _normalizeStorageUrl(fullPath);
          if (_isUsablePhotoRef(normalized)) folderRefs.add(normalized);
        }
      } catch (_) {}
    }

    return <String>{...collected, ...folderRefs}.toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final renderable = paths
        .map((p) => p.trim())
        .where(_isAllowedForDisplay)
        .toList(growable: false);

    if (enableFirestoreFallback && fallbackOrderId.trim().isNotEmpty) {
      return FutureBuilder<List<String>>(
        future: _loadFallbackPhotos(),
        builder: (context, snap) {
          final fetched = (snap.data ?? const <String>[])
              .map((e) => e.trim())
              .where(_isAllowedForDisplay)
              .toList(growable: false);
          final merged = <String>{
            ...renderable,
            ...fetched,
          }.toList(growable: false);
          if (merged.isNotEmpty) {
            return _SubmittedPhotosStrip(
              paths: merged,
              enableFirestoreFallback: false,
              showAll: showAll,
            );
          }
          return Text(
            'No photos were uploaded by Brand.',
            style: TextStyle(
              color: AppColors.blackCat.withValues(alpha: 0.62),
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          );
        },
      );
    }

    if (renderable.isEmpty) {
      return Text(
        'No photos were uploaded by Brand.',
        style: TextStyle(
          color: AppColors.blackCat.withValues(alpha: 0.62),
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      );
    }

    ImageProvider providerFor(String p) {
      if (p.startsWith('data:image/')) {
        try {
          final comma = p.indexOf(',');
          if (comma > 0) {
            final b64 = p.substring(comma + 1).trim();
            final bytes = base64Decode(b64);
            return MemoryImage(bytes);
          }
        } catch (_) {}
      }
      if (p.startsWith('http://') || p.startsWith('https://')) {
        return NetworkImage(p);
      }
      if (p.startsWith('assets/')) return AssetImage(p);
      if (p.startsWith('file://')) {
        final localPath = p.replaceFirst('file://', '');
        if (kIsWeb) return NetworkImage(p);
        return FileImage(File(localPath));
      }
      if (kIsWeb) return NetworkImage(p);
      return FileImage(File(p));
    }

    Future<String> resolveDisplayPath(String raw) async {
      var p = raw.trim();
      for (var j = 0; j < 3; j++) {
        final decoded = Uri.decodeFull(p);
        if (decoded == p) break;
        p = decoded.trim();
      }
      if (p.isEmpty || !_isAllowedForDisplay(p)) return '';
      if (p.startsWith('http://') ||
          p.startsWith('https://') ||
          p.startsWith('assets/') ||
          p.startsWith('data:image/') ||
          p.startsWith('file://')) {
        if (!_isAllowedForDisplay(p)) return '';
        return p;
      }
      final looksStoragePath =
          p.startsWith('gs://') ||
          p.startsWith('company_custom_requests/') ||
          p.startsWith('client_custom_requests/') ||
          p.startsWith('clients/') ||
          p.startsWith('artists/') ||
          p.startsWith('client_artists/') ||
          p.startsWith('company/') ||
          (!p.contains('://') && p.contains('/'));
      if (looksStoragePath) {
        final resolved = await StorageUrlResolver.resolve(p);
        final text = (resolved ?? '').trim();
        if (_isAllowedForDisplay(text) &&
            (text.startsWith('http://') ||
                text.startsWith('https://') ||
                text.startsWith('assets/') ||
                text.startsWith('data:image/') ||
                text.startsWith('file://'))) {
          return text;
        }
      }
      final resolved = await StorageUrlResolver.resolve(p);
      final text = (resolved ?? '').trim();
      if (_isAllowedForDisplay(text) &&
          (text.startsWith('http://') ||
              text.startsWith('https://') ||
              text.startsWith('assets/') ||
              text.startsWith('data:image/') ||
              text.startsWith('file://'))) {
        return text;
      }
      return '';
    }

    Future<List<String>> validDisplayPaths(List<String> rawPaths) async {
      final seen = <String>{};
      final valid = <String>[];

      for (final raw in rawPaths) {
        final resolved = await resolveDisplayPath(raw);
        if (resolved.isEmpty || !seen.add(resolved)) continue;

        try {
          await precacheImage(providerFor(resolved), context);
          valid.add(resolved);
        } catch (_) {
          // Broken image refs should not reserve an empty tile.
        }
      }

      return valid;
    }

    Widget buildTile(String resolved, {required double size}) {
      final provider = providerFor(resolved);
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
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: AppColors.snow),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          child: SizedBox(
            width: size,
            height: size,
            child: Image(
              image: provider,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
      );
    }

    return FutureBuilder<List<String>>(
      future: validDisplayPaths(renderable),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return SizedBox(height: showAll ? 96 : 120);
        }

        final displayPaths = snap.data ?? const <String>[];
        if (displayPaths.isEmpty) {
          return Text(
            'No photos were uploaded by Brand.',
            style: TextStyle(
              color: AppColors.blackCat.withValues(alpha: 0.62),
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final tileSize = showAll
                ? ((constraints.maxWidth - 24) / 4).clamp(72.0, 110.0)
                : 120.0;
            if (showAll) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: displayPaths
                    .map((path) => buildTile(path, size: tileSize))
                    .toList(growable: false),
              );
            }

            return SizedBox(
              height: tileSize,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: displayPaths.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) =>
                    buildTile(displayPaths[i], size: tileSize),
              ),
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
    return raw.isEmpty ? 'Company_Custom_Requests' : raw;
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
      final row = await _supabaseFetchOrderRow(
        widget.order.id,
        orderNumber: widget.order.orderNumber,
      );
      final data = row ?? const <String, dynamic>{};
      final payload = _asMap(data['payload']);
      final details = _asMap(data['details']);
      final prompt = _asMap(payload['clientReviewPrompt'])
        ..addAll(_asMap(details['clientReviewPrompt']));
      final sentAt = _firstNonEmpty([
        data['client_review_prompt_sent_at'],
        data['clientReviewPromptSentAt'],
        payload['clientReviewPromptSentAt'],
        details['clientReviewPromptSentAt'],
      ]);
      if (sentAt.isNotEmpty || prompt['sentAt'] != null) {
        if (!mounted) return;
        setState(() {
          _promptProcessed = true;
          _promptChannelLabel = _textOrEmpty(
            data['client_review_prompt_channel'] ??
                data['clientReviewPromptChannel'] ??
                payload['clientReviewPromptChannel'] ??
                details['clientReviewPromptChannel'] ??
                prompt['channel'],
          );
        });
        return;
      }

      final prefs = await _loadClientContactPrefs();
      final channelLabel = await _sendPromptByPreference(prefs);
      final nowIso = DateTime.now().toIso8601String();
      final mergedPayload = <String, dynamic>{
        ...payload,
        'clientReviewPromptSentAt': nowIso,
        'client_review_prompt_sent_at': nowIso,
        'clientReviewPromptChannel': channelLabel,
        'client_review_prompt_channel': channelLabel,
        'updatedAt': nowIso,
        'updated_at': nowIso,
        'clientReviewPrompt': {
          ...prompt,
          'sentAt': nowIso,
          'channel': channelLabel,
        },
        'reviewPrompt': {
          ..._asMap(payload['reviewPrompt']),
          'sentAt': nowIso,
          'channel': channelLabel,
        },
      };
      final mergedDetails = <String, dynamic>{
        ...details,
        'clientReviewPromptSentAt': nowIso,
        'client_review_prompt_sent_at': nowIso,
        'clientReviewPromptChannel': channelLabel,
        'client_review_prompt_channel': channelLabel,
        'updatedAt': nowIso,
        'updated_at': nowIso,
        'clientReviewPrompt': {
          ...prompt,
          'sentAt': nowIso,
          'channel': channelLabel,
        },
      };
      await _client
          .from('company_custom_requests')
          .update({
            'client_review_prompt_sent_at': nowIso,
            'clientReviewPromptSentAt': nowIso,
            'client_review_prompt_channel': channelLabel,
            'clientReviewPromptChannel': channelLabel,
            'updated_at': nowIso,
            'updatedAt': nowIso,
            'payload': mergedPayload,
            'details': mergedDetails,
          })
          .eq('id', widget.order.id);

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
    final email = _currentEmail;
    final uid = (_currentUser?.id ?? '').trim();
    Map<String, dynamic>? found;
    if (uid.isNotEmpty) {
      for (final table in const <String>['client', 'client_artist']) {
        try {
          final rows = await _client
              .from(table)
              .select(columnsForProfileTable(table) ?? '*')
              .eq('id', uid)
              .limit(1);
          if (rows.isNotEmpty) {
            found = Map<String, dynamic>.from(rows.first as Map);
            break;
          }
        } catch (_) {}
      }
    }
    if (found == null && email.isNotEmpty) {
      found = await _supabaseFetchClientRowByEmail(email);
    }

    final data = found ?? const <String, dynamic>{};
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
      final artistEmail = widget.order.acceptedByArtistEmail
          .trim()
          .toLowerCase();
      final row = await _supabaseFetchOrderRow(
        widget.order.id,
        orderNumber: widget.order.orderNumber,
      );
      final data = row ?? const <String, dynamic>{};
      final payload = _asMap(data['payload']);
      final details = _asMap(data['details']);
      double? previousRatingValue;
      previousRatingValue =
          _asDouble(data['client_rating']) ??
          _asDouble(data['clientRating']) ??
          _asDouble(_asMap(payload['clientReview'])['rating']);
      final nowIso = DateTime.now().toIso8601String();
      final reviewMap = <String, dynamic>{
        'rating': _rating,
        'comment': comment,
        'submittedAt': nowIso,
      };
      final tipMap = <String, dynamic>{
        'amount': tipAmount,
        'percent': tipPercent,
        'customAmount': customTipAmount,
        'fundingSource': 'bank_account',
        'submittedAt': tipAmount > 0 ? nowIso : null,
      };
      await _client
          .from('company_custom_requests')
          .update({
            'client_rating': _rating,
            'rating': _rating,
            'clientReviewText': comment,
            'client_review_text': comment,
            'reviewText': comment,
            'review_text': comment,
            'clientReviewSubmittedAt': nowIso,
            'client_review_submitted_at': nowIso,
            'reviewSubmittedAt': nowIso,
            'review_submitted_at': nowIso,
            'clientTipAmount': tipAmount,
            'clientTipPercent': tipPercent,
            'clientTipCustomAmount': customTipAmount,
            'clientTipSubmittedAt': tipAmount > 0 ? nowIso : null,
            'updatedAt': nowIso,
            'updated_at': nowIso,
            'clientReview': reviewMap,
            'clientReviewPrompt': _asMap(payload['clientReviewPrompt']),
            'clientTip': tipMap,
            'payload': {
              ...payload,
              'clientReview': reviewMap,
              'clientTip': tipMap,
              'clientRating': _rating,
              'rating': _rating,
              'clientReviewText': comment,
              'reviewText': comment,
              'clientReviewSubmittedAt': nowIso,
              'reviewSubmittedAt': nowIso,
              'updatedAt': nowIso,
              'updated_at': nowIso,
            },
            'details': {
              ...details,
              'clientReview': reviewMap,
              'clientTip': tipMap,
              'clientRating': _rating,
              'rating': _rating,
              'clientReviewText': comment,
              'reviewText': comment,
              'clientReviewSubmittedAt': nowIso,
              'reviewSubmittedAt': nowIso,
              'updatedAt': nowIso,
              'updated_at': nowIso,
            },
          })
          .eq('id', widget.order.id);

      await bestEffort(() async {
        final artistRow = await _supabaseFetchArtistRowByEmail(artistEmail);
        if (artistRow == null) return;
        final artistData = artistRow;
        final stats = _asMap(artistData['stats']);
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
        final update = {
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
          'updatedAt': nowIso,
          'updated_at': nowIso,
        };
        final artistId = _firstNonEmpty([
          artistData['id'],
          artistData['artist_id'],
          artistData['client_artist_id'],
        ]);
        if (artistId.isNotEmpty) {
          for (final table in const <String>['artist', 'client_artist']) {
            try {
              await _client.from(table).update(update).eq('id', artistId);
            } catch (_) {}
          }
        }
      });

      if (tipAmount > 0) {
        await bestEffort(() async {
          await _client.from('tip_payout_queue').insert({
            'order_id': widget.order.id,
            'orderId': widget.order.id,
            'order_number': widget.order.orderNumber,
            'orderNumber': widget.order.orderNumber,
            'source_collection': _orderCollection,
            'sourceCollection': _orderCollection,
            'artist_email': artistEmail,
            'artistEmail': artistEmail,
            'artist_name': widget.order.artistName,
            'artistName': widget.order.artistName,
            'client_email': _currentEmail,
            'clientEmail': _currentEmail,
            'tip_amount': tipAmount,
            'tipAmount': tipAmount,
            'tip_percent': tipPercent,
            'tipPercent': tipPercent,
            'custom_tip_amount': customTipAmount,
            'customTipAmount': customTipAmount,
            'funding_source': 'bank_account',
            'fundingSource': 'bank_account',
            'status': 'queued',
            'created_at': nowIso,
            'createdAt': nowIso,
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
      final row = await _supabaseFetchOrderRow(
        widget.order.id,
        orderNumber: widget.order.orderNumber,
      );
      final data = row ?? const <String, dynamic>{};
      final payload = _asMap(data['payload']);
      final details = _asMap(data['details']);
      final review = _asMap(data['clientReview'])
        ..addAll(_asMap(payload['clientReview']));
      final tip = _asMap(data['clientTip'])
        ..addAll(_asMap(payload['clientTip']));
      final submittedAtRaw = _firstNonEmpty([
        data['client_review_submitted_at'],
        data['clientReviewSubmittedAt'],
        review['submittedAt'],
      ]);
      final submittedAt = _parseDate(submittedAtRaw);

      final latestRating =
          _asDouble(data['clientRating']) ??
          _asDouble(data['client_rating']) ??
          _asDouble(review['rating']) ??
          _rating;
      final latestComment =
          (data['client_review_text'] ??
                  data['clientReviewText'] ??
                  review['comment'] ??
                  details['clientReviewText'] ??
                  '')
              .toString()
              .trim();
      final latestTipAmount =
          _asDouble(data['clientTipAmount']) ??
          _asDouble(data['client_tip_amount']) ??
          _asDouble(tip['amount']) ??
          0;
      final latestTipPercentRaw =
          data['clientTipPercent'] ??
          data['client_tip_percent'] ??
          tip['percent'];
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
                            color: AppColors.blackCat.withValues(alpha: 0.62),
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
                                color: AppColors.blackCat.withValues(
                                  alpha: 0.08,
                                ),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                color: AppColors.blackCat.withValues(
                                  alpha: 0.08,
                                ),
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
                                  color: AppColors.blackCat.withValues(
                                    alpha: 0.08,
                                  ),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.zero,
                                borderSide: BorderSide(
                                  color: AppColors.blackCat.withValues(
                                    alpha: 0.08,
                                  ),
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
            color: AppColors.blackCat.withValues(alpha: 0.62),
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
