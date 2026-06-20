import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Temporary Supabase compatibility layer used only for the migration.
/// It removes Firebase package dependencies while preserving existing page logic.
class FirebaseAuth {
  FirebaseAuth._();
  static final FirebaseAuth instance = FirebaseAuth._();

  _CompatUser? get currentUser {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    return _CompatUser(user);
  }

  Future<void> signOut() => Supabase.instance.client.auth.signOut();
}

class _CompatUser {
  const _CompatUser(this._user);
  final User _user;

  String get uid => _user.id;
  String? get email => _user.email;
  String? get displayName {
    final data = _user.userMetadata ?? const <String, dynamic>{};
    return (data['name'] ??
            data['displayName'] ??
            data['full_name'] ??
            data['fullName'])
        ?.toString();
  }
}

class Timestamp {
  Timestamp._(this._value);
  final DateTime _value;

  static Timestamp now() => Timestamp._(DateTime.now());
  static Timestamp fromDate(DateTime value) => Timestamp._(value);
  DateTime toDate() => _value;

  @override
  String toString() => _value.toIso8601String();
}

class FieldValue {
  static Object serverTimestamp() => const _ServerTimestamp();
  static Object arrayUnion(List<Object?> values) => _ArrayUnion(values);
  static Object arrayRemove(List<Object?> values) => _ArrayRemove(values);
}

class _ServerTimestamp {
  const _ServerTimestamp();
}

class _ArrayUnion {
  const _ArrayUnion(this.values);
  final List<Object?> values;
}

class _ArrayRemove {
  const _ArrayRemove(this.values);
  final List<Object?> values;
}

class SetOptions {
  const SetOptions({this.merge = false});
  final bool merge;
}

class FirebaseFirestore {
  FirebaseFirestore._();
  static final FirebaseFirestore instance = FirebaseFirestore._();

  CollectionReference<Map<String, dynamic>> collection(String path) =>
      CollectionReference<Map<String, dynamic>>._root(path);

  WriteBatch batch() => WriteBatch();

  Future<T> runTransaction<T>(Future<T> Function(Transaction tx) action) async {
    return action(Transaction());
  }
}

class Transaction {
  Future<DocumentSnapshot<Map<String, dynamic>>> get(
    DocumentReference<Map<String, dynamic>> ref,
  ) =>
      ref.get();

  void set(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data, [
    SetOptions? options,
  ]) {
    unawaited(ref.set(data, options));
  }

  void update(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data,
  ) {
    unawaited(ref.update(data));
  }
}

class WriteBatch {
  final List<Future<void> Function()> _ops = <Future<void> Function()>[];

  void set(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data, [
    SetOptions? options,
  ]) {
    _ops.add(() => ref.set(data, options));
  }

  void delete(DocumentReference<Map<String, dynamic>> ref) {
    _ops.add(ref.delete);
  }

  Future<void> commit() async {
    for (final op in _ops) {
      await op();
    }
  }
}

class CollectionReference<T extends Map<String, dynamic>> extends Query<T> {
  CollectionReference._root(String collection)
      : _collection = collection,
        _parent = null,
        super._(collection);

  CollectionReference._sub(String collection, this._parent)
      : _collection = collection,
        super._(collection);

  final String _collection;
  final DocumentReference<Map<String, dynamic>>? _parent;

  String get id => _collection;

  DocumentReference<T> doc([String? id]) {
    final generated = id ?? DateTime.now().microsecondsSinceEpoch.toString();
    return DocumentReference<T>._(_collection, generated, _parent);
  }

  Future<DocumentReference<T>> add(Map<String, dynamic> data) async {
    final ref = doc();
    await ref.set(data);
    return ref;
  }
}

class DocumentReference<T extends Map<String, dynamic>> {
  DocumentReference._(this._collection, this.id, this._parent);

  final String _collection;
  final String id;
  final DocumentReference<Map<String, dynamic>>? _parent;

  String get path => _parent == null
      ? '$_collection/$id'
      : '${_parent.path}/$_collection/$id';

