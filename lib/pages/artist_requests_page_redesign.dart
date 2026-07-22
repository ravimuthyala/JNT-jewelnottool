import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../theme/app_colors.dart';
import '../utils/image_cache_utils.dart';
import 'artist_designing_request_sheet.dart';
import '../models/client_request_v2.dart';
import 'artist_completed_request_sheet.dart';
import 'artist_shipped_request_sheet.dart';
import 'client_campaign_details_page.dart';
import '../services/artist_requests_repository.dart';
import '../services/ascension_service.dart';
import '../services/notifications_service.dart';
import '../services/shipping_qr_helper.dart';
import 'artist_profile_page.dart';
import 'artist_reviews_page.dart';
import 'notifications_page.dart';
import '../utils/scenario_4_1.dart';
import '../utils/scenario_4_3.dart';
import '../utils/request_nfc_details_loader.dart';
import '../widgets/artist_profile_avatar_icon.dart';
import '../widgets/jnt_standard_app_bar.dart';
import '../widgets/company_client_request_card.dart';

// Supabase database compatibility helpers for this page.
// These keep the existing UI and business-flow code intact while routing reads/writes to Supabase tables.
class SetOptions {
  const SetOptions({this.merge = false});
  final bool merge;
}

class SupabaseDbTime {
  const SupabaseDbTime(this.value);
  final DateTime value;
  static SupabaseDbTime fromDate(DateTime value) => SupabaseDbTime(value);
  DateTime toDate() => value;
}

class _ServerNowMarker {
  const _ServerNowMarker();
}

class _ArrayUnionMarker {
  const _ArrayUnionMarker(this.values);
  final List<Object?> values;
}

class SupabaseServerValue {
  static const _ServerNowMarker _now = _ServerNowMarker();
  static Object serverNow() => _now;
  static Object arrayUnion(List<Object?> values) => _ArrayUnionMarker(values);
}

class DocumentSnapshot<T extends Map<String, dynamic>> {
  const DocumentSnapshot({
    required this.id,
    required this.reference,
    required Map<String, dynamic>? data,
  }) : _data = data;

  final String id;
  final DocumentReference<T> reference;
  final Map<String, dynamic>? _data;
  bool get exists => _data != null;
  T? data() {
    final data = _data;
    return data == null
        ? null
        : Map<String, dynamic>.from(_withAliases(data)) as T;
  }
}

class QuerySnapshot<T extends Map<String, dynamic>> {
  const QuerySnapshot(this.docs);
  final List<DocumentSnapshot<T>> docs;
}

class SupabaseCompatDatabase {
  SupabaseCompatDatabase._();
  static final SupabaseCompatDatabase instance = SupabaseCompatDatabase._();

  CollectionReference<Map<String, dynamic>> collection(String name) {
    return CollectionReference<Map<String, dynamic>>(_tableForCollection(name));
  }

  WriteBatch batch() => WriteBatch();
}

class CollectionReference<T extends Map<String, dynamic>> {
  CollectionReference(this.table, {this.parent});
  final String table;
  final DocumentReference<Map<String, dynamic>>? parent;
  int? _limit;
  final List<_Filter> _filters = <_Filter>[];

  DocumentReference<T> doc(String id) =>
      DocumentReference<T>(table, id, parent: parent);

  CollectionReference<T> limit(int value) {
    _limit = value;
    return this;
  }

  CollectionReference<T> where(String field, {Object? isEqualTo}) {
    _filters.add(_Filter(_columnName(field), isEqualTo));
    return this;
  }

  Future<QuerySnapshot<T>> get() async {
    try {
      var query = Supabase.instance.client.from(table).select();
      for (final filter in _filters) {
        query = query.eq(filter.field, _encodeValue(filter.value));
      }
      final rows = _limit == null ? await query : await query.limit(_limit!);
      final list = rows as List;
      final docs = list
          .whereType<Map>()
          .map((raw) {
            final data = Map<String, dynamic>.from(raw);
            final id = (data['id'] ?? '').toString();
            return DocumentSnapshot<T>(
              id: id,
              reference: DocumentReference<T>(table, id, parent: parent),
              data: data,
            );
          })
          .toList(growable: false);
      return QuerySnapshot<T>(docs);
    } catch (_) {
      return QuerySnapshot<T>(<DocumentSnapshot<T>>[]);
    }
  }

  Stream<QuerySnapshot<T>> snapshots() async* {
    yield await get();
    try {
      await for (final rows
          in Supabase.instance.client
              .from(table)
              .stream(primaryKey: const ['id'])) {
        final docs = rows
            .map((raw) {
              final data = Map<String, dynamic>.from(raw);
              final id = (data['id'] ?? '').toString();
              return DocumentSnapshot<T>(
                id: id,
                reference: DocumentReference<T>(table, id, parent: parent),
                data: data,
              );
            })
            .toList(growable: false);
        yield QuerySnapshot<T>(docs);
      }
    } catch (_) {}
  }
}

class DocumentReference<T extends Map<String, dynamic>> {
  const DocumentReference(this.table, this.id, {this.parent});
  final String table;
  final String id;
  final DocumentReference<Map<String, dynamic>>? parent;

  CollectionReference<Map<String, dynamic>> collection(String name) {
    final childTable = _detailsTableFor(table);
    return CollectionReference<Map<String, dynamic>>(
      childTable,
      parent: this as DocumentReference<Map<String, dynamic>>,
    );
  }

  Future<DocumentSnapshot<T>> get() async {
    try {
      final data = await _fetchOne();
      return DocumentSnapshot<T>(id: id, reference: this, data: data);
    } catch (_) {
      return DocumentSnapshot<T>(id: id, reference: this, data: null);
    }
  }

  Future<void> set(Map<String, dynamic> values, [SetOptions? options]) async {
    await _write(values, merge: options?.merge ?? false);
  }

  Future<void> update(Map<String, dynamic> values) async {
    await _write(values, merge: true);
  }

  Future<Map<String, dynamic>?> _fetchOne() async {
    if (parent != null && _isDetailsTable(table)) {
      final parentId = parent!.id;
      final isClientDetailsTable = table == 'client_custom_requests_details';
      final attempts = <Future<Map<String, dynamic>?>>[
        if (isClientDetailsTable)
          _selectMaybe({'request_id': parentId, 'detail_key': id}),
        if (!isClientDetailsTable)
          _selectMaybe({'request_id': parentId, 'doc_id': id}),
        _selectMaybe({'request_id': parentId}),
        _selectMaybe({'id': '$parentId:$id'}),
        _selectMaybe({'id': parentId}),
      ];
      for (final attempt in attempts) {
        try {
          final row = await attempt;
          if (row != null) return _flattenDetailRow(row);
        } catch (_) {}
      }
      return null;
    }

    final row = await Supabase.instance.client
        .from(table)
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>?> _selectMaybe(
    Map<String, Object?> filters,
  ) async {
    var query = Supabase.instance.client.from(table).select();
    filters.forEach((key, value) {
      query = query.eq(key, value as Object);
    });
    final row = await query.maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<void> _write(
    Map<String, dynamic> values, {
    required bool merge,
  }) async {
    if (parent != null && _isDetailsTable(table)) {
      await _writeDetails(values);
      return;
    }

    final encoded = await _prepareValues(
      values,
      existing: merge ? await _fetchOne() : null,
    );
    encoded['id'] = id;
    try {
      await Supabase.instance.client
          .from(table)
          .upsert(encoded, onConflict: 'id');
    } catch (_) {
      final dataPayload = <String, dynamic>{'id': id, 'data': encoded};
      await Supabase.instance.client
          .from(table)
          .upsert(dataPayload, onConflict: 'id');
    }
  }

  Future<void> _writeDetails(Map<String, dynamic> values) async {
    final parentId = parent!.id;
    final existing = await _fetchOne();
    final encoded = await _prepareValues(values, existing: existing);

    // Supabase detail tables do not all share the same schema.
    // In this project, client_custom_requests_details does not have a
    // `payload` column, so never send `payload` to that table.
    // This keeps accept/decline writes from failing with PGRST204.
    final isClientDetailsTable = table == 'client_custom_requests_details';
    if (isClientDetailsTable) {
      await Supabase.instance.client.from(table).upsert(<String, dynamic>{
        'id': '$parentId:$id',
        'request_id': parentId,
        'detail_key': id,
        'data': encoded,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'id');
      return;
    }

    final detailRows = <Map<String, dynamic>>[
      <String, dynamic>{
        'request_id': parentId,
        'doc_id': id,
        if (!isClientDetailsTable) 'payload': encoded,
        'data': encoded,
        ...encoded,
      },
      <String, dynamic>{
        'request_id': parentId,
        if (!isClientDetailsTable) 'payload': encoded,
        'data': encoded,
        ...encoded,
      },
      <String, dynamic>{
        'id': parentId,
        if (!isClientDetailsTable) 'payload': encoded,
        'data': encoded,
      },
      <String, dynamic>{'id': parentId, 'details': encoded},
    ];

    final conflicts = <String>['request_id,doc_id', 'request_id', 'id', 'id'];

    Object? lastError;
    for (var i = 0; i < detailRows.length; i += 1) {
      try {
        await Supabase.instance.client
            .from(table)
            .upsert(detailRows[i], onConflict: conflicts[i]);
        return;
      } catch (e) {
        lastError = e;
      }
    }

    throw lastError ?? Exception('Unable to save request details.');
  }
}

class WriteBatch {
  final List<Future<void> Function()> _ops = <Future<void> Function()>[];

  void set(
    DocumentReference<dynamic> ref,
    Map<String, dynamic> values, [
    SetOptions? options,
  ]) {
    _ops.add(() => ref.set(values, options));
  }

  void update(DocumentReference<dynamic> ref, Map<String, dynamic> values) {
    _ops.add(() => ref.update(values));
  }

  Future<void> commit() async {
    for (final op in _ops) {
      await op();
    }
  }
}

class _Filter {
  const _Filter(this.field, this.value);

  final String field;
  final Object? value;
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
  if (parentTable == 'company_custom_requests')
    return 'company_custom_requests_details';
  if (parentTable == 'client_custom_requests')
    return 'client_custom_requests_details';
  return '${parentTable}_details';
}

bool _isDetailsTable(String table) => table.endsWith('_details');

String _snakeName(String input) {
  return input
      .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]}_${m[2]}')
      .replaceAll(' ', '_')
      .replaceAll('-', '_')
      .toLowerCase();
}

String _columnName(String input) => _snakeName(input);

String _camelName(String input) {
  final parts = input.split('_');
  if (parts.isEmpty) return input;
  return parts.first +
      parts
          .skip(1)
          .map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1))
          .join();
}

Map<String, dynamic> _withAliases(Map<String, dynamic> row) {
  final out = Map<String, dynamic>.from(row);
  for (final entry in row.entries) {
    if (entry.key.contains('_')) out[_camelName(entry.key)] = entry.value;
  }
  final payload = row['payload'] ?? row['data'] ?? row['details'];
  if (payload is Map) {
    final p = Map<String, dynamic>.from(payload);
    out.addAll(p);
    for (final entry in p.entries) {
      if (entry.key.contains('_')) out[_camelName(entry.key)] = entry.value;
    }
  }
  return out;
}

Map<String, dynamic> _flattenDetailRow(Map<String, dynamic> row) {
  final out = _withAliases(row);
  for (final key in const ['payload', 'data', 'details']) {
    final value = row[key];
    if (value is Map) {
      out.addAll(_withAliases(Map<String, dynamic>.from(value)));
      continue;
    }
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) {
          out.addAll(_withAliases(Map<String, dynamic>.from(decoded)));
        }
      } catch (_) {}
    }
  }
  return out;
}

Object _encodeValue(Object? value) {
  if (value == null) return '';

  if (value is _ServerNowMarker) {
    return DateTime.now().toUtc().toIso8601String();
  }

  if (value is SupabaseDbTime) {
    return value.value.toUtc().toIso8601String();
  }

  if (value is DateTime) {
    return value.toUtc().toIso8601String();
  }

  if (value is Map) {
    return value.map(
      (k, v) => MapEntry(_columnName(k.toString()), _encodeValue(v)),
    );
  }

  if (value is List) {
    return value.map(_encodeValue).toList(growable: false);
  }

  return value;
}

Future<Map<String, dynamic>> _prepareValues(
  Map<String, dynamic> values, {
  Map<String, dynamic>? existing,
}) async {
  final out = <String, dynamic>{};
  values.forEach((key, value) {
    final col = _columnName(key);
    if (value is _ArrayUnionMarker) {
      final current = existing?[col] ?? existing?[key];
      final list = current is List ? List<Object?>.from(current) : <Object?>[];
      for (final item in value.values) {
        if (!list.map((e) => e.toString()).contains(item.toString()))
          list.add(item);
      }
      out[col] = list;
    } else {
      out[col] = _encodeValue(value);
    }
  });
  return out;
}

extension SupabaseUserDisplayNameCompat on User {
  String? get displayName {
    final user = Supabase.instance.client.auth.currentUser;
    final metadata = user?.userMetadata ?? const <String, dynamic>{};
    final candidates = <Object?>[
      metadata['display_name'],
      metadata['displayName'],
      metadata['full_name'],
      metadata['name'],
      email?.split('@').first,
    ];
    for (final raw in candidates) {
      final value = (raw ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return null;
  }
}

enum DocumentChangeType { added, modified, removed }

class SupabaseDocumentChange<T extends Map<String, dynamic>> {
  const SupabaseDocumentChange(this.type, this.doc);

  final DocumentChangeType type;
  final DocumentSnapshot<T> doc;
}

extension SupabaseQuerySnapshotDocChangesCompat<T extends Map<String, dynamic>>
    on QuerySnapshot<T> {
  List<SupabaseDocumentChange<T>> get docChanges => docs
      .map((doc) => SupabaseDocumentChange<T>(DocumentChangeType.modified, doc))
      .toList(growable: false);
}

class StorageUrlResolver {
  static Future<String?> resolve(String value) async {
    final raw = value.trim();
    if (raw.isEmpty) return null;
    if (raw.startsWith('http://') ||
        raw.startsWith('https://') ||
        raw.startsWith('data:') ||
        raw.startsWith('blob:') ||
        raw.startsWith('content://') ||
        raw.startsWith('file://') ||
        raw.startsWith('assets/')) {
      return raw;
    }

    var path = raw;
    String? explicitBucket;
    if (path.startsWith('gs://')) {
      final withoutScheme = path.substring(5);
      final slash = withoutScheme.indexOf('/');
      if (slash == -1) return null;
      explicitBucket = withoutScheme.substring(0, slash);
      path = withoutScheme.substring(slash + 1);
    }

    final cleaned = path.startsWith('/') ? path.substring(1) : path;
    final supabase = Supabase.instance.client;
    final buckets = <String>[
      if (explicitBucket != null && explicitBucket.isNotEmpty) explicitBucket,
      'request-inspiration-photos',
      'request-completed-photos',
      'request-design-previews',
      'chat-attachments',
      'public',
    ];

    for (final bucket in buckets) {
      try {
        final url = supabase.storage.from(bucket).getPublicUrl(cleaned);
        if (url.trim().isNotEmpty) return url;
      } catch (_) {}
    }
    return raw;
  }
}

double _reqScale(BuildContext context) {
  final w = MediaQuery.of(context).size.width;
  if (w < 360) return 0.85;
  if (w < 390) return 0.9;
  return 0.95; // slightly smaller even on normal phones
}

bool shouldShowScenario21ToArtist({
  required bool clientAccepted,
  required bool isDirectRequest,
  required String selectedArtistEmail,
  required String viewerArtistEmail,
}) {
  if (!clientAccepted) return false;
  if (!isDirectRequest) return true;
  final selected = selectedArtistEmail.trim().toLowerCase();
  final viewer = viewerArtistEmail.trim().toLowerCase();
  if (selected.isEmpty || viewer.isEmpty) return false;
  return selected == viewer;
}

bool shouldShowScenario31ToArtistPool({
  required bool clientAccepted,
  required String requestStatus,
  required String acceptedByArtistEmail,
  required String viewerArtistEmail,
}) {
  if (!clientAccepted) return false;
  final normalizedStatus = requestStatus.trim().toLowerCase();
  final owner = acceptedByArtistEmail.trim().toLowerCase();
  final viewer = viewerArtistEmail.trim().toLowerCase();
  if (owner.isNotEmpty) return owner == viewer;
  return normalizedStatus == 'in_review' || normalizedStatus == 'pending';
}

/// ----------------------------------------------
/// Redesigned Artist Requests Page (UI v2)
/// - Search bar
/// - Filters: Direct / Inspo only
/// - Budget preset from profile (editable + range)
/// - Shipping time filter (estimator stub: uses client+artist location fields)
/// - Sort: Newest / Soonest needed / Higher budget
/// - Tabs: In Review, Designing, Completed, Shipped
/// ----------------------------------------------
class ArtistRequestsPageRedesign extends StatefulWidget {
  const ArtistRequestsPageRedesign({
    super.key,
    this.initialBudgetMin = 15,
    this.initialBudgetMax = 5000,
    this.artistLocation = '',
    this.showBottomNav = false,
    this.bottomNavIndex = 2,
    this.onNavTap,
    this.onOpenNotifications,
    this.onManageProfile,
    this.onOpenInbox,
    this.onOpenHistory,
    this.onOpenCalendar,
    this.onOpenArtist,
    this.onOpenEarnings,
    this.onOpenReviews,
    this.onSignOut,
    this.clientArtistMenuStyle = false,
    this.showProfileMenuItem = false,
    this.showOnlyCurrentClientRequests = false,
    this.showOnlyCompanyRequests = false,
    this.includeClientArtistBrandRequestsInRequestTab = false,
  });

  final int initialBudgetMin;
  final int initialBudgetMax;

  /// Used by shipping estimator when available.
  final String artistLocation;
  final bool showBottomNav;
  final int bottomNavIndex;
  final ValueChanged<int>? onNavTap;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onManageProfile;
  final VoidCallback? onOpenInbox;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenArtist;
  final VoidCallback? onOpenEarnings;
  final VoidCallback? onOpenReviews;
  final VoidCallback? onSignOut;
  final bool clientArtistMenuStyle;
  final bool showProfileMenuItem;
  final bool showOnlyCurrentClientRequests;
  final bool showOnlyCompanyRequests;
  final bool includeClientArtistBrandRequestsInRequestTab;

  @override
  State<ArtistRequestsPageRedesign> createState() =>
      _ArtistRequestsPageRedesignState();
}

class _ArtistRequestsPageRedesignState extends State<ArtistRequestsPageRedesign>
    with SingleTickerProviderStateMixin {
  static const int _realtimeWatchLimitPerCollection = 8;

  // Search + sort
  final _searchCtrl = TextEditingController();
  String _sort = 'Newest';

  // Toggle filters
  bool _directOnly = false;
  bool _groupOnly = false;

  OverlayEntry? _dropdownEntry;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _clientRequestsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _companyRequestsSub;

  void _closeDropdown() {
    _dropdownEntry?.remove();
    _dropdownEntry = null;
  }

  // Budget
  late RangeValues _budgetRange;
  late final TextEditingController _budgetMinCtrl;
  late final TextEditingController _budgetMaxCtrl;

  // Tabs (8 statuses)
  late final TabController _tabCtrl;

  bool _isLoadingDb = false;
  bool _loadRequestsInFlight = false;
  bool _hasLoadedRequests = false;
  bool _initialLoadScheduled = false;
  bool _realtimeBound = false;
  final List<ClientRequestV2> _all = [];
  final Set<String> _locallyDeclinedRequestIds = <String>{};
  final Set<String> _persistedArtistDeclinedRequestIds = <String>{};
  String _currentArtistNameLower = '';
  String _currentArtistDisplayNameLower = '';
  String _currentArtistEmailLocalLower = '';
  bool _currentArtistIsLicensed = true;
  bool _currentArtistBrandEligible = false;
  bool _currentClientAmbassadorEligible = false;
  bool _currentArtistAcceptsNfc = false;
  TextStyle _t(
    double size, {
    FontWeight w = FontWeight.w700,
    Color? c,
    double? h,
  }) {
    final s = _reqScale(context);
    return TextStyle(
      fontSize: (size + 2) * s,
      fontWeight: w,
      color: c ?? AppColors.blackCat.withValues(alpha: 0.90),
      height: h,
    );
  }

  int _countForAllActive() {
    return _all
        .where(
          (r) =>
              r.status != RequestStatusV2.delivered &&
              r.status != RequestStatusV2.declined &&
              r.status != RequestStatusV2.expired &&
              r.status != RequestStatusV2.cancelled,
        )
        .where(_applySharedFilters)
        .length;
  }

  int _countForStatus(RequestStatusV2 status) {
    return _all
        .where((r) => r.status == status)
        .where(_applySharedFilters)
        .length;
  }

  int _countForDesigningTab() {
    return _all
        .where(
          (r) =>
              r.status == RequestStatusV2.designing ||
              r.status == RequestStatusV2.accepted,
        )
        .where(_applySharedFilters)
        .length;
  }

  bool _matchesSearch(ClientRequestV2 r) {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    return r.clientName.toLowerCase().contains(q) ||
        r.title.toLowerCase().contains(q) ||
        r.subtitle.toLowerCase().contains(q) ||
        r.id.toLowerCase().contains(q);
  }

  bool _matchesDirect(ClientRequestV2 r) => !_directOnly || r.isDirectRequest;
  bool _matchesGroup(ClientRequestV2 r) =>
      !_groupOnly || r.orderType == RequestOrderTypeV2.group;
  bool _matchesBudget(ClientRequestV2 r) {
    final minBudget = _budgetRange.start.round();
    final maxBudget = _budgetRange.end.round();
    final normalizedMin = r.budgetMin <= r.budgetMax
        ? r.budgetMin
        : r.budgetMax;
    final normalizedMax = r.budgetMin <= r.budgetMax
        ? r.budgetMax
        : r.budgetMin;
    return normalizedMax >= minBudget && normalizedMin <= maxBudget;
  }

  bool _matchesShipTime(ClientRequestV2 r) {
    return true;
  }

  bool get _hasActiveFilters {
    final minPreset = widget.initialBudgetMin.clamp(15, 5000);
    final maxPreset = widget.initialBudgetMax.clamp(15, 5000);
    final defaultStart = minPreset <= maxPreset ? minPreset : maxPreset;
    final defaultEnd = minPreset <= maxPreset ? maxPreset : minPreset;
    final budgetChanged =
        _budgetRange.start.round() != defaultStart ||
        _budgetRange.end.round() != defaultEnd;
    return _directOnly || _groupOnly || budgetChanged || _sort != 'Newest';
  }

  bool _applySharedFilters(ClientRequestV2 r) {
    return _matchesSearch(r) &&
        _matchesDirect(r) &&
        _matchesGroup(r) &&
        _matchesBudget(r) &&
        _matchesShipTime(r);
  }

  @override
  void initState() {
    super.initState();

    _tabCtrl = TabController(length: 5, vsync: this);

    final minPreset = widget.initialBudgetMin.clamp(15, 5000);
    final maxPreset = widget.initialBudgetMax.clamp(15, 5000);
    final start = minPreset <= maxPreset ? minPreset : maxPreset;
    final end = minPreset <= maxPreset ? maxPreset : minPreset;

    _budgetRange = RangeValues(start.toDouble(), end.toDouble());
    _budgetMinCtrl = TextEditingController(text: start.toString());
    _budgetMaxCtrl = TextEditingController(text: end.toString());
    if (!widget.showOnlyCurrentClientRequests) {
      unawaited(_loadCurrentArtistIdentity());
    }
    // Load on explicit user action to avoid startup OOM from large legacy docs.
  }

  Future<void> _loadCurrentArtistIdentity() async {
    final email = (Supabase.instance.client.auth.currentUser?.email ?? '')
        .trim()
        .toLowerCase();
    _currentArtistDisplayNameLower =
        (Supabase.instance.client.auth.currentUser?.displayName ?? '')
            .trim()
            .toLowerCase();
    _currentArtistEmailLocalLower = email.contains('@')
        ? email.split('@').first.trim().toLowerCase()
        : '';
    if (email.isEmpty) return;

    Map<String, dynamic> parseMap(Object? value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        return value.map((key, val) => MapEntry(key.toString(), val));
      }
      if (value is String) {
        final text = value.trim();
        if (text.isEmpty) return const <String, dynamic>{};
        try {
          final decoded = jsonDecode(text);
          if (decoded is Map<String, dynamic>) return decoded;
          if (decoded is Map) {
            return decoded.map((key, val) => MapEntry(key.toString(), val));
          }
        } catch (_) {}
      }
      return const <String, dynamic>{};
    }

    String readName(Map<String, dynamic> data) {
      final profile = parseMap(data['profile']);
      final candidates = <Object?>[
        data['name'],
        data['displayName'],
        profile['name'],
        profile['displayName'],
      ];
      for (final raw in candidates) {
        final v = (raw ?? '').toString().trim();
        if (v.isNotEmpty) return v.toLowerCase();
      }
      return '';
    }

    bool readIsLicensed(Map<String, dynamic> data) {
      String pullNailTechType() {
        final profile = parseMap(data['profile']);
        final credentials = parseMap(data['credentials']);
        final nestedCredentials = parseMap(profile['credentials']);
        final artist = parseMap(data['artist']);
        final artistCredentials = parseMap(artist['credentials']);
        final artistProfile = parseMap(data['artist_profile']);
        final artistProfileCredentials = parseMap(artistProfile['credentials']);
        final candidateValues = <Object?>[
          credentials['nailTechType'],
          credentials['nail_tech_type'],
          nestedCredentials['nailTechType'],
          nestedCredentials['nail_tech_type'],
          profile['nailTechType'],
          profile['nail_tech_type'],
          artistProfileCredentials['nailTechType'],
          artistProfileCredentials['nail_tech_type'],
          artistCredentials['nailTechType'],
          artistCredentials['nail_tech_type'],
          artistProfile['nailTechType'],
          artistProfile['nail_tech_type'],
          artist['nailTechType'],
          artist['nail_tech_type'],
          data['panel_artist_nailTechType'],
          data['panel_artist_nail_tech_type'],
          data['panel_nailTechType'],
          data['panel_nail_tech_type'],
          data['nailTechType'],
          data['nail_tech_type'],
          data['credential'],
        ];
        for (final raw in candidateValues) {
          final value = (raw ?? '').toString().trim();
          if (value.isNotEmpty) return value;
        }
        return '';
      }

      final type = pullNailTechType().toLowerCase();
      if (type.isEmpty) return true;
      final isUnlicensed =
          type.contains('student') ||
          type.contains('non-licensed') ||
          type.contains('unlicensed');
      return !isUnlicensed;
    }

    bool readBrandEligibility(Map<String, dynamic> data) {
      final ascension = parseMap(data['ascension']);
      final profile = parseMap(data['profile']);
      final sponsorshipRequest = parseMap(data['sponsorshipRequest']);
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
      final sponsorshipEligible = ascension['sponsorshipEligible'];
      if (sponsorshipEligible is bool) return sponsorshipEligible;
      final pointsRaw =
          ascension['points'] ??
          data['panel_ascensionPoints'] ??
          data['ascensionPoints'];
      final points = pointsRaw is num
          ? pointsRaw.toInt()
          : int.tryParse((pointsRaw ?? '').toString()) ?? 0;
      return points >= AscensionService.goldsmithMin;
    }

    bool readAcceptsNfc(Map<String, dynamic> data) {
      bool? maybeBool(Object? raw) {
        if (raw is bool) return raw;
        if (raw is num) return raw != 0;
        final value = (raw ?? '').toString().trim().toLowerCase();
        if (value == 'true' || value == '1' || value == 'yes') return true;
        if (value == 'false' || value == '0' || value == 'no') return false;
        return null;
      }

      final profile = parseMap(data['profile']);
      final availability = parseMap(data['availability']);
      final artist = parseMap(data['artist']);
      final artistAvailability = parseMap(artist['availability']);
      for (final raw in <Object?>[
        data['panel_nfcRequestEnabled'],
        data['panel_nfc_request_enabled'],
        data['nfcRequestEnabled'],
        data['nfc_request_enabled'],
        availability['nfcRequestEnabled'],
        availability['nfc_request_enabled'],
        profile['nfcRequestEnabled'],
        profile['nfc_request_enabled'],
        artist['nfcRequestEnabled'],
        artist['nfc_request_enabled'],
        artistAvailability['nfcRequestEnabled'],
        artistAvailability['nfc_request_enabled'],
      ]) {
        final value = maybeBool(raw);
        if (value != null) return value;
      }
      return false;
    }

    bool readAmbassadorEligibility(Map<String, dynamic> data) {
      String normalize(Object? raw) =>
          (raw ?? '').toString().trim().toLowerCase().replaceAll('_', ' ');

      bool matchStatus(Object? raw) {
        final value = normalize(raw);
        return value == 'ambassador' ||
            (value.contains('ambassador') && !value.contains('not ambassador'));
      }

      bool matchList(Object? raw) {
        if (raw is! List) return false;
        for (final item in raw) {
          if (matchStatus(item)) return true;
        }
        return false;
      }

      final ascension = parseMap(data['ascension']);
      final profile = parseMap(data['profile']);
      final basic = parseMap(data['basic']);
      final client = parseMap(data['client']);
      final profileAscension = parseMap(profile['ascension']);
      final basicAscension = parseMap(basic['ascension']);
      final clientAscension = parseMap(client['ascension']);

      for (final raw in <Object?>[
        data['status'],
        data['partnerStatus'],
        data['tier'],
        profile['status'],
        profile['partnerStatus'],
        profile['tier'],
        basic['status'],
        basic['partnerStatus'],
        basic['tier'],
        client['status'],
        client['partnerStatus'],
        client['tier'],
        ascension['status'],
        ascension['partnerStatus'],
        ascension['tier'],
        profileAscension['status'],
        profileAscension['partnerStatus'],
        profileAscension['tier'],
        basicAscension['status'],
        basicAscension['partnerStatus'],
        basicAscension['tier'],
        clientAscension['status'],
        clientAscension['partnerStatus'],
        clientAscension['tier'],
      ]) {
        if (matchStatus(raw)) return true;
      }

      for (final raw in <Object?>[
        data['tags'],
        data['accountTags'],
        profile['tags'],
        profile['accountTags'],
        basic['tags'],
        basic['accountTags'],
        client['tags'],
        client['accountTags'],
        ascension['tags'],
        profileAscension['tags'],
        basicAscension['tags'],
        clientAscension['tags'],
      ]) {
        if (matchList(raw)) return true;
      }

      return false;
    }

    for (final collection in const <String>['artist', 'client_artist']) {
      try {
        final row = await Supabase.instance.client
            .from(collection)
            .select()
            .eq('email', email)
            .maybeSingle();
        if (row != null) {
          final artistData = Map<String, dynamic>.from(row);
          _currentArtistNameLower = readName(artistData);
          _currentArtistIsLicensed = readIsLicensed(artistData);
          _currentArtistBrandEligible = readBrandEligibility(artistData);
          _currentArtistAcceptsNfc = readAcceptsNfc(artistData);
          _currentClientAmbassadorEligible = readAmbassadorEligibility(
            artistData,
          );
          unawaited(
            _syncAscensionForArtistDoc(
              artistEmail: email,
              artistCollection: collection,
              currentData: artistData,
            ),
          );
          break;
        }
      } catch (_) {}
    }
    if (mounted) {
      await _loadRequestsFromDb();
    }
  }

  Future<void> _syncAscensionForArtistDoc({
    required String artistEmail,
    required String artistCollection,
    required Map<String, dynamic> currentData,
  }) async {
    try {
      final previousPointsRaw =
          (currentData['ascension'] as Map<String, dynamic>?)?['points'];
      final previousPoints = previousPointsRaw is num
          ? previousPointsRaw.toDouble()
          : double.tryParse((previousPointsRaw ?? '').toString()) ?? 0;
      final portfolioUploads =
          (currentData['portfolioItems'] as List<dynamic>?)?.length ??
          (currentData['portfolioImages'] as List<dynamic>?)?.length ??
          0;
      final snapshot = await AscensionService.calculateForArtist(
        artistEmail: artistEmail,
        portfolioUploads: portfolioUploads,
      );
      if (!mounted) return;
      setState(() {
        _currentArtistBrandEligible = snapshot.sponsorshipEligible;
      });
      final computedPayload = AscensionService.buildAscensionPayload(snapshot);
      final override = await AscensionService.readActiveOverride(
        artistDocPath: '$artistCollection/$artistEmail',
        artistEmail: artistEmail,
      );
      final finalPayload = AscensionService.applyOverrideToPayload(
        payload: computedPayload,
        override: override,
      );
      final stabilizedPayload = AscensionService.preserveExistingAdminOverride(
        payload: finalPayload,
        artistData: currentData,
      );
      final finalEligibility = stabilizedPayload['sponsorshipEligible'] == true;
      if (mounted) {
        setState(() {
          _currentArtistBrandEligible = finalEligibility;
        });
      }
      await AscensionService.persistAdminCollections(
        artistEmail: artistEmail,
        artistCollection: artistCollection,
        artistName: _currentArtistNameLower,
        ascensionPayload: stabilizedPayload,
        previousPoints: previousPoints,
      );
    } catch (_) {}
  }

  Future<void> _syncAscensionForCurrentArtist() async {
    final email = (Supabase.instance.client.auth.currentUser?.email ?? '')
        .trim()
        .toLowerCase();
    if (email.isEmpty) return;

    for (final collection in const <String>['artist', 'client_artist']) {
      try {
        final row = await Supabase.instance.client
            .from(collection)
            .select()
            .eq('email', email)
            .maybeSingle();
        if (row == null) continue;
        await _syncAscensionForArtistDoc(
          artistEmail: email,
          artistCollection: collection,
          currentData: Map<String, dynamic>.from(row),
        );
        return;
      } catch (_) {}
    }
  }

  void _listenClientRequestsRealtime() {
    _clientRequestsSub?.cancel();
    _companyRequestsSub?.cancel();
    _clientRequestsSub = SupabaseCompatDatabase.instance
        .collection('Client_Custom_Requests')
        .limit(_realtimeWatchLimitPerCollection)
        .snapshots()
        .listen((snapshot) {
          unawaited(_handlePaidStatusNotifications(snapshot));
          _loadRequestsFromDb();
        });
    _companyRequestsSub = SupabaseCompatDatabase.instance
        .collection('Company_Custom_Requests')
        .limit(_realtimeWatchLimitPerCollection)
        .snapshots()
        .listen((_) {
          _loadRequestsFromDb();
        });
  }

  Future<void> _handlePaidStatusNotifications(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    final artistEmail = (Supabase.instance.client.auth.currentUser?.email ?? '')
        .trim()
        .toLowerCase();
    if (artistEmail.isEmpty) return;

    for (final change in snapshot.docChanges) {
      if (change.type != DocumentChangeType.modified) continue;
      final data = change.doc.data() ?? <String, dynamic>{};

      final paymentStatus = ((data['paymentStatus'] ?? '') as Object)
          .toString()
          .trim()
          .toLowerCase();
      if (paymentStatus != 'paid') continue;
      final currentStatus = ((data['status'] ?? '') as Object)
          .toString()
          .trim()
          .toLowerCase();
      if (currentStatus != 'accepted') continue;

      final acceptedBy = ((data['acceptedByArtistEmail'] ?? '') as Object)
          .toString()
          .trim()
          .toLowerCase();
      if (acceptedBy != artistEmail) continue;

      if (data['paymentNotifiedArtist'] == true) continue;

      final docRef = change.doc.reference;
      final orderNumber = ((data['orderNumber'] ?? '') as Object).toString();

      await NotificationsService.createUserNotification(
        receiverEmail: artistEmail,
        title: 'Payment Done',
        body: orderNumber.trim().isEmpty
            ? 'Client completed payment for your accepted request.'
            : 'Payment completed for order $orderNumber.',
        type: 'payment_done',
        orderId: change.doc.id,
        orderNumber: orderNumber,
        sourceCollection: 'Client_Custom_Requests',
      );

      final batch = SupabaseCompatDatabase.instance.batch();
      batch.set(docRef, {
        'status': 'designing',
        'paymentNotifiedArtist': true,
        'paymentNotifiedArtistAt': SupabaseServerValue.serverNow(),
        'updatedAt': SupabaseServerValue.serverNow(),
      }, SetOptions(merge: true));
      batch.set(docRef.collection('details').doc('payload'), {
        'status': 'designing',
      }, SetOptions(merge: true));
      await batch.commit();
    }
  }

  bool _rowWasDeclinedByArtist(Map<String, dynamic> row, String artistEmail) {
    final email = artistEmail.trim().toLowerCase();
    if (email.isEmpty) return false;

    bool listContains(Object? raw) {
      if (raw is List) {
        return raw
            .map((e) => e.toString().trim().toLowerCase())
            .contains(email);
      }
      if (raw is String) {
        return raw
            .split(',')
            .map((e) => e.trim().toLowerCase())
            .contains(email);
      }
      return false;
    }

    String text(Object? value) => (value ?? '').toString().trim().toLowerCase();
    Map<String, dynamic> asMap(Object? value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        return value.map((k, v) => MapEntry(k.toString(), v));
      }
      return const <String, dynamic>{};
    }

    final data = asMap(row['data']);
    final artistDecline = asMap(data['artistDecline']);
    final roleStatuses = asMap(data['roleStatuses']);

    final acceptedBy = text(row['accepted_by_artist_email']);

    // If the current artist is now the accepted artist, do not treat an old
    // direct-artist decline/release-to-pool marker as a decline for this artist.
    // This happens when the originally selected artist declines, the request is
    // released to the artist pool, and a different pool artist accepts it.
    if (acceptedBy == email) {
      return false;
    }

    if (listContains(row['declined_by_artist_emails']) ||
        listContains(data['declinedByArtistEmails']) ||
        listContains(data['declined_by_artist_emails'])) {
      return true;
    }

    final declinedBy = <String>[
      text(row['declined_by_artist_email']),
      text(data['declinedByArtistEmail']),
      text(data['declined_by_artist_email']),
      text(artistDecline['artistEmail']),
      text(artistDecline['artist_email']),
    ].where((e) => e.isNotEmpty).toSet();
    if (declinedBy.contains(email)) return true;

    final selectedArtist = text(row['selected_artist_email']);
    final selectedArtistData = text(data['selectedArtistEmail']);
    final assignedToCurrent =
        acceptedBy == email ||
        selectedArtist == email ||
        selectedArtistData == email;

    final rootStatusDeclined =
        text(row['status']) == 'declined' ||
        text(row['artist_status']) == 'declined' ||
        text(row['direct_artist_status']) == 'declined' ||
        text(row['artist_pool_status']) == 'declined';
    final dataStatusDeclined =
        text(data['status']) == 'declined' ||
        text(data['artistStatus']) == 'declined' ||
        text(data['artist_status']) == 'declined' ||
        text(data['directArtistStatus']) == 'declined' ||
        text(data['direct_artist_status']) == 'declined' ||
        text(roleStatuses['artist']) == 'declined';

    return assignedToCurrent && (rootStatusDeclined || dataStatusDeclined);
  }

