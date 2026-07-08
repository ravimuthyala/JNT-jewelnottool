import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/client_profile_models.dart';
import '../theme/app_colors.dart';
import 'client_artist_requests_page.dart';
import 'client_artist_artist_page.dart';
import 'client_artist_campaigns_page.dart';
import 'client_artist_calendar_page.dart';
import 'client_artist_earnings_page.dart';
import 'client_artist_history_page.dart';
import 'client_artist_profile_page.dart';
import 'client_artist_custom_request_with_artist_page.dart';
import 'client_custom_request_page.dart';
import 'client_home_page.dart';
import 'client_artist_order_page.dart';

class ClientArtistHomePage extends StatefulWidget {
  const ClientArtistHomePage({
    super.key,
    required this.showContinueProfileCard,
    required this.enableAllTabs,
    this.initialTabIndex = 0,
    this.profile,
    this.onOpenProfile,
    this.onLogout,
  });

  final bool showContinueProfileCard;
  final bool enableAllTabs;
  final int initialTabIndex;
  final ClientProfileDraft? profile;
  final VoidCallback? onOpenProfile;
  final Future<void> Function()? onLogout;

  @override
  State<ClientArtistHomePage> createState() => _ClientArtistHomePageState();
}

class _ClientArtistHomePageState extends State<ClientArtistHomePage> {
  int _clientIndex = 0;
  String? _initialArtistName;
  bool _showCampaignsTab = false;

  late ClientProfileDraft _profile;

  ClientProfileDraft _fallbackProfile() {
    return ClientProfileDraft(
      basic: const BasicInfo(name: '', email: '', phone: ''),
      address: const AddressInfo(
        street: '',
        city: '',
        state: '',
        zip: '',
        country: 'United States',
      ),
      payment: const PaymentInfo(
        method: PaymentMethod.applePay,
        saveForFuture: false,
      ),
      nail: NailPreferences.empty(),
    );
  }

  @override
  void initState() {
    super.initState();
    _profile = widget.profile ?? _fallbackProfile();
    _clientIndex = widget.initialTabIndex.clamp(0, 5);
    unawaited(_loadAmbassadorStatus());
    unawaited(_loadProfileFromSupabase());
  }

  bool _isAmbassadorFromData(Map<String, dynamic> data) {
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

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
  }

