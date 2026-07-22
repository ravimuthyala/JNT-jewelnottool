import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/profile_table_columns.dart';
import '../models/client_request_v2.dart';
import '../services/artist_requests_repository.dart';
import '../services/notifications_service.dart';
import '../services/storage_url_resolver.dart' as storage_resolver;
import '../theme/app_colors.dart';
import '../utils/image_cache_utils.dart';
import '../utils/scenario_4_1.dart';
import '../widgets/company_client_request_card.dart';
import '../widgets/client_profile_avatar_icon.dart';
import '../widgets/jnt_standard_app_bar.dart';
import 'artist_requests_page_redesign.dart' show AcceptRequestDialogV2;
import 'client_campaign_details_page.dart';
import 'notifications_page.dart';

bool shouldShowScenario31ToDirectClient({
  required bool openToClientPool,
  required RequestOrderTypeV2 orderType,
  required String selectedClientEmail,
  required List<String> selectedGroupClientEmails,
  required String viewerEmail,
}) {
  return shouldShowScenario41ToDirectClient(
    openToClientPool: openToClientPool,
    orderType: orderType,
    selectedClientEmail: selectedClientEmail,
    selectedGroupClientEmails: selectedGroupClientEmails,
    viewerEmail: viewerEmail,
  );
}

class ClientCampaignsPage extends StatefulWidget {
  const ClientCampaignsPage({
    super.key,
    this.onOpenNotifications,
    this.onOpenProfile,
    this.onOpenEarnings,
    this.onLogout,
    this.showProfileMenuItem = true,
    this.showBrandRequests = true,
    this.showClientRequests = true,
    this.splitArtistVisibleRequestsBySource = false,
    this.useCampaignNaming = false,
  });

  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenEarnings;
  final VoidCallback? onLogout;
  final bool showProfileMenuItem;
  final bool showBrandRequests;
  final bool showClientRequests;
  final bool splitArtistVisibleRequestsBySource;
  final bool useCampaignNaming;

  @override
  State<ClientCampaignsPage> createState() => _ClientCampaignsPageState();
}

class _ClientCampaignsPageState extends State<ClientCampaignsPage> {
  RealtimeChannel? _companyChannel;
  bool _loading = true;
  List<ClientRequestV2> _items = const <ClientRequestV2>[];
  List<ClientRequestV2> _brandRequests = const <ClientRequestV2>[];
  List<ClientRequestV2> _clientRequests = const <ClientRequestV2>[];
  final Set<String> _hiddenRequestIds = <String>{};
  String _headerAvatarUrl = '';
  String _headerDisplayName = '';
  bool _currentClientIsBrandPartner = false;
  bool _currentClientNfcEligible = false;
  final Map<String, Set<String>> _tableColumnsCache = <String, Set<String>>{};

  bool _isBrandPartnerClient(Map<String, dynamic> data) {
    String norm(Object? value) => (value ?? '').toString().trim().toLowerCase();
    final profile = _asMap(data['profile']);
    final basic = _asMap(data['basic']);
    final client = _asMap(data['client']);
    final ascension = _asMap(data['ascension']);
    final profileAscension = _asMap(profile['ascension']);
    final basicAscension = _asMap(basic['ascension']);
    final clientAscension = _asMap(client['ascension']);

    bool hasTag(Object? raw) {
      if (raw is! List) return false;
      for (final item in raw) {
        final value = norm(item).replaceAll('_', ' ');
        if (value == 'ambassador' || value.contains('ambassador')) {
          return true;
        }
      }
      return false;
    }

    final statuses = <String>[
      norm(ascension['status']),
      norm(profileAscension['status']),
      norm(basicAscension['status']),
      norm(clientAscension['status']),
      norm(data['status']),
      norm(data['partnerStatus']),
      norm(data['tier']),
      norm(profile['status']),
      norm(profile['partnerStatus']),
      norm(profile['tier']),
      norm(basic['status']),
      norm(basic['partnerStatus']),
      norm(basic['tier']),
    ];
    for (final status in statuses) {
      final normalized = status.replaceAll('_', ' ');
      if (normalized == 'ambassador' ||
          (normalized.contains('ambassador') &&
              !normalized.contains('not ambassador'))) {
        return true;
      }
    }

    return hasTag(data['accountTags']) ||
        hasTag(profile['accountTags']) ||
        hasTag(basic['accountTags']) ||
        hasTag(client['accountTags']) ||
        hasTag(ascension['tags']) ||
        hasTag(profileAscension['tags']) ||
        hasTag(basicAscension['tags']) ||
        hasTag(clientAscension['tags']);
  }

  bool _isNfcEligibleClient(Map<String, dynamic> data) {
    Map<String, dynamic> asMap(Object? value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        return value.map((key, val) => MapEntry(key.toString(), val));
      }
      return const <String, dynamic>{};
    }

    double? mmValue(Object? raw) {
      if (raw is num) return raw.toDouble();
      final text = (raw ?? '').toString().trim().replaceAll(
        RegExp(r'[^0-9.]'),
        '',
      );
      if (text.isEmpty) return null;
      return double.tryParse(text);
    }

