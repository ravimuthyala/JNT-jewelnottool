import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/artist_request_legacy_models.dart'
    show ClientRequest, NailDimensions, RequestStatus;
import '../models/client_profile_models.dart' hide NailDimensions;
import '../services/ambassador_role_service.dart';
import '../theme/app_colors.dart';
import 'artist_calendar_page.dart';
import 'client_artist_artist_page.dart';
import 'client_artist_earnings_page.dart';
import 'client_artist_history_page.dart';
import 'client_artist_home_page.dart';
import 'client_artist_profile_page.dart';

class ClientArtistCalendarPage extends StatefulWidget {
  const ClientArtistCalendarPage({
    super.key,
    required this.profile,
    required this.showContinueProfileCard,
    required this.enableAllTabs,
    this.onOpenProfile,
    this.onLogout,
  });

  final ClientProfileDraft profile;
  final bool showContinueProfileCard;
  final bool enableAllTabs;
  final VoidCallback? onOpenProfile;
  final Future<void> Function()? onLogout;

  @override
  State<ClientArtistCalendarPage> createState() =>
      _ClientArtistCalendarPageState();
}

class _ClientArtistCalendarPageState extends State<ClientArtistCalendarPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<ClientRequest> _requests = const <ClientRequest>[];
  bool _showCampaignsTab = false;

  String get _viewerEmail =>
      (_supabase.auth.currentUser?.email ?? widget.profile.basic.email)
          .trim()
          .toLowerCase();
  String get _viewerId => (_supabase.auth.currentUser?.id ?? '').trim();

  @override
  void initState() {
    super.initState();
    unawaited(_loadCampaignVisibility());
    unawaited(_loadCalendarRequests());
  }

  Future<void> _loadCampaignVisibility() async {
    final show = await AmbassadorRoleService.currentUserIsAmbassador(
      fallbackEmail: widget.profile.basic.email,
    );
    if (!mounted) return;
    setState(() => _showCampaignsTab = show);
  }

  Future<void> _openProfile(BuildContext context) async {
    if (widget.onOpenProfile != null) {
      widget.onOpenProfile!.call();
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ClientArtistProfilePage(initialProfile: widget.profile),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    if (widget.onLogout != null) {
      await widget.onLogout!.call();
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  Future<void> _openHistory(BuildContext context) async {
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ClientArtistHistoryPage(
          profile: widget.profile,
          showContinueProfileCard: widget.showContinueProfileCard,
          enableAllTabs: widget.enableAllTabs,
          onOpenProfile: widget.onOpenProfile,
          onLogout: widget.onLogout,
        ),
      ),
    );
  }

  Future<void> _openArtist(BuildContext context) async {
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ClientArtistArtistPage(
          profile: widget.profile,
          showContinueProfileCard: widget.showContinueProfileCard,
          enableAllTabs: widget.enableAllTabs,
          showCampaignsTab: _showCampaignsTab,
          onOpenProfile: widget.onOpenProfile,
          onOpenHistory: () {
            _openHistory(context);
          },
          onOpenCalendar: () {},
          onLogout: widget.onLogout,
        ),
      ),
    );
  }

  void _openHomeTab(BuildContext context, int index) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ClientArtistHomePage(
          showContinueProfileCard: widget.showContinueProfileCard,
          enableAllTabs: widget.enableAllTabs,
          profile: widget.profile,
          initialTabIndex: index,
          onOpenProfile: widget.onOpenProfile,
          onLogout: widget.onLogout,
        ),
      ),
    );
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
  }

  String _firstNonEmpty(List<dynamic> values, {String fallback = ''}) {
    for (final value in values) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return fallback;
  }

  Object? _firstExisting(List<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;
      return value;
    }
    return null;
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse((value ?? '').toString().trim()) ?? 0;
  }

  bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = (value ?? '').toString().trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'yes';
  }

  DateTime? _parseDate(dynamic value) {
    if (value is DateTime) return value;
    final text = (value ?? '').toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  List<String> _photoList(dynamic raw) {
    if (raw is List) {
      return raw
          .map((item) {
            if (item is Map) {
              return _firstNonEmpty(<Object?>[
                item['imageUrl'],
                item['downloadUrl'],
                item['photoUrl'],
                item['url'],
                item['path'],
              ]);
            }
            return (item ?? '').toString().trim();
          })
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  Map<String, dynamic> _flattenRow(Map<String, dynamic> row) {
    final data = <String, dynamic>{...row};

    void merge(Object? raw) {
      final map = _asMap(raw);
      if (map.isNotEmpty) data.addAll(map);
    }

    merge(row['summary']);
    merge(row['details']);

    final details = _asMap(row['details']);
    final requestDetails = _asMap(details['requestDetails']);
    final payload = _asMap(details['payload']);
    final budget = _asMap(details['budget']);

    if (requestDetails.isNotEmpty) {
      data['requestDetails'] ??= requestDetails;
      data['description'] ??= requestDetails['description'];
      data['needBy'] ??= requestDetails['needBy'];
      data['nailPreferences'] ??= requestDetails['nailPreferences'];
      data['dimensions'] ??= requestDetails['dimensions'];
      data['inspirationPhotos'] ??= requestDetails['inspirationPhotos'];
    }

    if (payload.isNotEmpty) {
      data['payload'] ??= payload;
      data['description'] ??= payload['description'];
      data['needBy'] ??= payload['needBy'];
      data['nailPreferences'] ??= payload['nailPreferences'];
      data['dimensions'] ??= payload['dimensions'];
      data['inspirationPhotos'] ??= payload['inspirationPhotos'];
    }

    if (budget.isNotEmpty) {
      data['budgetMin'] ??= budget['min'];
      data['budgetMax'] ??= budget['max'];
    }

    data['inspirationPhotos'] ??= row['inspiration_photos'];
    return data;
  }

  bool _matchesCurrentClient(Map<String, dynamic> row) {
    final data = _flattenRow(row);
    final details = _asMap(row['details']);
    final requestDetails = _asMap(details['requestDetails']);
    final payload = _asMap(details['payload']);
    final summary = _asMap(row['summary']);

    final emails = <String>{
      _firstNonEmpty([row['client_email'], row['clientEmail']]).toLowerCase(),
      _firstNonEmpty([row['accepted_by_client_email'], row['acceptedByClientEmail']])
          .toLowerCase(),
      _firstNonEmpty([data['clientEmail']]).toLowerCase(),
      _firstNonEmpty([summary['clientEmail']]).toLowerCase(),
      _firstNonEmpty([requestDetails['clientEmail']]).toLowerCase(),
      _firstNonEmpty([payload['clientEmail']]).toLowerCase(),
    }..remove('');

    final ids = <String>{
      _firstNonEmpty([row['client_id'], row['clientId']]),
      _firstNonEmpty([row['created_by_uid'], row['createdByUid']]),
      _firstNonEmpty([data['clientId']]),
      _firstNonEmpty([summary['clientId']]),
      _firstNonEmpty([requestDetails['clientId']]),
      _firstNonEmpty([payload['clientId']]),
    }..remove('');

    return (_viewerEmail.isNotEmpty && emails.contains(_viewerEmail)) ||
        (_viewerId.isNotEmpty && ids.contains(_viewerId));
  }

  RequestStatus _statusFrom(dynamic raw) {
    final value = (raw ?? '').toString().trim().toLowerCase();
    switch (value) {
      case 'accepted':
      case 'in progress':
      case 'in_progress':
      case 'approved':
      case 'designing':
        return RequestStatus.accepted;
      case 'declined':
      case 'rejected':
        return RequestStatus.declined;
      case 'completed':
        return RequestStatus.completed;
      case 'shipped':
        return RequestStatus.shipped;
      case 'delivered':
        return RequestStatus.delivered;
      case 'cancelled':
        return RequestStatus.cancelled;
      case 'expired':
        return RequestStatus.expired;
      case 'pending':
      case 'submitted':
      case 'new':
        return RequestStatus.inReview;
      default:
        return RequestStatus.inReview;
    }
  }

  String _dimText(dynamic raw) {
    final text = (raw ?? '').toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
  }

  ClientRequest? _mapRequest(Map<String, dynamic> row, {required bool brand}) {
    try {
      final data = _flattenRow(row);
      final requestDetails = _asMap(data['requestDetails']);
      final nailPrefs = _asMap(
        _firstExisting([data['nailPreferences'], requestDetails['nailPreferences']]),
      );
      final dimensions = _asMap(
        _firstExisting([nailPrefs['dimensions'], data['dimensions']]),
      );

      final neededBy =
          _parseDate(
            _firstNonEmpty([
              data['needBy'],
              data['neededBy'],
              data['need_by'],
              requestDetails['needBy'],
              row['created_at'],
              row['updated_at'],
            ]),
          ) ??
          DateTime.now();

      return ClientRequest(
        id: _firstNonEmpty([
          row['id'],
          data['id'],
          data['request_number'],
          data['order_number'],
        ]),
        clientName: brand
            ? _firstNonEmpty([
                data['displayName'],
                data['clientName'],
                data['client_name'],
                widget.profile.basic.name,
              ], fallback: 'Client')
            : _firstNonEmpty([
                data['clientName'],
                data['client_name'],
                widget.profile.basic.name,
              ], fallback: 'Client'),
        title: _firstNonEmpty([
          data['title'],
          data['campaignName'],
          data['requestTitle'],
          data['request_number'],
          data['order_number'],
          'Custom Nail Request',
        ]),
        subtitle: _firstNonEmpty([
          data['descriptionPreview'],
          data['description'],
          requestDetails['description'],
          data['status'],
        ]),
        neededBy: neededBy,
        budgetMin: _asInt(_firstExisting([data['budgetMin'], data['budget_min']])),
        budgetMax: _asInt(_firstExisting([data['budgetMax'], data['budget_max']])),
        leftHand: NailDimensions(
          thumb: _dimText(dimensions['lThumb']),
          index: _dimText(dimensions['lIndex']),
          middle: _dimText(dimensions['lMiddle']),
          ring: _dimText(dimensions['lRing']),
          pinky: _dimText(dimensions['lPinky']),
        ),
        rightHand: NailDimensions(
          thumb: _dimText(dimensions['rThumb']),
          index: _dimText(dimensions['rIndex']),
          middle: _dimText(dimensions['rMiddle']),
          ring: _dimText(dimensions['rRing']),
          pinky: _dimText(dimensions['rPinky']),
        ),
        nailShape: _firstNonEmpty([
          nailPrefs['shape'],
          data['nailShape'],
          data['nail_shape'],
        ]),
        nailLength: _firstNonEmpty([
          nailPrefs['length'],
          data['nailLength'],
          data['nail_length'],
        ]),
        bio: _firstNonEmpty([
          data['bio'],
          data['description'],
          requestDetails['description'],
        ]),
        images: _photoList(
          _firstExisting([
            data['inspirationPhotos'],
            data['inspiration_photos'],
            data['photos'],
          ]),
        ),
        status: _statusFrom(
          _firstExisting([
            data['artistStatus'],
            data['artist_status'],
            data['status'],
          ]),
        ),
        isDirectRequest: _asBool(
          _firstExisting([
            data['isDirectRequest'],
            data['is_direct_request'],
          ]),
        ),
        estimatedShipDays: _asInt(data['estimatedShipDays']) == 0
            ? 3
            : _asInt(data['estimatedShipDays']),
      );
    } catch (error) {
      debugPrint('CLIENT-ARTIST CALENDAR MAP FAILED: $error');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _safeQuery(String table) async {
    try {
      final rows = await _supabase
          .from(table)
          .select()
          .order('created_at', ascending: false)
          .limit(250);
      return rows
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
    } catch (error) {
      debugPrint('CLIENT-ARTIST CALENDAR QUERY FAILED ($table): $error');
      return const <Map<String, dynamic>>[];
    }
  }

  Future<void> _loadCalendarRequests() async {
    final clientRows = await _safeQuery('client_custom_requests');
    final brandRows = await _safeQuery('company_custom_requests');

    final mapped = <ClientRequest>[
      ...clientRows
          .where(_matchesCurrentClient)
          .map((row) => _mapRequest(row, brand: false))
          .whereType<ClientRequest>(),
      ...brandRows
          .where(_matchesCurrentClient)
          .map((row) => _mapRequest(row, brand: true))
          .whereType<ClientRequest>(),
    ];

    mapped.sort((a, b) => a.neededBy.compareTo(b.neededBy));

    if (!mounted) return;
    setState(() {
      _requests = mapped;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.snow,
      body: ArtistCalendarPage(
        requests: _requests,
        enableSupabaseAutoload: false,
        showExtendedAvatarMenu: true,
        hideCalendarMenuItem: true,
        onOpenProfile: () {
          _openProfile(context);
        },
        onOpenHistory: () {
          _openHistory(context);
        },
        onOpenCalendar: () {},
        onOpenArtist: () {
          _openArtist(context);
        },
        onOpenReviews: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ClientArtistReviewsPage(
                profile: widget.profile,
                showContinueProfileCard: widget.showContinueProfileCard,
                enableAllTabs: widget.enableAllTabs,
                showCampaignsTab: _showCampaignsTab,
                onOpenProfile: widget.onOpenProfile,
                onLogout: () async {
                  _logout(context);
                },
              ),
            ),
          );
        },
        onOpenEarnings: _showCampaignsTab
            ? () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ClientArtistEarningsPage(
                      profile: widget.profile,
                      showContinueProfileCard: widget.showContinueProfileCard,
                      enableAllTabs: widget.enableAllTabs,
                      showCampaignsTab: _showCampaignsTab,
                      onOpenProfile: widget.onOpenProfile,
                      onLogout: () async {
                        _logout(context);
                      },
                    ),
                  ),
                );
              }
            : null,
        onSignOut: () {
          _logout(context);
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (i) => _openHomeTab(context, i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.blackCat,
        unselectedItemColor: Colors.black.withValues(alpha: 0.55),
        backgroundColor: AppColors.balletSlippers,
        items: <BottomNavigationBarItem>[
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            activeIcon: Icon(Icons.add_circle),
            label: 'Design',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.inbox_outlined),
            activeIcon: Icon(Icons.inbox),
            label: 'Requests',
          ),
          if (_showCampaignsTab)
            const BottomNavigationBarItem(
              icon: Icon(Icons.campaign_outlined),
              activeIcon: Icon(Icons.campaign),
              label: 'Campaigns',
            ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          if (!_showCampaignsTab)
            const BottomNavigationBarItem(
              icon: Icon(Icons.attach_money_outlined),
              activeIcon: Icon(Icons.attach_money),
              label: 'Earnings',
            ),
        ],
      ),
    );
  }
}