  String _firstNonEmpty(List<Object?> values) {
    for (final raw in values) {
      final value = (raw ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  NailLength _parseNailLength(Object? raw) {
    final value = (raw ?? '').toString().trim();
    switch (value) {
      case 'short':
        return NailLength.short;
      case 'medium':
        return NailLength.medium;
      case 'long':
        return NailLength.long;
      case 'extraLong':
        return NailLength.extraLong;
      case 'xlLong':
        return NailLength.xlLong;
      default:
        return NailLength.none;
    }
  }

  NailDimensions _parseNailDimensions(Map<String, dynamic> map) {
    double? read(String key) {
      final raw = map[key];
      if (raw is num) return raw.toDouble();
      if (raw is String) return double.tryParse(raw.trim());
      return null;
    }

    bool readBool(String key) {
      final raw = map[key];
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      final value = (raw ?? '').toString().trim().toLowerCase();
      return value == 'true' || value == 'yes' || value == '1';
    }

    return NailDimensions(
      lThumb: read('lThumb'),
      lIndex: read('lIndex'),
      lMiddle: read('lMiddle'),
      lRing: read('lRing'),
      lPinky: read('lPinky'),
      rThumb: read('rThumb'),
      rIndex: read('rIndex'),
      rMiddle: read('rMiddle'),
      rRing: read('rRing'),
      rPinky: read('rPinky'),
      lThumbNfc: readBool('lThumbNfc'),
      lIndexNfc: readBool('lIndexNfc'),
      lMiddleNfc: readBool('lMiddleNfc'),
      lRingNfc: readBool('lRingNfc'),
      lPinkyNfc: readBool('lPinkyNfc'),
      rThumbNfc: readBool('rThumbNfc'),
      rIndexNfc: readBool('rIndexNfc'),
      rMiddleNfc: readBool('rMiddleNfc'),
      rRingNfc: readBool('rRingNfc'),
      rPinkyNfc: readBool('rPinkyNfc'),
    );
  }

  Future<Map<String, dynamic>?> _readProfileRowFromSupabase() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    final uid = (user?.id ?? '').trim();
    final email = (user?.email ?? '').trim().toLowerCase();

    if (uid.isEmpty && email.isEmpty) return null;

    for (final table in const <String>['client_artist', 'client']) {
      try {
        if (uid.isNotEmpty) {
          final rows = await supabase.from(table).select().eq('id', uid).limit(1);
          if (rows.isNotEmpty) {
            return Map<String, dynamic>.from(rows.first as Map);
          }
        }

        if (email.isNotEmpty) {
          final rows = await supabase.from(table).select().eq('email', email).limit(1);
          if (rows.isNotEmpty) {
            return Map<String, dynamic>.from(rows.first as Map);
          }
        }
      } catch (_) {}
    }

    return null;
  }

  ClientProfileDraft _profileFromSupabaseRow(Map<String, dynamic> data) {
    final profile = _asMap(data['profile']);
    final basic = _asMap(data['basic']);
    final client = _asMap(data['client']);
    final clientProfile = _asMap(client['profile']);
    final address = _asMap(data['address']);
    final clientAddress = _asMap(client['address']);
    final nail = _asMap(data['nailPreferences']).isNotEmpty
        ? _asMap(data['nailPreferences'])
        : _asMap(data['nail_preferences']);
    final clientNail = _asMap(client['nailPreferences']).isNotEmpty
        ? _asMap(client['nailPreferences'])
        : _asMap(client['nail_preferences']);
    final nextNail = nail.isNotEmpty
        ? NailPreferences(
            dimensions: _parseNailDimensions(_asMap(nail['dimensions'])),
            shape: _firstNonEmpty([nail['shape']]),
            length: _parseNailLength(nail['length']),
          )
        : clientNail.isNotEmpty
        ? NailPreferences(
            dimensions: _parseNailDimensions(_asMap(clientNail['dimensions'])),
            shape: _firstNonEmpty([clientNail['shape']]),
            length: _parseNailLength(clientNail['length']),
          )
        : _profile.nail;

    final name = _firstNonEmpty([
      basic['name'],
      profile['name'],
      clientProfile['name'],
      data['panel_displayName'],
      data['name'],
      _profile.basic.name,
    ]);

    final email = _firstNonEmpty([
      basic['email'],
      data['email'],
      client['email'],
      _profile.basic.email,
    ]);

    final phone = _firstNonEmpty([
      basic['phone'],
      profile['phone'],
      clientProfile['phone'],
      data['panel_phone'],
      data['phone'],
      _profile.basic.phone,
    ]);

    final profileImageUrl = _firstNonEmpty([
      basic['profileImageUrl'],
      basic['photoUrl'],
      basic['avatarUrl'],
      profile['profileImageUrl'],
      profile['photoUrl'],
      profile['avatarUrl'],
      clientProfile['profileImageUrl'],
      clientProfile['photoUrl'],
      clientProfile['avatarUrl'],
      data['panel_profileImageUrl'],
      data['profileImageUrl'],
      data['photoUrl'],
      data['avatarUrl'],
      _profile.basic.profileImageUrl,
    ]);

    return _profile.copyWith(
      basic: _profile.basic.copyWith(
        name: name,
        email: email,
        phone: phone,
        profileImageUrl: profileImageUrl,
      ),
      address: AddressInfo(
        street: _firstNonEmpty([
          address['street'],
          address['addressLine1'],
          clientAddress['street'],
          clientAddress['addressLine1'],
          data['panel_street'],
          _profile.address.street,
        ]),
        city: _firstNonEmpty([
          address['city'],
          clientAddress['city'],
          data['panel_city'],
          _profile.address.city,
        ]),
        state: _firstNonEmpty([
          address['state'],
          clientAddress['state'],
          data['panel_state'],
          _profile.address.state,
        ]),
        zip: _firstNonEmpty([
          address['zip'],
          clientAddress['zip'],
          data['panel_zip'],
          _profile.address.zip,
        ]),
        country: _firstNonEmpty([
          address['country'],
          clientAddress['country'],
          data['panel_country'],
          _profile.address.country,
        ]),
      ),
      nail: nextNail,
    );
  }

  Future<void> _loadProfileFromSupabase() async {
    final row = await _readProfileRowFromSupabase();
    if (row == null || !mounted) return;
    setState(() {
      _profile = _profileFromSupabaseRow(row);
    });
  }

  Future<void> _loadAmbassadorStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    final uid = (user?.id ?? '').trim();
    final email = (user?.email ?? _profile.basic.email).trim().toLowerCase();
    if (uid.isEmpty && email.isEmpty) return;

    for (final table in const <String>['client_artist', 'client']) {
      try {
        List<dynamic> rows = const <dynamic>[];
        if (uid.isNotEmpty) {
          rows = await Supabase.instance.client
              .from(table)
              .select()
              .eq('id', uid)
              .limit(5);
        }
        if (rows.isEmpty && email.isNotEmpty) {
          rows = await Supabase.instance.client
              .from(table)
              .select()
              .eq('email', email)
              .limit(10);
        }
        for (final row in rows) {
          if (_isAmbassadorFromData(_asMap(row))) {
            if (!mounted) return;
            setState(() => _showCampaignsTab = true);
            return;
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _openUnifiedProfile() async {
    if (widget.onOpenProfile != null) {
      widget.onOpenProfile!.call();
      return;
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClientArtistProfilePage(initialProfile: _profile),
      ),
    );
  }

  Future<void> _logout() async {
    if (widget.onLogout != null) {
      await widget.onLogout!.call();
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  Future<void> _openClientArtistRequestWithArtist(String artistName) async {
    final name = artistName.trim();
    if (name.isEmpty) return;
    _initialArtistName = name;
    if (!mounted) return;
    final navIndex = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => ClientArtistCustomRequestWithArtistPage(
          profile: _profile,
          artistName: name,
          artistNames: _initialArtistName == null
              ? const <String>[]
              : <String>[_initialArtistName!],
          onClientNavTap: (ctx, index) async {
            if (index == 1) return;
            if (Navigator.of(ctx).canPop()) {
              Navigator.of(ctx).pop(index);
            }
          },
        ),
      ),
    );
    if (navIndex == null || !mounted) return;
    setState(() => _clientIndex = navIndex);
  }

  void _openClientArtistArtistSection() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientArtistArtistPage(
          profile: _profile,
          showContinueProfileCard: false,
          enableAllTabs: widget.enableAllTabs,
          showCampaignsTab: _showCampaignsTab,
          onOpenProfile: _openUnifiedProfile,
          onOpenHistory: () {
            unawaited(_openClientArtistHistory());
          },
          onOpenCalendar: () {
            unawaited(_openClientArtistCalendar());
          },
          onLogout: _logout,
        ),
      ),
    );
  }

  Future<void> _openClientArtistHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientArtistHistoryPage(
          profile: _profile,
          showContinueProfileCard: false,
          enableAllTabs: widget.enableAllTabs,
          onOpenProfile: _openUnifiedProfile,
          onLogout: _logout,
        ),
      ),
    );
  }

  Future<void> _openClientArtistCalendar() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientArtistCalendarPage(
          profile: _profile,
          showContinueProfileCard: false,
          enableAllTabs: widget.enableAllTabs,
          onOpenProfile: _openUnifiedProfile,
          onLogout: _logout,
        ),
      ),
    );
  }

  Future<void> _openClientArtistEarnings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientArtistEarningsPage(
          profile: _profile,
          showContinueProfileCard: false,
          enableAllTabs: widget.enableAllTabs,
          showCampaignsTab: _showCampaignsTab,
          onOpenProfile: _openUnifiedProfile,
          onLogout: _logout,
        ),
      ),
    );
  }

  Future<void> _openClientArtistReviews() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientArtistReviewsPage(
          profile: _profile,
          showContinueProfileCard: false,
          enableAllTabs: widget.enableAllTabs,
          showCampaignsTab: _showCampaignsTab,
          onOpenProfile: _openUnifiedProfile,
          onLogout: _logout,
        ),
      ),
    );
  }

  Widget _buildClientBody() {
    final pages = <Widget>[
      ClientHomePage(
        clientName: _profile.basic.name.trim().isEmpty
            ? 'Client'
            : _profile.basic.name.trim(),
        profileImageUrl: _profile.basic.profileImageUrl,
        profileComplete: true,
        tapArtistTileOpensImageOnly: true,
        onOpenProfile: _openUnifiedProfile,
        onOpenHistory: () {
          unawaited(_openClientArtistHistory());
        },
        onOpenCalendar: () {
          unawaited(_openClientArtistCalendar());
        },
        onOpenArtist: _openClientArtistArtistSection,
        onOpenReviews: () {
          unawaited(_openClientArtistReviews());
        },
        onOpenEarnings: _showCampaignsTab
            ? () {
                unawaited(_openClientArtistEarnings());
              }
            : null,
        onLogout: _logout,
        showExtendedAvatarMenu: true,
        onRequestArtist: (artistName) {
          unawaited(_openClientArtistRequestWithArtist(artistName));
        },
      ),
      ClientCustomRequestPage(
        profile: _profile,
        showExtendedAvatarMenu: true,
        showProfileMenu: true,
        initialArtistName: _initialArtistName,
        onNavTap: (i) {
          if (!mounted) return;
          setState(() => _clientIndex = i);
        },
        onOpenProfile: _openUnifiedProfile,
        onOpenHistory: () {
          unawaited(_openClientArtistHistory());
        },
        onOpenCalendar: () {
          unawaited(_openClientArtistCalendar());
        },
        onOpenArtist: _openClientArtistArtistSection,
        onOpenReviews: () {
          unawaited(_openClientArtistReviews());
        },
        onLogout: _logout,
      ),
      ClientArtistRequestsPage(
        onOpenProfile: _openUnifiedProfile,
        onOpenHistory: () {
          unawaited(_openClientArtistHistory());
        },
        onOpenCalendar: () {
          unawaited(_openClientArtistCalendar());
        },
        onOpenArtist: _openClientArtistArtistSection,
        onOpenReviews: () {
          unawaited(_openClientArtistReviews());
        },
        onOpenEarnings: _showCampaignsTab
            ? () {
                unawaited(_openClientArtistEarnings());
              }
            : null,
        onLogout: _logout,
      ),
      if (_showCampaignsTab)
        ClientArtistCampaignsPage(
          onOpenProfile: _openUnifiedProfile,
          onOpenEarnings: () {
            unawaited(_openClientArtistEarnings());
          },
          onLogout: () {
            unawaited(_logout());
          },
        ),
      ClientArtistOrderPage(
        profile: _profile,
        showExtendedAvatarMenu: true,
        showProfileMenu: true,
        onBackHome: () => setState(() => _clientIndex = 0),
        onOpenProfile: _openUnifiedProfile,
        onOpenEarnings: _showCampaignsTab
            ? () {
                unawaited(_openClientArtistEarnings());
              }
            : null,
        onOpenHistory: () {
          unawaited(_openClientArtistHistory());
        },
        onOpenCalendar: () {
          unawaited(_openClientArtistCalendar());
        },
        onOpenArtist: _openClientArtistArtistSection,
        onOpenReviews: () {
          unawaited(_openClientArtistReviews());
        },
        onLogout: _logout,
      ),
      if (!_showCampaignsTab)
        ClientArtistEarningsPage(
          profile: _profile,
          showContinueProfileCard: false,
          enableAllTabs: widget.enableAllTabs,
          showCampaignsTab: _showCampaignsTab,
          showBottomNav: false,
          onOpenProfile: _openUnifiedProfile,
          onLogout: _logout,
        ),
    ];

    final safeIndex = _clientIndex.clamp(0, pages.length - 1);
    return IndexedStack(index: safeIndex, children: pages);
  }

  Widget _buildBottomNav() {
    final safeIndex = _clientIndex.clamp(0, 4);
    return BottomNavigationBar(
      backgroundColor: AppColors.balletSlippers,
      currentIndex: safeIndex,
      onTap: (i) => setState(() => _clientIndex = i),
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.deepPlum,
      unselectedItemColor: Colors.black.withValues(alpha: 0.55),
      items: [
        _clientItem(
          Icons.home_outlined,
          Icons.home,
          'Home',
          true,
        ),
        _clientItem(
          Icons.add_circle_outline,
          Icons.add_circle,
          'Design',
          true,
        ),
        _clientItem(
          Icons.inbox_outlined,
          Icons.inbox,
          'Requests',
          true,
        ),
        if (_showCampaignsTab)
          _clientItem(
            Icons.campaign_outlined,
            Icons.campaign,
            'Campaigns',
            true,
          ),
        _clientItem(
          Icons.receipt_long_outlined,
          Icons.receipt_long,
          'Orders',
          true,
        ),
        if (!_showCampaignsTab)
          _clientItem(
            Icons.attach_money_outlined,
            Icons.attach_money,
            'Earnings',
            true,
          ),
      ],
    );
  }

  BottomNavigationBarItem _clientItem(
    IconData icon,
    IconData activeIcon,
    String label,
    bool enabled,
  ) {
    return BottomNavigationBarItem(
      icon: Opacity(opacity: enabled ? 1 : 0.35, child: Icon(icon)),
      activeIcon: Icon(activeIcon),
      label: label,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.snow,
      body: SafeArea(child: _buildClientBody()),
      bottomNavigationBar: _buildBottomNav(),
    );
  }
}
