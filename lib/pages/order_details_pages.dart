// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../services/notifications_service.dart';
import '../widgets/jnt_modal_app_bar.dart';
import 'request_chat_page.dart';
import 'track_order_page.dart';

dynamic _decodeJsonLike(dynamic value) {
  if (value is! String) return value;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return value;
  final startsJson =
      (trimmed.startsWith('{') && trimmed.endsWith('}')) ||
      (trimmed.startsWith('[') && trimmed.endsWith(']'));
  if (!startsJson) return value;
  try {
    return jsonDecode(trimmed);
  } catch (_) {
    return value;
  }
}

Map<String, dynamic> _mapFromDynamic(dynamic value) {
  final decoded = _decodeJsonLike(value);
  if (decoded is Map<String, dynamic>)
    return Map<String, dynamic>.from(decoded);
  if (decoded is Map) {
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }
  return <String, dynamic>{};
}

List<dynamic> _listFromDynamic(dynamic value) {
  final decoded = _decodeJsonLike(value);
  if (decoded is List) return List<dynamic>.from(decoded);
  return const <dynamic>[];
}

// -----------------------------------------------------------------------------
// Supabase compatibility helpers for this migrated order details page.
// These small classes keep the existing UI/business flow intact while preserving
// the existing document-style flow on top of Supabase tables.
// -----------------------------------------------------------------------------

class AppAuth {
  AppAuth._();
  static final AppAuth instance = AppAuth._();

  AppUser? get currentUser {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    return AppUser._(user);
  }
}

class AppUser {
  AppUser._(this._user);
  final User _user;

  String get uid => _user.id;
  String? get email => _user.email;
  String? get displayName {
    final meta = _user.userMetadata ?? const <String, dynamic>{};
    final raw =
        meta['displayName'] ??
        meta['display_name'] ??
        meta['fullName'] ??
        meta['full_name'] ??
        meta['name'];
    final value = (raw ?? '').toString().trim();
    if (value.isNotEmpty) return value;
    final mail = (_user.email ?? '').trim();
    if (mail.contains('@')) return mail.split('@').first;
    return mail.isEmpty ? null : mail;
  }
}

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  final SupabaseClient _client = Supabase.instance.client;

  CollectionReference<Map<String, dynamic>> collection(String name) {
    return CollectionReference<Map<String, dynamic>>._(
      this,
      _tableFor(name),
      name,
    );
  }

  Future<T> runTransaction<T>(Future<T> Function(Transaction tx) action) async {
    return action(const Transaction._());
  }
}

class Transaction {
  const Transaction._();

  Future<void> set(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data, [
    SetOptions? options,
  ]) async {
    await ref.set(data, options);
  }
}

class SetOptions {
  const SetOptions({this.merge = false});
  final bool merge;
}

class UpdateValue {
  const UpdateValue._(this.kind, [this.values = const <dynamic>[]]);

  final String kind;
  final List<dynamic> values;

  static UpdateValue now() => const UpdateValue._('now');
  static UpdateValue arrayUnion(List<dynamic> values) =>
      UpdateValue._('arrayUnion', values);
}

class CollectionReference<T extends Map<String, dynamic>> {
  CollectionReference._(
    this._db,
    this.table,
    this.firestoreName, {
    this.parent,
    this.subcollection,
  });

  final AppDatabase _db;
  final String table;
  final String firestoreName;
  final DocumentReference<Map<String, dynamic>>? parent;
  final String? subcollection;

  String get id => firestoreName;

  DocumentReference<T> doc([String? id]) {
    return DocumentReference<T>._(
      _db,
      table,
      firestoreName,
      id ?? _newId(),
      parent: parent,
      subcollection: subcollection,
      parentCollection: this,
    );
  }

  Query<T> where(String field, {Object? isEqualTo}) {
    return Query<T>._(
      _db,
      table,
      firestoreName,
      parent: parent,
      subcollection: subcollection,
    ).where(field, isEqualTo: isEqualTo);
  }

  Query<T> limit(int count) {
    return Query<T>._(
      _db,
      table,
      firestoreName,
      parent: parent,
      subcollection: subcollection,
    ).limit(count);
  }

  Query<T> orderBy(String field, {bool descending = false}) {
    return Query<T>._(
      _db,
      table,
      firestoreName,
      parent: parent,
      subcollection: subcollection,
    ).orderBy(field, descending: descending);
  }

  Future<DocumentReference<T>> add(Map<String, dynamic> data) async {
    final ref = doc();
    await ref.set(data, const SetOptions(merge: true));
    return ref;
  }
}

class Query<T extends Map<String, dynamic>> {
  Query._(
    this._db,
    this.table,
    this.firestoreName, {
    this.parent,
    this.subcollection,
  });

  final AppDatabase _db;
  final String table;
  final String firestoreName;
  final DocumentReference<Map<String, dynamic>>? parent;
  final String? subcollection;
  final List<_WhereClause> _wheres = <_WhereClause>[];
  int? _limit;
  String? _orderField;
  bool _descending = false;

  Query<T> where(String field, {Object? isEqualTo}) {
    _wheres.add(_WhereClause(field, isEqualTo));
    return this;
  }

  Query<T> limit(int count) {
    _limit = count;
    return this;
  }

  Query<T> orderBy(String field, {bool descending = false}) {
    _orderField = field;
    _descending = descending;
    return this;
  }

  Future<QuerySnapshot<T>> get() async {
    if (subcollection == 'details' && parent != null) {
      final rows = await _fetchDetailsRows(_db._client, parent!, null);
      final docs = rows
          .map(
            (row) => DocumentSnapshot<T>._(
              DocumentReference<T>._(
                _db,
                table,
                firestoreName,
                (row['detail_key'] ?? row['id'] ?? 'payload').toString(),
                parent: parent,
                subcollection: subcollection,
              ),
              _normalizeSupabaseRow(row).cast<String, dynamic>() as T,
              true,
            ),
          )
          .toList(growable: false);
      return QuerySnapshot<T>(docs);
    }

    dynamic query = _db._client.from(table).select();
    for (final where in _wheres) {
      final column = _columnFor(where.field);
      query = query.eq(column, _toSupabaseValue(where.value));
    }
    if (_orderField != null) {
      query = query.order(_columnFor(_orderField!), ascending: !_descending);
    }
    if (_limit != null) query = query.limit(_limit!);

    final rows = await query;
    final docs = <DocumentSnapshot<T>>[];
    for (final raw in (rows as List)) {
      final map = _normalizeSupabaseRow(Map<String, dynamic>.from(raw as Map));
      docs.add(
        DocumentSnapshot<T>._(
          DocumentReference<T>._(
            _db,
            table,
            firestoreName,
            (map['id'] ?? '').toString(),
          ),
          map.cast<String, dynamic>() as T,
          true,
        ),
      );
    }
    return QuerySnapshot<T>(docs);
  }
}

class _WhereClause {
  const _WhereClause(this.field, this.value);
  final String field;
  final Object? value;
}

class QuerySnapshot<T extends Map<String, dynamic>> {
  const QuerySnapshot(this.docs);
  final List<DocumentSnapshot<T>> docs;
}

class DocumentSnapshot<T extends Map<String, dynamic>> {
  DocumentSnapshot._(this.reference, this._data, this.exists);

  final DocumentReference<T> reference;
  final T? _data;
  final bool exists;

  String get id => reference.id;
  T? data() => _data;
}

class DocumentReference<T extends Map<String, dynamic>> {
  DocumentReference._(
    this._db,
    this.table,
    this.firestoreCollection,
    this.id, {
    DocumentReference<Map<String, dynamic>>? parent,
    this.subcollection,
    CollectionReference<T>? parentCollection,
  }) : parentDoc = parent,
       _parentCollection = parentCollection;

  final AppDatabase _db;
  final String table;
  final String firestoreCollection;
  final String id;
  final DocumentReference<Map<String, dynamic>>? parentDoc;
  final String? subcollection;
  final CollectionReference<T>? _parentCollection;

  CollectionReference<T> get parentCollection =>
      _parentCollection ??
      CollectionReference<T>._(_db, table, firestoreCollection);

  CollectionReference<T> get parentRef => parentCollection;
  CollectionReference<T> get parentCollectionRef => parentCollection;
  CollectionReference<T> get parentReference => parentCollection;
  CollectionReference<T> get parent_ => parentCollection;
  CollectionReference<T> get parentCollection_ => parentCollection;
  CollectionReference<T> get parentIdCompat => parentCollection;
  CollectionReference<T> get parentCollectionCompat => parentCollection;

  CollectionReference<Map<String, dynamic>> get parentCollectionUntyped =>
      CollectionReference<Map<String, dynamic>>._(
        _db,
        table,
        firestoreCollection,
      );

  CollectionReference<Map<String, dynamic>> get parentCollectionCompatAlias =>
      parentCollectionUntyped;

  CollectionReference<Map<String, dynamic>> get parent =>
      CollectionReference<Map<String, dynamic>>._(
        _db,
        table,
        firestoreCollection,
      );

  CollectionReference<Map<String, dynamic>> collection(String name) {
    return CollectionReference<Map<String, dynamic>>._(
      _db,
      _detailsTableFor(firestoreCollection),
      name,
      parent: this as DocumentReference<Map<String, dynamic>>,
      subcollection: name,
    );
  }

  Future<DocumentSnapshot<T>> get() async {
    if (subcollection == 'details' && parentDoc != null) {
      final row = await _fetchDetailsRow(_db._client, parentDoc!, id);
      if (row == null) {
        return DocumentSnapshot<T>._(this, null, false);
      }
      return DocumentSnapshot<T>._(
        this,
        _normalizeSupabaseRow(row).cast<String, dynamic>() as T,
        true,
      );
    }

    final row = await _fetchById(_db._client, table, id);
    if (row == null) return DocumentSnapshot<T>._(this, null, false);
    return DocumentSnapshot<T>._(
      this,
      _normalizeSupabaseRow(row).cast<String, dynamic>() as T,
      true,
    );
  }

  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    final merge = options?.merge ?? false;
    final normalized = _toSupabaseWrite(data);

