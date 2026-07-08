import 'package:flutter/material.dart';

import 'client_campaigns_page.dart';

class ClientArtistCampaignsPage extends StatelessWidget {
  const ClientArtistCampaignsPage({
    super.key,
    this.onOpenProfile,
    this.onOpenEarnings,
    this.onLogout,
  });

  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenEarnings;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    return ClientCampaignsPage(
      onOpenProfile: onOpenProfile,
      onOpenEarnings: onOpenEarnings,
      onLogout: onLogout,
      showBrandRequests: true,
      showClientRequests: false,
      useCampaignNaming: true,
    );
  }
}