    bool hasEligibleDimension(Map<String, dynamic> dims) {
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
        'thumb',
        'index',
        'middle',
        'ring',
        'pinky',
      ];
      for (final key in keys) {
        final value = mmValue(dims[key]);
        if (value != null && value >= 8) return true;
      }
      return false;
    }

    final profile = asMap(data['profile']);
    final basic = asMap(data['basic']);
    final client = asMap(data['client']);
    final nailPreferences = asMap(data['nailPreferences']);
    final profileNailPreferences = asMap(profile['nailPreferences']);
    final basicNailPreferences = asMap(basic['nailPreferences']);
    final clientNailPreferences = asMap(client['nailPreferences']);
    final apiNailMeasurements = asMap(data['apiNailMeasurements']);

    final dimensionMaps = <Map<String, dynamic>>[
      asMap(nailPreferences['dimensions']),
      asMap(profileNailPreferences['dimensions']),
      asMap(basicNailPreferences['dimensions']),
      asMap(clientNailPreferences['dimensions']),
      asMap(data['dimensions']),
      asMap(profile['dimensions']),
      asMap(basic['dimensions']),
      asMap(client['dimensions']),
      apiNailMeasurements,
    ];

    for (final dims in dimensionMaps) {
      if (hasEligibleDimension(dims)) return true;
    }

    bool truthy(Object? raw) {
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      final text = (raw ?? '').toString().trim().toLowerCase();
      return text == 'true' || text == '1' || text == 'yes';
    }

    return truthy(data['nfcEligible']) ||
        truthy(profile['nfcEligible']) ||
        truthy(basic['nfcEligible']) ||
        truthy(client['nfcEligible']);
  }

  Future<bool> _isCurrentClientNfcEligible(String clientEmail) async {
    final normalized = clientEmail.trim().toLowerCase();
    final uid = (_supabase.auth.currentUser?.id ?? '').trim();
    if (normalized.isEmpty && uid.isEmpty) return false;
    for (final collection in const <String>[
      'client',
      'client_artist',
      'clients',
    ]) {
      final columns = columnsForProfileTable(collection);
      try {
        if (uid.isNotEmpty) {
          final query = _supabase.from(collection).select(columns ?? '*');
          final rows = await query.eq('id', uid).limit(20);
          for (final row in rows) {
            final data = _asMap(row);
            if (_isNfcEligibleClient(data)) return true;
          }
        }
        if (normalized.isNotEmpty) {
          final query = _supabase.from(collection).select(columns ?? '*');
          final rows = await query.eq('email', normalized).limit(50);
          for (final row in rows) {
            final data = _asMap(row);
            if (_isNfcEligibleClient(data)) return true;
          }
        }
      } catch (_) {}
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadHeaderIdentity());
    _listenRequests();
  }

  @override
  void dispose() {
    if (_companyChannel != null) {
      Supabase.instance.client.removeChannel(_companyChannel!);
      _companyChannel = null;
    }
    super.dispose();
  }

  SupabaseClient get _supabase => Supabase.instance.client;

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return <String, dynamic>{};
  }

  List<dynamic> _asList(Object? value) {
    if (value is List) return List<dynamic>.from(value);
    return <dynamic>[];
  }

  Set<String> _asEmailSet(Object? value) {
    return _asList(value)
        .map((e) => e.toString().trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  String _tableNameForCollection(String collection) {
    final lower = collection.trim();
    if (lower == 'Company_Custom_Requests') return 'company_custom_requests';
    if (lower == 'Client_Custom_Requests') return 'client_custom_requests';
    if (lower == 'company_custom_requests') return 'company_custom_requests';
    if (lower == 'client_custom_requests') return 'client_custom_requests';
    return collection;
  }

  String _detailsTableForCollection(String collection) {
    return _tableNameForCollection(collection) == 'company_custom_requests'
        ? 'company_custom_requests_details'
        : 'client_custom_requests_details';
  }

  bool _isCompanyCustomRequestSource(String collection) {
    final normalized = _tableNameForCollection(collection).trim().toLowerCase();
    return normalized == 'company_custom_requests';
  }

  Future<Map<String, dynamic>?> _readRow(
    String table, {
    String? id,
    String? email,
  }) async {
    if (id != null && id.trim().isNotEmpty) {
      final rows = await _supabase
          .from(table)
          .select()
          .eq('id', id.trim())
          .limit(1);
      if (rows.isNotEmpty) return _asMap(rows.first);
    }
    if (email != null && email.trim().isNotEmpty) {
      final rows = await _supabase
          .from(table)
          .select()
          .eq('email', email.trim().toLowerCase())
          .limit(1);
      if (rows.isNotEmpty) return _asMap(rows.first);
    }
    return null;
  }

  Future<Map<String, dynamic>> _readRequestRoot(ClientRequestV2 request) async {
    final rows = await _supabase
        .from(_tableNameForCollection(request.sourceCollection))
        .select()
        .eq('id', request.id)
        .limit(1);
    return rows.isEmpty ? const <String, dynamic>{} : _asMap(rows.first);
  }

  Future<Map<String, dynamic>> _readRequestDetails(
    ClientRequestV2 request,
  ) async {
    final table = _detailsTableForCollection(request.sourceCollection);
    try {
      final rows = await _supabase
          .from(table)
          .select()
          .eq('request_id', request.id)
          .limit(1);
      if (rows.isNotEmpty) {
        return _asMap(rows.first);
      }
      final fallback = await _supabase
          .from(table)
          .select()
          .eq('id', request.id)
          .limit(1);
      if (fallback.isNotEmpty) {
        return _asMap(fallback.first);
      }
    } catch (_) {
      // Some environments do not keep a separate *_details row for brand
      // requests. In that case, the JSON lives in the root details column.
    }

    final root = await _readRequestRoot(request);
    final rootDetails = root['details'];
    return _asMap(rootDetails);
  }

  Map<String, dynamic> _deepMergeMaps(
    Map<String, dynamic> base,
    Map<String, dynamic> patch,
  ) {
    final result = Map<String, dynamic>.from(base);
    patch.forEach((key, value) {
      final current = result[key];
      if (current is Map && value is Map) {
        result[key] = _deepMergeMaps(
          current.map((k, v) => MapEntry(k.toString(), v)),
          value.map((k, v) => MapEntry(k.toString(), v)),
        );
      } else {
        result[key] = value;
      }
    });
    return result;
  }

  Future<Set<String>> _tableColumns(String table) async {
    final cached = _tableColumnsCache[table];
    if (cached != null) return cached;
    final rows = await _supabase.from(table).select().limit(1);
    final cols = <String>{};
    if (rows.isNotEmpty) {
      cols.addAll(_asMap(rows.first).keys.map((key) => key.toString()));
    }
    if (cols.isEmpty) {
      // Safe minimum for the current request tables. This prevents PostgREST
      // errors caused by sending camelCase JSON keys as DB columns.
      cols.addAll(const <String>[
        'id',
        'status',
        'details',
        'updated_at',
        'accepted_by_client_email',
        'declined_by_client_emails',
        'open_to_client_pool',
        'client_response_status',
        'artist_status',
        'brand_status',
        'client_status',
      ]);
    }
    _tableColumnsCache[table] = cols;
    return cols;
  }

  Future<void> _upsertRequestPayload(
    String collection,
    String requestId,
    Map<String, dynamic> summaryPayload,
    Map<String, dynamic> detailsPayload,
  ) async {
    final table = _tableNameForCollection(collection);
    final nowIso = DateTime.now().toIso8601String();
    final existingRows = await _supabase
        .from(table)
        .select()
        .eq('id', requestId)
        .limit(1);
    final root = existingRows.isEmpty
        ? const <String, dynamic>{}
        : _asMap(existingRows.first);
    final existingDetails = _asMap(root['details']);
    final mergedDetails = _deepMergeMaps(
      existingDetails,
      _deepMergeMaps(
        detailsPayload,
        <String, dynamic>{
          'status': summaryPayload['status'] ?? detailsPayload['status'],
          'acceptedByClientEmail': summaryPayload['acceptedByClientEmail'],
          'acceptedByClientAt': summaryPayload['acceptedByClientAt'],
          'declinedByClientEmails': summaryPayload['declinedByClientEmails'],
          'acceptedGroupClientEmails':
              summaryPayload['acceptedGroupClientEmails'],
          'groupClientsAllResponded':
              summaryPayload['groupClientsAllResponded'],
          'brandStatus': summaryPayload['brandStatus'],
          'clientStatus': summaryPayload['clientStatus'],
          'artistStatus': summaryPayload['artistStatus'],
          'directArtistStatus': summaryPayload['directArtistStatus'],
          'clientResponseStatus': summaryPayload['clientResponseStatus'],
          'openToClientPool': summaryPayload['openToClientPool'],
        }..removeWhere((_, value) => value == null),
      ),
    );

    final update = <String, dynamic>{
      'id': requestId,
      'status':
          summaryPayload['status'] ?? detailsPayload['status'] ?? 'pending',
      'details': mergedDetails,
      'updated_at': nowIso,
      'accepted_by_client_email': summaryPayload['acceptedByClientEmail'],
      'declined_by_client_emails': summaryPayload['declinedByClientEmails'],
      'open_to_client_pool': summaryPayload['openToClientPool'],
      'client_response_status': summaryPayload['clientResponseStatus'],
      'artist_status': summaryPayload['artistStatus'],
      'brand_status': summaryPayload['brandStatus'],
      'client_status': summaryPayload['clientStatus'],
    }..removeWhere((_, value) => value == null);

    final columns = await _tableColumns(table);
    update.removeWhere((key, _) => !columns.contains(key));

    update.remove('id');
    await _supabase.from(table).update(update).eq('id', requestId);

    // Keep the optional details table in sync only when it exists and accepts
    // these columns. The root details JSON is the source of truth.
    try {
      final detailsTable = _detailsTableForCollection(collection);
      final detailColumns = await _tableColumns(detailsTable);
      final detailsUpdate = <String, dynamic>{
        'request_id': requestId,
        'id': requestId,
        'details': mergedDetails,
        'payload': mergedDetails,
        'status':
            summaryPayload['status'] ?? detailsPayload['status'] ?? 'pending',
        'updated_at': nowIso,
      };
      detailsUpdate.removeWhere((key, _) => !detailColumns.contains(key));
      if (detailsUpdate.containsKey('request_id') ||
          detailsUpdate.containsKey('id')) {
        await _supabase.from(detailsTable).upsert(detailsUpdate);
      }
    } catch (_) {}
  }

  Future<void> _loadHeaderIdentity() async {
    final auth = _supabase.auth.currentUser;
    final uid = (auth?.id ?? '').trim();
    final email = (auth?.email ?? '').trim().toLowerCase();
    String pick(Map<String, dynamic> data, List<String> keys) {
      for (final key in keys) {
        final value = (data[key] ?? '').toString().trim();
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    Future<Map<String, dynamic>?> readFrom(String collection) async {
      return _readRow(collection, id: uid, email: email);
    }

    try {
      for (final c in const <String>['client', 'client_artist']) {
        final data = await readFrom(c);
        if (data == null) continue;
        final profile = _asMap(data['profile']);
        final basic = _asMap(data['basic']);
        final avatar =
            pick(data, const ['profileImageUrl', 'avatarUrl']).isNotEmpty
            ? pick(data, const ['profileImageUrl', 'avatarUrl'])
            : (pick(profile, const [
                    'profileImageUrl',
                    'avatarUrl',
                    'photoUrl',
                  ]).isNotEmpty
                  ? pick(profile, const [
                      'profileImageUrl',
                      'avatarUrl',
                      'photoUrl',
                    ])
                  : pick(basic, const [
                      'profileImageUrl',
                      'avatarUrl',
                      'photoUrl',
                    ]));
        final name = pick(data, const ['displayName', 'name']).isNotEmpty
            ? pick(data, const ['displayName', 'name'])
            : (pick(profile, const ['name', 'displayName']).isNotEmpty
                  ? pick(profile, const ['name', 'displayName'])
                  : pick(basic, const ['name', 'displayName']));
        if (!mounted) return;
        setState(() {
          _headerAvatarUrl = avatar;
          _headerDisplayName = name;
        });
        break;
      }
    } catch (e) {
      debugPrint('[ClientCampaignsPage] _loadHeaderIdentity failed: $e');
    }
  }

  void _listenRequests() {
    if (_companyChannel != null) {
      _supabase.removeChannel(_companyChannel!);
    }
    _companyChannel = _supabase
        .channel('client-requests-company-custom-requests')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'company_custom_requests',
          callback: (_) => unawaited(_reload()),
        )
        .subscribe();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    try {
      final currentEmail = (_supabase.auth.currentUser?.email ?? '')
          .trim()
          .toLowerCase();
      if (currentEmail.isEmpty) {
        if (!mounted) return;
        setState(() {
          _items = const <ClientRequestV2>[];
          _brandRequests = const <ClientRequestV2>[];
          _clientRequests = const <ClientRequestV2>[];
          _loading = false;
        });
        return;
      }

      _currentClientIsBrandPartner = await _isCurrentClientBrandPartner(
        currentEmail,
      );
      _currentClientNfcEligible = await _isCurrentClientNfcEligible(
        currentEmail,
      );

      final all = await ArtistRequestsRepository.fetchAllRequests();
      final brandVisible = <ClientRequestV2>[];
      final clientVisible = <ClientRequestV2>[];

      for (final request in all) {
        if (_hiddenRequestIds.contains(request.id)) continue;

        final isBrandSource = _isCompanyCustomRequestSource(
          request.sourceCollection,
        );

        if (isBrandSource) {
          final visibleAsClient = _isVisibleForClient(
            request: request,
            clientEmail: currentEmail,
          );
          if (visibleAsClient) {
            final requiresNfc = await _requestRequiresNfc(request);
            if (!requiresNfc ||
                (_currentClientIsBrandPartner && _currentClientNfcEligible)) {
              brandVisible.add(request);
              continue;
            }
          }

          // After a Brand Request is accepted by a client, eligible artists can
          // see it as an artist-side Client Request. This keeps the
          // client-artist workflow separate: first accept as client, then handle
          // the artist work only after the client acceptance stage is complete.
          if (_isVisibleForArtist(
            request: request,
            artistEmail: currentEmail,
          )) {
            clientVisible.add(request);
          }
          continue;
        }

        if (_isVisibleForArtist(request: request, artistEmail: currentEmail)) {
          clientVisible.add(request);
        }
      }

      brandVisible.sort((a, b) => a.neededBy.compareTo(b.neededBy));
      clientVisible.sort((a, b) => a.neededBy.compareTo(b.neededBy));

      if (!mounted) return;
      setState(() {
        _brandRequests = brandVisible;
        _clientRequests = clientVisible;
        _items = <ClientRequestV2>[...brandVisible, ...clientVisible];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items = const <ClientRequestV2>[];
        _brandRequests = const <ClientRequestV2>[];
        _clientRequests = const <ClientRequestV2>[];
        _loading = false;
      });
    }
  }

  Future<bool> _isCurrentClientBrandPartner(String clientEmail) async {
    final normalized = clientEmail.trim().toLowerCase();
    final uid = (_supabase.auth.currentUser?.id ?? '').trim();
    if (normalized.isEmpty && uid.isEmpty) return false;

    for (final collection in const <String>[
      'client',
      'client_artist',
      'clients',
    ]) {
      final columns = columnsForProfileTable(collection);
      try {
        if (uid.isNotEmpty) {
          final query = _supabase.from(collection).select(columns ?? '*');
          final rows = await query.eq('id', uid).limit(20);
          for (final row in rows) {
            final data = _asMap(row);
            if (_isBrandPartnerClient(data)) return true;
          }
        }
        if (normalized.isNotEmpty) {
          final query = _supabase.from(collection).select(columns ?? '*');
          final rows = await query.eq('email', normalized).limit(50);
          for (final row in rows) {
            final data = _asMap(row);
            if (_isBrandPartnerClient(data)) return true;
          }
        }
      } catch (_) {}
    }
    return false;
  }

  bool _isVisibleForClient({
    required ClientRequestV2 request,
    required String clientEmail,
  }) {
    final viewerEmail = clientEmail.trim().toLowerCase();
    if (viewerEmail.isEmpty) return false;

    final acceptedByClient = request.acceptedByClientEmail.trim().toLowerCase();
    final rawStatus = request.status.name.trim().toLowerCase();
    final isOpenForClientReview =
        request.status == RequestStatusV2.inReview ||
        request.status == RequestStatusV2.accepted ||
        rawStatus == 'pending' ||
        rawStatus == 'inreview' ||
        rawStatus == 'in_review' ||
        rawStatus == 'accepted';
    if (!isOpenForClientReview) return false;

    final clientResponseStatus = request.clientResponseStatus
        .trim()
        .toLowerCase();
    if (!request.openToClientPool &&
        request.orderType == RequestOrderTypeV2.single &&
        (clientResponseStatus == 'accepted' ||
            clientResponseStatus == 'declined')) {
      return false;
    }
    if (request.openToClientPool && acceptedByClient.isNotEmpty) {
      return false;
    }

    final isGroupOrder = request.orderType == RequestOrderTypeV2.group;
    final acceptedGroupClients = request.acceptedGroupClientEmails
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();

    if (!isGroupOrder && acceptedByClient == viewerEmail) {
      return false;
    }

    if (isGroupOrder && acceptedGroupClients.contains(viewerEmail)) {
      return false;
    }

    final declinedByClient = request.declinedByClientEmails
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    if (declinedByClient.contains(viewerEmail)) return false;

    // The client who created/submitted the request should not see it
    // in their own incoming client-pool request list.
    final creatorEmail = request.clientEmail.trim().toLowerCase();
    if (creatorEmail.isNotEmpty && creatorEmail == viewerEmail) return false;

    if (request.openToClientPool) return true;

    return shouldShowScenario41ToDirectClient(
      openToClientPool: request.openToClientPool,
      orderType: request.orderType,
      selectedClientEmail: request.selectedClientEmail,
      selectedGroupClientEmails: request.selectedGroupClientEmails,
      viewerEmail: viewerEmail,
    );
  }

  bool _isVisibleForArtist({
    required ClientRequestV2 request,
    required String artistEmail,
  }) {
    final viewerEmail = artistEmail.trim().toLowerCase();
    if (viewerEmail.isEmpty) return false;

    final creatorEmail = request.clientEmail.trim().toLowerCase();
    if (creatorEmail.isNotEmpty && creatorEmail == viewerEmail) return false;

    final acceptedByArtist = request.acceptedByArtistEmail.trim().toLowerCase();
    if (acceptedByArtist.isNotEmpty && acceptedByArtist != viewerEmail) {
      return false;
    }

    final declinedArtists = request.declinedByArtistEmails
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    if (declinedArtists.contains(viewerEmail)) return false;

    final rawStatus = request.status.name.trim().toLowerCase();
    final terminal =
        rawStatus == 'declined' ||
        rawStatus == 'cancelled' ||
        rawStatus == 'canceled' ||
        rawStatus == 'expired' ||
        rawStatus == 'delivered' ||
        rawStatus == 'shipped';
    if (terminal) return false;

    final isBrandSource = _isCompanyCustomRequestSource(
      request.sourceCollection,
    );
    if (isBrandSource) {
      final acceptedClient = request.acceptedByClientEmail.trim().toLowerCase();
      final acceptedGroup = request.acceptedGroupClientEmails
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toSet();
      final clientAccepted =
          acceptedClient.isNotEmpty || acceptedGroup.isNotEmpty;
      if (!clientAccepted) return false;
    }

    if (request.isDirectRequest) {
      final selected = request.selectedArtistEmail.trim().toLowerCase();
      if (selected.isEmpty) return true;
      return selected == viewerEmail;
    }

    return true;
  }

  Future<bool> _requestRequiresNfc(ClientRequestV2 request) async {
    try {
      final root = await _readRequestRoot(request);
      final details = await _readRequestDetails(request);
      return _requestRequiresNfcFromMaps(root, details);
    } catch (_) {
      return false;
    }
  }

  String _displayDateLabel(dynamic value) {
    if (value == null) return '';
    if (value is DateTime) return _needByLabel(value);
    final text = value.toString().trim();
    if (text.isEmpty) return '';
    final parsed = DateTime.tryParse(text);
    if (parsed != null) return _needByLabel(parsed);
    return text;
  }

  Future<String> _loadJntRevealDateLabel(ClientRequestV2 request) async {
    if (!_isCompanyCustomRequestSource(request.sourceCollection)) return '';
    try {
      final root = await _readRequestRoot(request);
      final details = await _readRequestDetails(request);
      final payload = _asMap(details['payload']).isNotEmpty
          ? _asMap(details['payload'])
          : details;
      final requestDetails = _asMap(payload['requestDetails']).isNotEmpty
          ? _asMap(payload['requestDetails'])
          : _asMap(details['requestDetails']);

      for (final value in <Object?>[
        root['jntRevealDateDisplay'],
        root['jnt_reveal_date_display'],
        details['jntRevealDateDisplay'],
        details['jnt_reveal_date_display'],
        payload['jntRevealDateDisplay'],
        payload['jnt_reveal_date_display'],
        requestDetails['jntRevealDateDisplay'],
        requestDetails['jnt_reveal_date_display'],
        root['jntRevealDate'],
        root['jnt_reveal_date'],
        details['jntRevealDate'],
        details['jnt_reveal_date'],
        payload['jntRevealDate'],
        payload['jnt_reveal_date'],
        requestDetails['jntRevealDate'],
        requestDetails['jnt_reveal_date'],
        root['revealDate'],
        details['revealDate'],
        payload['revealDate'],
        requestDetails['revealDate'],
      ]) {
        final label = _displayDateLabel(value);
        if (label.isNotEmpty) return label;
      }
    } catch (_) {}
    return '';
  }

  bool _requestRequiresNfcFromMaps(
    Map<String, dynamic> root,
    Map<String, dynamic> details,
  ) {
    bool truthy(Object? value) {
      if (value == null) return false;
      if (value is bool) return value;
      if (value is num) return value != 0;
      final text = value.toString().trim().toLowerCase();
      return text == 'true' || text == '1' || text == 'yes' || text == 'y';
    }

    Map<String, dynamic> asMap(Object? value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        return value.map((key, val) => MapEntry(key.toString(), val));
      }
      return const <String, dynamic>{};
    }

    final payload = asMap(details['payload']).isNotEmpty
        ? asMap(details['payload'])
        : details;
    final requestDetails = asMap(payload['requestDetails']).isNotEmpty
        ? asMap(payload['requestDetails'])
        : asMap(details['requestDetails']);
    final order = asMap(payload['order']).isNotEmpty
        ? asMap(payload['order'])
        : asMap(details['order']);
    final nfc = asMap(payload['nfc']).isNotEmpty
        ? asMap(payload['nfc'])
        : (asMap(details['nfc']).isNotEmpty
              ? asMap(details['nfc'])
              : asMap(root['nfc']));

    final candidates = <Object?>[
      root['requiresNfc'],
      root['requiresNFC'],
      root['nfcRequired'],
      root['isNfcRequired'],
      root['hasNfc'],
      root['hasNFC'],
      root['nfcEnabled'],
      details['requiresNfc'],
      details['requiresNFC'],
      details['nfcRequired'],
      details['isNfcRequired'],
      details['hasNfc'],
      details['hasNFC'],
      payload['requiresNfc'],
      payload['requiresNFC'],
      payload['nfcRequired'],
      payload['isNfcRequired'],
      payload['hasNfc'],
      payload['hasNFC'],
      requestDetails['requiresNfc'],
      requestDetails['requiresNFC'],
      requestDetails['nfcRequired'],
      requestDetails['isNfcRequired'],
      requestDetails['hasNfc'],
      requestDetails['hasNFC'],
      order['requiresNfc'],
      order['requiresNFC'],
      order['nfcRequired'],
      order['isNfcRequired'],
      order['hasNfc'],
      order['hasNFC'],
      nfc['required'],
      nfc['enabled'],
      nfc['requiresNfc'],
      nfc['hasNfc'],
    ];
    return candidates.any(truthy);
  }

  Widget _nfcRequiredBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.balletSlippers.withValues(alpha: 0.92),
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.nfc_rounded, size: 14, color: AppColors.blackCat),
          SizedBox(width: 4),
          Text(
            'NFC',
            style: TextStyle(
              color: AppColors.blackCat,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              fontFamily: 'Arial',
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(ClientRequestV2 request) {
    return 'Pending';
  }

  String _needByLabel(DateTime date) {
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
    return '${months[(date.month - 1).clamp(0, 11)]} ${date.day}, ${date.year}';
  }

  String _submittedLabel(DateTime date) {
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
    return '${months[(date.month - 1).clamp(0, 11)]} ${date.day}, ${date.year}';
  }

  String _acceptByLabel(DateTime date) {
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
    return '${months[(date.month - 1).clamp(0, 11)]} ${date.day}, ${date.year}';
  }

  Future<void> _openDetails(ClientRequestV2 request) async {
    final artistStyleRequestView =
        widget.splitArtistVisibleRequestsBySource &&
        widget.showClientRequests &&
        !widget.showBrandRequests;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return ClientCampaignDetailsPage(
          request: request,
          headerTitleOverride:
              widget.useCampaignNaming &&
                  widget.showBrandRequests &&
                  !widget.showClientRequests
              ? 'Brand Campaign Request'
              : null,
          onDecline: () async {
            if (artistStyleRequestView) {
              await _persistArtistDecline(request);
            } else {
              await _respondToBrandRequest(request: request, accept: false);
            }

            if (mounted) {
              setState(() {
                _hiddenRequestIds.add(request.id);
                _items = _items.where((item) => item.id != request.id).toList();
              });
            }

            await _reload();

            if (sheetContext.mounted) Navigator.of(sheetContext).pop();
          },
          onAccept: () async {
            if (artistStyleRequestView) {
              final accepted = await showModalBottomSheet<dynamic>(
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

              if (accepted == null) return;

              final acceptedTotal = _acceptedArtistTotal(accepted);
              final optimistic = request.copyWith(
                status: RequestStatusV2.designing,
                artistFinalAmount: double.parse(
                  acceptedTotal.toStringAsFixed(2),
                ),
              );

              if (mounted) {
                setState(() {
                  _replaceById(request.id, optimistic);
                });
              }

              final persisted = await _persistArtistAcceptance(
                request,
                acceptedTotal,
              );
              if (!persisted) {
                throw Exception('Could not update request in database.');
              }
            } else {
              await _respondToBrandRequest(request: request, accept: true);

              if (mounted) {
                setState(() {
                  _hiddenRequestIds.add(request.id);
                  _items = _items
                      .where((item) => item.id != request.id)
                      .toList();
                });
              }
            }

            await _reload();

            if (sheetContext.mounted) Navigator.of(sheetContext).pop();
          },
        );
      },
    );
  }

  void _replaceById(String id, ClientRequestV2 replacement) {
    List<ClientRequestV2> replaceIn(List<ClientRequestV2> source) {
      return source
          .map((item) => item.id == id ? replacement : item)
          .toList(growable: false);
    }

    _items = replaceIn(_items);
    _brandRequests = replaceIn(_brandRequests);
    _clientRequests = replaceIn(_clientRequests);
  }

  double _acceptedArtistTotal(dynamic accepted) {
    double readNum(Object? raw) => raw is num ? raw.toDouble() : 0;

    try {
      final dynamic value = accepted;
      final yourPrice = readNum(value.yourPrice);
      final shipping = readNum(value.shipping);
      final extra = readNum(value.extra);
      return yourPrice + shipping + extra;
    } catch (_) {
      return 0;
    }
  }

  Future<bool> _persistArtistAcceptance(
    ClientRequestV2 request,
    double acceptedTotal,
  ) async {
    final normalizedTotal = double.parse(acceptedTotal.toStringAsFixed(2));

    try {
      await _supabase.rpc(
        'artist_accept_request',
        params: <String, dynamic>{
          'p_request_id': request.id,
          'p_order_number': request.orderNumber.trim().isEmpty
              ? null
              : request.orderNumber.trim(),
          'p_artist_amount': normalizedTotal,
        },
      );
      return true;
    } catch (e) {
      debugPrint('[ClientCampaignsPage] artist_accept_request failed: $e');
      return false;
    }
  }

  Future<void> _persistArtistDecline(ClientRequestV2 request) async {
    final artistEmail = (_supabase.auth.currentUser?.email ?? '')
        .trim()
        .toLowerCase();
    if (artistEmail.isEmpty) {
      throw Exception('Missing signed-in artist email.');
    }

    try {
      await _supabase.rpc(
        'artist_decline_request_for_history',
        params: <String, dynamic>{
          'p_request_id': request.id,
          'p_source_collection': request.sourceCollection,
          'p_artist_email': artistEmail,
        },
      );
      return;
    } catch (rpcError) {
      debugPrint(
        '[ClientCampaignsPage] artist_decline_request_for_history failed: $rpcError',
      );
    }

    final table = _tableForRequestCollection(request.sourceCollection);
    final declinedAtIso = DateTime.now().toUtc().toIso8601String();
    const reason = 'Artist declined the request';

    await _supabase
        .from(table)
        .update(<String, dynamic>{
          'status': 'declined',
          'artist_status': 'declined',
          'direct_artist_status': 'declined',
          'declined_by_artist_email': artistEmail,
          'artist_declined_at': declinedAtIso,
          'completion_decline_reason': reason,
          'completion_decline_description': reason,
          'updated_at': declinedAtIso,
        })
        .eq('id', request.id);
  }

  String _tableForRequestCollection(String name) {
    switch (name) {
      case 'Client_Custom_Requests':
        return 'client_custom_requests';
      case 'Company_Custom_Requests':
        return 'company_custom_requests';
      default:
        return name
            .replaceAllMapped(
              RegExp(r'([a-z0-9])([A-Z])'),
              (match) => '${match.group(1)}_${match.group(2)}',
            )
            .replaceAll(' ', '_')
            .toLowerCase();
    }
  }

  Future<void> _respondToBrandRequest({
    required ClientRequestV2 request,
    required bool accept,
  }) async {
    final clientEmail = (_supabase.auth.currentUser?.email ?? '')
        .trim()
        .toLowerCase();
    if (clientEmail.isEmpty) {
      throw Exception('Missing signed-in client email.');
    }

    final selectedClientEmail = request.selectedClientEmail
        .trim()
        .toLowerCase();
    final selectedGroupClientEmails = request.selectedGroupClientEmails
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();

    if (!request.openToClientPool &&
        (request.orderType == RequestOrderTypeV2.group
            ? !selectedGroupClientEmails.contains(clientEmail)
            : (selectedClientEmail.isNotEmpty &&
                  selectedClientEmail != clientEmail))) {
      throw Exception('Only the designated client can respond.');
    }

    final isGroupOrder = request.orderType == RequestOrderTypeV2.group;

    Set<String> normList(Object? raw) => _asEmailSet(raw);

    final rootData = await _readRequestRoot(request);
    final detailsData = await _readRequestDetails(request);
    final orderData = _asMap(detailsData['order']);
    final brandRecipientEmails =
        await NotificationsService.resolveBrandRecipientEmails(
          rootData: rootData,
          detailsData: detailsData,
          orderData: orderData,
          excludeEmails: <String>[clientEmail],
        );
    DateTime? requestAcceptByDate(Object? value) {
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    final brandRequestAcceptBy =
        requestAcceptByDate(rootData['requestAcceptBy']) ??
        requestAcceptByDate(detailsData['requestAcceptBy']) ??
        requestAcceptByDate(orderData['requestAcceptBy']) ??
        DateTime(
          request.neededBy.year,
          request.neededBy.month,
          request.neededBy.day,
        ).subtract(const Duration(days: 5));
    final brandRequestTimedOut =
        _isCompanyCustomRequestSource(request.sourceCollection) &&
        DateTime.now().isAfter(
          DateTime(
            brandRequestAcceptBy.year,
            brandRequestAcceptBy.month,
            brandRequestAcceptBy.day,
          ).add(const Duration(days: 1)),
        ) &&
        request.acceptedByClientEmail.trim().isEmpty &&
        request.declinedByClientEmails.isEmpty;

    if (brandRequestTimedOut && !accept) {
      final acceptByLabel = _firstNonEmpty(<Object?>[
        rootData['requestAcceptByDisplay'],
        detailsData['requestAcceptByDisplay'],
        orderData['requestAcceptByDisplay'],
      ], fallback: _monthDayYear(brandRequestAcceptBy));
      final cancellationReason =
          'Request was not accepted/rejected by $acceptByLabel';
      await _persistStatusUpdate(
        request: request,
        status: 'cancelled',
        summaryExtra: <String, dynamic>{
          'cancelReason': cancellationReason,
          'cancelledAt': DateTime.now().toIso8601String(),
        },
        detailsExtra: <String, dynamic>{
          'cancelReason': cancellationReason,
          'cancelledAt': DateTime.now().toIso8601String(),
        },
      );
      return;
    }

    final selected = request.selectedGroupClientEmails
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    var accepted = <String>{
      ...request.acceptedGroupClientEmails
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty),
      ...normList(rootData['acceptedGroupClientEmails']),
      ...normList(detailsData['acceptedGroupClientEmails']),
    };
    var declined = <String>{
      ...request.declinedByClientEmails
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty),
      ...normList(rootData['declinedByClientEmails']),
      ...normList(detailsData['declinedByClientEmails']),
    };

    if (!accept) {
      if (isGroupOrder && !request.openToClientPool) {
        accepted.remove(clientEmail);
        declined.add(clientEmail);
        final responded = <String>{...accepted, ...declined};
        final allResponded =
            selected.isNotEmpty && selected.every(responded.contains);
        final artistStatus = allResponded ? 'in_review' : 'pending';
        final overallStatus = allResponded
            ? (accepted.isNotEmpty ? 'accepted' : 'declined')
            : 'pending';

        await _persistStatusUpdate(
          request: request,
          status: overallStatus,
          summaryExtra: <String, dynamic>{
            'acceptedByClientEmail': '',
            if (!isGroupOrder) 'clientResponseStatus': 'declined',
            'acceptedGroupClientEmails': accepted.toList(growable: false),
            'declinedByClientEmails': declined.toList(growable: false),
            'groupClientsAllResponded': allResponded,
            'brandStatus': 'pending',
            'clientStatus': overallStatus,
            'artistStatus': artistStatus,
            'directArtistStatus': artistStatus,
          },
          detailsExtra: <String, dynamic>{
            'acceptedGroupClientEmails': accepted.toList(growable: false),
            if (!isGroupOrder) 'clientResponseStatus': 'declined',
            'declinedByClientEmails': declined.toList(growable: false),
            'groupClientsAllResponded': allResponded,
            'acceptance': const <String, dynamic>{'acceptedByClientEmail': ''},
            'roleStatuses': <String, dynamic>{
              'brand': 'pending',
              'client': overallStatus,
              'artist': artistStatus,
            },
            'routing': <String, dynamic>{'directArtistStatus': artistStatus},
          },
        );
        return;
      }

      if (request.openToClientPool) {
        await _persistStatusUpdate(
          request: request,
          status: 'in_review',
          summaryExtra: <String, dynamic>{
            'acceptedByClientEmail': '',
            if (!isGroupOrder) 'clientResponseStatus': 'declined',
            'declinedByClientEmails':
                <String>[...request.declinedByClientEmails, clientEmail]
                    .map((e) => e.trim().toLowerCase())
                    .where((e) => e.isNotEmpty)
                    .toSet()
                    .toList(),
            'updatedAt': DateTime.now().toIso8601String(),
          },
          detailsExtra: <String, dynamic>{
            'declinedByClientEmails':
                <String>[...request.declinedByClientEmails, clientEmail]
                    .map((e) => e.trim().toLowerCase())
                    .where((e) => e.isNotEmpty)
                    .toSet()
                    .toList(),
            if (!isGroupOrder) 'clientResponseStatus': 'declined',
            'acceptance': const <String, dynamic>{'acceptedByClientEmail': ''},
            'lastClientDeclinedAt': DateTime.now().toIso8601String(),
          },
        );
      } else {
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
            'declinedByClientEmails':
                <String>[...request.declinedByClientEmails, clientEmail]
                    .map((e) => e.trim().toLowerCase())
                    .where((e) => e.isNotEmpty)
                    .toSet()
                    .toList(),
          },
          detailsExtra: <String, dynamic>{
            'openToClientPool': true,
            'declinedByClientEmails':
                <String>[...request.declinedByClientEmails, clientEmail]
                    .map((e) => e.trim().toLowerCase())
                    .where((e) => e.isNotEmpty)
                    .toSet()
                    .toList(),
            'acceptance': const <String, dynamic>{'acceptedByClientEmail': ''},
            'roleStatuses': const <String, dynamic>{
              'brand': 'pending',
              'client': 'pending',
              'artist': 'pending',
            },
            'routing': <String, dynamic>{
              'directClientStatus': 'declined',
              'clientPoolStatus': 'pending',
              'releasedToClientPoolAt': DateTime.now().toIso8601String(),
            },
          },
        );
      }
      return;
    }

    final clientData = await _loadAcceptingClientData(clientEmail);
    final clientName = (clientData['name'] as String? ?? '').trim();
    final clientProfileImage = (clientData['profileImage'] as String? ?? '')
        .trim();
    final nailShape = (clientData['nailShape'] as String? ?? '').trim();
    final nailLength = (clientData['nailLength'] as String? ?? '').trim();
    final nailDimensions = _asMap(clientData['nailDimensions']);
    accepted = <String>{...accepted, clientEmail};
    declined = <String>{...declined}..remove(clientEmail);
    final responded = <String>{...accepted, ...declined};
    final allResponded =
        !isGroupOrder ||
        (selected.isNotEmpty && selected.every(responded.contains));
    final allAccepted =
        !isGroupOrder ||
        (selected.isNotEmpty && selected.every(accepted.contains));
    final artistStatus = allResponded ? 'in_review' : 'pending';
    List<dynamic>? updatedGroupClients;
    if (isGroupOrder) {
      final groupOrderMap = _asMap(detailsData['groupOrder']);
      final rawClients = _asList(groupOrderMap['clients']);
      updatedGroupClients = rawClients
          .map((raw) {
            if (raw is! Map) return raw;
            final item = Map<String, dynamic>.from(raw);
            final itemEmail = (item['clientEmail'] ?? '')
                .toString()
                .trim()
                .toLowerCase();
            if (itemEmail != clientEmail) return item;
            item['responseStatus'] = 'accepted';
            item['acceptedAt'] = DateTime.now().toIso8601String();
            item['clientName'] = clientName.isNotEmpty
                ? clientName
                : item['clientName'];
            item['savedNails'] = <String, dynamic>{
              if (nailShape.isNotEmpty) 'shape': nailShape,
              if (nailLength.isNotEmpty) 'length': nailLength,
              'dimensions': nailDimensions,
            };
            return item;
          })
          .toList(growable: false);
    }

    await _persistStatusUpdate(
      request: request,
      status: 'pending',
      summaryExtra: <String, dynamic>{
        'acceptedByClientEmail': clientEmail,
        if (!isGroupOrder) 'clientResponseStatus': 'accepted',
        if (!isGroupOrder) 'openToClientPool': false,
        if (!isGroupOrder) 'clientPoolStatus': 'accepted',
        'acceptedByClientAt': DateTime.now().toIso8601String(),
        'acceptedGroupClientEmails': accepted.toList(growable: false),
        'declinedByClientEmails': declined.toList(growable: false),
        'groupClientsAllResponded': allResponded,
        'brandStatus': 'pending',
        'clientStatus': 'pending',
        'artistStatus': artistStatus,
        'directArtistStatus': artistStatus,
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
          'acceptedByClientAt': DateTime.now().toIso8601String(),
          if (!isGroupOrder) 'clientResponseStatus': 'accepted',
        },
        if (!isGroupOrder) 'openToClientPool': false,
        if (!isGroupOrder) 'clientPoolStatus': 'accepted',
        if (!isGroupOrder) 'clientResponseStatus': 'accepted',
        'acceptedGroupClientEmails': accepted.toList(growable: false),
        'declinedByClientEmails': declined.toList(growable: false),
        'groupClientsAllResponded': allResponded,
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
          'artist': artistStatus,
        },
        'routing': <String, dynamic>{'directArtistStatus': artistStatus},
        if (updatedGroupClients != null)
          'groupOrder': <String, dynamic>{'clients': updatedGroupClients},
      },
    );
    final campaignName = _firstNonEmpty(<Object?>[
      rootData['campaignName'],
      rootData['title'],
      request.title,
    ], fallback: 'Campaign');
    final brandName = _firstNonEmpty(<Object?>[
      rootData['companyName'],
      rootData['brandName'],
      request.clientName,
    ], fallback: 'Brand');
    final acceptedClientName = clientName.isNotEmpty ? clientName : 'Client';
    final normalizedOrderNumber = request.orderNumber.trim().isNotEmpty
        ? request.orderNumber.trim()
        : request.id;

    // Notifications are non-blocking for the accept flow. The DB update above is
    // the source of truth; notification failures should not keep the modal open
    // or prevent the request from moving to Orders.
    try {
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

      if (allResponded && allAccepted) {
        final summaryNames = <String>[];
        if (isGroupOrder) {
          final groupDetails = _asMap(detailsData['groupOrder']);
          final rawClients = _asList(groupDetails['clients']);
          for (final raw in rawClients) {
            final item = _asMap(raw);
            if (item.isEmpty) continue;
            final email = (item['clientEmail'] ?? '')
                .toString()
                .trim()
                .toLowerCase();
            final name = (item['clientName'] ?? '').toString().trim();
            if (email.isEmpty || name.isEmpty) continue;
            if (accepted.contains(email) && !summaryNames.contains(name)) {
              summaryNames.add(name);
            }
          }
        }
        final groupClientSummary = summaryNames.isNotEmpty
            ? summaryNames.join(', ')
            : acceptedClientName;
        await NotificationsService.notifyArtistsForBrandClientAcceptedRequest(
          clientName: groupClientSummary,
          brandName: brandName,
          campaignName: campaignName,
          isDirectRequest: request.isDirectRequest,
          selectedArtistEmail: request.selectedArtistEmail.trim().toLowerCase(),
          selectedArtistName: request.selectedArtist.trim(),
          orderId: request.id,
          sourceCollection: request.sourceCollection,
          orderNumber: request.orderNumber,
          allowNonLicensed: request.allowNonLicensed,
        );
      }
    } catch (_) {
      // Ignore notification failures. Request acceptance already succeeded.
    }
  }

  String _monthDayYear(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$month/$day/${date.year}';
  }

  Future<void> _persistStatusUpdate({
    required ClientRequestV2 request,
    required String status,
    Map<String, dynamic> summaryExtra = const <String, dynamic>{},
    Map<String, dynamic> detailsExtra = const <String, dynamic>{},
  }) async {
    final root = await _readRequestRoot(request);
    final details = await _readRequestDetails(request);
    await _upsertRequestPayload(
      request.sourceCollection,
      request.id,
      <String, dynamic>{...root, 'status': status, ...summaryExtra},
      <String, dynamic>{...details, 'status': status, ...detailsExtra},
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
      final columns = columnsForProfileTable(collection);
      final rows = await _supabase
          .from(collection)
          .select(columns ?? '*')
          .eq('email', normalizedEmail)
          .limit(1);
      if (rows.isEmpty) return const <String, dynamic>{};
      final data = _asMap(rows.first);
      final profile = _asMap(data['profile']);
      final basic = _asMap(data['basic']);
      final nail = _asMap(data['nailPreferences']);
      final profileNail = _asMap(profile['nailPreferences']);
      final dimensions = _asMap(nail['dimensions']);
      final profileDimensions = _asMap(profileNail['dimensions']);

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
        'nailShape': first(nail, const ['shape']).isNotEmpty
            ? first(nail, const ['shape'])
            : first(profileNail, const ['shape']),
        'nailLength': first(nail, const ['length']).isNotEmpty
            ? first(nail, const ['length'])
            : first(profileNail, const ['length']),
        'nailDimensions': <String, dynamic>{
          'lThumb': dimensions['lThumb'] ?? profileDimensions['lThumb'],
          'lIndex': dimensions['lIndex'] ?? profileDimensions['lIndex'],
          'lMiddle': dimensions['lMiddle'] ?? profileDimensions['lMiddle'],
          'lRing': dimensions['lRing'] ?? profileDimensions['lRing'],
          'lPinky': dimensions['lPinky'] ?? profileDimensions['lPinky'],
          'rThumb': dimensions['rThumb'] ?? profileDimensions['rThumb'],
          'rIndex': dimensions['rIndex'] ?? profileDimensions['rIndex'],
          'rMiddle': dimensions['rMiddle'] ?? profileDimensions['rMiddle'],
          'rRing': dimensions['rRing'] ?? profileDimensions['rRing'],
          'rPinky': dimensions['rPinky'] ?? profileDimensions['rPinky'],
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

  String _firstNonEmpty(List<Object?> values, {String fallback = ''}) {
    for (final value in values) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_loading) {
      content = const Center(child: CircularProgressIndicator());
    } else {
      final brandRequests = _brandRequests;
      final clientRequests = _clientRequests;
      final artistVisibleBrandRequests = clientRequests
          .where(
            (request) =>
                _isCompanyCustomRequestSource(request.sourceCollection),
          )
          .toList(growable: false);
      final artistVisibleClientRequests = clientRequests
          .where(
            (request) =>
                !_isCompanyCustomRequestSource(request.sourceCollection),
          )
          .toList(growable: false);

      Widget requestCard(ClientRequestV2 request) {
        return FutureBuilder<String>(
          future: _loadJntRevealDateLabel(request),
          builder: (context, revealSnap) {
            final card = Semantics(
              button: true,
              label: 'Open request details for ${request.clientName}',
              child: ExcludeSemantics(
                child: InkWell(
                borderRadius: BorderRadius.zero,
                onTap: () => _openDetails(request),
                child: CompanyClientRequestCard(
                  request: request,
                  scale: 1.0,
                  displayStatus: _statusLabel(request),
                  needByLabel: _needByLabel(request.neededBy),
                  submittedLabel: _submittedLabel(
                    request.submittedAt ?? request.neededBy,
                  ),
                  acceptByLabel:
                      _isCompanyCustomRequestSource(request.sourceCollection)
                      ? _acceptByLabel(
                          DateTime(
                            request.neededBy.year,
                            request.neededBy.month,
                            request.neededBy.day,
                          ).subtract(const Duration(days: 5)),
                        )
                      : '',
                  jntRevealDateLabel: revealSnap.data?.trim() ?? '',
                  avatar: _avatarWidget(request),
                  previewImage: _previewWidget(request),
                  onTap: () => _openDetails(request),
                ),
              ),
              ),
            );

            return FutureBuilder<bool>(
              future: _requestRequiresNfc(request),
              builder: (context, snap) {
                final requiresNfc = snap.data ?? false;
                if (!requiresNfc) return card;
                return Stack(
                  children: [
                    card,
                    Positioned(top: 10, right: 10, child: _nfcRequiredBadge()),
                  ],
                );
              },
            );
          },
        );
      }

      Widget sectionTitle(String title) {
        return Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.blackCat,
          ),
        );
      }

      Widget sectionHelper(String text) {
        return Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: AppColors.blackCat.withValues(alpha: 0.62),
          ),
        );
      }

      Widget emptyText(String text) {
        return Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: AppColors.blackCat.withValues(alpha: 0.6),
          ),
        );
      }

      content = ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          if (widget.splitArtistVisibleRequestsBySource &&
              widget.showClientRequests &&
              !widget.showBrandRequests) ...[
            sectionTitle('Brand Requests'),
            const SizedBox(height: 4),
            sectionHelper(
              'These are brand requests available for you as an artist.',
            ),
            const SizedBox(height: 10),
            if (artistVisibleBrandRequests.isEmpty)
              emptyText('No brand requests available.')
            else ...[
              for (var i = 0; i < artistVisibleBrandRequests.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                requestCard(artistVisibleBrandRequests[i]),
              ],
            ],
            const SizedBox(height: 22),
            sectionTitle('Client Requests'),
            const SizedBox(height: 4),
            sectionHelper(
              'These are client requests available for you as an artist.',
            ),
            const SizedBox(height: 10),
            if (artistVisibleClientRequests.isEmpty)
              emptyText('No client requests available.')
            else ...[
              for (var i = 0; i < artistVisibleClientRequests.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                requestCard(artistVisibleClientRequests[i]),
              ],
            ],
          ] else ...[
            if (widget.showBrandRequests) ...[
              sectionTitle(
                widget.useCampaignNaming &&
                        widget.showBrandRequests &&
                        !widget.showClientRequests
                    ? 'Client Campaigns'
                    : 'Brand Requests',
              ),
              const SizedBox(height: 4),
              sectionHelper(
                widget.showClientRequests
                    ? 'Accept a Brand Request first. After client acceptance, eligible Artist Requests appear in Client Requests.'
                    : widget.useCampaignNaming &&
                          widget.showBrandRequests &&
                          !widget.showClientRequests
                    ? 'These are campaigns available to you.'
                    : 'These are brand campaigns available to you.',
              ),
              const SizedBox(height: 10),
              if (brandRequests.isEmpty)
                emptyText(
                  widget.useCampaignNaming &&
                          widget.showBrandRequests &&
                          !widget.showClientRequests
                      ? 'No campaigns available.'
                      : 'No brand requests available.',
                )
              else ...[
                for (var i = 0; i < brandRequests.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  requestCard(brandRequests[i]),
                ],
              ],
            ],
            if (widget.showBrandRequests && widget.showClientRequests)
              const SizedBox(height: 22),
            if (widget.showClientRequests) ...[
              sectionTitle('Client Requests'),
              const SizedBox(height: 4),
              sectionHelper(
                'These are requests available for you as an artist.',
              ),
              const SizedBox(height: 10),
              if (clientRequests.isEmpty)
                emptyText('No client requests available.')
              else ...[
                for (var i = 0; i < clientRequests.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  requestCard(clientRequests[i]),
                ],
              ],
            ],
          ],
        ],
      );
    }

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: 'Client campaigns',
      child: Scaffold(
      backgroundColor: AppColors.snow,
      appBar: JntStandardAppBar(
        onNotifications: () {
          if (widget.onOpenNotifications != null) {
            widget.onOpenNotifications!.call();
          } else {
            NotificationsPage.showAsModal(context);
          }
        },
        trailing: _AvatarMenu(
          onSelected: _onAvatarMenuSelected,
          displayName: _headerDisplayName.isNotEmpty
              ? _headerDisplayName
              : (_supabase.auth.currentUser?.userMetadata?['displayName'] ??
                        _supabase.auth.currentUser?.email ??
                        '')
                    .toString()
                    .trim(),
          avatarUrl: _headerAvatarUrl,
          showEarnings: widget.onOpenEarnings != null,
        ),
      ),
      body: content,
      ),
    );
  }

  Future<void> _onAvatarMenuSelected(String choice) async {
    if (choice == 'profile') {
      widget.onOpenProfile?.call();
      return;
    }
    if (choice == 'earnings') {
      widget.onOpenEarnings?.call();
      return;
    }
    if (choice == 'logout') {
      if (widget.onLogout != null) {
        widget.onLogout!.call();
        return;
      }
      try {
        await _supabase.auth.signOut();
      } catch (e) {
        debugPrint('[ClientCampaignsPage] signOut failed: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to log out: $e')),
        );
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  Widget _avatarWidget(ClientRequestV2 request) {
    final path = request.clientProfileImage.trim();
    if (path.isEmpty) {
      return const Icon(Icons.business, color: AppColors.blackCat);
    }
    return _imageFromPath(path, fallback: const Icon(Icons.business));
  }

  Future<String> _loadPreviewImagePath(ClientRequestV2 request) async {
    String pickBest(Iterable<String> values) {
      final list = values
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
      for (final item in list) {
        final v = item.trim().toLowerCase();
        if (v.startsWith('http://') ||
            v.startsWith('https://') ||
            v.startsWith('gs://') ||
            v.startsWith('assets/') ||
            v.startsWith('data:') ||
            v.startsWith('blob:') ||
            v.startsWith('content://') ||
            v.contains('/')) {
          return item.trim();
        }
      }
      return list.isEmpty ? '' : list.first.trim();
    }

    final fromModel = pickBest(<String>[
      ...request.clientImages.map((e) => e.trim()),
      request.previewImageAsset.trim(),
    ]);
    if (fromModel.isNotEmpty) return fromModel;

    Map<String, dynamic> asMap(dynamic value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        return value.map((key, value) => MapEntry(key.toString(), value));
      }
      return const <String, dynamic>{};
    }

    List<String> collectPhotos(List<Object?> sources) {
      final out = <String>{};
      void add(dynamic value) {
        if (value == null) return;
        if (value is String) {
          final v = value.trim();
          if (v.isNotEmpty) out.add(v);
          return;
        }
        if (value is List) {
          for (final item in value) {
            add(item);
          }
          return;
        }
        if (value is Map) {
          final map = Map<String, dynamic>.from(value);
          for (final key in const <String>[
            'imageUrl',
            'downloadUrl',
            'downloadURL',
            'url',
            'photoUrl',
            'image',
            'photo',
            'path',
            'storagePath',
            'fullPath',
            'ref',
            'src',
            'uri',
          ]) {
            add(map[key]);
          }
          map.forEach((key, value) {
            final lower = key.toString().toLowerCase();
            if (lower.contains('photo') ||
                lower.contains('image') ||
                lower.contains('inspiration') ||
                lower.contains('preview') ||
                lower.endsWith('url') ||
                lower.endsWith('path')) {
              add(value);
            }
          });
        }
      }

      for (final source in sources) {
        add(source);
      }
      return out.toList(growable: false);
    }

    try {
      final root = await _readRequestRoot(request);
      final details = await _readRequestDetails(request);
      final payload = asMap(details['payload']).isNotEmpty
          ? asMap(details['payload'])
          : details;
      final requestDetails = asMap(payload['requestDetails']).isNotEmpty
          ? asMap(payload['requestDetails'])
          : asMap(details['requestDetails']);
      final recovered = pickBest(
        collectPhotos(<Object?>[
          root['previewImage'],
          root['previewImageAsset'],
          root['brandInspirationPhotos'],
          root['inspirationPhotos'],
          root['inspirationPhotoUrls'],
          root['inspirationPhotoRefs'],
          root['photos'],
          root['clientImages'],
          payload['previewImage'],
          payload['previewImageAsset'],
          payload['brandInspirationPhotos'],
          payload['inspirationPhotos'],
          payload['inspirationPhotoUrls'],
          payload['inspirationPhotoRefs'],
          payload['photos'],
          payload['clientImages'],
          requestDetails['previewImage'],
          requestDetails['previewImageAsset'],
          requestDetails['brandInspirationPhotos'],
          requestDetails['inspirationPhotos'],
          requestDetails['inspirationPhotoUrls'],
          requestDetails['inspirationPhotoRefs'],
          requestDetails['photos'],
          requestDetails['clientImages'],
        ]),
      );
      if (recovered.isNotEmpty) return recovered;
    } catch (_) {}

    return '';
  }

  Widget _previewWidget(ClientRequestV2 request) {
    const fallback = Icon(Icons.image_outlined, color: AppColors.blackCat);
    return FutureBuilder<String>(
      future: _loadPreviewImagePath(request),
      builder: (_, snap) {
        final first = (snap.data ?? '').trim();
        if (first.isEmpty) return fallback;
        return _imageFromPath(first, fallback: fallback);
      },
    );
  }

  Widget _imageFromPath(String raw, {required Widget fallback}) {
    var path = raw.trim();
    for (var i = 0; i < 3; i++) {
      final decoded = Uri.decodeFull(path);
      if (decoded == path) break;
      path = decoded.trim();
    }
    if (path.isEmpty) return fallback;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        cacheWidth: kMaxImageDecodeDimension,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    if (path.startsWith('data:image/')) {
      try {
        final comma = path.indexOf(',');
        if (comma > 0) {
          final bytes = base64Decode(path.substring(comma + 1).trim());
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            cacheWidth: kMaxImageDecodeDimension,
            errorBuilder: (_, _, _) => fallback,
          );
        }
      } catch (_) {}
      return fallback;
    }
    if (path.startsWith('gs://')) {
      return FutureBuilder<String>(
        future: storage_resolver.StorageUrlResolver.resolve(
          path,
        ).then((v) => v ?? ''),
        builder: (_, snap) {
          final url = snap.data?.trim() ?? '';
          if (url.isEmpty) return fallback;
          return Image.network(
            url,
            fit: BoxFit.cover,
            cacheWidth: kMaxImageDecodeDimension,
            errorBuilder: (_, _, _) => fallback,
          );
        },
      );
    }
    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    if (!path.startsWith('http') &&
        !path.startsWith('assets/') &&
        !path.startsWith('gs://') &&
        !path.startsWith('data:') &&
        !path.startsWith('blob:') &&
        !path.startsWith('content://') &&
        (path.contains('/') || path.contains('\\'))) {
      return FutureBuilder<String>(
        future: storage_resolver.StorageUrlResolver.resolve(
          path,
        ).then((v) => v ?? ''),
        builder: (_, snap) {
          final url = snap.data?.trim() ?? '';
          if (url.isEmpty) return fallback;
          return Image.network(
            url,
            fit: BoxFit.cover,
            cacheWidth: kMaxImageDecodeDimension,
            errorBuilder: (_, _, _) => fallback,
          );
        },
      );
    }
    final isFile = path.startsWith('/') || path.contains(':\\');
    if (isFile) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    return fallback;
  }
}

