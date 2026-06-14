// lib/pages/client_shell_page.dart
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

import '../models/client_profile_models.dart';
import '../theme/app_colors.dart';
import 'client_artists_page.dart';
import 'client_custom_request_page.dart';
import 'client_custom_request_with_artist_page.dart';
import 'client_home_artist_portfolio_page.dart';
import 'client_order_page.dart';
import 'client_profile_page.dart';
import 'client_requests_page.dart';
import 'track_order_page.dart';

class ClientShellPage extends StatefulWidget {
  const ClientShellPage({
    super.key,
    required this.profile,
    this.initialIndex = 0,
    this.forceEnableAllTabs = false,
    this.initialArtistName,
  });

  final ClientProfileDraft profile;
  final int initialIndex;
  final bool forceEnableAllTabs;
  final String? initialArtistName;

  @override
  State<ClientShellPage> createState() => _ClientShellPageState();
}

class _ClientShellPageState extends State<ClientShellPage> {
  late int _index;
  late ClientProfileDraft _profile;
  late bool _profileComplete;
  late String _clientName;
  late bool _forceEnableAllTabs;
  String? _initialArtistName;

  static const bool _restrictRequestsTabToApprovedBrandPartners = true;
  bool _brandPartnerApprovedByAdmin = false;
  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _profileComplete = true;
    _clientName = _profile.basic.name;
    _index = widget.initialIndex;
    _forceEnableAllTabs = widget.forceEnableAllTabs;
    _initialArtistName = widget.initialArtistName;
    unawaited(_loadClientProfileFromSupabase());
    unawaited(_loadBrandPartnerApprovalStatus());
  }

  @override
  void dispose() {
    super.dispose();
  }

  bool _hasBrandPartnerTag(Object? value) {
    if (value is! List) return false;
    return value.any((item) {
      final tag = item.toString().trim().toLowerCase();
      return tag == 'brand partner' ||
          tag == 'ambassador' ||
          tag == '1m followers' ||
          tag == '1m+ followers';
    });
  }

  bool _isBrandPartnerFromData(Map<String, dynamic> data) {
    String firstNonEmpty(Map<String, dynamic> source, List<String> keys) {
      for (final key in keys) {
        final value = (source[key] ?? '').toString().trim();
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    final profile = (data['profile'] as Map<String, dynamic>?) ?? const {};
    final basic = (data['basic'] as Map<String, dynamic>?) ?? const {};
    final company = (data['company'] as Map<String, dynamic>?) ?? const {};
    final client = (data['client'] as Map<String, dynamic>?) ?? const {};
    final ascension = (data['ascension'] as Map<String, dynamic>?) ?? const {};
    final profileAscension =
        (profile['ascension'] as Map<String, dynamic>?) ?? const {};
    final basicAscension =
        (basic['ascension'] as Map<String, dynamic>?) ?? const {};
    final clientAscension =
        (client['ascension'] as Map<String, dynamic>?) ?? const {};

    final partnerText = <String>[
      firstNonEmpty(data, const ['status', 'partnerStatus', 'tier']),
      firstNonEmpty(profile, const ['status', 'partnerStatus', 'tier']),
      firstNonEmpty(basic, const ['status', 'partnerStatus', 'tier']),
      firstNonEmpty(company, const ['status', 'partnerStatus', 'tier']),
      firstNonEmpty(client, const ['status', 'partnerStatus', 'tier']),
      firstNonEmpty(ascension, const ['status']),
      firstNonEmpty(profileAscension, const ['status']),
      firstNonEmpty(basicAscension, const ['status']),
      firstNonEmpty(clientAscension, const ['status']),
    ].join(' ').toLowerCase();

    final hasBrandPartnerLabel =
        partnerText.contains('brand partner') ||
        partnerText.contains('brand_partner') ||
        partnerText.contains('ambassador');

    final hasBrandPartnerTag =
        _hasBrandPartnerTag(data['accountTags']) ||
        _hasBrandPartnerTag(profile['accountTags']) ||
        _hasBrandPartnerTag(basic['accountTags']) ||
        _hasBrandPartnerTag(client['accountTags']);

    final approvalStatus = firstNonEmpty(data, const [
      'brandPartnerStatus',
      'brandPartnerApproval',
    ]).toLowerCase();
    final adminOverrideStatus = firstNonEmpty(data, const [
      'adminOverride',
      'override',
    ]).toLowerCase();
    final hasAdminOverride =
        approvalStatus == 'approved' ||
        adminOverrideStatus == 'true' ||
        adminOverrideStatus == '1' ||
        adminOverrideStatus == 'yes';

    bool followersAtLeast1M(Map<String, dynamic> map) {
      final possibleCounts = <Object?>[
        map['followers'],
        map['followerCount'],
        map['followersCount'],
        map['socialFollowers'],
        map['socialFollowerCount'],
      ];
      for (final value in possibleCounts) {
        if (value is num && value >= 1000000) return true;
        final parsed = num.tryParse(value?.toString() ?? '');
        if (parsed != null && parsed >= 1000000) return true;
      }
      final label = firstNonEmpty(map, const [
        'followersLabel',
        'followerMilestone',
        'followersTier',
      ]).toLowerCase();
      return label.contains('1m');
    }

    final hasFollowers1M =
        followersAtLeast1M(data) ||
        followersAtLeast1M(profile) ||
        followersAtLeast1M(basic) ||
        followersAtLeast1M(client) ||
        followersAtLeast1M(ascension) ||
        followersAtLeast1M(profileAscension) ||
        followersAtLeast1M(basicAscension) ||
        followersAtLeast1M(clientAscension);

    // Admin-approved flow may only update profile with Brand Partner tag.
    if (hasBrandPartnerTag) return true;
    if (hasAdminOverride || hasFollowers1M) {
      return true;
    }
    return hasBrandPartnerLabel;
  }

  Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
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

  bool _asBool(Object? raw, {bool fallback = false}) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    final value = (raw ?? '').toString().trim().toLowerCase();
    if (value == 'true' || value == 'yes' || value == '1') return true;
    if (value == 'false' || value == 'no' || value == '0') return false;
    return fallback;
  }

  Future<Map<String, dynamic>?> _readClientRowFromSupabase() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    final uid = (user?.id ?? '').trim();
    final email = (user?.email ?? '').trim().toLowerCase();

    if (uid.isEmpty && email.isEmpty) return null;

    for (final table in const <String>['client', 'client_artist']) {
      try {
        if (uid.isNotEmpty) {
          final rows = await supabase.from(table).select().eq('id', uid).limit(1);
          if (rows is List && rows.isNotEmpty && rows.first is Map) {
            return Map<String, dynamic>.from(rows.first as Map);
          }
        }

        if (email.isNotEmpty) {
          final rows = await supabase
              .from(table)
              .select()
              .eq('email', email)
              .limit(1);
          if (rows is List && rows.isNotEmpty && rows.first is Map) {
            return Map<String, dynamic>.from(rows.first as Map);
          }
        }
      } catch (e) {
        debugPrint('CLIENT SHELL LOAD FAILED [$table]: $e');
      }
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
    final payment = _asMap(data['payment']);
    final clientPayment = _asMap(client['payment']);
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

    final nextBasic = _profile.basic.copyWith(
      name: name,
      email: email,
      phone: phone,
      profileImageUrl: profileImageUrl,
    );

    final nextAddress = AddressInfo(
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
    );

    return _profile.copyWith(
      basic: nextBasic,
      address: nextAddress,
      nail: nextNail,
    );
  }

  Future<void> _loadClientProfileFromSupabase() async {
    final row = await _readClientRowFromSupabase();
    if (row == null || !mounted) return;

    final updated = _profileFromSupabaseRow(row);
    setState(() {
      _profile = updated;
      _clientName = updated.basic.name;
      _profileComplete = true;
    });
  }

  Future<void> _loadBrandPartnerApprovalStatus() async {
    final row = await _readClientRowFromSupabase();
    if (row == null || !mounted) return;

    setState(() {
      _brandPartnerApprovedByAdmin = _isBrandPartnerFromData(row);
    });
  }

  bool _shouldShowRequestsTab() {
    if (!_restrictRequestsTabToApprovedBrandPartners) {
      return true;
    }
    return _brandPartnerApprovedByAdmin;
  }

  Future<void> _showCompleteClientProfileDialog() {
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(
          'Client Profile',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Please complete the Client Profile to submit design request',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'OK',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.deepPlum,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onNavTap(int i) {
    setState(() => _index = i);
  }

  Future<void> _logoutToHomePage() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  Future<void> _openRequestWithArtist(String artistName) async {
    final name = artistName.trim();
    if (name.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientCustomRequestWithArtistPage(
          profile: _profile,
          artistName: name,
          artistNames: const <String>[],
        ),
      ),
    );
  }

  Future<void> _openTrackOrderPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TrackOrderPage()),
    );
  }

  Future<void> _openProfilePage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientProfilePage(
          profile: _profile,
          onBackHome: () => Navigator.of(context).pop(),
          onOpenDesignRequest: () => _onNavTap(1),
          onOpenTrackOrder: () {
            unawaited(_openTrackOrderPage());
          },
          onProfileUpdated: (updated) {
            setState(() {
              _profile = updated;
              _profileComplete = true;
              _clientName = updated.basic.name;
            });
          },
          onLogout: _logoutToHomePage,
        ),
      ),
    );
  }

  void _openProfileFromAvatar() {
    unawaited(_openProfilePage());
  }

  String _routeLabelForIndex(
    int index, {
    required bool showRequestsTab,
    required bool showProfileBottomTab,
  }) {
    if (index == 0) return 'Client home';
    if (index == 1) return 'Design request';
    if (showRequestsTab) {
      if (index == 2) return 'Client requests';
      if (index == 3) return 'Artists';
      if (index == 4) return 'Orders';
    } else {
      if (index == 2) return 'Artists';
      if (index == 3) return 'Orders';
      if (showProfileBottomTab && index == 4) return 'Client profile';
    }
    return 'Client home';
  }

  @override
  Widget build(BuildContext context) {
    final showRequestsTab = _shouldShowRequestsTab();
    final showProfileInAvatar = showRequestsTab;
    final showProfileBottomTab = !showRequestsTab;

    final pages = <Widget>[
      ClientHomeArtistPortfolioPage(
        clientName: _clientName,
        profileImageUrl: _profile.basic.profileImageUrl,
        profileComplete: _profileComplete,
        onOpenProfile: _openProfileFromAvatar,
        showProfileMenuInAvatar: showProfileInAvatar,
        onLogout: _logoutToHomePage,
        onRequestArtist: (artistName) {
          if (!_profileComplete) {
            unawaited(_showCompleteClientProfileDialog());
            return;
          }
          _forceEnableAllTabs = true;
          _initialArtistName = artistName;
          unawaited(_openRequestWithArtist(artistName));
        },
      ),
      ClientCustomRequestPage(
        profile: _profile,
        initialArtistName: _initialArtistName,
        isActiveTab: _index == 1,
        onNavTap: _onNavTap,
        onOpenProfile: _openProfileFromAvatar,
        onLogout: _logoutToHomePage,
        showProfileMenu: showProfileInAvatar,
      ),
      if (showRequestsTab)
        ClientRequestsPage(
          onOpenProfile: _openProfileFromAvatar,
          showProfileMenuItem: showProfileInAvatar,
          onLogout: () {
            unawaited(_logoutToHomePage());
          },
        ),
      ClientArtistsPage(
        profile: _profile,
        onOpenProfile: _openProfileFromAvatar,
        onLogout: _logoutToHomePage,
        showProfileMenu: showProfileInAvatar,
        onRequestArtist: (artistName) {
          if (!_profileComplete) {
            unawaited(_showCompleteClientProfileDialog());
            return;
          }
          setState(() {
            _forceEnableAllTabs = true;
            _initialArtistName = artistName;
            _index = 1;
          });
          unawaited(_openRequestWithArtist(artistName));
        },
      ),
      ClientOrderPage(
        onBackHome: () => _onNavTap(0),
        profile: _profile,
        isActiveTab: _index == (showRequestsTab ? 4 : 3),
        onOpenProfile: _openProfileFromAvatar,
        onLogout: _logoutToHomePage,
        showProfileMenu: showProfileInAvatar,
      ),
      if (showProfileBottomTab)
        ClientProfilePage(
          profile: _profile,
          isActiveTab: _index == (showRequestsTab ? 5 : 4),
          onBackHome: () => _onNavTap(0),
          onOpenDesignRequest: () => _onNavTap(1),
          onOpenTrackOrder: () {
            unawaited(_openTrackOrderPage());
          },
          onProfileUpdated: (updated) {
            setState(() {
              _profile = updated;
              _profileComplete = true;
              _clientName = updated.basic.name;
            });
          },
          onLogout: _logoutToHomePage,
        ),
    ];

    final safeIndex = _index.clamp(0, pages.length - 1);

    final routeLabel = _routeLabelForIndex(
      safeIndex,
      showRequestsTab: showRequestsTab,
      showProfileBottomTab: showProfileBottomTab,
    );

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      label: routeLabel,
      explicitChildNodes: true,
      child: Scaffold(
        backgroundColor: AppColors.snow,
        body: IndexedStack(index: safeIndex, children: pages),
        bottomNavigationBar: _ClientBottomNav(
          currentIndex: safeIndex,
          profileComplete: _profileComplete,
          forceEnableAllTabs: _forceEnableAllTabs,
          showRequestsTab: showRequestsTab,
          showProfileTab: showProfileBottomTab,
          onTap: _onNavTap,
        ),
      ),
    );
  }
}

