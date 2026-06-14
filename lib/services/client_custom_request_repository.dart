import 'dart:async';

import 'package:flutter/foundation.dart';
import 'supabase_firebase_compat.dart';

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
    final db = FirebaseFirestore.instance;
    final doc = db.collection('Client_Custom_Requests').doc();
    final detailDoc = doc.collection('details').doc('payload');
    final batch = db.batch();
    final orderNumber =
        (summary['orderNumber'] as String?)?.trim().isNotEmpty == true
        ? (summary['orderNumber'] as String).trim()
        : _generateClientOrderNumber(doc.id);

    final enrichedSummary = <String, dynamic>{
      ...summary,
      'orderNumber': orderNumber,
      'admin': <String, dynamic>{
        ...((summary['admin'] as Map<String, dynamic>?) ??
            const <String, dynamic>{}),
        'orderNumber': orderNumber,
      },
    };
    final enrichedDetails = <String, dynamic>{
      ...details,
      'orderNumber': orderNumber,
      'admin': <String, dynamic>{
        ...((details['admin'] as Map<String, dynamic>?) ??
            const <String, dynamic>{}),
        'orderNumber': orderNumber,
      },
    };

    batch.set(doc, enrichedSummary);
    batch.set(detailDoc, enrichedDetails);
    await batch.commit();

    return doc.id;
  }

  static Stream<List<SubmittedClientRequestSummary>> watchRequestsForClient({
    required String clientEmail,
    String? alternateClientEmail,
    String? clientName,
    String? userUid,
  }) {
    final email = clientEmail.trim().toLowerCase();
    final alternateEmail = (alternateClientEmail ?? '').trim().toLowerCase();
    final candidateEmails = <String>{
      email,
      alternateEmail,
    }.where((e) => e.isNotEmpty).toSet();
    final name = (clientName ?? '').trim().toLowerCase();
    final uid = (userUid ?? '').trim();
    final controller = StreamController<List<SubmittedClientRequestSummary>>();
    QuerySnapshot<Map<String, dynamic>>? clientSnapshot;
    QuerySnapshot<Map<String, dynamic>>? companySnapshot;
    var disposed = false;
    var emitting = false;
    var emitQueued = false;

    Future<Set<String>> resolveCandidateClientIds() async {
      final ids = <String>{};
      Future<void> collect(String collection) async {
        for (final candidateEmail in candidateEmails) {
          try {
            final snap = await FirebaseFirestore.instance
                .collection(collection)
                .where('email', isEqualTo: candidateEmail)
                .limit(1)
                .get();
            if (snap.docs.isNotEmpty) {
              ids.add(snap.docs.first.id.trim().toLowerCase());
            }
          } catch (_) {}
        }
      }

      await collect('client');
      await collect('client_artist');
      return ids;
    }

    final candidateClientIdsFuture = resolveCandidateClientIds();

    Future<void> emitIfReady() async {
      if (disposed) return;
      if (emitting) {
        emitQueued = true;
        return;
      }
      if (clientSnapshot == null && companySnapshot == null) return;
      emitting = true;
      try {
        final candidateClientIds = await candidateClientIdsFuture;
        final allDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[
          ...(clientSnapshot?.docs ?? const []),
          ...(companySnapshot?.docs ?? const []),
        ];
        Future<bool> matchesDoc(
          QueryDocumentSnapshot<Map<String, dynamic>> doc,
        ) async {
          Map<String, dynamic> asMap(dynamic value) {
            if (value is Map<String, dynamic>) {
              return Map<String, dynamic>.from(value);
            }
            if (value is Map) {
              return value.map((k, v) => MapEntry(k.toString(), v));
            }
            return <String, dynamic>{};
          }

          bool matchesWithData(Map<String, dynamic> data) {
            final collection = doc.reference.parent.id;
            final requestType = ((data['requestType'] as String?) ?? '')
                .trim()
                .toLowerCase();
            final typeMatches = collection == 'Company_Custom_Requests'
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
                  }.contains(requestType);
            if (!typeMatches) return false;

            final docEmail = ((data['clientEmail'] as String?) ?? '')
                .trim()
                .toLowerCase();
            final requesterEmail = ((data['requesterEmail'] as String?) ?? '')
                .trim()
                .toLowerCase();
            final legacyEmail = ((data['email'] as String?) ?? '')
                .trim()
                .toLowerCase();
            final companyEmail = ((data['companyEmail'] as String?) ?? '')
                .trim()
                .toLowerCase();
            final docName = ((data['clientName'] as String?) ?? '')
                .trim()
                .toLowerCase();
            final docUid =
                ((data['companyUid'] ??
                            data['requesterUid'] ??
                            data['createdByUid'] ??
                            data['uid'] ??
                            '')
                        as Object)
                    .toString()
                    .trim();
            final acceptedByClientEmail =
                ((data['acceptedByClientEmail'] as String?) ?? '')
                    .trim()
                    .toLowerCase();
            final declinedByClientEmails =
                ((data['declinedByClientEmails'] as List<dynamic>?) ??
                        const <dynamic>[])
                    .whereType<String>()
                    .map((e) => e.trim().toLowerCase())
                    .where((e) => e.isNotEmpty)
                    .toSet();

            final groupClientEmails = <String>{};
            final groupClientIds = <String>{};
            final groupClientNames = <String>{};

            void ingestClients(List<dynamic> clients) {
              for (final rawClient in clients) {
                if (rawClient is! Map) continue;
                final map = Map<String, dynamic>.from(rawClient);
                final groupClientId = ((map['clientId'] as String?) ?? '')
                    .trim()
                    .toLowerCase();
                final groupEmail = ((map['clientEmail'] as String?) ?? '')
                    .trim()
                    .toLowerCase();
                final groupName = ((map['clientName'] as String?) ?? '')
                    .trim()
                    .toLowerCase();
                if (groupEmail.isNotEmpty) groupClientEmails.add(groupEmail);
                if (groupClientId.isNotEmpty) groupClientIds.add(groupClientId);
                if (groupName.isNotEmpty) groupClientNames.add(groupName);
              }
            }

            ingestClients(
              (data['groupClients'] as List<dynamic>?) ?? const <dynamic>[],
            );
            final rootGroupOrder = asMap(data['groupOrder']);
            ingestClients(
              (rootGroupOrder['clients'] as List<dynamic>?) ??
                  const <dynamic>[],
            );

            final detailsGroupOrder = asMap(
              asMap(data['details'])['groupOrder'],
            );
            ingestClients(
              (detailsGroupOrder['clients'] as List<dynamic>?) ??
                  const <dynamic>[],
            );

            final matchesClient =
                (uid.isNotEmpty && docUid == uid) ||
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
            return matchesClient;
          }

          if (matchesWithData(doc.data())) return true;

          if (doc.reference.parent.id == 'Company_Custom_Requests') {
            try {
              final detailSnap = await doc.reference
                  .collection('details')
                  .doc('payload')
                  .get();
              final detailData = detailSnap.data() ?? const <String, dynamic>{};
              final merged = <String, dynamic>{...doc.data(), ...detailData};
              if (matchesWithData(merged)) return true;
            } catch (_) {}
          }

          return false;
        }

        final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        for (final doc in allDocs) {
          if (await matchesDoc(doc)) {
            docs.add(doc);
          }
        }

        final items = <SubmittedClientRequestSummary>[];
        for (final doc in docs) {
          try {
            final parsed =
                await SubmittedClientRequestSummary.fromDocWithDetails(doc);
            items.add(parsed);
          } catch (_) {
            // Skip malformed docs so one bad record doesn't hide all orders.
          }
        }
        if (!disposed) {
          controller.add(items);
        }
      } catch (e, st) {
        if (!disposed) controller.addError(e, st);
      } finally {
        emitting = false;
        if (!disposed && emitQueued) {
          emitQueued = false;
          unawaited(emitIfReady());
        }
      }
    }

    final clientSub = FirebaseFirestore.instance
        .collection('Client_Custom_Requests')
        .snapshots()
        .listen((snap) {
          clientSnapshot = snap;
          unawaited(emitIfReady());
        }, onError: controller.addError);

    final companySub = FirebaseFirestore.instance
        .collection('Company_Custom_Requests')
        .snapshots()
        .listen((snap) {
          companySnapshot = snap;
          unawaited(emitIfReady());
        }, onError: controller.addError);

    controller.onCancel = () async {
      disposed = true;
      await clientSub.cancel();
      await companySub.cancel();
    };

    return controller.stream;
  }

  static Future<String> resolvePhotoRef(String raw) async {
    final ref = _decodeUriSafelyRepeatedly(raw).trim();
    if (ref.isEmpty) return '';
    final cached = _resolvedPhotoRefCache[ref];
    if (cached != null) return cached;
    if (_missingPhotoRefCache.contains(ref)) return ref;
    if (_isRenderableImageRef(ref)) return ref;
    final inflight = _inflightPhotoRefResolvers[ref];
    if (inflight != null) return inflight;

    final future = () async {
      if (ref.startsWith('gs://')) {
        try {
          final resolved = await FirebaseStorage.instance
              .refFromURL(ref)
              .getDownloadURL()
              .timeout(const Duration(seconds: 20));
          _resolvedPhotoRefCache[ref] = resolved;
          return resolved;
        } catch (_) {
          _missingPhotoRefCache.add(ref);
          return ref;
        }
      }
      if (ref.startsWith('clients/') ||
          ref.startsWith('artists/') ||
          ref.startsWith('client_artists/') ||
          ref.startsWith('client_custom_requests/') ||
          ref.startsWith('company_custom_requests/') ||
          ref.startsWith('company/')) {
        try {
          final resolved = await FirebaseStorage.instance
              .ref(ref)
              .getDownloadURL()
              .timeout(const Duration(seconds: 20));
          _resolvedPhotoRefCache[ref] = resolved;
          return resolved;
        } catch (_) {
          _missingPhotoRefCache.add(ref);
          return ref;
        }
      }
      if (!ref.contains('://') && _looksLikeStoragePath(ref)) {
        try {
          final resolved = await FirebaseStorage.instance
              .ref(ref)
              .getDownloadURL()
              .timeout(const Duration(seconds: 20));
          _resolvedPhotoRefCache[ref] = resolved;
          return resolved;
        } catch (_) {
          _missingPhotoRefCache.add(ref);
          return ref;
        }
      }
      return ref;
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

  static bool _looksLikeStoragePath(String value) {
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

Future<List<String>> _recoverBrandRequestPhotos({
  required String companyUid,
  required String requestId,
}) async {
  final recovered = <String>[];
  for (final basePath in <String>[
    'company_custom_requests/$companyUid/$requestId',
    'client_custom_requests/$companyUid/$requestId',
  ]) {
    try {
      final listed = await FirebaseStorage.instance.ref(basePath).listAll();
      for (final item in listed.items) {
        final name = item.name.toLowerCase();
        final isImage =
            name.endsWith('.jpg') ||
            name.endsWith('.jpeg') ||
            name.endsWith('.png') ||
            name.endsWith('.webp') ||
            name.endsWith('.heic');
        if (!isImage) continue;
        try {
          final url = await item.getDownloadURL();
          if (url.trim().isNotEmpty) {
            recovered.add(url.trim());
            continue;
          }
        } catch (_) {
          if (item.fullPath.trim().isNotEmpty) {
            recovered.add(item.fullPath.trim());
          }
        }
      }
      if (recovered.isNotEmpty) break;
    } catch (_) {}
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

  static Future<SubmittedClientRequestSummary> fromDocWithDetails(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final sourceCollection = doc.reference.parent.id;
    final submittedRaw = data['clientSubmittedAtLocal'];
    DateTime? submittedAt;
    if (submittedRaw is String && submittedRaw.isNotEmpty) {
      submittedAt = DateTime.tryParse(submittedRaw);
    } else if (data['createdAt'] is Timestamp) {
      submittedAt = (data['createdAt'] as Timestamp).toDate();
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
    DateTime? paidAt;
    if (payment['paidAt'] is Timestamp) {
      paidAt = (payment['paidAt'] as Timestamp).toDate();
    } else if (data['paidAt'] is Timestamp) {
      paidAt = (data['paidAt'] as Timestamp).toDate();
    }

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
    DateTime? completionDeclinedAt;
    if (data['completionDeclinedAt'] is Timestamp) {
      completionDeclinedAt = (data['completionDeclinedAt'] as Timestamp)
          .toDate();
    } else if (artistCompletion['reviewedAt'] is Timestamp) {
      completionDeclinedAt = (artistCompletion['reviewedAt'] as Timestamp)
          .toDate();
    } else if (data['completionReviewedAt'] is Timestamp) {
      completionDeclinedAt = (data['completionReviewedAt'] as Timestamp)
          .toDate();
    }
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
    DateTime? clientReviewSubmittedAt;
    if (data['clientReviewSubmittedAt'] is Timestamp) {
      clientReviewSubmittedAt = (data['clientReviewSubmittedAt'] as Timestamp)
          .toDate();
    } else if (clientReview['submittedAt'] is Timestamp) {
      clientReviewSubmittedAt = (clientReview['submittedAt'] as Timestamp)
          .toDate();
    }
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

List<String> _collectPhotoRefsFromMap(Map<String, dynamic> source) {
  final out = <String>[];

  void addIfPhotoLike(String value, {required String keyHint}) {
    final v = value.trim();
    if (v.isEmpty) return;
    if (_isPhotoLikeString(v, keyHint: keyHint)) out.add(v);
  }

  void visit(Object? node, {required String keyHint}) {
    if (node is String) {
      addIfPhotoLike(node, keyHint: keyHint);
      return;
    }
    if (node is List) {
      for (final item in node) {
        visit(item, keyHint: keyHint);
      }
      return;
    }
    if (node is Map) {
      final map = node.cast<String, dynamic>();
      for (final entry in map.entries) {
        visit(entry.value, keyHint: entry.key.trim());
      }
    }
  }

  visit(source, keyHint: '');
  return out.toList(growable: false);
}

bool _isPhotoLikeString(String value, {required String keyHint}) {
  final v = value.trim();
  if (v.isEmpty) return false;
  final key = keyHint.toLowerCase().trim();
  final keyLooksPhoto =
      key.contains('photo') ||
      key.contains('image') ||
      key.contains('inspiration') ||
      key.contains('upload') ||
      key.contains('attachment');
  final keyExcluded =
      key.contains('profile') || key.contains('avatar') || key.contains('logo');
  final keyLooksArtistCompleted =
      key.contains('artistcompleted') ||
      key.contains('artistuploaded') ||
      key == 'artistimages' ||
      key.contains('completedphotos') ||
      key.contains('artistphotos') ||
      key.contains('designpreview');
  if (keyExcluded || keyLooksArtistCompleted) return false;

  final lower = v.toLowerCase();
  if (lower.startsWith('data:image/')) return true;
  if (lower.startsWith('gs://')) return true;
  if (lower.contains('client_custom_requests/')) return true;
  if (lower.contains('/o/client_custom_requests%2f')) return true;
  if (lower.contains('firebasestorage.googleapis.com')) {
    return keyLooksPhoto ||
        lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.png') ||
        lower.contains('.webp') ||
        lower.contains('.heic') ||
        lower.contains('.gif');
  }
  if (lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.heic') ||
      lower.endsWith('.gif')) {
    return true;
  }
  if (ClientCustomRequestRepository._looksLikeStoragePath(v) && keyLooksPhoto) {
    return true;
  }
  return false;
}

String _firstNonEmptyString(List<Object?> values) {
  for (final value in values) {
    final trimmed = (value ?? '').toString().trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return '';
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

  final acceptance =
      (detailData['acceptance'] as Map<String, dynamic>?) ??
      const <String, dynamic>{};
  final artistProfile =
      (detailData['artistProfile'] as Map<String, dynamic>?) ??
      const <String, dynamic>{};

  final directImage = firstNonEmpty([
    data['acceptedByArtistProfileImage'],
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

  final db = FirebaseFirestore.instance;
  for (final collection in const <String>['artist', 'client_artist']) {
    final snap = await db
        .collection(collection)
        .where('email', isEqualTo: artistEmail)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) continue;
    final docData = snap.docs.first.data();
    final profile =
        (docData['profile'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final basic =
        (docData['basic'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final image = firstNonEmpty([
      profile['profileImageUrl'],
      profile['avatarUrl'],
      profile['profileImagePath'],
      basic['profileImageUrl'],
      basic['avatarUrl'],
      basic['profileImagePath'],
      docData['panel_profileImageUrl'],
      docData['profileImageUrl'],
      docData['avatarUrl'],
    ]);
    final name = firstNonEmpty([
      profile['name'],
      profile['displayName'],
      basic['name'],
      basic['displayName'],
      docData['name'],
      docData['displayName'],
      directName,
      selectedArtistName,
    ]);
    if (name.isNotEmpty || image.isNotEmpty) {
      return _ResolvedArtistIdentity(name: name, profileImageRef: image);
    }
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

    Future<String> fromCollection(String collection) async {
      try {
        final snap = await FirebaseFirestore.instance
            .collection(collection)
            .doc(id)
            .get();
        if (!snap.exists) return '';
        final data = snap.data() ?? const <String, dynamic>{};
        final profile =
            (data['profile'] as Map<String, dynamic>?) ??
            const <String, dynamic>{};
        return firstNonEmpty(<Object?>[
          profile['name'],
          profile['displayName'],
          data['displayName'],
          data['name'],
        ]);
      } catch (_) {
        return '';
      }
    }

    final fromClient = await fromCollection('client');
    if (fromClient.isNotEmpty) {
      idNameCache[id] = fromClient;
      return fromClient;
    }
    final fromClientArtist = await fromCollection('client_artist');
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
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  return null;
}
