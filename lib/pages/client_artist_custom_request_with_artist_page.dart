import 'package:flutter/material.dart';

import '../models/client_profile_models.dart';
import 'client_custom_request_with_artist_page.dart';

class ClientArtistCustomRequestWithArtistPage extends StatelessWidget {
  const ClientArtistCustomRequestWithArtistPage({
    super.key,
    required this.profile,
    required this.artistName,
    this.artistNames = const <String>[],
    this.onClientNavTap,
  });

  final ClientProfileDraft profile;
  final String artistName;
  final List<String> artistNames;
  final Future<void> Function(BuildContext context, int index)? onClientNavTap;

  @override
  Widget build(BuildContext context) {
    return ClientCustomRequestWithArtistPage(
      profile: profile,
      artistName: artistName,
      artistNames: artistNames,
      showClientBottomNav: true,
      onClientNavTap: onClientNavTap,
      excludeCurrentUserFromArtistDropdown: true,
      onSubmitted: (ctx) async {
        if (Navigator.of(ctx).canPop()) {
          Navigator.of(ctx).pop();
        }
      },
    );
  }
}
