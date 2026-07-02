import 'dart:async';

import 'package:flutter/material.dart';

import 'artist_requests_page_redesign.dart';

class ClientArtistRequestsPage extends StatelessWidget {
  const ClientArtistRequestsPage({
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
  final Future<void> Function()? onLogout;

  @override
  Widget build(BuildContext context) {
    return ArtistRequestsPageRedesign(
      clientArtistMenuStyle: true,
      showProfileMenuItem: true,
      onManageProfile: onOpenProfile,
      onOpenHistory: onOpenHistory,
      onOpenCalendar: onOpenCalendar,
      onOpenArtist: onOpenArtist,
      onOpenReviews: onOpenReviews,
      onOpenEarnings: onOpenEarnings,
      onSignOut: onLogout == null ? null : () => unawaited(onLogout!.call()),
    );
  }
}