class _AvatarMenu extends StatelessWidget {
  const _AvatarMenu({
    required this.onSelected,
    this.avatarUrl = '',
    this.displayName = '',
    this.showEarnings = false,
  });

  final ValueChanged<String> onSelected;
  final String avatarUrl;
  final String displayName;
  final bool showEarnings;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Account menu',
      offset: const Offset(0, 55),
      elevation: 8,
      color: AppColors.snow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      onSelected: onSelected,
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: 'profile',
          child: Row(
            children: [
              Icon(Icons.person_outline, size: 22),
              SizedBox(width: 14),
              Text(
                'Profile',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        if (showEarnings)
          const PopupMenuItem<String>(
            value: 'earnings',
            child: Row(
              children: [
                Icon(Icons.attach_money_outlined, size: 22),
                SizedBox(width: 14),
                Text(
                  'Earnings',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 22, color: AppColors.blackCat),
              SizedBox(width: 14),
              Text(
                'Logout',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.blackCat,
                ),
              ),
            ],
          ),
        ),
      ],
      child: SizedBox(
        height: JntHeaderMetrics.avatarSize,
        width: JntHeaderMetrics.avatarSize,
        child: ClipRRect(
          borderRadius: BorderRadius.zero,
          child: ClientProfileAvatarIcon(
            imageUrl: avatarUrl,
            displayName: displayName,
            size: JntHeaderMetrics.avatarSize,
            resolveCurrentUserFallback: true,
          ),
        ),
      ),
    );
  }
}
