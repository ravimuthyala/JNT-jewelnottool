import 'package:flutter/material.dart';

import '../models/client_profile_models.dart';
import 'company_custom_request_page.dart';

class CompanyCustomRequestWithArtistPage extends StatelessWidget {
  const CompanyCustomRequestWithArtistPage({
    super.key,
    required this.profile,
    required this.artistName,
    required this.artistNames,
    this.companyName,
    this.onBackHome,
    this.onOpenProfile,
    this.onLogout,
    this.showBottomNav = true,
    this.bottomNavIndex = 1,
    this.onNavTap,
  });

  final ClientProfileDraft profile;
  final String artistName;
  final List<String> artistNames;
  final String? companyName;
  final VoidCallback? onBackHome;
  final VoidCallback? onOpenProfile;
  final Future<void> Function()? onLogout;
  final bool showBottomNav;
  final int bottomNavIndex;
  final ValueChanged<int>? onNavTap;

  @override
  Widget build(BuildContext context) {
    return CompanyCustomRequestPage(
      profile: profile,
      companyName: companyName,
      onBackHome: onBackHome,
      onOpenProfile: onOpenProfile,
      onLogout: onLogout,
      showBottomNav: showBottomNav,
      bottomNavIndex: bottomNavIndex,
      onNavTap: onNavTap,
      initialRequestedArtist: artistName,
      defaultSpecificArtistSelection: true,
      artistOptions: artistNames,
    );
  }
}
