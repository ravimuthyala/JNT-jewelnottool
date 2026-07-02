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
