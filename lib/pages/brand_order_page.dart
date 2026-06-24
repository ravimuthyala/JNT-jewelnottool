import 'package:flutter/material.dart';

import '../models/client_profile_models.dart';
import 'brand_order_page_v2.dart';

class BrandOrderPage extends StatefulWidget {
  const BrandOrderPage({
    super.key,
    required this.profile,
    required this.companyName,
    this.onBackHome,
    this.showCompanyChrome = true,
    this.onOpenProfile,
    this.onOpenHistory,
    this.onOpenCalendar,
    this.onOpenArtist,
    this.onLogout,
    this.showExtendedAvatarMenu = false,
    this.showProfileMenu = false,
    this.bottomNavIndex = 3,
    this.onNavTap,
  });

  final ClientProfileDraft profile;
  final VoidCallback? onBackHome;
  final String companyName;
  final bool showCompanyChrome;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenArtist;
  final Future<void> Function()? onLogout;
  final bool showExtendedAvatarMenu;
  final bool showProfileMenu;
  final int bottomNavIndex;
  final ValueChanged<int>? onNavTap;

  @override
  State<BrandOrderPage> createState() => _BrandOrderPageState();
}

class _BrandOrderPageState extends State<BrandOrderPage> {
  @override
  Widget build(BuildContext context) {
    return BrandOrderPageV2(
      profile: widget.profile,
      companyName: widget.companyName,
      onBackHome: widget.onBackHome,
      showCompanyChrome: widget.showCompanyChrome,
      onOpenProfile: widget.onOpenProfile,
      onOpenHistory: widget.onOpenHistory,
      onOpenCalendar: widget.onOpenCalendar,
      onOpenArtist: widget.onOpenArtist,
      onLogout: widget.onLogout,
      showExtendedAvatarMenu: widget.showExtendedAvatarMenu,
      showProfileMenu: widget.showProfileMenu,
      bottomNavIndex: widget.bottomNavIndex,
      onNavTap: widget.onNavTap,
    );
  }
}
