import 'package:flutter/material.dart';

import '../models/client_profile_models.dart';
import '../theme/app_colors.dart';
import 'artist_calendar_page.dart';
import 'client_artist_artist_page.dart';
import 'client_artist_history_page.dart';
import 'client_artist_home_page.dart';
import 'client_artist_profile_page.dart';
import '../models/artist_request_legacy_models.dart' show ClientRequest;

class ClientArtistCalendarPage extends StatelessWidget {
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

  Future<void> _openHistory(BuildContext context) async {
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ClientArtistHistoryPage(
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
          onOpenHistory: () {
            _openHistory(context);
          },
          onOpenCalendar: () {},
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
    return Scaffold(
      backgroundColor: AppColors.snow,
      body: ArtistCalendarPage(
        requests: const <ClientRequest>[],
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
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            activeIcon: Icon(Icons.add_circle),
            label: 'Design',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inbox_outlined),
            activeIcon: Icon(Icons.inbox),
            label: 'Requests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money_outlined),
            activeIcon: Icon(Icons.attach_money),
            label: 'Earnings',
          ),
        ],
      ),
    );
  }
}