    if (subcollection == 'details' && parentDoc != null) {
      await _upsertDetailsRow(
        _db._client,
        parentDoc!,
        id,
        _applyUpdateValues(<String, dynamic>{}, normalized),
        merge: merge,
      );
      return;
    }

    Map<String, dynamic> finalData = normalized;
    if (merge) {
      final current =
          await _fetchById(_db._client, table, id) ?? <String, dynamic>{};
      finalData = _applyUpdateValues(
        _normalizeSupabaseRow(current),
        normalized,
      );
    } else {
      finalData = _applyUpdateValues(<String, dynamic>{}, normalized);
    }
    finalData['id'] = id;

    await _db._client.from(table).upsert(_toDbColumns(finalData));
  }

  Future<void> update(Map<String, dynamic> data) async {
    final current =
        await _fetchById(_db._client, table, id) ?? <String, dynamic>{};
    final finalData = _applyUpdateValues(
      _normalizeSupabaseRow(current),
      _toSupabaseWrite(data),
    );
    await _db._client
        .from(table)
        .update(_toDbColumns(finalData)..remove('id'))
        .eq('id', id);
  }
}

class StorageUrlResolver {
  static Future<String?> resolve(String? value) async {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return null;
    if (raw.startsWith('http://') ||
        raw.startsWith('https://') ||
        raw.startsWith('data:image/')) {
      return raw;
    }
    final normalized = raw.replaceFirst(RegExp(r'^/+'), '');
    final parts = normalized.split('/');
    if (parts.length >= 2) {
      final bucket = parts.first;
      final path = parts.sublist(1).join('/');
      return Supabase.instance.client.storage.from(bucket).getPublicUrl(path);
    }
    for (final bucket in const <String>[
      'request-inspiration-photos',
      'client-request-photos',
      'artist-completed-photos',
      'design-preview-photos',
      'avatars',
      'profile-images',
    ]) {
      try {
        final url = Supabase.instance.client.storage
            .from(bucket)
            .getPublicUrl(normalized);
        if (url.isNotEmpty) return url;
      } catch (_) {}
    }
    return raw;
  }
}

String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

String _tableFor(String collection) {
  switch (collection) {
    case 'Client_Custom_Requests':
      return 'client_custom_requests';
    case 'Company_Custom_Requests':
      return 'company_custom_requests';
    default:
      return collection;
  }
}

String _detailsTableFor(String collection) {
  switch (collection) {
    case 'Client_Custom_Requests':
    case 'client_custom_requests':
      return 'client_custom_requests_details';
    case 'Company_Custom_Requests':
    case 'company_custom_requests':
      return 'company_custom_requests_details';
    default:
      return '${_tableFor(collection)}_details';
  }
}

String _firestoreCollectionForTable(String table) {
  switch (table) {
    case 'client_custom_requests':
      return 'Client_Custom_Requests';
    case 'company_custom_requests':
      return 'Company_Custom_Requests';
    default:
      return table;
  }
}

String _columnFor(String field) {
  const map = <String, String>{
    'orderNumber': 'order_number',
    'requestNumber': 'request_number',
    'clientRequestNumber': 'client_request_number',
    'companyRequestNumber': 'company_request_number',
    'requestType': 'request_type',
    'orderType': 'order_type',
    'clientStatus': 'client_status',
    'artistStatus': 'artist_status',
    'brandStatus': 'brand_status',
    'clientId': 'client_id',
    'clientUid': 'client_uid',
    'clientEmail': 'client_email',
    'clientName': 'client_name',
    'companyEmail': 'company_email',
    'companyName': 'company_name',
    'brandName': 'company_name',
    'selectedArtist': 'selected_artist',
    'selectedArtistEmail': 'selected_artist_email',
    'acceptedByArtistEmail': 'accepted_by_artist_email',
    'acceptedByArtistName': 'accepted_by_artist_name',
    'acceptedByClientEmail': 'accepted_by_client_email',
    'acceptedByClientName': 'accepted_by_client_name',
    'artistEmail': 'artist_email',
    'artistName': 'artist_name',
    'needBy': 'need_by',
    'needByDisplay': 'need_by_display',
    'descriptionPreview': 'description_preview',
    'budgetMin': 'budget_min',
    'budgetMax': 'budget_max',
    'paymentStatus': 'payment_status',
    'paymentLink': 'payment_link',
    'paidAt': 'paid_at',
    'updatedAt': 'updated_at',
    'createdAt': 'created_at',
    'cancelledAt': 'cancelled_at',
    'cancelReason': 'cancel_reason',
    'declinedByClientEmails': 'declined_by_client_emails',
    'declinedByArtistEmails': 'declined_by_artist_emails',
    'designApprovalStatus': 'design_approval_status',
    'designApprovedAt': 'design_approved_at',
    'designSubmittedAt': 'design_submitted_at',
    'clientReviewPromptSentAt': 'client_review_prompt_sent_at',
    'clientRating': 'client_rating',
    'clientReviewText': 'client_review_text',
    'clientReviewSubmittedAt': 'client_review_submitted_at',
    'tipAmount': 'tip_amount',
    'shippedByCourier': 'shipped_by_courier',
    'trackingNumber': 'tracking_number',
    'shippedAt': 'shipped_at',
    'deliveredAt': 'delivered_at',
    'openToClientPool': 'open_to_client_pool',
  };
  return map[field] ?? _camelToSnake(field);
}

String _camelToSnake(String value) => value.replaceAllMapped(
  RegExp(r'[A-Z]'),
  (m) => '_${m.group(0)!.toLowerCase()}',
);

String _snakeToCamel(String value) {
  final parts = value.split('_');
  if (parts.isEmpty) return value;
  return parts.first +
      parts
          .skip(1)
          .map((p) => p.isEmpty ? '' : p[0].toUpperCase() + p.substring(1))
          .join();
}

Object? _toSupabaseValue(Object? value) {
  if (value is DateTime) return value.toIso8601String();
  return value;
}

Map<String, dynamic> _normalizeSupabaseRow(Map<String, dynamic> row) {
  final out = <String, dynamic>{...row};
  for (final entry in row.entries) {
    if (entry.key.contains('_')) out[_snakeToCamel(entry.key)] = entry.value;
  }
  if (!out.containsKey('sourceCollection')) {
    out['sourceCollection'] = _firestoreCollectionForTable(
      (row['source_collection'] ?? '').toString(),
    );
  }
  if (row['data'] is Map) {
    final data = Map<String, dynamic>.from(row['data'] as Map);
    out.addAll(data);
    out['data'] = data;
  }
  return out;
}

Map<String, dynamic> _toSupabaseWrite(Map<String, dynamic> data) {
  final out = <String, dynamic>{};
  data.forEach((key, value) {
    out[_columnFor(key)] = value;
    out[key] = value;
  });
  return out;
}

Map<String, dynamic> _toDbColumns(Map<String, dynamic> data) {
  final out = <String, dynamic>{};
  data.forEach((key, value) {
    if (key.contains(RegExp(r'[A-Z]'))) {
      out[_columnFor(key)] = _encodeValue(value);
    } else {
      out[key] = _encodeValue(value);
    }
  });
  if (!out.containsKey('updated_at'))
    out['updated_at'] = DateTime.now().toIso8601String();
  return out;
}

Object? _encodeValue(Object? value) {
  if (value is UpdateValue) {
    if (value.kind == 'now') return DateTime.now().toIso8601String();
    if (value.kind == 'arrayUnion') {
      return value.values.map(_encodeValue).toList(growable: false);
    }
  }
  if (value is DateTime) return value.toIso8601String();
  if (value is Map) {
    final out = <String, dynamic>{};
    value.forEach((key, nestedValue) {
      out[key.toString()] = _encodeValue(nestedValue);
    });
    return out;
  }
  if (value is List) {
    return value.map(_encodeValue).toList(growable: false);
  }
  return value;
}

Map<String, dynamic> _applyUpdateValues(
  Map<String, dynamic> current,
  Map<String, dynamic> update,
) {
  final out = <String, dynamic>{...current};
  update.forEach((key, value) {
    final column = key.contains(RegExp(r'[A-Z]')) ? _columnFor(key) : key;
    if (value is UpdateValue) {
      if (value.kind == 'now') {
        out[column] = DateTime.now().toIso8601String();
        out[_snakeToCamel(column)] = out[column];
      } else if (value.kind == 'arrayUnion') {
        final existing = out[column] is List
            ? List<dynamic>.from(out[column] as List)
            : <dynamic>[];
        for (final item in value.values) {
          final encodedItem = _encodeValue(item);
          if (!existing.contains(encodedItem)) existing.add(encodedItem);
        }
        out[column] = existing;
        out[_snakeToCamel(column)] = existing;
      }
    } else {
      final encoded = _encodeValue(value);
      out[column] = encoded;
      out[_snakeToCamel(column)] = encoded;
    }
  });
  return out;
}

Future<Map<String, dynamic>?> _fetchById(
  SupabaseClient client,
  String table,
  String id,
) async {
  try {
    final row = await client.from(table).select().eq('id', id).maybeSingle();
    if (row != null) return Map<String, dynamic>.from(row as Map);
  } catch (_) {}

  if (table == 'client_custom_requests' || table == 'company_custom_requests') {
    for (final column in const [
      'order_number',
      'request_number',
      'client_request_number',
      'brand_request_number',
    ]) {
      try {
        final row = await client
            .from(table)
            .select()
            .eq(column, id)
            .limit(1)
            .maybeSingle();
        if (row != null) return Map<String, dynamic>.from(row as Map);
      } catch (_) {}
    }
  }
  return null;
}

Future<Map<String, dynamic>?> _fetchDetailsRow(
  SupabaseClient client,
  DocumentReference<dynamic> parent,
  String detailKey,
) async {
  final table = _detailsTableFor(parent.firestoreCollection);
  try {
    final row = await client
        .from(table)
        .select()
        .eq('request_id', parent.id)
        .eq('detail_key', detailKey)
        .maybeSingle();
    if (row != null) return Map<String, dynamic>.from(row as Map);
  } catch (_) {}

  final parentRow = await _fetchById(client, parent.table, parent.id);
  if (parentRow == null) return null;
  final json =
      parentRow[detailKey] ?? parentRow['details'] ?? parentRow['payload'];
  if (json is Map) {
    return <String, dynamic>{
      'id': '${parent.id}_$detailKey',
      'request_id': parent.id,
      'detail_key': detailKey,
      'data': Map<String, dynamic>.from(json),
      ...Map<String, dynamic>.from(json),
    };
  }
  return null;
}

