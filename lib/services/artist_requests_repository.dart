import 'package:flutter/foundation.dart';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/client_request_v2.dart';

class ArtistRequestsRepository {
  static final Map<String, String> _resolvedPhotoRefCache = <String, String>{};
  static final Set<String> _missingPhotoRefCache = <String>{};
  static final Map<String, Future<String>> _inflightPhotoRefResolvers =
      <String, Future<String>>{};

  static const int _maxResolvedPhotosPerRequest = 10;
  static const int _maxResolvedDesignPreviewPhotos = 1;

  static const int _maxInitialRequestsPerCollection = 10;
  static const int _maxActiveRequestsPerCollection = 6;

  // Column projection for client_custom_requests: verified against the live
  // Supabase schema (2026-07) and cross-referenced against every field this
  // file actually reads via _flattenSupabaseRequestRow/_fromSupabaseRow*.
  // Keep in sync with docs/DB_OPTIMIZATION_PLAN.md Phase A if columns change.
  static const String _clientRequestColumns =
      'accepted_by_artist_email, accepted_by_artist_name, accepted_by_client_email, '
      'accepted_client_name, allow_non_licensed, artist_completed_photos, artist_final_amount, '
      'artist_images, artist_pool_status, artist_profile_image, artist_quote, artist_status, '
      'artist_uploaded_photos, budget_max, budget_min, campaign_name, cancel_reason, '
      'client_avatar_url, client_budget_max, client_budget_min, client_email, client_name, '
      'client_rating, client_response_status, client_review, client_review_submitted_at, '
      'client_review_text, client_status, completed_art, completion_decline_description, '
      'completion_decline_reason, completion_declined_at, completion_review_status, created_at, '
      'data, declined_by_artist_emails, declined_by_client_emails, delivered_at, description, '
      'description_preview, design_approval_due_at, design_approval_status, design_approved_at, '
      'design_preview_photos, design_reminder_sent_at, design_submitted_at, details, '
      'direct_artist_status, fallback_to_pool, group_client_count, has_inspiration_photos, id, '
      'inspiration_photos, is_direct_request, is_group_order, nail_length, nail_preferences, '
      'nail_shape, need_by, open_to_artist_pool, open_to_client_pool, order_number, order_type, '
      'paid_at, payload, payment, payment_link, payment_status, photo_count, preview_image, '
      'preview_image_asset, request_details, selected_artist, selected_artist_email, '
      'selected_client, selected_client_email, shipped_at, shipped_by_courier, shipping, '
      'shipping_label_carrier, shipping_label_created_at, shipping_label_pdf_url, '
      'shipping_label_qr_data, shipping_label_ready, shipping_label_tracking_number, '
      'shipping_qr_code, shipping_status, status, summary, title, tracking_number, updated_at';

  // Column projection for company_custom_requests — same provenance as above.
  static const String _companyRequestColumns =
      'accepted_by_artist_email, accepted_by_artist_name, accepted_by_client_email, '
      'accepted_client_name, accepted_group_client_emails, admin, artist_budget, '
      'artist_budget_max, artist_budget_min, artist_completed_photos, artist_final_amount, '
      'artist_images, artist_pool_status, artist_profile_image, artist_quote, artist_status, '
      'artist_uploaded_photos, brand_inspiration_photos, brand_name, budget_max, budget_min, '
      'campaign_name, cancel_reason, client_avatar_url, client_budget, client_budget_max, '
      'client_budget_min, client_email, client_location, client_name, client_profile_image, '
      'client_rating, client_review, client_review_submitted_at, client_review_text, '
      'client_status, company_name, completed_art, completion_decline_description, '
      'completion_decline_reason, completion_declined_at, completion_review_status, created_at, '
      'declined_by_artist_emails, declined_by_client_emails, delivered_at, description, '
      'description_preview, design_approval_due_at, design_approval_status, design_approved_at, '
      'design_preview_photos, design_reminder_sent_at, design_submitted_at, details, '
      'direct_artist_status, fallback_to_pool, has_inspiration_photos, id, inspiration_photos, '
      'is_direct_request, nail_length, nail_preferences, nail_shape, need_by, '
      'open_to_artist_pool, open_to_client_pool, order_number, order_type, order_type_label, '
      'paid_at, payload, payment, payment_link, payment_status, photo_count, preview_image, '
      'preview_image_asset, request_details, request_title, requester_name, selected_artist, '
      'selected_artist_email, selected_client, selected_client_email, '
      'selected_group_client_emails, shipped_at, shipped_by_courier, shipping, '
      'shipping_address_different_from_profile, shipping_city, shipping_country, '
      'shipping_label_carrier, shipping_label_created_at, shipping_label_pdf_url, '
      'shipping_label_qr_data, shipping_label_ready, shipping_label_tracking_number, '
      'shipping_state, shipping_status, shipping_street, shipping_zip, status, summary, title, '
      'tracking_number, updated_at';

  static String _columnsForTable(String tableName) =>
      tableName == 'company_custom_requests'
          ? _companyRequestColumns
          : _clientRequestColumns;

  static SupabaseClient get _supabase => Supabase.instance.client;

  static Future<List<ClientRequestV2>> fetchActiveRequests() async {
    final rows = await _fetchRows(
      limit: _maxActiveRequestsPerCollection,
      preferRecentOnly: true,
    );

    final items = await Future.wait(
      rows.map(
        (row) => _fromSupabaseRowLiteWithDetailsHints(
          row,
          sourceCollection: _sourceCollectionFor(
            (row['__sourceCollection'] ?? '').toString(),
          ),
        ),
      ),
    );

    final merged = items.whereType<ClientRequestV2>().toList(growable: false);
    merged.sort((a, b) => b.neededBy.compareTo(a.neededBy));
    return merged;
  }

  static Future<List<ClientRequestV2>> fetchAllRequests() async {
    final rows = await _fetchRows(
      limit: _maxInitialRequestsPerCollection,
      preferRecentOnly: true,
    );

    final items = await Future.wait(
      rows.map(
        (row) => _fromSupabaseRowWithDetails(
          row,
          sourceCollection: _sourceCollectionFor(
            (row['__sourceCollection'] ?? '').toString(),
          ),
        ),
      ),
    );

    final merged = items.whereType<ClientRequestV2>().toList(growable: false);
    merged.sort((a, b) => b.neededBy.compareTo(a.neededBy));
    return merged;
  }

