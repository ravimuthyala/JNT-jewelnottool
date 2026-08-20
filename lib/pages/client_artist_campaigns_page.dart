import 'package:flutter/material.dart';

import 'client_campaigns_page.dart';

class ClientArtistCampaignsPage extends StatelessWidget {
  const ClientArtistCampaignsPage({
    super.key,
    this.onOpenProfile,
    this.onOpenHistory,
    this.onOpenCalendar,
    this.onOpenArtist,
    this.onOpenReviews,
    this.onOpenEarnings,
    this.onLogout,
  });

  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenArtist;
  final VoidCallback? onOpenReviews;
  final VoidCallback? onOpenEarnings;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    return ClientCampaignsPage(
      onOpenProfile: onOpenProfile,
      onOpenHistory: onOpenHistory,
      onOpenCalendar: onOpenCalendar,
      onOpenArtist: onOpenArtist,
      onOpenReviews: onOpenReviews,
      onOpenEarnings: onOpenEarnings,
      onLogout: onLogout,
      showBrandRequests: true,
      showClientRequests: false,
      useCampaignNaming: true,
      clientArtistMenuStyle: true,
    );
  }
}