Future<List<Map<String, dynamic>>> _fetchDetailsRows(
  SupabaseClient client,
  DocumentReference<dynamic> parent,
  String? detailKey,
) async {
  final table = _detailsTableFor(parent.firestoreCollection);
  try {
    dynamic query = client.from(table).select().eq('request_id', parent.id);
    if (detailKey != null) query = query.eq('detail_key', detailKey);
    final rows = await query;
    return (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  } catch (_) {
    final row = await _fetchDetailsRow(client, parent, detailKey ?? 'payload');
    return row == null ? <Map<String, dynamic>>[] : <Map<String, dynamic>>[row];
  }
}

Future<void> _upsertDetailsRow(
  SupabaseClient client,
  DocumentReference<dynamic> parent,
  String detailKey,
  Map<String, dynamic> data, {
  required bool merge,
}) async {
  final table = _detailsTableFor(parent.firestoreCollection);
  Map<String, dynamic> existing = <String, dynamic>{};
  if (merge) {
    final row = await _fetchDetailsRow(client, parent, detailKey);
    if (row != null) {
      final stored = row['data'];
      if (stored is Map) existing = Map<String, dynamic>.from(stored);
      existing.addAll(row);
    }
  }
  final finalData = _applyUpdateValues(existing, data);
  final payload = {
    'request_id': parent.id,
    'detail_key': detailKey,
    'data': finalData,
    'updated_at': DateTime.now().toIso8601String(),
  };

  final existingRow = await _fetchDetailsRow(client, parent, detailKey);
  if (existingRow != null && (existingRow['id'] ?? '').toString().isNotEmpty) {
    await client
        .from(table)
        .update(payload)
        .eq('id', existingRow['id'].toString());
  } else {
    await client.from(table).insert(payload);
  }

  // Also keep fallback JSON columns on the main request row in sync.
  final parentTable = parent.table;
  final update = <String, dynamic>{
    'updated_at': DateTime.now().toIso8601String(),
  };
  if (detailKey == 'payload') {
    update['payload'] = finalData;
    update['details'] = finalData;
  } else {
    update[detailKey] = finalData;
  }
  try {
    await client.from(parentTable).update(update).eq('id', parent.id);
  } catch (_) {}
}

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
  final String jntRevealDateDisplay;
  final String nailShape;
  final String nailLength;
  final int? budgetMin;
  final int? budgetMax;
  final int? clientBudgetMin;
  final int? clientBudgetMax;
  final int? artistBudgetMin;
  final int? artistBudgetMax;
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
    required this.jntRevealDateDisplay,
    required this.nailShape,
    required this.nailLength,
    required this.budgetMin,
    required this.budgetMax,
    required this.clientBudgetMin,
    required this.clientBudgetMax,
    required this.artistBudgetMin,
    required this.artistBudgetMax,
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

    int? i(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.round();
      return int.tryParse((v ?? '').toString().trim());
    }

    DateTime? dt(dynamic v) {
      if (v == null) return null;

      if (v is DateTime) {
        return v;
      }

      if (v is String) {
        final text = v.trim();
        final parsed = DateTime.tryParse(text);
        if (parsed != null) return parsed;
        final mmddyyyy = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(text);
        if (mmddyyyy != null) {
          final month = int.tryParse(mmddyyyy.group(1) ?? '');
          final day = int.tryParse(mmddyyyy.group(2) ?? '');
          final year = int.tryParse(mmddyyyy.group(3) ?? '');
          if (month != null && day != null && year != null) {
            return DateTime(year, month, day);
          }
        }
        return null;
      }

      if (v is int) {
        return DateTime.fromMillisecondsSinceEpoch(v);
      }

      if (v is double) {
        return DateTime.fromMillisecondsSinceEpoch(v.toInt());
      }

      if (v is Map) {
        // Handles serialized timestamps like {"seconds":..., "nanoseconds":...}
        final seconds = v['seconds'];
        if (seconds is int) {
          return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
        }
      }

      return null;
    }

    String dateDisplay(dynamic value) {
      final parsed = dt(value);
      if (parsed != null) {
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
        return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year}';
      }
      return (value ?? '').toString().trim();
    }

    String dateDisplayFrom(List<Object?> values) {
      for (final value in values) {
        final display = dateDisplay(value).trim();
        if (display.isNotEmpty) return display;
      }
      return '';
    }

    Map<String, dynamic> asMap(dynamic value) {
      return _mapFromDynamic(value);
    }

    final rootMap = o is Map ? asMap(o) : <String, dynamic>{};
    final detailMap = asMap(rootMap['details']);
    final payloadMap = asMap(detailMap['payload']).isNotEmpty
        ? asMap(detailMap['payload'])
        : asMap(rootMap['payload']).isNotEmpty
        ? asMap(rootMap['payload'])
        : detailMap;
    final requestDetailsMap = asMap(payloadMap['requestDetails']).isNotEmpty
        ? asMap(payloadMap['requestDetails'])
        : asMap(detailMap['requestDetails']).isNotEmpty
        ? asMap(detailMap['requestDetails'])
        : asMap(rootMap['requestDetails']);
    final orderMap = asMap(payloadMap['order']).isNotEmpty
        ? asMap(payloadMap['order'])
        : asMap(detailMap['order']).isNotEmpty
        ? asMap(detailMap['order'])
        : asMap(rootMap['order']);
    final designMap = asMap(payloadMap['designApproval']).isNotEmpty
        ? asMap(payloadMap['designApproval'])
        : asMap(detailMap['designApproval']);
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
      final list = _listFromDynamic(v);
      if (list.isNotEmpty) return List<String>.from(list.whereType<String>());
      return const <String>[];
    }

    List<String> normalizedEmailList(dynamic v) => listOrEmpty(v)
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(growable: false);

    String dimText(Object? value) {
      if (value is num) {
        return value == value.roundToDouble()
            ? value.toInt().toString()
            : value.toString();
      }
      return (value ?? '').toString().trim();
    }

    Map<String, String> handFromDimensions(
      Map<String, dynamic> dimensions,
      bool isLeft,
    ) {
      final prefix = isLeft ? 'l' : 'r';
      return <String, String>{
        'thumb': dimText(dimensions['${prefix}Thumb']),
        'index': dimText(dimensions['${prefix}Index']),
        'middle': dimText(dimensions['${prefix}Middle']),
        'ring': dimText(dimensions['${prefix}Ring']),
        'pinky': dimText(dimensions['${prefix}Pinky']),
      };
    }

    Map<String, String> pickHandDimensions(bool isLeft) {
      final direct = _dimsMap(
        isLeft ? o?.leftHandDimensions : o?.rightHandDimensions,
      );
      if (direct.values.any((value) => value.trim().isNotEmpty)) return direct;

      final candidates = <Map<String, dynamic>>[
        Map<String, dynamic>.from(payloadMap),
        Map<String, dynamic>.from(requestDetailsMap),
        Map<String, dynamic>.from(orderMap),
        Map<String, dynamic>.from(detailMap),
        if (o is Map) Map<String, dynamic>.from(o),
      ];

      for (final candidate in candidates) {
        final nailPreferences = asMap(candidate['nailPreferences']).isNotEmpty
            ? asMap(candidate['nailPreferences'])
            : asMap(
                asMap(candidate['clientProfileSnapshot'])['nailPreferences'],
              );
        final dimensions = asMap(nailPreferences['dimensions']).isNotEmpty
            ? asMap(nailPreferences['dimensions'])
            : asMap(candidate['dimensions']);
        if (dimensions.isNotEmpty) {
          final hand = handFromDimensions(dimensions, isLeft);
          if (hand.values.any((value) => value.trim().isNotEmpty)) return hand;
        }

        final rootDimensions = candidate['dimensions'];
        if (rootDimensions is Map) {
          final hand = handFromDimensions(
            Map<String, dynamic>.from(rootDimensions),
            isLeft,
          );
          if (hand.values.any((value) => value.trim().isNotEmpty)) return hand;
        }
      }

      return direct;
    }

    List<_OrderGroupClient> pickGroupClients() {
      final rootGroupOrder = asMap(rootMap['groupOrder']);
      final detailGroupOrder = asMap(detailMap['groupOrder']);
      final payloadGroupOrder = asMap(payloadMap['groupOrder']);
      final requestGroupOrder = asMap(requestDetailsMap['groupOrder']);
      final candidates = <dynamic>[
        o?.groupClients,
        rootMap['groupClients'],
        rootMap['group_clients'],
        rootGroupOrder['clients'],
        detailMap['groupClients'],
        detailMap['group_clients'],
        detailGroupOrder['clients'],
        payloadMap['groupClients'],
        payloadMap['group_clients'],
        payloadGroupOrder['clients'],
        requestDetailsMap['groupClients'],
        requestDetailsMap['group_clients'],
        requestGroupOrder['clients'],
      ];
      for (final candidate in candidates) {
        final clients = _groupClientList(candidate);
        if (clients.isNotEmpty) return clients;
      }
      return const <_OrderGroupClient>[];
    }

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
      groupClients: pickGroupClients(),
      createdAt: o?.createdAt is DateTime ? o.createdAt as DateTime : null,
      clientDescription: s(o?.clientDescription, ''),
      cancelReason: s(o?.cancelReason, ''),
      inspirationPhotos: collectPhotoRefs([
        o?.inspirationPhotos,
        payloadMap['brandInspirationPhotos'],
        payloadMap['inspirationPhotos'],
        payloadMap['clientImages'],
        payloadMap['photos'],
        payloadMap['inspirationPhoto'],
        payloadMap['inspirationPhotoUrl'],
        payloadMap['previewImage'],
        payloadMap['previewImageAsset'],
        requestDetailsMap['brandInspirationPhotos'],
        requestDetailsMap['inspirationPhotos'],
        requestDetailsMap['clientImages'],
        requestDetailsMap['photos'],
        requestDetailsMap['inspirationPhoto'],
        requestDetailsMap['inspirationPhotoUrl'],
        requestDetailsMap['inspirationPhotoUrls'],
        requestDetailsMap['inspirationPhotoRefs'],
        requestDetailsMap['previewImage'],
        requestDetailsMap['previewImageAsset'],
        orderMap['brandInspirationPhotos'],
        orderMap['inspirationPhotos'],
        orderMap['clientImages'],
        orderMap['photos'],
        orderMap['inspirationPhoto'],
        orderMap['inspirationPhotoUrl'],
        orderMap['previewImage'],
        orderMap['previewImageAsset'],
      ]),
      needByDisplay: s(
        o?.needByDisplay ??
            rootMap['need_by_display'] ??
            rootMap['needByDisplay'] ??
            requestDetailsMap['needByDisplay'] ??
            detailMap['needByDisplay'] ??
            payloadMap['needByDisplay'],
        dateDisplay(
          requestDetailsMap['needBy'] ??
              detailMap['needBy'] ??
              payloadMap['needBy'] ??
              rootMap['need_by'] ??
              rootMap['needBy'],
        ),
      ),
      jntRevealDateDisplay: dateDisplayFrom([
        o?.jntRevealDateDisplay,
        rootMap['jnt_reveal_date'],
        rootMap['jntRevealDate'],
        rootMap['jnt_reveal_date_display'],
        rootMap['jntRevealDateDisplay'],
        payloadMap['jntRevealDate'],
        payloadMap['jnt_reveal_date'],
        payloadMap['revealDate'],
        payloadMap['jntRevealDateDisplay'],
        requestDetailsMap['jntRevealDate'],
        requestDetailsMap['jnt_reveal_date'],
        requestDetailsMap['revealDate'],
        requestDetailsMap['jntRevealDateDisplay'],
        orderMap['jntRevealDate'],
        orderMap['jnt_reveal_date'],
        orderMap['revealDate'],
        orderMap['jntRevealDateDisplay'],
      ]),

      nailShape: s(
        o?.nailShape ??
            rootMap['nail_shape'] ??
            detailMap['nailShape'] ??
            detailMap['nail_shape'] ??
            payloadMap['nailShape'] ??
            payloadMap['nail_shape'] ??
            requestDetailsMap['nailShape'] ??
            requestDetailsMap['nail_shape'] ??
            asMap(detailMap['nailPreferences'])['shape'] ??
            asMap(payloadMap['nailPreferences'])['shape'] ??
            asMap(requestDetailsMap['nailPreferences'])['shape'],
        '',
      ),

      nailLength: s(
        o?.nailLength ??
            rootMap['nail_length'] ??
            rootMap['nail_size'] ??
            detailMap['nailLength'] ??
            detailMap['nail_length'] ??
            detailMap['nailSize'] ??
            detailMap['nail_size'] ??
            payloadMap['nailLength'] ??
            payloadMap['nail_length'] ??
            payloadMap['nailSize'] ??
            payloadMap['nail_size'] ??
            requestDetailsMap['nailLength'] ??
            requestDetailsMap['nail_length'] ??
            requestDetailsMap['nailSize'] ??
            requestDetailsMap['nail_size'] ??
            asMap(detailMap['nailPreferences'])['length'] ??
            asMap(payloadMap['nailPreferences'])['length'] ??
            asMap(requestDetailsMap['nailPreferences'])['length'],
        '',
      ),

      budgetMin: o?.budgetMin is int
          ? o.budgetMin as int
          : int.tryParse((rootMap['budget_min'] ?? '').toString()),

      budgetMax: o?.budgetMax is int
          ? o.budgetMax as int
          : int.tryParse((rootMap['budget_max'] ?? '').toString()),

      clientBudgetMin: i(
        o?.clientBudgetMin ??
            rootMap['clientBudgetMin'] ??
            rootMap['client_budget_min'] ??
            detailMap['clientBudgetMin'] ??
            payloadMap['clientBudgetMin'] ??
            requestDetailsMap['clientBudgetMin'] ??
            asMap(detailMap['clientBudget'])['min'] ??
            asMap(payloadMap['clientBudget'])['min'] ??
            asMap(requestDetailsMap['clientBudget'])['min'],
      ),

      clientBudgetMax: i(
        o?.clientBudgetMax ??
            rootMap['clientBudgetMax'] ??
            rootMap['client_budget_max'] ??
            detailMap['clientBudgetMax'] ??
            payloadMap['clientBudgetMax'] ??
            requestDetailsMap['clientBudgetMax'] ??
            asMap(detailMap['clientBudget'])['max'] ??
            asMap(payloadMap['clientBudget'])['max'] ??
            asMap(requestDetailsMap['clientBudget'])['max'],
      ),

      artistBudgetMin: i(
        o?.artistBudgetMin ??
            rootMap['artistBudgetMin'] ??
            rootMap['artist_budget_min'] ??
            detailMap['artistBudgetMin'] ??
            payloadMap['artistBudgetMin'] ??
            requestDetailsMap['artistBudgetMin'] ??
            asMap(detailMap['artistBudget'])['min'] ??
            asMap(payloadMap['artistBudget'])['min'] ??
            asMap(requestDetailsMap['artistBudget'])['min'],
      ),

      artistBudgetMax: i(
        o?.artistBudgetMax ??
            rootMap['artistBudgetMax'] ??
            rootMap['artist_budget_max'] ??
            detailMap['artistBudgetMax'] ??
            payloadMap['artistBudgetMax'] ??
            requestDetailsMap['artistBudgetMax'] ??
            asMap(detailMap['artistBudget'])['max'] ??
            asMap(payloadMap['artistBudget'])['max'] ??
            asMap(requestDetailsMap['artistBudget'])['max'],
      ),

      leftHandDimensions: pickHandDimensions(true),
      rightHandDimensions: pickHandDimensions(false),
      imageAsset: s(o?.imageAsset, 'assets/images/order_thumb_1.png'),
      artistAcceptedAmount: o?.artistAcceptedAmount is int
          ? o.artistAcceptedAmount as int
          : null,
      paymentStatus: s(o?.paymentStatus, ''),
      paymentLink: s(o?.paymentLink, ''),
      selectedArtistName: s(
        o?.selectedArtistName ??
            o?.selectedArtist ??
            payloadMap['selectedArtistName'] ??
            payloadMap['selectedArtist'],
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
      designSubmittedAt: dt(o?.designSubmittedAt ?? designMap['submittedAt']),
      designApprovalDueAt: dt(o?.designApprovalDueAt ?? designMap['dueAt']),
      designReminderSentAt: dt(
        o?.designReminderSentAt ?? designMap['reminderSentAt'],
      ),
      designPreviewPhotos: listOrEmpty(
        o?.designPreviewPhotos ?? designMap['previewPhotos'],
      ),
      clientEmail: s(o?.clientEmail, ''),
      acceptedByArtistEmail: s(o?.acceptedByArtistEmail, ''),
      declinedByClientEmails: normalizedEmailList(
        o?.declinedByClientEmails ??
            rootMap['declinedByClientEmails'] ??
            (payloadMap['declinedByClientEmails']),
      ),
      declinedByArtistEmails: normalizedEmailList(
        o?.declinedByArtistEmails ??
            rootMap['declinedByArtistEmails'] ??
            (payloadMap['declinedByArtistEmails']),
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
    final map = _mapFromDynamic(value);
    if (map.isEmpty) return const <String, String>{};
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
    final list = _listFromDynamic(value);
    if (list.isEmpty) return const <_OrderGroupClient>[];
    final items = <_OrderGroupClient>[];
    String s(dynamic v) => (v ?? '').toString().trim();
    Map<String, dynamic> asMap(dynamic value) {
      return _mapFromDynamic(value);
    }

    int slotIndexOf(dynamic entry) {
      if (entry is _OrderGroupClient) return entry.slotIndex;
      if (entry is Map) {
        final map = asMap(entry);
        return _RequestNfcDetails._intValue(
              map['slotIndex'] ?? map['slot_index'] ?? map['index'],
            ) ??
            0;
      }
      try {
        return _RequestNfcDetails._intValue((entry as dynamic).slotIndex) ?? 0;
      } catch (_) {
        return 0;
      }
    }

    String dimText(dynamic value) {
      if (value is num) {
        return value == value.roundToDouble()
            ? value.toInt().toString()
            : value.toString();
      }
      return (value ?? '').toString().trim();
    }

    Map<String, String> handFromNailMap(
      Map<String, dynamic> source,
      bool isLeft,
    ) {
      final nailPreferences = asMap(source['savedNails']).isNotEmpty
          ? asMap(source['savedNails'])
          : (asMap(source['draftNails']).isNotEmpty
                ? asMap(source['draftNails'])
                : asMap(source['nailPreferences']));
      final dimensions = asMap(nailPreferences['dimensions']).isNotEmpty
          ? asMap(nailPreferences['dimensions'])
          : asMap(source['dimensions']);
      if (dimensions.isEmpty) return const <String, String>{};
      final prefix = isLeft ? 'l' : 'r';
      return <String, String>{
        'thumb': dimText(dimensions['${prefix}Thumb']),
        'index': dimText(dimensions['${prefix}Index']),
        'middle': dimText(dimensions['${prefix}Middle']),
        'ring': dimText(dimensions['${prefix}Ring']),
        'pinky': dimText(dimensions['${prefix}Pinky']),
      };
    }

    for (final entry in list) {
      if (entry is _OrderGroupClient) {
        items.add(entry);
        continue;
      }
      if (entry is Map) {
        final map = asMap(entry);
        final savedNails = asMap(map['savedNails']);
        final draftNails = asMap(map['draftNails']);
        final nailPreferences = savedNails.isNotEmpty ? savedNails : draftNails;
        items.add(
          _OrderGroupClient(
            clientId: s(map['clientId']),
            clientName: s(map['clientName']),
            clientEmail: s(map['clientEmail']),
            slotIndex:
                _RequestNfcDetails._intValue(
                  map['slotIndex'] ?? map['slot_index'] ?? map['index'],
                ) ??
                0,
            nailShape: s(map['nailShape']).isNotEmpty
                ? s(map['nailShape'])
                : s(nailPreferences['shape']),
            nailLength: s(map['nailLength']).isNotEmpty
                ? s(map['nailLength'])
                : s(nailPreferences['length']),
            leftHandDimensions: _dimsMap(map['leftHandDimensions']).isNotEmpty
                ? _dimsMap(map['leftHandDimensions'])
                : handFromNailMap(map, true),
            rightHandDimensions: _dimsMap(map['rightHandDimensions']).isNotEmpty
                ? _dimsMap(map['rightHandDimensions'])
                : handFromNailMap(map, false),
          ),
        );
        continue;
      }
      items.add(
        _OrderGroupClient(
          clientId: s(entry?.clientId),
          clientName: s(entry?.clientName),
          clientEmail: s(entry?.clientEmail),
          slotIndex: slotIndexOf(entry),
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
    this.slotIndex = 0,
    this.nailShape = '',
    this.nailLength = '',
    this.leftHandDimensions = const <String, String>{},
    this.rightHandDimensions = const <String, String>{},
  });

  final String clientId;
  final String clientName;
  final String clientEmail;
  final int slotIndex;
  final String nailShape;
  final String nailLength;
  final Map<String, String> leftHandDimensions;
  final Map<String, String> rightHandDimensions;
}

enum OrderBudgetViewMode {
  singleRange,
  clientOnly,
  artistOnly,
  clientAndArtist,
}

/// ------------------------
/// SHIPPED ORDER DETAILS (UI like your screenshot)
/// ------------------------
class ShippedOrderDetailsPage extends StatelessWidget {
  const ShippedOrderDetailsPage({
    super.key,
    required this.order,
    this.isBrandViewer = false,
    this.budgetViewMode = OrderBudgetViewMode.singleRange,
  });
  final dynamic order;
  final bool isBrandViewer;
  final OrderBudgetViewMode budgetViewMode;

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
      budgetViewMode: budgetViewMode,
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
    this.budgetViewMode = OrderBudgetViewMode.singleRange,
  });
  final dynamic order;
  final bool isBrandViewer;
  final OrderBudgetViewMode budgetViewMode;

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
      budgetViewMode: budgetViewMode,
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
    this.budgetViewMode = OrderBudgetViewMode.singleRange,
  });
  final dynamic order;
  final bool isBrandViewer;
  final OrderBudgetViewMode budgetViewMode;

  @override
  Widget build(BuildContext context) {
    final o = _OrderSafe.from(order);

    return _BaseOrderDetails(
      title: 'Order Details',
      statusPillText: 'Pending',
      statusPillColor: AppColors.balletSlippers,
      statusPillIcon: Icons.hourglass_bottom_rounded,
      statusPillIconColor: Colors.black.withValues(alpha: 0.65),
      order: o,
      isBrandViewer: isBrandViewer,
      budgetViewMode: budgetViewMode,
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
    this.budgetViewMode = OrderBudgetViewMode.singleRange,
  });
  final dynamic order;
  final bool isBrandViewer;
  final OrderBudgetViewMode budgetViewMode;

  @override
  Widget build(BuildContext context) {
    final o = _OrderSafe.from(order);

    return _BaseOrderDetails(
      title: 'Order Details',
      statusPillText: 'New',
      statusPillColor: AppColors.balletSlippers,
      statusPillIcon: Icons.fiber_new_rounded,
      statusPillIconColor: Colors.black.withValues(alpha: 0.65),
      order: o,
      isBrandViewer: isBrandViewer,
      budgetViewMode: budgetViewMode,
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
    this.budgetViewMode = OrderBudgetViewMode.singleRange,
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
  final OrderBudgetViewMode budgetViewMode;
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

  bool get _isBrandRequest {
    final source = order.sourceCollection.trim().toLowerCase();
    return source == 'company_custom_requests';
  }

  String _rangeText(int? min, int? max) {
    if (min == null && max == null) return '-';
    if (min != null && max != null) return '\$$min - \$$max';
    if (min != null) return '\$$min';
    return '\$${max!}';
  }

  List<({String label, String value})> _budgetRows() {
    if (!_isBrandRequest) {
      return <({String label, String value})>[
        (label: 'Range:', value: _budgetText()),
      ];
    }

    final clientText = _rangeText(order.clientBudgetMin, order.clientBudgetMax);
    final artistText = _rangeText(order.artistBudgetMin, order.artistBudgetMax);

    switch (budgetViewMode) {
      case OrderBudgetViewMode.clientOnly:
        return <({String label, String value})>[
          (label: 'Client Budget Range:', value: clientText),
        ];
      case OrderBudgetViewMode.artistOnly:
        return <({String label, String value})>[
          (label: 'Artist Budget Range:', value: artistText),
        ];
      case OrderBudgetViewMode.clientAndArtist:
        return <({String label, String value})>[
          (label: 'Client Range:', value: clientText),
          (label: 'Budget Range:', value: artistText),
        ];
      case OrderBudgetViewMode.singleRange:
        return <({String label, String value})>[
          (label: 'Range:', value: _budgetText()),
        ];
    }
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

    final supabase = Supabase.instance.client;

    for (final table in const <String>['artist', 'client_artist']) {
      final rows = await supabase
          .from(table)
          .select()
          .ilike('email', email)
          .limit(1);

      if (rows.isEmpty) continue;

      final data = Map<String, dynamic>.from(rows.first);

      final profile =
          (data['profile'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};

      final basic =
          (data['basic'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};

      final address =
          (data['address'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};

      final stats =
          (data['stats'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};

      final name = _firstNonEmpty([
        order.artistName,
        profile['displayName'],
        profile['name'],
        basic['displayName'],
        basic['name'],
        data['panel_display_name'],
        data['panel_displayName'],
        data['display_name'],
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
        data['panel_profile_image_url'],
        data['panel_profileImageUrl'],
        data['profile_image_url'],
        data['profileImageUrl'],
        data['avatar_url'],
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

      final rating =
          _asDouble(stats['rating']) ??
          _asDouble(stats['averageRating']) ??
          _asDouble(data['rating']) ??
          _asDouble(data['average_rating']) ??
          _asDouble(data['averageRating']) ??
          _asDouble(data['panel_rating']);

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
    final currentName = (AppAuth.instance.currentUser?.displayName ?? '')
        .trim();
    final fallbackCurrentName = (AppAuth.instance.currentUser?.email ?? '')
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
    final currentName = (AppAuth.instance.currentUser?.displayName ?? '')
        .trim();
    final fallbackCurrentName = (AppAuth.instance.currentUser?.email ?? '')
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
                    color: AppColors.blackCat.withValues(alpha: 0.85),
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
      appBar: JntModalAppBar(
        onClose: () => Navigator.pop(context),
        closeTooltip: 'Close order details',
        autofocusClose: MediaQuery.of(context).accessibleNavigation,
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
          ],

          if (isCancelledStatus) ...[
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _orderDetailsWithRightNailDimensions(),
                  const SizedBox(height: 8),
                  Divider(color: Colors.black.withValues(alpha: 0.08)),
                  const SizedBox(height: 5),
                  _paymentSection(context),
                ],
              ),
            ),
          ] else ...[
            if (statusPillText != 'Delivered') ...[
              _Card(child: _orderDetailsWithRightNailDimensions()),
              const SizedBox(height: 14),
            ],
            if (statusPillText != 'In Progress' &&
                statusPillText != 'Shipped' &&
                statusPillText != 'Delivered')
              _Card(child: _paymentSection(context)),
            if (statusPillText == 'Delivered' || statusPillText == 'Shipped')
              const SizedBox(height: 14),
            if (statusPillText == 'In Progress') ...[
              if (order.artistCompletedPhotos.isNotEmpty) ...[
                _Card(child: _artistCompletedArtSection()),
                const SizedBox(height: 12),
              ],

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

            if (statusPillText == 'Shipped') ...[
              _ClientStatusTabs(
                tabs: const ['Details', 'Photos', 'Shipping'],
                initialSelectedIndex: 2,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Card(
                        child: _orderDetailsWithRightNailDimensions(
                          showPaymentAmount: false,
                          showUploadedInspiration: false,
                          showSingleMeasurementOuterBorder: false,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_shouldShowPaymentAmountSection()) ...[
                        _Card(child: _finalAcceptedAmountSection()),
                        const SizedBox(height: 12),
                      ],
                      _Card(child: _paymentSection(context)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Card(child: _uploadedInspirationSection()),
                      if (order.artistCompletedPhotos.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _Card(child: _artistCompletedArtSection()),
                      ],
                    ],
                  ),
                  _Card(child: _shippingInformationSection(context)),
                ],
              ),
              const SizedBox(height: 12),
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
            if (statusPillText == 'Delivered') ...[
              _ClientStatusTabs(
                tabs: const ['Details', 'Photos', 'Delivered'],
                initialSelectedIndex: 2,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Card(
                        child: _orderDetailsWithRightNailDimensions(
                          showPaymentAmount: false,
                          showUploadedInspiration: false,
                          showSingleMeasurementOuterBorder: false,
                          showGroupMeasurementOuterBorder: false,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_shouldShowPaymentAmountSection()) ...[
                        _Card(child: _finalAcceptedAmountSection()),
                        const SizedBox(height: 12),
                      ],
                      _Card(child: _paymentSection(context)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Card(child: _uploadedInspirationSection()),
                      if (order.artistCompletedPhotos.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _Card(child: _artistCompletedArtSection()),
                      ],
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Card(child: _shippingInformationSection(context)),
                      const SizedBox(height: 12),
                      _Card(child: rightPanel),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
                      final docRef = AppDatabase.instance
                          .collection('Client_Custom_Requests')
                          .doc(order.id);
                      final snap = await docRef.get();
                      var activeRef = docRef;
                      var rootData = snap.data() ?? const <String, dynamic>{};
                      if (!snap.exists) {
                        final companyRef = AppDatabase.instance
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
                          (AppAuth.instance.currentUser?.email ?? '')
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
                          'declinedByClientEmails': UpdateValue.arrayUnion(
                            <String>[currentClientEmail],
                          ),
                        'updatedAt': UpdateValue.now(),
                        'cancelledAt': UpdateValue.now(),
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
                          'declinedByClientEmails': UpdateValue.arrayUnion(
                            <String>[currentClientEmail],
                          ),
                        'cancellation': {
                          'reason': normalizedReason,
                          'cancelledAt': UpdateValue.now(),
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
        _SubmittedPhotosStrip(paths: order.artistCompletedPhotos),
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
    final hasArtistFinalAmount =
        order.artistAcceptedAmount != null && order.artistAcceptedAmount! > 0;
    final budgetRows = _budgetRows();
    final primaryRangeText = budgetRows.isEmpty
        ? _budgetText()
        : budgetRows.first.value;
    final amountText = amount == null ? primaryRangeText : '\$$amount';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          header,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < budgetRows.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Row(
            children: [
              Text(
                budgetRows[i].label,
                style: TextStyle(
                  color: AppColors.blackCat,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const Spacer(),
              Text(
                budgetRows[i].value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.blackCat,
                ),
              ),
            ],
          ),
        ],
        if ((isPending || isPaid) && hasArtistFinalAmount) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                isPaid ? 'Paid Amount:' : 'Amount Due:',
                style: TextStyle(
                  color: AppColors.blackCat,
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
          ),
        ],
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
    final budgetRows = _budgetRows();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Amount',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppColors.blackCat,
            fontFamily: 'ArialBold',
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < budgetRows.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Row(
            children: [
              Text(
                budgetRows[i].label,
                style: TextStyle(
                  color: AppColors.blackCat,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                budgetRows[i].value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.blackCat,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              'Final Amount by Artist:',
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

  bool _shouldShowPaymentAmountSection() {
    return statusPillText == 'In Progress' ||
        statusPillText == 'Shipped' ||
        statusPillText == 'Delivered';
  }

  Widget _shippingInformationSection(BuildContext context) {
    final courier = order.shippedByCourier.trim().isEmpty
        ? '-'
        : order.shippedByCourier.trim();
    final tracking = order.trackingNumber.trim().isEmpty
        ? '-'
        : order.trackingNumber.trim();
    final shippedOn = _dateText(order.shippedAt) ?? '-';
    final deliveredOn = _dateText(order.deliveredAt) ?? '-';

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
        if (statusPillText == 'Delivered')
          _bullet('Delivered Date', deliveredOn),
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
      AppAuth.instance.currentUser?.displayName,
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
            (data['profile'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};

        final ascension =
            (data['ascension'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};

        final sponsorshipRequest =
            (data['sponsorshipRequest'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};

        final tierCandidates = <Object?>[
          ascension['tier'],
          ascension['levelName'],
          data['sponsorship_tier'],
          data['sponsorshipTier'],
          sponsorshipRequest['tier'],
          profile['ascensionTier'],
          data['panel_ascension_level'],
          data['panel_ascensionLevel'],
        ];

        for (final raw in tierCandidates) {
          final tier = (raw ?? '').toString().trim().toLowerCase();
          if (tier == 'goldsmith' || tier == 'crowned') {
            return true;
          }
        }

        final eligibleCandidates = <Object?>[
          ascension['sponsorshipEligible'],
          data['panel_brand_eligible'],
          data['panel_brandEligible'],
          profile['sponsorshipEligible'],
        ];

        for (final raw in eligibleCandidates) {
          if (raw == true) return true;
          if (raw is num && raw != 0) return true;
          if ((raw ?? '').toString().toLowerCase() == 'true') return true;
        }

        return false;
      }

      final supabase = Supabase.instance.client;

      for (final table in const ['artist', 'client_artist']) {
        try {
          final rows = await supabase.from(table).select();

          for (final row in rows) {
            final data = Map<String, dynamic>.from(row);

            if (isBrandRequest && !isBrandEligibleArtist(data)) {
              continue;
            }

            final email = readEmail(data['email']);
            if (email.isNotEmpty) {
              targets.add(email);
            }
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
      final docRef = AppDatabase.instance
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
        'paidAt': UpdateValue.now(),
        'updatedAt': UpdateValue.now(),
        'paymentNotifiedArtist': acceptedByArtistEmail.isNotEmpty,
        if (acceptedByArtistEmail.isNotEmpty)
          'paymentNotifiedArtistAt': UpdateValue.now(),
        'payment': {
          'status': 'paid',
          'paidAt': UpdateValue.now(),
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
          'paidAt': UpdateValue.now(),
          'paymentLink': order.paymentLink,
        },
        'updatedAt': UpdateValue.now(),
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
      return _mapFromDynamic(value);
    }

    try {
      var doc = await AppDatabase.instance.collection(collection).doc(id).get();
      if (!doc.exists && collection != 'Client_Custom_Requests') {
        doc = await AppDatabase.instance
            .collection('Client_Custom_Requests')
            .doc(id)
            .get();
      }
      if (!doc.exists && collection != 'Company_Custom_Requests') {
        doc = await AppDatabase.instance
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
      final rootDetails = asMap(root['details']);
      final payload = asMap(details['payload']).isNotEmpty
          ? asMap(details['payload'])
          : asMap(rootDetails['payload']).isNotEmpty
          ? asMap(rootDetails['payload'])
          : details;
      return _RequestNfcDetails.fromMaps(
        root: <String, dynamic>{...root, ...rootDetails},
        details: payload,
      );
    } catch (_) {
      return _RequestNfcDetails.empty();
    }
  }

  Widget _orderDetailsWithRightNailDimensions({
    bool showPaymentAmount = true,
    bool showUploadedInspiration = true,
    bool showSingleMeasurementOuterBorder = true,
    bool showGroupMeasurementOuterBorder = true,
  }) {
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
          if (_isBrandRequest) ...[
            _bullet('Brand Name', _valueOrDash(order.brandName ?? '')),
            _bullet('Campaign Name', _valueOrDash(order.campaignName ?? '')),
            if (order.clientDescription.trim().isNotEmpty) ...[
              _bullet('Description', order.clientDescription.trim()),
            ],
          ],
          _bullet('Need by', _valueOrDash(order.needByDisplay)),
          if (_isBrandRequest && order.jntRevealDateDisplay.trim().isNotEmpty) ...[
            _bullet('JNT Reveal Date', order.jntRevealDateDisplay.trim()),
          ],
          if (!_isBrandRequest && order.clientDescription.trim().isNotEmpty) ...[
            _bullet('Description', order.clientDescription.trim()),
          ],
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
            ? _groupClientMeasurementsSection(
                showOuterBorder: showGroupMeasurementOuterBorder,
              )
            : _nailDimensionsRightAlignedWithBorder(
                showOuterBorder: showSingleMeasurementOuterBorder,
              ),
        if (showPaymentAmount && _shouldShowPaymentAmountSection()) ...[
          const SizedBox(height: 12),
          _finalAcceptedAmountSection(),
        ],
        if (showUploadedInspiration) ...[
          const SizedBox(height: 12),
          _uploadedInspirationSection(),
        ],
      ],
    );
  }

  Widget _uploadedInspirationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Uploaded Inspiration',
          style: TextStyle(
            color: AppColors.blackCat,
            fontWeight: FontWeight.w700,
            fontSize: 15,
            fontFamily: 'ArialBold',
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
      ],
    );
  }

  Widget _groupClientMeasurementsSection({bool showOuterBorder = true}) {
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
              currentViewerEmail: AppAuth.instance.currentUser?.email ?? '',
              showOuterBorder: showOuterBorder,
            ),
          ],
        );
      },
    );
  }

  List<_ClientMeasurementTabData> _groupClientTabsData(_RequestNfcDetails nfc) {
    final tabs = <_ClientMeasurementTabData>[];
    final seen = <String>{};

    void addTab({
      required String name,
      required String email,
      required String nailShape,
      required String nailLength,
      required Map<String, String> leftHand,
      required Map<String, String> rightHand,
      required _FingerNfcSelection nfcValue,
    }) {
      final cleanName = name.trim().isEmpty ? 'Client' : name.trim();
      final cleanEmail = email.trim().toLowerCase();
      final key = cleanEmail.isNotEmpty ? cleanEmail : cleanName.toLowerCase();

      if (seen.contains(key)) return;
      seen.add(key);

      tabs.add(
        _ClientMeasurementTabData(
          name: cleanName,
          clientEmail: cleanEmail,
          nailShape: nailShape,
          nailLength: nailLength,
          leftHand: leftHand,
          rightHand: rightHand,
          nfc: nfcValue,
        ),
      );
    }

    // First tab must always be the submitting client.
    addTab(
      name: order.title,
      email: order.clientEmail,
      nailShape: order.nailShape,
      nailLength: order.nailLength,
      leftHand: order.leftHandDimensions,
      rightHand: order.rightHandDimensions,
      nfcValue: nfc.main,
    );

    // Remaining tabs are the selected group clients.
    for (var i = 0; i < order.groupClients.length; i++) {
      final client = order.groupClients[i];
      final slotIndex = client.slotIndex > 0 ? client.slotIndex : (i + 1);
      addTab(
        name: client.clientName,
        email: client.clientEmail,
        nailShape: client.nailShape,
        nailLength: client.nailLength,
        leftHand: client.leftHandDimensions,
        rightHand: client.rightHandDimensions,
        nfcValue:
            nfc.groupBySlotIndex[slotIndex] ?? _FingerNfcSelection.empty(),
      );

      if (tabs.length >= 16) break;
    }

    final viewerEmail =
        AppAuth.instance.currentUser?.email?.trim().toLowerCase() ?? '';
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

  Widget _nailDimensionsRightAlignedWithBorder({
    required bool showOuterBorder,
  }) {
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
          showOuterBorder: showOuterBorder,
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
    bool showOuterBorder = true,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: showOuterBorder
          ? BoxDecoration(
              border: Border.all(color: AppColors.blackCatBorderLight),
              borderRadius: BorderRadius.zero,
            )
          : null,
      child: Column(
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
          const SizedBox(height: 10),
          _measurementSummaryRow(
            nailShape: _valueOrDash(nailShape),
            nailLength: _valueOrDash(_prettyLength(nailLength)),
          ),
        ],
      ),
    );
  }

  Widget _measurementSummaryRow({
    required String nailShape,
    required String nailLength,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _measurementSummaryItem('Shape', nailShape)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: SizedBox(
            height: 42,
            child: VerticalDivider(
              width: 1,
              thickness: 1,
              color: AppColors.blackCatBorderLight,
            ),
          ),
        ),
        Expanded(child: _measurementSummaryItem('Length', nailLength)),
      ],
    );
  }

  Widget _measurementSummaryItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.blackCatBorderLight),
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
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
                color: AppColors.blackCat,
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
              textAlign: TextAlign.right,
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
      ),
    );
  }

  Widget _dimensionHandCard(
    String title,
    Map<String, String> map,
    Map<String, bool> nfc,
  ) {
    String value(String key) {
      final raw = (map[key] ?? '').trim();
      return _formatMeasurementMm(raw);
    }

    bool showNfc(String key) {
      return nfc[key] == true;
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

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.blackCatBorderLight),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
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
      ),
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
                color: AppColors.blackCat.withValues(alpha: 0.75),
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
                TextSpan(text: cleanValue),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _valueOrDash(String v) => v.trim().isEmpty ? '-' : v.trim();

  String _formatMeasurementMm(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '-') return '-';
    final cleaned = trimmed.replaceAll(RegExp(r'[^0-9.]'), '');
    final parsed = double.tryParse(cleaned);
    if (parsed == null) return trimmed;
    return '${parsed.toStringAsFixed(2)} mm';
  }

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
      return _mapFromDynamic(value);
    }

    final rootNailPrefs = asMap(root['nailPreferences']);
    final detailNailPrefs = asMap(details['nailPreferences']);
    final snapshot = asMap(details['clientProfileSnapshot']);
    final snapshotNailPrefs = asMap(snapshot['nailPreferences']);
    final rootSummary = asMap(root['summary']);
    final detailSummary = asMap(details['summary']);

    bool truthy(dynamic value) {
      if (value == true) return true;
      if (value is num) return value != 0;
      final text = (value ?? '').toString().trim().toLowerCase();
      return text == 'true' ||
          text == 'yes' ||
          text == '1' ||
          text == 'selected' ||
          text == 'requested' ||
          text == 'enabled';
    }

    bool isNfcCheckboxKey(String key) {
      final normalized = key.trim().toLowerCase();
      return normalized == 'nfcrequested' ||
          normalized == 'nfcselected' ||
          normalized == 'hasnfc' ||
          normalized == 'lthumbnfc' ||
          normalized == 'lindexnfc' ||
          normalized == 'lmiddlenfc' ||
          normalized == 'lringnfc' ||
          normalized == 'lpinkynfc' ||
          normalized == 'rthumbnfc' ||
          normalized == 'rindexnfc' ||
          normalized == 'rmiddlenfc' ||
          normalized == 'rringnfc' ||
          normalized == 'rpinkynfc' ||
          normalized == 'thumbnfc' ||
          normalized == 'indexnfc' ||
          normalized == 'middlenfc' ||
          normalized == 'ringnfc' ||
          normalized == 'pinkynfc';
    }

    bool containsSelectedNfcCheckbox(Object? value) {
      if (value == null) return false;
      if (value is Map) {
        for (final entry in value.entries) {
          final key = entry.key.toString();
          final entryValue = entry.value;
          if (isNfcCheckboxKey(key) && truthy(entryValue)) return true;
          if (entryValue is Map || entryValue is List) {
            if (containsSelectedNfcCheckbox(entryValue)) return true;
          }
        }
        return false;
      }
      if (value is List) {
        for (final item in value) {
          if (containsSelectedNfcCheckbox(item)) return true;
        }
      }
      return false;
    }

    bool requestNfcSelected(Map<String, dynamic> source) {
      final nfc = asMap(source['nfc']);
      final summary = asMap(source['summary']);
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
          truthy(nfc['requested']) ||
          truthy(nfc['selected']) ||
          truthy(nfc['hasNfc']) ||
          truthy(nfc['has_nfc']) ||
          containsSelectedNfcCheckbox(source);
    }

    final mainNfcSelected =
        requestNfcSelected(root) ||
        requestNfcSelected(details) ||
        requestNfcSelected(rootSummary) ||
        requestNfcSelected(detailSummary);

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
    List<dynamic> firstNonEmptyList(List<dynamic> values) {
      for (final value in values) {
        final list = _listFromDynamic(value);
        if (list.isNotEmpty) return list;
      }
      return const <dynamic>[];
    }

    final rawClients = firstNonEmptyList([
      groupOrder['clients'],
      details['groupClients'],
      details['group_clients'],
      root['groupClients'],
      root['group_clients'],
    ]);

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
      final parsed = _FingerNfcSelection.fromDimensions(dimensions);
      if (parsed.anySelected) {
        groupBySlot[slotIndex] = parsed;
        continue;
      }
      groupBySlot[slotIndex] = requestNfcSelected(client)
          ? _FingerNfcSelection.fromEligibleDimensions(dimensions)
          : _FingerNfcSelection.emptyConst;
    }

    final parsedMain = _FingerNfcSelection.fromDimensions(mainDimensions);
    return _RequestNfcDetails(
      main: parsedMain.anySelected
          ? parsedMain
          : (mainNfcSelected
                ? _FingerNfcSelection.fromEligibleDimensions(mainDimensions)
                : _FingerNfcSelection.emptyConst),
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

  bool get anySelected =>
      left.values.any((value) => value) || right.values.any((value) => value);

  factory _FingerNfcSelection.empty() => emptyConst;

  factory _FingerNfcSelection.fromDimensions(Map<String, dynamic> dimensions) {
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

    dynamic nfcValue(String key) {
      final nfc = _mapFromDynamic(dimensions['nfc']);
      if (nfc.isNotEmpty) {
        return dimensions['${key}Nfc'] ?? nfc[key] ?? nfc['${key}Nfc'];
      }
      return dimensions['${key}Nfc'];
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

  factory _FingerNfcSelection.fromEligibleDimensions(Map<String, dynamic> map) {
    Map<String, dynamic> dimensions = map;
    final nested = _mapFromDynamic(map['dimensions']);
    if (nested.isNotEmpty) {
      dimensions = nested;
    }

    bool eligible(String key) {
      final raw = dimensions[key];
      final text = (raw ?? '').toString().trim();
      if (text.isEmpty || text.toLowerCase() == 'null') return false;
      final cleaned = text.replaceAll(RegExp(r'[^0-9.]'), '');
      final parsed = double.tryParse(cleaned);
      return parsed != null && parsed.isFinite && parsed >= 8;
    }

    return _FingerNfcSelection(
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
    this.showOuterBorder = true,
  });

  final List<_ClientMeasurementTabData> clients;
  final String currentViewerEmail;
  final bool showOuterBorder;

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
    return Container(
      decoration: widget.showOuterBorder
          ? BoxDecoration(
              color: AppColors.snow,
              borderRadius: BorderRadius.zero,
              border: Border.all(color: AppColors.blackCatBorderLight),
            )
          : null,
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
                            : AppColors.blackCat.withValues(alpha: 0.62),
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
              showMeasurements: true,
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

  String _formatMeasurementMm(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '-') return '-';
    final cleaned = trimmed.replaceAll(RegExp(r'[^0-9.]'), '');
    final parsed = double.tryParse(cleaned);
    if (parsed == null) return trimmed;
    return '${parsed.toStringAsFixed(2)} mm';
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
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _plainHandColumn(
                  'Left Hand',
                  client.leftHand,
                  client.nfc.left,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: AppColors.blackCatBorderLight,
                ),
              ),
              Expanded(
                child: _plainHandColumn(
                  'Right Hand',
                  client.rightHand,
                  client.nfc.right,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Divider(height: 1, thickness: 1, color: AppColors.blackCatBorderLight),
        const SizedBox(height: 10),
        _summaryRow(
          nailShape: _valueOrDash(client.nailShape),
          nailLength: _valueOrDash(_prettyLength(client.nailLength)),
        ),
      ],
    );
  }

  Widget _summaryRow({required String nailShape, required String nailLength}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _plainSummaryItem('Shape', nailShape)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: SizedBox(
            height: 24,
            child: VerticalDivider(
              width: 1,
              thickness: 1,
              color: AppColors.blackCatBorderLight,
            ),
          ),
        ),
        Expanded(child: _plainSummaryItem('Length', nailLength)),
      ],
    );
  }

  Widget _plainSummaryItem(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.blackCat.withValues(alpha: 0.78),
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
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

  Widget _plainHandColumn(
    String title,
    Map<String, String> map,
    Map<String, bool> nfc,
  ) {
    String value(String key) {
      final raw = (map[key] ?? '').trim();
      return _formatMeasurementMm(raw);
    }

    bool showNfc(String key) {
      return nfc[key] == true;
    }

    Widget row(String label, String key) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.blackCat,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Arial',
                ),
              ),
            ),
            SizedBox(
              width: 34,
              child: showNfc(key)
                  ? Center(child: _nfcChip())
                  : const SizedBox.shrink(),
            ),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  value(key),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'ArialBold',
                    color: AppColors.blackCat,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              fontFamily: 'ArialBold',
              color: AppColors.blackCat,
            ),
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
                      .toList(),
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

    var doc = await AppDatabase.instance
        .collection(collection)
        .doc(orderId)
        .get();
    if (!doc.exists) {
      final orderNo = fallbackOrderNumber.trim();
      if (orderNo.isNotEmpty) {
        final query = await AppDatabase.instance
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
                color: Colors.black.withValues(alpha: 0.62),
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
          color: Colors.black.withValues(alpha: 0.62),
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
        color: AppColors.blackCat.withValues(alpha: 0.35),
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
                          color: AppColors.blackCat.withValues(alpha: 0.04),
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
      final ref = AppDatabase.instance
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
        'clientReviewPromptSentAt': UpdateValue.now(),
        'clientReviewPromptChannel': channelLabel,
        'updatedAt': UpdateValue.now(),
      }, SetOptions(merge: true));
      await ref.collection('details').doc('payload').set({
        'clientReviewPrompt': {
          'sentAt': UpdateValue.now(),
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
    final auth = AppAuth.instance.currentUser;
    final email = (auth?.email ?? '').trim().toLowerCase();
    final uid = (auth?.uid ?? '').trim();
    final db = AppDatabase.instance;

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

      final supabase = Supabase.instance.client;

      final comment = _commentCtrl.text.trim();
      final tipAmount = _calculatedTip;
      final tipPercent = _selectedTipPercent;
      final customTipAmount = _selectedTipPercent == null
          ? _customTipAmount
          : 0;
      final nowIso = DateTime.now().toIso8601String();

      final table = _orderCollection == 'Company_Custom_Requests'
          ? 'company_custom_requests'
          : 'client_custom_requests';

      final detailsTable = _orderCollection == 'Company_Custom_Requests'
          ? 'company_custom_requests_details'
          : 'client_custom_requests_details';

      final artistEmail = widget.order.acceptedByArtistEmail
          .trim()
          .toLowerCase();

      double? previousRatingValue;

      final orderData = await supabase
          .from(table)
          .select()
          .eq('id', widget.order.id)
          .maybeSingle();

      if (orderData == null) {
        throw Exception('Order not found');
      }

      final existingClientReview =
          (orderData['client_review'] as Map?) ??
          (orderData['clientReview'] as Map?) ??
          (orderData['details'] is Map
              ? (orderData['details']['clientReview'] as Map?)
              : null) ??
          (orderData['payload'] is Map
              ? (orderData['payload']['clientReview'] as Map?)
              : null);

      previousRatingValue =
          _asDouble(orderData['client_rating']) ??
          _asDouble(orderData['clientRating']) ??
          _asDouble(existingClientReview?['rating']);

      final currentDetails =
          (orderData['details'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};

      final currentPayload =
          (orderData['payload'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};

      final clientReview = <String, dynamic>{
        'rating': _rating,
        'comment': comment,
        'submittedAt': nowIso,
      };

      final clientTip = <String, dynamic>{
        'amount': tipAmount,
        'percent': tipPercent,
        'customAmount': customTipAmount,
        'fundingSource': 'bank_account',
        'submittedAt': tipAmount > 0 ? nowIso : null,
      };

      await supabase
          .from(table)
          .update({
            'client_rating': _rating,
            'client_review_text': comment,
            'client_review_submitted_at': nowIso,
            'client_tip_amount': tipAmount,
            'client_tip_percent': tipPercent,
            'client_tip_custom_amount': customTipAmount,
            'client_tip_submitted_at': tipAmount > 0 ? nowIso : null,
            'updated_at': nowIso,
            'details': {
              ...currentDetails,
              'clientRating': _rating,
              'clientReviewText': comment,
              'clientReviewSubmittedAt': nowIso,
              'clientTipAmount': tipAmount,
              'clientTipPercent': tipPercent,
              'clientTipCustomAmount': customTipAmount,
              'clientTipSubmittedAt': tipAmount > 0 ? nowIso : null,
              'clientReview': clientReview,
              'clientTip': clientTip,
            },
            'payload': {
              ...currentPayload,
              'clientRating': _rating,
              'clientReviewText': comment,
              'clientReviewSubmittedAt': nowIso,
              'clientTipAmount': tipAmount,
              'clientTipPercent': tipPercent,
              'clientTipCustomAmount': customTipAmount,
              'clientTipSubmittedAt': tipAmount > 0 ? nowIso : null,
              'clientReview': clientReview,
              'clientTip': clientTip,
            },
          })
          .eq('id', widget.order.id);

      await bestEffort(() async {
        final existingDetail = await supabase
            .from(detailsTable)
            .select()
            .eq('request_id', widget.order.id)
            .eq('detail_key', 'payload')
            .maybeSingle();

        final existingData =
            (existingDetail?['data'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};

        final detailPayload = {
          ...existingData,
          'clientReview': clientReview,
          'clientTip': clientTip,
          'updatedAt': nowIso,
        };

        if (existingDetail == null) {
          await supabase.from(detailsTable).insert({
            'request_id': widget.order.id,
            'detail_key': 'payload',
            'data': detailPayload,
            'created_at': nowIso,
            'updated_at': nowIso,
          });
        } else {
          await supabase
              .from(detailsTable)
              .update({'data': detailPayload, 'updated_at': nowIso})
              .eq('id', existingDetail['id']);
        }
      });

      if (artistEmail.isNotEmpty) {
        await bestEffort(() async {
          Map<String, dynamic>? artistRow = await supabase
              .from('artist')
              .select()
              .ilike('email', artistEmail)
              .maybeSingle();

          var artistTable = 'artist';

          artistRow ??= await supabase
              .from('client_artist')
              .select()
              .ilike('email', artistEmail)
              .maybeSingle();

          if (artistRow != null && artistRow['id'] != null) {
            if (artistRow.containsKey('account_type')) {
              artistTable = 'client_artist';
            }

            final stats =
                (artistRow['stats'] as Map?)?.cast<String, dynamic>() ??
                <String, dynamic>{};

            final currentCount = _asNonNegativeInt(
              stats['reviewCount'] ??
                  stats['reviews'] ??
                  artistRow['review_count'] ??
                  artistRow['reviewCount'] ??
                  artistRow['reviews'] ??
                  artistRow['panel_reviews'],
            );

            final currentRating =
                _asDouble(
                  stats['rating'] ??
                      stats['averageRating'] ??
                      artistRow['rating'] ??
                      artistRow['average_rating'] ??
                      artistRow['averageRating'] ??
                      artistRow['panel_rating'],
                ) ??
                0.0;

            final hadPrevious = (previousRatingValue ?? 0) > 0;
            final safeCount = currentCount <= 0
                ? (hadPrevious ? 1 : 0)
                : currentCount;
            final nextCount = hadPrevious ? safeCount : (safeCount + 1);
            final nextRating = currentRating >= _rating
                ? currentRating
                : _rating;

            await supabase
                .from(artistTable)
                .update({
                  'stats': {
                    ...stats,
                    'rating': nextRating,
                    'averageRating': nextRating,
                    'reviewCount': nextCount,
                    'reviews': nextCount,
                  },
                  'rating': nextRating,
                  'average_rating': nextRating,
                  'review_count': nextCount,
                  'reviews': nextCount,
                  'panel_rating': nextRating,
                  'panel_reviews': nextCount,
                  'updated_at': nowIso,
                })
                .eq('id', artistRow['id']);
          }
        });
      }

      if (tipAmount > 0) {
        await bestEffort(() async {
          await supabase.from('tip_payout_queue').insert({
            'order_id': widget.order.id,
            'order_number': widget.order.orderNumber,
            'source_collection': _orderCollection,
            'artist_email': artistEmail,
            'artist_name': widget.order.artistName,
            'client_email': (supabase.auth.currentUser?.email ?? '')
                .trim()
                .toLowerCase(),
            'tip_amount': tipAmount,
            'tip_percent': tipPercent,
            'custom_tip_amount': customTipAmount,
            'funding_source': 'bank_account',
            'status': 'queued',
            'created_at': nowIso,
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
          extra: <String, dynamic>{
            'rating': _rating,
            'tipAmount': tipAmount,
          },
        );
      });

      final clientEmail = (supabase.auth.currentUser?.email ?? '')
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
      final snap = await AppDatabase.instance
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
      if (submittedAtRaw is DateTime) {
        submittedAt = submittedAtRaw;
      } else if (submittedAtRaw is String) {
        submittedAt = DateTime.tryParse(submittedAtRaw);
      }

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
                  size: 22,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 1),
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                visualDensity: VisualDensity.compact,
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
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 4,
                          runSpacing: 6,
                          children: [
                            const Text(
                              'Artist Review Rating',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(width: 2),
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
            color: Colors.black.withValues(alpha: 0.62),
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

class _ClientStatusTabs extends StatefulWidget {
  const _ClientStatusTabs({
    required this.tabs,
    required this.children,
    this.initialSelectedIndex = 0,
  });

  final List<String> tabs;
  final List<Widget> children;
  final int initialSelectedIndex;

  @override
  State<_ClientStatusTabs> createState() => _ClientStatusTabsState();
}

class _ClientStatusTabsState extends State<_ClientStatusTabs> {
  late int _selectedTab;

  @override
  void initState() {
    super.initState();
    final maxIndex = widget.children.isEmpty ? 0 : widget.children.length - 1;
    _selectedTab = widget.initialSelectedIndex.clamp(0, maxIndex);
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.children[_selectedTab];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.blackCatBorderLight),
        borderRadius: BorderRadius.zero,
        color: AppColors.snow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(
              widget.tabs.length,
              (index) => _tabButton(widget.tabs[index], index),
            ),
          ),
          Container(height: 1, color: AppColors.blackCatBorderLight),
          Padding(padding: const EdgeInsets.all(12), child: content),
        ],
      ),
    );
  }

  Widget _tabButton(String label, int index) {
    final selected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: AppColors.blackCat,
                ),
              ),
            ),
            Container(
              height: 3,
              width: double.infinity,
              color: selected ? AppColors.blackCat : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}

class DeliveredOrderDetailsPage extends StatelessWidget {
  const DeliveredOrderDetailsPage({
    super.key,
    required this.order,
    this.isBrandViewer = false,
    this.budgetViewMode = OrderBudgetViewMode.singleRange,
  });
  final dynamic order;
  final bool isBrandViewer;
  final OrderBudgetViewMode budgetViewMode;

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
      budgetViewMode: budgetViewMode,
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
    this.budgetViewMode = OrderBudgetViewMode.singleRange,
    this.onChat,
    this.onResubmit,
  });
  final dynamic order;
  final bool isBrandViewer;
  final OrderBudgetViewMode budgetViewMode;
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
      budgetViewMode: budgetViewMode,
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
    this.budgetViewMode = OrderBudgetViewMode.singleRange,
    this.onChat,
    this.onResubmit,
  });
  final dynamic order;
  final bool isBrandViewer;
  final OrderBudgetViewMode budgetViewMode;
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
      budgetViewMode: budgetViewMode,
      showRightPanel: false,
      rightPanel: const SizedBox.shrink(),
      onCancelledChat: onChat,
      onCancelledResubmit: onResubmit,
    );
  }
}
