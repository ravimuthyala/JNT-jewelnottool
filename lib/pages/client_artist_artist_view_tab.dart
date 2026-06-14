import 'dart:async';

import 'package:flutter/material.dart';

import '../models/client_profile_models.dart';
import 'artist_earnings_page.dart';
import 'artist_history_page.dart';
import 'artist_home_page.dart';
import 'artist_inbox_page.dart';
import 'artist_requests_page_redesign.dart';
import 'client_artist_profile_page.dart';
import 'client_artist_view_tabs.dart';

class ClientArtistArtistViewTab extends StatelessWidget {
  const ClientArtistArtistViewTab({
    super.key,
    this.profile,
    this.onOpenProfile,
    this.onLogout,
  });

  final ClientProfileDraft? profile;
  final VoidCallback? onOpenProfile;
  final Future<void> Function()? onLogout;

  ClientProfileDraft _fallbackProfile() {
    return ClientProfileDraft(
      basic: const BasicInfo(name: '', email: '', phone: ''),
      address: const AddressInfo(
        street: '',
        city: '',
        state: '',
        zip: '',
        country: 'United States',
      ),
      payment: const PaymentInfo(
        method: PaymentMethod.applePay,
        saveForFuture: false,
      ),
      nail: NailPreferences.empty(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = profile ?? _fallbackProfile();

    return ArtistHomePage(
      headerBottom: const ClientArtistViewTabs(),
      onOpenRequests: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ArtistRequestsPageRedesign(),
          ),
        );
      },
      onManageProfile: () {
        if (onOpenProfile != null) {
          onOpenProfile!.call();
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ClientArtistProfilePage(initialProfile: draft),
          ),
        );
      },
      onOpenInbox: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ArtistInboxPage()),
        );
      },
      onSignOut: () {
        if (onLogout != null) {
          unawaited(onLogout!.call());
          return;
        }
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      },
      onOpenEarnings: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ArtistEarningsPage()),
        );
      },
      onOpenHistory: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ArtistHistoryPage()),
        );
      },
      onOpenInProgress: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ArtistRequestsPageRedesign(),
          ),
        );
      },
    );
  }
}