  RequestStatusV2? _statusFromRootColumns(Map<String, dynamic> row) {
    String norm(Object? value) =>
        (value ?? '').toString().trim().toLowerCase().replaceAll(' ', '_');

    final values = <String>[
      norm(row['artist_status']),
      norm(row['status']),
    ].where((v) => v.isNotEmpty).toList(growable: false);

    bool has(String value) => values.contains(value);

    if (has('declined')) return RequestStatusV2.declined;
    if (has('cancelled') || has('canceled')) return RequestStatusV2.cancelled;
    if (has('expired')) return RequestStatusV2.expired;
    if (has('delivered')) return RequestStatusV2.delivered;
    if (has('shipped')) return RequestStatusV2.shipped;
    if (has('completed') || has('complete')) return RequestStatusV2.completed;
    if (has('designing') || has('in_progress') || has('inprogress')) {
      return RequestStatusV2.designing;
    }
    if (has('accepted')) return RequestStatusV2.accepted;
    if (has('in_review') || has('inreview') || has('pending')) {
      return RequestStatusV2.inReview;
    }
    return null;
  }

  Future<List<ClientRequestV2>> _applyRootStatusOverrides(
    List<ClientRequestV2> requests,
  ) async {
    if (requests.isEmpty) return requests;

    final byId = <String, RequestStatusV2>{};
    final byOrderNumber = <String, RequestStatusV2>{};

    void addRow(Map<String, dynamic> row) {
      final status = _statusFromRootColumns(row);
      if (status == null) return;
      final id = (row['id'] ?? '').toString().trim();
      final orderNumber = (row['order_number'] ?? '').toString().trim();
      final requestNumber = (row['request_number'] ?? '').toString().trim();
      if (id.isNotEmpty) byId[id] = status;
      if (orderNumber.isNotEmpty) byOrderNumber[orderNumber] = status;
      if (requestNumber.isNotEmpty) byOrderNumber[requestNumber] = status;
    }

    Future<void> scan(String table) async {
      try {
        final rows = await Supabase.instance.client
            .from(table)
            .select(
              'id,order_number,request_number,status,artist_status,updated_at',
            )
            .order('updated_at', ascending: false)
            .limit(500);
        for (final raw in rows.whereType<Map>()) {
          addRow(Map<String, dynamic>.from(raw));
        }
      } catch (_) {}
    }

    await scan('client_custom_requests');
    await scan('company_custom_requests');

    return requests
        .map((request) {
          final rootStatus =
              byId[request.id] ?? byOrderNumber[request.orderNumber];
          if (rootStatus == null || rootStatus == request.status)
            return request;
          return request.copyWith(status: rootStatus);
        })
        .toList(growable: false);
  }

  Future<Set<String>> _fetchPersistedArtistDeclinedRequestIds(
    String artistEmail,
  ) async {
    final email = artistEmail.trim().toLowerCase();
    if (email.isEmpty) return <String>{};
    final ids = <String>{};

    Future<void> scanTable(String table) async {
      try {
        final rows = await Supabase.instance.client
            .from(table)
            .select(
              'id,status,artist_status,direct_artist_status,artist_pool_status,accepted_by_artist_email,selected_artist_email,declined_by_artist_email,declined_by_artist_emails,data,updated_at',
            )
            .order('updated_at', ascending: false)
            .limit(1000);
        for (final raw in rows.whereType<Map>()) {
          final row = Map<String, dynamic>.from(raw);
          final id = (row['id'] ?? '').toString().trim();
          if (id.isEmpty) continue;
          if (_rowWasDeclinedByArtist(row, email)) ids.add(id);
        }
      } catch (_) {
        try {
          final rows = await Supabase.instance.client
              .from(table)
              .select(
                'id,status,artist_status,accepted_by_artist_email,selected_artist_email,data,updated_at',
              )
              .order('updated_at', ascending: false)
              .limit(1000);
          for (final raw in rows.whereType<Map>()) {
            final row = Map<String, dynamic>.from(raw);
            final id = (row['id'] ?? '').toString().trim();
            if (id.isEmpty) continue;
            if (_rowWasDeclinedByArtist(row, email)) ids.add(id);
          }
        } catch (_) {}
      }
    }

    await scanTable('client_custom_requests');
    await scanTable('company_custom_requests');
    return ids;
  }

  Future<void> _loadRequestsFromDb() async {
    if (_loadRequestsInFlight) return;
    _loadRequestsInFlight = true;
    if (!_realtimeBound) {
      _listenClientRequestsRealtime();
      _realtimeBound = true;
    }
    if (mounted && !_isLoadingDb) {
      setState(() => _isLoadingDb = true);
    }
    try {
      final dbRequests = await ArtistRequestsRepository.fetchActiveRequests();
      final rootStatusCorrectedRequests = await _applyRootStatusOverrides(
        dbRequests,
      );
      final hydratedRequests = await _expireCompanyPoolRequestsIfNeeded(
        rootStatusCorrectedRequests,
      );
      final currentArtistEmail =
          (Supabase.instance.client.auth.currentUser?.email ?? '')
              .trim()
              .toLowerCase();
      final currentClientEmail =
          (Supabase.instance.client.auth.currentUser?.email ?? '')
              .trim()
              .toLowerCase();
      final persistedDeclinedIds =
          await _fetchPersistedArtistDeclinedRequestIds(currentArtistEmail);
      if (!mounted) return;

      setState(() {
        _persistedArtistDeclinedRequestIds
          ..clear()
          ..addAll(persistedDeclinedIds);
        _all
          ..clear()
          ..addAll(
            hydratedRequests.where((r) {
              if (_locallyDeclinedRequestIds.contains(r.id)) return false;
              if (_persistedArtistDeclinedRequestIds.contains(r.id))
                return false;
              if (widget.showOnlyCompanyRequests &&
                  r.sourceCollection != 'Company_Custom_Requests') {
                return false;
              }
              if (widget.showOnlyCurrentClientRequests) {
                return _isVisibleToCurrentClient(
                  request: r,
                  clientEmail: currentClientEmail,
                );
              }
              if (widget.showOnlyCompanyRequests) {
                return _isVisibleInCompanyClientPool(
                  request: r,
                  clientEmail: currentClientEmail,
                );
              }
              if (widget.clientArtistMenuStyle &&
                  r.sourceCollection == 'Company_Custom_Requests') {
                final acceptedByClient = r.acceptedByClientEmail
                    .trim()
                    .toLowerCase();
                if (widget.includeClientArtistBrandRequestsInRequestTab &&
                    _currentClientAmbassadorEligible &&
                    acceptedByClient.isNotEmpty &&
                    acceptedByClient == currentClientEmail) {
                  return true;
                }
              }
              return _isVisibleToArtist(
                request: r,
                artistEmail: currentArtistEmail,
              );
            }),
          );
        _isLoadingDb = false;
        _hasLoadedRequests = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingDb = false);
    } finally {
      _loadRequestsInFlight = false;
    }
  }

  Future<List<ClientRequestV2>> _expireCompanyPoolRequestsIfNeeded(
    List<ClientRequestV2> requests,
  ) async {
    final now = DateTime.now();
    final updated = <ClientRequestV2>[];

    for (final request in requests) {
      final shouldExpire =
          request.sourceCollection == 'Company_Custom_Requests' &&
          request.acceptedByArtistEmail.trim().isEmpty &&
          request.status != RequestStatusV2.expired &&
          request.status != RequestStatusV2.cancelled &&
          request.status != RequestStatusV2.declined &&
          request.status != RequestStatusV2.delivered &&
          request.status != RequestStatusV2.shipped &&
          now.isAfter(
            DateTime(
              request.neededBy.year,
              request.neededBy.month,
              request.neededBy.day,
            ).add(const Duration(days: 1)),
          );

      if (!shouldExpire) {
        updated.add(request);
        continue;
      }

      try {
        final docRef = SupabaseCompatDatabase.instance
            .collection(request.sourceCollection)
            .doc(request.id);
        final batch = SupabaseCompatDatabase.instance.batch();
        batch.set(docRef, {
          'status': 'expired',
          'expiredAt': SupabaseServerValue.serverNow(),
          'updatedAt': SupabaseServerValue.serverNow(),
        }, SetOptions(merge: true));
        batch.set(docRef.collection('details').doc('payload'), {
          'status': 'expired',
          'expiredAt': SupabaseServerValue.serverNow(),
        }, SetOptions(merge: true));
        await batch.commit();
        updated.add(request.copyWith(status: RequestStatusV2.expired));
      } catch (_) {
        updated.add(request);
      }
    }

    return updated;
  }

  @override
  void dispose() {
    _closeDropdown();
    _clientRequestsSub?.cancel();
    _companyRequestsSub?.cancel();
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    _budgetMinCtrl.dispose();
    _budgetMaxCtrl.dispose();
    super.dispose();
  }

  bool _isVisibleToArtist({
    required ClientRequestV2 request,
    required String artistEmail,
  }) {
    if (_locallyDeclinedRequestIds.contains(request.id)) return false;
    if (_persistedArtistDeclinedRequestIds.contains(request.id)) return false;
    if (_isClientArtistViewingOwnRequest(
      request: request,
      viewerEmail: artistEmail,
    )) {
      return false;
    }
    final isCompanyRequest =
        request.sourceCollection == 'Company_Custom_Requests';
    final hasClientAccepted = request.acceptedByClientEmail.trim().isNotEmpty;
    if (isCompanyRequest &&
        !shouldShowScenario41ToDirectArtist(
          clientAccepted: hasClientAccepted,
          isDirectRequest: request.isDirectRequest,
          selectedArtistEmail: request.selectedArtistEmail,
          acceptedByArtistEmail: request.acceptedByArtistEmail,
          viewerArtistEmail: artistEmail,
        )) {
      return false;
    }
    if (isCompanyRequest &&
        request.status == RequestStatusV2.inReview &&
        !_currentArtistBrandEligible) {
      return false;
    }

    final ownedBy = request.acceptedByArtistEmail.trim().toLowerCase();
    final isOwnedByCurrentArtist =
        artistEmail.isNotEmpty && ownedBy == artistEmail;
    if (request.nfcRequested &&
        !_currentArtistAcceptsNfc &&
        !isOwnedByCurrentArtist) {
      return false;
    }
    final declinedByCurrentArtist =
        artistEmail.isNotEmpty &&
        request.declinedByArtistEmails.contains(artistEmail);

    bool matchesSelectedArtistName() {
      final selected = request.selectedArtist.trim().toLowerCase();
      if (selected.isEmpty) return false;
      return selected == _currentArtistNameLower ||
          selected == _currentArtistDisplayNameLower ||
          selected == _currentArtistEmailLocalLower;
    }

    bool isCurrentArtistDirectTarget() {
      final directTargetEmail = request.selectedArtistEmail
          .trim()
          .toLowerCase();
      if (directTargetEmail.isNotEmpty && artistEmail.isNotEmpty) {
        return directTargetEmail == artistEmail;
      }
      return matchesSelectedArtistName();
    }

    switch (request.status) {
      case RequestStatusV2.inReview:
        final isBrandGroupOrder =
            request.sourceCollection == 'Company_Custom_Requests' &&
            request.orderType == RequestOrderTypeV2.group;
        if (isBrandGroupOrder && !request.groupClientsAllResponded) {
          return false;
        }
        if (!request.allowNonLicensed && !_currentArtistIsLicensed) {
          return false;
        }
        final hiddenByDirectTarget =
            request.isDirectRequest && !isCurrentArtistDirectTarget();
        return !declinedByCurrentArtist && !hiddenByDirectTarget;
      case RequestStatusV2.accepted:
      case RequestStatusV2.designing:
      case RequestStatusV2.completed:
      case RequestStatusV2.shipped:
      case RequestStatusV2.delivered:
        return ownedBy.isEmpty || isOwnedByCurrentArtist;
      case RequestStatusV2.declined:
      case RequestStatusV2.cancelled:
      case RequestStatusV2.expired:
        return ownedBy.isEmpty || isOwnedByCurrentArtist;
    }
  }

  bool _isClientArtistViewingOwnRequest({
    required ClientRequestV2 request,
    required String viewerEmail,
  }) {
    if (!widget.clientArtistMenuStyle) return false;
    final normalizedViewer = viewerEmail.trim().toLowerCase();
    if (normalizedViewer.isEmpty) return false;

    final requestClientEmail = request.clientEmail.trim().toLowerCase();
    final selectedClientEmail = request.selectedClientEmail
        .trim()
        .toLowerCase();
    final acceptedByClientEmail = request.acceptedByClientEmail
        .trim()
        .toLowerCase();
    final selectedGroupClientEmails = request.selectedGroupClientEmails
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    final acceptedGroupClientEmails = request.acceptedGroupClientEmails
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    final groupClientEmails = request.groupClients
        .map((client) => client.clientEmail.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();

    return requestClientEmail == normalizedViewer ||
        selectedClientEmail == normalizedViewer ||
        acceptedByClientEmail == normalizedViewer ||
        selectedGroupClientEmails.contains(normalizedViewer) ||
        acceptedGroupClientEmails.contains(normalizedViewer) ||
        groupClientEmails.contains(normalizedViewer);
  }

  bool _isVisibleToCurrentClient({
    required ClientRequestV2 request,
    required String clientEmail,
  }) {
    final email = clientEmail.trim().toLowerCase();
    if (email.isEmpty) return false;
    return request.clientEmail.trim().toLowerCase() == email;
  }

  bool _isVisibleInCompanyClientPool({
    required ClientRequestV2 request,
    required String clientEmail,
  }) {
    final viewerEmail = clientEmail.trim().toLowerCase();
    final acceptedByClient = request.acceptedByClientEmail.trim().toLowerCase();
    final declinedByClient = request.declinedByClientEmails
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    final selectedClientEmail = request.selectedClientEmail
        .trim()
        .toLowerCase();
    final selectedGroupClientEmails = request.selectedGroupClientEmails
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    final isPoolOpen = request.openToClientPool;

    // Once accepted by any client, it should move to Orders and leave Requests.
    if (acceptedByClient.isNotEmpty) return false;

    if (!isPoolOpen) {
      if (viewerEmail.isEmpty) return false;
      if (request.orderType == RequestOrderTypeV2.group) {
        return selectedGroupClientEmails.contains(viewerEmail);
      }
      if (selectedClientEmail.isEmpty) return false;
      return selectedClientEmail == viewerEmail;
    }

    if (request.status == RequestStatusV2.inReview) {
      if (declinedByClient.contains(viewerEmail)) return false;
      return true;
    }
    return false;
  }

  // ----------------------------
  // Filtering + sorting
  // ----------------------------
  List<ClientRequestV2> _filteredForTab(int tabIndex) {
    bool isActiveTab(ClientRequestV2 r) {
      // ✅ ALL = everything EXCEPT Delivered/Declined/Expired/Cancelled
      if (tabIndex == 0) {
        return r.status != RequestStatusV2.delivered &&
            r.status != RequestStatusV2.declined &&
            r.status != RequestStatusV2.expired &&
            r.status != RequestStatusV2.cancelled;
      }

      // ✅ Other tabs
      if (tabIndex == 1) return r.status == RequestStatusV2.inReview;
      if (tabIndex == 2) {
        return r.status == RequestStatusV2.designing ||
            r.status == RequestStatusV2.accepted;
      }
      if (tabIndex == 3) return r.status == RequestStatusV2.completed;
      if (tabIndex == 4) return r.status == RequestStatusV2.shipped;

      return false;
    }

    final list = _all.where(isActiveTab).where(_applySharedFilters).toList();

    // Sort
    if (_sort == 'Newest') {
      list.sort((a, b) => b.neededBy.compareTo(a.neededBy));
    } else if (_sort == 'Soonest needed') {
      list.sort((a, b) => a.neededBy.compareTo(b.neededBy));
    } else if (_sort == 'Higher budget') {
      list.sort((a, b) => b.budgetMax.compareTo(a.budgetMax));
    }

    return list;
  }

  // ----------------------------
  // Shipping estimator (stub)
  // Replace this with real geo logic later:
  // - distance between artist and client
  // - carrier SLA based on distance
  // ----------------------------
  int _estimateShipDays({
    required String artistLocation,
    required String clientLocation,
  }) {
    // Very small heuristic just to behave realistically:
    final a = artistLocation.toLowerCase();
    final c = clientLocation.toLowerCase();

    // same state-ish hint => faster
    if ((a.contains('ca') && c.contains('ca')) ||
        (a.contains('los') && c.contains('san'))) {
      return 2;
    }
    // nearby southwest-ish
    if ((a.contains('ca') && (c.contains('az') || c.contains('nv')))) {
      return 3;
    }
    return 5;
  }

  // ----------------------------
  // Header actions (same as others)
  // ----------------------------
  void _openNotifications() {
    if (widget.onOpenNotifications != null) {
      widget.onOpenNotifications!.call();
      return;
    }
    NotificationsPage.showAsModal(context);
  }

  void _openManageProfile() {
    if (widget.onManageProfile != null) {
      widget.onManageProfile!.call();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const ArtistProfilePage(showBottomNav: true, bottomNavIndex: 1),
      ),
    );
  }

  void _openHistory() {
    if (widget.onOpenHistory != null) {
      widget.onOpenHistory!.call();
    }
  }

  void _openCalendar() {
    if (widget.onOpenCalendar != null) {
      widget.onOpenCalendar!.call();
    }
  }

  void _openArtist() {
    if (widget.onOpenArtist != null) {
      widget.onOpenArtist!.call();
    }
  }

  void _openReviews() {
    if (widget.onOpenReviews != null) {
      widget.onOpenReviews!.call();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ArtistReviewsPage()),
    );
  }

