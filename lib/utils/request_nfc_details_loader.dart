import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

class RequestFingerNfcSelection {
  const RequestFingerNfcSelection({
    this.left = const <String, bool>{},
    this.right = const <String, bool>{},
  });

  static const emptyConst = RequestFingerNfcSelection(
    left: <String, bool>{},
    right: <String, bool>{},
  );

  final Map<String, bool> left;
  final Map<String, bool> right;

  bool get anySelected =>
      left.values.any((value) => value) || right.values.any((value) => value);

  factory RequestFingerNfcSelection.fromDimensions(Map<String, dynamic> map) {
    bool truthy(dynamic value) {
      if (value == true) return true;
      // IMPORTANT: do not treat nail dimension values such as 10 or 3 as NFC.
      // Numeric support is only for explicit boolean-like DB flags stored as 1.
      if (value is num) return value == 1;
      final text = (value ?? '').toString().trim().toLowerCase();
      return text == 'true' ||
          text == 'yes' ||
          text == '1' ||
          text == 'selected' ||
          text == 'requested' ||
          text == 'enabled';
    }

    dynamic nfcValue(String key) {
      final nfc = map['nfc'];
      if (nfc is Map) {
        return map['${key}Nfc'] ?? nfc[key] ?? nfc['${key}Nfc'];
      }
      // IMPORTANT: only read explicit NFC flags. Do not fall back to map[key],
      // because map[key] is the nail dimension (for example lThumb = 10).
      return map['${key}Nfc'];
    }

    return RequestFingerNfcSelection(
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

  factory RequestFingerNfcSelection.fromEligibleDimensions(
    Map<String, dynamic> map,
  ) {
    Map<String, dynamic> dimensions = asDimensionsMap(map);

    bool eligible(String key) {
      final raw = dimensions[key];
      final text = (raw ?? '').toString().trim();
      if (text.isEmpty || text.toLowerCase() == 'null') return false;
      final cleaned = text.replaceAll(RegExp(r'[^0-9.]'), '');
      final parsed = double.tryParse(cleaned);
      return parsed != null && parsed.isFinite && parsed >= 8;
    }

    return RequestFingerNfcSelection(
      left: <String, bool>{
        'thumb': eligible('lThumb'),
        'index': eligible('lIndex'),
        'middle': eligible('lMiddle'),
        'ring': eligible('lRing'),
        'pinky': eligible('lPinky'),
      },
      right: <String, bool>{
        'thumb': eligible('rThumb'),
        'index': eligible('rIndex'),
        'middle': eligible('rMiddle'),
        'ring': eligible('rRing'),
        'pinky': eligible('rPinky'),
      },
    );
  }
}

Map<String, dynamic> asDimensionsMap(Map<String, dynamic> map) {
  final nested = map['dimensions'];
  if (nested is Map<String, dynamic>) return Map<String, dynamic>.from(nested);
  if (nested is Map) {
    return nested.map((key, value) => MapEntry(key.toString(), value));
  }
  return map;
}

class RequestNfcDetails {
  const RequestNfcDetails({
    this.main = RequestFingerNfcSelection.emptyConst,
    this.groupBySlotIndex = const <int, RequestFingerNfcSelection>{},
  });

  static const emptyConst = RequestNfcDetails();

  final RequestFingerNfcSelection main;
  final Map<int, RequestFingerNfcSelection> groupBySlotIndex;
}

bool _truthy(dynamic value) {
  if (value == true) return true;
  if (value is num) return value == 1;
  final text = (value ?? '').toString().trim().toLowerCase();
  return text == 'true' ||
      text == 'yes' ||
      text == '1' ||
      text == 'selected' ||
      text == 'requested' ||
      text == 'enabled';
}

bool _requestHasNfc(Map<String, dynamic> source) {
  Map<String, dynamic> asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
    return <String, dynamic>{};
  }

  final summary = asMap(source['summary']);
  final nfc = asMap(source['nfc']);
  // The flat nfc_requested/nfcRequested column can go stale relative to the
  // payload/details JSONB blobs -- e.g. an "open pool" brand request whose
  // flat column reads false while payload.nfcRequested/details.nfcRequested
  // are true. Check those blobs too so this never under-reports.
  final payload = asMap(source['payload']);
  final details = asMap(source['details']);
  return _truthy(source['nfcRequested']) ||
      _truthy(source['nfcSelected']) ||
      _truthy(source['hasNfc']) ||
      _truthy(source['nfc_requested']) ||
      _truthy(source['nfc_selected']) ||
      _truthy(source['has_nfc']) ||
      _truthy(summary['nfcRequested']) ||
      _truthy(summary['nfcSelected']) ||
      _truthy(summary['hasNfc']) ||
      _truthy(summary['nfc_requested']) ||
      _truthy(summary['nfc_selected']) ||
      _truthy(summary['has_nfc']) ||
      _truthy(payload['nfcRequested']) ||
      _truthy(payload['nfcSelected']) ||
      _truthy(payload['hasNfc']) ||
      _truthy(payload['nfc_requested']) ||
      _truthy(payload['requiresNfcEligibleClient']) ||
      _truthy(details['nfcRequested']) ||
      _truthy(details['nfcSelected']) ||
      _truthy(details['hasNfc']) ||
      _truthy(details['nfc_requested']) ||
      _truthy(details['requiresNfcEligibleClient']) ||
      _truthy(nfc['requested']) ||
      _truthy(nfc['selected']) ||
      _truthy(nfc['hasNfc']) ||
      _truthy(nfc['has_nfc']);
}

String _extractAcceptedClientEmail(
  Map<String, dynamic> root,
  Map<String, dynamic> details,
) {
  Map<String, dynamic> asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
    return <String, dynamic>{};
  }

