import 'package:flutter/material.dart';

import '../models/client_profile_models.dart';
import 'artist_earnings_page.dart';
import 'artist_reviews_page.dart';
import 'client_artist_artist_page.dart';
import 'client_artist_calendar_page.dart';
import 'client_artist_history_page.dart';
import 'client_artist_home_page.dart';

class ClientArtistEarningsPage extends StatelessWidget {
  const ClientArtistEarningsPage({
    super.key,
    required this.profile,
    required this.showContinueProfileCard,
    required this.enableAllTabs,
    required this.showCampaignsTab,
    this.showBottomNav = true,
    this.onOpenProfile,
    this.onLogout,
  });

  final ClientProfileDraft profile;
  final bool showContinueProfileCard;
  final bool enableAllTabs;
  final bool showCampaignsTab;
  final bool showBottomNav;
  final VoidCallback? onOpenProfile;
  final Future<void> Function()? onLogout;

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
          showCampaignsTab: showCampaignsTab,
          onOpenProfile: onOpenProfile,
          onOpenHistory: () {
            _openHistory(context);
          },
          onOpenCalendar: () {
            _openCalendar(context);
          },
          onLogout: onLogout,
        ),
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

  @override
  Widget build(BuildContext context) {
    return ArtistEarningsPage(
      clientArtistMenuStyle: true,
      showBottomNav: showBottomNav,
      showCampaignsTab: showCampaignsTab,
      bottomNavCurrentIndex: showCampaignsTab ? 0 : 4,
      onBottomNavTap: (index) => _openHomeTab(context, index),
      onManageProfile: onOpenProfile,
      onOpenHistory: () {
        _openHistory(context);
      },
      onOpenCalendar: () {
        _openCalendar(context);
      },
      onOpenArtist: () {
        _openArtist(context);
      },
      onOpenReviews: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ClientArtistReviewsPage(
              profile: profile,
              showContinueProfileCard: showContinueProfileCard,
              enableAllTabs: enableAllTabs,
              showCampaignsTab: showCampaignsTab,
              onOpenProfile: onOpenProfile,
              onLogout: onLogout,
            ),
          ),
        );
      },
      onSignOut: () {
        _logout(context);
      },
    );
  }
}

class ClientArtistReviewsPage extends StatelessWidget {
  const ClientArtistReviewsPage({
    super.key,
    required this.profile,
    required this.showContinueProfileCard,
    required this.enableAllTabs,
    required this.showCampaignsTab,
    this.onOpenProfile,
    this.onLogout,
  });

  final ClientProfileDraft profile;
  final bool showContinueProfileCard;
  final bool enableAllTabs;
  final bool showCampaignsTab;
  final VoidCallback? onOpenProfile;
  final Future<void> Function()? onLogout;

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
          showCampaignsTab: showCampaignsTab,
          onOpenProfile: onOpenProfile,
          onOpenHistory: () {
            _openHistory(context);
          },
          onOpenCalendar: () {
            _openCalendar(context);
          },
          onLogout: onLogout,
        ),
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

  @override
  Widget build(BuildContext context) {
    return ArtistReviewsPage(
      clientArtistMenuStyle: true,
      showBottomNav: true,
      showCampaignsTab: showCampaignsTab,
      bottomNavCurrentIndex: showCampaignsTab ? 0 : 4,
      onBottomNavTap: (index) => _openHomeTab(context, index),
      onManageProfile: onOpenProfile,
      onOpenHistory: () {
        _openHistory(context);
      },
      onOpenCalendar: () {
        _openCalendar(context);
      },
      onOpenArtist: () {
        _openArtist(context);
      },
      onOpenEarnings: showCampaignsTab
          ? () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => ClientArtistEarningsPage(
                    profile: profile,
                    showContinueProfileCard: showContinueProfileCard,
                    enableAllTabs: enableAllTabs,
                    showCampaignsTab: showCampaignsTab,
                    onOpenProfile: onOpenProfile,
                    onLogout: onLogout,
                  ),
                ),
              );
            }
          : null,
      onOpenReviews: () {},
      onSignOut: () {
        _logout(context);
      },
    );
  }
}