  Future<void> _signOut() async {
    if (widget.onSignOut != null) {
      widget.onSignOut!.call();
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  Widget _avatarMenu() {
    return PopupMenuButton<_HeaderAvatarAction>(
      tooltip: 'Account menu',
      position: PopupMenuPosition.under,
      elevation: 12,
      color: AppColors.snow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      onSelected: (v) {
        switch (v) {
          case _HeaderAvatarAction.profile:
            _openManageProfile();
            break;
          case _HeaderAvatarAction.history:
            _openHistory();
            break;
          case _HeaderAvatarAction.calendar:
            _openCalendar();
            break;
          case _HeaderAvatarAction.artist:
            _openArtist();
            break;
          case _HeaderAvatarAction.earnings:
            widget.onOpenEarnings?.call();
            break;
          case _HeaderAvatarAction.reviews:
            _openReviews();
            break;
          case _HeaderAvatarAction.signOut:
            _signOut();
            break;
        }
      },
      child: SizedBox(
        height: JntHeaderMetrics.avatarSize,
        width: JntHeaderMetrics.avatarSize,
        child: ClipRRect(
          borderRadius: BorderRadius.zero,
          child: const ArtistProfileAvatarIcon(
            size: JntHeaderMetrics.avatarSize,
          ),
        ),
      ),
      itemBuilder: (_) => [
        if (widget.clientArtistMenuStyle || widget.showProfileMenuItem)
          const PopupMenuItem(
            value: _HeaderAvatarAction.profile,
            child: _HeaderMenuRow(icon: Icons.person_outline, label: 'Profile'),
          ),
        if (widget.clientArtistMenuStyle)
          const PopupMenuItem(
            value: _HeaderAvatarAction.history,
            child: _HeaderMenuRow(icon: Icons.history, label: 'History'),
          ),
        if (widget.clientArtistMenuStyle)
          const PopupMenuItem(
            value: _HeaderAvatarAction.calendar,
            child: _HeaderMenuRow(
              icon: Icons.calendar_month_outlined,
              label: 'Calendar',
            ),
          ),
        if (widget.clientArtistMenuStyle)
          const PopupMenuItem(
            value: _HeaderAvatarAction.artist,
            child: _HeaderMenuRow(icon: Icons.brush_outlined, label: 'Artist'),
          ),
        if (widget.clientArtistMenuStyle && widget.onOpenEarnings != null)
          const PopupMenuItem(
            value: _HeaderAvatarAction.earnings,
            child: _HeaderMenuRow(
              icon: Icons.attach_money_outlined,
              label: 'Earnings',
            ),
          ),
        const PopupMenuItem(
          value: _HeaderAvatarAction.reviews,
          child: _HeaderMenuRow(
            icon: Icons.star_outline_rounded,
            label: 'Reviews',
          ),
        ),
        if (widget.clientArtistMenuStyle || widget.showProfileMenuItem)
          const PopupMenuDivider(),
        PopupMenuItem(
          value: _HeaderAvatarAction.signOut,
          child: _HeaderMenuRow(
            icon: Icons.logout_rounded,
            label: 'Logout',
            color: widget.clientArtistMenuStyle ? AppColors.blackCat : null,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: 'Artist requests',
      child: Scaffold(
      backgroundColor: AppColors.snow,

      // HEADER (same style as your other pages)
      appBar: JntStandardAppBar(
        onNotifications: _openNotifications,
        trailing: _avatarMenu(),
      ),

      body: Column(
        children: [
          // Top controls area
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Column(
              children: [
                if (!widget.showOnlyCompanyRequests) _searchWithFilterButton(),
                if (!widget.showOnlyCompanyRequests) ...[
                  const SizedBox(height: 12),
                  // Status tabs
                  _statusTabs(),
                ],
              ],
            ),
          ),

          if (widget.showOnlyCompanyRequests)
            Expanded(child: _tabList(0))
          else
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                // OLD
                // children: List.generate(8, (i) => _tabList(i)),

                // NEW
                children: List.generate(5, (i) => _tabList(i)),
              ),
            ),
        ],
      ),
      bottomNavigationBar: widget.showBottomNav
          ? BottomNavigationBar(
              currentIndex: widget.bottomNavIndex,
              selectedItemColor: AppColors.blackCat,
              unselectedItemColor: AppColors.blackCat.withValues(alpha: 0.35),
              type: BottomNavigationBarType.fixed,
              onTap: (i) {
                if (widget.onNavTap != null) {
                  widget.onNavTap!(i);
                  return;
                }
                if (i != widget.bottomNavIndex) {
                  Navigator.pop(context);
                }
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_filled),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.add_circle_outline),
                  label: 'Design',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.inbox_outlined),
                  label: 'Requests',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_month_outlined),
                  label: 'Calendar',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.history),
                  label: 'History',
                ),
              ],
            )
          : null,
    ),
    );
  }

  // ----------------------------
  // UI components
  // ----------------------------
  Widget _searchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.blackCat.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        style: _t(
          13,
          w: FontWeight.w800,
          c: AppColors.blackCat.withValues(alpha: 0.9),
        ),
        controller: _searchCtrl,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Search by client, title, ID',
          hintStyle: _t(
            12,
            w: FontWeight.w400,
            c: AppColors.blackCat.withValues(alpha: 0.45),
          ),
          prefixIcon: Icon(
            Icons.search,
            color: AppColors.blackCat.withValues(alpha: 0.45),
            size: 18,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ), // was 14
        ),
      ),
    );
  }

  Widget _searchWithFilterButton() {
    return Row(
      children: [
        Expanded(child: _searchBar()),
        const SizedBox(width: 10),
        Semantics(
          button: true,
          label: _hasActiveFilters ? 'Filters, active' : 'Filters',
          onTap: _openFiltersModal,
          child: ExcludeSemantics(
            child: InkWell(
          borderRadius: BorderRadius.zero,
          onTap: _openFiltersModal,
          child: Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: _hasActiveFilters
                  ? AppColors.alabaster.withValues(alpha: 0.75)
                  : AppColors.snow,
              borderRadius: BorderRadius.zero,
              border: Border.all(color: AppColors.blackCatBorderLight),
              boxShadow: [
                BoxShadow(
                  color: AppColors.blackCat.withValues(alpha: 0.03),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.filter_alt_outlined,
                  size: 20,
                  color: AppColors.blackCat.withValues(alpha: 0.75),
                ),
                if (_hasActiveFilters)
                  Positioned(
                    top: 9,
                    right: 9,
                    child: Container(
                      height: 7,
                      width: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.blackCat,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openFiltersModal() async {
    bool directOnly = _directOnly;
    bool groupOnly = _groupOnly;
    RangeValues budgetRange = _budgetRange;
    String sort = _sort;
    final minCtrl = TextEditingController(
      text: budgetRange.start.round().toString(),
    );
    final maxCtrl = TextEditingController(
      text: budgetRange.end.round().toString(),
    );

    RangeValues normalizedBudgetFromText() {
      final min =
          int.tryParse(minCtrl.text.trim()) ?? budgetRange.start.round();
      final max = int.tryParse(maxCtrl.text.trim()) ?? budgetRange.end.round();
      final clampedMin = min.clamp(15, 5000);
      final clampedMax = max.clamp(15, 5000);
      final start = clampedMin <= clampedMax ? clampedMin : clampedMax;
      final end = clampedMin <= clampedMax ? clampedMax : clampedMin;
      return RangeValues(start.toDouble(), end.toDouble());
    }

    void applyTextBudget(StateSetter setModalState) {
      final next = normalizedBudgetFromText();
      setModalState(() {
        budgetRange = next;
      });
    }

    final result = await showDialog<_RequestFilterResult>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: AppColors.snow,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          child: StatefulBuilder(
            builder: (modalContext, setModalState) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.filter_alt_outlined,
                          size: 18,
                          color: AppColors.blackCat,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Filter',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.blackCat,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          color: AppColors.blackCat,
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _filterChip(
                            label: 'Direct Request',
                            icon: Icons.verified_user_outlined,
                            selected: directOnly,
                            onTap: () =>
                                setModalState(() => directOnly = !directOnly),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _filterChip(
                            label: 'Group Order',
                            icon: Icons.attach_file_rounded,
                            selected: groupOnly,
                            onTap: () =>
                                setModalState(() => groupOnly = !groupOnly),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Budget',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.blackCat.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minCtrl,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            style: const TextStyle(
                              color: AppColors.blackCat,
                              fontWeight: FontWeight.w700,
                            ),
                            cursorColor: AppColors.blackCat,
                            decoration: _miniDec(prefix: '\$', hint: 'Min'),
                            onSubmitted: (_) => applyTextBudget(setModalState),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: maxCtrl,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            style: const TextStyle(
                              color: AppColors.blackCat,
                              fontWeight: FontWeight.w700,
                            ),
                            cursorColor: AppColors.blackCat,
                            decoration: _miniDec(prefix: '\$', hint: 'Max'),
                            onSubmitted: (_) => applyTextBudget(setModalState),
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(modalContext).copyWith(
                        activeTrackColor: AppColors.blackCat,
                        inactiveTrackColor: AppColors.blackCat.withValues(
                          alpha: 0.18,
                        ),
                        thumbColor: AppColors.blackCat,
                        overlayColor: Colors.transparent,
                        rangeThumbShape: const RoundRangeSliderThumbShape(
                          enabledThumbRadius: 8,
                        ),
                        valueIndicatorColor: AppColors.blackCat,
                        valueIndicatorTextStyle: const TextStyle(
                          color: AppColors.snow,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: RangeSlider(
                        values: budgetRange,
                        min: 15,
                        max: 5000,
                        divisions: 4985,
                        labels: RangeLabels(
                          '\$${budgetRange.start.round()}',
                          '\$${budgetRange.end.round()}',
                        ),
                        onChanged: (v) {
                          minCtrl.text = v.start.round().toString();
                          maxCtrl.text = v.end.round().toString();
                          setModalState(() {
                            budgetRange = v;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Sort',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.blackCat.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.snow,
                        borderRadius: BorderRadius.zero,
                        border: Border.all(
                          color: AppColors.blackCatBorderLight,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: sort,
                          dropdownColor: AppColors.snow,
                          style: TextStyle(
                            color: AppColors.blackCat,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.blackCat.withValues(alpha: 0.7),
                          ),
                          isExpanded: true,
                          items: [
                            DropdownMenuItem(
                              value: 'Newest',
                              child: Text(
                                'Sort: Newest',
                                style: TextStyle(color: AppColors.blackCat),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Soonest needed',
                              child: Text(
                                'Sort: Soonest needed',
                                style: TextStyle(color: AppColors.blackCat),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Higher budget',
                              child: Text(
                                'Sort: Higher budget',
                                style: TextStyle(color: AppColors.blackCat),
                              ),
                            ),
                          ],
                          onChanged: (v) =>
                              setModalState(() => sort = v ?? 'Newest'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.blackCat.withValues(
                                alpha: 0.16,
                              ),
                              foregroundColor: AppColors.blackCat,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                              side: const BorderSide(
                                color: AppColors.blackCatBorderLight,
                              ),
                              elevation: 0,
                            ),
                            onPressed: () {
                              final minPreset = widget.initialBudgetMin.clamp(
                                15,
                                5000,
                              );
                              final maxPreset = widget.initialBudgetMax.clamp(
                                15,
                                5000,
                              );
                              final start = minPreset <= maxPreset
                                  ? minPreset
                                  : maxPreset;
                              final end = minPreset <= maxPreset
                                  ? maxPreset
                                  : minPreset;
                              minCtrl.text = start.toString();
                              maxCtrl.text = end.toString();
                              setModalState(() {
                                directOnly = false;
                                groupOnly = false;
                                sort = 'Newest';
                                budgetRange = RangeValues(
                                  start.toDouble(),
                                  end.toDouble(),
                                );
                              });
                            },
                            child: const Text(
                              'Clear',
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                fontFamily: 'Arial',
                              ),
                            ),
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
                            child: const Text('Apply'),
                            onPressed: () {
                              final normalized = normalizedBudgetFromText();
                              Navigator.pop(
                                dialogContext,
                                _RequestFilterResult(
                                  directOnly: directOnly,
                                  groupOnly: groupOnly,
                                  sort: sort,
                                  budgetRange: normalized,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    minCtrl.dispose();
    maxCtrl.dispose();

    if (result == null || !mounted) return;
    setState(() {
      _directOnly = result.directOnly;
      _groupOnly = result.groupOnly;
      _sort = result.sort;
      _budgetRange = result.budgetRange;
      _budgetMinCtrl.text = result.budgetRange.start.round().toString();
      _budgetMaxCtrl.text = result.budgetRange.end.round().toString();
    });
  }

  Widget _filterChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      child: ExcludeSemantics(
      child: InkWell(
      borderRadius: BorderRadius.zero,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.alabaster.withValues(alpha: 0.7)
              : AppColors.snow,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: AppColors.blackCatBorderLight),
          boxShadow: [
            BoxShadow(
              color: AppColors.blackCat.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.blackCat),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.blackCat,
              ),
            ),
          ],
        ),
      ),
      ),
      ),
    );
  }

  Widget _statusTab(String label, int count, bool isActive) {
    final s = _reqScale(context);

    final labelColor = AppColors.blackCat;

    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5 * s,
              color: labelColor,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12.5 * s,
              color: AppColors.blackCat,
            ),
          ),
        ],
      ),
    );
  }

  ClientRequestV2 _getById(String id) => _all.firstWhere((e) => e.id == id);

  void _replaceById(String id, ClientRequestV2 updated) {
    final i = _all.indexWhere((e) => e.id == id);
    if (i == -1) return;
    setState(() => _all[i] = updated);
  }

  Future<ClientRequestV2> _hydrateRequestForDetails(
    ClientRequestV2 request,
  ) async {
    try {
      final hydrated = await ArtistRequestsRepository.fetchRequestById(
        sourceCollection: request.sourceCollection,
        requestId: request.id,
      );
      if (hydrated == null) return request;
      if (mounted) _replaceById(request.id, hydrated);
      return hydrated;
    } catch (_) {
      return request;
    }
  }

  void _moveToStatus(String id, RequestStatusV2 status) {
    final r = _getById(id);
    _replaceById(id, r.copyWith(status: status));
  }

  Future<void> _forcePersistArtistAcceptedDesigning(
    ClientRequestV2 request,
    double normalizedTotal,
  ) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final artistEmail = (currentUser?.email ?? '').trim().toLowerCase();
    final artistName = (() {
      final displayName = (currentUser?.displayName ?? '').trim();
      if (displayName.isNotEmpty) return displayName;
      if (artistEmail.contains('@')) return artistEmail.split('@').first;
      return 'Artist';
    })();
    if (artistEmail.isEmpty) return;

    final table = _tableForCollection(request.sourceCollection);
    final orderRef = request.orderNumber.trim();
    final nowIso = DateTime.now().toUtc().toIso8601String();

    Map<String, dynamic> asMap(Object? value) {
      if (value is Map<String, dynamic>)
        return Map<String, dynamic>.from(value);
      if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
      return <String, dynamic>{};
    }

    bool asBool(Object? value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      final text = (value ?? '').toString().trim().toLowerCase();
      return text == 'true' || text == 'yes' || text == '1' || text == 'open';
    }

    String text(Object? value) => (value ?? '').toString().trim();

    Map<String, dynamic>? row;
    try {
      row = await Supabase.instance.client
          .from(table)
          .select()
          .eq('id', request.id)
          .maybeSingle();
      if (row == null && orderRef.isNotEmpty) {
        row = await Supabase.instance.client
            .from(table)
            .select()
            .or('order_number.eq.$orderRef,request_number.eq.$orderRef')
            .maybeSingle();
      }
    } catch (e) {
      debugPrint('[Artist Accept] Unable to reload row for status sync: $e');
    }

    final rowId = text(row?['id']).isNotEmpty ? text(row?['id']) : request.id;
    final details = asMap(row?['details']);
    final payload = asMap(row?['payload']);
    final requestDetails = asMap(row?['request_details']);
    final data = asMap(row?['data']);
    final detailsOrder = asMap(details['order']);
    final payloadOrder = asMap(payload['order']);
    final requestDetailsOrder = asMap(requestDetails['order']);
    final dataOrder = asMap(data['order']);

    final wasReleasedToPool =
        asBool(row?['open_to_artist_pool']) ||
        asBool(details['openToArtistPool']) ||
        asBool(detailsOrder['openToArtistPool']) ||
        asBool(payload['openToArtistPool']) ||
        asBool(payloadOrder['openToArtistPool']) ||
        asBool(requestDetails['openToArtistPool']) ||
        asBool(requestDetailsOrder['openToArtistPool']) ||
        text(row?['request_type']).toLowerCase() == 'standard' ||
        text(detailsOrder['artistPoolStatus']).toLowerCase() == 'open' ||
        text(detailsOrder['artistPoolStatus']).toLowerCase() == 'pending' ||
        text(payloadOrder['artistPoolStatus']).toLowerCase() == 'open' ||
        text(dataOrder['artistPoolStatus']).toLowerCase() == 'open';

    Map<String, dynamic> mergeRoleStatuses(Map<String, dynamic> source) {
      final roleStatuses = asMap(
        source['roleStatuses'] ?? source['role_statuses'],
      );
      return <String, dynamic>{
        ...source,
        'status': 'designing',
        'clientStatus': 'in_progress',
        'artistStatus': 'designing',
        'acceptedByArtistEmail': artistEmail,
        'acceptedByArtistName': artistName,
        'artistFinalAmount': normalizedTotal,
        'artistAcceptedAt': nowIso,
        'roleStatuses': <String, dynamic>{
          ...roleStatuses,
          'client': 'in_progress',
          'artist': 'designing',
        },
      };
    }

    Map<String, dynamic> mergeOrder(Map<String, dynamic> source) {
      return <String, dynamic>{
        ...source,
        'artistPoolStatus': 'accepted',
        'directArtistStatus': 'accepted',
        'openToArtistPool': false,
        'acceptedByArtistEmail': artistEmail,
        'acceptedByArtistName': artistName,
        'artistFinalAmount': normalizedTotal,
        'artistAcceptedAt': nowIso,
      };
    }

    final nextDetails = mergeRoleStatuses(details);
    nextDetails['order'] = mergeOrder(detailsOrder);
    nextDetails['acceptance'] = <String, dynamic>{
      ...asMap(nextDetails['acceptance']),
      'acceptedByArtistEmail': artistEmail,
      'acceptedByArtistName': artistName,
      'acceptedByArtistAt': nowIso,
    };

    final nextPayload = mergeRoleStatuses(payload);
    nextPayload['order'] = mergeOrder(payloadOrder);
    nextPayload['acceptance'] = <String, dynamic>{
      ...asMap(nextPayload['acceptance']),
      'acceptedByArtistEmail': artistEmail,
      'acceptedByArtistName': artistName,
      'acceptedByArtistAt': nowIso,
    };

    final nextRequestDetails = mergeRoleStatuses(requestDetails);
    nextRequestDetails['order'] = mergeOrder(requestDetailsOrder);

    final nextData = mergeRoleStatuses(data);
    nextData['order'] = mergeOrder(dataOrder);

    final commonRootUpdate = <String, dynamic>{
      'status': 'designing',
      'artist_status': 'designing',
      'client_status': 'in_progress',
      'accepted_by_artist_email': artistEmail,
      'accepted_by_artist_name': artistName,
      'artist_email': artistEmail,
      'artist_name': artistName,
      'artist_final_amount': normalizedTotal,
      'final_amount_by_artist': normalizedTotal,
      'direct_artist_status': wasReleasedToPool
          ? 'released_to_pool'
          : 'accepted',
      'artist_pool_status': 'accepted',
      'updated_at': nowIso,
      'details': nextDetails,
      if (payload.isNotEmpty || table == 'client_custom_requests')
        'payload': nextPayload,
      if (requestDetails.isNotEmpty || table == 'client_custom_requests')
        'request_details': nextRequestDetails,
      if (data.isNotEmpty || table == 'client_custom_requests')
        'data': nextData,
      if (wasReleasedToPool) 'request_type': 'Standard',
      if (wasReleasedToPool) 'open_to_artist_pool': false,
      if (wasReleasedToPool) 'is_direct_request': false,
    };

    Future<void> updateRoot(Map<String, dynamic> values) async {
      await Supabase.instance.client.from(table).update(values).eq('id', rowId);
    }

    try {
      await updateRoot(commonRootUpdate);
    } catch (e) {
      debugPrint('[Artist Accept] full root status sync failed: $e');
      final fallback = Map<String, dynamic>.from(commonRootUpdate)
        ..remove('open_to_artist_pool')
        ..remove('is_direct_request')
        ..remove('request_type')
        ..remove('payload')
        ..remove('request_details')
        ..remove('data');
      try {
        await updateRoot(fallback);
      } catch (e2) {
        debugPrint('[Artist Accept] fallback root status sync failed: $e2');
        await updateRoot(<String, dynamic>{
          'status': 'designing',
          'artist_status': 'designing',
          'client_status': 'in_progress',
          'accepted_by_artist_email': artistEmail,
          'accepted_by_artist_name': artistName,
          'artist_final_amount': normalizedTotal,
          'direct_artist_status': wasReleasedToPool
              ? 'released_to_pool'
              : 'accepted',
          'artist_pool_status': 'accepted',
          'updated_at': nowIso,
        });
      }
    }

    final detailTable = _detailsTableFor(table);
    try {
      await Supabase.instance.client.from(detailTable).upsert(<String, dynamic>{
        'id': '$rowId:payload',
        'request_id': rowId,
        'detail_key': 'payload',
        'data': nextDetails,
        'updated_at': nowIso,
      }, onConflict: 'id');
    } catch (e) {
      debugPrint('[Artist Accept] details status sync failed: $e');
    }
  }

  Future<bool> _persistArtistAcceptance(
    ClientRequestV2 request,
    _AcceptResult accepted,
  ) async {
    final total = accepted.yourPrice + accepted.shipping + accepted.extra;
    final normalizedTotal = double.parse(total.toStringAsFixed(2));

    try {
      await Supabase.instance.client.rpc(
        'artist_accept_request',
        params: <String, dynamic>{
          'p_request_id': request.id,
          'p_order_number': request.orderNumber.trim().isEmpty
              ? null
              : request.orderNumber.trim(),
          'p_artist_amount': normalizedTotal,
        },
      );

      await _forcePersistArtistAcceptedDesigning(request, normalizedTotal);

      try {
        final currentUser = Supabase.instance.client.auth.currentUser;
        final artistName = (() {
          final displayName = (currentUser?.displayName ?? '').trim();
          if (displayName.isNotEmpty) return displayName;
          final email = (currentUser?.email ?? '').trim();
          if (email.contains('@')) return email.split('@').first;
          return 'Your artist';
        })();
        final orderRef = request.orderNumber.trim().isNotEmpty
            ? request.orderNumber.trim()
            : request.id;
        final sourceCollection = request.sourceCollection.trim().isEmpty
            ? 'Client_Custom_Requests'
            : request.sourceCollection.trim();

        String normalizeEmail(Object? value) {
          final text = (value ?? '').toString().trim().toLowerCase();
          return text.contains('@') ? text : '';
        }

        String firstEmail(Iterable<Object?> values) {
          for (final value in values) {
            final normalized = normalizeEmail(value);
            if (normalized.isNotEmpty) return normalized;
          }
          return '';
        }

        String firstText(Iterable<Object?> values) {
          for (final value in values) {
            final text = (value ?? '').toString().trim();
            if (text.isNotEmpty) return text;
          }
          return '';
        }

        Map<String, dynamic> asMap(Object? value) {
          if (value is Map<String, dynamic>)
            return Map<String, dynamic>.from(value);
          if (value is Map) {
            return value.map(
              (key, mapValue) => MapEntry(key.toString(), mapValue),
            );
          }
          return <String, dynamic>{};
        }

        var notifyEmail = '';
        var notificationTitle = 'Request Accepted';
        var notificationBody =
            '$artistName accepted your request $orderRef. Final amount: \$${normalizedTotal.toStringAsFixed(2)}.';

        if (sourceCollection == 'Company_Custom_Requests') {
          Map<String, dynamic>? row;
          row = await Supabase.instance.client
              .from('company_custom_requests')
              .select('id,payload,details,order_number,request_number')
              .eq('id', request.id)
              .maybeSingle();
          if (row == null && request.orderNumber.trim().isNotEmpty) {
            row = await Supabase.instance.client
                .from('company_custom_requests')
                .select('id,payload,details,order_number,request_number')
                .or(
                  'order_number.eq.${request.orderNumber.trim()},request_number.eq.${request.orderNumber.trim()}',
                )
                .maybeSingle();
          }

          final payload = asMap(row?['payload']);
          final details = asMap(row?['details']);
          notifyEmail = firstEmail(<Object?>[
            payload['acceptedClientEmail'],
            details['acceptedClientEmail'],
            payload['selectedClientEmail'],
            details['selectedClientEmail'],
            request.selectedClientEmail,
            request.clientEmail,
          ]);

          final campaignName = firstText(<Object?>[
            payload['campaignName'],
            details['campaignName'],
            request.title,
          ]);
          notificationTitle = 'Brand Request Accepted';
          notificationBody =
              '$artistName accepted your ${campaignName.isEmpty ? 'brand request' : '$campaignName brand request'} $orderRef. Final amount: \$${normalizedTotal.toStringAsFixed(2)}.';
        } else {
          notifyEmail = firstEmail(<Object?>[
            request.clientEmail,
            request.selectedClientEmail,
          ]);
        }

        if (notifyEmail.isNotEmpty) {
          await NotificationsService.createUserNotification(
            receiverEmail: notifyEmail,
            title: notificationTitle,
            body: notificationBody,
            type: sourceCollection == 'Company_Custom_Requests'
                ? 'brand_request_accepted_by_artist'
                : 'request_accepted_by_artist',
            orderId: request.id,
            orderNumber: request.orderNumber,
            sourceCollection: sourceCollection,
            extra: <String, dynamic>{
              'artistFinalAmount': normalizedTotal,
              'artistName': artistName,
            },
          );
        }
      } catch (notificationError) {
        debugPrint(
          '[Artist Accept] Client notification failed: $notificationError',
        );
      }

      return true;
    } catch (e) {
      debugPrint('[Artist Accept] RPC failed: $e');
      return false;
    }
  }

  void _removeRequestLocally(String id) {
    setState(() {
      _all.removeWhere((r) => r.id == id);
    });
  }

  Future<void> _persistStatusUpdate({
    required ClientRequestV2 request,
    required String status,
    Map<String, dynamic> summaryExtra = const <String, dynamic>{},
    Map<String, dynamic> detailsExtra = const <String, dynamic>{},
  }) async {
    final normalized = status.trim().toLowerCase();
    final roleSummaryDefaults = _roleStatusSummaryDefaultsFor(normalized);
    final roleDetailsDefaults = _roleStatusDetailsDefaultsFor(normalized);

    final summaryPayload = <String, dynamic>{
      'status': normalized,
      'updatedAt': SupabaseServerValue.serverNow(),
      ...roleSummaryDefaults,
      ...summaryExtra,
    };

    final detailsPayload = <String, dynamic>{
      'status': normalized,
      ...roleDetailsDefaults,
      ...detailsExtra,
    };

    // If caller provided partial roleStatuses, merge with defaults so both keys exist.
    final existingRoleStatuses = detailsPayload['roleStatuses'];
    if (existingRoleStatuses is Map) {
      detailsPayload['roleStatuses'] = <String, dynamic>{
        ...(roleDetailsDefaults['roleStatuses'] as Map<String, dynamic>? ??
            const <String, dynamic>{}),
        ...existingRoleStatuses.cast<String, dynamic>(),
      };
    }

    final docRef = SupabaseCompatDatabase.instance
        .collection(request.sourceCollection)
        .doc(request.id);
    final batch = SupabaseCompatDatabase.instance.batch();
    batch.set(docRef, summaryPayload, SetOptions(merge: true));
    batch.set(
      docRef.collection('details').doc('payload'),
      detailsPayload,
      SetOptions(merge: true),
    );
    await batch.commit();

    if (normalized == 'completed' ||
        normalized == 'shipped' ||
        normalized == 'delivered') {
      unawaited(_syncAscensionForCurrentArtist());
    }
  }

  Future<void> _persistDeliveredRootStatus(ClientRequestV2 request) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final orderNumber = request.orderNumber.trim();

    Map<String, dynamic> asMap(Object? value) {
      if (value is Map<String, dynamic>)
        return Map<String, dynamic>.from(value);
      if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
      return <String, dynamic>{};
    }

    Future<void> updateClientRow() async {
      try {
        Map<String, dynamic>? row = await Supabase.instance.client
            .from('client_custom_requests')
            .select('id,data')
            .eq('id', request.id)
            .maybeSingle();
        if (row == null && orderNumber.isNotEmpty) {
          row = await Supabase.instance.client
              .from('client_custom_requests')
              .select('id,data')
              .or('order_number.eq.$orderNumber,request_number.eq.$orderNumber')
              .maybeSingle();
        }
        if (row == null) return;
        final id = (row['id'] ?? '').toString().trim();
        if (id.isEmpty) return;
        final data = asMap(row['data']);
        final roleStatuses = asMap(data['roleStatuses']);
        await Supabase.instance.client
            .from('client_custom_requests')
            .update({
              'status': 'delivered',
              'client_status': 'delivered',
              'artist_status': 'delivered',
              'delivered_at': now,
              'order_delivered_at': now,
              'updated_at': now,
              'data': <String, dynamic>{
                ...data,
                'status': 'delivered',
                'clientStatus': 'delivered',
                'artistStatus': 'delivered',
                'deliveredAt': now,
                'orderDeliveredAt': now,
                'roleStatuses': <String, dynamic>{
                  ...roleStatuses,
                  'client': 'delivered',
                  'artist': 'delivered',
                },
              },
            })
            .eq('id', id);
      } catch (e) {
        debugPrint(
          '[Artist Delivered] client_custom_requests update failed: $e',
        );
      }
    }

    Future<void> updateCompanyRow() async {
      try {
        Map<String, dynamic>? row = await Supabase.instance.client
            .from('company_custom_requests')
            .select('id,payload,details')
            .eq('id', request.id)
            .maybeSingle();
        if (row == null && orderNumber.isNotEmpty) {
          row = await Supabase.instance.client
              .from('company_custom_requests')
              .select('id,payload,details')
              .or('order_number.eq.$orderNumber,request_number.eq.$orderNumber')
              .maybeSingle();
        }
        if (row == null) return;
        final id = (row['id'] ?? '').toString().trim();
        if (id.isEmpty) return;
        final payload = asMap(row['payload']);
        final details = asMap(row['details']);
        final payloadRoleStatuses = asMap(payload['roleStatuses']);
        final detailsRoleStatuses = asMap(details['roleStatuses']);
        await Supabase.instance.client
            .from('company_custom_requests')
            .update({
              'status': 'delivered',
              'brand_status': 'delivered',
              'client_status': 'delivered',
              'artist_status': 'delivered',
              'updated_at': now,
              'payload': <String, dynamic>{
                ...payload,
                'status': 'delivered',
                'brandStatus': 'delivered',
                'clientStatus': 'delivered',
                'artistStatus': 'delivered',
                'deliveredAt': now,
                'orderDeliveredAt': now,
                'roleStatuses': <String, dynamic>{
                  ...payloadRoleStatuses,
                  'brand': 'delivered',
                  'client': 'delivered',
                  'artist': 'delivered',
                },
              },
              'details': <String, dynamic>{
                ...details,
                'status': 'delivered',
                'brandStatus': 'delivered',
                'clientStatus': 'delivered',
                'artistStatus': 'delivered',
                'deliveredAt': now,
                'orderDeliveredAt': now,
                'roleStatuses': <String, dynamic>{
                  ...detailsRoleStatuses,
                  'brand': 'delivered',
                  'client': 'delivered',
                  'artist': 'delivered',
                },
              },
            })
            .eq('id', id);
      } catch (e) {
        debugPrint(
          '[Artist Delivered] company_custom_requests update failed: $e',
        );
      }
    }

    Future<void> updateDetails(String table) async {
      try {
        final rows = await Supabase.instance.client
            .from(table)
            .select('id,data')
            .eq('request_id', request.id);
        for (final raw in rows.whereType<Map>()) {
          final row = Map<String, dynamic>.from(raw);
          final id = (row['id'] ?? '').toString().trim();
          if (id.isEmpty) continue;
          final data = asMap(row['data']);
          final roleStatuses = asMap(data['roleStatuses']);
          await Supabase.instance.client
              .from(table)
              .update({
                'data': <String, dynamic>{
                  ...data,
                  'status': 'delivered',
                  'clientStatus': 'delivered',
                  'artistStatus': 'delivered',
                  'deliveredAt': now,
                  'orderDeliveredAt': now,
                  'roleStatuses': <String, dynamic>{
                    ...roleStatuses,
                    'client': 'delivered',
                    'artist': 'delivered',
                  },
                },
                'updated_at': now,
              })
              .eq('id', id);
        }
      } catch (_) {}
    }

    await Future.wait(<Future<void>>[
      updateClientRow(),
      updateCompanyRow(),
      updateDetails('client_custom_requests_details'),
      updateDetails('company_custom_requests_details'),
    ]);
    unawaited(_syncAscensionForCurrentArtist());
  }

  Map<String, dynamic> _roleStatusSummaryDefaultsFor(String status) {
    switch (status) {
      case 'completed':
        return const <String, dynamic>{
          'clientStatus': 'In Progress',
          'artistStatus': 'Completed',
        };
      case 'shipped':
        return const <String, dynamic>{
          'clientStatus': 'Shipped',
          'artistStatus': 'Shipped',
        };
      case 'delivered':
        return const <String, dynamic>{
          'clientStatus': 'Delivered',
          'artistStatus': 'Delivered',
        };
      case 'designing':
      case 'in_progress':
      case 'in progress':
        return const <String, dynamic>{
          'clientStatus': 'In Progress',
          'artistStatus': 'Designing',
        };
      case 'in_review':
      case 'in review':
        return const <String, dynamic>{
          'clientStatus': 'Pending',
          'artistStatus': 'In Review',
        };
      case 'cancelled':
      case 'canceled':
        return const <String, dynamic>{
          'clientStatus': 'Cancelled',
          'artistStatus': 'Cancelled',
        };
      case 'declined':
        return const <String, dynamic>{
          'clientStatus': 'Declined',
          'artistStatus': 'Declined',
        };
      case 'expired':
        return const <String, dynamic>{
          'clientStatus': 'Expired',
          'artistStatus': 'Expired',
        };
      default:
        return const <String, dynamic>{};
    }
  }

  Map<String, dynamic> _roleStatusDetailsDefaultsFor(String status) {
    switch (status) {
      case 'completed':
        return const <String, dynamic>{
          'clientStatus': 'In Progress',
          'artistStatus': 'Completed',
          'roleStatuses': <String, dynamic>{
            'client': 'in_progress',
            'artist': 'completed',
          },
        };
      case 'shipped':
        return const <String, dynamic>{
          'clientStatus': 'Shipped',
          'artistStatus': 'Shipped',
          'roleStatuses': <String, dynamic>{
            'client': 'shipped',
            'artist': 'shipped',
          },
        };
      case 'delivered':
        return const <String, dynamic>{
          'clientStatus': 'Delivered',
          'artistStatus': 'Delivered',
          'roleStatuses': <String, dynamic>{
            'client': 'delivered',
            'artist': 'delivered',
          },
        };
      case 'designing':
      case 'in_progress':
      case 'in progress':
        return const <String, dynamic>{
          'clientStatus': 'In Progress',
          'artistStatus': 'Designing',
          'roleStatuses': <String, dynamic>{
            'client': 'in_progress',
            'artist': 'designing',
          },
        };
      case 'in_review':
      case 'in review':
        return const <String, dynamic>{
          'clientStatus': 'Pending',
          'artistStatus': 'In Review',
          'roleStatuses': <String, dynamic>{
            'client': 'pending',
            'artist': 'in_review',
          },
        };
      case 'cancelled':
      case 'canceled':
        return const <String, dynamic>{
          'clientStatus': 'Cancelled',
          'artistStatus': 'Cancelled',
          'roleStatuses': <String, dynamic>{
            'client': 'cancelled',
            'artist': 'cancelled',
          },
        };
      case 'declined':
        return const <String, dynamic>{
          'clientStatus': 'Declined',
          'artistStatus': 'Declined',
          'roleStatuses': <String, dynamic>{
            'client': 'declined',
            'artist': 'declined',
          },
        };
      case 'expired':
        return const <String, dynamic>{
          'clientStatus': 'Expired',
          'artistStatus': 'Expired',
          'roleStatuses': <String, dynamic>{
            'client': 'expired',
            'artist': 'expired',
          },
        };
      default:
        return const <String, dynamic>{};
    }
  }

  Future<void> _persistArtistDecline(ClientRequestV2 request) async {
    final artistEmail = (Supabase.instance.client.auth.currentUser?.email ?? '')
        .trim()
        .toLowerCase();
    if (artistEmail.isEmpty) {
      throw Exception('Missing signed-in artist email.');
    }

    final docRef = SupabaseCompatDatabase.instance
        .collection(request.sourceCollection)
        .doc(request.id);
    final isClientRequest =
        request.sourceCollection != 'Company_Custom_Requests';
    final releaseDirectToPool =
        request.isDirectRequest && request.fallbackToPool;
    final releaseDirectClientRequestToArtistPool =
        isClientRequest && releaseDirectToPool;
    final releaseDirectBrandRequestToPool =
        !isClientRequest && releaseDirectToPool;
    final cancelDirectRequest =
        request.isDirectRequest && !request.fallbackToPool;
    String firstNonEmpty(List<Object?> values, {String fallback = ''}) {
      for (final value in values) {
        final text = (value ?? '').toString().trim();
        if (text.isNotEmpty) return text;
      }
      return fallback;
    }

    const artistCancelReasonText = 'Artist declined the request';
    final artistCancelReason = artistCancelReasonText;
    final declinedAtIso = DateTime.now().toUtc().toIso8601String();

    if (mounted) {
      setState(() {
        _locallyDeclinedRequestIds.add(request.id);
        _persistedArtistDeclinedRequestIds.add(request.id);
        _all.removeWhere((item) => item.id == request.id);
      });
    } else {
      _locallyDeclinedRequestIds.add(request.id);
      _persistedArtistDeclinedRequestIds.add(request.id);
    }

    final table = _tableForCollection(request.sourceCollection);
    final existingRoot = await Supabase.instance.client
        .from(table)
        .select()
        .eq('id', request.id)
        .maybeSingle();
    final existingMap = existingRoot == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(existingRoot as Map);
    final existingData = existingMap['data'] is Map
        ? Map<String, dynamic>.from(existingMap['data'] as Map)
        : <String, dynamic>{};
    final existingDetails = existingMap['details'] is Map
        ? Map<String, dynamic>.from(existingMap['details'] as Map)
        : <String, dynamic>{};
    final existingDetailsOrder = existingDetails['order'] is Map
        ? Map<String, dynamic>.from(existingDetails['order'] as Map)
        : <String, dynamic>{};
    final existingDataOrder = existingData['order'] is Map
        ? Map<String, dynamic>.from(existingData['order'] as Map)
        : <String, dynamic>{};

    String firstText(List<Object?> values) {
      for (final value in values) {
        final text = (value ?? '').toString().trim();
        if (text.isNotEmpty) return text;
      }
      return '';
    }

    final originallySelectedArtistName = firstText(<Object?>[
      existingMap['selected_artist'],
      existingMap['artist_name'],
      existingData['selectedArtist'],
      existingData['selected_artist'],
      existingDataOrder['selectedArtist'],
      existingDataOrder['selected_artist'],
      existingDetailsOrder['selectedArtist'],
      existingDetailsOrder['selected_artist'],
      request.selectedArtist,
    ]);
    final originallySelectedArtistEmail = firstText(<Object?>[
      existingMap['selected_artist_email'],
      existingMap['artist_email'],
      existingData['selectedArtistEmail'],
      existingData['selected_artist_email'],
      existingDataOrder['selectedArtistEmail'],
      existingDataOrder['selected_artist_email'],
      existingDetailsOrder['selectedArtistEmail'],
      existingDetailsOrder['selected_artist_email'],
      request.selectedArtistEmail,
    ]).toLowerCase();

    final shouldReleaseClientDirectToPool =
        releaseDirectClientRequestToArtistPool;

    final existingDeclined = <String>{
      if (existingMap['declined_by_artist_emails'] is List)
        ...(existingMap['declined_by_artist_emails'] as List)
            .map((e) => e.toString().trim().toLowerCase())
            .where((e) => e.isNotEmpty),
      if (existingData['declinedByArtistEmails'] is List)
        ...(existingData['declinedByArtistEmails'] as List)
            .map((e) => e.toString().trim().toLowerCase())
            .where((e) => e.isNotEmpty),
      artistEmail,
    }.toList(growable: false);

    final updatedData = <String, dynamic>{
      ...existingData,
      'status': shouldReleaseClientDirectToPool ? 'pending' : 'declined',
      'clientStatus': 'pending',
      'artistStatus': shouldReleaseClientDirectToPool ? 'pending' : 'declined',
      'directArtistStatus': 'declined',
      'artistPoolStatus': shouldReleaseClientDirectToPool
          ? 'in_review'
          : 'declined',
      if (shouldReleaseClientDirectToPool) 'openToArtistPool': true,
      if (shouldReleaseClientDirectToPool) 'isDirectRequest': false,
      if (shouldReleaseClientDirectToPool) 'requestType': 'Standard',
      if (shouldReleaseClientDirectToPool) 'selectedArtist': '',
      if (shouldReleaseClientDirectToPool) 'selectedArtistEmail': '',
      if (shouldReleaseClientDirectToPool) 'acceptedByArtistEmail': '',
      if (shouldReleaseClientDirectToPool)
        'declinedArtistName': originallySelectedArtistName,
      if (shouldReleaseClientDirectToPool)
        'declinedArtistEmail': originallySelectedArtistEmail,
      'declinedByArtistEmails': existingDeclined,
      'declinedByArtistEmail': artistEmail,
      'artistDeclinedAt': declinedAtIso,
      'completionDeclinedAt': declinedAtIso,
      'completionDeclineReason': artistCancelReason,
      'completionDeclineDescription': artistCancelReason,
      'roleStatuses': <String, dynamic>{
        'client': 'pending',
        'artist': 'declined',
      },
      'artistDecline': <String, dynamic>{
        'artistEmail': artistEmail,
        'artistName': originallySelectedArtistName,
        'declinedAt': declinedAtIso,
        'status': 'declined',
        'reason': 'Declined by artist',
      },
    };

    final updatedDetailsOrder = <String, dynamic>{
      ...existingDetailsOrder,
      'directArtistStatus': 'declined',
      'artistPoolStatus': shouldReleaseClientDirectToPool ? 'open' : 'declined',
      if (shouldReleaseClientDirectToPool) 'openToArtistPool': true,
      if (shouldReleaseClientDirectToPool) 'isDirectRequest': false,
      if (shouldReleaseClientDirectToPool)
        'declinedArtist': originallySelectedArtistName,
      if (shouldReleaseClientDirectToPool)
        'declinedArtistEmail': originallySelectedArtistEmail,
    };
    final updatedDetailsRouting = existingDetails['routing'] is Map
        ? Map<String, dynamic>.from(existingDetails['routing'] as Map)
        : <String, dynamic>{};
    if (shouldReleaseClientDirectToPool) {
      updatedDetailsRouting['openToArtistPool'] = true;
      updatedDetailsRouting['artistPoolStatus'] = 'open';
      updatedDetailsRouting['directArtistStatus'] = 'declined';
    }
    final updatedDetails = <String, dynamic>{
      ...existingDetails,
      'order': updatedDetailsOrder,
      if (shouldReleaseClientDirectToPool) 'routing': updatedDetailsRouting,
      if (shouldReleaseClientDirectToPool) 'requestType': 'Standard',
      if (shouldReleaseClientDirectToPool)
        'declinedArtistName': originallySelectedArtistName,
      if (shouldReleaseClientDirectToPool)
        'declinedArtistEmail': originallySelectedArtistEmail,
    };

    try {
      await Supabase.instance.client.rpc(
        'artist_decline_request_for_history',
        params: <String, dynamic>{
          'p_request_id': request.id,
          'p_source_collection': request.sourceCollection,
          'p_artist_email': artistEmail,
        },
      );
    } catch (_) {
      // Fallback below keeps the app working even before the RPC is installed.
    }

    try {
      await Supabase.instance.client
          .from(table)
          .update(<String, dynamic>{
            'status': shouldReleaseClientDirectToPool ? 'pending' : 'declined',
            'client_status': 'pending',
            'artist_status': shouldReleaseClientDirectToPool
                ? 'pending'
                : 'declined',
            'direct_artist_status': 'declined',
            'artist_pool_status': shouldReleaseClientDirectToPool
                ? 'in_review'
                : 'declined',
            if (shouldReleaseClientDirectToPool) 'request_type': 'Standard',
            if (shouldReleaseClientDirectToPool) 'open_to_artist_pool': true,
            if (shouldReleaseClientDirectToPool) 'selected_artist': '',
            if (shouldReleaseClientDirectToPool) 'selected_artist_email': '',
            if (shouldReleaseClientDirectToPool) 'accepted_by_artist_email': '',
            if (shouldReleaseClientDirectToPool) 'is_direct_request': false,
            if (shouldReleaseClientDirectToPool)
              'declined_artist_name': originallySelectedArtistName,
            if (shouldReleaseClientDirectToPool)
              'declined_artist_email': originallySelectedArtistEmail,
            'declined_by_artist_emails': existingDeclined,
            'declined_by_artist_email': artistEmail,
            'artist_declined_at': declinedAtIso,
            'completion_declined_at': declinedAtIso,
            'completion_decline_reason': artistCancelReason,
            'completion_decline_description': artistCancelReason,
            'updated_at': declinedAtIso,
            'data': updatedData,
            'details': updatedDetails,
          })
          .eq('id', request.id);
    } catch (_) {
      await Supabase.instance.client
          .from(table)
          .update(<String, dynamic>{
            'status': shouldReleaseClientDirectToPool ? 'pending' : 'declined',
            'artist_status': shouldReleaseClientDirectToPool
                ? 'pending'
                : 'declined',
            if (shouldReleaseClientDirectToPool) 'request_type': 'Standard',
            if (shouldReleaseClientDirectToPool) 'open_to_artist_pool': true,
            if (shouldReleaseClientDirectToPool) 'selected_artist': '',
            if (shouldReleaseClientDirectToPool) 'selected_artist_email': '',
            if (shouldReleaseClientDirectToPool) 'accepted_by_artist_email': '',
            if (shouldReleaseClientDirectToPool) 'is_direct_request': false,
            if (shouldReleaseClientDirectToPool)
              'declined_artist_name': originallySelectedArtistName,
            if (shouldReleaseClientDirectToPool)
              'declined_artist_email': originallySelectedArtistEmail,
            'updated_at': declinedAtIso,
            'data': updatedData,
            'details': updatedDetails,
          })
          .eq('id', request.id);
    }

    final detailTable = _detailsTableFor(table);
    await Supabase.instance.client.from(detailTable).upsert(<String, dynamic>{
      'id': '${request.id}:payload',
      'request_id': request.id,
      'detail_key': 'payload',
      'data': updatedData,
      'updated_at': declinedAtIso,
    }, onConflict: 'id');

    if (releaseDirectBrandRequestToPool) {
      final rootSnap = await docRef.get();
      final rootData = rootSnap.data() ?? const <String, dynamic>{};
      final detailsSnap = await docRef
          .collection('details')
          .doc('payload')
          .get();
      final detailsData = detailsSnap.data() ?? const <String, dynamic>{};
      final orderData =
          (detailsData['order'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final orderRef = request.orderNumber.trim().isNotEmpty
          ? request.orderNumber.trim()
          : request.id;
      final brandName = firstNonEmpty(<Object?>[
        rootData['companyName'],
        rootData['brandName'],
        request.brandName,
        request.clientName,
      ], fallback: 'Brand');
      final campaignName = firstNonEmpty(<Object?>[
        rootData['campaignName'],
        rootData['title'],
        request.title,
      ], fallback: 'Campaign');
      final artistName =
          (Supabase.instance.client.auth.currentUser?.displayName ?? '')
              .trim()
              .isNotEmpty
          ? (Supabase.instance.client.auth.currentUser?.displayName ?? '')
                .trim()
          : artistEmail.split('@').first;
      final acceptedClientName = firstNonEmpty(<Object?>[
        rootData['acceptedClientName'],
        rootData['selectedClient'],
        request.acceptedClientName,
        request.selectedClient,
        'Client',
      ], fallback: 'Client');

      final brandRecipientEmails =
          await NotificationsService.resolveBrandRecipientEmails(
            rootData: rootData,
            detailsData: detailsData,
            orderData: orderData,
            excludeEmails: <String>[artistEmail],
          );

      for (final brandCompanyEmail in brandRecipientEmails) {
        await NotificationsService.createUserNotification(
          receiverEmail: brandCompanyEmail,
          title: 'Brand Request Declined',
          body: scenario43BrandReceiveOnDirectArtistDecline(
            artistName: artistName,
            brandName: brandName,
            campaignName: campaignName,
            orderRef: orderRef,
            clientName: acceptedClientName,
          ),
          type: 'brand_request_declined_by_direct_artist',
          orderId: request.id,
          orderNumber: request.orderNumber,
          sourceCollection: request.sourceCollection,
        );
      }

      await NotificationsService.notifyArtistsForBrandClientAcceptedRequest(
        clientName: acceptedClientName,
        brandName: brandName,
        campaignName: campaignName,
        isDirectRequest: false,
        selectedArtistEmail: '',
        selectedArtistName: '',
        orderId: request.id,
        sourceCollection: request.sourceCollection,
        orderNumber: request.orderNumber,
        allowNonLicensed: request.allowNonLicensed,
        excludeArtistEmails: <String>[artistEmail],
      );
    }

    if (releaseDirectClientRequestToArtistPool) {
      await NotificationsService.notifyArtistsForNewClientRequest(
        clientName: request.clientName.trim().isEmpty
            ? 'Client'
            : request.clientName.trim(),
        isDirectRequest: false,
        selectedArtistEmail: '',
        selectedArtistName: '',
        orderId: request.id,
        sourceCollection: request.sourceCollection,
        orderNumber: request.orderNumber,
        allowNonLicensed: request.allowNonLicensed,
        excludeArtistEmails: <String>[artistEmail],
      );
    }

    if (cancelDirectRequest && request.clientEmail.trim().isNotEmpty) {
      final artistName =
          (Supabase.instance.client.auth.currentUser?.displayName ?? '')
              .trim()
              .isEmpty
          ? (Supabase.instance.client.auth.currentUser?.email ?? 'Artist')
                .split('@')
                .first
          : (Supabase.instance.client.auth.currentUser?.displayName ?? '')
                .trim();
      await NotificationsService.createUserNotification(
        receiverEmail: request.clientEmail.trim().toLowerCase(),
        title: 'Request Cancelled',
        body: 'Declined by Artist $artistName',
        type: 'direct_request_declined_cancelled',
        orderId: request.id,
        orderNumber: request.orderNumber,
        sourceCollection: request.sourceCollection,
      );
    }
  }

  Future<void> _persistClientPoolResponse({
    required ClientRequestV2 request,
    required bool accept,
  }) async {
    final clientEmail = (Supabase.instance.client.auth.currentUser?.email ?? '')
        .trim()
        .toLowerCase();
    if (clientEmail.isEmpty) {
      throw Exception('Missing signed-in client email.');
    }
    if (request.sourceCollection != 'Company_Custom_Requests') {
      throw Exception('Only company requests can be accepted/cancelled here.');
    }
    final selectedClientEmail = request.selectedClientEmail
        .trim()
        .toLowerCase();
    final selectedGroupClientEmails = request.selectedGroupClientEmails
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    String firstNonEmpty(List<Object?> values, {String fallback = ''}) {
      for (final value in values) {
        final text = (value ?? '').toString().trim();
        if (text.isNotEmpty) return text;
      }
      return fallback;
    }

    if (!request.openToClientPool &&
        (request.orderType == RequestOrderTypeV2.group
            ? !selectedGroupClientEmails.contains(clientEmail)
            : (selectedClientEmail.isNotEmpty &&
                  selectedClientEmail != clientEmail))) {
      throw Exception(
        'Only the designated client can respond to this request.',
      );
    }

    if (!accept) {
      if (request.openToClientPool) {
        await _persistStatusUpdate(
          request: request,
          status: 'in_review',
          summaryExtra: <String, dynamic>{
            'declinedByClientEmails': SupabaseServerValue.arrayUnion(<String>[
              clientEmail,
            ]),
            'updatedAt': SupabaseServerValue.serverNow(),
          },
          detailsExtra: <String, dynamic>{
            'declinedByClientEmails': SupabaseServerValue.arrayUnion(<String>[
              clientEmail,
            ]),
            'lastClientDeclinedAt': SupabaseServerValue.serverNow(),
          },
        );
        return;
      }
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
          'declinedByClientEmails': SupabaseServerValue.arrayUnion(<String>[
            clientEmail,
          ]),
        },
        detailsExtra: <String, dynamic>{
          'openToClientPool': true,
          'declinedByClientEmails': SupabaseServerValue.arrayUnion(<String>[
            clientEmail,
          ]),
          'acceptance': <String, dynamic>{'acceptedByClientEmail': ''},
          'roleStatuses': <String, dynamic>{
            'brand': 'pending',
            'client': 'pending',
            'artist': 'pending',
          },
          'routing': <String, dynamic>{
            'directClientStatus': 'declined',
            'clientPoolStatus': 'pending',
            'releasedToClientPoolAt': SupabaseServerValue.serverNow(),
          },
        },
      );
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
    final rootSnap = await SupabaseCompatDatabase.instance
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
    final brandName = firstNonEmpty(<Object?>[
      rootData['companyName'],
      rootData['brandName'],
      request.clientName,
    ], fallback: 'Brand company');
    final campaignName = firstNonEmpty(<Object?>[
      rootData['campaignName'],
      rootData['title'],
      request.title,
    ], fallback: 'Campaign');
    final brandRecipientEmails =
        await NotificationsService.resolveBrandRecipientEmails(
          rootData: rootData,
          detailsData: detailsData,
          orderData: orderData,
          excludeEmails: <String>[clientEmail],
        );

    await _persistStatusUpdate(
      request: request,
      status: 'pending',
      summaryExtra: <String, dynamic>{
        'acceptedByClientEmail': clientEmail,
        'acceptedByClientAt': SupabaseServerValue.serverNow(),
        'brandStatus': 'pending',
        'clientStatus': 'pending',
        'artistStatus': 'in_review',
        'directArtistStatus': 'in_review',
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
          'acceptedByClientAt': SupabaseServerValue.serverNow(),
        },
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
          'artist': 'in_review',
        },
      },
    );

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

    await NotificationsService.notifyArtistsForBrandClientAcceptedRequest(
      clientName: acceptedClientName,
      brandName: brandName,
      campaignName: campaignName,
      isDirectRequest: request.isDirectRequest,
      selectedArtistEmail: request.selectedArtistEmail.trim().toLowerCase(),
      orderId: request.id,
      sourceCollection: request.sourceCollection,
      orderNumber: request.orderNumber,
      allowNonLicensed: request.allowNonLicensed,
    );
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
      Map<String, dynamic> asMap(Object? value) {
        if (value is Map<String, dynamic>) return value;
        if (value is Map) return Map<String, dynamic>.from(value);
        return const <String, dynamic>{};
      }

      final snap = await SupabaseCompatDatabase.instance
          .collection(collection)
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return const <String, dynamic>{};
      final data = snap.docs.first.data() ?? const <String, dynamic>{};
      final profile = asMap(data['profile']);
      final basic = asMap(data['basic']);
      final nail = asMap(data['nailPreferences']);
      final dimensions = asMap(nail['dimensions']);

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
        'nailShape': first(nail, const ['shape']),
        'nailLength': first(nail, const ['length']),
        'nailDimensions': <String, dynamic>{
          'lThumb': dimensions['lThumb'],
          'lIndex': dimensions['lIndex'],
          'lMiddle': dimensions['lMiddle'],
          'lRing': dimensions['lRing'],
          'lPinky': dimensions['lPinky'],
          'rThumb': dimensions['rThumb'],
          'rIndex': dimensions['rIndex'],
          'rMiddle': dimensions['rMiddle'],
          'rRing': dimensions['rRing'],
          'rPinky': dimensions['rPinky'],
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

  Future<void> _openDesigningDetails(ClientRequestV2 r) async {
    final shipDays = _estimateShipDays(
      artistLocation: widget.artistLocation,
      clientLocation: r.clientLocation,
    );

    await showArtistDesigningRequestSheet(
      context: context,
      request: r,
      shipDays: shipDays,
      onClose: () {},
      onMarkCompleted: (completed, artistPhotos) async =>
          _handleMarkCompleted(r, completed, artistPhotos),
    );
  }

  Future<void> _handleMarkCompleted(
    ClientRequestV2 r,
    bool completed,
    List<String> artistPhotos,
  ) async {
    if (!completed) return;
    final summaryPhotos = artistPhotos
        .where((p) => p.trim().isNotEmpty && !p.trim().startsWith('data:'))
        .toList(growable: false);
    try {
      _moveToStatus(r.id, RequestStatusV2.completed);
      final orderNumber = r.orderNumber.trim().isNotEmpty
          ? r.orderNumber
          : r.id;
      // Completion is persisted in Supabase by artist_mark_request_completed()
      // before the sheet closes. Keep this parent handler for local UI movement
      // and best-effort notifications only, so a secondary write cannot make
      // the Mark as Completed flow spin or fail after the DB has already updated.
      try {
        debugPrint('========== MARK COMPLETED ==========');
        debugPrint('Order: ${r.orderNumber}');
        debugPrint('summaryPhotos count = ${summaryPhotos.length}');
        debugPrint(summaryPhotos.toString());
        await _mirrorCompletedPhotosToArtistPortfolio(r, summaryPhotos);
      } catch (e, st) {
        debugPrint(
          'ARTIST REQUESTS portfolio mirror failed request=${r.id} order=$orderNumber: $e',
        );
        debugPrintStack(stackTrace: st);
      }

      final clientEmail = r.clientEmail.trim().toLowerCase();
      final isBrandRequest =
          r.sourceCollection == 'Company_Custom_Requests' ||
          orderNumber.toUpperCase().startsWith('BE-') ||
          orderNumber.toUpperCase().startsWith('BR-');
      final brandCtx = isBrandRequest
          ? await _loadBrandNotificationContext(r)
          : const <String, String>{};
      final campaignName = (brandCtx['campaignName'] ?? '').trim().isNotEmpty
          ? brandCtx['campaignName']!
          : (r.title.trim().isEmpty ? 'Campaign' : r.title.trim());
      final acceptedClientName =
          (brandCtx['acceptedClientName'] ?? '').trim().isNotEmpty
          ? brandCtx['acceptedClientName']!
          : (r.acceptedClientName.trim().isEmpty
                ? (r.clientName.trim().isEmpty ? 'Client' : r.clientName.trim())
                : r.acceptedClientName.trim());
      final brandCompanyName = (brandCtx['brandName'] ?? '').trim().isNotEmpty
          ? brandCtx['brandName']!
          : (r.brandName.trim().isEmpty ? 'Brand' : r.brandName.trim());
      final brandEmail = (brandCtx['brandEmail'] ?? '').trim().toLowerCase();
      final brandEmails = (brandCtx['brandEmailsCsv'] ?? '')
          .split(',')
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty && e.contains('@'))
          .toSet();
      if (brandEmail.isNotEmpty) {
        brandEmails.add(brandEmail);
      }
      final acceptedClientEmail = (brandCtx['acceptedClientEmail'] ?? '')
          .trim()
          .toLowerCase();
      final artistName =
          (Supabase.instance.client.auth.currentUser?.displayName ?? '')
              .trim()
              .isNotEmpty
          ? (Supabase.instance.client.auth.currentUser?.displayName ?? '')
                .trim()
          : (Supabase.instance.client.auth.currentUser?.email ?? 'Artist')
                .split('@')
                .first;
      if (isBrandRequest) {
        for (final receiver in brandEmails) {
          await NotificationsService.createUserNotification(
            receiverEmail: receiver,
            title: 'Brand Request Completed',
            body:
                '$artistName has completed your $campaignName brand request $orderNumber for $acceptedClientName',
            type: 'brand_request_completed_brand',
            orderId: r.id,
            orderNumber: orderNumber,
            sourceCollection: r.sourceCollection,
          );
        }
        if (acceptedClientEmail.isNotEmpty) {
          await NotificationsService.createUserNotification(
            receiverEmail: acceptedClientEmail,
            title: 'Brand Request Completed',
            body:
                'Your $campaignName Brand request $orderNumber is completed by $artistName',
            type: 'brand_request_completed_client',
            orderId: r.id,
            orderNumber: orderNumber,
            sourceCollection: r.sourceCollection,
          );
        }
        await NotificationsService.notifyAdmins(
          title: 'Brand Request Completed',
          body:
              '$artistName has completed $brandCompanyName $campaignName brand request $orderNumber for $acceptedClientName',
          type: 'brand_request_completed_admin',
          orderId: r.id,
          orderNumber: orderNumber,
          sourceCollection: r.sourceCollection,
        );
        return;
      }

      if (clientEmail.isNotEmpty) {
        final orderNo = r.orderNumber.trim().isNotEmpty ? r.orderNumber : r.id;
        await NotificationsService.createUserNotification(
          receiverEmail: clientEmail,
          title: 'Order Completed',
          body:
              'Your nails are done! 💅 $artistName just uploaded your final look.',
          type: 'order_completed_by_artist',
          orderId: r.id,
          orderNumber: orderNo,
          sourceCollection: r.sourceCollection,
        );
        await NotificationsService.queueEmail(
          to: clientEmail,
          subject: 'Please Review Your Completed Nail Design',
          text:
              'Your artist completed order $orderNo and uploaded photos. Please open your order details to Accept or Decline before shipping.',
          html:
              '<p>Your artist completed order <b>$orderNo</b> and uploaded photos.</p>'
              '<p>Please open your order details to <b>Accept</b> or <b>Decline</b> before shipping.</p>',
        );
        try {
          final doc = await SupabaseCompatDatabase.instance
              .collection(r.sourceCollection)
              .doc(r.id)
              .get();
          final phone = ((doc.data()?['clientPhone'] ?? '') as Object)
              .toString()
              .trim();
          if (phone.isNotEmpty) {
            await NotificationsService.queueSms(
              to: phone,
              text:
                  'JNT: Your completed design for order $orderNo is ready for review. Please accept or decline in the app.',
            );
          }
        } catch (_) {
          // Best-effort SMS; ignore missing/invalid phone fields.
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to complete order: $e')));
    }
  }

  Map<String, dynamic> _portfolioAsMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  List<dynamic> _portfolioAsList(Object? value) {
    if (value is List) return List<dynamic>.from(value);
    return const <dynamic>[];
  }

  Object? _portfolioFirstPresent(
    Map<String, dynamic> source,
    String snakeKey,
    String camelKey,
  ) {
    if (source.containsKey(snakeKey)) return source[snakeKey];
    return source[camelKey];
  }

  List<dynamic> _mergeUniquePortfolioList(
    List<dynamic> base,
    List<dynamic> incoming,
  ) {
    final out = <dynamic>[...base];
    final seen = out.map((e) => jsonEncode(e)).toSet();
    for (final item in incoming) {
      final key = jsonEncode(item);
      if (seen.add(key)) out.add(item);
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> _findArtistPortfolioRows({
    required String id,
    required String email,
  }) async {
    final normalizedId = id.trim();
    final normalizedEmail = email.trim().toLowerCase();
    final rows = <Map<String, dynamic>>[];
    final seen = <String>{};

    Future<void> addRow(String table, Map<dynamic, dynamic>? row) async {
      if (row == null) return;
      final mapped = Map<String, dynamic>.from(row);
      final rowId = (mapped['id'] ?? '').toString().trim();
      if (rowId.isEmpty) return;
      final key = '$table:$rowId';
      if (!seen.add(key)) return;
      rows.add(<String, dynamic>{...mapped, '_table': table});
    }

    for (final table in const <String>['artist', 'client_artist']) {
      if (normalizedId.isNotEmpty) {
        try {
          final byId = await Supabase.instance.client
              .from(table)
              .select()
              .eq('id', normalizedId)
              .maybeSingle();
          await addRow(table, byId is Map ? byId : null);
        } catch (_) {}

        try {
          final byUid = await Supabase.instance.client
              .from(table)
              .select()
              .eq('uid', normalizedId)
              .maybeSingle();
          await addRow(table, byUid is Map ? byUid : null);
        } catch (_) {}
      }

      if (normalizedEmail.isNotEmpty) {
        try {
          final byEmail = await Supabase.instance.client
              .from(table)
              .select()
              .ilike('email', normalizedEmail)
              .maybeSingle();
          await addRow(table, byEmail is Map ? byEmail : null);
        } catch (_) {}
      }
    }

    return rows;
  }

  Future<void> _mirrorCompletedPhotosToArtistPortfolio(
    ClientRequestV2 request,
    List<String> photos,
  ) async {
    final cleaned = photos
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    debugPrint('Portfolio mirror received ${cleaned.length} photos');
    debugPrint(cleaned.toString());

    if (cleaned.isEmpty) return;

    final currentUser = Supabase.instance.client.auth.currentUser;
    final artistId = (currentUser?.id ?? '').trim();
    final artistEmail = (currentUser?.email ?? '').trim().toLowerCase();
    final artistRows = await _findArtistPortfolioRows(
      id: artistId,
      email: artistEmail,
    );
    if (artistRows.isEmpty) return;

    final nowIso = DateTime.now().toIso8601String();
    final itemMaps = cleaned
        .map(
          (url) => <String, dynamic>{
            'imageUrl': url,
            'url': url,
            'image': url,
            'style': 'All',
            'source': 'artist_completed_set',
            'requestId': request.id,
            'orderId': request.id,
            'orderNumber': request.orderNumber,
            'title': request.title,
            'clientName': request.clientName,
            'brandName': request.brandName,
            'sourceCollection': request.sourceCollection,
            'createdAt': nowIso,
          },
        )
        .toList(growable: false);

    for (final artistRow in artistRows) {
      final table = (artistRow['_table'] ?? '').toString().trim();
      final rowId = (artistRow['id'] ?? '').toString().trim();
      if (table.isEmpty || rowId.isEmpty) continue;

      final portfolio = _portfolioAsMap(artistRow['portfolio']);
      final artist = _portfolioAsMap(artistRow['artist']);
      final artistPortfolio = _portfolioAsMap(artist['portfolio']);
      final nextPortfolioImages = _mergeUniquePortfolioList(
        _portfolioAsList(
          _portfolioFirstPresent(
            artistRow,
            'portfolio_images',
            'portfolioImages',
          ),
        ),
        cleaned,
      );
      final nextPortfolioItems = _mergeUniquePortfolioList(
        _portfolioAsList(
          _portfolioFirstPresent(
            artistRow,
            'portfolio_items',
            'portfolioItems',
          ),
        ),
        itemMaps,
      );

      debugPrint(
        'ARTIST REQUESTS portfolio mirror request=${request.id} order=${request.orderNumber} '
        'targetTable=$table targetRowId=$rowId photoCount=${cleaned.length}',
      );

      await Supabase.instance.client
          .from(table)
          .update({
            'portfolio_images': nextPortfolioImages,
            'panel_portfolio_images': nextPortfolioImages,
            'panel_artist_portfolio_images': nextPortfolioImages,
            'portfolio_items': nextPortfolioItems,
            'portfolio': {
              ...portfolio,
              'images': _mergeUniquePortfolioList(
                _portfolioAsList(portfolio['images']),
                cleaned,
              ),
              'items': _mergeUniquePortfolioList(
                _portfolioAsList(portfolio['items']),
                itemMaps,
              ),
            },
            'artist': {
              ...artist,
              'portfolioImages': nextPortfolioImages,
              'portfolioItems': nextPortfolioItems,
              'portfolio': {
                ...artistPortfolio,
                'images': _mergeUniquePortfolioList(
                  _portfolioAsList(artistPortfolio['images']),
                  cleaned,
                ),
                'items': _mergeUniquePortfolioList(
                  _portfolioAsList(artistPortfolio['items']),
                  itemMaps,
                ),
              },
            },
            'updated_at': nowIso,
            'updatedAt': nowIso,
          })
          .eq('id', rowId);
      debugPrint('Portfolio updated for $table : $rowId');
    }
  }

  String _normalizeImagePath(String raw) {
    var p = raw.trim();
    if (p.isEmpty) return '';
    if (p.startsWith('assets/')) {
      final rest = p.substring('assets/'.length);
      final decodedRest = _decodeUriSafelyRepeatedly(rest).trim();
      final lower = decodedRest.toLowerCase();
      if (lower.startsWith('data:') ||
          lower.startsWith('blob:') ||
          lower.startsWith('http://') ||
          lower.startsWith('https://') ||
          lower.startsWith('content://') ||
          lower.startsWith('file://')) {
        return decodedRest;
      }
    }
    p = _decodeUriSafelyRepeatedly(p).trim();
    if (p.startsWith('assets/')) {
      final rest = p.substring('assets/'.length);
      final decodedRest = _decodeUriSafelyRepeatedly(rest).trim();
      final lower = decodedRest.toLowerCase();
      if (lower.startsWith('data:') ||
          lower.startsWith('blob:') ||
          lower.startsWith('http://') ||
          lower.startsWith('https://') ||
          lower.startsWith('content://') ||
          lower.startsWith('file://')) {
        return decodedRest;
      }
    }
    return p;
  }

  Future<Map<String, String>> _loadBrandNotificationContext(
    ClientRequestV2 r,
  ) async {
    String firstNonEmpty(List<Object?> values, {String fallback = ''}) {
      for (final value in values) {
        final text = (value ?? '').toString().trim();
        if (text.isNotEmpty) return text;
      }
      return fallback;
    }

    final doc = await SupabaseCompatDatabase.instance
        .collection(r.sourceCollection)
        .doc(r.id)
        .get();
    final data = doc.data() ?? const <String, dynamic>{};
    final detailSnap = await doc.reference
        .collection('details')
        .doc('payload')
        .get();
    final detailData = detailSnap.data() ?? const <String, dynamic>{};
    final orderData =
        (detailData['order'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final acceptanceData =
        (detailData['acceptance'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};

    final companyUid = firstNonEmpty(<Object?>[
      data['companyUid'],
      detailData['companyUid'],
      orderData['companyUid'],
    ]);
    Map<String, dynamic> companyData = const <String, dynamic>{};
    if (companyUid.trim().isNotEmpty) {
      try {
        final companySnap = await SupabaseCompatDatabase.instance
            .collection('company')
            .doc(companyUid.trim())
            .get();
        companyData = companySnap.data() ?? const <String, dynamic>{};
      } catch (_) {}
    }

    final brandRecipientEmails =
        await NotificationsService.resolveBrandRecipientEmails(
          rootData: <String, dynamic>{...data, ...companyData},
          detailsData: <String, dynamic>{...detailData, ...acceptanceData},
          orderData: orderData,
        );

    final brandEmail = brandRecipientEmails.isNotEmpty
        ? brandRecipientEmails.first
        : '';

    final acceptedClientEmail = firstNonEmpty(<Object?>[
      data['acceptedByClientEmail'],
      data['selectedClientEmail'],
      detailData['selectedClientEmail'],
      orderData['selectedClientEmail'],
      (detailData['acceptance']
          as Map<String, dynamic>?)?['acceptedByClientEmail'],
      (detailData['acceptance']
          as Map<String, dynamic>?)?['selectedClientEmail'],
      r.acceptedByClientEmail,
      r.selectedClientEmail,
    ]).toLowerCase();

    final brandName = firstNonEmpty(<Object?>[
      data['companyName'],
      data['brandName'],
      orderData['companyName'],
      r.brandName,
      r.clientName,
    ], fallback: 'Brand');
    final campaignName = firstNonEmpty(<Object?>[
      data['campaignName'],
      data['title'],
      orderData['campaignName'],
      orderData['title'],
      r.title,
    ], fallback: 'Campaign');
    final acceptedClientName = firstNonEmpty(<Object?>[
      data['acceptedClientName'],
      data['selectedClient'],
      orderData['selectedClient'],
      (detailData['acceptance']
          as Map<String, dynamic>?)?['acceptedClientName'],
      (detailData['acceptance']
          as Map<String, dynamic>?)?['selectedClientName'],
      r.acceptedClientName,
      r.selectedClient,
      r.clientName,
    ], fallback: 'Client');

    return <String, String>{
      'brandEmail': brandEmail,
      'brandEmailsCsv': brandRecipientEmails.join(','),
      'acceptedClientEmail': acceptedClientEmail,
      'brandName': brandName,
      'campaignName': campaignName,
      'acceptedClientName': acceptedClientName,
    };
  }

  Future<void> _openCompletedDetails(ClientRequestV2 r) async {
    final shipDays = _estimateShipDays(
      artistLocation: widget.artistLocation,
      clientLocation: r.clientLocation,
    );

    await showCompletedRequestSheet(
      context: context,
      request: r,
      shipDays: shipDays,
      onClose: () => Navigator.pop(context),

      // ✅ UPDATED signature + uses shippedDate
      onMarkShipped:
          ({
            required String courier,
            required String tracking,
            required DateTime shippedDate,
          }) async {
            // 1) update local UI immediately
            final updated = r.copyWith(
              status: RequestStatusV2.shipped,
              shippedByCourier: courier,
              trackingNumber: tracking,

              // ✅ NEW: use selected shipped date from sheet
              shippedAt: shippedDate,
            );
            _replaceById(r.id, updated);
            try {
              await _persistStatusUpdate(
              request: r,
              status: 'shipped',
              summaryExtra: {
                'shippedByCourier': courier,
                'trackingNumber': tracking,
                'shippedAt': SupabaseDbTime.fromDate(shippedDate),
              },
              detailsExtra: {
                'shipment': {
                  'courier': courier,
                  'trackingNumber': tracking,
                  'shippedAt': SupabaseDbTime.fromDate(shippedDate),
                },
              },
            );
            final clientEmail = r.clientEmail.trim().toLowerCase();
            final orderRef = r.orderNumber.trim().isNotEmpty
                ? r.orderNumber.trim()
                : r.id;
            final isBrandRequest =
                r.sourceCollection == 'Company_Custom_Requests' ||
                orderRef.toUpperCase().startsWith('BE-') ||
                orderRef.toUpperCase().startsWith('BR-');
            final brandCtx = isBrandRequest
                ? await _loadBrandNotificationContext(r)
                : const <String, String>{};
            final campaignName =
                (brandCtx['campaignName'] ?? '').trim().isNotEmpty
                ? brandCtx['campaignName']!
                : (r.title.trim().isEmpty ? 'Campaign' : r.title.trim());
            final acceptedClientName =
                (brandCtx['acceptedClientName'] ?? '').trim().isNotEmpty
                ? brandCtx['acceptedClientName']!
                : (r.acceptedClientName.trim().isEmpty
                      ? (r.clientName.trim().isEmpty
                            ? 'Client'
                            : r.clientName.trim())
                      : r.acceptedClientName.trim());
            final brandCompanyName =
                (brandCtx['brandName'] ?? '').trim().isNotEmpty
                ? brandCtx['brandName']!
                : (r.brandName.trim().isEmpty ? 'Brand' : r.brandName.trim());
            final brandEmail = (brandCtx['brandEmail'] ?? '')
                .trim()
                .toLowerCase();
            final brandEmails = (brandCtx['brandEmailsCsv'] ?? '')
                .split(',')
                .map((e) => e.trim().toLowerCase())
                .where((e) => e.isNotEmpty && e.contains('@'))
                .toSet();
            if (brandEmail.isNotEmpty) {
              brandEmails.add(brandEmail);
            }
            final acceptedClientEmail = (brandCtx['acceptedClientEmail'] ?? '')
                .trim()
                .toLowerCase();
            final artistName =
                (Supabase.instance.client.auth.currentUser?.displayName ?? '')
                    .trim()
                    .isNotEmpty
                ? (Supabase.instance.client.auth.currentUser?.displayName ?? '')
                      .trim()
                : (Supabase.instance.client.auth.currentUser?.email ?? 'Artist')
                      .split('@')
                      .first;
            final shippedOnText =
                '${shippedDate.month.toString().padLeft(2, '0')}/${shippedDate.day.toString().padLeft(2, '0')}/${shippedDate.year}';
            final shippedMessage =
                '$artistName has shipped your $campaignName on $shippedOnText';
            if (isBrandRequest) {
              for (final receiver in brandEmails) {
                await NotificationsService.createUserNotification(
                  receiverEmail: receiver,
                  title: 'Brand Request Shipped',
                  body: shippedMessage,
                  type: 'brand_request_shipped_brand',
                  orderId: r.id,
                  orderNumber: r.orderNumber,
                  sourceCollection: r.sourceCollection,
                );
              }
              if (acceptedClientEmail.isNotEmpty) {
                await NotificationsService.createUserNotification(
                  receiverEmail: acceptedClientEmail,
                  title: 'Brand Request Shipped',
                  body: shippedMessage,
                  type: 'brand_request_shipped_client',
                  orderId: r.id,
                  orderNumber: r.orderNumber,
                  sourceCollection: r.sourceCollection,
                );
              }
              await NotificationsService.notifyAdmins(
                title: 'Brand Request Shipped',
                body:
                    '$artistName has shipped $brandCompanyName $campaignName brand request $orderRef to $acceptedClientName',
                type: 'brand_request_shipped_admin',
                orderId: r.id,
                orderNumber: r.orderNumber,
                sourceCollection: r.sourceCollection,
              );
              return;
            }
            if (clientEmail.isNotEmpty) {
              final trackingUrl =
                  'https://jnt-app-c3097.web.app/open-app?type=track-order&orderId=${Uri.encodeComponent(r.id)}';
              await NotificationsService.createUserNotification(
                receiverEmail: clientEmail,
                title: 'Order Shipped',
                body: shippedMessage,
                type: 'order_shipped',
                orderId: r.id,
                orderNumber: r.orderNumber,
                sourceCollection: r.sourceCollection,
              );
              await NotificationsService.queueTemplatedEmail(
                to: clientEmail,
                templateName: 'client_order_shipped',
                data: <String, dynamic>{
                  'clientName': r.clientName.trim().isEmpty
                      ? 'Client'
                      : r.clientName.trim(),
                  'orderId': orderRef,
                  'orderNumber': orderRef,
                  'carrierName': courier,
                  'trackingNumber': tracking,
                  'estimatedDelivery': '',
                  'trackingUrl': trackingUrl,
                },
              );
            }
            } catch (e) {
              debugPrint('[Artist Mark Shipped] failed: $e');
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to mark request shipped: $e')),
              );
            }
          },
    );
  }

  Future<void> _openShippedDetails(ClientRequestV2 r) async {
    await showShippedRequestSheet(
      context: context,
      request: r,
      onClose: () => Navigator.pop(context),
      onMarkDelivered: () async {
        // 1) update local UI
        final updated = r.copyWith(
          status: RequestStatusV2.delivered,
          deliveredAt: DateTime.now(),
        );
        _replaceById(r.id, updated);
        try {
        await _persistStatusUpdate(
          request: r,
          status: 'delivered',
          summaryExtra: {'deliveredAt': SupabaseServerValue.serverNow()},
        );
        await _persistDeliveredRootStatus(r);
        final clientEmail = r.clientEmail.trim().toLowerCase();
        final orderRef = r.orderNumber.trim().isNotEmpty
            ? r.orderNumber.trim()
            : r.id;
        final isBrandRequest =
            r.sourceCollection == 'Company_Custom_Requests' ||
            orderRef.toUpperCase().startsWith('BE-') ||
            orderRef.toUpperCase().startsWith('BR-');
        final brandCtx = isBrandRequest
            ? await _loadBrandNotificationContext(r)
            : const <String, String>{};
        final campaignName = (brandCtx['campaignName'] ?? '').trim().isNotEmpty
            ? brandCtx['campaignName']!
            : (r.title.trim().isEmpty ? 'Campaign' : r.title.trim());
        final acceptedClientName =
            (brandCtx['acceptedClientName'] ?? '').trim().isNotEmpty
            ? brandCtx['acceptedClientName']!
            : (r.acceptedClientName.trim().isEmpty
                  ? (r.clientName.trim().isEmpty
                        ? 'Client'
                        : r.clientName.trim())
                  : r.acceptedClientName.trim());
        final brandEmail = (brandCtx['brandEmail'] ?? '').trim().toLowerCase();
        final brandEmails = (brandCtx['brandEmailsCsv'] ?? '')
            .split(',')
            .map((e) => e.trim().toLowerCase())
            .where((e) => e.isNotEmpty && e.contains('@'))
            .toSet();
        if (brandEmail.isNotEmpty) {
          brandEmails.add(brandEmail);
        }
        final acceptedClientEmail = (brandCtx['acceptedClientEmail'] ?? '')
            .trim()
            .toLowerCase();
        final artistEmail =
            (Supabase.instance.client.auth.currentUser?.email ?? '')
                .trim()
                .toLowerCase();
        brandEmails.remove(acceptedClientEmail);
        if (isBrandRequest) {
          for (final receiver in brandEmails) {
            await NotificationsService.createUserNotification(
              receiverEmail: receiver,
              title: 'Brand Request Delivered',
              body:
                  'Delivered: $campaignName brand request $orderRef to $acceptedClientName',
              type: 'brand_request_delivered_brand',
              orderId: r.id,
              orderNumber: r.orderNumber,
              sourceCollection: r.sourceCollection,
            );
          }
          if (artistEmail.isNotEmpty) {
            await NotificationsService.createUserNotification(
              receiverEmail: artistEmail,
              title: 'Brand Request Delivered',
              body:
                  'You marked $campaignName brand request $orderRef as delivered to $acceptedClientName',
              type: 'brand_request_delivered_artist',
              orderId: r.id,
              orderNumber: r.orderNumber,
              sourceCollection: r.sourceCollection,
            );
          }
          if (acceptedClientEmail.isNotEmpty) {
            await NotificationsService.createUserNotification(
              receiverEmail: acceptedClientEmail,
              title: 'Brand Request Delivered',
              body:
                  'Your $campaignName Brand request $orderRef has been delivered',
              type: 'brand_request_delivered_client',
              orderId: r.id,
              orderNumber: r.orderNumber,
              sourceCollection: r.sourceCollection,
            );
          }
          await NotificationsService.notifyArtistPoolBrandDelivered(
            clientName: acceptedClientName,
            campaignName: campaignName,
            orderId: r.id,
            sourceCollection: r.sourceCollection,
            orderNumber: r.orderNumber,
            excludeArtistEmails: artistEmail.isEmpty
                ? const <String>[]
                : <String>[artistEmail],
          );
          await NotificationsService.notifyAdmins(
            title: 'Brand Request Delivered',
            body:
                'Delivered: $campaignName brand request $orderRef to $acceptedClientName',
            type: 'brand_request_delivered_admin',
            orderId: r.id,
            orderNumber: r.orderNumber,
            sourceCollection: r.sourceCollection,
          );
          return;
        }
        if (clientEmail.isNotEmpty) {
          final artistName = r.selectedArtist.trim().isNotEmpty
              ? r.selectedArtist.trim()
              : (r.acceptedByArtistEmail.trim().isNotEmpty
                    ? r.acceptedByArtistEmail.trim().split('@').first
                    : 'Your artist');
          final deliveredDate = DateTime.now().toIso8601String();
          final tracking = r.trackingNumber?.trim().isNotEmpty == true
              ? r.trackingNumber!.trim()
              : (r.shippingLabelTrackingNumber.trim().isNotEmpty
                    ? r.shippingLabelTrackingNumber.trim()
                    : '');
          final reviewUrl =
              'https://jnt-app-c3097.web.app/open-app?type=review-order&orderId=${Uri.encodeComponent(r.id)}';
          final appLink =
              'https://jnt-app-c3097.web.app/open-app?type=order-details&orderId=${Uri.encodeComponent(r.id)}';
          final deepLink = reviewUrl;
          await NotificationsService.createUserNotification(
            receiverEmail: clientEmail,
            title: 'Order Delivered: Review & Tip',
            body:
                'Your order has been delivered. Open the app to leave a rating, comments, and tip your artist.',
            type: 'delivered_review_prompt',
            orderId: r.id,
            orderNumber: r.orderNumber,
            sourceCollection: r.sourceCollection,
            extra: <String, dynamic>{
              'deepLink': deepLink,
              'action': 'review_tip',
            },
          );
          await NotificationsService.queueTemplatedEmail(
            to: clientEmail,
            templateName: 'client_order_delivered_review_tip',
            data: <String, dynamic>{
              'clientName': r.clientName.trim().isEmpty
                  ? 'Client'
                  : r.clientName.trim(),
              'orderId': orderRef,
              'artistName': artistName,
              'deliveredDate': deliveredDate,
              'trackingNumber': tracking,
              'reviewUrl': reviewUrl,
              'tip10Url': '$reviewUrl&tip=10',
              'tip15Url': '$reviewUrl&tip=15',
              'tip20Url': '$reviewUrl&tip=20',
              'appLink': appLink,
            },
          );
        }
        } catch (e) {
          debugPrint('[Artist Mark Delivered] failed: $e');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to mark request delivered: $e')),
          );
        }
      },
    );
  }

  Future<void> _openInReviewDetails(ClientRequestV2 r) async {
    final request = await _hydrateRequestForDetails(r);
    if (!mounted) return;

    if (widget.showOnlyCompanyRequests) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: false,
        backgroundColor: Colors.transparent,
        builder: (_) => ClientCampaignDetailsPage(
          request: request,
          declineLabel: 'Decline',
          acceptLabel: 'Accept',
          onDecline: () async {
            Navigator.pop(context);
            try {
              await _persistClientPoolResponse(request: request, accept: false);
              if (!mounted) return;
              _removeRequestLocally(request.id);
              unawaited(_loadRequestsFromDb());
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to cancel request: $e')),
              );
            }
          },
          onAccept: () async {
            try {
              await _persistClientPoolResponse(request: request, accept: true);
              if (!mounted) return;
              Navigator.pop(context);
              _replaceById(
                request.id,
                request.copyWith(
                  status: RequestStatusV2.inReview,
                  acceptedByClientEmail:
                      (Supabase.instance.client.auth.currentUser?.email ?? '')
                          .trim()
                          .toLowerCase(),
                ),
              );
              unawaited(_loadRequestsFromDb());
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to accept request: $e')),
              );
            }
          },
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      builder: (_) => InReviewDetailsSheet(
        request: request,
        onDecline: () async {
          Navigator.pop(context);
          try {
            _removeRequestLocally(request.id);
            await _persistArtistDecline(request);
            unawaited(_loadRequestsFromDb());
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to decline request: $e')),
            );
          }
        },
        onAccept: () async {
          final accepted = await showModalBottomSheet<_AcceptResult>(
            context: context,
            isScrollControlled: true,
            useSafeArea: false,
            useRootNavigator: true,
            backgroundColor: Colors.transparent,
            builder: (_) => AcceptRequestDialogV2(
              budgetMin: request.budgetMin,
              budgetMax: request.budgetMax,
            ),
          );

          if (accepted != null) {
            final acceptedTotal =
                accepted.yourPrice + accepted.shipping + accepted.extra;
            final optimistic = request.copyWith(
              status: RequestStatusV2.designing,
              artistFinalAmount: double.parse(acceptedTotal.toStringAsFixed(2)),
            );

            if (!mounted) return;
            Navigator.pop(context);
            _replaceById(request.id, optimistic);

            try {
              final persisted = await _persistArtistAcceptance(
                request,
                accepted,
              );
              if (!persisted) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Could not update request in database.'),
                  ),
                );
                return;
              }

              if (!mounted) return;
              unawaited(_loadRequestsFromDb());
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to accept request: $e')),
              );
            }
          }
        },
      ),
    );
  }

  InputDecoration _miniDec({String? prefix, String? hint}) {
    return InputDecoration(
      prefixText: prefix,
      prefixStyle: TextStyle(
        color: AppColors.blackCat.withValues(alpha: 0.78),
        fontWeight: FontWeight.w600,
      ),
      hintText: hint,
      hintStyle: TextStyle(
        color: AppColors.blackCat.withValues(alpha: 0.45),
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: AppColors.snow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _statusTabs() {
    final activeIndex = _tabCtrl.index;
    return TabBar(
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      controller: _tabCtrl,
      dividerColor: Colors.transparent,
      labelPadding: const EdgeInsets.only(left: 0, right: 14),
      onTap: (_) => setState(() {}),
      indicator: const UnderlineTabIndicator(
        borderSide: BorderSide(color: AppColors.alabaster, width: 3),
      ),
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      labelColor: AppColors.blackCat,
      unselectedLabelColor: AppColors.blackCat,
      tabs: [
        _statusTab(
          'All',
          _countForAllActive(), // ✅ new helper below
          activeIndex == 0,
        ),
        _statusTab(
          'In Review',
          _countForStatus(RequestStatusV2.inReview),
          activeIndex == 1,
        ),
        _statusTab('Designing', _countForDesigningTab(), activeIndex == 2),
        _statusTab(
          'Completed',
          _countForStatus(RequestStatusV2.completed),
          activeIndex == 3,
        ),
        _statusTab(
          'Shipped',
          _countForStatus(RequestStatusV2.shipped),
          activeIndex == 4,
        ),

        // -------------------------------------------------
        // KEEP THESE BUT COMMENTED (per your request)
        // -------------------------------------------------
        /*
          _statusTab(
            'Delivered',
            _countForStatus(RequestStatusV2.delivered),
            activeIndex == 5,
          ),
          _statusTab(
            'Declined',
            _countForStatus(RequestStatusV2.declined),
            activeIndex == 6,
          ),
          _statusTab(
            'Cancelled',
            _countForStatus(RequestStatusV2.cancelled),
            activeIndex == 7,
          ),
          _statusTab(
            'Expired',
            _countForStatus(RequestStatusV2.expired),
            activeIndex == 8,
          ),
          */
      ],
    );
  }

  Widget _tabList(int tabIndex) {
    if (!_hasLoadedRequests && !_isLoadingDb && _all.isEmpty) {
      if (!_initialLoadScheduled) {
        _initialLoadScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(_loadRequestsFromDb());
        });
      }
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_isLoadingDb && _all.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    final items = _filteredForTab(tabIndex);

    if (items.isEmpty) {
      return Center(
        child: Text(
          'No requests in this status',
          style: TextStyle(
            color: AppColors.blackCat.withValues(alpha: 0.55),
            fontWeight: FontWeight.w400,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _requestCard(items[i]),
    );
  }

  bool _truthyNfcValue(Object? value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value.toString().trim().toLowerCase();
    return normalized == 'true' ||
        normalized == 'yes' ||
        normalized == '1' ||
        normalized == 'selected' ||
        normalized == 'requested' ||
        normalized == 'enabled';
  }

  bool _isNfcCheckboxKey(String key) {
    final normalized = key.trim().toLowerCase();
    return normalized == 'nfcrequested' ||
        normalized == 'nfcselected' ||
        normalized == 'nfcrequest' ||
        normalized == 'nfcenabled' ||
        normalized == 'hasnfc' ||
        normalized == 'requiresnfceligibleclient' ||
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

  bool _containsSelectedNfcCheckbox(Object? value) {
    if (value == null) return false;
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString();
        final entryValue = entry.value;
        if (_isNfcCheckboxKey(key) && _truthyNfcValue(entryValue)) return true;
        if (key.trim().toLowerCase() == 'nfc' && entryValue is Map) {
          for (final nested in entryValue.entries) {
            if (_isNfcCheckboxKey(nested.key.toString()) &&
                _truthyNfcValue(nested.value)) {
              return true;
            }
          }
        }
        if (entryValue is Map || entryValue is List) {
          if (_containsSelectedNfcCheckbox(entryValue)) return true;
        }
      }
      return false;
    }
    if (value is List) {
      for (final item in value) {
        if (_containsSelectedNfcCheckbox(item)) return true;
      }
    }
    return false;
  }

  Future<bool> _requestHasNfc(ClientRequestV2 request) async {
    try {
      final docRef = SupabaseCompatDatabase.instance
          .collection(request.sourceCollection)
          .doc(request.id);
      final rootSnap = await docRef.get();
      final rootData = rootSnap.data() ?? const <String, dynamic>{};
      final detailsSnap = await docRef
          .collection('details')
          .doc('payload')
          .get();
      final detailsData = detailsSnap.data() ?? const <String, dynamic>{};

      return _containsSelectedNfcCheckbox(rootData) ||
          _containsSelectedNfcCheckbox(detailsData);
    } catch (_) {
      return false;
    }
  }

  Widget _nfcChip(BuildContext context) {
    final s = _reqScale(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: const BoxDecoration(
        color: AppColors.balletSlippers,
        borderRadius: BorderRadius.zero,
      ),
      child: Text(
        'NFC',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 11 * s,
          color: AppColors.blackCat.withValues(alpha: 0.85),
          height: 1.05,
        ),
      ),
    );
  }

  Widget _requestCard(ClientRequestV2 r) {
    if (widget.showOnlyCompanyRequests) {
      return _companyRequestCard(r);
    }
    final s = _reqScale(context);

    return MergeSemantics(
      child: Semantics(
        button: true,
        child: ExcludeSemantics(
        child: InkWell(
      borderRadius: BorderRadius.zero,
      onTap: () {
        if (r.status == RequestStatusV2.inReview) {
          _openInReviewDetails(r);
        } else if (r.status == RequestStatusV2.accepted ||
            r.status == RequestStatusV2.designing) {
          _openDesigningDetails(r);
        } else if (r.status == RequestStatusV2.completed) {
          _openCompletedDetails(r);
        } else if (r.status == RequestStatusV2.shipped) {
          _openShippedDetails(r);
        }

        // -------------------------------------------------
        // KEEP THESE BUT COMMENTED (per your request)
        // -------------------------------------------------
        /*
        else if (r.status == RequestStatusV2.delivered) {
          showDeliveredRequestSheet(context: context, request: r);
        } else if (r.status == RequestStatusV2.cancelled) {
          _openCancelledDetails(r);
        } else if (r.status == RequestStatusV2.declined) {
          _openDeclinedDetails(r);
        } else if (r.status == RequestStatusV2.expired) {
          _openExpiredDetails(r);
        }
        */
      },

      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.snow,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: AppColors.blackCatBorderLight),
          boxShadow: [
            BoxShadow(
              color: AppColors.blackCat.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Avatar stacked above name (left column)
            SizedBox(width: 62, child: Column(children: [_clientAvatar(r, s)])),

            const SizedBox(width: 12),

            // Middle content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // title row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.sourceCollection == 'Company_Custom_Requests' &&
                                  r.brandName.trim().isNotEmpty
                              ? r.brandName.trim()
                              : r.clientName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14 * s,
                            color: AppColors.blackCat,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (r.sourceCollection == 'Company_Custom_Requests') ...[
                    const SizedBox(height: 4),
                    Text(
                      r.title.trim().isEmpty ? 'Campaign' : r.title.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.blackCat.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w500,
                        fontSize: 12.5 * s,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.blackCat),
                        color: AppColors.snow,
                      ),
                      child: Text(
                        'Brand Request',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 10.5 * s,
                          color: AppColors.blackCat,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'Order # ${r.orderNumber.trim().isNotEmpty ? r.orderNumber.trim() : r.id}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.blackCat.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w500,
                      fontSize: 12.5 * s,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Need by ${_formatNeedBy(r.neededBy)}',
                    style: TextStyle(
                      color: AppColors.blackCat.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5 * s,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      const Icon(
                        Icons.attach_money_rounded,
                        size: 16,
                        color: AppColors.blackCat,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '\$${r.budgetMin} - \$${r.budgetMax}',
                          style: _t(
                            11.5,
                            w: FontWeight.w700,
                            c: AppColors.blackCat.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        size: 16,
                        color: AppColors.blackCat,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          r.isDirectRequest ? 'Direct' : 'Standard',
                          style: _t(
                            11.5,
                            w: FontWeight.w700,
                            c: AppColors.blackCat.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.groups_2_outlined,
                        size: 16,
                        color: AppColors.blackCat,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          r.orderType == RequestOrderTypeV2.group
                              ? 'Group Order'
                              : 'Single Order',
                          style: _t(
                            11.5,
                            w: FontWeight.w700,
                            c: AppColors.blackCat.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Right preview image + status text
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  r.status.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.blackCat.withValues(alpha: 0.85),
                    fontSize: 14 * s,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: Container(
                    height: 64,
                    width: 84,
                    color: AppColors.blackCat.withValues(alpha: 0.05),
                    child: _requestPreviewImage(r),
                  ),
                ),
                FutureBuilder<bool>(
                  future: _requestHasNfc(r),
                  builder: (context, snapshot) {
                    if (snapshot.data != true) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _nfcChip(context),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      ),
      ),
      ),
    );
  }

  Widget _companyRequestCard(ClientRequestV2 r) {
    final s = _reqScale(context);
    final displayStatus = _companyRequestStatus(r);
    return FutureBuilder<bool>(
      future: _requestHasNfc(r),
      builder: (context, snapshot) {
        return CompanyClientRequestCard(
          request: r,
          scale: s,
          displayStatus: displayStatus,
          needByLabel: _shortDate(r.neededBy),
          submittedLabel: _shortDate(r.submittedAt ?? r.neededBy),
          avatar: _clientAvatar(r, s),
          previewImage: _requestPreviewImage(r),
          showNfcChip: snapshot.data == true,
          onTap: () {
            if (r.status == RequestStatusV2.inReview) {
              _openInReviewDetails(r);
            } else if (r.status == RequestStatusV2.accepted ||
                r.status == RequestStatusV2.designing) {
              _openDesigningDetails(r);
            } else if (r.status == RequestStatusV2.completed) {
              _openCompletedDetails(r);
            } else if (r.status == RequestStatusV2.shipped) {
              _openShippedDetails(r);
            }
          },
        );
      },
    );
  }

  Widget _clientAvatar(ClientRequestV2 r, double s) {
    final photo = r.clientProfileImage.trim();

    Widget initialFallback() {
      final letter = r.clientName.isEmpty ? 'C' : r.clientName[0].toUpperCase();
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.balletSlippers,
          borderRadius: BorderRadius.zero,
        ),
        alignment: Alignment.center,
        child: Text(
          letter,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16 * s,
            color: AppColors.blackCat,
          ),
        ),
      );
    }

    Widget boxedImage(ImageProvider provider) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.zero,
          image: DecorationImage(image: provider, fit: BoxFit.cover),
        ),
      );
    }

    Widget imageFromPath(String path) {
      final p = _normalizeImagePath(path);
      final dataBytes = _decodeDataImageBytes(p);
      final isNetwork =
          p.startsWith('http://') ||
          p.startsWith('https://') ||
          p.startsWith('blob:') ||
          p.startsWith('content://');
      final isAsset = p.startsWith('assets/');
      final isFileUri = p.startsWith('file://');
      final isFilePath = !kIsWeb && (p.startsWith('/') || p.contains(':\\'));
      final isStorageRef = _looksLikeStorageRef(p);

      if (p.startsWith('gs://') || isStorageRef) {
        return FutureBuilder<String>(
          future: p.startsWith('gs://')
              ? StorageUrlResolver.resolve(p).then((v) => v ?? '')
              : StorageUrlResolver.resolve(p).then((v) => v ?? ''),
          builder: (_, snap) {
            final url = snap.data?.trim() ?? '';
            if (url.isNotEmpty) return boxedImage(NetworkImage(url));
            return FutureBuilder<Uint8List?>(
              future: _readStorageBytes(p),
              builder: (_, bytesSnap) {
                final bytes = bytesSnap.data;
                if (bytes == null || bytes.isEmpty) return initialFallback();
                return boxedImage(MemoryImage(bytes));
              },
            );
          },
        );
      }

      if (dataBytes != null) {
        return boxedImage(MemoryImage(dataBytes));
      }

      if (isNetwork) {
        return boxedImage(NetworkImage(p));
      }

      if (isAsset) {
        return boxedImage(AssetImage(p));
      }

      if (isFileUri || isFilePath) {
        final localPath = isFileUri ? p.replaceFirst('file://', '') : p;
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.zero,
            image: DecorationImage(
              image: FileImage(File(localPath)),
              fit: BoxFit.cover,
            ),
          ),
        );
      }

      return initialFallback();
    }

    return Container(
      height: 46,
      width: 46,
      decoration: BoxDecoration(
        color: AppColors.balletSlippers,
        borderRadius: BorderRadius.zero,
      ),
      clipBehavior: Clip.antiAlias,
      child: FutureBuilder<String>(
        future: _resolveClientProfileImageForRequest(r),
        builder: (_, snap) {
          final resolved = (snap.data ?? photo).trim();
          return resolved.isNotEmpty
              ? imageFromPath(resolved)
              : initialFallback();
        },
      ),
    );
  }

  Future<String> _resolveClientProfileImageForRequest(ClientRequestV2 r) async {
    final existing = r.clientProfileImage.trim();
    if (existing.isNotEmpty && existing.toLowerCase() != 'null')
      return existing;

    final accepted = r.acceptedClientProfileImage.trim();
    if (accepted.isNotEmpty && accepted.toLowerCase() != 'null')
      return accepted;

    return _lookupClientProfileImage(
      email: r.clientEmail.trim(),
      name: r.clientName.trim(),
    );
  }

  Future<String> _lookupClientProfileImage({
    required String email,
    required String name,
  }) async {
    String firstNonEmpty(List<Object?> values) {
      for (final raw in values) {
        final text = (raw ?? '').toString().trim();
        if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
      }
      return '';
    }

    Map<String, dynamic> asMap(Object? value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
      return const <String, dynamic>{};
    }

    String imageFromRow(Map<String, dynamic> row) {
      final profile = asMap(row['profile']);
      final basic = asMap(row['basic']);
      final client = asMap(row['client']);
      final clientProfile = asMap(client['profile']);
      final data = asMap(row['data']);
      return firstNonEmpty(<Object?>[
        row['client_profile_image'],
        row['clientProfileImage'],
        row['profileImageUrl'],
        row['profile_image_url'],
        row['profile_picture_url'],
        row['profilePhotoUrl'],
        row['profile_photo_url'],
        row['avatarUrl'],
        row['avatar_url'],
        row['photoUrl'],
        row['photo_url'],
        profile['profileImageUrl'],
        profile['profile_image_url'],
        profile['profile_picture_url'],
        profile['avatarUrl'],
        profile['avatar_url'],
        profile['photoUrl'],
        profile['photo_url'],
        basic['profileImageUrl'],
        basic['profile_image_url'],
        basic['profile_picture_url'],
        basic['avatarUrl'],
        basic['avatar_url'],
        basic['photoUrl'],
        basic['photo_url'],
        client['profileImageUrl'],
        client['profile_image_url'],
        client['profile_picture_url'],
        client['avatarUrl'],
        client['avatar_url'],
        client['photoUrl'],
        client['photo_url'],
        clientProfile['profileImageUrl'],
        clientProfile['profile_image_url'],
        clientProfile['profile_picture_url'],
        clientProfile['avatarUrl'],
        clientProfile['avatar_url'],
        clientProfile['photoUrl'],
        clientProfile['photo_url'],
        data['clientProfileImage'],
        data['client_profile_image'],
        data['profileImageUrl'],
        data['profile_image_url'],
        data['avatarUrl'],
        data['avatar_url'],
        data['photoUrl'],
        data['photo_url'],
      ]);
    }

    Future<String> lookupBy(String table, String column, String value) async {
      final needle = value.trim();
      if (needle.isEmpty) return '';
      try {
        final row = await Supabase.instance.client
            .from(table)
            .select()
            .eq(column, needle)
            .limit(1)
            .maybeSingle();
        if (row == null) return '';
        return imageFromRow((row as Map).cast<String, dynamic>());
      } catch (_) {
        return '';
      }
    }

    for (final table in const <String>['client', 'clients', 'client_artist']) {
      for (final column in const <String>['email', 'client_email']) {
        final byEmail = await lookupBy(table, column, email.toLowerCase());
        if (byEmail.isNotEmpty) return byEmail;
      }
    }
    for (final table in const <String>['client', 'clients', 'client_artist']) {
      for (final column in const <String>[
        'name',
        'displayName',
        'display_name',
        'client_name',
      ]) {
        final byName = await lookupBy(table, column, name);
        if (byName.isNotEmpty) return byName;
      }
    }
    return '';
  }

  Widget _requestPreviewImage(ClientRequestV2 r) {
    String pickFirstPhoto(List<String> images, String fallback) {
      for (final raw in images) {
        final s = raw.trim();
        if (s.isNotEmpty) return s;
      }
      return fallback.trim();
    }

    final trimmed = _normalizeImagePath(
      pickFirstPhoto(r.clientImages, r.previewImageAsset),
    );
    final dataBytes = _decodeDataImageBytes(trimmed);
    final isNet =
        trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('gs://') ||
        trimmed.startsWith('blob:') ||
        trimmed.startsWith('content://');
    final isAsset = trimmed.startsWith('assets/');
    final isFileUri = trimmed.startsWith('file://');
    final isFilePath =
        !kIsWeb && (trimmed.startsWith('/') || trimmed.contains(':\\'));
    final isStorageRef = _looksLikeStorageRef(trimmed);

    if (trimmed.startsWith('gs://') || isStorageRef) {
      return FutureBuilder<String>(
        future: trimmed.startsWith('gs://')
            ? StorageUrlResolver.resolve(trimmed).then((v) => v ?? '')
            : StorageUrlResolver.resolve(trimmed).then((v) => v ?? ''),
        builder: (_, snap) {
          final url = snap.data?.trim() ?? '';
          if (url.isNotEmpty) {
            return Image.network(
              url,
              fit: BoxFit.cover,
              cacheWidth: kMaxImageDecodeDimension,
              errorBuilder: (_, _, _) => Icon(
                Icons.image_outlined,
                color: AppColors.blackCat.withValues(alpha: 0.35),
              ),
            );
          }
          return FutureBuilder<Uint8List?>(
            future: _readStorageBytes(trimmed),
            builder: (_, bytesSnap) {
              final bytes = bytesSnap.data;
              if (bytes == null || bytes.isEmpty) {
                return Icon(
                  Icons.image_outlined,
                  color: AppColors.blackCat.withValues(alpha: 0.35),
                );
              }
              return Image.memory(
                bytes,
                fit: BoxFit.cover,
                cacheWidth: kMaxImageDecodeDimension,
                errorBuilder: (_, _, _) => Icon(
                  Icons.image_outlined,
                  color: AppColors.blackCat.withValues(alpha: 0.35),
                ),
              );
            },
          );
        },
      );
    }
    if (dataBytes != null) {
      return Image.memory(
        dataBytes,
        fit: BoxFit.cover,
        cacheWidth: kMaxImageDecodeDimension,
        errorBuilder: (_, _, _) => Icon(
          Icons.image_outlined,
          color: AppColors.blackCat.withValues(alpha: 0.35),
        ),
      );
    }
    if (isNet) {
      return Image.network(
        trimmed,
        fit: BoxFit.cover,
        cacheWidth: kMaxImageDecodeDimension,
        errorBuilder: (_, _, _) => Icon(
          Icons.image_outlined,
          color: AppColors.blackCat.withValues(alpha: 0.35),
        ),
      );
    }

    if (isAsset) {
      return Image.asset(
        trimmed,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Icon(
          Icons.image_outlined,
          color: AppColors.blackCat.withValues(alpha: 0.35),
        ),
      );
    }

    if (isFileUri || isFilePath) {
      final localPath = isFileUri
          ? trimmed.replaceFirst('file://', '')
          : trimmed;
      return Image.file(
        File(localPath),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Icon(
          Icons.image_outlined,
          color: AppColors.blackCat.withValues(alpha: 0.35),
        ),
      );
    }

    return Center(
      child: Icon(
        Icons.image_outlined,
        color: AppColors.blackCat.withValues(alpha: 0.35),
      ),
    );
  }

  String _formatNeedBy(DateTime d) {
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
    final wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1];
    return '$wd, ${months[d.month - 1]} ${d.day}';
  }

  String _shortDate(DateTime d) {
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
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _companyRequestStatus(ClientRequestV2 r) {
    if (r.status == RequestStatusV2.inReview &&
        r.acceptedByClientEmail.trim().isEmpty) {
      return 'Pending';
    }
    if (r.acceptedByClientEmail.trim().isNotEmpty &&
        r.acceptedByArtistEmail.trim().isEmpty) {
      return 'In Review';
    }
    return r.status.label;
  }
}

// ----------------------------------------------
// Enums / Models for this page (keep isolated)
// ----------------------------------------------
enum ShipTimeFilter { any, upTo2Days, upTo3Days, upTo5Days }

class _ArtistRequestDisplayContext {
  const _ArtistRequestDisplayContext({
    required this.isDirectRequest,
    required this.isGroupOrder,
    required this.companyBio,
  });

  final bool isDirectRequest;
  final bool isGroupOrder;
  final String companyBio;
}

class InReviewDetailsSheet extends StatelessWidget {
  const InReviewDetailsSheet({
    super.key,
    required this.request,
    required this.onDecline,
    required this.onAccept,
    this.declineLabel = 'Decline',
    this.acceptLabel = 'Accept',
  });

  final ClientRequestV2 request;
  final VoidCallback onDecline;
  final Future<void> Function() onAccept;
  final String declineLabel;
  final String acceptLabel;

  static final Map<String, Future<_ArtistRequestDisplayContext>>
  _displayContextFutureCache = <String, Future<_ArtistRequestDisplayContext>>{};

  String get _displayContextCacheKey =>
      '${request.sourceCollection}:${request.id}:${request.orderNumber}';

  Future<_ArtistRequestDisplayContext> _cachedDisplayContext() {
    final key = _displayContextCacheKey;
    return _displayContextFutureCache.putIfAbsent(
      key,
      () => _loadDisplayContext(),
    );
  }

  bool _hasHeroProfileImage() {
    final path = _heroPhotoSource().trim();
    return path.isNotEmpty;
  }


  String _heroPhotoSource() {
    final profile = request.clientProfileImage.trim();
    final isBrandRequest =
        request.sourceCollection == 'Company_Custom_Requests';
    if (profile.isNotEmpty) {
      if (!isBrandRequest) return profile;
      final normalizedProfile = _normalizeImagePath(
        profile,
      ).trim().toLowerCase();
      final blocked = <String>{
        _normalizeImagePath(request.previewImageAsset).trim().toLowerCase(),
        ...request.clientImages.map(
          (e) => _normalizeImagePath(e).trim().toLowerCase(),
        ),
      }..removeWhere((e) => e.isEmpty);
      if (!blocked.contains(normalizedProfile)) return profile;
    }
    return '';
  }

  Future<String> _resolvedHeroPhotoSource() async {
    final existing = _heroPhotoSource().trim();
    if (existing.isNotEmpty) return existing;
    return _lookupClientProfileImage(
      email: request.clientEmail.trim(),
      name: request.clientName.trim(),
    );
  }

  Future<String> _lookupClientProfileImage({
    required String email,
    required String name,
  }) async {
    String firstNonEmpty(List<Object?> values) {
      for (final raw in values) {
        final text = (raw ?? '').toString().trim();
        if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
      }
      return '';
    }

    Map<String, dynamic> asMap(Object? value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
      return const <String, dynamic>{};
    }

    String imageFromRow(Map<String, dynamic> row) {
      final profile = asMap(row['profile']);
      final basic = asMap(row['basic']);
      final client = asMap(row['client']);
      final clientProfile = asMap(client['profile']);
      final data = asMap(row['data']);
      return firstNonEmpty(<Object?>[
        row['client_profile_image'],
        row['clientProfileImage'],
        row['profileImageUrl'],
        row['profile_image_url'],
        row['profile_picture_url'],
        row['profilePhotoUrl'],
        row['profile_photo_url'],
        row['avatarUrl'],
        row['avatar_url'],
        row['photoUrl'],
        row['photo_url'],
        profile['profileImageUrl'],
        profile['profile_image_url'],
        profile['profile_picture_url'],
        profile['avatarUrl'],
        profile['avatar_url'],
        profile['photoUrl'],
        profile['photo_url'],
        basic['profileImageUrl'],
        basic['profile_image_url'],
        basic['profile_picture_url'],
        basic['avatarUrl'],
        basic['avatar_url'],
        basic['photoUrl'],
        basic['photo_url'],
        client['profileImageUrl'],
        client['profile_image_url'],
        client['profile_picture_url'],
        client['avatarUrl'],
        client['avatar_url'],
        client['photoUrl'],
        client['photo_url'],
        clientProfile['profileImageUrl'],
        clientProfile['profile_image_url'],
        clientProfile['profile_picture_url'],
        clientProfile['avatarUrl'],
        clientProfile['avatar_url'],
        clientProfile['photoUrl'],
        clientProfile['photo_url'],
        data['clientProfileImage'],
        data['client_profile_image'],
        data['profileImageUrl'],
        data['profile_image_url'],
        data['avatarUrl'],
        data['avatar_url'],
        data['photoUrl'],
        data['photo_url'],
      ]);
    }

    Future<String> lookupBy(String table, String column, String value) async {
      final needle = value.trim();
      if (needle.isEmpty) return '';
      try {
        final row = await Supabase.instance.client
            .from(table)
            .select()
            .eq(column, needle)
            .limit(1)
            .maybeSingle();
        if (row == null) return '';
        return imageFromRow((row as Map).cast<String, dynamic>());
      } catch (_) {
        return '';
      }
    }

    for (final table in const <String>['client', 'clients', 'client_artist']) {
      for (final column in const <String>['email', 'client_email']) {
        final byEmail = await lookupBy(table, column, email.toLowerCase());
        if (byEmail.isNotEmpty) return byEmail;
      }
    }
    for (final table in const <String>['client', 'clients', 'client_artist']) {
      for (final column in const <String>[
        'name',
        'displayName',
        'display_name',
        'client_name',
      ]) {
        final byName = await lookupBy(table, column, name);
        if (byName.isNotEmpty) return byName;
      }
    }
    return '';
  }

  Map<String, dynamic> _displayAsMap(Object? value) {
    if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
    if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
    if (value is String) {
      final text = value.trim();
      if (text.isEmpty) return const <String, dynamic>{};
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>)
          return Map<String, dynamic>.from(decoded);
        if (decoded is Map)
          return decoded.map((k, v) => MapEntry(k.toString(), v));
      } catch (_) {}
    }
    return const <String, dynamic>{};
  }

  List<dynamic> _displayAsList(Object? value) {
    if (value is List) return List<dynamic>.from(value);
    return const <dynamic>[];
  }

  String _displayFirstNonEmpty(List<Object?> values, {String fallback = ''}) {
    for (final raw in values) {
      final text = (raw ?? '').toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return fallback;
  }

  bool _displayTruthy(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = (value ?? '').toString().trim().toLowerCase();
    return text == 'true' || text == 'yes' || text == '1' || text == 'direct';
  }

  String _displayNormalized(Object? value) =>
      (value ?? '').toString().trim().toLowerCase().replaceAll(' ', '_');

  bool _displayIsRequestDescription(String value) {
    final candidate = value.trim().toLowerCase();
    if (candidate.isEmpty) return true;
    final requestDescriptionCandidates = <String>{
      request.bio.trim().toLowerCase(),
      request.subtitle.trim().toLowerCase(),
      request.title.trim().toLowerCase(),
    }..removeWhere((e) => e.isEmpty);
    return requestDescriptionCandidates.contains(candidate);
  }

  Future<_ArtistRequestDisplayContext> _loadDisplayContext() async {
    Map<String, dynamic> rootData = const <String, dynamic>{};
    Map<String, dynamic> detailsData = const <String, dynamic>{};

    try {
      final table = _tableForCollection(request.sourceCollection);
      final detailTable = _detailsTableFor(table);
      final requestId = request.id.trim();
      final orderNumber = request.orderNumber.trim();

      Map<String, dynamic>? rootRow;
      if (requestId.isNotEmpty) {
        final row = await Supabase.instance.client
            .from(table)
            .select()
            .eq('id', requestId)
            .maybeSingle();
        if (row != null) rootRow = Map<String, dynamic>.from(row);
      }
      if (rootRow == null && orderNumber.isNotEmpty) {
        try {
          final row = await Supabase.instance.client
              .from(table)
              .select()
              .or('order_number.eq.$orderNumber,request_number.eq.$orderNumber')
              .maybeSingle();
          if (row != null) rootRow = Map<String, dynamic>.from(row);
        } catch (_) {}
      }
      rootData = rootRow ?? const <String, dynamic>{};

      final detailRows = requestId.isEmpty
          ? const <dynamic>[]
          : await Supabase.instance.client
                .from(detailTable)
                .select()
                .eq('request_id', requestId);
      final mergedDetails = <String, dynamic>{};
      for (final raw in detailRows.whereType<Map>()) {
        final row = Map<String, dynamic>.from(raw);
        for (final key in const <String>['payload', 'data', 'details']) {
          final value = row[key];
          if (value is Map) {
            mergedDetails.addAll(
              value.map((k, v) => MapEntry(k.toString(), v)),
            );
          }
        }
        mergedDetails.addAll(row);
      }
      detailsData = mergedDetails;
    } catch (_) {}

    Map<String, dynamic> safeMap(Object? value) => _displayAsMap(value);
    List<dynamic> safeList(Object? value) => _displayAsList(value);

    final payload = safeMap(rootData['payload']);
    final rootDetails = safeMap(rootData['details']);
    final rootDataJson = safeMap(rootData['data']);
    final detailsPayload = safeMap(detailsData['payload']);
    final detailsDataJson = safeMap(detailsData['data']);

    final orderData = <String, dynamic>{
      ...safeMap(rootData['order']),
      ...safeMap(rootDetails['order']),
      ...safeMap(payload['order']),
      ...safeMap(rootDataJson['order']),
      ...safeMap(detailsData['order']),
      ...safeMap(detailsPayload['order']),
      ...safeMap(detailsDataJson['order']),
    };

    String first(List<Object?> values, {String fallback = ''}) =>
        _displayFirstNonEmpty(values, fallback: fallback).trim();

    final requestTypeText = first(<Object?>[
      rootData['request_type'],
      rootData['requestType'],
      rootData['request_type_label'],
      rootData['requestTypeLabel'],
      rootDetails['requestType'],
      rootDetails['request_type'],
      payload['requestType'],
      payload['request_type'],
      rootDataJson['requestType'],
      rootDataJson['request_type'],
      detailsData['request_type'],
      detailsData['requestType'],
      detailsData['requestTypeLabel'],
      detailsPayload['requestType'],
      detailsPayload['request_type'],
      detailsDataJson['requestType'],
      detailsDataJson['request_type'],
      orderData['requestType'],
      orderData['request_type'],
    ]).toLowerCase();

    final selectedArtistEmail = first(<Object?>[
      rootData['selected_artist_email'],
      rootData['selectedArtistEmail'],
      rootData['artist_email'],
      rootData['artistEmail'],
      rootDetails['selectedArtistEmail'],
      rootDetails['selected_artist_email'],
      payload['selectedArtistEmail'],
      payload['selected_artist_email'],
      rootDataJson['selectedArtistEmail'],
      rootDataJson['selected_artist_email'],
      detailsData['selected_artist_email'],
      detailsData['selectedArtistEmail'],
      detailsPayload['selectedArtistEmail'],
      detailsPayload['selected_artist_email'],
      detailsDataJson['selectedArtistEmail'],
      detailsDataJson['selected_artist_email'],
      orderData['selectedArtistEmail'],
      orderData['selected_artist_email'],
      request.selectedArtistEmail,
    ]);

    final selectedArtistName = first(<Object?>[
      rootData['selected_artist'],
      rootData['selectedArtist'],
      rootData['artist_name'],
      rootDetails['selectedArtist'],
      rootDetails['selected_artist'],
      payload['selectedArtist'],
      payload['selected_artist'],
      rootDataJson['selectedArtist'],
      rootDataJson['selected_artist'],
      detailsData['selectedArtist'],
      detailsData['selected_artist'],
      detailsPayload['selectedArtist'],
      detailsPayload['selected_artist'],
      detailsDataJson['selectedArtist'],
      detailsDataJson['selected_artist'],
      orderData['selectedArtist'],
      orderData['selected_artist'],
      request.selectedArtist,
    ]);

    final directFlag =
        _displayTruthy(rootData['is_direct_request']) ||
        _displayTruthy(rootData['isDirectRequest']) ||
        _displayTruthy(rootData['direct_request']) ||
        _displayTruthy(rootDetails['isDirectRequest']) ||
        _displayTruthy(rootDetails['is_direct_request']) ||
        _displayTruthy(payload['isDirectRequest']) ||
        _displayTruthy(payload['is_direct_request']) ||
        _displayTruthy(rootDataJson['isDirectRequest']) ||
        _displayTruthy(rootDataJson['is_direct_request']) ||
        _displayTruthy(detailsData['is_direct_request']) ||
        _displayTruthy(detailsData['isDirectRequest']) ||
        _displayTruthy(detailsPayload['isDirectRequest']) ||
        _displayTruthy(detailsPayload['is_direct_request']) ||
        _displayTruthy(detailsDataJson['isDirectRequest']) ||
        _displayTruthy(detailsDataJson['is_direct_request']) ||
        _displayTruthy(orderData['isDirectRequest']) ||
        _displayTruthy(orderData['is_direct_request']);
    final openToArtistPool =
        _displayTruthy(rootData['open_to_artist_pool']) ||
        _displayTruthy(rootData['openToArtistPool']) ||
        _displayTruthy(rootDetails['openToArtistPool']) ||
        _displayTruthy(rootDetails['open_to_artist_pool']) ||
        _displayTruthy(payload['openToArtistPool']) ||
        _displayTruthy(payload['open_to_artist_pool']) ||
        _displayTruthy(rootDataJson['openToArtistPool']) ||
        _displayTruthy(rootDataJson['open_to_artist_pool']) ||
        _displayTruthy(detailsData['open_to_artist_pool']) ||
        _displayTruthy(detailsData['openToArtistPool']) ||
        _displayTruthy(detailsPayload['openToArtistPool']) ||
        _displayTruthy(detailsPayload['open_to_artist_pool']) ||
        _displayTruthy(detailsDataJson['openToArtistPool']) ||
        _displayTruthy(detailsDataJson['open_to_artist_pool']) ||
        _displayTruthy(orderData['openToArtistPool']) ||
        _displayTruthy(orderData['open_to_artist_pool']);

    final requestTypeSaysDirect =
        requestTypeText.contains('direct') &&
        !requestTypeText.contains('standard');
    final requestTypeSaysStandard =
        requestTypeText.contains('standard') &&
        !requestTypeText.contains('direct');
    final hasSelectedArtist =
        selectedArtistEmail.isNotEmpty || selectedArtistName.isNotEmpty;
    final isDirectRequest = openToArtistPool
        ? false
        : requestTypeSaysStandard
        ? false
        : (request.isDirectRequest ||
              directFlag ||
              requestTypeSaysDirect ||
              hasSelectedArtist);

    final orderTypeText = first(<Object?>[
      rootData['order_type'],
      rootData['orderType'],
      rootData['order_type_label'],
      rootData['orderTypeLabel'],
      rootDetails['orderType'],
      rootDetails['order_type'],
      payload['orderType'],
      payload['order_type'],
      rootDataJson['orderType'],
      rootDataJson['order_type'],
      detailsData['order_type'],
      detailsData['orderType'],
      detailsData['orderTypeLabel'],
      detailsPayload['orderType'],
      detailsPayload['order_type'],
      detailsDataJson['orderType'],
      detailsDataJson['order_type'],
      orderData['type'],
      orderData['orderType'],
      orderData['order_type'],
    ]).toLowerCase();

    final groupClients = <dynamic>[
      ...safeList(rootData['group_clients']),
      ...safeList(rootData['groupClients']),
      ...safeList(rootDetails['group_clients']),
      ...safeList(rootDetails['groupClients']),
      ...safeList(payload['group_clients']),
      ...safeList(payload['groupClients']),
      ...safeList(rootDataJson['group_clients']),
      ...safeList(rootDataJson['groupClients']),
      ...safeList(detailsData['group_clients']),
      ...safeList(detailsData['groupClients']),
      ...safeList(detailsPayload['group_clients']),
      ...safeList(detailsPayload['groupClients']),
      ...safeList(detailsDataJson['group_clients']),
      ...safeList(detailsDataJson['groupClients']),
      ...safeList(orderData['group_clients']),
      ...safeList(orderData['groupClients']),
      ...safeList(orderData['selectedGroupClientEmails']),
      ...safeList(orderData['selected_group_client_emails']),
    ];
    final isGroupOrder =
        request.orderType == RequestOrderTypeV2.group ||
        orderTypeText.contains('group') ||
        groupClients.isNotEmpty ||
        request.groupClients.isNotEmpty ||
        request.selectedGroupClientEmails.isNotEmpty;

    final companyUid = first(<Object?>[
      rootData['company_uid'],
      rootData['companyUid'],
      rootData['company_id'],
      rootData['companyId'],
      rootData['brand_id'],
      rootData['brandId'],
      rootDetails['companyUid'],
      rootDetails['company_uid'],
      rootDetails['companyId'],
      rootDetails['company_id'],
      payload['companyUid'],
      payload['company_uid'],
      payload['companyId'],
      payload['company_id'],
      rootDataJson['companyUid'],
      rootDataJson['company_uid'],
      detailsData['company_uid'],
      detailsData['companyUid'],
      detailsData['company_id'],
      detailsData['companyId'],
      detailsPayload['companyUid'],
      detailsPayload['company_uid'],
      detailsPayload['companyId'],
      detailsPayload['company_id'],
      detailsDataJson['companyUid'],
      detailsDataJson['company_uid'],
      orderData['companyUid'],
      orderData['company_uid'],
      orderData['companyId'],
      orderData['company_id'],
    ]);

    final companyEmail = first(<Object?>[
      rootData['company_email'],
      rootData['companyEmail'],
      rootData['brand_email'],
      rootData['brandEmail'],
      rootData['email'],
      rootDetails['companyEmail'],
      rootDetails['company_email'],
      payload['companyEmail'],
      payload['company_email'],
      payload['brandEmail'],
      payload['brand_email'],
      rootDataJson['companyEmail'],
      rootDataJson['company_email'],
      detailsData['company_email'],
      detailsData['companyEmail'],
      detailsData['brandEmail'],
      detailsData['brand_email'],
      detailsPayload['companyEmail'],
      detailsPayload['company_email'],
      detailsPayload['brandEmail'],
      detailsPayload['brand_email'],
      detailsDataJson['companyEmail'],
      detailsDataJson['company_email'],
      orderData['companyEmail'],
      orderData['company_email'],
      orderData['brandEmail'],
      orderData['brand_email'],
    ]).toLowerCase();

    final companyName = first(<Object?>[
      rootData['company_name'],
      rootData['companyName'],
      rootData['brand_name'],
      rootData['brandName'],
      rootDetails['companyName'],
      rootDetails['company_name'],
      rootDetails['brandName'],
      rootDetails['brand_name'],
      payload['companyName'],
      payload['company_name'],
      payload['brandName'],
      payload['brand_name'],
      rootDataJson['companyName'],
      rootDataJson['company_name'],
      rootDataJson['brandName'],
      rootDataJson['brand_name'],
      detailsData['companyName'],
      detailsData['company_name'],
      detailsData['brandName'],
      detailsData['brand_name'],
      detailsPayload['companyName'],
      detailsPayload['company_name'],
      detailsPayload['brandName'],
      detailsPayload['brand_name'],
      detailsDataJson['companyName'],
      detailsDataJson['company_name'],
      detailsDataJson['brandName'],
      detailsDataJson['brand_name'],
      orderData['companyName'],
      orderData['company_name'],
      orderData['brandName'],
      orderData['brand_name'],
      request.brandName,
      request.clientName,
    ]);

    bool isRealCompanyBio(String value) {
      final candidate = value.trim();
      if (candidate.isEmpty) return false;
      if (_displayIsRequestDescription(candidate)) return false;
      final lower = candidate.toLowerCase();
      return lower != 'null' &&
          lower != '-' &&
          lower != 'no company bio available';
    }

    String bioFromCompanyRow(Map<String, dynamic> row) {
      final company = safeMap(row['company']);
      final profile = safeMap(row['profile']);
      final data = safeMap(row['data']);
      final candidates = <Object?>[
        company['bio'],
        company['companyBio'],
        company['company_bio'],
        row['company_bio'],
        row['companyBio'],
        row['bio'],
        row['panel_company_bio'],
        row['panel_companyBio'],
        profile['companyBio'],
        profile['company_bio'],
        profile['bio'],
        data['companyBio'],
        data['company_bio'],
        data['bio'],
      ];
      for (final raw in candidates) {
        final text = (raw ?? '').toString().trim();
        if (isRealCompanyBio(text)) return text;
      }
      return '';
    }

    String bioFromSnapshot(Map<String, dynamic> source) {
      final snapshot = safeMap(
        source['companyProfileSnapshot'] ?? source['company_profile_snapshot'],
      );
      final company = safeMap(snapshot['company']);
      final candidates = <Object?>[
        company['bio'],
        company['companyBio'],
        company['company_bio'],
        snapshot['bio'],
        snapshot['companyBio'],
        snapshot['company_bio'],
        snapshot['panel_companyBio'],
        snapshot['panel_company_bio'],
      ];
      for (final raw in candidates) {
        final text = (raw ?? '').toString().trim();
        if (isRealCompanyBio(text)) return text;
      }
      return '';
    }

    Future<String> bioFromCompanyTable() async {
      Future<String> readRow(dynamic row) async {
        if (row == null) return '';
        final map = Map<String, dynamic>.from(row as Map);
        return bioFromCompanyRow(map);
      }

      if (companyUid.isNotEmpty) {
        try {
          final row = await Supabase.instance.client
              .from('company')
              .select()
              .eq('id', companyUid)
              .maybeSingle();
          final bio = await readRow(row);
          if (bio.isNotEmpty) return bio;
        } catch (_) {}
      }

      if (companyEmail.isNotEmpty) {
        try {
          final row = await Supabase.instance.client
              .from('company')
              .select()
              .ilike('email', companyEmail)
              .maybeSingle();
          final bio = await readRow(row);
          if (bio.isNotEmpty) return bio;
        } catch (_) {}
      }

      if (companyName.isNotEmpty) {
        for (final column in const <String>[
          'panel_company_name',
          'company_name',
          'brand_name',
        ]) {
          try {
            final row = await Supabase.instance.client
                .from('company')
                .select()
                .ilike(column, companyName)
                .maybeSingle();
            final bio = await readRow(row);
            if (bio.isNotEmpty) return bio;
          } catch (_) {}
        }
      }

      return '';
    }

    String companyBio = '';
    if (request.sourceCollection == 'Company_Custom_Requests') {
      for (final source in <Map<String, dynamic>>[
        rootData,
        rootDetails,
        payload,
        rootDataJson,
        detailsData,
        detailsPayload,
        detailsDataJson,
        orderData,
      ]) {
        companyBio = bioFromSnapshot(source);
        if (companyBio.isNotEmpty) break;
      }
      if (companyBio.isEmpty) {
        companyBio = await bioFromCompanyTable();
      }
    }

    return _ArtistRequestDisplayContext(
      isDirectRequest: isDirectRequest,
      isGroupOrder: isGroupOrder,
      companyBio: companyBio.trim(),
    );
  }

  String _requestDescriptionText() {
    final text = request.bio.trim();
    if (text.isNotEmpty) return text;
    final subtitle = request.subtitle.trim();
    if (subtitle.isNotEmpty) return subtitle;
    return '-';
  }

  Widget _companyBioBlock() {
    if (request.sourceCollection != 'Company_Custom_Requests') {
      return const SizedBox.shrink();
    }
    return FutureBuilder<_ArtistRequestDisplayContext>(
      future: _cachedDisplayContext(),
      builder: (context, snapshot) {
        final bio = (snapshot.data?.companyBio ?? '').trim();
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: _softBox(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Company Bio'),
                const SizedBox(height: 8),
                Text(
                  bio.isEmpty ? 'No company bio available' : bio,
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 14.5,
                    height: 1.35,
                    color: AppColors.blackCat.withValues(alpha: 0.90),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<List<String>> _modalPhotoCandidates() async {
    final out = <String>[];

    Map<String, dynamic> asMap(Object? value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
      return const <String, dynamic>{};
    }

    List<dynamic> asList(Object? value) {
      if (value is List) return value;
      return const <dynamic>[];
    }

    void addRaw(Object? value, List<String> target) {
      if (value == null) return;
      if (value is String) {
        final text = value.trim();
        if (text.isNotEmpty && text.toLowerCase() != 'null') target.add(text);
        return;
      }
      if (value is Iterable) {
        for (final item in value) {
          addRaw(item, target);
        }
        return;
      }
      if (value is Map) {
        final map = value.map((k, v) => MapEntry(k.toString(), v));
        for (final key in const <String>[
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
        ]) {
          if (map.containsKey(key)) addRaw(map[key], target);
        }
        map.forEach((key, child) {
          final lower = key.toLowerCase();
          if (lower.contains('photo') ||
              lower.contains('image') ||
              lower.contains('inspiration') ||
              lower.contains('preview') ||
              lower.endsWith('url') ||
              lower.endsWith('path')) {
            addRaw(child, target);
          } else if (child is Map || child is List) {
            addRaw(child, target);
          }
        });
      }
    }

    final rawCandidates = <String>[];
    addRaw(request.clientImages, rawCandidates);
    addRaw(request.previewImageAsset, rawCandidates);

    try {
      final docRef = SupabaseCompatDatabase.instance
          .collection(request.sourceCollection)
          .doc(request.id);
      final rootSnap = await docRef.get();
      final rootData = rootSnap.data() ?? const <String, dynamic>{};
      final detailsSnap = await docRef
          .collection('details')
          .doc('payload')
          .get();
      final detailsData = detailsSnap.data() ?? const <String, dynamic>{};

      void addFromSource(Map<String, dynamic> source) {
        addRaw(source['clientImages'], rawCandidates);
        addRaw(source['client_images'], rawCandidates);
        addRaw(source['inspirationPhotos'], rawCandidates);
        addRaw(source['inspiration_photos'], rawCandidates);
        addRaw(source['brandInspirationPhotos'], rawCandidates);
        addRaw(source['brand_inspiration_photos'], rawCandidates);
        addRaw(source['photos'], rawCandidates);
        addRaw(source['uploadedPhotos'], rawCandidates);
        addRaw(source['uploaded_photos'], rawCandidates);
        addRaw(source['previewImage'], rawCandidates);
        addRaw(source['preview_image'], rawCandidates);
        addRaw(source['previewImageAsset'], rawCandidates);
        addRaw(source['preview_image_asset'], rawCandidates);

        final payload = asMap(source['payload']);
        final requestDetails = asMap(
          source['requestDetails'] ?? source['request_details'],
        );
        final orderData = asMap(
          source['order'] ?? source['orderData'] ?? source['order_data'],
        );
        for (final nested in <Map<String, dynamic>>[
          payload,
          requestDetails,
          orderData,
        ]) {
          addRaw(nested['clientImages'], rawCandidates);
          addRaw(nested['client_images'], rawCandidates);
          addRaw(nested['inspirationPhotos'], rawCandidates);
          addRaw(nested['inspiration_photos'], rawCandidates);
          addRaw(nested['brandInspirationPhotos'], rawCandidates);
          addRaw(nested['brand_inspiration_photos'], rawCandidates);
          addRaw(nested['photos'], rawCandidates);
          addRaw(nested['uploadedPhotos'], rawCandidates);
          addRaw(nested['uploaded_photos'], rawCandidates);
          addRaw(nested['previewImage'], rawCandidates);
          addRaw(nested['preview_image'], rawCandidates);
          addRaw(nested['previewImageAsset'], rawCandidates);
          addRaw(nested['preview_image_asset'], rawCandidates);
        }

        final groupSources = <Object?>[
          asMap(source['groupOrder'] ?? source['group_order'])['clients'],
          source['groupClients'],
          source['group_clients'],
          source['selectedGroupClients'],
          source['selected_group_clients'],
          payload['groupClients'],
          payload['group_clients'],
          payload['selectedGroupClients'],
          payload['selected_group_clients'],
          asMap(payload['groupOrder'] ?? payload['group_order'])['clients'],
          requestDetails['groupClients'],
          requestDetails['group_clients'],
          requestDetails['selectedGroupClients'],
          requestDetails['selected_group_clients'],
          asMap(
            requestDetails['groupOrder'] ?? requestDetails['group_order'],
          )['clients'],
          orderData['groupClients'],
          orderData['group_clients'],
          orderData['selectedGroupClients'],
          orderData['selected_group_clients'],
          asMap(orderData['groupOrder'] ?? orderData['group_order'])['clients'],
        ];
        for (final groupSource in groupSources) {
          for (final rawClient in asList(groupSource)) {
            final client = asMap(rawClient);
            addRaw(client['clientImages'], rawCandidates);
            addRaw(client['client_images'], rawCandidates);
            addRaw(client['inspirationPhotos'], rawCandidates);
            addRaw(client['inspiration_photos'], rawCandidates);
            addRaw(client['uploadedPhotos'], rawCandidates);
            addRaw(client['uploaded_photos'], rawCandidates);
            addRaw(client['photos'], rawCandidates);
            addRaw(client['images'], rawCandidates);
          }
        }
      }

      addFromSource(rootData);
      addFromSource(detailsData);
    } catch (_) {}

    for (final raw in rawCandidates) {
      final normalized = _normalizeImagePath(raw).trim();
      if (normalized.isEmpty) continue;
      final lower = normalized.toLowerCase();
      if (lower == 'null' || lower == '-' || lower == '[]' || lower == '{}')
        continue;
      if (lower.startsWith('assets/images/order_thumb') ||
          lower.startsWith('assets/images/placeholder') ||
          lower.startsWith('assets/icons/')) {
        continue;
      }
      if (!out.any((existing) => existing.toLowerCase() == lower)) {
        out.add(normalized);
      }
    }

    return out;
  }

  String _initialLetter() {
    final name = request.clientName.trim();
    if (name.isEmpty) return 'C';
    return name[0].toUpperCase();
  }

  Future<_RequestNfcDetails> _loadRequestedNfcDetails() async {
    try {
      RequestNfcDetails sharedNfc = RequestNfcDetails.emptyConst;
      try {
        sharedNfc = await loadRequestNfcDetails(
          sourceCollection: request.sourceCollection,
          requestId: request.id,
          requestOrderNumber: request.orderNumber,
        );
      } catch (e, st) {
        debugPrint(
          'IN_REVIEW_GROUP_SHARED_NFC_ERROR request=${request.id} '
          'order=${request.orderNumber} error=$e',
        );
        debugPrintStack(stackTrace: st);
      }
      final table = request.sourceCollection == 'Client_Custom_Requests'
          ? 'client_custom_requests'
          : (request.sourceCollection == 'Company_Custom_Requests'
                ? 'company_custom_requests'
                : request.sourceCollection);
      final detailsTable = table == 'client_custom_requests'
          ? 'client_custom_requests_details'
          : (table == 'company_custom_requests'
                ? 'company_custom_requests_details'
                : '${table}_details');
      final supabase = Supabase.instance.client;

      Map<String, dynamic> rootData =
          await supabase
              .from(table)
              .select()
              .eq('id', request.id)
              .maybeSingle() ??
          const <String, dynamic>{};
      if (rootData.isEmpty && request.orderNumber.trim().isNotEmpty) {
        rootData =
            await supabase
                .from(table)
                .select()
                .or(
                  'order_number.eq.${request.orderNumber.trim()},request_number.eq.${request.orderNumber.trim()},client_request_number.eq.${request.orderNumber.trim()}',
                )
                .maybeSingle() ??
            const <String, dynamic>{};
      }

      final resolvedRequestId = (rootData['id'] ?? request.id)
          .toString()
          .trim();
      List<dynamic> detailRows = const <dynamic>[];
      try {
        detailRows = await supabase
            .from(detailsTable)
            .select()
            .eq('request_id', resolvedRequestId);
      } catch (e, st) {
        debugPrint(
          'IN_REVIEW_GROUP_DETAIL_ROWS_ERROR request=${request.id} '
          'table=$detailsTable resolvedRequestId=$resolvedRequestId error=$e',
        );
        debugPrintStack(stackTrace: st);
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
          final row = raw is Map<String, dynamic>
              ? raw
              : (raw is Map
                    ? raw.map((key, value) => MapEntry(key.toString(), value))
                    : <String, dynamic>{});
          if (row.isEmpty) continue;
          final payload = row['payload'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(
                  row['payload'] as Map<String, dynamic>,
                )
              : (row['payload'] is Map
                    ? (row['payload'] as Map).map(
                        (key, value) => MapEntry(key.toString(), value),
                      )
                    : <String, dynamic>{});
          final data = row['data'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(row['data'] as Map<String, dynamic>)
              : (row['data'] is Map
                    ? (row['data'] as Map).map(
                        (key, value) => MapEntry(key.toString(), value),
                      )
                    : <String, dynamic>{});
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

      final detailsData = mergedDetailRows(detailRows);

      Map<String, dynamic> asMap(Object? value) {
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
        if (value is Map<String, dynamic>) return value;
        if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
        return const <String, dynamic>{};
      }

      List<dynamic> asList(Object? value) {
        if (value is String) {
          final text = value.trim();
          if (text.startsWith('[') && text.endsWith(']')) {
            try {
              final decoded = jsonDecode(text);
              if (decoded is List) return decoded;
            } catch (_) {}
          }
        }
        if (value is List) return value;
        return const <dynamic>[];
      }

      String firstNonEmpty(List<Object?> values, {String fallback = ''}) {
        for (final value in values) {
          final text = (value ?? '').toString().trim();
          if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
        }
        return fallback;
      }

      Map<String, String> dimsFrom(Object? source, {required bool left}) {
        final map = asMap(source);
        if (map.isEmpty) return const <String, String>{};
        final nested = asMap(map['dimensions']);
        final data = nested.isNotEmpty ? nested : map;
        String pick(String finger) {
          final upper = finger[0].toUpperCase() + finger.substring(1);
          final candidates = left
              ? <String>[finger, 'l$upper', 'left$upper']
              : <String>[finger, 'r$upper', 'right$upper'];
          for (final key in candidates) {
            final text = (data[key] ?? '').toString().trim();
            if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
          }
          return '';
        }

        return <String, String>{
          'thumb': pick('thumb'),
          'index': pick('index'),
          'middle': pick('middle'),
          'ring': pick('ring'),
          'pinky': pick('pinky'),
        };
      }

      Map<String, String> firstDims(
        List<Object?> sources, {
        required bool left,
      }) {
        for (final source in sources) {
          final dims = dimsFrom(source, left: left);
          if (dims.values.any((v) => v.trim().isNotEmpty)) return dims;
        }
        return const <String, String>{};
      }

      NailDimensionsV2 nailDimsFromMap(Map<String, String> source) {
        return NailDimensionsV2(
          thumb: (source['thumb'] ?? '').trim(),
          index: (source['index'] ?? '').trim(),
          middle: (source['middle'] ?? '').trim(),
          ring: (source['ring'] ?? '').trim(),
          pinky: (source['pinky'] ?? '').trim(),
        );
      }

      bool hasDims(Map<String, String> source) {
        return source.values.any((value) => value.trim().isNotEmpty);
      }

      final detailsPayload = asMap(detailsData['payload']);
      final detailsDetails = asMap(detailsData['details']);
      final detailsDataJson = asMap(detailsData['data']);
      final detailsRequestDetails = asMap(
        detailsData['requestDetails'] ?? detailsData['request_details'],
      );
      final detailsOrderData = asMap(
        detailsData['order'] ??
            detailsData['orderData'] ??
            detailsData['order_data'],
      );
      final rootPayload = asMap(rootData['payload']);
      final rootDetails = asMap(rootData['details']);
      final rootDataJson = asMap(rootData['data']);
      final rootRequestDetails = asMap(
        rootData['requestDetails'] ?? rootData['request_details'],
      );
      final rootOrderData = asMap(
        rootData['order'] ?? rootData['orderData'] ?? rootData['order_data'],
      );

      // Fast path for Supabase client_custom_requests rows.
      // Client submissions store the selected NFC checkboxes under:
      // details.nailPreferences.dimensions.nfc and/or details.nailPreferences.dimensions.*Nfc.
      // Parse that exact submitted snapshot before any profile fallback data,
      // because profile snapshots can contain the same dimensions with all NFC flags false.
      final submittedDetails = asMap(rootData['details']);
      final submittedNailPrefs = asMap(
        submittedDetails['nailPreferences'] ??
            submittedDetails['nail_preferences'],
      );
      final submittedDims = asMap(submittedNailPrefs['dimensions']);
      final submittedNfc = _FingerNfcSelection.fromDimensionsMap(submittedDims);
      final hasGroupClientsInPayload =
          request.groupClients.isNotEmpty ||
          asList(
            asMap(rootData['groupOrder'] ?? rootData['group_order'])['clients'],
          ).isNotEmpty ||
          asList(
            asMap(
              rootDetails['groupOrder'] ?? rootDetails['group_order'],
            )['clients'],
          ).isNotEmpty ||
          asList(
            rootData['groupClients'] ?? rootData['group_clients'],
          ).isNotEmpty ||
          asList(
            rootDetails['groupClients'] ?? rootDetails['group_clients'],
          ).isNotEmpty ||
          asList(
            asMap(
              detailsData['groupOrder'] ?? detailsData['group_order'],
            )['clients'],
          ).isNotEmpty ||
          asList(
            asMap(
              detailsDetails['groupOrder'] ?? detailsDetails['group_order'],
            )['clients'],
          ).isNotEmpty ||
          asList(
            detailsData['groupClients'] ?? detailsData['group_clients'],
          ).isNotEmpty ||
          asList(
            detailsDetails['groupClients'] ?? detailsDetails['group_clients'],
          ).isNotEmpty;
      if (submittedNfc.anySelected && !hasGroupClientsInPayload) {
        final submittedLeft = dimsFrom(submittedDims, left: true);
        final submittedRight = dimsFrom(submittedDims, left: false);
        final submittedShape = firstNonEmpty(<Object?>[
          submittedNailPrefs['shape'],
          rootData['nail_shape'],
          rootData['nailShape'],
          request.nailShape,
        ]);
        final submittedLength = firstNonEmpty(<Object?>[
          submittedNailPrefs['length'],
          rootData['nail_length'],
          rootData['nailLength'],
          request.nailLength,
        ]);
        return _RequestNfcDetails(
          main: submittedNfc,
          groupBySlotIndex: const <int, _FingerNfcSelection>{},
          groupTabs: const <_OrderClientTabData>[],
          submittedClient: _OrderClientTabData(
            name: request.clientName.trim().isEmpty
                ? 'Client'
                : request.clientName.trim(),
            nailShape: submittedShape,
            nailLength: submittedLength,
            leftHand: hasDims(submittedLeft)
                ? nailDimsFromMap(submittedLeft)
                : request.leftHand,
            rightHand: hasDims(submittedRight)
                ? nailDimsFromMap(submittedRight)
                : request.rightHand,
            nfc: submittedNfc,
          ),
        );
      }
      final detailsSnapshot = asMap(
        detailsData['clientProfileSnapshot'] ??
            detailsData['client_profile_snapshot'],
      );
      final rootSnapshot = asMap(
        rootData['clientProfileSnapshot'] ??
            rootData['client_profile_snapshot'],
      );
      final detailsDetailsPayload = asMap(detailsDetails['payload']);
      final rootDetailsPayload = asMap(rootDetails['payload']);
      final detailsDetailsRequestDetails = asMap(
        detailsDetails['requestDetails'] ?? detailsDetails['request_details'],
      );
      final rootDetailsRequestDetails = asMap(
        rootDetails['requestDetails'] ?? rootDetails['request_details'],
      );
      final detailsDetailsOrderData = asMap(
        detailsDetails['order'] ??
            detailsDetails['orderData'] ??
            detailsDetails['order_data'],
      );
      final rootDetailsOrderData = asMap(
        rootDetails['order'] ??
            rootDetails['orderData'] ??
            rootDetails['order_data'],
      );
      final detailsDataJsonRequestDetails = asMap(
        detailsDataJson['requestDetails'] ?? detailsDataJson['request_details'],
      );
      final rootDataJsonRequestDetails = asMap(
        rootDataJson['requestDetails'] ?? rootDataJson['request_details'],
      );
      final detailsDataJsonOrderData = asMap(
        detailsDataJson['order'] ??
            detailsDataJson['orderData'] ??
            detailsDataJson['order_data'],
      );
      final rootDataJsonOrderData = asMap(
        rootDataJson['order'] ??
            rootDataJson['orderData'] ??
            rootDataJson['order_data'],
      );
      final detailsDetailsSnapshot = asMap(
        detailsDetails['clientProfileSnapshot'] ??
            detailsDetails['client_profile_snapshot'],
      );
      final rootDetailsSnapshot = asMap(
        rootDetails['clientProfileSnapshot'] ??
            rootDetails['client_profile_snapshot'],
      );
      final detailsDataJsonSnapshot = asMap(
        detailsDataJson['clientProfileSnapshot'] ??
            detailsDataJson['client_profile_snapshot'],
      );
      final rootDataJsonSnapshot = asMap(
        rootDataJson['clientProfileSnapshot'] ??
            rootDataJson['client_profile_snapshot'],
      );

      final mainCandidates = <Map<String, dynamic>>[
        rootData,
        detailsData,
        rootPayload,
        detailsPayload,
        rootDetails,
        detailsDetails,
        rootDataJson,
        detailsDataJson,
        rootRequestDetails,
        detailsRequestDetails,
        rootOrderData,
        detailsOrderData,
        asMap(rootData['nfc']),
        asMap(detailsData['nfc']),
        asMap(rootPayload['nfc']),
        asMap(detailsPayload['nfc']),
        asMap(rootDetails['nfc']),
        asMap(detailsDetails['nfc']),
        asMap(rootDataJson['nfc']),
        asMap(detailsDataJson['nfc']),
        asMap(rootRequestDetails['nfc']),
        asMap(detailsRequestDetails['nfc']),
        asMap(rootOrderData['nfc']),
        asMap(detailsOrderData['nfc']),
        asMap(rootData['nfcSelection'] ?? rootData['nfc_selection']),
        asMap(detailsData['nfcSelection'] ?? detailsData['nfc_selection']),
        asMap(rootPayload['nfcSelection'] ?? rootPayload['nfc_selection']),
        asMap(
          detailsPayload['nfcSelection'] ?? detailsPayload['nfc_selection'],
        ),
        asMap(
          asMap(
            detailsData['nailPreferences'] ?? detailsData['nail_preferences'],
          )['dimensions'],
        ),
        asMap(
          asMap(
            rootData['nailPreferences'] ?? rootData['nail_preferences'],
          )['dimensions'],
        ),
        asMap(
          asMap(
            detailsDetails['nailPreferences'] ??
                detailsDetails['nail_preferences'],
          )['dimensions'],
        ),
        asMap(
          asMap(
            rootDetails['nailPreferences'] ?? rootDetails['nail_preferences'],
          )['dimensions'],
        ),
        asMap(
          asMap(
            detailsDataJson['nailPreferences'] ??
                detailsDataJson['nail_preferences'],
          )['dimensions'],
        ),
        asMap(
          asMap(
            rootDataJson['nailPreferences'] ?? rootDataJson['nail_preferences'],
          )['dimensions'],
        ),
        asMap(
          asMap(
            detailsRequestDetails['nailPreferences'] ??
                detailsRequestDetails['nail_preferences'],
          )['dimensions'],
        ),
        asMap(
          asMap(
            rootRequestDetails['nailPreferences'] ??
                rootRequestDetails['nail_preferences'],
          )['dimensions'],
        ),
        asMap(
          asMap(
            detailsDetailsRequestDetails['nailPreferences'] ??
                detailsDetailsRequestDetails['nail_preferences'],
          )['dimensions'],
        ),
        asMap(
          asMap(
            rootDetailsRequestDetails['nailPreferences'] ??
                rootDetailsRequestDetails['nail_preferences'],
          )['dimensions'],
        ),
        asMap(
          asMap(
            detailsDataJsonRequestDetails['nailPreferences'] ??
                detailsDataJsonRequestDetails['nail_preferences'],
          )['dimensions'],
        ),
        asMap(
          asMap(
            rootDataJsonRequestDetails['nailPreferences'] ??
                rootDataJsonRequestDetails['nail_preferences'],
          )['dimensions'],
        ),
        asMap(
          asMap(
            detailsPayload['nailPreferences'] ??
                detailsPayload['nail_preferences'],
          )['dimensions'],
        ),
        asMap(
          asMap(
            rootPayload['nailPreferences'] ?? rootPayload['nail_preferences'],
          )['dimensions'],
        ),
        asMap(
          asMap(
            detailsDetailsPayload['nailPreferences'] ??
                detailsDetailsPayload['nail_preferences'],
          )['dimensions'],
        ),
        asMap(
          asMap(
            rootDetailsPayload['nailPreferences'] ??
                rootDetailsPayload['nail_preferences'],
          )['dimensions'],
        ),
        asMap(
          asMap(
            detailsSnapshot['nailPreferences'] ??
                detailsSnapshot['nail_preferences'],
          )['dimensions'],
        ),
        asMap(
          asMap(
            rootSnapshot['nailPreferences'] ?? rootSnapshot['nail_preferences'],
          )['dimensions'],
        ),
        asMap(
          asMap(
            detailsDetailsSnapshot['nailPreferences'] ??
                detailsDetailsSnapshot['nail_preferences'],
          )['dimensions'],
        ),
        asMap(
          asMap(
            rootDetailsSnapshot['nailPreferences'] ??
                rootDetailsSnapshot['nail_preferences'],
          )['dimensions'],
        ),
        asMap(
          asMap(
            detailsDataJsonSnapshot['nailPreferences'] ??
                detailsDataJsonSnapshot['nail_preferences'],
          )['dimensions'],
        ),
        asMap(
          asMap(
            rootDataJsonSnapshot['nailPreferences'] ??
                rootDataJsonSnapshot['nail_preferences'],
          )['dimensions'],
        ),
        asMap(
          asMap(
            detailsOrderData['nailPreferences'] ??
                detailsOrderData['nail_preferences'],
          )['dimensions'],
        ),
        asMap(
          asMap(
            rootOrderData['nailPreferences'] ??
                rootOrderData['nail_preferences'],
          )['dimensions'],
        ),
        asMap(
          asMap(
            detailsDetailsOrderData['nailPreferences'] ??
                detailsDetailsOrderData['nail_preferences'],
          )['dimensions'],
        ),
        asMap(
          asMap(
            rootDetailsOrderData['nailPreferences'] ??
                rootDetailsOrderData['nail_preferences'],
          )['dimensions'],
        ),
        asMap(
          asMap(
            detailsDataJsonOrderData['nailPreferences'] ??
                detailsDataJsonOrderData['nail_preferences'],
          )['dimensions'],
        ),
        asMap(
          asMap(
            rootDataJsonOrderData['nailPreferences'] ??
                rootDataJsonOrderData['nail_preferences'],
          )['dimensions'],
        ),
        asMap(
          asMap(
            detailsData['apiNailMeasurements'] ??
                detailsData['api_nail_measurements'],
          )['dimensions'],
        ),
        asMap(
          asMap(
            rootData['apiNailMeasurements'] ??
                rootData['api_nail_measurements'],
          )['dimensions'],
        ),
        asMap(
          asMap(
            detailsDetails['apiNailMeasurements'] ??
                detailsDetails['api_nail_measurements'],
          )['dimensions'],
        ),
        asMap(
          asMap(
            rootDetails['apiNailMeasurements'] ??
                rootDetails['api_nail_measurements'],
          )['dimensions'],
        ),
        asMap(
          asMap(
            detailsDataJson['apiNailMeasurements'] ??
                detailsDataJson['api_nail_measurements'],
          )['dimensions'],
        ),
        asMap(
          asMap(
            rootDataJson['apiNailMeasurements'] ??
                rootDataJson['api_nail_measurements'],
          )['dimensions'],
        ),
        asMap(detailsData['dimensions']),
        asMap(rootData['dimensions']),
        asMap(detailsDetails['dimensions']),
        asMap(rootDetails['dimensions']),
        asMap(detailsDataJson['dimensions']),
        asMap(rootDataJson['dimensions']),
      ];

      bool truthy(Object? value) {
        if (value is bool) return value;
        if (value is num) return value != 0;
        final text = (value ?? '').toString().trim().toLowerCase();
        return text == 'true' ||
            text == 'yes' ||
            text == '1' ||
            text == 'selected' ||
            text == 'requested' ||
            text == 'enabled';
      }

      bool containsSelectedNfcCheckbox(Object? value) {
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

      bool requestHasNfc(Map<String, dynamic> source) {
        final summary = asMap(source['summary']);
        final nfc = asMap(source['nfc']);
        return truthy(source['nfcRequested']) ||
            truthy(source['nfcSelected']) ||
            truthy(source['hasNfc']) ||
            truthy(source['nfcRequest']) ||
            truthy(source['nfcEnabled']) ||
            truthy(source['requiresNfcEligibleClient']) ||
            truthy(source['nfc_request']) ||
            truthy(source['nfc_enabled']) ||
            truthy(source['requires_nfc_eligible_client']) ||
            truthy(source['nfc_requested']) ||
            truthy(source['nfc_selected']) ||
            truthy(source['has_nfc']) ||
            truthy(summary['nfcRequested']) ||
            truthy(summary['nfcSelected']) ||
            truthy(summary['hasNfc']) ||
            truthy(summary['nfcRequest']) ||
            truthy(summary['nfcEnabled']) ||
            truthy(summary['requiresNfcEligibleClient']) ||
            truthy(summary['nfc_request']) ||
            truthy(summary['nfc_enabled']) ||
            truthy(summary['requires_nfc_eligible_client']) ||
            truthy(summary['nfc_requested']) ||
            truthy(summary['nfc_selected']) ||
            truthy(summary['has_nfc']) ||
            truthy(nfc['requested']) ||
            truthy(nfc['selected']) ||
            truthy(nfc['hasNfc']) ||
            truthy(nfc['nfcRequest']) ||
            truthy(nfc['nfcEnabled']) ||
            truthy(nfc['requiresNfcEligibleClient']) ||
            truthy(nfc['nfc_request']) ||
            truthy(nfc['nfc_enabled']) ||
            truthy(nfc['requires_nfc_eligible_client']) ||
            truthy(nfc['has_nfc']) ||
            containsSelectedNfcCheckbox(source);
      }

      var main = submittedNfc.anySelected
          ? submittedNfc
          : _FingerNfcSelection.empty();
      for (final candidate in mainCandidates) {
        final parsed = _FingerNfcSelection.fromDimensionsMap(candidate);
        if (parsed.anySelected) {
          main = parsed;
          break;
        }
      }
      if (!main.anySelected &&
          (requestHasNfc(rootData) || requestHasNfc(detailsData))) {
        for (final candidate in mainCandidates) {
          final parsed = _FingerNfcSelection.fromEligibleDimensionsMap(
            candidate,
          );
          if (parsed.anySelected) {
            main = parsed;
            break;
          }
        }
        if (!main.anySelected) {
          final modelDims = <String, dynamic>{
            'lThumb': request.leftHand.thumb,
            'lIndex': request.leftHand.index,
            'lMiddle': request.leftHand.middle,
            'lRing': request.leftHand.ring,
            'lPinky': request.leftHand.pinky,
            'rThumb': request.rightHand.thumb,
            'rIndex': request.rightHand.index,
            'rMiddle': request.rightHand.middle,
            'rRing': request.rightHand.ring,
            'rPinky': request.rightHand.pinky,
          };
          final parsed = _FingerNfcSelection.fromEligibleDimensionsMap(
            modelDims,
          );
          if (parsed.anySelected) main = parsed;
        }
      }

      final groupBySlot = <int, _FingerNfcSelection>{};
      final groupTabs = <_OrderClientTabData>[];
      final seenClientKeys = <String>{};

      Future<Map<String, dynamic>> loadClientProfile({
        required String email,
        required String clientId,
      }) async {
        final cleanEmail = email.trim().toLowerCase();
        final cleanId = clientId.trim();
        Future<Map<String, dynamic>> queryTable(String table) async {
          try {
            Map<String, dynamic>? row;
            if (cleanId.isNotEmpty) {
              row = await Supabase.instance.client
                  .from(table)
                  .select()
                  .eq('id', cleanId)
                  .maybeSingle();
              if (row != null && row.isNotEmpty) return row;
            }
            if (cleanEmail.isNotEmpty) {
              row = await Supabase.instance.client
                  .from(table)
                  .select()
                  .eq('email', cleanEmail)
                  .maybeSingle();
              if (row != null && row.isNotEmpty) return row;
            }
          } catch (_) {}
          return const <String, dynamic>{};
        }

        final clientArtist = await queryTable('client_artist');
        if (clientArtist.isNotEmpty) return clientArtist;
        return queryTable('client');
      }

      Map<String, dynamic> profileNailSource(Map<String, dynamic> profileRow) {
        final saved = asMap(
          profileRow['savedNails'] ?? profileRow['saved_nails'],
        );
        if (saved.isNotEmpty) return saved;
        final draft = asMap(
          profileRow['draftNails'] ?? profileRow['draft_nails'],
        );
        if (draft.isNotEmpty) return draft;
        final nailPrefs = asMap(
          profileRow['nailPreferences'] ?? profileRow['nail_preferences'],
        );
        if (nailPrefs.isNotEmpty) return nailPrefs;
        final client = asMap(profileRow['client']);
        final clientPrefs = asMap(
          client['nailPreferences'] ?? client['nail_preferences'],
        );
        if (clientPrefs.isNotEmpty) return clientPrefs;
        return const <String, dynamic>{};
      }

      Future<_OrderClientTabData?> buildProfileTab({
        required int slotIndex,
        required String fallbackName,
        required String email,
        required String clientId,
        required _FingerNfcSelection nfc,
      }) async {
        final profileRow = await loadClientProfile(
          email: email,
          clientId: clientId,
        );
        if (profileRow.isEmpty) return null;
        final basic = asMap(profileRow['basic']);
        final profile = asMap(profileRow['profile']);
        final client = asMap(profileRow['client']);
        final nailSource = profileNailSource(profileRow);
        final dimensions = asMap(nailSource['dimensions']);
        final left = firstDims(<Object?>[
          nailSource['leftHandDimensions'],
          nailSource['left_hand_dimensions'],
          dimensions,
          profileRow['dimensions'],
          client['dimensions'],
        ], left: true);
        final right = firstDims(<Object?>[
          nailSource['rightHandDimensions'],
          nailSource['right_hand_dimensions'],
          dimensions,
          profileRow['dimensions'],
          client['dimensions'],
        ], left: false);
        final hasDimensions =
            left.values.any((v) => v.trim().isNotEmpty) ||
            right.values.any((v) => v.trim().isNotEmpty);
        final shape = firstNonEmpty(<Object?>[
          nailSource['shape'],
          nailSource['nailShape'],
          nailSource['nail_shape'],
          profileRow['nailShape'],
          profileRow['nail_shape'],
          client['nailShape'],
          client['nail_shape'],
        ]);
        final length = firstNonEmpty(<Object?>[
          nailSource['length'],
          nailSource['nailLength'],
          nailSource['nail_length'],
          profileRow['nailLength'],
          profileRow['nail_length'],
          client['nailLength'],
          client['nail_length'],
        ]);
        if (!hasDimensions && shape.isEmpty && length.isEmpty) return null;
        return _OrderClientTabData(
          slotIndex: slotIndex,
          name: firstNonEmpty(<Object?>[
            fallbackName,
            basic['name'],
            basic['displayName'],
            profile['name'],
            profile['displayName'],
            profileRow['name'],
            profileRow['displayName'],
            clientId,
            email,
          ], fallback: 'Client'),
          nailShape: shape,
          nailLength: length,
          leftHand: nailDimsFromMap(left),
          rightHand: nailDimsFromMap(right),
          nfc: nfc,
        );
      }

      Future<void> addGroupClientsFrom(Map<String, dynamic> source) async {
        final payload = asMap(source['payload']);
        final details = asMap(source['details']);
        final requestDetails = asMap(
          source['requestDetails'] ?? source['request_details'],
        );
        final orderData = asMap(
          source['order'] ?? source['orderData'] ?? source['order_data'],
        );
        final groupSources = <Object?>[
          asMap(source['groupOrder'] ?? source['group_order'])['clients'],
          source['groupClients'],
          source['group_clients'],
          asMap(details['groupOrder'] ?? details['group_order'])['clients'],
          details['groupClients'],
          details['group_clients'],
          payload['groupClients'],
          payload['group_clients'],
          asMap(payload['groupOrder'] ?? payload['group_order'])['clients'],
          requestDetails['groupClients'],
          requestDetails['group_clients'],
          asMap(
            requestDetails['groupOrder'] ?? requestDetails['group_order'],
          )['clients'],
          orderData['groupClients'],
          orderData['group_clients'],
          asMap(orderData['groupOrder'] ?? orderData['group_order'])['clients'],
        ];

        for (final sourceList in groupSources) {
          for (final rawClient in asList(sourceList)) {
            final client = asMap(rawClient);
            if (client.isEmpty) {
              final text = (rawClient ?? '').toString().trim();
              if (text.isEmpty || text.toLowerCase() == 'null') continue;
              final slotIndex = groupTabs.length + 1;
              final email = text.contains('@') ? text.toLowerCase() : '';
              final key = email.isNotEmpty
                  ? email
                  : 'label:${text.toLowerCase()}';
              if (!seenClientKeys.add(key)) continue;
              final tab = await buildProfileTab(
                slotIndex: slotIndex,
                fallbackName: text,
                email: email,
                clientId: '',
                nfc: groupBySlot[slotIndex] ?? _FingerNfcSelection.empty(),
              );
              if (tab != null) {
                groupTabs.add(tab);
              } else {
                groupTabs.add(
                  _OrderClientTabData(
                    slotIndex: slotIndex,
                    name: text,
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
                    nfc: groupBySlot[slotIndex] ?? _FingerNfcSelection.empty(),
                  ),
                );
              }
              continue;
            }

            final slotIndex =
                _parseInt(
                  client['slotIndex'] ??
                      client['slot_index'] ??
                      client['index'] ??
                      client['position'],
                ) ??
                (groupTabs.length + 1);

            final email = firstNonEmpty(<Object?>[
              client['clientEmail'],
              client['client_email'],
              client['email'],
            ]).toLowerCase();
            final clientId = firstNonEmpty(<Object?>[
              client['clientId'],
              client['client_id'],
              client['id'],
              client['uid'],
            ]);
            final key = email.isNotEmpty
                ? email
                : (clientId.isNotEmpty ? clientId : 'slot_$slotIndex');
            if (!seenClientKeys.add(key)) continue;

            final profileRow = await loadClientProfile(
              email: email,
              clientId: clientId,
            );
            final profileNails = profileNailSource(profileRow);

            final savedNails = asMap(
              client['savedNails'] ?? client['saved_nails'],
            );
            final draftNails = asMap(
              client['draftNails'] ?? client['draft_nails'],
            );
            final nailPreferences = asMap(
              client['nailPreferences'] ?? client['nail_preferences'],
            );
            final nailSource = savedNails.isNotEmpty
                ? savedNails
                : (draftNails.isNotEmpty
                      ? draftNails
                      : (nailPreferences.isNotEmpty
                            ? nailPreferences
                            : profileNails));

            final left = firstDims(<Object?>[
              client['leftHandDimensions'],
              client['left_hand_dimensions'],
              nailSource['leftHandDimensions'],
              nailSource['left_hand_dimensions'],
              nailSource['dimensions'],
              client['dimensions'],
              profileNails['leftHandDimensions'],
              profileNails['left_hand_dimensions'],
              profileNails['dimensions'],
              profileRow['dimensions'],
            ], left: true);
            final right = firstDims(<Object?>[
              client['rightHandDimensions'],
              client['right_hand_dimensions'],
              nailSource['rightHandDimensions'],
              nailSource['right_hand_dimensions'],
              nailSource['dimensions'],
              client['dimensions'],
              profileNails['rightHandDimensions'],
              profileNails['right_hand_dimensions'],
              profileNails['dimensions'],
              profileRow['dimensions'],
            ], left: false);

            final requestPayload = asMap(client['payload']);
            final requestDetailsMap = asMap(
              client['requestDetails'] ?? client['request_details'],
            );
            final orderMap = asMap(
              client['order'] ?? client['orderData'] ?? client['order_data'],
            );
            final candidateMaps = <Map<String, dynamic>>[
              client,
              asMap(client['savedNails'] ?? client['saved_nails']),
              asMap(client['draftNails'] ?? client['draft_nails']),
              asMap(client['nailPreferences'] ?? client['nail_preferences']),
              requestDetailsMap,
              requestPayload,
              orderMap,
              asMap(
                asMap(
                  client['savedNails'] ?? client['saved_nails'],
                )['dimensions'],
              ),
              asMap(
                asMap(
                  client['draftNails'] ?? client['draft_nails'],
                )['dimensions'],
              ),
              asMap(
                asMap(
                  client['nailPreferences'] ?? client['nail_preferences'],
                )['dimensions'],
              ),
              asMap(
                asMap(
                  requestDetailsMap['nailPreferences'] ??
                      requestDetailsMap['nail_preferences'],
                )['dimensions'],
              ),
              asMap(
                asMap(
                  requestPayload['nailPreferences'] ??
                      requestPayload['nail_preferences'],
                )['dimensions'],
              ),
              asMap(
                asMap(
                  orderMap['nailPreferences'] ?? orderMap['nail_preferences'],
                )['dimensions'],
              ),
              asMap(client['dimensions']),
              asMap(profileNails['dimensions']),
            ];
            var nfc = _FingerNfcSelection.empty();
            for (final candidate in candidateMaps) {
              final parsed = _FingerNfcSelection.fromDimensionsMap(candidate);
              if (parsed.anySelected) {
                nfc = parsed;
                groupBySlot[slotIndex] = parsed;
                break;
              }
            }
            if (!nfc.anySelected &&
                (requestHasNfc(client) ||
                    requestHasNfc(rootData) ||
                    requestHasNfc(detailsData))) {
              for (final candidate in candidateMaps) {
                final parsed = _FingerNfcSelection.fromEligibleDimensionsMap(
                  candidate,
                );
                if (parsed.anySelected) {
                  nfc = parsed;
                  groupBySlot[slotIndex] = parsed;
                  break;
                }
              }
            }

            final profileBasic = asMap(profileRow['basic']);
            final profileProfile = asMap(profileRow['profile']);
            final name = firstNonEmpty(<Object?>[
              client['clientName'],
              client['client_name'],
              client['name'],
              client['displayName'],
              profileBasic['name'],
              profileBasic['displayName'],
              profileProfile['name'],
              profileProfile['displayName'],
              clientId,
            ], fallback: 'Client $slotIndex');

            groupTabs.add(
              _OrderClientTabData(
                slotIndex: slotIndex,
                name: name,
                nailShape: firstNonEmpty(<Object?>[
                  nailSource['shape'],
                  nailSource['nailShape'],
                  nailSource['nail_shape'],
                  client['nailShape'],
                  client['nail_shape'],
                  profileNails['shape'],
                  profileNails['nailShape'],
                  profileNails['nail_shape'],
                ]),
                nailLength: firstNonEmpty(<Object?>[
                  nailSource['length'],
                  nailSource['nailLength'],
                  nailSource['nail_length'],
                  client['nailLength'],
                  client['nail_length'],
                  profileNails['length'],
                  profileNails['nailLength'],
                  profileNails['nail_length'],
                ]),
                leftHand: nailDimsFromMap(left),
                rightHand: nailDimsFromMap(right),
                nfc: nfc,
              ),
            );
          }
        }
      }

      await addGroupClientsFrom(rootData);
      await addGroupClientsFrom(detailsData);

      bool nailDimsHasValues(NailDimensionsV2 dims) {
        return <String>[
          dims.thumb,
          dims.index,
          dims.middle,
          dims.ring,
          dims.pinky,
        ].any((v) => v.trim().isNotEmpty && v.trim() != '-');
      }

      Future<void> addRequestModelGroupClients() async {
        for (final client in request.groupClients) {
          final slotIndex = client.slotIndex <= 0
              ? (groupTabs.length + 1)
              : client.slotIndex;
          final email = client.clientEmail.trim().toLowerCase();
          final clientId = client.clientId.trim();
          final key = email.isNotEmpty
              ? email
              : (clientId.isNotEmpty ? clientId : 'slot_$slotIndex');
          if (!seenClientKeys.add(key)) continue;

          final profileTab = await buildProfileTab(
            slotIndex: slotIndex,
            fallbackName: client.clientName,
            email: email,
            clientId: clientId,
            nfc: groupBySlot[slotIndex] ?? _FingerNfcSelection.empty(),
          );

          final hasModelDimensions =
              nailDimsHasValues(client.leftHand) ||
              nailDimsHasValues(client.rightHand);
          final hasModelShapeLength =
              client.nailShape.trim().isNotEmpty ||
              client.nailLength.trim().isNotEmpty;

          if (!hasModelDimensions && !hasModelShapeLength) {
            if (profileTab != null) {
              groupTabs.add(profileTab);
            }
            continue;
          }

          groupTabs.add(
            _OrderClientTabData(
              slotIndex: slotIndex,
              name: firstNonEmpty(<Object?>[
                client.clientName,
                profileTab?.name,
                clientId,
                email,
              ], fallback: 'Client $slotIndex'),
              nailShape: firstNonEmpty(<Object?>[
                client.nailShape,
                profileTab?.nailShape,
              ]),
              nailLength: firstNonEmpty(<Object?>[
                client.nailLength,
                profileTab?.nailLength,
              ]),
              leftHand: hasModelDimensions
                  ? client.leftHand
                  : profileTab?.leftHand,
              rightHand: hasModelDimensions
                  ? client.rightHand
                  : profileTab?.rightHand,
              nfc:
                  groupBySlot[slotIndex] ??
                  profileTab?.nfc ??
                  _FingerNfcSelection.empty(),
            ),
          );
        }
      }

      Future<void> addSelectedGroupClientEmails() async {
        final selectedEmailSources = <Object?>[
          request.selectedGroupClientEmails,
          rootData['selectedGroupClientEmails'],
          rootData['selected_group_client_emails'],
          detailsData['selectedGroupClientEmails'],
          detailsData['selected_group_client_emails'],
          rootPayload['selectedGroupClientEmails'],
          rootPayload['selected_group_client_emails'],
          detailsPayload['selectedGroupClientEmails'],
          detailsPayload['selected_group_client_emails'],
          rootOrderData['selectedGroupClientEmails'],
          rootOrderData['selected_group_client_emails'],
          detailsOrderData['selectedGroupClientEmails'],
          detailsOrderData['selected_group_client_emails'],
        ];
        final selectedEmails = <String>{
          for (final source in selectedEmailSources)
            for (final raw in asList(source))
              (raw ?? '').toString().trim().toLowerCase(),
        }..removeWhere((value) => value.isEmpty || value == 'null');

        for (final email in selectedEmails) {
          if (!seenClientKeys.add(email)) continue;
          final matchedClient = request.groupClients
              .cast<GroupOrderClientV2?>()
              .firstWhere(
                (client) =>
                    client != null &&
                    client.clientEmail.trim().toLowerCase() == email,
                orElse: () => null,
              );
          final slotIndex = matchedClient?.slotIndex ?? 0;
          final tab = await buildProfileTab(
            slotIndex: slotIndex,
            fallbackName: email,
            email: email,
            clientId: '',
            nfc: slotIndex > 0
                ? (groupBySlot[slotIndex] ?? _FingerNfcSelection.empty())
                : _FingerNfcSelection.empty(),
          );
          if (tab != null) {
            groupTabs.add(tab);
          } else {
            groupTabs.add(
              _OrderClientTabData(
                slotIndex: slotIndex,
                name: email,
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
                nfc: _FingerNfcSelection.empty(),
              ),
            );
          }
        }
      }

      await addRequestModelGroupClients();
      await addSelectedGroupClientEmails();

      final submittedRequestNailSources = <Map<String, dynamic>>[
        asMap(
          detailsData['nailPreferences'] ?? detailsData['nail_preferences'],
        ),
        asMap(
          detailsRequestDetails['nailPreferences'] ??
              detailsRequestDetails['nail_preferences'],
        ),
        asMap(
          detailsPayload['nailPreferences'] ??
              detailsPayload['nail_preferences'],
        ),
        asMap(rootData['nailPreferences'] ?? rootData['nail_preferences']),
        asMap(
          rootRequestDetails['nailPreferences'] ??
              rootRequestDetails['nail_preferences'],
        ),
        asMap(
          rootPayload['nailPreferences'] ?? rootPayload['nail_preferences'],
        ),
      ].where((entry) => entry.isNotEmpty).toList(growable: false);

      final submittedLeft = firstDims(<Object?>[
        ...submittedRequestNailSources,
        detailsRequestDetails['leftHandDimensions'],
        detailsRequestDetails['left_hand_dimensions'],
        detailsRequestDetails['dimensions'],
        detailsOrderData['leftHandDimensions'],
        detailsOrderData['left_hand_dimensions'],
        detailsOrderData['dimensions'],
        detailsData['leftHandDimensions'],
        detailsData['left_hand_dimensions'],
        detailsData['dimensions'],
        rootRequestDetails['leftHandDimensions'],
        rootRequestDetails['left_hand_dimensions'],
        rootRequestDetails['dimensions'],
        rootOrderData['leftHandDimensions'],
        rootOrderData['left_hand_dimensions'],
        rootOrderData['dimensions'],
        rootData['leftHandDimensions'],
        rootData['left_hand_dimensions'],
        rootData['dimensions'],
      ], left: true);
      final submittedRight = firstDims(<Object?>[
        ...submittedRequestNailSources,
        detailsRequestDetails['rightHandDimensions'],
        detailsRequestDetails['right_hand_dimensions'],
        detailsRequestDetails['dimensions'],
        detailsOrderData['rightHandDimensions'],
        detailsOrderData['right_hand_dimensions'],
        detailsOrderData['dimensions'],
        detailsData['rightHandDimensions'],
        detailsData['right_hand_dimensions'],
        detailsData['dimensions'],
        rootRequestDetails['rightHandDimensions'],
        rootRequestDetails['right_hand_dimensions'],
        rootRequestDetails['dimensions'],
        rootOrderData['rightHandDimensions'],
        rootOrderData['right_hand_dimensions'],
        rootOrderData['dimensions'],
        rootData['rightHandDimensions'],
        rootData['right_hand_dimensions'],
        rootData['dimensions'],
      ], left: false);

      final submittedShape = firstNonEmpty(<Object?>[
        for (final source in submittedRequestNailSources) ...<Object?>[
          source['shape'],
          source['nailShape'],
          source['nail_shape'],
        ],
        detailsRequestDetails['nailShape'],
        detailsRequestDetails['nail_shape'],
        detailsOrderData['nailShape'],
        detailsOrderData['nail_shape'],
        detailsData['nailShape'],
        detailsData['nail_shape'],
        rootRequestDetails['nailShape'],
        rootRequestDetails['nail_shape'],
        rootOrderData['nailShape'],
        rootOrderData['nail_shape'],
        rootData['nailShape'],
        rootData['nail_shape'],
        request.nailShape,
      ]);

      final submittedLength = firstNonEmpty(<Object?>[
        for (final source in submittedRequestNailSources) ...<Object?>[
          source['length'],
          source['nailLength'],
          source['nail_length'],
        ],
        detailsRequestDetails['nailLength'],
        detailsRequestDetails['nail_length'],
        detailsOrderData['nailLength'],
        detailsOrderData['nail_length'],
        detailsData['nailLength'],
        detailsData['nail_length'],
        rootRequestDetails['nailLength'],
        rootRequestDetails['nail_length'],
        rootOrderData['nailLength'],
        rootOrderData['nail_length'],
        rootData['nailLength'],
        rootData['nail_length'],
        request.nailLength,
      ]);

      final rootDetailsContainer = asMap(rootData['details']);
      final directRootSubmittedNfc = _FingerNfcSelection.fromDimensionsMap(
        asMap(
          asMap(
            rootDetailsContainer['nailPreferences'] ??
                rootDetailsContainer['nail_preferences'],
          )['dimensions'],
        ),
      );
      final directRootGroupBySlot = <int, _FingerNfcSelection>{};
      for (final rawClient in asList(
        asMap(
          rootDetailsContainer['groupOrder'] ??
              rootDetailsContainer['group_order'],
        )['clients'],
      )) {
        final client = asMap(rawClient);
        if (client.isEmpty) continue;
        final slotIndex =
            _parseInt(
              client['slotIndex'] ??
                  client['slot_index'] ??
                  client['index'] ??
                  client['position'],
            ) ??
            0;
        if (slotIndex <= 0) continue;
        final clientNfc = _FingerNfcSelection.fromDimensionsMap(
          asMap(
                asMap(
                  client['savedNails'] ?? client['saved_nails'],
                )['dimensions'],
              ).isNotEmpty
              ? asMap(
                  asMap(
                    client['savedNails'] ?? client['saved_nails'],
                  )['dimensions'],
                )
              : asMap(
                  asMap(
                    client['draftNails'] ?? client['draft_nails'],
                  )['dimensions'],
                ),
        );
        if (clientNfc.anySelected) {
          directRootGroupBySlot[slotIndex] = clientNfc;
        }
      }

      final hasSubmittedSnapshotDimensions =
          submittedLeft.values.any((v) => v.trim().isNotEmpty) ||
          submittedRight.values.any((v) => v.trim().isNotEmpty);
      final hasSubmittedSnapshotShapeLength =
          submittedShape.trim().isNotEmpty || submittedLength.trim().isNotEmpty;

      final submittedProfileTab = await buildProfileTab(
        slotIndex: 0,
        fallbackName: request.clientName,
        email: request.clientEmail,
        clientId: '',
        nfc: main,
      );

      NailDimensionsV2 mergeDims(
        Map<String, String> source,
        NailDimensionsV2? fallback,
        NailDimensionsV2 requestFallback,
      ) {
        String pick(String key, String requestValue, String? profileValue) {
          final value = (source[key] ?? '').trim();
          if (value.isNotEmpty) return value;
          final profile = (profileValue ?? '').trim();
          if (profile.isNotEmpty) return profile;
          return requestValue.trim();
        }

        return NailDimensionsV2(
          thumb: pick('thumb', requestFallback.thumb, fallback?.thumb),
          index: pick('index', requestFallback.index, fallback?.index),
          middle: pick('middle', requestFallback.middle, fallback?.middle),
          ring: pick('ring', requestFallback.ring, fallback?.ring),
          pinky: pick('pinky', requestFallback.pinky, fallback?.pinky),
        );
      }

      final submittedSnapshotTab =
          hasSubmittedSnapshotDimensions || hasSubmittedSnapshotShapeLength
          ? _OrderClientTabData(
              slotIndex: 0,
              name: firstNonEmpty(<Object?>[
                request.clientName,
                rootRequestDetails['clientName'],
                rootData['clientName'],
                request.clientEmail,
              ], fallback: 'Client'),
              nailShape: submittedShape.trim().isNotEmpty
                  ? submittedShape
                  : (submittedProfileTab?.nailShape ?? request.nailShape),
              nailLength: submittedLength.trim().isNotEmpty
                  ? submittedLength
                  : (submittedProfileTab?.nailLength ?? request.nailLength),
              leftHand: mergeDims(
                submittedLeft,
                submittedProfileTab?.leftHand,
                request.leftHand,
              ),
              rightHand: mergeDims(
                submittedRight,
                submittedProfileTab?.rightHand,
                request.rightHand,
              ),
              nfc: main,
            )
          : null;

      final sharedMain = _FingerNfcSelection.fromShared(sharedNfc.main);
      final mergedMain = directRootSubmittedNfc.anySelected
          ? directRootSubmittedNfc
          : (sharedMain.anySelected ? sharedMain : main);
      final mergedGroupBySlot = <int, _FingerNfcSelection>{
        ...groupBySlot,
        for (final entry in sharedNfc.groupBySlotIndex.entries)
          if (_FingerNfcSelection.fromShared(entry.value).anySelected)
            entry.key: _FingerNfcSelection.fromShared(entry.value),
        ...directRootGroupBySlot,
      };
      final normalizedGroupTabs = groupTabs
          .map(
            (tab) => _OrderClientTabData(
              slotIndex: tab.slotIndex,
              name: tab.name,
              nailShape: tab.nailShape,
              nailLength: tab.nailLength,
              leftHand: tab.leftHand,
              rightHand: tab.rightHand,
              nfc: tab.slotIndex > 0
                  ? (mergedGroupBySlot[tab.slotIndex] ?? tab.nfc)
                  : (mergedMain.anySelected ? mergedMain : tab.nfc),
            ),
          )
          .toList(growable: false);

      _OrderClientTabData? normalizedSubmittedClient;
      final sourceSubmittedClient = submittedSnapshotTab ?? submittedProfileTab;
      if (sourceSubmittedClient != null) {
        normalizedSubmittedClient = _OrderClientTabData(
          slotIndex: sourceSubmittedClient.slotIndex,
          name: sourceSubmittedClient.name,
          nailShape: sourceSubmittedClient.nailShape,
          nailLength: sourceSubmittedClient.nailLength,
          leftHand: sourceSubmittedClient.leftHand,
          rightHand: sourceSubmittedClient.rightHand,
          nfc: mergedMain.anySelected ? mergedMain : sourceSubmittedClient.nfc,
        );
      }

      return _RequestNfcDetails(
        main: mergedMain,
        groupBySlotIndex: mergedGroupBySlot,
        groupTabs: normalizedGroupTabs,
        submittedClient:
            normalizedSubmittedClient ??
            _OrderClientTabData(
              slotIndex: 0,
              name: request.clientName.trim().isEmpty
                  ? 'Client'
                  : request.clientName.trim(),
              nailShape: request.nailShape,
              nailLength: request.nailLength,
              leftHand: request.leftHand,
              rightHand: request.rightHand,
              nfc: mergedMain,
            ),
      );
    } catch (e, st) {
      debugPrint(
        'IN_REVIEW_GROUP_LOAD_ERROR request=${request.id} '
        'order=${request.orderNumber} error=$e',
      );
      debugPrintStack(stackTrace: st);
      return _RequestNfcDetails(
        main: _FingerNfcSelection.empty(),
        groupBySlotIndex: const <int, _FingerNfcSelection>{},
        submittedClient: _OrderClientTabData(
          slotIndex: 0,
          name: request.clientName.trim().isEmpty
              ? 'Client'
              : request.clientName.trim(),
          nailShape: request.nailShape,
          nailLength: request.nailLength,
          leftHand: request.leftHand,
          rightHand: request.rightHand,
          nfc: _FingerNfcSelection.empty(),
        ),
      );
    }
  }

  static int? _parseInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString().trim());
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).viewPadding.bottom;
    final maxH = MediaQuery.of(context).size.height * 0.92;
    final isGroupOrder = request.orderType == RequestOrderTypeV2.group;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxH),
        decoration: const BoxDecoration(
          color: AppColors.snow,
          borderRadius: BorderRadius.zero,
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              height: 5,
              width: 54,
              decoration: BoxDecoration(
                color: AppColors.blackCat.withValues(alpha: 0.12),
                borderRadius: BorderRadius.zero,
              ),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  _topHero(context),
                  const SizedBox(height: 10),
                  _softBox(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('Description'),
                        const SizedBox(height: 8),
                        Text(
                          _requestDescriptionText(),
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            fontSize: 14.5,
                            height: 1.35,
                            color: AppColors.blackCat.withValues(alpha: 0.90),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _companyBioBlock(),
                  const SizedBox(height: 10),
                  if (isGroupOrder) ...[
                    _softBox(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle('Client Measurements'),
                          const SizedBox(height: 10),
                          FutureBuilder<_RequestNfcDetails>(
                            future: _loadRequestedNfcDetails(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState !=
                                      ConnectionState.done &&
                                  !snapshot.hasData) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 24),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              }
                              final details =
                                  snapshot.data ?? _RequestNfcDetails.empty();
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [_groupOrderClientsTabs(details)],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    if (request.sourceCollection == 'Company_Custom_Requests')
                      _brandClientDetailsBlock(),
                    _sectionTitle('Nail Dimensions (mm)'),
                    const SizedBox(height: 10),
                    FutureBuilder<_RequestNfcDetails>(
                      future: _loadRequestedNfcDetails(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done &&
                            !snapshot.hasData) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        final nfc = snapshot.data ?? _RequestNfcDetails.empty();
                        final submittedClient =
                            nfc.submittedClient ??
                            _OrderClientTabData(
                              name: request.clientName.trim().isEmpty
                                  ? 'Client'
                                  : request.clientName.trim(),
                              nailShape: request.nailShape,
                              nailLength: request.nailLength,
                              leftHand: request.leftHand,
                              rightHand: request.rightHand,
                              nfc: nfc.main,
                            );
                        return Column(
                          children: [
                            LayoutBuilder(
                              builder: (context, c) {
                                final maxCardW = (c.maxWidth - 8) / 2;

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: maxCardW,
                                      child: _handCardCentered(
                                        'Left Hand',
                                        submittedClient.leftHand,
                                        nfc: submittedClient.nfc.left,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: maxCardW,
                                      child: _handCardCentered(
                                        'Right Hand',
                                        submittedClient.rightHand,
                                        nfc: submittedClient.nfc.right,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _softBoxCompact(
                                    Row(
                                      children: [
                                        Text(
                                          'Shape',
                                          style: TextStyle(
                                            color: AppColors.blackCat
                                                .withValues(alpha: 0.78),
                                            fontWeight: FontWeight.w400,
                                            fontSize: 14.5,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          submittedClient.nailShape
                                                  .trim()
                                                  .isEmpty
                                              ? '-'
                                              : submittedClient.nailShape,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14.5,
                                            color: AppColors.blackCat,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _softBoxCompact(
                                    Row(
                                      children: [
                                        Text(
                                          'Length',
                                          style: TextStyle(
                                            color: AppColors.blackCat
                                                .withValues(alpha: 0.78),
                                            fontWeight: FontWeight.w400,
                                            fontSize: 14.5,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          submittedClient.nailLength
                                                  .trim()
                                                  .isEmpty
                                              ? '-'
                                              : _prettyLength(
                                                  submittedClient.nailLength,
                                                ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14.5,
                                            color: AppColors.blackCat,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  _softBox(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(
                          request.sourceCollection == 'Company_Custom_Requests'
                              ? 'Uploaded Photo (Brand)'
                              : 'Uploaded Photos (Client)',
                        ),
                        const SizedBox(height: 10),
                        FutureBuilder<List<String>>(
                          future: _modalPhotoCandidates(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState !=
                                ConnectionState.done) {
                              return const SizedBox(
                                height: 120,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            final modalPhotos =
                                snapshot.data ?? const <String>[];
                            if (modalPhotos.isEmpty) {
                              return Row(
                                children: [
                                  Icon(
                                    Icons.image_outlined,
                                    color: AppColors.blackCat.withValues(
                                      alpha: 0.45,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    request.sourceCollection ==
                                            'Company_Custom_Requests'
                                        ? 'No photos uploaded by Brand'
                                        : 'No images uploaded',
                                    style: TextStyle(
                                      color: AppColors.blackCat.withValues(
                                        alpha: 0.82,
                                      ),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              );
                            }
                            return _photosGrid(context, modalPhotos);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + safeBottom),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 132,
                    height: 52,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.blackCat.withValues(
                          alpha: 0.16,
                        ),
                        foregroundColor: AppColors.blackCat,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                        side: BorderSide(
                          color: AppColors.blackCat.withValues(alpha: 0.30),
                        ),
                      ),
                      onPressed: onDecline,
                      child: Text(
                        declineLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontFamily: 'Arial',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 132,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blackCat,
                        foregroundColor: AppColors.snow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                        elevation: 0,
                      ),
                      onPressed: onAccept,
                      child: Text(
                        acceptLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontFamily: 'Arial',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _handCardCentered(
    String title,
    dynamic d, {
    Map<String, bool> nfc = const <String, bool>{},
  }) {
    return _softBox(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
                color: AppColors.blackCat,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _dimRow(
            'Thumb',
            _dimensionText(d, 'thumb'),
            nfcRequested: nfc['thumb'] == true,
          ),
          _dimRow(
            'Index',
            _dimensionText(d, 'index'),
            nfcRequested: nfc['index'] == true,
          ),
          _dimRow(
            'Middle',
            _dimensionText(d, 'middle'),
            nfcRequested: nfc['middle'] == true,
          ),
          _dimRow(
            'Ring',
            _dimensionText(d, 'ring'),
            nfcRequested: nfc['ring'] == true,
          ),
          _dimRow(
            'Pinky',
            _dimensionText(d, 'pinky'),
            nfcRequested: nfc['pinky'] == true,
          ),
        ],
      ),
    );
  }

  static String _dimensionText(dynamic source, String key) {
    String clean(Object? value) {
      final text = (value ?? '').toString().trim();
      return text == 'null' ? '' : text;
    }

    if (source is Map) {
      final map = source.map((k, v) => MapEntry(k.toString(), v));
      final upper = key[0].toUpperCase() + key.substring(1);
      final candidates = <String>[
        key,
        '${key}_width',
        '${key}Width',
        'left_$key',
        'right_$key',
        'left$upper',
        'right$upper',
        'l${key[0].toUpperCase()}${key.substring(1)}',
        'r${key[0].toUpperCase()}${key.substring(1)}',
      ];
      for (final candidate in candidates) {
        final value = clean(map[candidate]);
        if (value.isNotEmpty) return value;
      }
      final nested = map['dimensions'];
      if (nested is Map) return _dimensionText(nested, key);
      return '-';
    }

    try {
      switch (key) {
        case 'thumb':
          return clean(source.thumb);
        case 'index':
          return clean(source.index);
        case 'middle':
          return clean(source.middle);
        case 'ring':
          return clean(source.ring);
        case 'pinky':
          return clean(source.pinky);
      }
    } catch (_) {}
    return '-';
  }

  static Widget _sectionTitle(String t) => Text(
    t,
    style: const TextStyle(
      fontWeight: FontWeight.w800,
      fontSize: 15,
      color: AppColors.blackCat,
    ),
  );

  static Widget _softBox(Widget child) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
      ),
      child: child,
    );
  }

  static Widget _softBoxCompact(Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
      ),
      child: child,
    );
  }

  static Widget _nailDimensionsPanel({
    required dynamic leftHand,
    required dynamic rightHand,
    required String nailShape,
    required String nailLength,
    Map<String, bool> leftNfc = const <String, bool>{},
    Map<String, bool> rightNfc = const <String, bool>{},
  }) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
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
          const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _plainHandColumn('Left Hand', leftHand, nfc: leftNfc),
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
                    rightHand,
                    nfc: rightNfc,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.blackCatBorderLight,
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _plainSummaryItem(
                  'Shape',
                  nailShape.trim().isEmpty ? '-' : nailShape,
                ),
              ),
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
              Expanded(
                child: _plainSummaryItem(
                  'Length',
                  nailLength.trim().isEmpty ? '-' : _prettyLength(nailLength),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _plainHandColumn(
    String title,
    dynamic dimensions, {
    Map<String, bool> nfc = const <String, bool>{},
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
              color: AppColors.blackCat,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _plainDimensionRow(
          'Thumb',
          _dimensionText(dimensions, 'thumb'),
          nfcRequested: nfc['thumb'] == true,
        ),
        _plainDimensionRow(
          'Index',
          _dimensionText(dimensions, 'index'),
          nfcRequested: nfc['index'] == true,
        ),
        _plainDimensionRow(
          'Middle',
          _dimensionText(dimensions, 'middle'),
          nfcRequested: nfc['middle'] == true,
        ),
        _plainDimensionRow(
          'Ring',
          _dimensionText(dimensions, 'ring'),
          nfcRequested: nfc['ring'] == true,
        ),
        _plainDimensionRow(
          'Pinky',
          _dimensionText(dimensions, 'pinky'),
          nfcRequested: nfc['pinky'] == true,
        ),
      ],
    );
  }

  static Widget _plainDimensionRow(
    String label,
    String value, {
    bool nfcRequested = false,
  }) {
    final formatted = _formatDimensionMm(value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.blackCat.withValues(alpha: 0.82),
                fontWeight: FontWeight.w400,
                fontSize: 13.5,
              ),
            ),
          ),
          SizedBox(
            width: 34,
            child: nfcRequested
                ? Center(child: _nfcDimensionChip())
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                formatted,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13.5,
                  color: AppColors.blackCat,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _plainSummaryItem(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.blackCat.withValues(alpha: 0.78),
            fontWeight: FontWeight.w400,
            fontSize: 14,
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
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.blackCat,
            ),
          ),
        ),
      ],
    );
  }

  static Widget _measurementSummaryItem(String label, String value) {
    return Container(
      constraints: const BoxConstraints(minHeight: 42),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.blackCatBorderLight),
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 42,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
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

  static String _prettyLength(String raw) {
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

  static Widget _dimRow(String k, String v, {bool nfcRequested = false}) {
    final value = _formatDimensionMm(v);
    final showNfcChip = nfcRequested;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            child: Text(
              k,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.blackCat.withValues(alpha: 0.82),
                fontWeight: FontWeight.w400,
                fontSize: 13.5,
              ),
            ),
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showNfcChip) ...[
                    _nfcDimensionChip(),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    value,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13.5,
                      color: AppColors.blackCat,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDimensionMm(String raw) {
    final value = raw.trim();
    if (value.isEmpty || value == '-') return '-';
    final cleaned = value.replaceAll(RegExp(r'[^0-9.]'), '').trim();
    if (cleaned.isEmpty) return value;
    final parsed = double.tryParse(cleaned);
    if (parsed == null) return value;
    return '${parsed.toStringAsFixed(2)} mm';
  }

  static Widget _nfcDimensionChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: const BoxDecoration(
        color: AppColors.balletSlippers,
        borderRadius: BorderRadius.zero,
      ),
      child: const Text(
        'NFC',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: AppColors.blackCat,
          height: 1.0,
        ),
      ),
    );
  }

  Widget _topHero(BuildContext context) {
    final s = _reqScale(context);
    final isBrandRequest =
        request.sourceCollection == 'Company_Custom_Requests';
    final campaignName = request.title.trim().isEmpty
        ? 'Campaign'
        : request.title.trim();
    final displayName = isBrandRequest && request.brandName.trim().isNotEmpty
        ? request.brandName.trim()
        : request.clientName;

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Column(
            children: [
              const SizedBox(height: 12),

              // Avatar (center)
              SizedBox(
                height: 78 * s,
                width: 78 * s,
                child: FutureBuilder<String>(
                  future: _resolvedHeroPhotoSource(),
                  builder: (_, snap) {
                    final path = (snap.data ?? _heroPhotoSource()).trim();
                    if (path.isNotEmpty) {
                      return ClipRRect(
                        borderRadius: BorderRadius.zero,
                        child: _heroAvatar(s, path),
                      );
                    }
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.zero,
                        color: AppColors.balletSlippers,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _initialLetter(),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 22 * s,
                          color: AppColors.blackCat,
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Name
              Text(
                displayName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16 * s,
                  color: AppColors.blackCat,
                ),
              ),
              if (isBrandRequest) ...[
                const SizedBox(height: 4),
                Text(
                  campaignName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13.5 * s,
                    color: AppColors.blackCat.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.blackCat),
                    color: AppColors.snow,
                  ),
                  child: Text(
                    'Brand Request',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11 * s,
                      color: AppColors.blackCat,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'Order # ${request.orderNumber.trim().isNotEmpty ? request.orderNumber.trim() : request.id}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.blackCat.withValues(alpha: 0.78),
                  fontWeight: FontWeight.w500,
                  fontSize: 12.5 * s,
                ),
              ),

              const SizedBox(height: 12),

              _requestTypePills(context),

              const SizedBox(height: 12),

              Row(
                children: [
                  Flexible(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                          color: AppColors.blackCat,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Need by: ${_needByLabel(request.neededBy)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5 * s,
                              color: AppColors.blackCat,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12 * s),
                  Container(
                    width: 1,
                    height: 18 * s,
                    color: AppColors.blackCatBorderLight,
                  ),
                  SizedBox(width: 12 * s),
                  Flexible(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.attach_money_rounded,
                          size: 18,
                          color: AppColors.blackCat,
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            'Budget: \$${request.budgetMin} to \$${request.budgetMax}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5 * s,
                              color: AppColors.blackCat,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Close icon top-right
        Positioned(
          right: 6,
          top: 6,
          child: Semantics(
            button: true,
            label: 'Close',
            onTap: () => Navigator.pop(context),
            child: ExcludeSemantics(
              child: InkWell(
            borderRadius: BorderRadius.zero,
            onTap: () => Navigator.pop(context),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                Icons.close_rounded,
                size: 18 * s,
                color: AppColors.blackCat,
              ),
            ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _brandClientDetailsBlock() {
    return _softBox(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Client Details'),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: _clientDetailsAvatar(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  request.acceptedClientName.trim().isEmpty
                      ? 'Client'
                      : request.acceptedClientName.trim(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.blackCat,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _clientDetailsAvatar() {
    final acceptedPhoto = request.acceptedClientProfileImage.trim();
    if (_canUseAcceptedClientAvatar(acceptedPhoto)) {
      final normalized = _normalizeImagePath(acceptedPhoto);
      final bytes = _decodeDataImageBytes(normalized);
      if (bytes != null) {
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          cacheWidth: kMaxImageDecodeDimension,
          errorBuilder: (_, _, _) => _clientDetailsAvatarFallback(),
        );
      }
      if (normalized.startsWith('http://') ||
          normalized.startsWith('https://')) {
        return Image.network(
          normalized,
          fit: BoxFit.cover,
          cacheWidth: kMaxImageDecodeDimension,
          errorBuilder: (_, _, _) => _clientDetailsAvatarFallback(),
        );
      }
    }
    return _clientDetailsAvatarFallback();
  }

  bool _canUseAcceptedClientAvatar(String raw) {
    final photo = raw.trim();
    if (photo.isEmpty) return false;
    final normalizedPhoto = _normalizeImagePath(photo).trim().toLowerCase();
    if (normalizedPhoto.isEmpty) return false;

    final blocked = <String>{
      _normalizeImagePath(_heroPhotoSource()).trim().toLowerCase(),
      _normalizeImagePath(request.previewImageAsset).trim().toLowerCase(),
      _normalizeImagePath(request.clientProfileImage).trim().toLowerCase(),
    }..removeWhere((e) => e.isEmpty);

    // Prevent brand/header images from being reused as the client avatar.
    if (blocked.contains(normalizedPhoto)) return false;
    return true;
  }

  Widget _clientDetailsAvatarFallback() {
    final name = request.acceptedClientName.trim().isNotEmpty
        ? request.acceptedClientName.trim()
        : 'Client';
    final letter = name[0].toUpperCase();
    return Container(
      color: AppColors.balletSlippers,
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: AppColors.blackCat,
        ),
      ),
    );
  }

  Widget _requestTypePills(BuildContext context) {
    return FutureBuilder<_ArtistRequestDisplayContext>(
      future: _cachedDisplayContext(),
      builder: (context, snapshot) {
        final display = snapshot.data;
        final isDirect = display?.isDirectRequest ?? request.isDirectRequest;
        final isGroup =
            display?.isGroupOrder ??
            (request.orderType == RequestOrderTypeV2.group);
        final s = _reqScale(context);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: _requestTypePill(
                context: context,
                text: isDirect ? 'Direct Request' : 'Standard Request',
                icon: isDirect
                    ? Icons.arrow_outward_rounded
                    : Icons.arrow_forward_rounded,
                alignEnd: true,
              ),
            ),
            SizedBox(width: 12 * s),
            Container(
              width: 1,
              height: 18 * s,
              color: AppColors.blackCatBorderLight,
            ),
            SizedBox(width: 12 * s),
            Flexible(
              child: _requestTypePill(
                context: context,
                text: isGroup ? 'Group Order' : 'Single Order',
                icon: isGroup
                    ? Icons.groups_2_outlined
                    : Icons.person_outline_rounded,
                alignEnd: false,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _requestTypePill({
    required BuildContext context,
    required String text,
    required IconData icon,
    required bool alignEnd,
  }) {
    final s = _reqScale(context);

    return Row(
      mainAxisAlignment: alignEnd
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        Icon(icon, size: 16 * s, color: AppColors.blackCat),
        SizedBox(width: 8 * s),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5 * s,
              color: AppColors.blackCat,
            ),
          ),
        ),
      ],
    );
  }

  Widget _groupOrderClientsTabs(_RequestNfcDetails nfcDetails) {
    final tabs = _orderClientsForTabs(nfcDetails);
    if (tabs.isEmpty) {
      return _softBox(
        Text(
          'No client measurements found for this order.',
          style: TextStyle(
            color: AppColors.blackCat.withValues(alpha: 0.65),
            fontWeight: FontWeight.w400,
            fontSize: 13.5,
          ),
        ),
      );
    }

    return DefaultTabController(
      key: ValueKey(
        tabs
            .map((tab) => '${tab.slotIndex}:${tab.name.trim().toLowerCase()}')
            .join('|'),
      ),
      length: tabs.length,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.snow,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: AppColors.blackCatBorderLight),
        ),
        child: Column(
          children: [
            Container(
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.blackCat,
                unselectedLabelColor: AppColors.blackCat,
                indicatorColor: AppColors.alabaster,
                indicatorWeight: 3,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13.5,
                ),
                tabs: tabs
                    .map(
                      (c) => Tab(
                        text: c.name.trim().isEmpty ? 'Client' : c.name.trim(),
                      ),
                    )
                    .toList(),
              ),
            ),
            SizedBox(
              height: 300,
              child: TabBarView(
                children: tabs.map((c) => _clientMeasurementsTab(c)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _clientMeasurementsTab(_OrderClientTabData client) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: _nailDimensionsPanel(
        leftHand: client.leftHand,
        rightHand: client.rightHand,
        nailShape: client.nailShape,
        nailLength: client.nailLength,
        leftNfc: client.nfc.left,
        rightNfc: client.nfc.right,
      ),
    );
  }

  List<_OrderClientTabData> _orderClientsForTabs(
    _RequestNfcDetails nfcDetails,
  ) {
    final submittedClientName = request.clientName.trim();
    final submittedClient =
        nfcDetails.submittedClient ??
        _OrderClientTabData(
          name: submittedClientName.isEmpty ? 'Client' : submittedClientName,
          nailShape: request.nailShape,
          nailLength: request.nailLength,
          leftHand: request.leftHand,
          rightHand: request.rightHand,
          nfc: nfcDetails.main,
        );

    String identityFor(_OrderClientTabData client) {
      if (client.slotIndex > 0) return 'slot:${client.slotIndex}';
      final nameKey = client.name.trim().toLowerCase();
      if (nameKey.isNotEmpty) return 'name:$nameKey';
      return 'submitted';
    }

    if (nfcDetails.groupTabs.isNotEmpty) {
      final ordered = <_OrderClientTabData>[submittedClient];
      final seen = <String>{'submitted'};
      final submittedNameKey = submittedClient.name.trim().toLowerCase();
      for (final tab in nfcDetails.groupTabs) {
        final tabNameKey = tab.name.trim().toLowerCase();
        final isSubmittedDuplicate =
            tab.slotIndex <= 0 &&
            tabNameKey.isNotEmpty &&
            tabNameKey == submittedNameKey;
        if (isSubmittedDuplicate) continue;

        final key = identityFor(tab);
        if (seen.add(key)) {
          ordered.add(tab);
        }
      }
      return ordered;
    }

    if (request.groupClients.isNotEmpty) {
      final ordered = <_OrderClientTabData>[submittedClient];
      final seen = <String>{identityFor(submittedClient)};
      for (final c in request.groupClients) {
        final name = c.clientName.trim().isNotEmpty
            ? c.clientName.trim()
            : (c.clientId.trim().isNotEmpty
                  ? c.clientId.trim()
                  : 'Client ${c.slotIndex}');
        final tab = _OrderClientTabData(
          slotIndex: c.slotIndex,
          name: name,
          nailShape: c.nailShape,
          nailLength: c.nailLength,
          leftHand: c.leftHand,
          rightHand: c.rightHand,
          nfc:
              nfcDetails.groupBySlotIndex[c.slotIndex] ??
              _FingerNfcSelection.empty(),
        );
        final key = identityFor(tab);
        if (seen.add(key)) {
          ordered.add(tab);
        }
      }
      return ordered;
    }

    return <_OrderClientTabData>[submittedClient];
  }

  Widget _heroAvatar(double s, [String? overridePhoto]) {
    final photo = (overridePhoto ?? _heroPhotoSource()).trim();

    Widget initialFallback() => Center(
      child: Text(
        request.clientName.isEmpty ? 'C' : request.clientName[0].toUpperCase(),
        style: TextStyle(fontWeight: FontWeight.w400, fontSize: 16 * s),
      ),
    );

    Widget fitCover(Widget child) {
      return SizedBox.expand(child: child);
    }

    if (photo.isEmpty) return initialFallback();

    final p = _normalizeImagePath(photo);
    final dataBytes = _decodeDataImageBytes(p);
    final isNetwork =
        p.startsWith('http://') ||
        p.startsWith('https://') ||
        p.startsWith('gs://') ||
        p.startsWith('blob:') ||
        p.startsWith('content://');
    final isAsset = p.startsWith('assets/');
    final isFileUri = p.startsWith('file://');
    final isFilePath = !kIsWeb && (p.startsWith('/') || p.contains(':\\'));
    final isStorageRef = _looksLikeStorageRef(p);

    if (p.startsWith('gs://') || isStorageRef || isNetwork) {
      return FutureBuilder<String>(
        future: StorageUrlResolver.resolve(p).then((v) {
          final resolved = (v ?? '').trim();
          if (resolved.isNotEmpty) return resolved;
          if (p.startsWith('http://') || p.startsWith('https://')) return p;
          return '';
        }),
        builder: (_, snap) {
          final url = snap.data?.trim() ?? '';
          if (url.isNotEmpty) {
            return fitCover(
              Image.network(
                url,
                fit: BoxFit.cover,
                cacheWidth: kMaxImageDecodeDimension,
                errorBuilder: (_, _, _) => initialFallback(),
              ),
            );
          }
          return FutureBuilder<Uint8List?>(
            future: _readStorageBytes(p),
            builder: (_, bytesSnap) {
              final bytes = bytesSnap.data;
              if (bytes == null || bytes.isEmpty) return initialFallback();
              return fitCover(
                Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  cacheWidth: kMaxImageDecodeDimension,
                  errorBuilder: (_, _, _) => initialFallback(),
                ),
              );
            },
          );
        },
      );
    }
    if (dataBytes != null) {
      return fitCover(
        Image.memory(
          dataBytes,
          fit: BoxFit.cover,
          cacheWidth: kMaxImageDecodeDimension,
          errorBuilder: (_, _, _) => initialFallback(),
        ),
      );
    }
    // Network URLs are resolved above through StorageUrlResolver for mobile.
    if (isAsset) {
      return fitCover(
        Image.asset(
          p,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => initialFallback(),
        ),
      );
    }
    if (isFileUri || isFilePath) {
      final localPath = isFileUri ? p.replaceFirst('file://', '') : p;
      return fitCover(
        Image.file(
          File(localPath),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => initialFallback(),
        ),
      );
    }
    return initialFallback();
  }

  String _normalizeImagePath(String raw) {
    var p = raw.trim();
    if (p.isEmpty) return '';
    if (p.startsWith('assets/')) {
      final rest = p.substring('assets/'.length);
      final decodedRest = _decodeUriSafelyRepeatedly(rest).trim();
      final lower = decodedRest.toLowerCase();
      if (lower.startsWith('data:') ||
          lower.startsWith('blob:') ||
          lower.startsWith('http://') ||
          lower.startsWith('https://') ||
          lower.startsWith('content://') ||
          lower.startsWith('file://')) {
        return decodedRest;
      }
    }
    p = _decodeUriSafelyRepeatedly(p).trim();
    if (p.startsWith('assets/')) {
      final rest = p.substring('assets/'.length);
      final decodedRest = _decodeUriSafelyRepeatedly(rest).trim();
      final lower = decodedRest.toLowerCase();
      if (lower.startsWith('data:') ||
          lower.startsWith('blob:') ||
          lower.startsWith('http://') ||
          lower.startsWith('https://') ||
          lower.startsWith('content://') ||
          lower.startsWith('file://')) {
        return decodedRest;
      }
    }
    return p;
  }

  bool _looksLikeStorageRef(String value) {
    final v = value.trim().toLowerCase();
    if (v.isEmpty) return false;
    if (v.startsWith('http://') ||
        v.startsWith('https://') ||
        v.startsWith('gs://') ||
        v.startsWith('data:') ||
        v.startsWith('blob:') ||
        v.startsWith('content://') ||
        v.startsWith('file://') ||
        v.startsWith('assets/') ||
        v.startsWith('/')) {
      return false;
    }
    if (v.contains(':\\')) return false;
    return v.contains('/');
  }

  Widget _photosGrid(BuildContext context, List<String> images) {
    final valid = images
        .map((e) => _normalizeImagePath(e).trim())
        .where((e) => e.isNotEmpty)
        .where((e) {
          final lower = e.toLowerCase();
          return lower != 'null' &&
              lower != '-' &&
              !lower.startsWith('assets/images/order_thumb') &&
              !lower.startsWith('assets/images/placeholder') &&
              !lower.startsWith('assets/icons/');
        })
        .toList();

    final unique = <String>[];
    for (final item in valid) {
      final key = item.toLowerCase();
      if (unique.any((existing) => existing.toLowerCase() == key)) continue;
      unique.add(item);
    }

    Widget broken() => Container(
      color: AppColors.blackCat.withValues(alpha: 0.05),
      alignment: Alignment.center,
      child: Icon(
        Icons.broken_image_outlined,
        color: AppColors.blackCat.withValues(alpha: 0.35),
      ),
    );

    Widget loading() => Container(
      color: AppColors.blackCat.withValues(alpha: 0.05),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );

    Widget imageFor(String raw) {
      final path = _normalizeImagePath(raw).trim();
      final dataBytes = _decodeDataImageBytes(path);
      if (dataBytes != null) {
        return Image.memory(
          dataBytes,
          fit: BoxFit.cover,
          cacheWidth: kMaxImageDecodeDimension,
          errorBuilder: (_, _, _) => broken(),
        );
      }
      if ((path.startsWith('http://') || path.startsWith('https://')) &&
          !path.contains('/storage/v1/object/')) {
        return Image.network(
          path,
          fit: BoxFit.cover,
          cacheWidth: kMaxImageDecodeDimension,
          errorBuilder: (_, _, _) => broken(),
        );
      }
      if (path.startsWith('assets/')) {
        return Image.asset(
          path,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => broken(),
        );
      }
      if (path.startsWith('file://') ||
          (!kIsWeb && (path.startsWith('/') || path.contains(':\\')))) {
        final localPath = path.startsWith('file://')
            ? path.replaceFirst('file://', '')
            : path;
        return Image.file(
          File(localPath),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => broken(),
        );
      }

      return FutureBuilder<String?>(
        future: _signedOrPublicPhotoUrl(path),
        builder: (_, urlSnap) {
          if (urlSnap.connectionState != ConnectionState.done) return loading();
          final url = (urlSnap.data ?? '').trim();
          if (url.isNotEmpty) {
            return Image.network(
              url,
              fit: BoxFit.cover,
              cacheWidth: kMaxImageDecodeDimension,
              errorBuilder: (_, _, _) => FutureBuilder<Uint8List?>(
                future: _readStorageBytes(path),
                builder: (_, bytesSnap) {
                  if (bytesSnap.connectionState != ConnectionState.done)
                    return loading();
                  final bytes = bytesSnap.data;
                  if (bytes == null || bytes.isEmpty) return broken();
                  return Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    cacheWidth: kMaxImageDecodeDimension,
                    errorBuilder: (_, _, _) => broken(),
                  );
                },
              ),
            );
          }
          return FutureBuilder<Uint8List?>(
            future: _readStorageBytes(path),
            builder: (_, bytesSnap) {
              if (bytesSnap.connectionState != ConnectionState.done)
                return loading();
              final bytes = bytesSnap.data;
              if (bytes == null || bytes.isEmpty) return broken();
              return Image.memory(
                bytes,
                fit: BoxFit.cover,
                cacheWidth: kMaxImageDecodeDimension,
                errorBuilder: (_, _, _) => broken(),
              );
            },
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final tileSize = ((constraints.maxWidth - 24) / 4).clamp(70.0, 112.0);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: unique.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            mainAxisExtent: tileSize,
          ),
          itemBuilder: (context, i) {
            final path = unique[i];
            return Semantics(
              button: true,
              label: 'View photo ${i + 1} full screen',
              onTap: () => _openImagePreview(context, path),
              child: ExcludeSemantics(
                child: InkWell(
              borderRadius: BorderRadius.zero,
              onTap: () => _openImagePreview(context, path),
              child: ClipRRect(
                borderRadius: BorderRadius.zero,
                child: SizedBox.expand(child: imageFor(path)),
              ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openImagePreview(BuildContext context, String imagePath) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        backgroundColor: AppColors.snow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: Stack(
          children: [
            AspectRatio(aspectRatio: 1, child: _previewImageForPath(imagePath)),
            Positioned(
              right: 6,
              top: 6,
              child: IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewImageForPath(String raw) {
    final path = _normalizeImagePath(raw).trim();
    final dataBytes = _decodeDataImageBytes(path);

    Widget broken() => Container(
          color: AppColors.blackCat.withValues(alpha: 0.05),
          alignment: Alignment.center,
          child: Icon(
            Icons.broken_image_outlined,
            color: AppColors.blackCat.withValues(alpha: 0.35),
          ),
        );

    Widget loading() => Container(
          color: AppColors.blackCat.withValues(alpha: 0.05),
          alignment: Alignment.center,
          child: const CircularProgressIndicator(strokeWidth: 2),
        );

    if (dataBytes != null) {
      return Image.memory(
        dataBytes,
        fit: BoxFit.contain,
        cacheWidth: kMaxImageDecodeDimension,
        errorBuilder: (_, _, _) => broken(),
      );
    }
    if ((path.startsWith('http://') || path.startsWith('https://')) &&
        !path.contains('/storage/v1/object/')) {
      return Image.network(
        path,
        fit: BoxFit.contain,
        cacheWidth: kMaxImageDecodeDimension,
        errorBuilder: (_, _, _) => broken(),
      );
    }
    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => broken(),
      );
    }
    if (path.startsWith('file://') ||
        (!kIsWeb && (path.startsWith('/') || path.contains(':\\')))) {
      final localPath = path.startsWith('file://')
          ? path.replaceFirst('file://', '')
          : path;
      return Image.file(
        File(localPath),
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => broken(),
      );
    }

    return FutureBuilder<String?>(
      future: _signedOrPublicPhotoUrl(path),
      builder: (_, urlSnap) {
        if (urlSnap.connectionState != ConnectionState.done) return loading();
        final url = (urlSnap.data ?? '').trim();
        if (url.isNotEmpty) {
          return Image.network(
            url,
            fit: BoxFit.contain,
            cacheWidth: kMaxImageDecodeDimension,
            errorBuilder: (_, _, _) => FutureBuilder<Uint8List?>(
              future: _readStorageBytes(path),
              builder: (_, bytesSnap) {
                if (bytesSnap.connectionState != ConnectionState.done)
                  return loading();
                final bytes = bytesSnap.data;
                if (bytes == null || bytes.isEmpty) return broken();
                return Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                  cacheWidth: kMaxImageDecodeDimension,
                  errorBuilder: (_, _, _) => broken(),
                );
              },
            ),
          );
        }
        return FutureBuilder<Uint8List?>(
          future: _readStorageBytes(path),
          builder: (_, bytesSnap) {
            if (bytesSnap.connectionState != ConnectionState.done)
              return loading();
            final bytes = bytesSnap.data;
            if (bytes == null || bytes.isEmpty) return broken();
            return Image.memory(
              bytes,
              fit: BoxFit.contain,
              cacheWidth: kMaxImageDecodeDimension,
              errorBuilder: (_, _, _) => broken(),
            );
          },
        );
      },
    );
  }

  static String _needByLabel(DateTime d) {
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
    const wds = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${wds[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }
}

String _decodeUriSafelyRepeatedly(String value) {
  var out = value;
  for (var i = 0; i < 3; i++) {
    try {
      final decoded = Uri.decodeFull(out);
      if (decoded == out) break;
      out = decoded;
    } catch (_) {
      break;
    }
  }
  return out;
}

bool _looksLikeStorageRef(String value) {
  final v = value.trim().toLowerCase();
  if (v.isEmpty) return false;
  if (v.startsWith('http://') ||
      v.startsWith('https://') ||
      v.startsWith('gs://') ||
      v.startsWith('data:') ||
      v.startsWith('blob:') ||
      v.startsWith('content://') ||
      v.startsWith('file://') ||
      v.startsWith('assets/') ||
      v.startsWith('/')) {
    return false;
  }
  if (v.contains(':\\')) return false;
  return v.contains('/');
}

class _SupabasePhotoRef {
  const _SupabasePhotoRef({required this.bucket, required this.path});
  final String bucket;
  final String path;
}

_SupabasePhotoRef? _parseSupabasePhotoRef(String raw) {
  var value = _decodeUriSafelyRepeatedly(raw).trim();
  if (value.isEmpty) return null;
  // Supabase public/signed object URLs can still point to private objects.
  // Parse them back into bucket + object path so we can create a fresh signed URL.
  final objectMarker = '/storage/v1/object/';
  final objectIndex = value.indexOf(objectMarker);
  if (objectIndex >= 0) {
    var tail = value.substring(objectIndex + objectMarker.length);
    tail = tail.replaceFirst(RegExp(r'^(public|sign)/'), '');
    final queryIndex = tail.indexOf('?');
    if (queryIndex >= 0) tail = tail.substring(0, queryIndex);
    final slash = tail.indexOf('/');
    if (slash > 0 && slash < tail.length - 1) {
      return _SupabasePhotoRef(
        bucket: tail.substring(0, slash),
        path: tail.substring(slash + 1),
      );
    }
  }

  if (value.startsWith('http://') ||
      value.startsWith('https://') ||
      value.startsWith('data:') ||
      value.startsWith('blob:') ||
      value.startsWith('content://') ||
      value.startsWith('file://') ||
      value.startsWith('assets/')) {
    return null;
  }

  if (value.startsWith('gs://')) {
    final withoutScheme = value.substring(5);
    final slash = withoutScheme.indexOf('/');
    if (slash <= 0 || slash >= withoutScheme.length - 1) return null;
    return _SupabasePhotoRef(
      bucket: withoutScheme.substring(0, slash),
      path: withoutScheme.substring(slash + 1),
    );
  }

  value = value.replaceFirst(RegExp(r'^/+'), '');

  const knownBuckets = <String>[
    'request-inspiration-photos',
    'company-request-photos',
    'client-request-photos',
    'request-photos',
    'request-completed-photos',
    'request-design-previews',
    'chat-attachments',
    'public',
  ];

  for (final bucket in knownBuckets) {
    if (value == bucket) return null;
    if (value.startsWith('$bucket/')) {
      return _SupabasePhotoRef(
        bucket: bucket,
        path: value.substring(bucket.length + 1),
      );
    }
  }

  // Most uploaded client inspiration images are stored here when the DB only has an object path.
  return _SupabasePhotoRef(bucket: 'request-inspiration-photos', path: value);
}

Future<String?> _signedOrPublicPhotoUrl(String raw) async {
  final ref = _parseSupabasePhotoRef(raw);
  if (ref == null || ref.path.trim().isEmpty) return null;
  final storage = Supabase.instance.client.storage.from(ref.bucket);
  try {
    final signed = await storage.createSignedUrl(ref.path, 60 * 60);
    if (signed.trim().isNotEmpty) return signed;
  } catch (_) {}
  try {
    final publicUrl = storage.getPublicUrl(ref.path);
    if (publicUrl.trim().isNotEmpty) return publicUrl;
  } catch (_) {}
  return null;
}

Future<Uint8List?> _readStorageBytes(String value) async {
  final raw = value.trim();
  if (raw.isEmpty) return null;

  final parsed = _parseSupabasePhotoRef(raw);
  if (parsed == null) return null;

  final candidateRefs = <_SupabasePhotoRef>[
    parsed,
    if (parsed.bucket != 'request-inspiration-photos')
      _SupabasePhotoRef(
        bucket: 'request-inspiration-photos',
        path: parsed.path,
      ),
    if (parsed.bucket != 'company-request-photos')
      _SupabasePhotoRef(bucket: 'company-request-photos', path: parsed.path),
    if (parsed.bucket != 'client-request-photos')
      _SupabasePhotoRef(bucket: 'client-request-photos', path: parsed.path),
    if (parsed.bucket != 'request-photos')
      _SupabasePhotoRef(bucket: 'request-photos', path: parsed.path),
    if (parsed.bucket != 'public')
      _SupabasePhotoRef(bucket: 'public', path: parsed.path),
  ];

  final seen = <String>{};
  for (final ref in candidateRefs) {
    final key = '${ref.bucket}/${ref.path}'.toLowerCase();
    if (!seen.add(key)) continue;
    try {
      final bytes = await Supabase.instance.client.storage
          .from(ref.bucket)
          .download(ref.path);
      if (bytes.isNotEmpty) return bytes;
    } catch (_) {}
  }
  return null;
}

Uint8List? _decodeDataImageBytes(String value) {
  final src = value.trim();
  if (!src.startsWith('data:image/')) return null;
  final comma = src.indexOf(',');
  if (comma <= 0 || comma >= src.length - 1) return null;
  try {
    return base64Decode(src.substring(comma + 1));
  } catch (_) {
    return null;
  }
}

class _OrderClientTabData {
  const _OrderClientTabData({
    this.slotIndex = 0,
    required this.name,
    required this.nailShape,
    required this.nailLength,
    required this.leftHand,
    required this.rightHand,
    required this.nfc,
  });

  final int slotIndex;
  final String name;
  final String nailShape;
  final String nailLength;
  final dynamic leftHand;
  final dynamic rightHand;
  final _FingerNfcSelection nfc;
}

class _RequestNfcDetails {
  const _RequestNfcDetails({
    required this.main,
    required this.groupBySlotIndex,
    this.groupTabs = const <_OrderClientTabData>[],
    this.submittedClient,
  });

  factory _RequestNfcDetails.empty() => const _RequestNfcDetails(
    main: _FingerNfcSelection(),
    groupBySlotIndex: <int, _FingerNfcSelection>{},
    groupTabs: <_OrderClientTabData>[],
  );

  final _FingerNfcSelection main;
  final Map<int, _FingerNfcSelection> groupBySlotIndex;
  final List<_OrderClientTabData> groupTabs;
  final _OrderClientTabData? submittedClient;
}

class _FingerNfcSelection {
  const _FingerNfcSelection({
    this.lThumb = false,
    this.lIndex = false,
    this.lMiddle = false,
    this.lRing = false,
    this.lPinky = false,
    this.rThumb = false,
    this.rIndex = false,
    this.rMiddle = false,
    this.rRing = false,
    this.rPinky = false,
  });

  factory _FingerNfcSelection.empty() => const _FingerNfcSelection();

  factory _FingerNfcSelection.fromDimensionsMap(Map<String, dynamic> map) {
    bool truthyFlag(Object? value) {
      if (value is bool) return value;
      if (value is num) return value == 1;
      final text = (value ?? '').toString().trim().toLowerCase();
      return text == 'true' ||
          text == 'yes' ||
          text == '1' ||
          text == 'selected' ||
          text == 'enabled' ||
          text == 'nfc';
    }

    Map<String, dynamic> asMap(Object? value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
      return const <String, dynamic>{};
    }

    bool requestLevelNfcSelected(Map<String, dynamic> source) {
      if (source.isEmpty) return false;
      final summary = asMap(source['summary']);
      final nfc = asMap(source['nfc']);
      final nfcSelection = asMap(source['nfcSelection']).isNotEmpty
          ? asMap(source['nfcSelection'])
          : asMap(source['nfc_selection']);
      for (final raw in <Object?>[
        source['nfcRequested'],
        source['nfcSelected'],
        source['hasNfc'],
        source['nfcRequest'],
        source['nfcEnabled'],
        source['requiresNfcEligibleClient'],
        source['nfc_requested'],
        source['nfc_selected'],
        source['has_nfc'],
        source['nfc_request'],
        source['nfc_enabled'],
        source['requires_nfc_eligible_client'],
        summary['nfcRequested'],
        summary['nfcSelected'],
        summary['hasNfc'],
        summary['nfcRequest'],
        summary['nfcEnabled'],
        summary['requiresNfcEligibleClient'],
        summary['nfc_requested'],
        summary['nfc_selected'],
        summary['has_nfc'],
        summary['nfc_request'],
        summary['nfc_enabled'],
        summary['requires_nfc_eligible_client'],
        nfc['requested'],
        nfc['selected'],
        nfc['hasNfc'],
        nfc['nfcRequest'],
        nfc['nfcEnabled'],
        nfc['requiresNfcEligibleClient'],
        nfc['requested_finger'],
        nfcSelection['requested'],
        nfcSelection['selected'],
        nfcSelection['hasNfc'],
      ]) {
        if (truthyFlag(raw)) return true;
      }
      return false;
    }

    String normalize(Object? value) {
      return (value ?? '').toString().trim().toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]+'),
        '',
      );
    }

    bool selectedByText(String key, String genericFinger) {
      final normalizedKey = normalize(key);
      final normalizedGeneric = normalize(genericFinger);
      final nfc = asMap(map['nfc']);
      final nfcSelection = asMap(map['nfcSelection']).isNotEmpty
          ? asMap(map['nfcSelection'])
          : asMap(map['nfc_selection']);
      final selectedValues = <Object?>[
        map['nfcFinger'],
        map['nfc_finger'],
        map['selectedNfcFinger'],
        map['selected_nfc_finger'],
        map['nfcPlacement'],
        map['nfc_placement'],
        map['nfcNail'],
        map['nfc_nail'],
        map['selectedNail'],
        map['selected_nail'],
        map['finger'],
        nfc['finger'],
        nfc['selectedFinger'],
        nfc['selected_finger'],
        nfc['placement'],
        nfc['nail'],
        nfcSelection['finger'],
        nfcSelection['selectedFinger'],
        nfcSelection['selected_finger'],
      ];
      bool matchesSelectedText(Object? raw) {
        if (raw is List) {
          for (final item in raw) {
            if (matchesSelectedText(item)) return true;
          }
          return false;
        }
        if (raw is Map) {
          for (final entry in raw.entries) {
            final entryKey = normalize(entry.key);
            final entryValue = entry.value;
            if ((entryKey == normalizedKey ||
                    entryKey == '${normalizedKey}nfc') &&
                truthyFlag(entryValue)) {
              return true;
            }
            if (matchesSelectedText(entryValue)) return true;
          }
          return false;
        }
        final text = normalize(raw);
        if (text.isEmpty) return false;
        if (text == normalizedKey || text == '${normalizedKey}nfc') {
          return true;
        }
        // Only use generic names like "thumb" when no left/right side was saved.
        if (text == normalizedGeneric &&
            !map.containsKey('l${key.substring(1)}Nfc') &&
            !map.containsKey('r${key.substring(1)}Nfc')) {
          return true;
        }
        return false;
      }

      for (final raw in selectedValues) {
        if (matchesSelectedText(raw)) return true;
      }
      return false;
    }

    bool hasExplicitSideFlags(Map<String, dynamic> source) {
      const keys = <String>[
        'lThumb',
        'lThumbNfc',
        'lThumb_nfc',
        'lIndex',
        'lIndexNfc',
        'lIndex_nfc',
        'lMiddle',
        'lMiddleNfc',
        'lMiddle_nfc',
        'lRing',
        'lRingNfc',
        'lRing_nfc',
        'lPinky',
        'lPinkyNfc',
        'lPinky_nfc',
        'rThumb',
        'rThumbNfc',
        'rThumb_nfc',
        'rIndex',
        'rIndexNfc',
        'rIndex_nfc',
        'rMiddle',
        'rMiddleNfc',
        'rMiddle_nfc',
        'rRing',
        'rRingNfc',
        'rRing_nfc',
        'rPinky',
        'rPinkyNfc',
        'rPinky_nfc',
      ];
      return keys.any(source.containsKey);
    }

    bool selected(String key, String genericFinger) {
      final nfc = asMap(map['nfc']);
      final nfcSelection = asMap(map['nfcSelection']).isNotEmpty
          ? asMap(map['nfcSelection'])
          : asMap(map['nfc_selection']);
      bool eligibleForKey() {
        final dimensions = map['dimensions'] is Map
            ? (map['dimensions'] as Map).map(
                (k, v) => MapEntry(k.toString(), v),
              )
            : map;
        final raw = dimensions[key];
        final text = (raw ?? '').toString().trim();
        if (text.isEmpty || text.toLowerCase() == 'null') return false;
        final cleaned = text.replaceAll(RegExp(r'[^0-9.]'), '');
        final parsed = double.tryParse(cleaned);
        return parsed != null && parsed.isFinite && parsed >= 8;
      }

      Object? valueByNormalizedKey(
        Map<String, dynamic> source,
        List<String> aliases,
      ) {
        if (source.isEmpty) return null;
        final normalizedAliases = aliases.map(normalize).toSet();
        for (final entry in source.entries) {
          if (normalizedAliases.contains(normalize(entry.key))) {
            return entry.value;
          }
        }
        return null;
      }

      final upper = key.length > 1 ? key.substring(1) : key;
      final side = key.startsWith('l')
          ? 'left'
          : (key.startsWith('r') ? 'right' : '');
      final shortSide = key.startsWith('l')
          ? 'l'
          : (key.startsWith('r') ? 'r' : '');
      final sideAliases = <String>[
        '${key}Nfc',
        '${key}_nfc',
        '${shortSide}_${upper}_nfc',
        '${shortSide}${upper}Nfc',
        '${side}${upper}Nfc',
        '${side}_${upper}_nfc',
      ];
      final sideValueAliases = <String>[
        key,
        '${shortSide}_${upper}',
        '${side}${upper}',
        '${side}_${upper}',
      ];

      final explicitCandidates = <Object?>[
        valueByNormalizedKey(map, sideAliases),
        valueByNormalizedKey(nfc, <String>[
          ...sideAliases,
          ...sideValueAliases,
        ]),
        valueByNormalizedKey(nfcSelection, <String>[
          ...sideAliases,
          ...sideValueAliases,
        ]),
      ];
      for (final value in explicitCandidates) {
        if (truthyFlag(value)) return true;
      }

      // Legacy support: generic thumb/index flags only when no side-specific
      // left/right NFC flags exist. Never treat numeric dimensions as NFC.
      if (!hasExplicitSideFlags(map) &&
          !hasExplicitSideFlags(nfc) &&
          !hasExplicitSideFlags(nfcSelection)) {
        final genericCandidates = <Object?>[
          map['${genericFinger}Nfc'],
          map['${genericFinger}_nfc'],
          nfc[genericFinger],
          nfc['${genericFinger}Nfc'],
          nfc['${genericFinger}_nfc'],
          nfcSelection[genericFinger],
          nfcSelection['${genericFinger}Nfc'],
          nfcSelection['${genericFinger}_nfc'],
        ];
        for (final value in genericCandidates) {
          if (truthyFlag(value)) return true;
        }
      }

      if (requestLevelNfcSelected(map) ||
          requestLevelNfcSelected(nfc) ||
          requestLevelNfcSelected(nfcSelection)) {
        if (eligibleForKey()) return true;
      }

      return selectedByText(key, genericFinger);
    }

    return _FingerNfcSelection(
      lThumb: selected('lThumb', 'thumb'),
      lIndex: selected('lIndex', 'index'),
      lMiddle: selected('lMiddle', 'middle'),
      lRing: selected('lRing', 'ring'),
      lPinky: selected('lPinky', 'pinky'),
      rThumb: selected('rThumb', 'thumb'),
      rIndex: selected('rIndex', 'index'),
      rMiddle: selected('rMiddle', 'middle'),
      rRing: selected('rRing', 'ring'),
      rPinky: selected('rPinky', 'pinky'),
    );
  }

  factory _FingerNfcSelection.fromEligibleDimensionsMap(
    Map<String, dynamic> map,
  ) {
    final data = map['dimensions'] is Map
        ? (map['dimensions'] as Map).map(
            (key, value) => MapEntry(key.toString(), value),
          )
        : map;

    bool eligible(String key) {
      final text = (data[key] ?? '').toString().trim();
      if (text.isEmpty || text.toLowerCase() == 'null') return false;
      final cleaned = text.replaceAll(RegExp(r'[^0-9.]'), '');
      final parsed = double.tryParse(cleaned);
      return parsed != null && parsed.isFinite && parsed >= 8;
    }

    return _FingerNfcSelection(
      lThumb: eligible('lThumb'),
      lIndex: eligible('lIndex'),
      lMiddle: eligible('lMiddle'),
      lRing: eligible('lRing'),
      lPinky: eligible('lPinky'),
      rThumb: eligible('rThumb'),
      rIndex: eligible('rIndex'),
      rMiddle: eligible('rMiddle'),
      rRing: eligible('rRing'),
      rPinky: eligible('rPinky'),
    );
  }


  final bool lThumb;
  final bool lIndex;
  final bool lMiddle;
  final bool lRing;
  final bool lPinky;
  final bool rThumb;
  final bool rIndex;
  final bool rMiddle;
  final bool rRing;
  final bool rPinky;

  bool get anySelected =>
      lThumb ||
      lIndex ||
      lMiddle ||
      lRing ||
      lPinky ||
      rThumb ||
      rIndex ||
      rMiddle ||
      rRing ||
      rPinky;

  Map<String, bool> get left => <String, bool>{
    'thumb': lThumb,
    'index': lIndex,
    'middle': lMiddle,
    'ring': lRing,
    'pinky': lPinky,
  };

  Map<String, bool> get right => <String, bool>{
    'thumb': rThumb,
    'index': rIndex,
    'middle': rMiddle,
    'ring': rRing,
    'pinky': rPinky,
  };

  static _FingerNfcSelection fromShared(RequestFingerNfcSelection value) {
    bool pick(Map<String, bool> source, String key) => source[key] == true;
    return _FingerNfcSelection(
      lThumb: pick(value.left, 'thumb'),
      lIndex: pick(value.left, 'index'),
      lMiddle: pick(value.left, 'middle'),
      lRing: pick(value.left, 'ring'),
      lPinky: pick(value.left, 'pinky'),
      rThumb: pick(value.right, 'thumb'),
      rIndex: pick(value.right, 'index'),
      rMiddle: pick(value.right, 'middle'),
      rRing: pick(value.right, 'ring'),
      rPinky: pick(value.right, 'pinky'),
    );
  }
}

class _RequestFilterResult {
  const _RequestFilterResult({
    required this.directOnly,
    required this.groupOnly,
    required this.sort,
    required this.budgetRange,
  });

  final bool directOnly;
  final bool groupOnly;
  final String sort;
  final RangeValues budgetRange;
}

class _AcceptResult {
  final double yourPrice;
  final double shipping;
  final double extra;
  const _AcceptResult({
    required this.yourPrice,
    required this.shipping,
    required this.extra,
  });
}

class AcceptRequestDialogV2 extends StatefulWidget {
  const AcceptRequestDialogV2({
    super.key,
    required this.budgetMin,
    required this.budgetMax,
  });

  final int budgetMin;
  final int budgetMax;

  @override
  State<AcceptRequestDialogV2> createState() => _AcceptRequestDialogV2State();
}

class _AcceptRequestDialogV2State extends State<AcceptRequestDialogV2> {
  late final TextEditingController _yourPriceCtrl;
  late final TextEditingController _shippingCtrl;

  @override
  void initState() {
    super.initState();
    final mid = ((widget.budgetMin + widget.budgetMax) / 2).round();
    _yourPriceCtrl = TextEditingController(text: mid.toStringAsFixed(0));
    _shippingCtrl = TextEditingController(text: '10');
  }

  @override
  void dispose() {
    _yourPriceCtrl.dispose();
    _shippingCtrl.dispose();
    super.dispose();
  }

  double _toNum(String v) => double.tryParse(v.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isNarrow = media.size.width < 360;
    final range = '\$${widget.budgetMin} - \$${widget.budgetMax}';
    final total = _toNum(_yourPriceCtrl.text) + _toNum(_shippingCtrl.text);
    final exceedsBudget = total > widget.budgetMax;
    final bottomInset = media.viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(maxHeight: media.size.height * 0.78),
          decoration: const BoxDecoration(
            color: AppColors.snow,
            borderRadius: BorderRadius.zero,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Accept',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.blackCat,
                    fontFamily: 'Arial',
                  ),
                ),
                const SizedBox(height: 12),
                _row('Price Range', range),
                const SizedBox(height: 8),
                _fieldRow('Your Price', _yourPriceCtrl, prefix: '\$'),
                const SizedBox(height: 8),
                _fieldRow(
                  'Shipping + Extra',
                  _shippingCtrl,
                  prefix: '\$',
                  enabled: false,
                ),
                const SizedBox(height: 10),
                _row('Total', '\$${total.toStringAsFixed(2)}'),
                if (exceedsBudget) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Total exceeds client budget range.',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: AppColors.blackCat.withValues(
                              alpha: 0.16,
                            ),
                            foregroundColor: AppColors.blackCat,
                            side: BorderSide(
                              color: AppColors.blackCat.withValues(alpha: 0.30),
                            ),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: isNarrow ? 11 : 12,
                              fontFamily: 'Arial',
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.blackCat,
                            foregroundColor: AppColors.snow,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                            elevation: 0,
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: exceedsBudget
                              ? null
                              : () {
                                  Navigator.pop(
                                    context,
                                    _AcceptResult(
                                      yourPrice: _toNum(_yourPriceCtrl.text),
                                      shipping: _toNum(_shippingCtrl.text),
                                      extra: 0,
                                    ),
                                  );
                                },
                          child: Text(
                            'Accept',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: isNarrow ? 11 : 12,
                              fontFamily: 'Arial',
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
      ),
    );
  }

  Widget _row(String a, String b) {
    return Row(
      children: [
        Expanded(
          child: Text(
            a,
            style: TextStyle(
              color: AppColors.blackCat.withValues(alpha: 0.65),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        Text(
          b,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ],
    );
  }

  Widget _fieldRow(
    String label,
    TextEditingController c, {
    String prefix = '',
    bool enabled = true,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.blackCat.withValues(alpha: 0.65),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 110,
          child: TextField(
            controller: c,
            enabled: enabled,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixText: prefix,
              filled: true,
              fillColor: AppColors.snow,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(
                  color: AppColors.blackCat.withValues(alpha: 0.06),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(
                  color: AppColors.blackCat.withValues(alpha: 0.06),
                ),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: AppColors.blackCat, width: 1.2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _HeaderAvatarAction {
  profile,
  history,
  calendar,
  artist,
  earnings,
  reviews,
  signOut,
}

class _HeaderMenuRow extends StatelessWidget {
  const _HeaderMenuRow({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? AppColors.blackCat;
    return Row(
      children: [
        Icon(icon, size: 18, color: resolvedColor),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: resolvedColor,
          ),
        ),
      ],
    );
  }
}