  static Future<ClientRequestV2?> fetchRequestById({
    required String sourceCollection,
    required String requestId,
  }) async {
    final id = requestId.trim();
    if (id.isEmpty) return null;

    final normalizedSource = _sourceCollectionFor(sourceCollection);
    final tableName = normalizedSource == 'Company_Custom_Requests'
        ? 'company_custom_requests'
        : 'client_custom_requests';

    try {
      final row = await _supabase
          .from(tableName)
          .select()
          .eq('id', id)
          .maybeSingle();

      if (row == null) return null;

      final mapped = await _mergeRowWithDetails(
        Map<String, dynamic>.from(row),
        sourceCollection: normalizedSource,
      );
      mapped['__sourceCollection'] = normalizedSource;

      return _fromSupabaseRowWithDetails(
        mapped,
        sourceCollection: normalizedSource,
      );
    } catch (e) {
      debugPrint('ARTIST REQUESTS fetchRequestById failed: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> _fetchRows({
    int? limit,
    bool preferRecentOnly = false,
  }) async {
    final requestLimit = limit ?? _maxInitialRequestsPerCollection;

    Future<List<Map<String, dynamic>>> fetchCollection({
      required String tableName,
      required String sourceCollection,
    }) async {
      try {
        dynamic query = _supabase.from(tableName).select();

        if (preferRecentOnly) {
          query = query.order('created_at', ascending: false);
        }

        final rows = await query.limit(requestLimit);

        if (rows is! List) return const <Map<String, dynamic>>[];

        final mergedRows = await Future.wait(
          rows.whereType<Map>().map((row) async {
            final mapped = await _mergeRowWithDetails(
              Map<String, dynamic>.from(row),
              sourceCollection: sourceCollection,
            );
            mapped['__sourceCollection'] = sourceCollection;
            return mapped;
          }),
        );

        return mergedRows.toList(growable: false);
      } catch (e, st) {
        debugPrint('ARTIST REQUESTS Supabase fetch $tableName failed: $e');
        debugPrint(st.toString());
        return const <Map<String, dynamic>>[];
      }
    }

    final results = await Future.wait(<Future<List<Map<String, dynamic>>>>[
      fetchCollection(
        tableName: 'client_custom_requests',
        sourceCollection: 'Client_Custom_Requests',
      ),
      fetchCollection(
        tableName: 'company_custom_requests',
        sourceCollection: 'Company_Custom_Requests',
      ),
    ]);

    final merged = <Map<String, dynamic>>[...results[0], ...results[1]];

    if (preferRecentOnly) {
      merged.sort((a, b) {
        final aDate =
            _toDate(a['created_at']) ??
            _toDate(a['createdAt']) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate =
            _toDate(b['created_at']) ??
            _toDate(b['createdAt']) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
    }

    return merged.take(requestLimit * 2).toList(growable: false);
  }

  static String _sourceCollectionFor(String sourceCollection) {
    final value = sourceCollection.trim();
    final lower = value.toLowerCase();
    if (value == 'Company_Custom_Requests' ||
        lower == 'company_custom_requests') {
      return 'Company_Custom_Requests';
    }
    if (value == 'Client_Custom_Requests' ||
        lower == 'client_custom_requests') {
      return 'Client_Custom_Requests';
    }
    if (value.isNotEmpty) return value;
    return 'Client_Custom_Requests';
  }

  static Future<Map<String, dynamic>> _mergeRowWithDetails(
    Map<String, dynamic> row, {
    required String sourceCollection,
  }) async {
    final requestId = (row['id'] ?? '').toString().trim();
    if (requestId.isEmpty) return row;

    final detailsTable = sourceCollection == 'Company_Custom_Requests'
        ? 'company_custom_requests_details'
        : 'client_custom_requests_details';

    try {
      final detailRows = await _supabase
          .from(detailsTable)
          .select()
          .eq('request_id', requestId);
      final mergedDetails = _mergeDetailRows(detailRows);
      if (mergedDetails.isEmpty) return row;

      return <String, dynamic>{...row, 'details': mergedDetails};
    } catch (e) {
      debugPrint(
        'ARTIST REQUESTS detail merge failed for $detailsTable/$requestId: $e',
      );
      return row;
    }
  }

  static Map<String, dynamic> _mergeDetailRows(dynamic rows) {
    if (rows is! List) return const <String, dynamic>{};

    bool isPayloadRow(Map<String, dynamic> row) {
      final docId = (row['doc_id'] ?? row['detail_key'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final id = (row['id'] ?? '').toString().trim().toLowerCase();
      return docId == 'payload' || id.endsWith(':payload');
    }

    Map<String, dynamic> payloadDoc = <String, dynamic>{};
    final merged = <String, dynamic>{};

    for (final raw in rows.whereType<Map>()) {
      final row = Map<String, dynamic>.from(raw);
      final payload = _asMap(row['payload']);
      final data = _asMap(row['data']);
      final effective = data.isNotEmpty
          ? data
          : (payload.isNotEmpty ? payload : row);
      merged.addAll(effective);
      if (isPayloadRow(row)) {
        payloadDoc = effective;
      }
    }

    return payloadDoc.isNotEmpty ? payloadDoc : merged;
  }

  static Future<ClientRequestV2?> _fromSupabaseRowLiteWithDetailsHints(
    Map<String, dynamic> row, {
    String sourceCollection = 'Client_Custom_Requests',
  }) async {
    final lite = await _fromSupabaseRowLite(
      row,
      sourceCollection: sourceCollection,
    );
    if (lite == null) return null;

    final detailData = _asMap(row['details']);
    if (detailData.isEmpty) return lite;

    final data = _flattenSupabaseRequestRow(row);
    final orderData = _asMap(detailData['order']).isNotEmpty
        ? _asMap(detailData['order'])
        : _asMap(data['order']);
    final groupOrder = _asMap(detailData['groupOrder']).isNotEmpty
        ? _asMap(detailData['groupOrder'])
        : _asMap(data['groupOrder']);
    final groupClientsRaw = _asList(groupOrder['clients']).isNotEmpty
        ? _asList(groupOrder['clients'])
        : _asList(orderData['clients']);

    final selectedGroupClientEmails = <String>{
      ...lite.selectedGroupClientEmails,
      ..._stringList(
        detailData['selectedGroupClientEmails'],
      ).map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty),
      ..._stringList(
        orderData['selectedGroupClientEmails'],
      ).map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty),
      ...groupClientsRaw
          .whereType<Map>()
          .map(
            (item) =>
                (item['clientEmail'] ?? '').toString().trim().toLowerCase(),
          )
          .where((e) => e.isNotEmpty),
    }.toList(growable: false);

    final orderType = _resolveOrderType(
      raw: _firstNonEmptyString(
        detailData['orderType'],
        detailData['orderTypeLabel'],
        orderData['type'],
        orderData['orderType'],
        data['orderType'],
        data['orderTypeLabel'],
        data['type'],
      ),
      isGroupOrder: data['isGroupOrder'],
      detailIsGroupOrder: groupOrder['isGroupOrder'],
      hasGroupClients:
          groupClientsRaw.isNotEmpty ||
          selectedGroupClientEmails.length > 1 ||
          _asInt(data['groupClientCount']) > 0,
    );

    final acceptedGroupClientEmails = <String>{
      ..._stringList(
        data['acceptedGroupClientEmails'],
      ).map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty),
      ..._stringList(
        detailData['acceptedGroupClientEmails'],
      ).map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty),
    };
    final declinedByClientEmails = <String>{
      ..._stringList(
        data['declinedByClientEmails'],
      ).map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty),
      ..._stringList(
        detailData['declinedByClientEmails'],
      ).map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty),
    };
    final respondedClientEmails = <String>{
      ...acceptedGroupClientEmails,
      ...declinedByClientEmails,
    };
    final groupClientsAllResponded =
        _asBool(data['groupClientsAllResponded']) ||
        _asBool(detailData['groupClientsAllResponded']) ||
        (orderType == RequestOrderTypeV2.group &&
            selectedGroupClientEmails.isNotEmpty &&
            selectedGroupClientEmails.every(respondedClientEmails.contains));