class _ClientBottomNav extends StatelessWidget {
  const _ClientBottomNav({
    required this.currentIndex,
    required this.profileComplete,
    required this.onTap,
    required this.forceEnableAllTabs,
    required this.showRequestsTab,
    required this.showProfileTab,
  });

  final int currentIndex;
  final bool profileComplete;
  final bool forceEnableAllTabs;
  final bool showRequestsTab;
  final bool showProfileTab;
  final ValueChanged<int> onTap;

  bool _enabled(int i) {
    if (forceEnableAllTabs) return true;
    return i == 0 ? true : profileComplete;
  }

  String _routeLabelForIndex(
    int index, {
    required bool showRequestsTab,
    required bool showProfileBottomTab,
  }) {
    if (index == 0) return 'Client home';
    if (index == 1) return 'Design request';
    if (showRequestsTab) {
      if (index == 2) return 'Client requests';
      if (index == 3) return 'Artists';
      if (index == 4) return 'Orders';
    } else {
      if (index == 2) return 'Artists';
      if (index == 3) return 'Orders';
      if (showProfileBottomTab && index == 4) return 'Client profile';
    }
    return 'Client home';
  }

  @override
  Widget build(BuildContext context) {
    final items = <BottomNavigationBarItem>[
      _item(Icons.home_outlined, Icons.home, 'Home', _enabled(0)),
      _item(Icons.add_circle_outline, Icons.add_circle, 'Design', _enabled(1)),
      if (showRequestsTab)
        _item(Icons.inbox_outlined, Icons.inbox, 'Requests', _enabled(2)),
      _item(
        Icons.brush_outlined,
        Icons.brush,
        'Artists',
        _enabled(showRequestsTab ? 3 : 2),
      ),
      _item(
        Icons.receipt_long_outlined,
        Icons.receipt_long,
        'Orders',
        _enabled(showRequestsTab ? 4 : 3),
      ),
      if (showProfileTab)
        _item(Icons.person_outline, Icons.person, 'Profile', _enabled(4)),
    ];

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppColors.balletSlippers,
      selectedItemColor: AppColors.deepPlum,
      unselectedItemColor: Colors.black.withValues(alpha: 0.55),
      items: items,
    );
  }

  BottomNavigationBarItem _item(
    IconData icon,
    IconData selectedIcon,
    String label,
    bool enabled,
  ) {
    return BottomNavigationBarItem(
      icon: Opacity(opacity: enabled ? 1 : 0.35, child: Icon(icon)),
      activeIcon: Icon(selectedIcon),
      label: label,
    );
  }
}
