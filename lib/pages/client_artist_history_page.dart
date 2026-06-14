import 'package:flutter/material.dart';

import '../models/client_profile_models.dart';
import 'artist_history_page.dart';
import 'client_artist_artist_page.dart';
import 'client_artist_calendar_page.dart';
import 'client_artist_home_page.dart';
import 'client_artist_profile_page.dart';

class ClientArtistHistoryPage extends StatelessWidget {
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

  Future<void> _openProfile(BuildContext context) async {
    if (onOpenProfile != null) {
      onOpenProfile!.call();
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientArtistProfilePage(initialProfile: profile),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    if (onLogout != null) {
      await onLogout!.call();
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  Future<void> _openCalendar(BuildContext context) async {
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ClientArtistCalendarPage(
          profile: profile,
          showContinueProfileCard: showContinueProfileCard,
          enableAllTabs: enableAllTabs,
          onOpenProfile: onOpenProfile,
          onLogout: onLogout,
        ),
      ),
    );
  }

  Future<void> _openArtist(BuildContext context) async {
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ClientArtistArtistPage(
          profile: profile,
          showContinueProfileCard: showContinueProfileCard,
          enableAllTabs: enableAllTabs,
          onOpenProfile: onOpenProfile,
          onOpenHistory: () {},
          onOpenCalendar: () {
            _openCalendar(context);
          },
          onLogout: onLogout,
        ),
      ),
    );
  }

  void _openHomeTab(BuildContext context, int index) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ClientArtistHomePage(
          showContinueProfileCard: showContinueProfileCard,
          enableAllTabs: enableAllTabs,
          profile: profile,
          initialTabIndex: index,
          onOpenProfile: onOpenProfile,
          onLogout: onLogout,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ArtistHistoryPage(
      showExtendedAvatarMenu: true,
      hideHistoryMenuItem: true,
      onBackHome: () => _openHomeTab(context, 0),
      onManageProfile: () {
        _openProfile(context);
      },
      onOpenHistory: () {},
      onOpenCalendar: () {
        _openCalendar(context);
      },
      onOpenArtist: () {
        _openArtist(context);
      },
      onSignOut: () {
        _logout(context);
      },
    );
  }
}
