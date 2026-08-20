import 'package:flutter/material.dart';

import '../models/client_profile_models.dart';
import '../theme/app_colors.dart';
import 'client_artist_artist_page.dart';
import 'client_custom_request_with_artist_page.dart';

class ClientArtistCustomRequestWithArtistPage extends StatelessWidget {
  const ClientArtistCustomRequestWithArtistPage({
    super.key,
    required this.profile,
    required this.artistName,
    this.artistNames = const <String>[],
    this.showCampaignsTab = false,
    this.showContinueProfileCard = false,
    this.enableAllTabs = true,
    this.onClientNavTap,
  });

  final ClientProfileDraft profile;
  final String artistName;
  final List<String> artistNames;
  final bool showCampaignsTab;
  final bool showContinueProfileCard;
  final bool enableAllTabs;
  final Future<void> Function(BuildContext context, int index)? onClientNavTap;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        child: ClientCustomRequestWithArtistPage(
          profile: profile,
          artistName: artistName,
          artistNames: artistNames,
          showClientBottomNav: true,
          onClientNavTap: onClientNavTap,
          // Client-Artist has its own tab set (Requests/Campaigns/Earnings
          // instead of Artists/Profile) -- reuse the same bar ClientArtist
          // pages show elsewhere instead of the Client-role bottom nav.
          customBottomNavigationBar: _ClientArtistBottomNav(
            showCampaignsTab: showCampaignsTab,
            onTap: (i) => onClientNavTap?.call(context, i),
          ),
          // Reopen the same Artists page (with its own bottom nav) the rest
          // of the Client-Artist role uses, instead of the plain Client's
          // bare page with no bottom nav.
          onOpenArtist: (ctx) async {
            Navigator.of(ctx).push(
              MaterialPageRoute(
                builder: (_) => ClientArtistArtistPage(
                  profile: profile,
                  showContinueProfileCard: showContinueProfileCard,
                  enableAllTabs: enableAllTabs,
                  showCampaignsTab: showCampaignsTab,
                ),
              ),
            );
          },
          excludeCurrentUserFromArtistDropdown: true,
          onSubmitted: (ctx) async {
            if (Navigator.of(ctx).canPop()) {
              Navigator.of(ctx).pop();
            }
          },
        ),
      ),
    );
  }
}

class _ClientArtistBottomNav extends StatelessWidget {
  const _ClientArtistBottomNav({
    required this.showCampaignsTab,
    required this.onTap,
  });

  final bool showCampaignsTab;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: AppColors.balletSlippers,
      currentIndex: 1, // Design selected on this page
      onTap: onTap,
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
    );
  }
}