  CollectionReference<Map<String, dynamic>> get parent =>
      CollectionReference<Map<String, dynamic>>._root(_collection);

  CollectionReference<Map<String, dynamic>> collection(String path) =>
      CollectionReference<Map<String, dynamic>>._sub(path, this);

  Future<DocumentSnapshot<T>> get() async {
    final data = await _CompatDb.getDoc(_collection, id, parentRef: _parent);
    return DocumentSnapshot<T>._(
      id: id,
      reference: this,
      exists: data != null,
      data: data == null ? null : Map<String, dynamic>.from(data) as T,
    );
  }

  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    await _CompatDb.setDoc(
      _collection,
      id,
      data,
      parentRef: _parent,
      merge: options?.merge ?? false,
    );
  }

  Future<void> update(Map<String, dynamic> data) async {
    await set(data, const SetOptions(merge: true));
  }

  Future<void> delete() async {
    await _CompatDb.deleteDoc(_collection, id, parentRef: _parent);
  }

  Stream<DocumentSnapshot<T>> snapshots() {
    final controller = StreamController<DocumentSnapshot<T>>();

    Future<void> emit() async {
      try {
        final snap = await get();
        if (!controller.isClosed) controller.add(snap);
      } catch (e, st) {
        if (!controller.isClosed) controller.addError(e, st);
      }
    }

    unawaited(emit());

    final table = _CompatDb.tableFor(_collection);
    RealtimeChannel? channel;
    if (table.isNotEmpty) {
      channel = Supabase.instance.client
          .channel('compat_doc_${table}_$id')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: table,
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: id,
            ),
            callback: (_) => unawaited(emit()),
          )
          .subscribe();
    }

    controller.onCancel = () async {
      if (channel != null) {
        await Supabase.instance.client.removeChannel(channel);
      }
    };

    return controller.stream;
  }
}

class DocumentSnapshot<T extends Map<String, dynamic>> {
  const DocumentSnapshot._({
    required this.id,
    required this.reference,
    required this.exists,
    required T? data,
  }) : _data = data;

  final String id;
  final DocumentReference<T> reference;
  final bool exists;
  final T? _data;

  T? data() => _data;
}

class QueryDocumentSnapshot<T extends Map<String, dynamic>>
    extends DocumentSnapshot<T> {
  const QueryDocumentSnapshot._({
    required super.id,
    required super.reference,
    required T data,
  }) : super._(exists: true, data: data);

  @override
  T data() => super.data() as T;
}

enum DocumentChangeType { added, modified, removed }

class DocumentChange<T extends Map<String, dynamic>> {
  const DocumentChange({
    required this.type,
    required this.doc,
  });

  final DocumentChangeType type;
  final QueryDocumentSnapshot<T> doc;
}

class QuerySnapshot<T extends Map<String, dynamic>> {
  const QuerySnapshot(this.docs, [List<DocumentChange<T>>? docChanges])
      : docChanges = docChanges ?? const [];

  final List<QueryDocumentSnapshot<T>> docs;
  final List<DocumentChange<T>> docChanges;
}

class Query<T extends Map<String, dynamic>> {
  Query._(this._collection);

  final String _collection;
  final List<_WhereFilter> _filters = <_WhereFilter>[];
  int? _limit;
  String? _orderBy;
  bool _descending = false;

  Query<T> where(String field, {Object? isEqualTo}) {
    _filters.add(_WhereFilter(field, isEqualTo));
    return this;
  }

  Query<T> limit(int value) {
    _limit = value;
    return this;
  }

  Query<T> orderBy(String field, {bool descending = false}) {
    _orderBy = field;
    _descending = descending;
    return this;
  }

  Future<QuerySnapshot<T>> get() async {
    final rows = await _CompatDb.queryCollection(
      _collection,
      filters: _filters,
      limit: _limit,
      orderBy: _orderBy,
      descending: _descending,
    );
    final docs = rows
        .map(
          (row) => QueryDocumentSnapshot<T>._(
            id: row.id,
            reference: DocumentReference<T>._(_collection, row.id, null),
            data: Map<String, dynamic>.from(row.data) as T,
          ),
        )
        .toList(growable: false);
    return QuerySnapshot<T>(
      docs,
      docs
          .map(
            (doc) => DocumentChange<T>(
              type: DocumentChangeType.added,
              doc: doc,
            ),
          )
          .toList(growable: false),
    );
  }

