import 'dart:async';

import 'package:flutter/material.dart';

import '../models/client_profile_models.dart';
import '../services/ambassador_role_service.dart';
import 'artist_history_page.dart';
import 'client_artist_artist_page.dart';
import 'client_artist_calendar_page.dart';
import 'client_artist_earnings_page.dart';
import 'client_artist_home_page.dart';
import 'client_artist_profile_page.dart';

class ClientArtistHistoryPage extends StatefulWidget {
  const ClientArtistHistoryPage({
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
  State<ClientArtistHistoryPage> createState() => _ClientArtistHistoryPageState();
}

class _ClientArtistHistoryPageState extends State<ClientArtistHistoryPage> {
  bool _showCampaignsTab = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCampaignVisibility());
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
        builder: (_) => ClientArtistProfilePage(initialProfile: widget.profile),
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

  Future<void> _openCalendar(BuildContext context) async {
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ClientArtistCalendarPage(
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
          onOpenHistory: () {},
          onOpenCalendar: () {
            _openCalendar(context);
          },
          onLogout: widget.onLogout,
        ),
      ),
    );
  }

  Future<void> _openReviews(BuildContext context) async {
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ClientArtistReviewsPage(
          profile: widget.profile,
          showContinueProfileCard: widget.showContinueProfileCard,
          enableAllTabs: widget.enableAllTabs,
          showCampaignsTab: _showCampaignsTab,
          onOpenProfile: () => _openProfile(context),
          onLogout: () async {
            await _logout(context);
          },
        ),
      ),
    );
  }

  void _onClientArtistNavTap(BuildContext context, int index) {
    _openHomeTab(context, index);
  }

  Widget _buildBottomNav(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: const Color(0xFFF2DCCB),
      currentIndex: 0,
      onTap: (index) => _onClientArtistNavTap(context, index),
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF2F2725),
      unselectedItemColor: Colors.black.withValues(alpha: 0.55),
      items: [
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return ArtistHistoryPage(
      onManageProfile: () {
        unawaited(_openProfile(context));
      },
      onOpenHistory: () {},
      onOpenCalendar: () {
        unawaited(_openCalendar(context));
      },
      onOpenArtist: () {
        unawaited(_openArtist(context));
      },
      onOpenReviews: () {
        unawaited(_openReviews(context));
      },
      onSignOut: () {
        unawaited(_logout(context));
      },
      showExtendedAvatarMenu: true,
      hideHistoryMenuItem: true,
      bottomNavigationBar: _buildBottomNav(context),
    );
  }
}