  final rootAcceptance = asMap(root['acceptance']);
  final detailsAcceptance = asMap(details['acceptance']);
  for (final candidate in <dynamic>[
    root['accepted_by_client_email'],
    root['acceptedByClientEmail'],
    rootAcceptance['acceptedByClientEmail'],
    details['accepted_by_client_email'],
    details['acceptedByClientEmail'],
    detailsAcceptance['acceptedByClientEmail'],
  ]) {
    final text = (candidate ?? '').toString().trim();
    if (text.isNotEmpty) return text.toLowerCase();
  }
  return '';
}

/// Some brand-sourced (open client pool) requests never snapshot the
/// accepting client's own finger measurements onto the request row itself
/// -- `nailPreferences.dimensions` stays null there even after acceptance.
/// When that happens, fall back to the accepted client's own saved
/// measurements on their profile.
Future<RequestFingerNfcSelection> _loadFallbackFromClientProfile(
  String acceptedClientEmail,
) async {
  if (acceptedClientEmail.isEmpty) return RequestFingerNfcSelection.emptyConst;
  try {
    final supabase = Supabase.instance.client;
    final clientRow =
        await supabase
            .from('client')
            .select('nail_preferences')
            .ilike('email', acceptedClientEmail)
            .maybeSingle() ??
        const <String, dynamic>{};
    final nailPrefs = clientRow['nail_preferences'];
    final dimensions = (nailPrefs is Map ? nailPrefs['dimensions'] : null);
    if (dimensions is! Map) return RequestFingerNfcSelection.emptyConst;
    final dimsMap = dimensions.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    return RequestFingerNfcSelection.fromEligibleDimensions(dimsMap);
  } catch (_) {
    return RequestFingerNfcSelection.emptyConst;
  }
}

