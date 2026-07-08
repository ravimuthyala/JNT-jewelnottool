import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/client_profile_models.dart';
import 'client_artist_custom_request_with_artist_page.dart';
import 'client_artist_profile_page.dart';
import 'client_artist_view_tabs.dart';
import 'client_home_page.dart';

class ClientArtistClientViewTab extends StatelessWidget {
  const ClientArtistClientViewTab({
    super.key,
    this.profile,
    required this.showContinueProfileCard,
    this.onOpenProfile,
    this.onLogout,
  });

  final ClientProfileDraft? profile;
  final bool showContinueProfileCard;
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
    final user = Supabase.instance.client.auth.currentUser;
    final metadata = user?.userMetadata ?? const <String, dynamic>{};
    final authDisplayName =
        (metadata['displayName'] ??
                metadata['display_name'] ??
                metadata['fullName'] ??
                metadata['full_name'] ??
                metadata['name'] ??
                '')
            .toString()
            .trim();
    final profileName = draft.basic.name.trim();
    final displayName = profileName.isNotEmpty
        ? profileName
        : (authDisplayName.isNotEmpty ? authDisplayName : 'Client');

    return ClientHomePage(
      clientName: displayName,
      profileComplete: true,
      showExtendedAvatarMenu: true,
      headerBottom: const ClientArtistViewTabs(),
      onLogout: () async {
        if (onLogout != null) {
          await onLogout!.call();
          return;
        }
        if (!context.mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      },
      onOpenProfile: () {
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
      onRequestArtist: (artistName) {
        final name = artistName.trim();
        if (name.isEmpty) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ClientArtistCustomRequestWithArtistPage(
              profile: draft,
              artistName: name,
              artistNames: <String>[name],
              onClientNavTap: (ctx, index) async {
                if (index == 1) return;
                if (Navigator.of(ctx).canPop()) {
                  Navigator.of(ctx).pop(index);
                }
              },
            ),
          ),
        );
      },
    );
  }
}