    return lite.copyWith(
      orderType: orderType,
      selectedGroupClientEmails: selectedGroupClientEmails,
      acceptedGroupClientEmails: acceptedGroupClientEmails.toList(
        growable: false,
      ),
      groupClientsAllResponded: groupClientsAllResponded,
      declinedByClientEmails: declinedByClientEmails.toList(growable: false),
    );
  }

  static Future<ClientRequestV2?> _fromSupabaseRowLite(
    Map<String, dynamic> row, {
    required String sourceCollection,
  }) async {
    final data = _flattenSupabaseRequestRow(row);

    final status =
        _mapStatus(
          data['artistStatus'] ?? data['artist_status'] ?? data['status'],
        ) ??
        RequestStatusV2.inReview;

    final brandName = _firstNonEmptyString(
      data['clientName'],
      data['client_name'],
      data['companyName'],
      data['brandName'],
      data['requesterName'],
    );
    final title = _firstNonEmptyString(
      data['title'],
      data['campaignName'],
      data['requestTitle'],
      data['orderNumber'],
      data['order_number'],
      'Custom Nail Request',
    );
    final subtitle = _firstNonEmptyString(
      data['descriptionPreview'],
      data['orderType'],
      data['priority'],
      data['artistStatus'],
      data['status'],
    );
    final neededBy =
        _toDate(data['needBy']) ??
        _toDate(data['neededBy']) ??
        _toDate(data['createdAt']) ??
        _toDate(data['created_at']) ??
        _toDate(data['updatedAt']) ??
        _toDate(data['updated_at']) ??
        DateTime.now();

    final selectedArtist = _firstNonEmptyString(
      data['selectedArtist'],
      data['selected_artist'],
    );
    final selectedArtistEmail = _firstNonEmptyString(
      data['selectedArtistEmail'],
      data['selected_artist_email'],
      data['acceptedByArtistEmail'],
      data['accepted_by_artist_email'],
    ).toLowerCase();

    final orderData = _asMap(data['order']);
    final groupOrder = _asMap(data['groupOrder']);
    final selectedGroupClientEmails = <String>{
      ..._stringList(
        data['selectedGroupClientEmails'],
      ).map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty),
      ..._stringList(
        orderData['selectedGroupClientEmails'],
      ).map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty),
      ..._asList(groupOrder['clients'])
          .whereType<Map>()
          .map(
            (item) =>
                (item['clientEmail'] ?? '').toString().trim().toLowerCase(),
          )
          .where((e) => e.isNotEmpty),
    }.toList(growable: false);

    final groupClientCount = _asInt(data['groupClientCount']);
    final hasGroupClients =
        _asList(groupOrder['clients']).isNotEmpty ||
        selectedGroupClientEmails.length > 1;
    final orderType = _resolveOrderType(
      raw: _firstNonEmptyString(
        data['orderType'],
        data['orderTypeLabel'],
        orderData['type'],
        orderData['orderType'],
        data['type'],
      ),
      isGroupOrder: data['isGroupOrder'],
      detailIsGroupOrder: groupOrder['isGroupOrder'],
      hasGroupClients: hasGroupClients || groupClientCount > 0,
    );

    final directFlag = _asNullableBool(data['isDirectRequest']) ?? false;
    final budgetMin = _asInt(data['budgetMin']);
    final budgetMax = _asInt(data['budgetMax']);
    final safeBudgetMin = budgetMin > 0 ? budgetMin : 0;
    final safeBudgetMax = budgetMax > 0
        ? budgetMax
        : (safeBudgetMin > 0 ? safeBudgetMin : 0);

    final rootNailPrefs = _asMap(data['nailPreferences']).isNotEmpty
        ? _asMap(data['nailPreferences'])
        : _asMap(data['nail_preferences']);
    final rootDims = _asMap(rootNailPrefs['dimensions']).isNotEmpty
        ? _asMap(rootNailPrefs['dimensions'])
        : _asMap(data['dimensions']);
    final leftHand = <String, String>{
      'thumb': _dimValue(rootDims['lThumb']),
      'index': _dimValue(rootDims['lIndex']),
      'middle': _dimValue(rootDims['lMiddle']),
      'ring': _dimValue(rootDims['lRing']),
      'pinky': _dimValue(rootDims['lPinky']),
    };
    final rightHand = <String, String>{
      'thumb': _dimValue(rootDims['rThumb']),
      'index': _dimValue(rootDims['rIndex']),
      'middle': _dimValue(rootDims['rMiddle']),
      'ring': _dimValue(rootDims['rRing']),
      'pinky': _dimValue(rootDims['rPinky']),
    };

    final photosRaw = _collectPhotoRefs(<Object?>[
      data['requestDetails'],
      data['inspiration_photos'],
      data['inspirationPhotos'],
      data['clientImages'],
      data['photos'],
      data['inspirationPhoto'],
      data['inspirationPhotoUrl'],
      data['previewImage'],
      data['previewImageAsset'],
    ]);
    final artistPhotosRaw = _collectPhotoRefs(<Object?>[
      data['artistImages'],
      data['artistUploadedPhotos'],
      data['artistCompletedPhotos'],
      data['artist_completed_photos'],
      _asMap(data['completedArt'])['imageUrls'],
      _asMap(data['artistCompletion'])['artistPhotos'],
    ]);
    final safeClientPhotos = _removeArtistRefsFromClientPhotos(
      clientRefs: photosRaw,
      artistRefs: artistPhotosRaw,
    ).take(_maxResolvedPhotosPerRequest).toList(growable: false);
    final safeArtistPhotos = artistPhotosRaw
        .take(_maxResolvedPhotosPerRequest)
        .toList(growable: false);
    final previewImage = _firstNonEmptyString(
      safeClientPhotos.isNotEmpty ? safeClientPhotos.first : '',
      data['previewImageAsset'],
      data['previewImage'],
    );

    return ClientRequestV2(
      id: (row['id'] ?? '').toString(),
      sourceCollection: sourceCollection,
      orderNumber: _firstNonEmptyString(
        data['orderNumber'],
        data['order_number'],
      ),
      clientEmail: _firstNonEmptyString(
        data['clientEmail'],
        data['client_email'],
      ).toLowerCase(),
      clientName: brandName,
      title: title,
      subtitle: subtitle,
      neededBy: neededBy,
      submittedAt: _toDate(data['createdAt']) ?? _toDate(data['created_at']),
      budgetMin: safeBudgetMin,
      budgetMax: safeBudgetMax,
      status: status,
      isDirectRequest: directFlag,
      fallbackToPool: _asNullableBool(data['fallbackToPool']) ?? true,
      openToClientPool: _asNullableBool(data['openToClientPool']) ?? true,
      allowNonLicensed:
          _asNullableBool(data['allowNonLicensed']) ??
          _asNullableBool(data['allow_non_licensed']) ??
          true,
      orderType: orderType,
      selectedArtist: directFlag ? selectedArtist : '',
      selectedArtistEmail: directFlag ? selectedArtistEmail : '',
      selectedGroupClientEmails: selectedGroupClientEmails,
      hasInspo:
          _asBool(data['hasInspirationPhotos']) ||
          _asBool(data['has_inspiration_photos']) ||
          _asInt(data['photoCount']) > 0 ||
          _asInt(data['photo_count']) > 0 ||
          safeClientPhotos.isNotEmpty,
      nfcRequested:
          _asBool(data['nfcRequested']) || _asBool(data['nfc_requested']),
      clientLocation: _locationFromData(data),
      previewImageAsset: previewImage,
      bio: _firstNonEmptyString(
        data['descriptionPreview'],
        data['description'],
      ),
      nailShape: _firstNonEmptyString(
        rootNailPrefs['shape'],
        data['nailShape'],
      ),
      nailLength: _firstNonEmptyString(
        rootNailPrefs['length'],
        data['nailLength'],
      ),
      leftHand: NailDimensionsV2(
        thumb: leftHand['thumb'] ?? '',
        index: leftHand['index'] ?? '',
        middle: leftHand['middle'] ?? '',
        ring: leftHand['ring'] ?? '',
        pinky: leftHand['pinky'] ?? '',
      ),
      rightHand: NailDimensionsV2(
        thumb: rightHand['thumb'] ?? '',
        index: rightHand['index'] ?? '',
        middle: rightHand['middle'] ?? '',
        ring: rightHand['ring'] ?? '',
        pinky: rightHand['pinky'] ?? '',
      ),
      clientImages: safeClientPhotos,
      paymentStatus: _firstNonEmptyString(
        data['paymentStatus'],
        data['payment_status'],
      ),
      acceptedByArtistEmail: _firstNonEmptyString(
        data['acceptedByArtistEmail'],
        data['accepted_by_artist_email'],
      ).toLowerCase(),
      acceptedByClientEmail: _firstNonEmptyString(
        data['acceptedByClientEmail'],
      ).toLowerCase(),
      clientResponseStatus: _firstNonEmptyString(
        data['clientResponseStatus'],
      ).toLowerCase(),
      declinedByArtistEmails: _stringList(data['declinedByArtistEmails'])
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toList(growable: false),
      groupClientsAllResponded: _asBool(data['groupClientsAllResponded']),
      artistImages: safeArtistPhotos,
    );
  }

  static Future<ClientRequestV2?> _fromSupabaseRowWithDetails(
    Map<String, dynamic> row, {
    String sourceCollection = 'Client_Custom_Requests',
  }) async {
    final data = _flattenSupabaseRequestRow(row);
    final detailData = _asMap(row['details']);
    final roleStatuses = _asMap(detailData['roleStatuses']);

    final status = _mapStatus(
      data['artistStatus'] ??
          data['artist_status'] ??
          roleStatuses['artist'] ??
          data['status'] ??
          detailData['status'],
    );
    if (status == null) return null;

    final brandName = _firstNonEmptyString(
      data['clientName'],
      data['client_name'],
      data['companyName'],
      data['brandName'],
      data['requesterName'],
    );
    String acceptedClientNameRaw = '';
    String clientName = brandName;

    final title = _firstNonEmptyString(
      data['title'],
      data['campaignName'],
      data['requestTitle'],
      data['orderNumber'],
      data['order_number'],
      'Custom Nail Request',
    );

    final subtitle = _firstNonEmptyString(
      data['descriptionPreview'],
      data['orderType'],
      data['priority'],
    );

    final neededBy =
        _toDate(data['needBy']) ??
        _toDate(data['need_by']) ??
        _toDate(data['createdAt']) ??
        _toDate(data['created_at']) ??
        DateTime.now();

    final location = _locationFromData(data);
    final submittedAt =
        _toDate(data['createdAt']) ??
        _toDate(data['created_at']) ??
        _toDate(detailData['createdAt']) ??
        _toDate(data['updatedAt']) ??
        _toDate(data['updated_at']) ??
        neededBy;

    final orderData = _asMap(detailData['order']).isNotEmpty
        ? _asMap(detailData['order'])
        : _asMap(data['order']);
    final groupOrder = _asMap(detailData['groupOrder']).isNotEmpty
        ? _asMap(detailData['groupOrder'])
        : _asMap(detailData['group_order']).isNotEmpty
        ? _asMap(detailData['group_order'])
        : _asMap(data['groupOrder']).isNotEmpty
        ? _asMap(data['groupOrder'])
        : _asMap(data['group_order']);

    final selectedArtistRaw = _firstNonEmptyString(
      data['selectedArtist'],
      data['selected_artist'],
      orderData['selectedArtist'],
      data['selectedArtistId'],
      data['selectedArtistEmail'],
      data['selected_artist_email'],
      data['acceptedByArtistEmail'],
      data['accepted_by_artist_email'],
    );
    final selectedArtistEmailRaw = _firstNonEmptyString(
      data['selectedArtistEmail'],
      data['selected_artist_email'],
      orderData['selectedArtistEmail'],
    ).toLowerCase();
    final openToArtistPoolFlag =
        _asNullableBool(data['openToArtistPool']) ??
        _asNullableBool(orderData['openToArtistPool']) ??
        _asNullableBool(detailData['openToArtistPool']);
    final directFlag =
        _asNullableBool(data['isDirectRequest']) ??
        _asNullableBool(orderData['isDirectRequest']) ??
        _asNullableBool(detailData['isDirectRequest']) ??
        (selectedArtistEmailRaw.isNotEmpty ||
            selectedArtistRaw.trim().isNotEmpty ||
            openToArtistPoolFlag == false);
    final selectedArtist = directFlag ? selectedArtistRaw : '';
    final selectedArtistEmail = directFlag ? selectedArtistEmailRaw : '';

    final selectedClient = _firstNonEmptyString(
      data['selectedClient'],
      orderData['selectedClient'],
      detailData['selectedClient'],
    );
    final selectedClientEmail = _firstNonEmptyString(
      data['selectedClientEmail'],
      orderData['selectedClientEmail'],
      _asMap(detailData['acceptance'])['selectedClientEmail'],
    ).toLowerCase();

    final groupClientsRaw = <dynamic>[
      ..._asList(groupOrder['clients']),
      ..._asList(groupOrder['groupClients']),
      ..._asList(groupOrder['group_clients']),
      ..._asList(detailData['groupClients']),
      ..._asList(detailData['group_clients']),
      ..._asList(detailData['selectedGroupClients']),
      ..._asList(detailData['selected_group_clients']),
      ..._asList(orderData['clients']),
      ..._asList(orderData['groupClients']),
      ..._asList(orderData['group_clients']),
      ..._asList(data['groupClients']),
      ..._asList(data['group_clients']),
      ..._asList(data['selectedGroupClients']),
      ..._asList(data['selected_group_clients']),
    ];

    final selectedGroupClientEmails = <String>{
      ..._stringList(
        data['selectedGroupClientEmails'],
      ).map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty),
      ..._stringList(
        orderData['selectedGroupClientEmails'],
      ).map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty),
      ...groupClientsRaw
          .whereType<Map>()
          .map(
            (item) =>
                (item['clientEmail'] ?? '').toString().trim().toLowerCase(),
          )
          .where((e) => e.isNotEmpty),
    }.toList(growable: false);

    final profileSnapshot = _asMap(detailData['clientProfileSnapshot']);
    final basic = _asMap(profileSnapshot['basic']);

    acceptedClientNameRaw = _firstNonEmptyString(
      data['acceptedClientName'],
      data['selectedClient'],
      orderData['selectedClient'],
      _asMap(detailData['acceptance'])['acceptedClientName'],
      _asMap(detailData['acceptance'])['selectedClient'],
      basic['name'],
      basic['displayName'],
      basic['fullName'],
    );
    clientName = sourceCollection == 'Company_Custom_Requests'
        ? (acceptedClientNameRaw.trim().isNotEmpty
              ? acceptedClientNameRaw
              : brandName)
        : brandName;

    final photosRaw = _collectPhotoRefs(<Object?>[
      detailData['requestDetails'],
      data['requestDetails'],
      detailData['brandInspirationPhotos'],
      _asMap(detailData['requestDetails'])['brandInspirationPhotos'],
      _asMap(data['requestDetails'])['brandInspirationPhotos'],
      detailData['photos'],
      detailData['inspirationPhotos'],
      _asMap(detailData['requestDetails'])['inspirationPhotos'],
      _asMap(detailData['requestDetails'])['inspirationPhotoUrls'],
      _asMap(detailData['requestDetails'])['inspirationPhotoRefs'],
      _asMap(detailData['requestDetails'])['photos'],
      detailData['clientImages'],
      detailData['inspirationPhoto'],
      detailData['inspirationPhotoUrl'],
      detailData['previewImage'],
      detailData['previewImageAsset'],
      orderData['requestDetails'],
      orderData['photos'],
      orderData['inspirationPhotos'],
      orderData['clientImages'],
      orderData['inspirationPhoto'],
      orderData['inspirationPhotoUrl'],
      orderData['previewImage'],
      orderData['previewImageAsset'],
      _asMap(data['requestDetails'])['inspirationPhotos'],
      _asMap(data['requestDetails'])['inspirationPhotoUrls'],
      _asMap(data['requestDetails'])['inspirationPhotoRefs'],
      _asMap(data['requestDetails'])['clientImages'],
      _asMap(data['requestDetails'])['photos'],
      _asMap(data['requestDetails'])['previewImage'],
      _asMap(data['requestDetails'])['previewImageAsset'],
      data['inspiration_photos'],
      data['photos'],
      data['inspirationPhotos'],
      data['clientImages'],
      data['inspirationPhoto'],
      data['inspirationPhotoUrl'],
      data['previewImage'],
      data['previewImageAsset'],
    ]);

    final hasInspo =
        _asBool(data['hasInspirationPhotos']) ||
        _asBool(data['has_inspiration_photos']) ||
        _asInt(data['photoCount']) > 0 ||
        _asInt(data['photo_count']) > 0 ||
        photosRaw.isNotEmpty;

    final orderType = _resolveOrderType(
      raw: _firstNonEmptyString(
        detailData['orderType'],
        detailData['orderTypeLabel'],
        orderData['type'],
        orderData['orderType'],
        data['orderType'],
        data['orderTypeLabel'],
        data['type'],
      ),
      isGroupOrder: data['isGroupOrder'],
      detailIsGroupOrder: groupOrder['isGroupOrder'],
      hasGroupClients:
          groupClientsRaw.isNotEmpty ||
          selectedGroupClientEmails.length > 1 ||
          _asInt(data['groupClientCount']) > 0,
    );

    final fallbackToPool =
        _asBool(data['fallbackToPool']) ||
        _asBool(orderData['fallbackToPool']) ||
        _asBool(detailData['fallbackToPool']);
    final openToClientPool =
        _asNullableBool(data['openToClientPool']) ??
        _asNullableBool(orderData['openToClientPool']) ??
        _asNullableBool(detailData['openToClientPool']) ??
        true;
    final allowNonLicensed =
        _asNullableBool(data['allowNonLicensed']) ??
        _asNullableBool(data['allow_non_licensed']) ??
        _asNullableBool(orderData['allowNonLicensed']) ??
        _asNullableBool(orderData['allow_non_licensed']) ??
        _asNullableBool(detailData['allowNonLicensed']) ??
        _asNullableBool(detailData['allow_non_licensed']) ??
        true;

    final nailPrefs = _asMap(detailData['nailPreferences']).isNotEmpty
        ? _asMap(detailData['nailPreferences'])
        : _asMap(
            _asMap(detailData['requestDetails'])['nailPreferences'],
          ).isNotEmpty
        ? _asMap(_asMap(detailData['requestDetails'])['nailPreferences'])
        : _asMap(data['nailPreferences']).isNotEmpty
        ? _asMap(data['nailPreferences'])
        : _asMap(_asMap(data['requestDetails'])['nailPreferences']);
    final dims = _asMap(nailPrefs['dimensions']);
    final budgetMap = _asMap(detailData['budget']);
    final artistQuote = _asMap(detailData['artistQuote']).isNotEmpty
        ? _asMap(detailData['artistQuote'])
        : _asMap(data['artistQuote']);
    final paymentMap = _asMap(detailData['payment']).isNotEmpty
        ? _asMap(detailData['payment'])
        : _asMap(data['payment']);
    final shippingLabelMap = _asMap(detailData['shippingLabel']).isNotEmpty
        ? _asMap(detailData['shippingLabel'])
        : _asMap(data['shippingLabel']);
    final shippingMap = _asMap(detailData['shipping']).isNotEmpty
        ? _asMap(detailData['shipping'])
        : _asMap(data['shipping']);
    final shipmentMap = _asMap(detailData['shipment']);
    final artistCompletion = _asMap(detailData['artistCompletion']);
    final designApproval = _asMap(detailData['designApproval']);

    final artistPhotosRaw = _collectPhotoRefs(<Object?>[
      artistCompletion['artistPhotos'],
      detailData['artistCompletedPhotos'],
      data['artistCompletedPhotos'],
      data['artist_completed_photos'],
    ]);
    final artistPhotos = await _resolvePhotoRefs(
      artistPhotosRaw
          .take(_maxResolvedPhotosPerRequest)
          .toList(growable: false),
    );
    final safeClientPhotos = await _resolvePhotoRefs(
      _removeArtistRefsFromClientPhotos(
        clientRefs: photosRaw,
        artistRefs: artistPhotosRaw,
      ).take(_maxResolvedPhotosPerRequest).toList(growable: false),
    );

    final acceptedByArtistEmail = _firstNonEmptyString(
      data['acceptedByArtistEmail'],
      data['accepted_by_artist_email'],
      _asMap(detailData['acceptance'])['acceptedByArtistEmail'],
    ).toLowerCase();
    final acceptedByClientEmail = _firstNonEmptyString(
      data['acceptedByClientEmail'],
      _asMap(detailData['acceptance'])['acceptedByClientEmail'],
    ).toLowerCase();

    final acceptedGroupClientEmails = <String>{
      ..._stringList(
        data['acceptedGroupClientEmails'],
      ).map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty),
      ..._stringList(
        detailData['acceptedGroupClientEmails'],
      ).map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty),
    }.toList(growable: false);

    final declinedByArtistEmails = <String>{
      ..._stringList(
        data['declinedByArtistEmails'],
      ).map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty),
      ..._stringList(
        detailData['declinedByArtistEmails'],
      ).map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty),
    }.toList(growable: false);

    final declinedByClientEmails = <String>{
      ..._stringList(
        data['declinedByClientEmails'],
      ).map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty),
      ..._stringList(
        detailData['declinedByClientEmails'],
      ).map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty),
    }.toList(growable: false);

    final respondedClientEmails = <String>{
      ...acceptedGroupClientEmails,
      ...declinedByClientEmails,
    };
    final groupClientsAllResponded =
        _asBool(data['groupClientsAllResponded']) ||
        _asBool(detailData['groupClientsAllResponded']) ||
        (orderType == RequestOrderTypeV2.group &&
            selectedGroupClientEmails.isNotEmpty &&
            selectedGroupClientEmails.every(respondedClientEmails.contains));

    final clientReview = _asMap(detailData['clientReview']).isNotEmpty
        ? _asMap(detailData['clientReview'])
        : _asMap(data['clientReview']);
    final clientRating =
        _asDouble(data['clientRating']) ?? _asDouble(clientReview['rating']);
    final clientReviewText = _firstNonEmptyString(
      data['clientReviewText'],
      clientReview['comment'],
    );
    final clientReviewSubmittedAt =
        _toDate(data['clientReviewSubmittedAt']) ??
        _toDate(clientReview['submittedAt']);

    final completionReviewStatus = _firstNonEmptyString(
      data['completionReviewStatus'],
      artistCompletion['reviewStatus'],
    ).toLowerCase();
    final completionDeclineReason = _firstNonEmptyString(
      data['completionDeclineReason'],
      artistCompletion['declineReason'],
    );
    final completionDeclineDescription = _firstNonEmptyString(
      data['completionDeclineDescription'],
      artistCompletion['declineDescription'],
    );

    final cancellationData = _asMap(detailData['cancellation']);
    final artistDeclineData = _asMap(detailData['artistDecline']);
    final cancelReason = _firstNonEmptyString(
      data['cancelReason'],
      data['cancel_reason'],
      detailData['cancelReason'],
      cancellationData['reason'],
      cancellationData['description'],
    );
    final declineReason = _firstNonEmptyString(
      data['declineReason'],
      detailData['declineReason'],
      artistDeclineData['reason'],
      artistDeclineData['description'],
      completionDeclineReason,
      completionDeclineDescription,
    );

    final completionDeclinedAt =
        _toDate(data['completionDeclinedAt']) ??
        _toDate(artistCompletion['reviewedAt']) ??
        _toDate(data['completionReviewedAt']);

    final designApprovalStatus = _firstNonEmptyString(
      data['designApprovalStatus'],
      data['design_approval_status'],
      data['clientDesignApprovalStatus'],
      designApproval['status'],
    ).toLowerCase();
    final designSubmittedAt =
        _toDate(data['designSubmittedAt']) ??
        _toDate(data['design_submitted_at']) ??
        _toDate(designApproval['submittedAt']) ??
        _toDate(designApproval['createdAt']);
    final designApprovalDueAt =
        _toDate(data['designApprovalDueAt']) ??
        _toDate(data['design_approval_due_at']) ??
        _toDate(designApproval['dueAt']);
    final designReminderSentAt =
        _toDate(data['designReminderSentAt']) ??
        _toDate(data['design_reminder_sent_at']) ??
        _toDate(designApproval['reminderSentAt']);
    final designPreviewPhotos = await _resolvePhotoRefs(
      _collectPhotoRefs(<Object?>[
        data['designPreviewPhotos'],
        data['design_preview_photos'],
        designApproval['previewPhotos'],
      ]).take(_maxResolvedDesignPreviewPhotos).toList(growable: false),
    );

    final shippingLabelCreatedAt =
        _toDate(data['shippingLabelCreatedAt']) ??
        _toDate(shippingLabelMap['createdAt']);
    final shippingLabelReady =
        _asBool(data['shippingLabelReady']) ||
        _asBool(shippingLabelMap['ready']);
    final shippingLabelPdfUrl = _firstNonEmptyString(
      data['shippingLabelPdfUrl'],
      shippingLabelMap['pdfUrl'],
    );
    final shippingLabelQrData = _firstNonEmptyString(
      data['shippingLabelQrData'],
      shippingLabelMap['qrData'],
    );
    final shippingLabelCarrier = _firstNonEmptyString(
      data['shippingLabelCarrier'],
      shippingLabelMap['carrier'],
    );
    final shippingLabelTrackingNumber = _firstNonEmptyString(
      data['shippingLabelTrackingNumber'],
      shippingLabelMap['trackingNumber'],
    );
    final shippingRequired =
        _asBool(data['shippingRequired']) || _asBool(shippingMap['required']);
    final shippingStatus = _firstNonEmptyString(
      data['shippingStatus'],
      shippingMap['status'],
    );
    final shippingQrCode = _firstNonEmptyString(
      data['shippingQrCode'],
      shippingMap['qrCode'],
      data['shippingLabelQrData'],
      shippingLabelMap['qrData'],
    );
    final shippingQrPayload = _asMap(shippingMap['qrPayload']);

    final detailsShippingMap = _asMap(detailData['shipping']);
    final rootShippingMap = _asMap(data['shipping']);
    final shippingProfileSnapshot = _asMap(detailData['clientProfileSnapshot']);
    final profileAddress = _asMap(shippingProfileSnapshot['address']);
    final rootAddress = _asMap(data['address']);
    final shippingAddressDifferentFromProfile =
        _asBool(detailsShippingMap['isDifferentFromProfile']) ||
        _asBool(rootShippingMap['isDifferentFromProfile']) ||
        _asBool(data['shippingAddressDifferentFromProfile']) ||
        _asBool(data['isDifferentFromProfile']);

    final shippingStreet = _firstNonEmptyString(
      detailsShippingMap['street'],
      rootShippingMap['street'],
      data['shippingStreet'],
      data['shippingAddressStreet'],
      data['shipping_address_street'],
      shippingAddressDifferentFromProfile ? '' : profileAddress['street'],
      shippingAddressDifferentFromProfile ? '' : rootAddress['street'],
    );
    final shippingCity = _firstNonEmptyString(
      detailsShippingMap['city'],
      rootShippingMap['city'],
      data['shippingCity'],
      data['shippingAddressCity'],
      data['shipping_address_city'],
      shippingAddressDifferentFromProfile ? '' : profileAddress['city'],
      shippingAddressDifferentFromProfile ? '' : rootAddress['city'],
    );
    final shippingState = _firstNonEmptyString(
      detailsShippingMap['state'],
      rootShippingMap['state'],
      data['shippingState'],
      data['shippingAddressState'],
      data['shipping_address_state'],
      shippingAddressDifferentFromProfile ? '' : profileAddress['state'],
      shippingAddressDifferentFromProfile ? '' : rootAddress['state'],
    );
    final shippingZip = _firstNonEmptyString(
      detailsShippingMap['zip'],
      rootShippingMap['zip'],
      data['shippingZip'],
      data['shippingAddressZip'],
      data['shipping_address_zip'],
      shippingAddressDifferentFromProfile ? '' : profileAddress['zip'],
      shippingAddressDifferentFromProfile ? '' : rootAddress['zip'],
    );
    final shippingCountry = _firstNonEmptyString(
      detailsShippingMap['country'],
      rootShippingMap['country'],
      data['shippingCountry'],
      data['shippingAddressCountry'],
      data['shipping_address_country'],
      shippingAddressDifferentFromProfile ? '' : profileAddress['country'],
      shippingAddressDifferentFromProfile ? '' : rootAddress['country'],
    );

    final shippingLabelUrl = _firstNonEmptyString(
      data['shippingLabelUrl'],
      shippingMap['labelUrl'],
      data['shippingLabelPdfUrl'],
      shippingLabelMap['pdfUrl'],
    );
    final shippingCreatedAt = _toDate(shippingMap['createdAt']);
    final shippingLastUpdatedAt = _toDate(shippingMap['lastUpdatedAt']);
    final shippingRegeneratedAt = _toDate(shippingMap['regeneratedAt']);
    final shippingRegeneratedBy = _firstNonEmptyString(
      shippingMap['regeneratedBy'],
    );

    final shippedByCourier = _firstNonEmptyString(
      data['shippedByCourier'],
      data['shipped_by_courier'],
      shipmentMap['courier'],
      data['shippingCarrier'],
      data['shippingLabelCarrier'],
      shippingLabelMap['carrier'],
    );
    final trackingNumber = _firstNonEmptyString(
      data['trackingNumber'],
      data['tracking_number'],
      shipmentMap['trackingNumber'],
      data['shippingLabelTrackingNumber'],
      shippingLabelMap['trackingNumber'],
    );
    final shippedAt =
        _toDate(data['shippedAt']) ??
        _toDate(data['shipped_at']) ??
        _toDate(shipmentMap['shippedAt']);
    final deliveredAt =
        _toDate(data['deliveredAt']) ??
        _toDate(data['delivered_at']) ??
        _toDate(shipmentMap['deliveredAt']);

    final rawBudgetMin = _asInt(data['budgetMin']) > 0
        ? _asInt(data['budgetMin'])
        : _asInt(budgetMap['min']);
    final rawBudgetMax = _asInt(data['budgetMax']) > 0
        ? _asInt(data['budgetMax'])
        : _asInt(budgetMap['max']);
    final fallbackBudget = _asInt(data['artistFinalAmount']) > 0
        ? _asInt(data['artistFinalAmount'])
        : _asInt(data['artist_final_amount']);
    final budgetMin = rawBudgetMin > 0
        ? rawBudgetMin
        : (rawBudgetMax > 0 ? rawBudgetMax : fallbackBudget);
    final budgetMax = rawBudgetMax > 0
        ? rawBudgetMax
        : (rawBudgetMin > 0 ? rawBudgetMin : fallbackBudget);

    final clientBudgetMap = _asMap(detailData['clientBudget']);
    final artistBudgetMap = _asMap(detailData['artistBudget']);
    final clientBudgetMin = _asInt(data['clientBudgetMin']) > 0
        ? _asInt(data['clientBudgetMin'])
        : (_asInt(clientBudgetMap['min']) > 0
              ? _asInt(clientBudgetMap['min'])
              : null);
    final clientBudgetMax = _asInt(data['clientBudgetMax']) > 0
        ? _asInt(data['clientBudgetMax'])
        : (_asInt(clientBudgetMap['max']) > 0
              ? _asInt(clientBudgetMap['max'])
              : null);
    final artistBudgetMin = _asInt(data['artistBudgetMin']) > 0
        ? _asInt(data['artistBudgetMin'])
        : (_asInt(artistBudgetMap['min']) > 0
              ? _asInt(artistBudgetMap['min'])
              : (_asInt(budgetMap['min']) > 0
                    ? _asInt(budgetMap['min'])
                    : null));
    final artistBudgetMax = _asInt(data['artistBudgetMax']) > 0
        ? _asInt(data['artistBudgetMax'])
        : (_asInt(artistBudgetMap['max']) > 0
              ? _asInt(artistBudgetMap['max'])
              : (_asInt(budgetMap['max']) > 0
                    ? _asInt(budgetMap['max'])
                    : null));
    final artistFinalAmount =
        _asDouble(artistQuote['total']) ??
        _asDouble(data['artistFinalAmount']) ??
        _asDouble(data['artist_final_amount']);

    final preview = safeClientPhotos.isNotEmpty ? safeClientPhotos.first : '';
    final requestDetailsMap = _asMap(detailData['requestDetails']);
    final clientProfileImageRaw = _firstNonEmptyFromList([
      data['clientProfileImage'],
      data['clientProfilePic'],
      data['clientProfilePhoto'],
      data['clientAvatar'],
      data['clientAvatarUrl'],
      data['companyProfileImage'],
      data['brandProfileImage'],
      data['companyLogoUrl'],
      data['brandLogoUrl'],
      data['client_profile_image'],
      data['logoUrl'],
      basic['profileImagePath'],
      basic['profileImageUrl'],
      basic['avatarUrl'],
      requestDetailsMap['clientProfileImage'],
      requestDetailsMap['clientProfilePic'],
      requestDetailsMap['clientAvatarUrl'],
      requestDetailsMap['profileImageUrl'],
      requestDetailsMap['profileImagePath'],
    ]);

    final acceptedClientProfileImageRaw = _firstNonEmptyString(
      data['acceptedClientProfileImage'],
      data['acceptedClientProfilePic'],
      _asMap(detailData['acceptance'])['acceptedClientProfileImage'],
      _asMap(detailData['acceptance'])['acceptedClientProfilePic'],
      _asMap(detailData['acceptance'])['profileImageUrl'],
      _asMap(detailData['acceptance'])['avatarUrl'],
      _asMap(
        _asMap(detailData['clientProfileSnapshot'])['basic'],
      )['profileImageUrl'],
      _asMap(_asMap(detailData['clientProfileSnapshot'])['basic'])['avatarUrl'],
    );

    String clientProfileImage = clientProfileImageRaw.trim();
    if (clientProfileImage.isNotEmpty) {
      clientProfileImage = (await _resolvePhotoRef(clientProfileImage)).trim();
    }
    String acceptedClientProfileImage = acceptedClientProfileImageRaw.trim();
    if (acceptedClientProfileImage.isNotEmpty) {
      acceptedClientProfileImage = (await _resolvePhotoRef(
        acceptedClientProfileImage,
      )).trim();
    }

    String dim(dynamic v) {
      if (v is num) {
        return v == v.roundToDouble() ? '${v.toInt()} mm' : '$v mm';
      }
      final s = (v ?? '').toString().trim();
      if (s.isEmpty || s == '-') return '-';
      return s.toLowerCase().contains('mm') ? s : '$s mm';
    }

    // Brand-sourced (open client pool) requests often never snapshot the
    // accepting client's own name, photo, or finger measurements onto the
    // request row -- those all stay empty/null there even after
    // acceptance. Fall back to a live lookup of the accepted client's own
    // saved profile for whichever of those pieces are still missing.
    var effectiveDims = dims;
    var effectiveNailShape = nailPrefs['shape'];
    var effectiveNailLength = nailPrefs['length'];
    // Only look at the actual finger keys -- this map can also carry
    // sibling flags like nfcRequested/requiresNfcEligibleClient, which
    // must not be mistaken for a real measurement being present.
    const fingerKeys = <String>[
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
    final hasOwnDims = fingerKeys.any(
      (key) => (dims[key] ?? '').toString().trim().isNotEmpty,
    );
    if (acceptedByClientEmail.isNotEmpty &&
        (!hasOwnDims ||
            acceptedClientNameRaw.trim().isEmpty ||
            acceptedClientProfileImage.trim().isEmpty)) {
      try {
        final clientRow =
            await _supabase
                .from('client')
                .select('nail_preferences,basic,profile')
                .ilike('email', acceptedByClientEmail)
                .maybeSingle() ??
            const <String, dynamic>{};
        if (!hasOwnDims) {
          final clientNailPrefs = _asMap(clientRow['nail_preferences']);
          final clientDims = _asMap(clientNailPrefs['dimensions']);
          if (clientDims.values.any(
            (v) => (v ?? '').toString().trim().isNotEmpty,
          )) {
            effectiveDims = clientDims;
            effectiveNailShape ??= clientNailPrefs['shape'];
            effectiveNailLength ??= clientNailPrefs['length'];
          }
        }
        final clientBasic = _asMap(clientRow['basic']);
        final clientProfile = _asMap(clientRow['profile']);
        if (acceptedClientNameRaw.trim().isEmpty) {
          acceptedClientNameRaw = _firstNonEmptyString(
            clientBasic['name'],
            clientProfile['name'],
          );
        }
        if (acceptedClientProfileImage.trim().isEmpty) {
          final livePhoto = _firstNonEmptyString(
            clientBasic['profileImageUrl'],
            clientBasic['avatarUrl'],
            clientBasic['photoUrl'],
            clientProfile['profileImageUrl'],
            clientProfile['avatarUrl'],
            clientProfile['photoUrl'],
          );
          if (livePhoto.isNotEmpty) {
            acceptedClientProfileImage = (await _resolvePhotoRef(
              livePhoto,
            )).trim();
          }
        }
      } catch (_) {}
    }

    final groupClients = await _parseGroupClients(
      groupOrder,
      dim,
      clients: groupClientsRaw,
    );

    final paymentStatus = _firstNonEmptyString(
      paymentMap['status'],
      data['paymentStatus'],
      data['payment_status'],
    ).toLowerCase();

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

    final orderNumber = canonicalOrderNumber(<Object?>[
      _asMap(data['admin'])['orderNumber'],
      _asMap(detailData['admin'])['orderNumber'],
      data['orderNumber'],
      data['order_number'],
      detailData['orderNumber'],
      data['orderNo'],
      data['orderId'],
    ], sourceCollection: sourceCollection);

    return ClientRequestV2(
      id: (row['id'] ?? '').toString(),
      sourceCollection: sourceCollection,
      orderNumber: orderNumber,
      clientEmail: _firstNonEmptyString(
        data['clientEmail'],
        data['client_email'],
      ).toLowerCase(),
      clientName: clientName,
      title: title,
      subtitle: subtitle,
      neededBy: neededBy,
      submittedAt: submittedAt,
      budgetMin: budgetMin,
      budgetMax: budgetMax,
      clientBudgetMin: clientBudgetMin,
      clientBudgetMax: clientBudgetMax,
      artistBudgetMin: artistBudgetMin,
      artistBudgetMax: artistBudgetMax,
      artistFinalAmount: artistFinalAmount,
      status: status,
      isDirectRequest: directFlag || selectedArtist.isNotEmpty,
      fallbackToPool: fallbackToPool,
      openToClientPool: openToClientPool,
      allowNonLicensed: allowNonLicensed,
      orderType: orderType,
      selectedArtist: selectedArtist,
      selectedArtistEmail: selectedArtistEmail,
      selectedClient: selectedClient,
      selectedClientEmail: selectedClientEmail,
      selectedGroupClientEmails: selectedGroupClientEmails,
      hasInspo: hasInspo,
      nfcRequested:
          _asBool(data['nfcRequested']) ||
          _asBool(data['nfc_requested']) ||
          _asBool(detailData['nfcRequested']) ||
          _asBool(detailData['nfc_requested']),
      clientLocation: location,
      previewImageAsset: preview,
      clientProfileImage: clientProfileImage,
      brandName: brandName,
      acceptedClientName: acceptedClientNameRaw,
      acceptedClientProfileImage: acceptedClientProfileImage,
      bio: _firstNonEmptyString(
        _asMap(detailData['requestDetails'])['description'],
        data['descriptionPreview'],
        data['description'],
      ),
      nailShape: _firstNonEmptyString(effectiveNailShape, data['nailShape']),
      nailLength: _firstNonEmptyString(
        effectiveNailLength,
        data['nailLength'],
      ),
      leftHand: NailDimensionsV2(
        thumb: dim(effectiveDims['lThumb']),
        index: dim(effectiveDims['lIndex']),
        middle: dim(effectiveDims['lMiddle']),
        ring: dim(effectiveDims['lRing']),
        pinky: dim(effectiveDims['lPinky']),
      ),
      rightHand: NailDimensionsV2(
        thumb: dim(effectiveDims['rThumb']),
        index: dim(effectiveDims['rIndex']),
        middle: dim(effectiveDims['rMiddle']),
        ring: dim(effectiveDims['rRing']),
        pinky: dim(effectiveDims['rPinky']),
      ),
      clientImages: safeClientPhotos,
      groupClients: groupClients,
      paymentStatus: paymentStatus,
      paymentLink: _firstNonEmptyString(
        paymentMap['paymentLink'],
        data['paymentLink'],
        data['payment_link'],
      ),
      acceptedByArtistEmail: acceptedByArtistEmail,
      acceptedByClientEmail: acceptedByClientEmail,
      clientResponseStatus: _firstNonEmptyString(
        data['clientResponseStatus'],
        _asMap(paymentMap['acceptance'])['clientResponseStatus'],
        _asMap(detailData['acceptance'])['clientResponseStatus'],
      ).toLowerCase(),
      acceptedGroupClientEmails: acceptedGroupClientEmails,
      declinedByClientEmails: declinedByClientEmails,
      groupClientsAllResponded: groupClientsAllResponded,
      declinedByArtistEmails: declinedByArtistEmails,
      completionReviewStatus: completionReviewStatus,
      completionDeclineReason: completionDeclineReason,
      completionDeclineDescription: completionDeclineDescription,
      cancelReason: cancelReason,
      declineReason: declineReason,
      completionDeclinedAt: completionDeclinedAt,
      designApprovalStatus: designApprovalStatus,
      designSubmittedAt: designSubmittedAt,
      designApprovalDueAt: designApprovalDueAt,
      designReminderSentAt: designReminderSentAt,
      designPreviewPhotos: designPreviewPhotos,
      shippingLabelReady: shippingLabelReady,
      shippingLabelPdfUrl: shippingLabelPdfUrl,
      shippingLabelQrData: shippingLabelQrData,
      shippingLabelCarrier: shippingLabelCarrier,
      shippingLabelTrackingNumber: shippingLabelTrackingNumber,
      shippingLabelCreatedAt: shippingLabelCreatedAt,
      shippingRequired: shippingRequired,
      shippingStatus: shippingStatus,
      shippingQrCode: shippingQrCode,
      shippingQrPayload: shippingQrPayload,
      shippingAddressDifferentFromProfile: shippingAddressDifferentFromProfile,
      shippingStreet: shippingStreet,
      shippingCity: shippingCity,
      shippingState: shippingState,
      shippingZip: shippingZip,
      shippingCountry: shippingCountry,
      shippingLabelUrl: shippingLabelUrl,
      shippingCreatedAt: shippingCreatedAt,
      shippingLastUpdatedAt: shippingLastUpdatedAt,
      shippingRegeneratedAt: shippingRegeneratedAt,
      shippingRegeneratedBy: shippingRegeneratedBy,
      shippedByCourier: shippedByCourier,
      trackingNumber: trackingNumber,
      shippedAt: shippedAt,
      artistImages: artistPhotos,
      deliveredAt: deliveredAt,
      clientRating: clientRating,
      clientReviewText: clientReviewText,
      clientReviewSubmittedAt: clientReviewSubmittedAt,
    );
  }

  static Map<String, dynamic> _flattenSupabaseRequestRow(
    Map<String, dynamic> row,
  ) {
    final data = <String, dynamic>{};

    void addMap(Object? raw) {
      final map = _asMap(raw);
      data.addAll(map);
    }

    data.addAll(row);
    addMap(row['summary']);
    addMap(row['details']);
    addMap(row['payload']);
    addMap(row['request_details']);
    addMap(row['requestDetails']);

    final details = _asMap(row['details']);
    final payload = _asMap(row['payload']);
    final rootRequestDetails = _asMap(row['request_details']).isNotEmpty
        ? _asMap(row['request_details'])
        : _asMap(row['requestDetails']);
    final payloadRequestDetails = _asMap(payload['requestDetails']);
    final requestDetails = _asMap(details['requestDetails']);
    final budget = _asMap(details['budget']);
    final order = _asMap(details['order']);
    final nailPrefs = _asMap(details['nailPreferences']);
    final payment = _asMap(details['payment']);
    final artistQuote = _asMap(details['artistQuote']);
    final designApproval = _asMap(details['designApproval']);
    final artistCompletion = _asMap(details['artistCompletion']);

    data['requestDetails'] ??= requestDetails.isNotEmpty
        ? requestDetails
        : (payloadRequestDetails.isNotEmpty
              ? payloadRequestDetails
              : rootRequestDetails);
    data['budget'] ??= budget.isNotEmpty ? budget : _asMap(payload['budget']);
    data['order'] ??= order.isNotEmpty ? order : _asMap(payload['order']);
    // Prefer populated nail preferences from details/payload over empty root
    // JSON columns created during migration. Client NFC placement is stored
    // under details.nailPreferences.dimensions.nfc and lThumbNfc/rThumbNfc...
    // so this must survive repository flattening.
    final payloadNailPrefs = _asMap(payload['nailPreferences']).isNotEmpty
        ? _asMap(payload['nailPreferences'])
        : _asMap(payload['nail_preferences']);
    final rootNailPrefs = _asMap(row['nailPreferences']).isNotEmpty
        ? _asMap(row['nailPreferences'])
        : _asMap(row['nail_preferences']);
    if (nailPrefs.isNotEmpty) {
      data['nailPreferences'] = nailPrefs;
    } else if (payloadNailPrefs.isNotEmpty) {
      data['nailPreferences'] = payloadNailPrefs;
    } else if (rootNailPrefs.isNotEmpty) {
      data['nailPreferences'] = rootNailPrefs;
    } else {
      data['nailPreferences'] ??= nailPrefs;
    }

    final detailsNfc = _asMap(details['nfc']);
    if (detailsNfc.isNotEmpty) data['nfc'] = detailsNfc;
    data['nfcRequested'] ??=
        details['nfcRequested'] ??
        details['nfc_requested'] ??
        row['nfc_requested'] ??
        row['nfcRequested'];
    data['nfcSelected'] ??=
        details['nfcSelected'] ??
        details['nfc_selected'] ??
        row['nfc_selected'] ??
        row['nfcSelected'];
    data['hasNfc'] ??=
        details['hasNfc'] ??
        details['has_nfc'] ??
        row['has_nfc'] ??
        row['hasNfc'];
    data['nfcEligible'] ??=
        details['nfcEligible'] ??
        details['nfc_eligible'] ??
        row['nfc_eligible'] ??
        row['nfcEligible'];
    data['nfcCount'] ??=
        details['nfcCount'] ??
        details['nfc_count'] ??
        row['nfc_count'] ??
        row['nfcCount'];

    data['payment'] ??= payment;
    data['artistQuote'] ??= artistQuote;
    data['designApproval'] ??= designApproval;
    data['artistCompletion'] ??= artistCompletion;

    data['clientEmail'] ??= row['client_email'];
    data['clientName'] ??= row['client_name'];
    data['selectedArtist'] ??= row['selected_artist'];
    data['selectedArtistEmail'] ??= row['selected_artist_email'];
    data['isDirectRequest'] ??= row['is_direct_request'];
    data['fallbackToPool'] ??= row['fallback_to_pool'];
    data['openToArtistPool'] ??= row['open_to_artist_pool'];
    data['directArtistStatus'] ??= row['direct_artist_status'];
    data['artistPoolStatus'] ??= row['artist_pool_status'];
    data['artistStatus'] ??= row['artist_status'];
    data['clientStatus'] ??= row['client_status'];
    data['orderNumber'] ??= row['order_number'];
    data['createdAt'] ??= row['created_at'];
    data['updatedAt'] ??= row['updated_at'];
    data['inspirationPhotos'] ??= row['inspiration_photos'];
    data['photoCount'] ??= row['photo_count'];
    data['hasInspirationPhotos'] ??= row['has_inspiration_photos'];

    data['acceptedByArtistEmail'] ??= row['accepted_by_artist_email'];
    data['acceptedByArtistName'] ??= row['accepted_by_artist_name'];
    data['artistProfileImage'] ??= row['artist_profile_image'];
    data['artistFinalAmount'] ??= row['artist_final_amount'];
    data['paymentStatus'] ??= row['payment_status'];
    data['paymentLink'] ??= row['payment_link'];
    data['paidAt'] ??= row['paid_at'];
    data['designApprovalStatus'] ??= row['design_approval_status'];
    data['designApprovedAt'] ??= row['design_approved_at'];
    data['designSubmittedAt'] ??= row['design_submitted_at'];
    data['designApprovalDueAt'] ??= row['design_approval_due_at'];
    data['designReminderSentAt'] ??= row['design_reminder_sent_at'];
    data['designPreviewPhotos'] ??= row['design_preview_photos'];
    data['artistCompletedPhotos'] ??= row['artist_completed_photos'];
    data['shippedByCourier'] ??= row['shipped_by_courier'];
    data['trackingNumber'] ??= row['tracking_number'];
    data['shippedAt'] ??= row['shipped_at'];
    data['deliveredAt'] ??= row['delivered_at'];

    if (budget.isNotEmpty) {
      data['budgetMin'] ??= budget['min'];
      data['budgetMax'] ??= budget['max'];
    }

    final mergedRequestDetails = data['requestDetails'] is Map
        ? _asMap(data['requestDetails'])
        : const <String, dynamic>{};
    if (mergedRequestDetails.isNotEmpty) {
      data['descriptionPreview'] ??= mergedRequestDetails['description'];
      data['description'] ??= mergedRequestDetails['description'];
      data['needBy'] ??= mergedRequestDetails['needBy'];
      data['clientLocation'] ??= mergedRequestDetails['clientLocation'];
    }

    return data;
  }

  static RequestStatusV2? _mapStatus(Object? raw) {
    final s = (raw ?? '').toString().trim().toLowerCase();
    if (s.isEmpty) return null;

    switch (s) {
      case 'pending':
      case 'submitted':
      case 'review':
      case 'in_review':
      case 'in review':
      case 'inreview':
        return RequestStatusV2.inReview;
      case 'accepted':
        return RequestStatusV2.designing;
      case 'designing':
        return RequestStatusV2.designing;
      case 'in_progress':
      case 'in progress':
      case 'inprogress':
        return RequestStatusV2.designing;
      case 'completed':
        return RequestStatusV2.completed;
      case 'shipped':
        return RequestStatusV2.shipped;
      case 'delivered':
        return RequestStatusV2.delivered;
      case 'declined':
        return RequestStatusV2.declined;
      case 'cancelled':
      case 'canceled':
        return RequestStatusV2.cancelled;
      case 'expired':
        return RequestStatusV2.expired;
      default:
        return null;
    }
  }

  static RequestOrderTypeV2 _mapOrderType(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.contains('group')) return RequestOrderTypeV2.group;
    return RequestOrderTypeV2.single;
  }

  static RequestOrderTypeV2 _resolveOrderType({
    required String raw,
    Object? isGroupOrder,
    Object? detailIsGroupOrder,
    bool hasGroupClients = false,
  }) {
    final mapped = _mapOrderType(raw);
    if (mapped == RequestOrderTypeV2.group ||
        _asBool(isGroupOrder) ||
        _asBool(detailIsGroupOrder) ||
        hasGroupClients) {
      return RequestOrderTypeV2.group;
    }
    return RequestOrderTypeV2.single;
  }

  static Future<List<GroupOrderClientV2>> _parseGroupClients(
    Map<String, dynamic> groupOrder,
    String Function(dynamic v) dim, {
    List<dynamic>? clients,
  }) async {
    final raw = clients ?? _asList(groupOrder['clients']);
    if (raw.isEmpty) return const <GroupOrderClientV2>[];

    final parsed = <GroupOrderClientV2>[];
    for (final item in raw) {
      if (item is! Map) {
        final text = (item ?? '').toString().trim();
        if (text.isEmpty || text.toLowerCase() == 'null') continue;
        final isEmail = text.contains('@');
        parsed.add(
          GroupOrderClientV2(
            slotIndex: parsed.length + 1,
            clientId: '',
            clientName: isEmail ? '' : text,
            clientEmail: isEmail ? text.toLowerCase() : '',
            nailShape: '',
            nailLength: '',
            leftHand: const NailDimensionsV2(
              thumb: '',
              index: '',
              middle: '',
              ring: '',
              pinky: '',
            ),
            rightHand: const NailDimensionsV2(
              thumb: '',
              index: '',
              middle: '',
              ring: '',
              pinky: '',
            ),
          ),
        );
        continue;
      }
      final map = Map<String, dynamic>.from(item);
      final clientId = _firstNonEmptyString(map['clientId']).trim();
      final savedName = _firstNonEmptyString(map['clientName'], map['name']);
      final clientEmail = _firstNonEmptyString(
        map['clientEmail'],
      ).trim().toLowerCase();
      final nail = _asMap(map['savedNails']).isNotEmpty
          ? _asMap(map['savedNails'])
          : _asMap(map['draftNails']).isNotEmpty
          ? _asMap(map['draftNails'])
          : _asMap(map['nailPreferences']);
      final dims = _asMap(nail['dimensions']).isNotEmpty
          ? _asMap(nail['dimensions'])
          : _asMap(map['dimensions']);
      parsed.add(
        GroupOrderClientV2(
          slotIndex: _asInt(map['slotIndex']) > 0
              ? _asInt(map['slotIndex'])
              : parsed.length + 1,
          clientId: clientId,
          clientName: savedName,
          clientEmail: clientEmail,
          nailShape: _firstNonEmptyString(nail['shape'], map['nailShape']),
          nailLength: _firstNonEmptyString(nail['length'], map['nailLength']),
          leftHand: NailDimensionsV2(
            thumb: dim(dims['lThumb']),
            index: dim(dims['lIndex']),
            middle: dim(dims['lMiddle']),
            ring: dim(dims['lRing']),
            pinky: dim(dims['lPinky']),
          ),
          rightHand: NailDimensionsV2(
            thumb: dim(dims['rThumb']),
            index: dim(dims['rIndex']),
            middle: dim(dims['rMiddle']),
            ring: dim(dims['rRing']),
            pinky: dim(dims['rPinky']),
          ),
        ),
      );
    }
    return parsed;
  }

  static DateTime? _toDate(Object? value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static String _locationFromData(Map<String, dynamic> data) {
    final direct = _firstNonEmptyString(data['clientLocation']);
    if (direct.isNotEmpty) return direct;

    final city = _firstNonEmptyString(data['clientCity'], data['city']);
    final state = _firstNonEmptyString(data['clientState'], data['state']);

    if (city.isEmpty && state.isEmpty) return '';
    if (city.isEmpty) return state;
    if (state.isEmpty) return city;
    return '$city, $state';
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static bool _asBool(Object? value) {
    if (value is bool) return value;
    final s = value?.toString().trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes';
  }

  static bool? _asNullableBool(Object? value) {
    if (value == null) return null;
    if (value is bool) return value;
    final s = value.toString().trim().toLowerCase();
    if (s.isEmpty) return null;
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
    return null;
  }

  static String _firstNonEmptyString([
    Object? a,
    Object? b,
    Object? c,
    Object? d,
    Object? e,
    Object? f,
    Object? g,
    Object? h,
    Object? i,
    Object? j,
    Object? k,
    Object? l,
  ]) {
    final candidates = <Object?>[a, b, c, d, e, f, g, h, i, j, k, l];
    for (final candidate in candidates) {
      final text = (candidate ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static String _firstNonEmptyFromList(Iterable<Object?> values) {
    for (final candidate in values) {
      final text = (candidate ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static String _dimValue(dynamic value) {
    if (value is num) {
      return value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toString();
    }
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? '-' : text;
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String) {
      final text = value.trim();
      if (text.isEmpty) return const <String, dynamic>{};
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) {
          return Map<String, dynamic>.from(decoded);
        }
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }
    return const <String, dynamic>{};
  }

  static List<dynamic> _asList(Object? value) {
    if (value is List) return value;
    if (value is String) {
      final text = value.trim();
      if (text.isEmpty) return const <dynamic>[];
      try {
        final decoded = jsonDecode(text);
        if (decoded is List) return decoded;
      } catch (_) {}
    }
    return const <dynamic>[];
  }

  static List<String> _stringList(Object? value) {
    if (value is List) {
      return value
          .map((e) => (e ?? '').toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }
    if (value is String && value.trim().isNotEmpty)
      return <String>[value.trim()];
    return const <String>[];
  }

  static List<String> _collectPhotoRefs(List<Object?> sources) {
    final out = <String>[];
    final seen = <String>{};

    bool isPlaceholderPhoto(String value) {
      final v = value.trim().toLowerCase();
      if (v.isEmpty) return true;
      if (v.startsWith('data:image/')) {
        final comma = v.indexOf(',');
        if (comma <= 0 || comma >= v.length - 1) return true;
        if (v.length < 200) return true;
      }
      final fileName = v.split(RegExp(r'[\\/]+')).last;
      const exactPlaceholders = <String>{
        'blank',
        'placeholder',
        'transparent',
        'default',
        'no-image',
        'no_image',
        'noimage',
      };
      if (exactPlaceholders.contains(fileName)) return true;
      if (fileName.contains('blank') ||
          fileName.contains('placeholder') ||
          fileName.contains('transparent')) {
        return true;
      }
      return false;
    }

    void addValue(Object? item) {
      if (item is String) {
        final value = item.trim();
        if (value.isNotEmpty && !isPlaceholderPhoto(value) && seen.add(value)) {
          out.add(value);
        }
        return;
      }
      if (item is Iterable) {
        for (final nested in item) {
          addValue(nested);
        }
        return;
      }
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        final primaryCandidates = <Object?>[
          map['url'],
          map['downloadUrl'],
          map['downloadURL'],
          map['imageUrl'],
          map['imageURL'],
          map['photoUrl'],
          map['image'],
          map['photo'],
          map['path'],
          map['ref'],
          map['storagePath'],
          map['fullPath'],
          map['src'],
          map['uri'],
        ];
        for (final candidate in primaryCandidates) {
          addValue(candidate);
        }
        for (final entry in map.entries) {
          final k = entry.key.toString().toLowerCase();
          if (k.contains('photo') ||
              k.contains('image') ||
              k.contains('inspiration') ||
              k.contains('preview') ||
              k.endsWith('url') ||
              k.endsWith('path')) {
            addValue(entry.value);
          }
        }
      }
    }

    for (final source in sources) {
      addValue(source);
    }
    return out.toSet().toList(growable: false);
  }

  static bool _isRenderableImageRef(String value) {
    final v = value.trim();
    if (v.isEmpty) return false;
    if (v.startsWith('http://') || v.startsWith('https://')) return true;
    if (v.startsWith('data:')) return true;
    if (v.startsWith('assets/')) return true;
    if (v.startsWith('content://')) return true;
    if (!kIsWeb && (v.startsWith('file://') || v.startsWith('/'))) return true;
    return false;
  }

  static Future<String> _resolvePhotoRef(String value) async {
    final v = _decodeUriSafelyRepeatedly(value).trim();
    if (v.isEmpty) return '';
    final cached = _resolvedPhotoRefCache[v];
    if (cached != null) return cached;
    if (_missingPhotoRefCache.contains(v)) return v;
    if (_isRenderableImageRef(v)) return v;
    final inflight = _inflightPhotoRefResolvers[v];
    if (inflight != null) return inflight;

    final future = () async {
      if (v.startsWith('profile-pictures/')) {
        final resolved = _supabase.storage
            .from('profile-pictures')
            .getPublicUrl(v.substring('profile-pictures/'.length))
            .trim();
        _resolvedPhotoRefCache[v] = resolved;
        return resolved;
      }

      if (v.startsWith('portfolio-images/')) {
        final resolved = _supabase.storage
            .from('portfolio-images')
            .getPublicUrl(v.substring('portfolio-images/'.length))
            .trim();
        _resolvedPhotoRefCache[v] = resolved;
        return resolved;
      }

      if (v.startsWith('request-inspiration-photos/')) {
        final resolved = _supabase.storage
            .from('request-inspiration-photos')
            .getPublicUrl(v.substring('request-inspiration-photos/'.length))
            .trim();
        _resolvedPhotoRefCache[v] = resolved;
        return resolved;
      }

      if (v.startsWith('clients/') ||
          v.startsWith('client_custom_requests/') ||
          v.startsWith('company_custom_requests/')) {
        final resolved = _supabase.storage
            .from('request-inspiration-photos')
            .getPublicUrl(v)
            .trim();
        _resolvedPhotoRefCache[v] = resolved;
        return resolved;
      }

      if (v.startsWith('artists/') ||
          v.startsWith('client_artists/') ||
          v.startsWith('portfolio/')) {
        final resolved = _supabase.storage
            .from('portfolio-images')
            .getPublicUrl(v)
            .trim();
        _resolvedPhotoRefCache[v] = resolved;
        return resolved;
      }

      if (!v.contains('://') && _looksLikeStoragePath(v)) {
        final resolved = _supabase.storage
            .from('request-inspiration-photos')
            .getPublicUrl(v)
            .trim();
        _resolvedPhotoRefCache[v] = resolved;
        return resolved;
      }

      return '';
    }();

    _inflightPhotoRefResolvers[v] = future;
    try {
      return await future;
    } catch (_) {
      _missingPhotoRefCache.add(v);
      return v;
    } finally {
      _inflightPhotoRefResolvers.remove(v);
    }
  }

  static Future<List<String>> _resolvePhotoRefs(List<String> values) async {
    final resolved = await Future.wait(values.map(_resolvePhotoRef));
    return resolved.where((e) => e.trim().isNotEmpty).toList(growable: false);
  }

  static String _decodeUriSafelyRepeatedly(String value) {
    var current = value.trim();
    for (var i = 0; i < 3; i++) {
      try {
        final decoded = Uri.decodeFull(current);
        if (decoded == current) break;
        current = decoded;
      } catch (_) {
        break;
      }
    }
    return current;
  }

  static bool _looksLikeStoragePath(String value) {
    final v = value.trim().toLowerCase();
    if (v.isEmpty) return false;
    if (v.startsWith('/') ||
        v.startsWith('assets/') ||
        v.startsWith('file://') ||
        v.startsWith('http://') ||
        v.startsWith('https://') ||
        v.startsWith('data:') ||
        v.startsWith('blob:') ||
        v.startsWith('content://')) {
      return false;
    }
    if (v.contains(':\\')) return false;
    return v.contains('/');
  }

  static List<String> _removeArtistRefsFromClientPhotos({
    required List<String> clientRefs,
    required List<String> artistRefs,
  }) {
    final artistSet = artistRefs
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    final out = <String>[];
    for (final raw in clientRefs) {
      final value = raw.trim();
      if (value.isEmpty) continue;
      final lower = value.toLowerCase();
      final looksArtistAsset =
          lower.contains('artistcompleted') ||
          lower.contains('artist_completed') ||
          lower.contains('completed_set') ||
          lower.contains('completedart') ||
          lower.contains('artistphotos') ||
          lower.contains('artistuploaded');
      if (looksArtistAsset) continue;
      final looksArtistPath = artistSet.any(
        (a) =>
            a.isNotEmpty &&
            (a.contains('artistcompleted') ||
                a.contains('artist_completed') ||
                a.contains('completed_set')),
      );
      if (looksArtistPath && artistSet.contains(lower)) continue;
      out.add(value);
    }
    return out.toSet().toList(growable: false);
  }
}
