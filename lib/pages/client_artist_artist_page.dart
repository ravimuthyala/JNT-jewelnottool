import 'package:flutter/material.dart';

import '../models/client_profile_models.dart';
import '../theme/app_colors.dart';
import 'client_artist_earnings_page.dart';
import 'client_artist_home_page.dart';
import 'client_artists_page.dart';

class ClientArtistArtistPage extends StatelessWidget {
  const ClientArtistArtistPage({
    super.key,
    required this.profile,
    required this.showContinueProfileCard,
    required this.enableAllTabs,
    required this.showCampaignsTab,
    this.onOpenProfile,
    this.onOpenHistory,
    this.onOpenCalendar,
    this.onLogout,
  });

  final ClientProfileDraft profile;
  final bool showContinueProfileCard;
  final bool enableAllTabs;
  final bool showCampaignsTab;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenCalendar;
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

  void _openReviews(BuildContext context) {
    Navigator.pushReplacement(
      context,
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
  }

  void _openEarnings(BuildContext context) {
    Navigator.pushReplacement(
      context,
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

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      label: 'Client artist view',
      child: Scaffold(
      backgroundColor: AppColors.snow,
      body: ClientArtistsPage(
        profile: profile,
        onOpenProfile: onOpenProfile,
        onOpenEarnings: showCampaignsTab ? () => _openEarnings(context) : null,
        onOpenHistory: onOpenHistory,
        onOpenCalendar: onOpenCalendar,
        onOpenArtist: () {},
        onOpenReviews: () => _openReviews(context),
        onLogout: onLogout,
        showProfileMenu: true,
        showHistoryMenu: true,
        showCalendarMenu: true,
        showArtistMenu: false,
        showReviewsMenu: true,
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppColors.balletSlippers,
        currentIndex: 0,
        onTap: (i) => _openHomeTab(context, i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.blackCat,
        unselectedItemColor: Colors.black.withValues(alpha: 0.55),
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
          if (showCampaignsTab)
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
          if (!showCampaignsTab)
            const BottomNavigationBarItem(
              icon: Icon(Icons.attach_money_outlined),
              activeIcon: Icon(Icons.attach_money),
              label: 'Earnings',
            ),
        ],
      ),
      ),
    );
  }
}
