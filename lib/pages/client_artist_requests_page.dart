import 'dart:async';

import 'package:flutter/material.dart';

import '../models/client_profile_models.dart';
import 'artist_requests_page_redesign.dart';

class ClientArtistRequestsPage extends StatelessWidget {
  const ClientArtistRequestsPage({
    super.key,
    this.profile,
    this.onOpenProfile,
    this.onOpenHistory,
    this.onOpenCalendar,
    this.onOpenArtist,
    this.onOpenReviews,
    this.onOpenEarnings,
    this.onLogout,
  });

  final ClientProfileDraft? profile;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenArtist;
  final VoidCallback? onOpenReviews;
  final VoidCallback? onOpenEarnings;
  final Future<void> Function()? onLogout;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        child: ArtistRequestsPageRedesign(
          clientArtistMenuStyle: true,
          showProfileMenuItem: true,
          clientDisplayName: profile?.basic.name ?? '',
          clientProfileImageUrl: profile?.basic.profileImageUrl ?? '',
          onManageProfile: onOpenProfile,
          onOpenHistory: onOpenHistory,
          onOpenCalendar: onOpenCalendar,
          onOpenArtist: onOpenArtist,
          onOpenReviews: onOpenReviews,
          onOpenEarnings: onOpenEarnings,
          onSignOut: onLogout == null
              ? null
              : () => unawaited(onLogout!.call()),
        ),
      ),
    );
  }
}
