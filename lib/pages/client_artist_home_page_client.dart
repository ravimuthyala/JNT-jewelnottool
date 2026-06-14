import 'dart:async';

import 'package:flutter/material.dart';

import '../models/client_profile_models.dart';
import '../theme/app_colors.dart';
import 'client_artists_page.dart';
import 'client_artist_custom_request_with_artist_page.dart';
import 'client_custom_request_page.dart';
import 'client_home_page.dart';
import 'client_artist_order_page.dart';
import 'client_profile_page.dart';
import 'track_order_page.dart';

class ClientArtistHomePageClient extends StatefulWidget {
  const ClientArtistHomePageClient({
    super.key,
    required this.profile,
    required this.showContinueProfileCard,
  });

  final ClientProfileDraft profile;
  final bool showContinueProfileCard;

  @override
  State<ClientArtistHomePageClient> createState() =>
      _ClientArtistHomePageClientState();
}

class _ClientArtistHomePageClientState
    extends State<ClientArtistHomePageClient> {
  int _index = 0;
  late ClientProfileDraft _profile;
  String? _initialArtistName;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
  }

  void _onNavTap(int i) {
    setState(() => _index = i);
  }

  Future<void> _logoutToHomePage() async {
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  Future<void> _openRequestWithArtist(String artistName) async {
    final name = artistName.trim();
    if (name.isEmpty) return;
    _initialArtistName = name;
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
    setState(() => _index = navIndex);
  }

  Future<void> _openTrackOrderPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TrackOrderPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _profile.basic.name.trim().isEmpty
        ? 'Client'
        : _profile.basic.name.trim();

    final pages = <Widget>[
      ClientHomePage(
        clientName: displayName,
        profileImageUrl: _profile.basic.profileImageUrl,
        profileComplete: true,
        showExtendedAvatarMenu: true,
        onLogout: _logoutToHomePage,
        onRequestArtist: (artistName) {
          unawaited(_openRequestWithArtist(artistName));
        },
      ),
      ClientCustomRequestPage(
        profile: _profile,
        showExtendedAvatarMenu: true,
        initialArtistName: _initialArtistName,
      ),
      ClientArtistsPage(
        profile: _profile,
        onRequestArtist: (artistName) {
          unawaited(_openRequestWithArtist(artistName));
        },
      ),
      ClientArtistOrderPage(
        onBackHome: () => _onNavTap(0),
        profile: _profile,
        showExtendedAvatarMenu: true,
      ),
      ClientProfilePage(
        profile: _profile,
        onBackHome: () => _onNavTap(0),
        onOpenTrackOrder: () {
          unawaited(_openTrackOrderPage());
        },
        onProfileUpdated: (updated) {
          setState(() => _profile = updated);
        },
        onLogout: _logoutToHomePage,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: _ClientBottomNav(
        currentIndex: _index,
        onTap: _onNavTap,
      ),
    );
  }
}

class _ClientBottomNav extends StatelessWidget {
  const _ClientBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.deepPlum,
      unselectedItemColor: Colors.black.withOpacity(0.55),
      items: [
        _item(Icons.home_outlined, Icons.home, 'Home', true),
        _item(
          Icons.add_circle_outline,
          Icons.add_circle,
          'Design',
          true,
        ),
        _item(Icons.brush_outlined, Icons.brush, 'Artists', true),
        _item(
          Icons.receipt_long_outlined,
          Icons.receipt_long,
          'Orders',
          true,
        ),
        _item(Icons.person_outline, Icons.person, 'Profile', true),
      ],
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
