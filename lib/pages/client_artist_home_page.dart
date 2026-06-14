import 'dart:async';

import 'package:flutter/material.dart';

import '../models/client_profile_models.dart';
import '../theme/app_colors.dart';
import 'artist_earnings_page.dart';
import 'artist_requests_page_redesign.dart';
import 'client_artist_artist_page.dart';
import 'client_artist_calendar_page.dart';
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
    _clientIndex = widget.initialTabIndex.clamp(0, 4);
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

  Widget _buildClientBody() {
    final pages = <Widget>[
      ClientHomePage(
        clientName: _profile.basic.name.trim().isEmpty
            ? 'Client'
            : _profile.basic.name.trim(),
        profileImageUrl: _profile.basic.profileImageUrl,
        profileComplete: true,
        onOpenProfile: _openUnifiedProfile,
        onOpenHistory: () {
          unawaited(_openClientArtistHistory());
        },
        onOpenCalendar: () {
          unawaited(_openClientArtistCalendar());
        },
        onOpenArtist: _openClientArtistArtistSection,
        onLogout: _logout,
        showExtendedAvatarMenu: true,
        onRequestArtist: (artistName) {
          unawaited(_openClientArtistRequestWithArtist(artistName));
        },
      ),
      ClientCustomRequestPage(
        profile: _profile,
        showExtendedAvatarMenu: true,
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
        onLogout: _logout,
      ),
      ArtistRequestsPageRedesign(
        clientArtistMenuStyle: true,
        onManageProfile: () {
          unawaited(_openUnifiedProfile());
        },
        onOpenHistory: () {
          unawaited(_openClientArtistHistory());
        },
        onOpenCalendar: () {
          unawaited(_openClientArtistCalendar());
        },
        onOpenArtist: _openClientArtistArtistSection,
        onSignOut: () {
          unawaited(_logout());
        },
      ),
      ClientArtistOrderPage(
        profile: _profile,
        showExtendedAvatarMenu: true,
        onBackHome: () => setState(() => _clientIndex = 0),
        onOpenProfile: _openUnifiedProfile,
        onOpenHistory: () {
          unawaited(_openClientArtistHistory());
        },
        onOpenCalendar: () {
          unawaited(_openClientArtistCalendar());
        },
        onOpenArtist: _openClientArtistArtistSection,
        onLogout: _logout,
      ),
      ArtistEarningsPage(
        clientArtistMenuStyle: true,
        onManageProfile: () {
          unawaited(_openUnifiedProfile());
        },
        onOpenHistory: () {
          unawaited(_openClientArtistHistory());
        },
        onOpenCalendar: () {
          unawaited(_openClientArtistCalendar());
        },
        onOpenArtist: _openClientArtistArtistSection,
        onSignOut: () {
          unawaited(_logout());
        },
      ),
    ];

    return IndexedStack(index: _clientIndex, children: pages);
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      backgroundColor: AppColors.balletSlippers,
      currentIndex: _clientIndex,
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
        _clientItem(
          Icons.receipt_long_outlined,
          Icons.receipt_long,
          'Orders',
          true,
        ),
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
