import 'package:flutter/material.dart';

import '../models/client_profile_models.dart';
import 'client_orders_page.dart';

class ClientArtistOrderPage extends StatelessWidget {
  const ClientArtistOrderPage({
    super.key,
    required this.profile,
    this.onBackHome,
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
  Widget build(BuildContext context) {
    return ClientOrdersPage(
      profile: profile,
      onBackHome: onBackHome,
      onOpenProfile: onOpenProfile,
      onOpenHistory: onOpenHistory,
      onOpenCalendar: onOpenCalendar,
      onOpenArtist: onOpenArtist,
      onLogout: onLogout,
      showExtendedAvatarMenu: showExtendedAvatarMenu,
      showProfileMenu: showProfileMenu,
      bottomNavIndex: bottomNavIndex,
      onNavTap: onNavTap,
      audience: OrdersAudience.clientArtist,
    );
  }
}