  Stream<QuerySnapshot<T>> snapshots() {
    final controller = StreamController<QuerySnapshot<T>>();

    Future<void> emit() async {
      try {
        if (!controller.isClosed) {
          controller.add(await get());
        }
      } catch (e, st) {
        if (!controller.isClosed) controller.addError(e, st);
      }
    }

    unawaited(emit());

    final table = _CompatDb.tableFor(_collection);
    RealtimeChannel? channel;
    if (table.isNotEmpty) {
      channel = Supabase.instance.client
          .channel('compat_${table}_${DateTime.now().microsecondsSinceEpoch}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: table,
            callback: (_) => unawaited(emit()),
          )
          .subscribe();
    }

    controller.onCancel = () async {
      if (channel != null) {
        await Supabase.instance.client.removeChannel(channel);
      }
    };

    return controller.stream;
  }
}

class _WhereFilter {
  const _WhereFilter(this.field, this.value);
  final String field;
  final Object? value;
}

class _CompatRow {
  const _CompatRow(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;
}

class _CompatDb {
  static SupabaseClient get _sb => Supabase.instance.client;

  static String tableFor(String collection) {
    switch (collection) {
      case 'Client_Custom_Requests':
      case 'client_custom_requests':
      case 'Company_Custom_Requests':
        return 'client_custom_requests';
      case 'client':
        return 'client';
      case 'artist':
        return 'artist';
      case 'client_artist':
        return 'client_artist';
      case 'company':
        return 'company';
      case 'user_notifications':
        return 'user_notifications';
      case 'Request_Chats':
      case 'request_chats':
        return 'request_chats';
      case 'tip_payout_queue':
        return 'tip_payout_queue';
      case 'mail':
        return 'mail';
      case 'sms_outbox':
        return 'sms_outbox';
      case 'admin':
      case 'admins':
      case 'users':
        return collection;
      default:
        return collection;
    }
  }

  static String _snake(String input) {
    return input
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (m) => '${m.group(1)}_${m.group(2)}',
        )
        .replaceAll('-', '_')
        .toLowerCase();
  }