Future<RequestNfcDetails> loadRequestNfcDetails({
  required String sourceCollection,
  required String requestId,
  String requestOrderNumber = '',
}) async {
  try {
    final table = _tableForCollection(sourceCollection);
    final detailsTable = _detailsTableFor(table);
    final supabase = Supabase.instance.client;

    Map<String, dynamic> asMap(dynamic value) {
      if (value is String) {
        final text = value.trim();
        if (text.startsWith('{') && text.endsWith('}')) {
          try {
            final decoded = jsonDecode(text);
            if (decoded is Map) {
              return decoded.map(
                (key, value) => MapEntry(key.toString(), value),
              );
            }
          } catch (_) {}
        }
      }
      if (value is Map<String, dynamic>)
        return Map<String, dynamic>.from(value);
      if (value is Map) {
        return value.map((key, value) => MapEntry(key.toString(), value));
      }
      return <String, dynamic>{};
    }

    Map<String, dynamic> rootRow =
        await supabase.from(table).select().eq('id', requestId).maybeSingle() ??
        const <String, dynamic>{};

    if (rootRow.isEmpty && requestOrderNumber.trim().isNotEmpty) {
      rootRow =
          await supabase
              .from(table)
              .select()
              .or(
                'order_number.eq.${requestOrderNumber.trim()},request_number.eq.${requestOrderNumber.trim()},client_request_number.eq.${requestOrderNumber.trim()}',
              )
              .maybeSingle() ??
          const <String, dynamic>{};
    }

    Map<String, dynamic> mergedDetailRows(List<dynamic> rows) {
      Map<String, dynamic> payloadDoc = <String, dynamic>{};
      final merged = <String, dynamic>{};

      bool isPayloadRow(Map<String, dynamic> row) {
        final docId = (row['doc_id'] ?? row['detail_key'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final id = (row['id'] ?? '').toString().trim().toLowerCase();
        return docId == 'payload' || id.endsWith(':payload');
      }

      for (final raw in rows) {
        final row = asMap(raw);
        if (row.isEmpty) continue;
        final payload = asMap(row['payload']);
        final data = asMap(row['data']);
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

    final resolvedRequestId = (rootRow['id'] ?? requestId).toString().trim();
    List<dynamic> detailRows = const <dynamic>[];
    try {
      detailRows = await supabase
          .from(detailsTable)
          .select()
          .eq('request_id', resolvedRequestId);
    } catch (_) {}

    final detailsRow = mergedDetailRows(detailRows);
    final rootMap = asMap(rootRow);
    final parsed = _parseRequestNfc(root: rootMap, details: detailsRow);
    if (parsed.main.anySelected) return parsed;

    final nfcWasRequested =
        _requestHasNfc(rootMap) || _requestHasNfc(detailsRow);
    if (!nfcWasRequested) return parsed;

    final acceptedClientEmail = _extractAcceptedClientEmail(
      rootMap,
      detailsRow,
    );
    if (acceptedClientEmail.isEmpty) return parsed;

    final fallbackMain = await _loadFallbackFromClientProfile(
      acceptedClientEmail,
    );
    if (!fallbackMain.anySelected) return parsed;
    return RequestNfcDetails(
      main: fallbackMain,
      groupBySlotIndex: parsed.groupBySlotIndex,
    );
  } catch (_) {
    return RequestNfcDetails.emptyConst;
  }
}

RequestNfcDetails _parseRequestNfc({
  required Map<String, dynamic> root,
  required Map<String, dynamic> details,
}) {
  Map<String, dynamic> asMap(dynamic value) {
    if (value is String) {
      final text = value.trim();
      if (text.startsWith('{') && text.endsWith('}')) {
        try {
          final decoded = jsonDecode(text);
          if (decoded is Map) {
            return decoded.map((key, value) => MapEntry(key.toString(), value));
          }
        } catch (_) {}
      }
    }
    if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  List<dynamic> asList(dynamic value) =>
      value is List ? value : const <dynamic>[];

  Map<String, dynamic> payloadOf(Map<String, dynamic> source) {
    final payload = asMap(source['payload']);
    if (payload.isNotEmpty) return payload;
    final detailsMap = asMap(source['details']);
    final detailsPayload = asMap(detailsMap['payload']);
    if (detailsPayload.isNotEmpty) return detailsPayload;
    return detailsMap.isNotEmpty ? detailsMap : source;
  }

  Map<String, dynamic> requestDetailsOf(Map<String, dynamic> source) {
    final payload = payloadOf(source);
    return asMap(
          payload['requestDetails'] ?? payload['request_details'],
        ).isNotEmpty
        ? asMap(payload['requestDetails'] ?? payload['request_details'])
        : asMap(
            source['requestDetails'] ?? source['request_details'],
          ).isNotEmpty
        ? asMap(source['requestDetails'] ?? source['request_details'])
        : asMap(
            asMap(source['details'])['requestDetails'] ??
                asMap(source['details'])['request_details'],
          );
  }

  Map<String, dynamic> orderOf(Map<String, dynamic> source) {
    final payload = payloadOf(source);
    return asMap(
          payload['order'] ?? payload['orderData'] ?? payload['order_data'],
        ).isNotEmpty
        ? asMap(
            payload['order'] ?? payload['orderData'] ?? payload['order_data'],
          )
        : asMap(
            source['order'] ?? source['orderData'] ?? source['order_data'],
          ).isNotEmpty
        ? asMap(source['order'] ?? source['orderData'] ?? source['order_data'])
        : asMap(
            asMap(source['details'])['order'] ??
                asMap(source['details'])['orderData'] ??
                asMap(source['details'])['order_data'],
          );
  }

  Map<String, dynamic> snapshotOf(Map<String, dynamic> source) {
    final payload = payloadOf(source);
    return asMap(
      payload['clientProfileSnapshot'] ??
          payload['client_profile_snapshot'] ??
          source['clientProfileSnapshot'] ??
          source['client_profile_snapshot'] ??
          asMap(source['details'])['clientProfileSnapshot'] ??
          asMap(source['details'])['client_profile_snapshot'],
    );
  }

  Iterable<Map<String, dynamic>> containersOf(
    Map<String, dynamic> source,
  ) sync* {
    final detailsMap = asMap(source['details']);
    final dataMap = asMap(source['data']);
    final payload = payloadOf(source);
    final requestDetails = requestDetailsOf(source);
    final order = orderOf(source);
    final snapshot = snapshotOf(source);
    final detailsPayload = asMap(detailsMap['payload']);
    final detailsRequestDetails = asMap(
      detailsMap['requestDetails'] ?? detailsMap['request_details'],
    );
    final detailsOrder = asMap(
      detailsMap['order'] ??
          detailsMap['orderData'] ??
          detailsMap['order_data'],
    );
    final detailsSnapshot = asMap(
      detailsMap['clientProfileSnapshot'] ??
          detailsMap['client_profile_snapshot'],
    );
    final dataRequestDetails = asMap(
      dataMap['requestDetails'] ?? dataMap['request_details'],
    );
    final dataOrder = asMap(
      dataMap['order'] ?? dataMap['orderData'] ?? dataMap['order_data'],
    );
    final dataSnapshot = asMap(
      dataMap['clientProfileSnapshot'] ?? dataMap['client_profile_snapshot'],
    );

    yield source;
    if (detailsMap.isNotEmpty) yield detailsMap;
    if (dataMap.isNotEmpty) yield dataMap;
    if (payload.isNotEmpty) yield payload;
    if (detailsPayload.isNotEmpty) yield detailsPayload;
    if (requestDetails.isNotEmpty) yield requestDetails;
    if (detailsRequestDetails.isNotEmpty) yield detailsRequestDetails;
    if (dataRequestDetails.isNotEmpty) yield dataRequestDetails;
    if (order.isNotEmpty) yield order;
    if (detailsOrder.isNotEmpty) yield detailsOrder;
    if (dataOrder.isNotEmpty) yield dataOrder;
    if (snapshot.isNotEmpty) yield snapshot;
    if (detailsSnapshot.isNotEmpty) yield detailsSnapshot;
    if (dataSnapshot.isNotEmpty) yield dataSnapshot;
  }

  bool truthy(dynamic value) {
    if (value == true) return true;
    if (value is num) return value == 1;
    final text = (value ?? '').toString().trim().toLowerCase();
    return text == 'true' ||
        text == 'yes' ||
        text == '1' ||
        text == 'selected' ||
        text == 'requested' ||
        text == 'enabled';
  }

  bool requestHasNfc(Map<String, dynamic> source) {
    final summary = asMap(source['summary']);
    final nfc = asMap(source['nfc']);
    final payload = asMap(source['payload']);
    final details = asMap(source['details']);
    return truthy(source['nfcRequested']) ||
        truthy(source['nfcSelected']) ||
        truthy(source['hasNfc']) ||
        truthy(source['nfc_requested']) ||
        truthy(source['nfc_selected']) ||
        truthy(source['has_nfc']) ||
        truthy(summary['nfcRequested']) ||
        truthy(summary['nfcSelected']) ||
        truthy(summary['hasNfc']) ||
        truthy(summary['nfc_requested']) ||
        truthy(summary['nfc_selected']) ||
        truthy(summary['has_nfc']) ||
        truthy(payload['nfcRequested']) ||
        truthy(payload['nfcSelected']) ||
        truthy(payload['hasNfc']) ||
        truthy(payload['nfc_requested']) ||
        truthy(payload['requiresNfcEligibleClient']) ||
        truthy(details['nfcRequested']) ||
        truthy(details['nfcSelected']) ||
        truthy(details['hasNfc']) ||
        truthy(details['nfc_requested']) ||
        truthy(details['requiresNfcEligibleClient']) ||
        truthy(nfc['requested']) ||
        truthy(nfc['selected']) ||
        truthy(nfc['hasNfc']) ||
        truthy(nfc['has_nfc']);
  }

  RequestFingerNfcSelection firstSelectionFrom(
    Iterable<Map<String, dynamic>> containers, {
    bool allowEligibleFallback = false,
  }) {
    final candidates = <Map<String, dynamic>>[];
    for (final source in containers) {
      candidates.add(
        asMap(
          asMap(
            source['nailPreferences'] ?? source['nail_preferences'],
          )['dimensions'],
        ),
      );
      candidates.add(
        asMap(
          asMap(
            source['apiNailMeasurements'] ?? source['api_nail_measurements'],
          )['dimensions'],
        ),
      );
      candidates.add(asMap(source['dimensions']));
    }
    for (final candidate in candidates) {
      if (candidate.isEmpty) continue;
      final parsed = RequestFingerNfcSelection.fromDimensions(candidate);
      if (parsed.anySelected) return parsed;
    }
    if (allowEligibleFallback) {
      for (final candidate in candidates) {
        if (candidate.isEmpty) continue;
        final parsed = RequestFingerNfcSelection.fromEligibleDimensions(
          candidate,
        );
        if (parsed.anySelected) return parsed;
      }
    }
    return RequestFingerNfcSelection.emptyConst;
  }

  final rootHasNfc = requestHasNfc(root);
  final detailsHasNfc = requestHasNfc(details);
  final main = firstSelectionFrom(<Map<String, dynamic>>[
    ...containersOf(details),
    ...containersOf(root),
  ], allowEligibleFallback: rootHasNfc || detailsHasNfc);

  final groupBySlot = <int, RequestFingerNfcSelection>{};

  Iterable<List<dynamic>> groupClientSources(
    Map<String, dynamic> source,
  ) sync* {
    final payload = payloadOf(source);
    final requestDetails = requestDetailsOf(source);
    final order = orderOf(source);
    final detailsMap = asMap(source['details']);

    yield asList(
      asMap(source['groupOrder'] ?? source['group_order'])['clients'],
    );
    yield asList(source['groupClients'] ?? source['group_clients']);
    yield asList(
      asMap(payload['groupOrder'] ?? payload['group_order'])['clients'],
    );
    yield asList(payload['groupClients'] ?? payload['group_clients']);
    yield asList(
      asMap(
        requestDetails['groupOrder'] ?? requestDetails['group_order'],
      )['clients'],
    );
    yield asList(
      requestDetails['groupClients'] ?? requestDetails['group_clients'],
    );
    yield asList(asMap(order['groupOrder'] ?? order['group_order'])['clients']);
    yield asList(order['groupClients'] ?? order['group_clients']);
    yield asList(
      asMap(detailsMap['groupOrder'] ?? detailsMap['group_order'])['clients'],
    );
    yield asList(detailsMap['groupClients'] ?? detailsMap['group_clients']);
  }

  int? parseInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString().trim());
  }

  for (final source in <Map<String, dynamic>>[details, root]) {
    for (final list in groupClientSources(source)) {
      for (var i = 0; i < list.length; i++) {
        final client = asMap(list[i]);
        if (client.isEmpty) continue;
        final slotIndex =
            parseInt(
              client['slotIndex'] ??
                  client['slot_index'] ??
                  client['index'] ??
                  client['position'],
            ) ??
            (i + 1);
        final clientHasNfc =
            requestHasNfc(client) ||
            requestHasNfc(
              asMap(client['savedNails'] ?? client['saved_nails']),
            ) ||
            requestHasNfc(
              asMap(client['draftNails'] ?? client['draft_nails']),
            ) ||
            requestHasNfc(
              asMap(client['nailPreferences'] ?? client['nail_preferences']),
            ) ||
            requestHasNfc(source) ||
            rootHasNfc ||
            detailsHasNfc;
        final parsed = firstSelectionFrom(<Map<String, dynamic>>[
          client,
          asMap(client['savedNails'] ?? client['saved_nails']),
          asMap(client['draftNails'] ?? client['draft_nails']),
          asMap(client['nailPreferences'] ?? client['nail_preferences']),
          asMap(client['requestDetails'] ?? client['request_details']),
          asMap(client['payload']),
          asMap(client['order'] ?? client['orderData'] ?? client['order_data']),
        ], allowEligibleFallback: clientHasNfc);
        if (parsed.anySelected) {
          groupBySlot[slotIndex] = parsed;
        }
      }
    }
  }

  return RequestNfcDetails(main: main, groupBySlotIndex: groupBySlot);
}

String _snakeName(String name) {
  final withUnderscores = name
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match.group(1)}_${match.group(2)}',
      )
      .replaceAll(RegExp(r'[\s\-]+'), '_')
      .toLowerCase();
  return withUnderscores;
}

String _tableForCollection(String name) {
  switch (name) {
    case 'Client_Custom_Requests':
      return 'client_custom_requests';
    case 'Company_Custom_Requests':
      return 'company_custom_requests';
    default:
      return _snakeName(name);
  }
}

String _detailsTableFor(String parentTable) {
  if (parentTable == 'company_custom_requests') {
    return 'company_custom_requests_details';
  }
  if (parentTable == 'client_custom_requests') {
    return 'client_custom_requests_details';
  }
  return '${parentTable}_details';
}
