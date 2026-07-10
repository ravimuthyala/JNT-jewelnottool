import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClientCustomRequestRepository {
  static final Map<String, String> _resolvedPhotoRefCache = <String, String>{};
  static final Set<String> _missingPhotoRefCache = <String>{};
  static final Map<String, Future<String>> _inflightPhotoRefResolvers =
      <String, Future<String>>{};

  static String _generateClientOrderNumber(String docId) {
    final digits = docId.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 5) {
      return 'CR-${digits.substring(digits.length - 5)}';
    }
    final hash = docId.codeUnits.fold<int>(
      0,
      (acc, ch) => (acc * 31 + ch) % 100000,
    );
    return 'CR-${hash.toString().padLeft(5, '0')}';
  }

  static Future<String> createRequest({
    required Map<String, dynamic> summary,
    required Map<String, dynamic> details,
  }) async {
    final supabase = Supabase.instance.client;
    final nowIso = DateTime.now().toIso8601String();

    final orderNumber =
        (summary['orderNumber'] as String?)?.trim().isNotEmpty == true
        ? (summary['orderNumber'] as String).trim()
        : _generateClientOrderNumber(
            DateTime.now().microsecondsSinceEpoch.toString(),
          );

    final enrichedSummary = <String, dynamic>{
      ...summary,
      'orderNumber': orderNumber,
      'sourceCollection': 'Client_Custom_Requests',
      'admin': <String, dynamic>{
        ...((summary['admin'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{}),
        'orderNumber': orderNumber,
      },
    };

    final enrichedDetails = <String, dynamic>{
      ...details,
      'orderNumber': orderNumber,
      'sourceCollection': 'Client_Custom_Requests',
      'admin': <String, dynamic>{
        ...((details['admin'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{}),
        'orderNumber': orderNumber,
      },
    };

    String textFrom(List<Object?> values) {
      for (final value in values) {
        final text = (value ?? '').toString().trim();
        if (text.isNotEmpty) return text;
      }
      return '';
    }

    int? intFrom(Object? value) {
      if (value is int) return value;
      if (value is num) return value.round();
      return int.tryParse((value ?? '').toString().trim());
    }

    bool boolFrom(Object? value, {bool fallback = false}) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      final text = (value ?? '').toString().trim().toLowerCase();
      if (text == 'true' || text == 'yes' || text == '1') return true;
      if (text == 'false' || text == 'no' || text == '0') return false;
      return fallback;
    }

    List<dynamic> listFrom(Object? value) {
      if (value is List) return List<dynamic>.from(value);
      if (value == null) return const <dynamic>[];
      return <dynamic>[value];
    }

    final requestDetails = <String, dynamic>{
      ..._asMap(summary['requestDetails']),
      ..._asMap(details['requestDetails']),
    };
    final order = <String, dynamic>{
      ..._asMap(summary['order']),
      ..._asMap(details['order']),
    };
    final nailPrefs = <String, dynamic>{
      ..._asMap(summary['nailPreferences']),
      ..._asMap(details['nailPreferences']),
      ..._asMap(requestDetails['nailPreferences']),
    };
    final shipping = <String, dynamic>{
      ..._asMap(summary['shipping']),
      ..._asMap(details['shipping']),
    };

    final clientEmail = textFrom([
      summary['clientEmail'],
      details['clientEmail'],
      requestDetails['clientEmail'],
      summary['email'],
    ]).toLowerCase();

    final clientName = textFrom([
      summary['clientName'],
      details['clientName'],
      requestDetails['clientName'],
      summary['name'],
    ]);

    final inspiration = _collectPhotoRefs(<Object?>[
      summary['inspirationPhotos'],
      details['inspirationPhotos'],
      requestDetails['inspirationPhotos'],
      summary['brandInspirationPhotos'],
      details['brandInspirationPhotos'],
      requestDetails['brandInspirationPhotos'],
    ]);

    final row = <String, dynamic>{
      'order_number': orderNumber,
      'request_number': orderNumber,
      'client_request_number': orderNumber,
      'source_collection': 'Client_Custom_Requests',
      'request_type': textFrom([
        summary['requestType'],
        details['requestType'],
        requestDetails['requestType'],
        'clientCustomRequest',
      ]),
      'order_type': textFrom([
        summary['orderType'],
        details['orderType'],
        order['type'],
        'single',
      ]),
      'status': textFrom([summary['status'], details['status'], 'pending']),
      'client_status': textFrom([
        summary['clientStatus'],
        details['clientStatus'],
        'pending',
      ]),
      'artist_status': textFrom([
        summary['artistStatus'],
        details['artistStatus'],
        'in_review',
      ]),
      'client_email': clientEmail,
      'client_name': clientName,
      'selected_artist': textFrom([
        summary['selectedArtist'],
        details['selectedArtist'],
        order['selectedArtist'],
      ]),
      'selected_artist_email': textFrom([
        summary['selectedArtistEmail'],
        details['selectedArtistEmail'],
        order['selectedArtistEmail'],
      ]).toLowerCase(),
      'description': textFrom([
        requestDetails['description'],
        details['description'],
        summary['description'],
      ]),
      'description_preview': textFrom([
        summary['descriptionPreview'],
        details['descriptionPreview'],
        requestDetails['descriptionPreview'],
      ]),
      'need_by': toDateTime(
        requestDetails['needBy'] ?? details['needBy'] ?? summary['needBy'],
      )?.toIso8601String(),
      'need_by_display': textFrom([
        requestDetails['needByDisplay'],
        details['needByDisplay'],
        summary['needByDisplay'],
      ]),
      'budget_min': intFrom(
        _asMap(details['budget'])['min'] ??
            _asMap(summary['budget'])['min'] ??
            details['budgetMin'] ??
            summary['budgetMin'],
      ),
      'budget_max': intFrom(
        _asMap(details['budget'])['max'] ??
            _asMap(summary['budget'])['max'] ??
            details['budgetMax'] ??
            summary['budgetMax'],
      ),
      'nail_shape': textFrom([nailPrefs['shape'], summary['nailShape']]),
      'nail_length': textFrom([nailPrefs['length'], summary['nailLength']]),
      'nail_preferences': nailPrefs,
      'shipping': shipping,
      'is_direct_request': boolFrom(
        summary['isDirectRequest'] ?? details['isDirectRequest'],
      ),
      'fallback_to_pool': boolFrom(
        summary['fallbackToPool'] ?? details['fallbackToPool'],
        fallback: true,
      ),
      'is_group_order': textFrom([
            summary['orderType'],
            details['orderType'],
            order['type'],
          ]).toLowerCase() ==
          'group',
      'group_clients': listFrom(
        summary['groupClients'] ?? details['groupClients'] ?? order['clients'],
      ),
      'group_client_count': listFrom(
        summary['groupClients'] ?? details['groupClients'] ?? order['clients'],
      ).length,
      'inspiration_photos': inspiration,
      'photo_count': inspiration.length,
      'has_inspiration_photos': inspiration.isNotEmpty,
      'summary': enrichedSummary,
      'details': enrichedDetails,
      'payload': {
        ...enrichedDetails,
        'summary': enrichedSummary,
        'requestDetails': requestDetails,
      },
      'request_details': requestDetails,
      'created_at': nowIso,
      'updated_at': nowIso,
    };

    row.removeWhere((_, value) => value == null);

    final inserted = await supabase
        .from('client_custom_requests')
        .insert(row)
        .select('id')
        .single();

    final requestId = inserted['id'].toString();

    await supabase.from('client_custom_requests_details').insert({
      'request_id': requestId,
      'detail_key': 'payload',
      'data': {
        ...enrichedDetails,
        'payload': row['payload'],
        'requestDetails': requestDetails,
      },
      'created_at': nowIso,
      'updated_at': nowIso,
    });

    return requestId;
  }

  static Stream<List<SubmittedClientRequestSummary>> watchRequestsForClient({
    required String clientEmail,
    String? alternateClientEmail,
    String? clientName,
    String? userUid,
  }) {
    final email = clientEmail.trim().toLowerCase();
    final alternateEmail = (alternateClientEmail ?? '').trim().toLowerCase();
    final candidateEmails = <String>{email, alternateEmail}
        .where((e) => e.isNotEmpty)
        .toSet();
    final name = (clientName ?? '').trim().toLowerCase();
    final uid = (userUid ?? '').trim();
    final controller = StreamController<List<SubmittedClientRequestSummary>>();
    final supabase = Supabase.instance.client;
    final channels = <RealtimeChannel>[];
    var disposed = false;
    var loading = false;
    var reloadPending = false;

    Map<String, dynamic> asMap(dynamic value) => _asMap(value);

    Future<Set<String>> resolveCandidateClientIds() async {
      final ids = <String>{};
      for (final table in const <String>['client', 'client_artist']) {
        for (final candidateEmail in candidateEmails) {
          try {
            final rows = await supabase
                .from(table)
                .select('id,email')
                .ilike('email', candidateEmail)
                .limit(1);
            if (rows.isNotEmpty) {
              ids.add(rows.first['id'].toString().trim().toLowerCase());
            }
          } catch (_) {}
        }
      }
      return ids;
    }

    bool matchesWithData(
      Map<String, dynamic> data,
      String sourceCollection,
      Set<String> candidateClientIds,
    ) {
      final requestType = _firstNonEmptyString([
        data['request_type'],
        data['requestType'],
        asMap(data['summary'])['requestType'],
        asMap(data['payload'])['requestType'],
      ]).toLowerCase();

      final typeMatches = sourceCollection == 'Company_Custom_Requests'
          ? <String>{
              '',
              'companycustomrequest',
              'company_custom_request',
              'brandcustomrequest',
              'brandrequest',
              'direct',
              'direct to client',
              'direct to artist',
              'standard',
              'customrequest',
            }.contains(requestType)
          : <String>{
              '',
              'clientcustomrequest',
              'client_custom_request',
              'customrequest',
              'standard',
            }.contains(requestType);
      if (!typeMatches) return false;

      final docEmail = _firstNonEmptyString([
        data['client_email'],
        data['clientEmail'],
        asMap(data['summary'])['clientEmail'],
        asMap(data['payload'])['clientEmail'],
      ]).toLowerCase();
      final requesterEmail = _firstNonEmptyString([
        data['requester_email'],
        data['requesterEmail'],
      ]).toLowerCase();
      final legacyEmail = _firstNonEmptyString([data['email']]).toLowerCase();
      final companyEmail = _firstNonEmptyString([
        data['company_email'],
        data['companyEmail'],
      ]).toLowerCase();
      final docName = _firstNonEmptyString([
        data['client_name'],
        data['clientName'],
        data['company_name'],
        data['companyName'],
      ]).toLowerCase();
      final docUid = _firstNonEmptyString([
        data['client_id'],
        data['client_uid'],
        data['company_uid'],
        data['companyUid'],
        data['requester_uid'],
        data['requesterUid'],
        data['created_by_uid'],
        data['createdByUid'],
        data['uid'],
      ]);
      final acceptedByClientEmail = _firstNonEmptyString([
        data['accepted_by_client_email'],
        data['acceptedByClientEmail'],
      ]).toLowerCase();
      final declinedByClientEmails = <String>{
        ...((data['declined_by_client_emails'] as List?) ?? const [])
            .map((e) => e.toString().trim().toLowerCase())
            .where((e) => e.isNotEmpty),
        ...((data['declinedByClientEmails'] as List?) ?? const [])
            .map((e) => e.toString().trim().toLowerCase())
            .where((e) => e.isNotEmpty),
      };

      final groupClientEmails = <String>{};
      final groupClientIds = <String>{};
      final groupClientNames = <String>{};

      void ingestClients(List<dynamic> clients) {
        for (final rawClient in clients) {
          if (rawClient is! Map) continue;
          final map = Map<String, dynamic>.from(rawClient);
          final groupClientId = _firstNonEmptyString([
            map['client_id'],
            map['clientId'],
          ]).toLowerCase();
          final groupEmail = _firstNonEmptyString([
            map['client_email'],
            map['clientEmail'],
          ]).toLowerCase();
          final groupName = _firstNonEmptyString([
            map['client_name'],
            map['clientName'],
            map['name'],
          ]).toLowerCase();
          if (groupEmail.isNotEmpty) groupClientEmails.add(groupEmail);
          if (groupClientId.isNotEmpty) groupClientIds.add(groupClientId);
          if (groupName.isNotEmpty) groupClientNames.add(groupName);
        }
      }

      ingestClients((data['group_clients'] as List?)?.cast<dynamic>() ?? const []);
      ingestClients((data['groupClients'] as List?)?.cast<dynamic>() ?? const []);
      ingestClients((asMap(data['groupOrder'])['clients'] as List?)?.cast<dynamic>() ?? const []);
      ingestClients((asMap(asMap(data['details'])['groupOrder'])['clients'] as List?)?.cast<dynamic>() ?? const []);
      ingestClients((asMap(asMap(data['payload'])['groupOrder'])['clients'] as List?)?.cast<dynamic>() ?? const []);

      return (uid.isNotEmpty && docUid == uid) ||
          candidateEmails.contains(docEmail) ||
          candidateEmails.contains(companyEmail) ||
          candidateEmails.contains(requesterEmail) ||
          candidateEmails.contains(legacyEmail) ||
          candidateEmails.contains(acceptedByClientEmail) ||
          declinedByClientEmails.any(candidateEmails.contains) ||
          groupClientEmails.any(candidateEmails.contains) ||
          groupClientIds.any(candidateClientIds.contains) ||
          (name.isNotEmpty && groupClientNames.contains(name)) ||
          (name.isNotEmpty && docName == name) ||
          (candidateEmails.isEmpty && name.isEmpty);
    }

    Future<Map<String, Map<String, dynamic>>> loadDetails(String table) async {
      final result = <String, Map<String, dynamic>>{};
      try {
        final rows = await supabase.from(table).select();
        for (final raw in rows) {
          final row = Map<String, dynamic>.from(raw);
          final requestId = (row['request_id'] ?? '').toString();
          if (requestId.isEmpty) continue;
          final data = _asMap(row['data']);
          if (data.isEmpty) continue;
          final detailKey = (row['detail_key'] ?? '').toString().trim();
          final existing = result[requestId] ?? <String, dynamic>{};
          final merged = <String, dynamic>{
            ...existing,
            ...data,
          };
          if (detailKey.isNotEmpty) {
            merged[detailKey] = <String, dynamic>{
              ..._asMap(existing[detailKey]),
              ...data,
            };
          }
          result[requestId] = merged;
        }
      } catch (_) {}
      return result;
    }

    Future<void> loadAndEmit() async {
      if (disposed || loading) return;
      loading = true;
      try {
        final candidateClientIds = await resolveCandidateClientIds();
        final clientDetails = await loadDetails('client_custom_requests_details');
        final companyDetails = await loadDetails('company_custom_requests_details');

        Future<List<Map<String, dynamic>>> fetchRows(
          String table,
          String sourceCollection,
          Map<String, Map<String, dynamic>> detailsById,
        ) async {
          final rows = await supabase.from(table).select().order('updated_at', ascending: false);
          final out = <Map<String, dynamic>>[];
          for (final raw in rows) {
            final row = Map<String, dynamic>.from(raw);
            row['source_collection'] = sourceCollection;
            row['sourceCollection'] = sourceCollection;
            final id = (row['id'] ?? '').toString();
            final detail = detailsById[id];
            if (detail != null && detail.isNotEmpty) {
              final mergedDetails = <String, dynamic>{
                ..._asMap(row['details']),
                ...detail,
              };
              final mergedPayload = <String, dynamic>{
                ..._asMap(row['payload']),
                ..._asMap(detail['payload']),
                ...detail,
              };
              row['details'] = mergedDetails;
              row['payload'] = mergedPayload;
            }
            if (matchesWithData(row, sourceCollection, candidateClientIds)) {
              out.add(row);
            }
          }
          return out;
        }

        final rows = <Map<String, dynamic>>[
          ...await fetchRows(
            'client_custom_requests',
            'Client_Custom_Requests',
            clientDetails,
          ),
          ...await fetchRows(
            'company_custom_requests',
            'Company_Custom_Requests',
            companyDetails,
          ),
        ];

        final items = <SubmittedClientRequestSummary>[];
        for (final row in rows) {
          try {
            items.add(await SubmittedClientRequestSummary.fromSupabaseRow(row));
          } catch (_) {}
        }
        items.sort((a, b) {
          final ad = a.clientSubmittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bd = b.clientSubmittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bd.compareTo(ad);
        });
        if (!disposed) controller.add(items);
      } catch (e, st) {
        if (!disposed) controller.addError(e, st);
      } finally {
        loading = false;
        if (reloadPending && !disposed) {
          reloadPending = false;
          unawaited(loadAndEmit());
        }
      }
    }

    void scheduleReload() {
      if (disposed) return;
      if (loading) {
        reloadPending = true;
        return;
      }
      unawaited(loadAndEmit());
    }

    unawaited(loadAndEmit());

    for (final table in const <String>[
      'client_custom_requests',
      'company_custom_requests',
      'client_custom_requests_details',
      'company_custom_requests_details',
    ]) {
      channels.add(
        supabase
            .channel('client-requests-watch-$table-${identityHashCode(controller)}')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: table,
              callback: (_) => scheduleReload(),
            )
            .subscribe(),
      );
    }

    controller.onCancel = () async {
      disposed = true;
      for (final channel in channels) {
        await supabase.removeChannel(channel);
      }
    };

    return controller.stream;
  }

  static Future<String> resolvePhotoRef(String raw) async {
    final ref = _decodeUriSafelyRepeatedly(raw).trim();
    if (ref.isEmpty) return '';
    final cached = _resolvedPhotoRefCache[ref];
    if (cached != null) return cached;
    if (_missingPhotoRefCache.contains(ref)) return '';
    if (_isRenderableImageRef(ref)) {
      if (await _storageObjectExists(ref)) {
        return ref;
      }
      _missingPhotoRefCache.add(ref);
      return '';
    }
    final inflight = _inflightPhotoRefResolvers[ref];
    if (inflight != null) return inflight;

    final future = () async {
      final normalized = ref.startsWith('/') ? ref.substring(1) : ref;
      final bucketCandidates = <String>[
        'request-inspiration-photos',
        'client-custom-requests',
        'company-custom-requests',
        'client_custom_requests',
        'company_custom_requests',
        'request-chat-attachments',
      ];

      String cleanPath = normalized;
      if (cleanPath.startsWith('gs://')) {
        final withoutScheme = cleanPath.substring(5);
        final slash = withoutScheme.indexOf('/');
        if (slash >= 0) cleanPath = withoutScheme.substring(slash + 1);
      }

      for (final bucket in bucketCandidates) {
        var path = cleanPath;
        if (path.startsWith('$bucket/')) {
          path = path.substring(bucket.length + 1);
        }
        if (path.trim().isEmpty) continue;
        try {
          final url = Supabase.instance.client.storage.from(bucket).getPublicUrl(path);
          if (url.trim().isNotEmpty && await _storageObjectExists(url)) {
            _resolvedPhotoRefCache[ref] = url;
            return url;
          }
        } catch (_) {}
      }

      _missingPhotoRefCache.add(ref);
      return '';
    }();

    _inflightPhotoRefResolvers[ref] = future;
    try {
      return await future;
    } finally {
      _inflightPhotoRefResolvers.remove(ref);
    }
  }

  static Future<List<String>> resolvePhotoRefs(List<String> refs) async {
    final resolved = await Future.wait(refs.map(resolvePhotoRef));
    return resolved.where((e) => e.trim().isNotEmpty).toList(growable: false);
  }

  static Future<bool> _storageObjectExists(String raw) async {
    final parsed = _parseStorageReference(raw);
    if (parsed == null) return true;
    final objectPath = parsed.objectPath.trim();
    if (objectPath.isEmpty) return false;
    final lastSlash = objectPath.lastIndexOf('/');
    final folder = lastSlash >= 0 ? objectPath.substring(0, lastSlash) : '';
    final fileName = lastSlash >= 0
        ? objectPath.substring(lastSlash + 1)
        : objectPath;
    if (fileName.isEmpty) return false;
    try {
      final items = await Supabase.instance.client.storage
          .from(parsed.bucket)
          .list(path: folder);
      for (final item in items) {
        final name = (() {
          try {
            return item.name.toString().trim();
          } catch (_) {
            return '';
          }
        })();
        if (name == fileName) return true;
      }
    } catch (_) {}
    return false;
  }

  static ({String bucket, String objectPath})? _parseStorageReference(
    String raw,
  ) {
    var value = raw.trim();
    if (value.isEmpty) return null;

    if (value.startsWith('gs://')) {
      value = value.substring(5);
      final slash = value.indexOf('/');
      if (slash < 0 || slash + 1 >= value.length) return null;
      return (
        bucket: value.substring(0, slash),
        objectPath: value.substring(slash + 1),
      );
    }

    if (value.startsWith('storage/v1/object/public/')) {
      value = value.substring('storage/v1/object/public/'.length);
    }

    if (value.startsWith('http://') || value.startsWith('https://')) {
      final uri = Uri.tryParse(value);
      if (uri == null) return null;
      if (!uri.host.contains('supabase.co')) return null;
      final segments = uri.pathSegments;
      final index = segments.indexOf('public');
      if (index >= 0 && index + 2 <= segments.length) {
        final bucket = segments[index + 1];
        final objectPath = Uri.decodeComponent(
          segments.sublist(index + 2).join('/'),
        );
        if (bucket.isNotEmpty && objectPath.isNotEmpty) {
          return (bucket: bucket, objectPath: objectPath);
        }
      }
      return null;
    }

    value = value.replaceAll(RegExp(r'^/+'), '');
    final parts = value.split('/');
    if (parts.length < 2) return null;
    return (bucket: parts.first, objectPath: parts.skip(1).join('/'));
  }

  static String _decodeUriSafelyRepeatedly(String value) {
    var current = value.trim();
    for (var i = 0; i < 3; i++) {
      final decoded = Uri.decodeFull(current);
      if (decoded == current) break;
      current = decoded;
    }
    return current;
  }

  static bool _isRenderableImageRef(String value) {
    final v = value.trim();
    if (v.isEmpty) return false;
    if (v.startsWith('http://') || v.startsWith('https://')) return true;
    if (v.startsWith('data:')) return true;
    if (v.startsWith('blob:')) return true;
    if (v.startsWith('assets/')) return true;
    if (v.startsWith('content://')) return true;
    if (!kIsWeb && (v.startsWith('file://') || v.startsWith('/'))) return true;
    return false;
  }
}

Future<List<String>> _recoverBrandRequestPhotos({
  required String companyUid,
  required String requestId,
}) async {
  final recovered = <String>[];
  final supabase = Supabase.instance.client;
  for (final bucket in const <String>[
    'request-inspiration-photos',
    'company-custom-requests',
    'client-custom-requests',
  ]) {
    for (final basePath in <String>[
      'company_custom_requests/$companyUid/$requestId',
      'client_custom_requests/$companyUid/$requestId',
      '$companyUid/$requestId',
    ]) {
      try {
        final listed = await supabase.storage.from(bucket).list(path: basePath);
        for (final item in listed) {
          final name = item.name.toLowerCase();
          final isImage = name.endsWith('.jpg') ||
              name.endsWith('.jpeg') ||
              name.endsWith('.png') ||
              name.endsWith('.webp') ||
              name.endsWith('.heic');
          if (!isImage) continue;
          final fullPath = '$basePath/${item.name}';
          final url = supabase.storage.from(bucket).getPublicUrl(fullPath);
          if (url.trim().isNotEmpty) recovered.add(url.trim());
        }
        if (recovered.isNotEmpty) return recovered.toList(growable: false);
      } catch (_) {}
    }
  }
  return recovered.toList(growable: false);
}

class SubmittedClientRequestSummary {
  const SubmittedClientRequestSummary({
    required this.id,
    required this.sourceCollection,
    required this.orderNumber,
    required this.status,
    required this.clientSubmittedAt,
    required this.needByDisplay,
    required this.needBy,
    required this.requestAcceptByDisplay,
    required this.requestAcceptBy,
    required this.descriptionPreview,
    required this.description,
    required this.campaignName,
    required this.contactName,
    required this.selectedArtist,
    required this.orderType,
    required this.groupClients,
    required this.cancelReason,
    required this.cancelledAt,
    required this.inspirationPhotos,
    required this.budgetMin,
    required this.budgetMax,
    required this.nailShape,
    required this.nailLength,
    required this.leftHandDimensions,
    required this.rightHandDimensions,
    required this.artistFinalAmount,
    required this.paymentStatus,
    required this.paymentLink,
    required this.paidAt,
    required this.clientProfileImage,
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
    required this.acceptedByClientEmail,
    required this.clientResponseStatus,
    required this.declinedByClientEmails,
    required this.declinedByArtistEmails,
    required this.directClientStatus,
    required this.acceptedByArtistName,
    required this.artistProfileImage,
    required this.clientRating,
    required this.clientReviewText,
    required this.clientReviewSubmittedAt,
    required this.shippedByCourier,
    required this.trackingNumber,
    required this.shippedAt,
    required this.deliveredAt,
  });

  final String id;
  final String sourceCollection;
  final String orderNumber;
  final String status;
  final DateTime? clientSubmittedAt;
  final String needByDisplay;
  final DateTime? needBy;
  final String requestAcceptByDisplay;
  final DateTime? requestAcceptBy;
  final String descriptionPreview;
  final String description;
  final String campaignName;
  final String contactName;
  final String selectedArtist;
  final String orderType;
  final List<SubmittedGroupClientSummary> groupClients;
  final String cancelReason;
  final DateTime? cancelledAt;
  final List<String> inspirationPhotos;
  final int? budgetMin;
  final int? budgetMax;
  final String nailShape;
  final String nailLength;
  final Map<String, String> leftHandDimensions;
  final Map<String, String> rightHandDimensions;
  final double? artistFinalAmount;
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
  final DateTime? designSubmittedAt;
  final DateTime? designApprovalDueAt;
  final DateTime? designReminderSentAt;
  final List<String> designPreviewPhotos;
  final String clientEmail;
  final String acceptedByArtistEmail;
  final String acceptedByClientEmail;
  final String clientResponseStatus;
  final List<String> declinedByClientEmails;
  final List<String> declinedByArtistEmails;
  final String directClientStatus;
  final String acceptedByArtistName;
  final String artistProfileImage;
  final double? clientRating;
  final String clientReviewText;
  final DateTime? clientReviewSubmittedAt;
  final String shippedByCourier;
  final String trackingNumber;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;

  static Future<SubmittedClientRequestSummary> fromDocWithDetails(dynamic doc) async {
    final data = doc.data();
    final sourceCollection = doc.reference.parent.id;
    final submittedRaw = data['clientSubmittedAtLocal'];
    DateTime? submittedAt;
    if (submittedRaw is String && submittedRaw.isNotEmpty) {
      submittedAt = DateTime.tryParse(submittedRaw);
    } else {
      submittedAt = toDateTime(data['createdAt']);
    }

    final detailSnap = await doc.reference
        .collection('details')
        .doc('payload')
        .get();
    final detailData = detailSnap.data() ?? const <String, dynamic>{};
    final payloadData =
        (detailData['payload'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final requestDetails = <String, dynamic>{
      ...((payloadData['requestDetails'] as Map<String, dynamic>?) ??
          const <String, dynamic>{}),
      ...((detailData['requestDetails'] as Map<String, dynamic>?) ??
          const <String, dynamic>{}),
    };
    final orderDetails = <String, dynamic>{
      ...((payloadData['order'] as Map<String, dynamic>?) ??
          const <String, dynamic>{}),
      ...((detailData['order'] as Map<String, dynamic>?) ??
          const <String, dynamic>{}),
    };

    String firstNonEmpty(List<Object?> values, {String fallback = ''}) {
      for (final value in values) {
        final trimmed = (value ?? '').toString().trim();
        if (trimmed.isNotEmpty) return trimmed;
      }
      return fallback;
    }

    String canonicalOrderNumber(
      List<Object?> values, {
      required String sourceCollection,
    }) {
      final normalized = values
          .map((v) => (v ?? '').toString().trim())
          .where((v) => v.isNotEmpty)
          .toList(growable: false);
      if (normalized.isEmpty) return '';
      final preferredPrefixes = sourceCollection == 'Company_Custom_Requests'
          ? const <String>['BE-', 'BR-']
          : const <String>['CR-'];
      for (final prefix in preferredPrefixes) {
        for (final value in normalized) {
          if (value.toUpperCase().startsWith(prefix)) return value;
        }
      }
      return normalized.first;
    }

    final descriptionPreview = firstNonEmpty([data['descriptionPreview']]);
    final fullDescription = firstNonEmpty([
      requestDetails['description'],
      data['description'],
      descriptionPreview,
    ]);
    final campaignName = firstNonEmpty([
      requestDetails['campaignName'],
      requestDetails['campaign'],
      requestDetails['requestTitle'],
      requestDetails['title'],
      detailData['campaignName'],
      detailData['campaign'],
      detailData['requestTitle'],
      detailData['title'],
      data['campaignName'],
      data['campaign'],
      data['requestTitle'],
      data['title'],
      data['projectName'],
      data['collectionName'],
      descriptionPreview,
    ]);
    final contactName = firstNonEmpty([
      requestDetails['contactName'],
      requestDetails['contactPerson'],
      requestDetails['requesterName'],
      detailData['contactName'],
      detailData['contactPerson'],
      detailData['requesterName'],
      data['contactName'],
      data['contactPerson'],
      data['requesterName'],
      data['clientName'],
      data['companyName'],
    ]);
    final selectedArtist = firstNonEmpty([
      data['selectedArtist'],
      data['artistName'],
      data['artistDisplayName'],
      orderDetails['selectedArtist'],
    ], fallback: 'Artist');
    final orderType = firstNonEmpty([
      orderDetails['type'],
      detailData['orderType'],
      data['orderType'],
    ], fallback: 'single').toLowerCase();
    final cancellation =
        (detailData['cancellation'] as Map<String, dynamic>?) ??
        (requestDetails['cancellation'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final cancelReason = firstNonEmpty([
      data['cancelReason'],
      requestDetails['cancelReason'],
      cancellation['reason'],
    ]);
    final inspirationPhotosRawList = _collectPhotoRefs(<Object?>[
      payloadData['brandInspirationPhotos'],
      payloadData['inspirationPhotos'],
      payloadData['clientImages'],
      payloadData['photos'],
      payloadData['inspirationPhoto'],
      payloadData['inspirationPhotoUrl'],
      payloadData['inspirationPhotoUrls'],
      payloadData['inspirationPhotoRefs'],
      payloadData['previewImage'],
      payloadData['previewImageAsset'],
      detailData['brandInspirationPhotos'],
      (detailData['requestDetails']
          as Map<String, dynamic>?)?['brandInspirationPhotos'],
      (detailData['order'] as Map<String, dynamic>?)?['brandInspirationPhotos'],
      detailData['inspirationPhotos'],
      (detailData['requestDetails']
          as Map<String, dynamic>?)?['inspirationPhotos'],
      (detailData['requestDetails']
          as Map<String, dynamic>?)?['inspirationPhotoUrls'],
      (detailData['requestDetails']
          as Map<String, dynamic>?)?['inspirationPhotoRefs'],
      detailData['clientImages'],
      detailData['inspirationPhoto'],
      detailData['inspirationPhotoUrl'],
      requestDetails['inspirationPhotos'],
      requestDetails['brandInspirationPhotos'],
      requestDetails['clientImages'],
      requestDetails['inspirationPhoto'],
      requestDetails['inspirationPhotoUrl'],
      requestDetails['inspirationPhotoUrls'],
      requestDetails['inspirationPhotoRefs'],
      requestDetails['previewImage'],
      requestDetails['previewImageAsset'],
      orderDetails['inspirationPhotos'],
      orderDetails['clientImages'],
      orderDetails['inspirationPhoto'],
      orderDetails['inspirationPhotoUrl'],
      orderDetails['inspirationPhotoUrls'],
      orderDetails['inspirationPhotoRefs'],
      orderDetails['previewImage'],
      orderDetails['previewImageAsset'],
      data['brandInspirationPhotos'],
      data['inspirationPhotos'],
      data['clientImages'],
      data['inspirationPhoto'],
      data['inspirationPhotoUrl'],
      data['previewImage'],
      data['previewImageAsset'],
    ]);
    final inspirationPhotos =
        await ClientCustomRequestRepository.resolvePhotoRefs(
          inspirationPhotosRawList,
        );
    var resolvedInspirationPhotos = inspirationPhotos;
    if (resolvedInspirationPhotos.isEmpty) {
      final companyUid = firstNonEmpty([
        data['companyUid'],
        detailData['companyUid'],
        requestDetails['companyUid'],
      ]);
      if (companyUid.isNotEmpty) {
        resolvedInspirationPhotos = await _recoverBrandRequestPhotos(
          companyUid: companyUid,
          requestId: doc.id,
        );
      }
    }
    final profileSnapshot =
        (detailData['clientProfileSnapshot'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final basicSnapshot =
        (profileSnapshot['basic'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final clientProfileImageRaw = firstNonEmpty([
      data['clientProfileImage'],
      data['clientProfilePic'],
      data['companyProfileImage'],
      data['brandProfileImage'],
      data['companyLogoUrl'],
      data['brandLogoUrl'],
      data['logoUrl'],
      basicSnapshot['profileImageUrl'],
      basicSnapshot['avatarUrl'],
      basicSnapshot['profileImagePath'],
      basicSnapshot['profilePhotoUrl'],
      basicSnapshot['profilePhoto'],
    ]);
    final clientProfileImage =
        await ClientCustomRequestRepository.resolvePhotoRef(
          clientProfileImageRaw,
        );
    int? asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.round();
      return null;
    }

    double? asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse((v ?? '').toString());
    }

    final budgetObj =
        (detailData['budget'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final groupOrder =
        (detailData['groupOrder'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final groupClientsRaw =
        (orderDetails['clients'] as List<dynamic>?) ??
        (groupOrder['clients'] as List<dynamic>?) ??
        const <dynamic>[];
    final groupClients = await _parseGroupClients(groupClientsRaw);
    final budgetMin = asInt(budgetObj['min']) ?? asInt(data['budgetMin']);
    final budgetMax = asInt(budgetObj['max']) ?? asInt(data['budgetMax']);
    final artistQuote =
        (detailData['artistQuote'] as Map<String, dynamic>?) ??
        (data['artistQuote'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final payment =
        (detailData['payment'] as Map<String, dynamic>?) ??
        (data['payment'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final artistCompletion =
        (detailData['artistCompletion'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final designApproval =
        (detailData['designApproval'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final shipment =
        (detailData['shipment'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final artistFinalAmount =
        asDouble(artistQuote['total']) ?? asDouble(data['artistFinalAmount']);
    final paymentStatus = firstNonEmpty([
      payment['status'],
      data['paymentStatus'],
    ]).toLowerCase();
    final paymentLink = firstNonEmpty([
      payment['paymentLink'],
      data['paymentLink'],
    ]);
    final paidAt = toDateTime(payment['paidAt']) ?? toDateTime(data['paidAt']);

    final needByAt =
        toDateTime(data['needBy']) ??
        toDateTime(requestDetails['needBy']) ??
        toDateTime(detailData['needBy']);
    final requestAcceptByAt =
        toDateTime(data['requestAcceptBy']) ??
        toDateTime(requestDetails['requestAcceptBy']) ??
        toDateTime(detailData['requestAcceptBy']) ??
        (needByAt == null
            ? null
            : DateTime(
                needByAt.year,
                needByAt.month,
                needByAt.day,
              ).subtract(const Duration(days: 5)));
    String formatDateMmDdYyyy(DateTime date) {
      final mm = date.month.toString().padLeft(2, '0');
      final dd = date.day.toString().padLeft(2, '0');
      return '$mm/$dd/${date.year}';
    }

    final resolvedNeedByDisplay = firstNonEmpty([
      data['needByDisplay'],
      requestDetails['needByDisplay'],
      detailData['needByDisplay'],
    ]);
    final resolvedRequestAcceptByDisplay = firstNonEmpty([
      data['requestAcceptByDisplay'],
      requestDetails['requestAcceptByDisplay'],
      detailData['requestAcceptByDisplay'],
    ]);
    final cancelledAt =
        toDateTime(data['cancelledAt']) ??
        toDateTime(requestDetails['cancelledAt']) ??
        toDateTime(cancellation['cancelledAt']);

    final artistCompletedPhotosRaw =
        (artistCompletion['artistPhotos'] as List<dynamic>?) ??
        (detailData['artistCompletedPhotos'] as List<dynamic>?) ??
        (data['artistCompletedPhotos'] as List<dynamic>?) ??
        const [];
    final artistCompletedPhotos =
        await ClientCustomRequestRepository.resolvePhotoRefs(
          artistCompletedPhotosRaw
              .whereType<String>()
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(growable: false),
        );
    final completionReviewStatus = firstNonEmpty([
      data['completionReviewStatus'],
      artistCompletion['reviewStatus'],
    ]).toLowerCase();
    final completionDeclineReason = firstNonEmpty([
      data['completionDeclineReason'],
      artistCompletion['declineReason'],
    ]);
    final completionDeclineDescription = firstNonEmpty([
      data['completionDeclineDescription'],
      artistCompletion['declineDescription'],
    ]);
    final completionDeclinedAt =
        toDateTime(data['completionDeclinedAt']) ??
        toDateTime(artistCompletion['reviewedAt']) ??
        toDateTime(data['completionReviewedAt']);
    final designApprovalStatus = firstNonEmpty([
      data['designApprovalStatus'],
      data['clientDesignApprovalStatus'],
      designApproval['status'],
    ]).toLowerCase();
    final designApprovedAt =
        toDateTime(data['designApprovedAt']) ??
        toDateTime(data['clientDesignApprovedAt']) ??
        toDateTime(designApproval['approvedAt']);
    final designSubmittedAt =
        toDateTime(data['designSubmittedAt']) ??
        toDateTime(designApproval['submittedAt']) ??
        toDateTime(designApproval['createdAt']);
    final designApprovalDueAt =
        toDateTime(data['designApprovalDueAt']) ??
        toDateTime(designApproval['dueAt']);
    final designReminderSentAt =
        toDateTime(data['designReminderSentAt']) ??
        toDateTime(designApproval['reminderSentAt']);
    final designPreviewPhotosRaw =
        (data['designPreviewPhotos'] as List<dynamic>?) ??
        (designApproval['previewPhotos'] as List<dynamic>?) ??
        const [];
    final designPreviewPhotos =
        await ClientCustomRequestRepository.resolvePhotoRefs(
          designPreviewPhotosRaw
              .whereType<String>()
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(growable: false),
        );
    final acceptedByArtistEmail = firstNonEmpty([
      data['acceptedByArtistEmail'],
      (detailData['acceptance']
          as Map<String, dynamic>?)?['acceptedByArtistEmail'],
    ]).toLowerCase();
    final acceptedByClientEmail = firstNonEmpty([
      data['acceptedByClientEmail'],
      (detailData['acceptance']
          as Map<String, dynamic>?)?['acceptedByClientEmail'],
    ]).toLowerCase();
    final declinedByClientEmails = <String>{
      ...((data['declinedByClientEmails'] as List<dynamic>?) ??
              const <dynamic>[])
          .whereType<String>()
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty),
      ...((detailData['declinedByClientEmails'] as List<dynamic>?) ??
              const <dynamic>[])
          .whereType<String>()
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty),
    }.toList(growable: false);
    final declinedByArtistEmails = <String>{
      ...((data['declinedByArtistEmails'] as List<dynamic>?) ??
              const <dynamic>[])
          .whereType<String>()
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty),
      ...((detailData['declinedByArtistEmails'] as List<dynamic>?) ??
              const <dynamic>[])
          .whereType<String>()
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty),
    }.toList(growable: false);
    final selectedArtistEmail = firstNonEmpty([
      data['selectedArtistEmail'],
      orderDetails['selectedArtistEmail'],
      (detailData['acceptance']
          as Map<String, dynamic>?)?['selectedArtistEmail'],
    ]).toLowerCase();
    final artistIdentity = await _resolveArtistIdentity(
      detailData: detailData,
      data: data,
      selectedArtistName: selectedArtist,
      acceptedByArtistEmail: acceptedByArtistEmail,
      selectedArtistEmail: selectedArtistEmail,
    );
    final acceptedByArtistName = artistIdentity.name;
    final artistProfileImageRaw = artistIdentity.profileImageRef;
    final artistProfileImage =
        await ClientCustomRequestRepository.resolvePhotoRef(
          artistProfileImageRaw,
        );
    final clientReview =
        (detailData['clientReview'] as Map<String, dynamic>?) ??
        (data['clientReview'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final clientRating =
        asDouble(data['clientRating']) ?? asDouble(clientReview['rating']);
    final clientReviewText = firstNonEmpty([
      data['clientReviewText'],
      clientReview['comment'],
    ]);
    final clientReviewSubmittedAt =
        toDateTime(data['clientReviewSubmittedAt']) ??
        toDateTime(clientReview['submittedAt']);
    final shippedByCourier = firstNonEmpty([
      data['shippedByCourier'],
      shipment['courier'],
      data['shippingCarrier'],
    ]);
    final trackingNumber = firstNonEmpty([
      data['trackingNumber'],
      shipment['trackingNumber'],
      data['shippingLabelTrackingNumber'],
    ]);
    final shippedAt =
        toDateTime(data['shippedAt']) ?? toDateTime(shipment['shippedAt']);
    final deliveredAt =
        toDateTime(data['deliveredAt']) ?? toDateTime(shipment['deliveredAt']);

    final nailPrefs =
        (detailData['nailPreferences'] as Map<String, dynamic>?) ??
        (detailData['requestDetails']
                as Map<String, dynamic>?)?['nailPreferences']
            as Map<String, dynamic>? ??
        (requestDetails['nailPreferences'] as Map<String, dynamic>?) ??
        (data['nailPreferences'] as Map<String, dynamic>?) ??
        (data['requestDetails'] as Map<String, dynamic>?)?['nailPreferences']
            as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final nailShape = firstNonEmpty([nailPrefs['shape'], data['nailShape']]);
    final nailLength = firstNonEmpty([nailPrefs['length'], data['nailLength']]);
    final dims =
        (nailPrefs['dimensions'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};

    String dim(dynamic v) {
      if (v is num) {
        return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
      }
      final s = (v ?? '').toString().trim();
      return s.isEmpty ? '-' : s;
    }

    final left = <String, String>{
      'thumb': dim(dims['lThumb']),
      'index': dim(dims['lIndex']),
      'middle': dim(dims['lMiddle']),
      'ring': dim(dims['lRing']),
      'pinky': dim(dims['lPinky']),
    };
    final right = <String, String>{
      'thumb': dim(dims['rThumb']),
      'index': dim(dims['rIndex']),
      'middle': dim(dims['rMiddle']),
      'ring': dim(dims['rRing']),
      'pinky': dim(dims['rPinky']),
    };

    final isGroupOrder = orderType == 'group';
    final isBrandRequest = sourceCollection == 'Company_Custom_Requests';
    final rootStatus = firstNonEmpty([
      if (isGroupOrder) data['status'],
      if (isGroupOrder) detailData['status'],
      if (!isGroupOrder) data['clientResponseStatus'],
      if (!isGroupOrder) detailData['clientResponseStatus'],
      if (!isGroupOrder)
        (detailData['acceptance']
            as Map<String, dynamic>?)?['clientResponseStatus'],
      data['clientStatus'],
      (detailData['roleStatuses'] is Map
          ? (detailData['roleStatuses'] as Map)['client']
          : null),
      data['brandStatus'],
      detailData['brandStatus'],
    ], fallback: 'submitted').toLowerCase();
    final resolvedStatus =
        isBrandRequest &&
            (cancelledAt != null || rootStatus == 'cancelled') &&
            rootStatus != 'cancelled'
        ? 'cancelled'
        : rootStatus;

    return SubmittedClientRequestSummary(
      id: doc.id,
      sourceCollection: sourceCollection,
      orderNumber: canonicalOrderNumber([
        (data['admin'] is Map ? (data['admin'] as Map)['orderNumber'] : null),
        (detailData['admin'] is Map
            ? (detailData['admin'] as Map)['orderNumber']
            : null),
        data['orderNumber'],
        detailData['orderNumber'],
        data['orderNo'],
        data['orderId'],
      ], sourceCollection: sourceCollection),
      status: resolvedStatus,
      clientSubmittedAt: submittedAt,
      needByDisplay: resolvedNeedByDisplay.isNotEmpty
          ? resolvedNeedByDisplay
          : (needByAt == null ? '' : formatDateMmDdYyyy(needByAt)),
      needBy: needByAt,
      requestAcceptByDisplay: resolvedRequestAcceptByDisplay.isNotEmpty
          ? resolvedRequestAcceptByDisplay
          : (requestAcceptByAt == null
                ? ''
                : formatDateMmDdYyyy(requestAcceptByAt)),
      requestAcceptBy: requestAcceptByAt,
      descriptionPreview: descriptionPreview,
      description: fullDescription,
      campaignName: campaignName,
      contactName: contactName,
      selectedArtist: selectedArtist,
      orderType: orderType,
      groupClients: groupClients,
      cancelReason: cancelReason,
      cancelledAt: cancelledAt,
      inspirationPhotos: resolvedInspirationPhotos,
      budgetMin: budgetMin,
      budgetMax: budgetMax,
      nailShape: nailShape,
      nailLength: nailLength,
      leftHandDimensions: left,
      rightHandDimensions: right,
      artistFinalAmount: artistFinalAmount,
      paymentStatus: paymentStatus,
      paymentLink: paymentLink,
      paidAt: paidAt,
      clientProfileImage: clientProfileImage,
      artistCompletedPhotos: artistCompletedPhotos,
      completionReviewStatus: completionReviewStatus,
      completionDeclineReason: completionDeclineReason,
      completionDeclineDescription: completionDeclineDescription,
      completionDeclinedAt: completionDeclinedAt,
      designApprovalStatus: designApprovalStatus,
      designApprovedAt: designApprovedAt,
      designSubmittedAt: designSubmittedAt,
      designApprovalDueAt: designApprovalDueAt,
      designReminderSentAt: designReminderSentAt,
      designPreviewPhotos: designPreviewPhotos,
      clientEmail: firstNonEmpty([data['clientEmail']]).toLowerCase(),
      acceptedByArtistEmail: acceptedByArtistEmail,
      acceptedByClientEmail: acceptedByClientEmail,
      clientResponseStatus: firstNonEmpty([
        data['clientResponseStatus'],
        detailData['clientResponseStatus'],
        (detailData['acceptance']
            as Map<String, dynamic>?)?['clientResponseStatus'],
      ]).toLowerCase(),
      declinedByClientEmails: declinedByClientEmails,
      declinedByArtistEmails: declinedByArtistEmails,
      directClientStatus: firstNonEmpty([
        data['directClientStatus'],
        (detailData['routing'] is Map
            ? (detailData['routing'] as Map)['directClientStatus']
            : null),
      ]).toLowerCase(),
      acceptedByArtistName: acceptedByArtistName,
      artistProfileImage: artistProfileImage,
      clientRating: clientRating,
      clientReviewText: clientReviewText,
      clientReviewSubmittedAt: clientReviewSubmittedAt,
      shippedByCourier: shippedByCourier,
      trackingNumber: trackingNumber,
      shippedAt: shippedAt,
      deliveredAt: deliveredAt,
    );
  }

  static Future<SubmittedClientRequestSummary> fromSupabaseRow(
    Map<String, dynamic> row,
  ) async {
    final data = Map<String, dynamic>.from(row);
    final payloadData = _asMap(
      data['payload'] ?? data['summary'] ?? data['data'],
    );
    final detailData = _asMap(
      data['details'] ?? data['detail'] ?? data['meta'],
    );
    final sourceCollection =
        _firstNonEmptyString([
          data['source_collection'],
          data['sourceCollection'],
          payloadData['source_collection'],
          payloadData['sourceCollection'],
          detailData['source_collection'],
          detailData['sourceCollection'],
        ]).isNotEmpty
        ? _firstNonEmptyString([
            data['source_collection'],
            data['sourceCollection'],
            payloadData['source_collection'],
            payloadData['sourceCollection'],
            detailData['source_collection'],
            detailData['sourceCollection'],
          ])
        : 'Company_Custom_Requests';

    final requestDetails = <String, dynamic>{
      ..._asMap(payloadData['requestDetails']),
      ..._asMap(detailData['requestDetails']),
    };
    final orderDetails = <String, dynamic>{
      ..._asMap(payloadData['order']),
      ..._asMap(detailData['order']),
    };

    String firstNonEmpty(List<Object?> values, {String fallback = ''}) {
      for (final value in values) {
        final trimmed = (value ?? '').toString().trim();
        if (trimmed.isNotEmpty) return trimmed;
      }
      return fallback;
    }

    String canonicalOrderNumber(
      List<Object?> values, {
      required String sourceCollection,
    }) {
      final normalized = values
          .map((v) => (v ?? '').toString().trim())
          .where((v) => v.isNotEmpty)
          .toList(growable: false);
      if (normalized.isEmpty) return '';
      final preferredPrefixes = sourceCollection == 'Company_Custom_Requests'
          ? const <String>['BE-', 'BR-']
          : const <String>['CR-'];
      for (final prefix in preferredPrefixes) {
        for (final value in normalized) {
          if (value.toUpperCase().startsWith(prefix)) return value;
        }
      }
      return normalized.first;
    }

    final submittedRaw =
        data['client_submitted_at_local'] ?? data['clientSubmittedAtLocal'];
    DateTime? submittedAt;
    if (submittedRaw is String && submittedRaw.isNotEmpty) {
      submittedAt = DateTime.tryParse(submittedRaw);
    } else {
      submittedAt =
          toDateTime(data['created_at']) ??
          toDateTime(data['createdAt']) ??
          toDateTime(payloadData['createdAt']) ??
          toDateTime(detailData['createdAt']);
    }

    final descriptionPreview = firstNonEmpty([
      data['description_preview'],
      data['descriptionPreview'],
    ]);
    final fullDescription = firstNonEmpty([
      requestDetails['description'],
      data['description'],
      descriptionPreview,
    ]);
    final campaignName = firstNonEmpty([
      data['campaign_name'],
      data['campaignName'],
      requestDetails['campaignName'],
      requestDetails['campaign'],
      requestDetails['requestTitle'],
      requestDetails['title'],
      detailData['campaignName'],
      detailData['campaign'],
      detailData['requestTitle'],
      detailData['title'],
      payloadData['campaignName'],
      payloadData['campaign'],
      payloadData['requestTitle'],
      payloadData['title'],
      data['title'],
      data['projectName'],
      data['collectionName'],
      descriptionPreview,
    ]);
    final contactName = firstNonEmpty([
      data['contact_name'],
      data['contactName'],
      requestDetails['contactName'],
      requestDetails['contactPerson'],
      requestDetails['requesterName'],
      detailData['contactName'],
      detailData['contactPerson'],
      detailData['requesterName'],
      data['client_name'],
      data['clientName'],
      data['company_name'],
      data['companyName'],
      payloadData['contactName'],
      payloadData['contactPerson'],
      payloadData['requesterName'],
      payloadData['clientName'],
      payloadData['companyName'],
    ]);
    final selectedArtist = firstNonEmpty([
      data['selected_artist'],
      data['selectedArtist'],
      data['artist_name'],
      data['artistName'],
      data['artist_display_name'],
      data['artistDisplayName'],
      orderDetails['selectedArtist'],
    ], fallback: 'Artist');
    final orderType = firstNonEmpty([
      data['order_type'],
      data['orderType'],
      orderDetails['type'],
      detailData['orderType'],
    ], fallback: 'single').toLowerCase();
    final cancellation = _asMap(detailData['cancellation'])
      ..addAll(_asMap(requestDetails['cancellation']));
    final cancelReason = firstNonEmpty([
      data['cancel_reason'],
      data['cancelReason'],
      requestDetails['cancelReason'],
      cancellation['reason'],
    ]);
    final inspirationPhotosRawList = _collectPhotoRefs(<Object?>[
      payloadData['brand_inspiration_photos'],
      payloadData['brandInspirationPhotos'],
      payloadData['inspiration_photos'],
      payloadData['inspirationPhotos'],
      payloadData['clientImages'],
      payloadData['photos'],
      payloadData['previewImage'],
      payloadData['previewImageAsset'],
      detailData['brand_inspiration_photos'],
      detailData['brandInspirationPhotos'],
      (detailData['requestDetails']
          as Map<String, dynamic>?)?['brandInspirationPhotos'],
      detailData['inspiration_photos'],
      detailData['inspirationPhotos'],
      (detailData['requestDetails']
          as Map<String, dynamic>?)?['inspirationPhotos'],
      detailData['clientImages'],
      detailData['previewImage'],
      detailData['previewImageAsset'],
      requestDetails['brandInspirationPhotos'],
      requestDetails['inspirationPhotos'],
      requestDetails['clientImages'],
      requestDetails['previewImage'],
      requestDetails['previewImageAsset'],
      orderDetails['inspirationPhotos'],
      orderDetails['previewImage'],
      orderDetails['previewImageAsset'],
      data['brand_inspiration_photos'],
      data['brandInspirationPhotos'],
      data['inspiration_photos'],
      data['inspirationPhotos'],
      data['previewImage'],
      data['previewImageAsset'],
    ]);
    final inspirationPhotos =
        await ClientCustomRequestRepository.resolvePhotoRefs(
          inspirationPhotosRawList,
        );
    final profileSnapshot = _asMap(detailData['clientProfileSnapshot']);
    final basicSnapshot = _asMap(profileSnapshot['basic']);
    final clientProfileImageRaw = firstNonEmpty([
      data['client_profile_image'],
      data['clientProfileImage'],
      data['client_profile_pic'],
      data['clientProfilePic'],
      data['company_profile_image'],
      data['companyProfileImage'],
      data['brand_profile_image'],
      data['brandProfileImage'],
      data['company_logo_url'],
      data['companyLogoUrl'],
      data['brand_logo_url'],
      data['brandLogoUrl'],
      data['logo_url'],
      data['logoUrl'],
      basicSnapshot['profileImageUrl'],
      basicSnapshot['avatarUrl'],
      basicSnapshot['profileImagePath'],
      basicSnapshot['profilePhotoUrl'],
      basicSnapshot['profilePhoto'],
    ]);
    final clientProfileImage =
        await ClientCustomRequestRepository.resolvePhotoRef(
          clientProfileImageRaw,
        );
    int? asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.round();
      return null;
    }

    double? asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse((v ?? '').toString());
    }

    final budgetObj = _asMap(detailData['budget'])
      ..addAll(_asMap(payloadData['budget']));
    final groupOrder = _asMap(detailData['groupOrder'])
      ..addAll(_asMap(payloadData['groupOrder']));
    final groupClientsRaw =
        (orderDetails['clients'] as List<dynamic>?) ??
        (groupOrder['clients'] as List<dynamic>?) ??
        (data['group_clients'] as List<dynamic>?) ??
        (data['groupClients'] as List<dynamic>?) ??
        const <dynamic>[];
    final groupClients = await _parseGroupClients(groupClientsRaw);
    final budgetMin =
        asInt(budgetObj['min']) ??
        asInt(data['budget_min']) ??
        asInt(data['budgetMin']);
    final budgetMax =
        asInt(budgetObj['max']) ??
        asInt(data['budget_max']) ??
        asInt(data['budgetMax']);
    final artistQuote = _asMap(detailData['artistQuote'])
      ..addAll(_asMap(payloadData['artistQuote']));
    final payment = _asMap(detailData['payment'])
      ..addAll(_asMap(payloadData['payment']));
    final artistCompletion = _asMap(detailData['artistCompletion'])
      ..addAll(_asMap(payloadData['artistCompletion']));
    final designApproval = _asMap(detailData['designApproval'])
      ..addAll(_asMap(payloadData['designApproval']));
    final shipment = _asMap(detailData['shipment'])
      ..addAll(_asMap(payloadData['shipment']));
    final artistFinalAmount =
        asDouble(artistQuote['total']) ??
        asDouble(data['artist_final_amount']) ??
        asDouble(data['artistFinalAmount']);
    final paymentStatus = firstNonEmpty([
      payment['status'],
      data['payment_status'],
      data['paymentStatus'],
    ]).toLowerCase();
    final paymentLink = firstNonEmpty([
      payment['paymentLink'],
      data['payment_link'],
      data['paymentLink'],
    ]);
    final paidAt =
        toDateTime(payment['paidAt']) ??
        toDateTime(data['paid_at']) ??
        toDateTime(data['paidAt']);

    final needByAt =
        toDateTime(data['need_by']) ??
        toDateTime(data['needBy']) ??
        toDateTime(requestDetails['needBy']) ??
        toDateTime(detailData['needBy']) ??
        toDateTime(payloadData['needBy']);
    final requestAcceptByAt =
        toDateTime(data['request_accept_by']) ??
        toDateTime(data['requestAcceptBy']) ??
        toDateTime(requestDetails['requestAcceptBy']) ??
        toDateTime(detailData['requestAcceptBy']) ??
        toDateTime(payloadData['requestAcceptBy']) ??
        (needByAt == null
            ? null
            : DateTime(
                needByAt.year,
                needByAt.month,
                needByAt.day,
              ).subtract(const Duration(days: 5)));
    String formatDateMmDdYyyy(DateTime date) {
      final mm = date.month.toString().padLeft(2, '0');
      final dd = date.day.toString().padLeft(2, '0');
      return '$mm/$dd/${date.year}';
    }

    final resolvedNeedByDisplay = firstNonEmpty([
      data['need_by_display'],
      data['needByDisplay'],
      requestDetails['needByDisplay'],
      detailData['needByDisplay'],
    ]);
    final resolvedRequestAcceptByDisplay = firstNonEmpty([
      data['request_accept_by_display'],
      data['requestAcceptByDisplay'],
      requestDetails['requestAcceptByDisplay'],
      detailData['requestAcceptByDisplay'],
    ]);
    final cancelledAt =
        toDateTime(data['cancelled_at']) ??
        toDateTime(data['cancelledAt']) ??
        toDateTime(requestDetails['cancelledAt']) ??
        toDateTime(cancellation['cancelledAt']);

    final artistCompletedPhotosRaw =
        (artistCompletion['artistPhotos'] as List<dynamic>?) ??
        (detailData['artistCompletedPhotos'] as List<dynamic>?) ??
        (data['artist_completed_photos'] as List<dynamic>?) ??
        (data['artistCompletedPhotos'] as List<dynamic>?) ??
        const [];
    final artistCompletedPhotos =
        await ClientCustomRequestRepository.resolvePhotoRefs(
          artistCompletedPhotosRaw
              .whereType<String>()
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(growable: false),
        );
    final completionReviewStatus = firstNonEmpty([
      data['completion_review_status'],
      data['completionReviewStatus'],
      artistCompletion['reviewStatus'],
    ]).toLowerCase();
    final completionDeclineReason = firstNonEmpty([
      data['completion_decline_reason'],
      data['completionDeclineReason'],
      artistCompletion['declineReason'],
    ]);
    final completionDeclineDescription = firstNonEmpty([
      data['completion_decline_description'],
      data['completionDeclineDescription'],
      artistCompletion['declineDescription'],
    ]);
    final completionDeclinedAt =
        toDateTime(data['completion_declined_at']) ??
        toDateTime(data['completionDeclinedAt']) ??
        toDateTime(artistCompletion['reviewedAt']) ??
        toDateTime(data['completionReviewedAt']);
    final designApprovalStatus = firstNonEmpty([
      data['design_approval_status'],
      data['designApprovalStatus'],
      data['clientDesignApprovalStatus'],
      designApproval['status'],
    ]).toLowerCase();
    final designApprovedAt =
        toDateTime(data['design_approved_at']) ??
        toDateTime(data['designApprovedAt']) ??
        toDateTime(data['clientDesignApprovedAt']) ??
        toDateTime(designApproval['approvedAt']);
    final designSubmittedAt =
        toDateTime(data['design_submitted_at']) ??
        toDateTime(data['designSubmittedAt']) ??
        toDateTime(designApproval['submittedAt']) ??
        toDateTime(designApproval['createdAt']);
    final designApprovalDueAt =
        toDateTime(data['design_approval_due_at']) ??
        toDateTime(data['designApprovalDueAt']) ??
        toDateTime(designApproval['dueAt']);
    final designReminderSentAt =
        toDateTime(data['design_reminder_sent_at']) ??
        toDateTime(data['designReminderSentAt']) ??
        toDateTime(designApproval['reminderSentAt']);
    final designPreviewPhotosRaw =
        (data['design_preview_photos'] as List<dynamic>?) ??
        (data['designPreviewPhotos'] as List<dynamic>?) ??
        (designApproval['previewPhotos'] as List<dynamic>?) ??
        const [];
    final designPreviewPhotos =
        await ClientCustomRequestRepository.resolvePhotoRefs(
          designPreviewPhotosRaw
              .whereType<String>()
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(growable: false),
        );
    final acceptedByArtistEmail = firstNonEmpty([
      data['accepted_by_artist_email'],
      data['acceptedByArtistEmail'],
      (detailData['acceptance']
          as Map<String, dynamic>?)?['acceptedByArtistEmail'],
    ]).toLowerCase();
    final acceptedByClientEmail = firstNonEmpty([
      data['accepted_by_client_email'],
      data['acceptedByClientEmail'],
      (detailData['acceptance']
          as Map<String, dynamic>?)?['acceptedByClientEmail'],
    ]).toLowerCase();
    final declinedByClientEmails = <String>{
      ...((data['declined_by_client_emails'] as List<dynamic>?) ??
              (data['declinedByClientEmails'] as List<dynamic>?) ??
              const <dynamic>[])
          .whereType<String>()
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty),
      ...((detailData['declinedByClientEmails'] as List<dynamic>?) ??
              const <dynamic>[])
          .whereType<String>()
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty),
    }.toList(growable: false);
    final declinedByArtistEmails = <String>{
      ...((data['declined_by_artist_emails'] as List<dynamic>?) ??
              (data['declinedByArtistEmails'] as List<dynamic>?) ??
              const <dynamic>[])
          .whereType<String>()
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty),
      ...((detailData['declinedByArtistEmails'] as List<dynamic>?) ??
              const <dynamic>[])
          .whereType<String>()
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty),
    }.toList(growable: false);
    final selectedArtistEmail = firstNonEmpty([
      data['selected_artist_email'],
      data['selectedArtistEmail'],
      orderDetails['selectedArtistEmail'],
      (detailData['acceptance']
          as Map<String, dynamic>?)?['selectedArtistEmail'],
    ]).toLowerCase();
    final artistIdentity = await _resolveArtistIdentity(
      detailData: detailData,
      data: data,
      selectedArtistName: selectedArtist,
      acceptedByArtistEmail: acceptedByArtistEmail,
      selectedArtistEmail: selectedArtistEmail,
    );
    final acceptedByArtistName = artistIdentity.name;
    final artistProfileImageRaw = artistIdentity.profileImageRef;
    final artistProfileImage =
        await ClientCustomRequestRepository.resolvePhotoRef(
          artistProfileImageRaw,
        );
    final clientReview = _asMap(detailData['clientReview'])
      ..addAll(_asMap(data['clientReview']));
    final clientRating =
        asDouble(data['client_rating']) ??
        asDouble(data['clientRating']) ??
        asDouble(clientReview['rating']);
    final clientReviewText = firstNonEmpty([
      data['client_review_text'],
      data['clientReviewText'],
      clientReview['comment'],
    ]);
    final clientReviewSubmittedAt =
        toDateTime(data['client_review_submitted_at']) ??
        toDateTime(data['clientReviewSubmittedAt']) ??
        toDateTime(clientReview['submittedAt']);
    final shippedByCourier = firstNonEmpty([
      data['shipped_by_courier'],
      data['shippedByCourier'],
      shipment['courier'],
      data['shippingCarrier'],
    ]);
    final trackingNumber = firstNonEmpty([
      data['tracking_number'],
      data['trackingNumber'],
      shipment['trackingNumber'],
      data['shippingLabelTrackingNumber'],
    ]);
    final shippedAt =
        toDateTime(data['shipped_at']) ??
        toDateTime(data['shippedAt']) ??
        toDateTime(shipment['shippedAt']);
    final deliveredAt =
        toDateTime(data['delivered_at']) ??
        toDateTime(data['deliveredAt']) ??
        toDateTime(shipment['deliveredAt']);

    final nailPrefs = _asMap(detailData['nailPreferences'])
      ..addAll(_asMap(data['nailPreferences']));
    final nailShape = firstNonEmpty([
      nailPrefs['shape'],
      data['nail_shape'],
      data['nailShape'],
    ]);
    final nailLength = firstNonEmpty([
      nailPrefs['length'],
      data['nail_length'],
      data['nailLength'],
    ]);
    final dims = _asMap(nailPrefs['dimensions'])
      ..addAll(
        _asMap(
          data['nailPreferences'] is Map
              ? (data['nailPreferences'] as Map)['dimensions']
              : null,
        ),
      );

    String dim(dynamic v) {
      if (v is num) {
        return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
      }
      final s = (v ?? '').toString().trim();
      return s.isEmpty ? '-' : s;
    }

    final left = <String, String>{
      'thumb': dim(dims['lThumb']),
      'index': dim(dims['lIndex']),
      'middle': dim(dims['lMiddle']),
      'ring': dim(dims['lRing']),
      'pinky': dim(dims['lPinky']),
    };
    final right = <String, String>{
      'thumb': dim(dims['rThumb']),
      'index': dim(dims['rIndex']),
      'middle': dim(dims['rMiddle']),
      'ring': dim(dims['rRing']),
      'pinky': dim(dims['rPinky']),
    };

    final isGroupOrder = orderType == 'group';
    final isBrandRequest = sourceCollection == 'Company_Custom_Requests';
    final rootStatus = firstNonEmpty([
      if (isGroupOrder) data['status'],
      if (isGroupOrder) detailData['status'],
      if (!isGroupOrder) data['client_response_status'],
      if (!isGroupOrder) data['clientResponseStatus'],
      if (!isGroupOrder)
        (detailData['acceptance']
            as Map<String, dynamic>?)?['clientResponseStatus'],
      data['client_status'],
      data['clientStatus'],
      (detailData['roleStatuses'] is Map
          ? (detailData['roleStatuses'] as Map)['client']
          : null),
      data['brand_status'],
      data['brandStatus'],
      detailData['brandStatus'],
    ], fallback: 'submitted').toLowerCase();
    final resolvedStatus =
        isBrandRequest &&
            (cancelledAt != null || rootStatus == 'cancelled') &&
            rootStatus != 'cancelled'
        ? 'cancelled'
        : rootStatus;

    return SubmittedClientRequestSummary(
      id: data['id']?.toString() ?? '',
      sourceCollection: sourceCollection,
      orderNumber: canonicalOrderNumber([
        (data['admin'] is Map ? (data['admin'] as Map)['orderNumber'] : null),
        (detailData['admin'] is Map
            ? (detailData['admin'] as Map)['orderNumber']
            : null),
        data['order_number'],
        data['orderNumber'],
        detailData['orderNumber'],
        data['order_no'],
        data['orderNo'],
        data['order_id'],
        data['orderId'],
      ], sourceCollection: sourceCollection),
      status: resolvedStatus,
      clientSubmittedAt: submittedAt,
      needByDisplay: resolvedNeedByDisplay.isNotEmpty
          ? resolvedNeedByDisplay
          : (needByAt == null ? '' : formatDateMmDdYyyy(needByAt)),
      needBy: needByAt,
      requestAcceptByDisplay: resolvedRequestAcceptByDisplay.isNotEmpty
          ? resolvedRequestAcceptByDisplay
          : (requestAcceptByAt == null
                ? ''
                : formatDateMmDdYyyy(requestAcceptByAt)),
      requestAcceptBy: requestAcceptByAt,
      descriptionPreview: descriptionPreview,
      description: fullDescription,
      campaignName: campaignName,
      contactName: contactName,
      selectedArtist: selectedArtist,
      orderType: orderType,
      groupClients: groupClients,
      cancelReason: cancelReason,
      cancelledAt: cancelledAt,
      inspirationPhotos: inspirationPhotos,
      budgetMin: budgetMin,
      budgetMax: budgetMax,
      nailShape: nailShape,
      nailLength: nailLength,
      leftHandDimensions: left,
      rightHandDimensions: right,
      artistFinalAmount: artistFinalAmount,
      paymentStatus: paymentStatus,
      paymentLink: paymentLink,
      paidAt: paidAt,
      clientProfileImage: clientProfileImage,
      artistCompletedPhotos: artistCompletedPhotos,
      completionReviewStatus: completionReviewStatus,
      completionDeclineReason: completionDeclineReason,
      completionDeclineDescription: completionDeclineDescription,
      completionDeclinedAt: completionDeclinedAt,
      designApprovalStatus: designApprovalStatus,
      designApprovedAt: designApprovedAt,
      designSubmittedAt: designSubmittedAt,
      designApprovalDueAt: designApprovalDueAt,
      designReminderSentAt: designReminderSentAt,
      designPreviewPhotos: designPreviewPhotos,
      clientEmail: firstNonEmpty([
        data['client_email'],
        data['clientEmail'],
        payloadData['clientEmail'],
        detailData['clientEmail'],
      ]).toLowerCase(),
      acceptedByArtistEmail: acceptedByArtistEmail,
      acceptedByClientEmail: acceptedByClientEmail,
      clientResponseStatus: firstNonEmpty([
        data['client_response_status'],
        data['clientResponseStatus'],
        detailData['clientResponseStatus'],
        (detailData['acceptance']
            as Map<String, dynamic>?)?['clientResponseStatus'],
      ]).toLowerCase(),
      declinedByClientEmails: declinedByClientEmails,
      declinedByArtistEmails: declinedByArtistEmails,
      directClientStatus: firstNonEmpty([
        data['direct_client_status'],
        data['directClientStatus'],
        (detailData['routing'] is Map
            ? (detailData['routing'] as Map)['directClientStatus']
            : null),
      ]).toLowerCase(),
      acceptedByArtistName: acceptedByArtistName,
      artistProfileImage: artistProfileImage,
      clientRating: clientRating,
      clientReviewText: clientReviewText,
      clientReviewSubmittedAt: clientReviewSubmittedAt,
      shippedByCourier: shippedByCourier,
      trackingNumber: trackingNumber,
      shippedAt: shippedAt,
      deliveredAt: deliveredAt,
    );
  }
}

List<String> _collectPhotoRefs(List<Object?> sources) {
  final out = <String>[];
  final seen = <String>{};

  void addValue(Object? item) {
    if (item is String) {
      final value = item.trim();
      if (value.isNotEmpty && seen.add(value)) out.add(value);
      return;
    }
    if (item is Map) {
      final map = item.cast<String, dynamic>();
      var value = _firstNonEmptyString([
        map['url'],
        map['downloadUrl'],
        map['downloadURL'],
        map['imageUrl'],
        map['imageURL'],
        map['photoUrl'],
        map['photo'],
        map['path'],
        map['ref'],
        map['storagePath'],
        map['src'],
        map['uri'],
        map['value'],
      ]);
      value = value.trim();
      if (value.isNotEmpty && seen.add(value)) out.add(value);
    }
  }

  for (final source in sources) {
    if (source is List) {
      for (final item in source) {
        addValue(item);
      }
      continue;
    }
    addValue(source);
  }
  return out.toList(growable: false);
}

String _firstNonEmptyString(List<Object?> values) {
  for (final value in values) {
    final trimmed = (value ?? '').toString().trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return '';
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, innerValue) => MapEntry(key.toString(), innerValue));
  }
  return <String, dynamic>{};
}

class _ResolvedArtistIdentity {
  const _ResolvedArtistIdentity({this.name = '', this.profileImageRef = ''});

  final String name;
  final String profileImageRef;
}

Future<_ResolvedArtistIdentity> _resolveArtistIdentity({
  required Map<String, dynamic> detailData,
  required Map<String, dynamic> data,
  required String selectedArtistName,
  required String acceptedByArtistEmail,
  required String selectedArtistEmail,
}) async {
  String firstNonEmpty(List<Object?> values, {String fallback = ''}) {
    for (final value in values) {
      final trimmed = (value ?? '').toString().trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return fallback;
  }

  final acceptance = _asMap(detailData['acceptance']);
  final artistProfile = _asMap(detailData['artistProfile']);

  final directImage = firstNonEmpty([
    data['accepted_by_artist_profile_image'],
    data['acceptedByArtistProfileImage'],
    data['artist_profile_image'],
    data['artistProfileImage'],
    data['acceptedByArtistAvatarUrl'],
    acceptance['acceptedByArtistProfileImage'],
    acceptance['artistProfileImage'],
    acceptance['acceptedByArtistAvatarUrl'],
    artistProfile['profileImageUrl'],
    artistProfile['avatarUrl'],
    artistProfile['profileImagePath'],
  ]);
  final directName = firstNonEmpty([
    data['accepted_by_artist_name'],
    data['acceptedByArtistName'],
    acceptance['acceptedByArtistName'],
    artistProfile['name'],
    artistProfile['displayName'],
    selectedArtistName,
  ]);

  final artistEmail = firstNonEmpty([
    acceptedByArtistEmail,
    selectedArtistEmail,
  ]).toLowerCase();
  if (artistEmail.isEmpty) {
    return _ResolvedArtistIdentity(
      name: directName,
      profileImageRef: directImage,
    );
  }

  final supabase = Supabase.instance.client;
  for (final table in const <String>['artist', 'client_artist']) {
    try {
      final rows = await supabase
          .from(table)
          .select()
          .ilike('email', artistEmail)
          .limit(1);
      if (rows.isEmpty) continue;
      final docData = Map<String, dynamic>.from(rows.first);
      final profile = _asMap(docData['profile']);
      final basic = _asMap(docData['basic']);
      final image = firstNonEmpty([
        profile['profileImageUrl'],
        profile['avatarUrl'],
        profile['profileImagePath'],
        basic['profileImageUrl'],
        basic['avatarUrl'],
        basic['profileImagePath'],
        docData['panel_profile_image_url'],
        docData['panel_profileImageUrl'],
        docData['profile_image_url'],
        docData['profileImageUrl'],
        docData['avatar_url'],
        docData['avatarUrl'],
      ]);
      final name = firstNonEmpty([
        profile['name'],
        profile['displayName'],
        basic['name'],
        basic['displayName'],
        docData['name'],
        docData['display_name'],
        docData['displayName'],
        directName,
        selectedArtistName,
      ]);
      if (name.isNotEmpty || image.isNotEmpty) {
        return _ResolvedArtistIdentity(name: name, profileImageRef: image);
      }
    } catch (_) {}
  }

  return _ResolvedArtistIdentity(
    name: directName,
    profileImageRef: directImage,
  );
}

@immutable
class SubmittedGroupClientSummary {
  const SubmittedGroupClientSummary({
    required this.slotIndex,
    required this.clientId,
    required this.clientName,
    required this.clientEmail,
    required this.responseStatus,
    required this.nailShape,
    required this.nailLength,
    required this.leftHandDimensions,
    required this.rightHandDimensions,
  });

  final int slotIndex;
  final String clientId;
  final String clientName;
  final String clientEmail;
  final String responseStatus;
  final String nailShape;
  final String nailLength;
  final Map<String, String> leftHandDimensions;
  final Map<String, String> rightHandDimensions;
}

Future<List<SubmittedGroupClientSummary>> _parseGroupClients(
  List<dynamic> raw,
) async {
  if (raw.isEmpty) return const <SubmittedGroupClientSummary>[];

  String s(dynamic value) => (value ?? '').toString().trim();

  String dim(dynamic value) {
    if (value is num) {
      return value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toString();
    }
    final text = s(value);
    return text.isEmpty ? '-' : text;
  }

  Map<String, String> dimsFrom(Map<String, dynamic> map, {required bool left}) {
    String pick(String key, String fallbackKey) =>
        dim(map[key] ?? map[fallbackKey]);
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

  Map<String, dynamic> mergeDimensionSources(
    List<Map<String, dynamic>> sources,
  ) {
    final merged = <String, dynamic>{};
    const keys = <String>[
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
    ];

    for (final source in sources) {
      for (final key in keys) {
        final current = merged[key];
        if (current != null && dim(current) != '-') continue;
        final candidate = source[key];
        if (dim(candidate) != '-') {
          merged[key] = candidate;
        }
      }
    }

    return merged;
  }

  final clients = <SubmittedGroupClientSummary>[];
  final idNameCache = <String, String>{};

  String firstNonEmpty(List<Object?> values) {
    for (final raw in values) {
      final text = (raw ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  Future<String> resolveClientName(String clientId, String fallback) async {
    final id = clientId.trim();
    if (id.isEmpty) return fallback.trim();
    if (idNameCache.containsKey(id)) return idNameCache[id] ?? fallback.trim();

    Future<String> fromTable(String table) async {
      try {
        final row = await Supabase.instance.client
            .from(table)
            .select()
            .eq('id', id)
            .maybeSingle();
        if (row == null) return '';
        final data = Map<String, dynamic>.from(row);
        final profile = _asMap(data['profile']);
        return firstNonEmpty(<Object?>[
          profile['name'],
          profile['displayName'],
          data['display_name'],
          data['displayName'],
          data['name'],
        ]);
      } catch (_) {
        return '';
      }
    }

    final fromClient = await fromTable('client');
    if (fromClient.isNotEmpty) {
      idNameCache[id] = fromClient;
      return fromClient;
    }
    final fromClientArtist = await fromTable('client_artist');
    if (fromClientArtist.isNotEmpty) {
      idNameCache[id] = fromClientArtist;
      return fromClientArtist;
    }

    final resolved = fallback.trim();
    idNameCache[id] = resolved;
    return resolved;
  }

  for (final item in raw) {
    if (item is! Map) continue;
    final map = Map<String, dynamic>.from(item);
    final savedNails =
        (map['savedNails'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final draftNails =
        (map['draftNails'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final nailPreferences =
        (map['nailPreferences'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final nails = <String, dynamic>{
      ...nailPreferences,
      ...draftNails,
      ...savedNails,
    };
    final dimensions = mergeDimensionSources([
      (savedNails['dimensions'] as Map<String, dynamic>?) ??
          const <String, dynamic>{},
      (draftNails['dimensions'] as Map<String, dynamic>?) ??
          const <String, dynamic>{},
      (nailPreferences['dimensions'] as Map<String, dynamic>?) ??
          const <String, dynamic>{},
      (map['dimensions'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    ]);
    final clientId = s(map['clientId']);
    final fallbackName = firstNonEmpty(<Object?>[
      map['clientName'],
      map['name'],
      map['clientDisplayName'],
      map['displayName'],
    ]);
    final clientName = await resolveClientName(clientId, fallbackName);

    if (clientId.trim().isEmpty && clientName.trim().isEmpty) {
      continue;
    }

    clients.add(
      SubmittedGroupClientSummary(
        slotIndex: (map['slotIndex'] is int)
            ? map['slotIndex'] as int
            : int.tryParse(s(map['slotIndex'])) ?? 0,
        clientId: clientId,
        clientName: clientName,
        clientEmail: s(map['clientEmail']),
        responseStatus: s(
          map['responseStatus'] ?? map['clientResponseStatus'] ?? map['status'],
        ),
        nailShape: s(nails['shape']),
        nailLength: s(nails['length']),
        leftHandDimensions: dimsFrom(dimensions, left: true),
        rightHandDimensions: dimsFrom(dimensions, left: false),
      ),
    );
  }

  clients.sort((a, b) => a.slotIndex.compareTo(b.slotIndex));
  return clients;
}

DateTime? toDateTime(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
  if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
  if (raw is num) return DateTime.fromMillisecondsSinceEpoch(raw.round());
  if (raw is Map) {
    final seconds = raw['seconds'] ?? raw['_seconds'];
    if (seconds is int) {
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    }
    if (seconds is num) {
      return DateTime.fromMillisecondsSinceEpoch((seconds * 1000).round());
    }
  }
  return null;
}