  static Object? _encodeValue(Object? value) {
    if (value is _ServerTimestamp) return DateTime.now().toIso8601String();
    if (value is _ArrayUnion || value is _ArrayRemove) return value;
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _encodeValue(v)));
    }
    if (value is List) {
      return value.map(_encodeValue).toList(growable: false);
    }
    return value;
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw is DateTime) return raw;
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  static Map<String, dynamic> _decodeRow(
    String collection,
    Map<String, dynamic> row,
  ) {
    final out = <String, dynamic>{...row};

    dynamic ts(String key) {
      final value = row[key];
      final date = _parseDate(value);
      return date == null ? value : Timestamp._(date);
    }

    if (row.containsKey('created_at')) {
      out['createdAt'] = ts('created_at');
    }
    if (row.containsKey('updated_at')) {
      out['updatedAt'] = ts('updated_at');
    }
    if (row.containsKey('created_at_millis')) {
      out['createdAtMillis'] = row['created_at_millis'];
    }
    if (row.containsKey('created_at_ms')) {
      out['createdAtMs'] = row['created_at_ms'];
    }
    if (row.containsKey('updated_at_ms')) {
      out['updatedAtMs'] = row['updated_at_ms'];
    }

    for (final entry in row.entries) {
      if (entry.key.contains('_')) {
        final parts = entry.key.split('_');
        final camel = parts.first +
            parts
                .skip(1)
                .map((p) => p.isEmpty
                    ? ''
                    : p.substring(0, 1).toUpperCase() + p.substring(1))
                .join();
        out[camel] = entry.value;
      }
    }

    final summary = row['summary'];
    if (summary is Map) {
      out.addAll(Map<String, dynamic>.from(summary));
    }

    final details = row['details'];
    if (details is Map) {
      out['details'] = Map<String, dynamic>.from(details);
    }

    if (collection == 'Company_Custom_Requests') {
      out['sourceCollection'] = 'Company_Custom_Requests';
    }

    return out;
  }

  static Future<Map<String, dynamic>?> getDoc(
    String collection,
    String id, {
    DocumentReference<Map<String, dynamic>>? parentRef,
  }) async {
    if (parentRef != null && parentRef._collection == 'Client_Custom_Requests') {
      final parent = await getDoc(parentRef._collection, parentRef.id);
      final details = parent?['details'];
      if (details is Map) {
        return Map<String, dynamic>.from(details);
      }
      return <String, dynamic>{};
    }

    if (parentRef != null && parentRef._collection == 'Request_Chats') {
      final rows = await _sb
          .from('request_chat_messages')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (rows == null) return null;
      return _decodeRow('request_chat_messages', Map<String, dynamic>.from(rows));
    }

    final table = tableFor(collection);
    try {
      final row = await _sb.from(table).select().eq('id', id).maybeSingle();
      if (row == null) return null;
      return _decodeRow(collection, Map<String, dynamic>.from(row));
    } catch (_) {
      return null;
    }
  }

  static Future<void> setDoc(
    String collection,
    String id,
    Map<String, dynamic> data, {
    DocumentReference<Map<String, dynamic>>? parentRef,
    bool merge = false,
  }) async {
    if (parentRef != null && parentRef._collection == 'Client_Custom_Requests') {
      final existing = await getDoc(parentRef._collection, parentRef.id);
      final currentDetails = existing?['details'] is Map
          ? Map<String, dynamic>.from(existing!['details'] as Map)
          : <String, dynamic>{};
      final encoded = Map<String, dynamic>.from(_encodeValue(data) as Map);
      final details = merge ? <String, dynamic>{...currentDetails, ...encoded} : encoded;
      await _sb
          .from(tableFor(parentRef._collection))
          .update({
            'details': details,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', parentRef.id);
      return;
    }

    if (parentRef != null && parentRef._collection == 'Request_Chats') {
      final encoded = Map<String, dynamic>.from(_encodeValue(data) as Map);
      final now = DateTime.now();
      encoded['conversation_id'] = parentRef.id;
      encoded['created_at'] ??= now.toIso8601String();
      encoded['created_at_ms'] ??= now.millisecondsSinceEpoch;
      encoded['request_id'] = encoded['requestId'] ?? encoded['request_id'];
      encoded['sender_email'] = encoded['senderEmail'] ?? encoded['sender_email'];
      encoded['sender_name'] = encoded['senderName'] ?? encoded['sender_name'];
      encoded['attachment_url'] =
          encoded['attachmentUrl'] ?? encoded['attachment_url'] ?? '';
      encoded['attachment_type'] =
          encoded['attachmentType'] ?? encoded['attachment_type'] ?? '';
      encoded['attachment_name'] =
          encoded['attachmentName'] ?? encoded['attachment_name'] ?? '';
      encoded['is_system'] = encoded['isSystem'] ?? encoded['is_system'] ?? false;
      encoded.removeWhere((k, v) => !_chatMessageColumns.contains(k));
      await _sb.from('request_chat_messages').upsert({
        'id': id,
        ...encoded,
      });
      return;
    }

    final table = tableFor(collection);
    final encoded = Map<String, dynamic>.from(_encodeValue(data) as Map);
    final payload = await _toDbPayload(collection, id, encoded, merge: merge);

    if (merge) {
      await _sb.from(table).upsert({'id': id, ...payload});
    } else {
      await _sb.from(table).upsert({'id': id, ...payload});
    }
  }

  static Future<void> deleteDoc(
    String collection,
    String id, {
    DocumentReference<Map<String, dynamic>>? parentRef,
  }) async {
    if (parentRef != null && parentRef._collection == 'Request_Chats') {
      await _sb.from('request_chat_messages').delete().eq('id', id);
      return;
    }
    await _sb.from(tableFor(collection)).delete().eq('id', id);
  }

  static Future<List<_CompatRow>> queryCollection(
    String collection, {
    List<_WhereFilter> filters = const <_WhereFilter>[],
    int? limit,
    String? orderBy,
    bool descending = false,
  }) async {
    final table = tableFor(collection);
    try {
      dynamic query = _sb.from(table).select();

      final rows = await query.limit(limit ?? 1000);
      if (rows is! List) return const <_CompatRow>[];

      final out = <_CompatRow>[];
      for (final raw in rows.whereType<Map>()) {
        final dbRow = Map<String, dynamic>.from(raw);
        final data = _decodeRow(collection, dbRow);
        var ok = true;
        for (final filter in filters) {
          final expected = (filter.value ?? '').toString();
          final actual = (data[filter.field] ??
                  data[_snake(filter.field)] ??
                  data[_snake(filter.field).replaceAll('_', '')] ??
                  '')
              .toString();
          if (actual != expected) {
            ok = false;
            break;
          }
        }
        if (!ok) continue;
        out.add(_CompatRow((dbRow['id'] ?? '').toString(), data));
      }

      if (orderBy != null) {
        out.sort((a, b) {
          final av = a.data[orderBy] ?? a.data[_snake(orderBy)];
          final bv = b.data[orderBy] ?? b.data[_snake(orderBy)];
          final cmp = av.toString().compareTo(bv.toString());
          return descending ? -cmp : cmp;
        });
      }

      if (limit != null && out.length > limit) {
        return out.take(limit).toList(growable: false);
      }

      return out;
    } catch (_) {
      return const <_CompatRow>[];
    }
  }

  static const Set<String> _clientCustomColumns = <String>{
    'id',
    'client_id',
    'client_email',
    'client_name',
    'selected_artist',
    'selected_artist_email',
    'status',
    'client_status',
    'artist_status',
    'order_number',
    'summary',
    'details',
    'inspiration_photos',
    'photo_count',
    'has_inspiration_photos',
    'photo_upload_status',
    'photo_upload_error',
    'photo_upload_attempt',
    'photo_upload_updated_at',
    'created_at',
    'updated_at',
    'cancel_reason',
    'cancelled_at',
    'accepted_by_artist_email',
    'accepted_by_artist_name',
    'artist_profile_image',
    'artist_final_amount',
    'payment_status',
    'payment_link',
    'paid_at',
    'design_approval_status',
    'design_approved_at',
    'design_submitted_at',
    'design_approval_due_at',
    'design_reminder_sent_at',
    'design_preview_photos',
    'artist_completed_photos',
    'shipped_by_courier',
    'tracking_number',
    'shipped_at',
    'delivered_at',
  };

  static const Set<String> _notificationColumns = <String>{
    'id',
    'receiver_email',
    'title',
    'body',
    'type',
    'order_id',
    'order_number',
    'source_collection',
    'read',
    'extra',
    'created_at',
    'created_at_millis',
  };

  static const Set<String> _chatColumns = <String>{
    'id',
    'request_id',
    'client_email',
    'artist_email',
    'client_name',
    'artist_name',
    'participants',
    'last_message',
    'last_sender_email',
    'last_sender_name',
    'created_at',
    'updated_at',
    'created_at_ms',
    'updated_at_ms',
  };

  static const Set<String> _chatMessageColumns = <String>{
    'id',
    'conversation_id',
    'request_id',
    'text',
    'sender_email',
    'sender_name',
    'attachment_url',
    'attachment_type',
    'attachment_name',
    'is_system',
    'created_at',
    'created_at_ms',
  };


  static Map<String, dynamic> _applyCompatArrayOperations(
    Map<String, dynamic> existing,
    Map<String, dynamic> incoming,
  ) {
    final out = <String, dynamic>{...existing};

    for (final entry in incoming.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value is _ArrayUnion) {
        final current = out[key];
        final list = current is List ? List<Object?>.from(current) : <Object?>[];
        for (final item in value.values) {
          if (!list.any((existingItem) => existingItem == item)) {
            list.add(item);
          }
        }
        out[key] = list;
        continue;
      }

      if (value is _ArrayRemove) {
        final current = out[key];
        final list = current is List ? List<Object?>.from(current) : <Object?>[];
        list.removeWhere((existingItem) => value.values.any((item) => item == existingItem));
        out[key] = list;
        continue;
      }

      out[key] = value;
    }

    return out;
  }

  static Future<Map<String, dynamic>> _toDbPayload(
    String collection,
    String id,
    Map<String, dynamic> data, {
    required bool merge,
  }) async {
    final now = DateTime.now().toIso8601String();

    if (collection == 'Client_Custom_Requests' ||
        collection == 'Company_Custom_Requests' ||
        collection == 'client_custom_requests') {
      final existing = await getDoc(collection, id);
      final summary = existing?['summary'] is Map
          ? Map<String, dynamic>.from(existing!['summary'] as Map)
          : <String, dynamic>{};
      final mergedSummary = merge
          ? _applyCompatArrayOperations(summary, data)
          : data;

      final out = <String, dynamic>{
        'summary': mergedSummary,
        'updated_at': now,
      };

      void put(String dbKey, Object? value) {
        if (value == null) return;
        out[dbKey] = value;
      }

      put('client_email', data['clientEmail'] ?? data['client_email']);
      put('client_name', data['clientName'] ?? data['client_name']);
      put('selected_artist', data['selectedArtist'] ?? data['selected_artist']);
      put('selected_artist_email',
          data['selectedArtistEmail'] ?? data['selected_artist_email']);
      put('status', data['status']);
      put('client_status', data['clientStatus'] ?? data['client_status']);
      put('artist_status', data['artistStatus'] ?? data['artist_status']);
      put('order_number', data['orderNumber'] ?? data['order_number']);
      put('cancel_reason', data['cancelReason'] ?? data['cancel_reason']);
      put('cancelled_at', data['cancelledAt'] ?? data['cancelled_at']);
      put('accepted_by_artist_email',
          data['acceptedByArtistEmail'] ?? data['accepted_by_artist_email']);
      put('accepted_by_artist_name',
          data['acceptedByArtistName'] ?? data['accepted_by_artist_name']);
      put('artist_profile_image',
          data['artistProfileImage'] ?? data['artist_profile_image']);
      put('artist_final_amount',
          data['artistFinalAmount'] ?? data['artist_final_amount']);
      put('payment_status', data['paymentStatus'] ?? data['payment_status']);
      put('payment_link', data['paymentLink'] ?? data['payment_link']);
      put('paid_at', data['paidAt'] ?? data['paid_at']);
      put('design_approval_status',
          data['designApprovalStatus'] ?? data['design_approval_status']);
      put('design_approved_at',
          data['designApprovedAt'] ?? data['design_approved_at']);
      put('design_submitted_at',
          data['designSubmittedAt'] ?? data['design_submitted_at']);
      put('design_approval_due_at',
          data['designApprovalDueAt'] ?? data['design_approval_due_at']);
      put('design_reminder_sent_at',
          data['designReminderSentAt'] ?? data['design_reminder_sent_at']);
      put('design_preview_photos',
          data['designPreviewPhotos'] ?? data['design_preview_photos']);
      put('artist_completed_photos',
          data['artistCompletedPhotos'] ?? data['artist_completed_photos']);
      put('shipped_by_courier',
          data['shippedByCourier'] ?? data['shipped_by_courier']);
      put('tracking_number', data['trackingNumber'] ?? data['tracking_number']);
      put('shipped_at', data['shippedAt'] ?? data['shipped_at']);
      put('delivered_at', data['deliveredAt'] ?? data['delivered_at']);

      if (data['inspirationPhotos'] != null) {
        out['inspiration_photos'] = data['inspirationPhotos'];
      }

      out.removeWhere((key, value) => !_clientCustomColumns.contains(key));
      out['updated_at'] = now;
      return out;
    }

    if (collection == 'user_notifications') {
      final out = <String, dynamic>{};
      for (final entry in data.entries) {
        final key = _snake(entry.key);
        if (_notificationColumns.contains(key)) {
          out[key] = entry.value;
        } else {
          final extra = out['extra'] is Map
              ? Map<String, dynamic>.from(out['extra'] as Map)
              : <String, dynamic>{};
          extra[entry.key] = entry.value;
          out['extra'] = extra;
        }
      }
      out['created_at'] ??= now;
      out['created_at_millis'] ??= DateTime.now().millisecondsSinceEpoch;
      return out;
    }

    if (collection == 'Request_Chats' || collection == 'request_chats') {
      final out = <String, dynamic>{};
      for (final entry in data.entries) {
        final key = _snake(entry.key);
        if (_chatColumns.contains(key)) out[key] = entry.value;
      }
      out['updated_at'] ??= now;
      out['updated_at_ms'] ??= DateTime.now().millisecondsSinceEpoch;
      out['created_at'] ??= now;
      out['created_at_ms'] ??= DateTime.now().millisecondsSinceEpoch;
      return out;
    }

    final out = <String, dynamic>{};
    for (final entry in data.entries) {
      out[entry.key] = entry.value;
    }
    out['updated_at'] ??= now;
    return out;
  }
}

class FirebaseStorage {
  FirebaseStorage._();
  static final FirebaseStorage instance = FirebaseStorage._();

  Reference ref([String path = '']) => Reference(path);
  Reference refFromURL(String url) => Reference(url);
}

class Reference {
  Reference(this.fullPath);

  final String fullPath;

  String get name {
    final parts = fullPath.split('/');
    return parts.isEmpty ? fullPath : parts.last;
  }

  Future<void> putData(Uint8List bytes, [SettableMetadata? metadata]) async {
    final bucket = _bucketForPath(fullPath);
    final path = _pathWithoutBucket(fullPath, bucket);
    await Supabase.instance.client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: metadata?.contentType,
            upsert: true,
          ),
        );
  }

  Future<String> getDownloadURL() async {
    final value = fullPath.trim();
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    final bucket = _bucketForPath(value);
    final path = _pathWithoutBucket(value, bucket);
    return Supabase.instance.client.storage.from(bucket).getPublicUrl(path).trim();
  }

  Future<Uint8List?> getData([int maxSize = 10485760]) async {
    final value = fullPath.trim();
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return null;
    }
    final bucket = _bucketForPath(value);
    final path = _pathWithoutBucket(value, bucket);
    return Supabase.instance.client.storage.from(bucket).download(path);
  }

  Future<ListResult> listAll() async {
    final bucket = _bucketForPath(fullPath);
    final path = _pathWithoutBucket(fullPath, bucket);
    final result = await Supabase.instance.client.storage.from(bucket).list(path: path);
    final items = result
        .map((file) => Reference('$path/${file.name}'.replaceAll('//', '/')))
        .toList(growable: false);
    return ListResult(items);
  }

  static String _bucketForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.startsWith('chat-attachments/')) return 'chat-attachments';
    if (lower.startsWith('portfolio-images/')) return 'portfolio-images';
    if (lower.startsWith('profile-pictures/')) return 'profile-pictures';
    if (lower.startsWith('company-logos/')) return 'company-logos';
    return lower.contains('chat_attachments') || lower.contains('chat-attachments')
        ? 'chat-attachments'
        : 'request-inspiration-photos';
  }

  static String _pathWithoutBucket(String path, String bucket) {
    var value = path.trim();
    if (value.startsWith('$bucket/')) {
      value = value.substring(bucket.length + 1);
    }
    return value;
  }
}

class SettableMetadata {
  const SettableMetadata({this.contentType});
  final String? contentType;
}

class ListResult {
  const ListResult(this.items);
  final List<Reference> items;
}

class StorageUrlResolver {
  static Future<String?> resolve(String raw) async {
    final value = raw.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('data:') ||
        value.startsWith('assets/')) {
      return value;
    }
    try {
      return await FirebaseStorage.instance.ref(value).getDownloadURL();
    } catch (_) {
      if (kIsWeb || value.startsWith('/')) return value;
      return '';
    }
  }
}
