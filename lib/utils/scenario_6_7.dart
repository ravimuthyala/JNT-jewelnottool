Map<String, String> scenario67StatusesAfterBrandSubmit() =>
    const <String, String>{
      'brandStatus': 'pending',
      'clientStatus': 'pending',
      'artistStatus': 'pending',
    };

Map<String, String> scenario67StatusesAfterPartialClientResponses() =>
    const <String, String>{
      'brandStatus': 'pending',
      'acceptedClientStatus': 'pending',
      'declinedClientStatus': 'declined',
      'artistStatus': 'pending',
    };

Map<String, String> scenario67StatusesAfterAllClientsResponded() =>
    const <String, String>{
      'brandStatus': 'pending',
      'acceptedClientStatus': 'pending',
      'declinedClientStatus': 'declined',
      'artistStatus': 'in_review',
    };

Map<String, String> scenario67StatusesAfterBrandCancelBeforeArtistAccept() =>
    const <String, String>{
      'brandStatus': 'cancelled',
      'acceptedClientStatus': 'cancelled',
      'declinedClientStatus': 'declined',
      'artistStatus': 'cancelled',
    };

bool scenario67CanSubmitGroupOrder({
  required int selectedClientCount,
  required bool specificArtistSelected,
}) {
  return selectedClientCount >= 2 &&
      selectedClientCount <= 15 &&
      specificArtistSelected;
}

bool scenario67CanSelectAnotherClient(int selectedClientCount) {
  return selectedClientCount < 15;
}

bool scenario67HasSingleOrderNumberForGroup() => true;

String scenario67RequestTypeLabel() => 'Direct';

bool scenario67VisibleToSelectedClient({
  required String viewerEmail,
  required List<String> selectedGroupClientEmails,
  required List<String> acceptedGroupClientEmails,
  required List<String> declinedGroupClientEmails,
}) {
  final viewer = viewerEmail.trim().toLowerCase();
  if (viewer.isEmpty) return false;
  final selected = selectedGroupClientEmails
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toSet();
  final accepted = acceptedGroupClientEmails
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toSet();
  final declined = declinedGroupClientEmails
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toSet();
  if (!selected.contains(viewer)) return false;
  if (accepted.contains(viewer)) return false;
  if (declined.contains(viewer)) return false;
  return true;
}

bool scenario67AllSelectedClientsResponded({
  required List<String> selectedGroupClientEmails,
  required List<String> acceptedGroupClientEmails,
  required List<String> declinedGroupClientEmails,
}) {
  final selected = selectedGroupClientEmails
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toSet();
  final responded = <String>{
    ...acceptedGroupClientEmails
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty),
    ...declinedGroupClientEmails
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty),
  };
  return selected.isNotEmpty && selected.every(responded.contains);
}

bool scenario67DirectArtistCanSee({
  required String viewerArtistEmail,
  required String selectedArtistEmail,
  required List<String> selectedGroupClientEmails,
  required List<String> acceptedGroupClientEmails,
  required List<String> declinedGroupClientEmails,
}) {
  final viewer = viewerArtistEmail.trim().toLowerCase();
  final selectedArtist = selectedArtistEmail.trim().toLowerCase();
  if (viewer.isEmpty || selectedArtist.isEmpty || viewer != selectedArtist) {
    return false;
  }
  return scenario67AllSelectedClientsResponded(
    selectedGroupClientEmails: selectedGroupClientEmails,
    acceptedGroupClientEmails: acceptedGroupClientEmails,
    declinedGroupClientEmails: declinedGroupClientEmails,
  );
}

bool scenario67DirectArtistCanSeeOnlyAcceptedClients({
  required List<String> selectedGroupClientEmails,
  required List<String> acceptedGroupClientEmails,
  required List<String> declinedGroupClientEmails,
}) {
  if (!scenario67AllSelectedClientsResponded(
    selectedGroupClientEmails: selectedGroupClientEmails,
    acceptedGroupClientEmails: acceptedGroupClientEmails,
    declinedGroupClientEmails: declinedGroupClientEmails,
  )) {
    return false;
  }
  final selected = selectedGroupClientEmails
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toSet();
  final accepted = acceptedGroupClientEmails
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toSet();
  final declined = declinedGroupClientEmails
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toSet();
  return accepted.isNotEmpty &&
      selected.length == accepted.length + declined.length &&
      selected.containsAll(accepted) &&
      selected.containsAll(declined);
}

bool scenario67ArtistCanActAfterBrandCancellation() => false;
bool scenario67ClientCanActAfterBrandCancellation() => false;
bool scenario67ArtistCanFinalizeAfterBrandCancellation() => false;

String scenario67ClientSummary(List<String> clientNames) {
  final names = clientNames
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList(growable: false);
  if (names.isEmpty) return 'Client Group';
  return names.join(', ');
}

String scenario67ClientReceiveOnSubmit({
  required String orderRef,
  required String brandCompany,
}) {
  return 'You have received the Brand request $orderRef from $brandCompany. Please review and accept.';
}

String scenario67BrandReceiveOnClientAcceptance({
  required String clientName,
  required String campaignName,
  required String orderRef,
}) {
  return '$clientName has accepted your $campaignName brand request $orderRef';
}

String scenario67DirectArtistReceiveAfterAllResponses({
  required String orderRef,
  required String clientSummary,
  required String brandName,
  required String campaignName,
}) {
  return 'You have received a Brand request $orderRef for $clientSummary from $brandName $campaignName';
}

String scenario67BrandReceiveAfterBrandCancellation({
  required String brandCompany,
  required String campaignName,
  required String orderRef,
  required String reason,
}) {
  return '**$brandCompany** cancelled your Campaign: **$campaignName** **$orderRef** **$reason**';
}

String scenario67DirectArtistReceiveAfterBrandCancellation({
  required String brandCompany,
  required String campaignName,
  required String orderRef,
  required String reason,
  required String clientSummary,
}) {
  return '**$brandCompany** cancelled Campaign **$campaignName** **$orderRef** **$reason** for **$clientSummary**';
}

String scenario67AcceptedClientReceiveAfterBrandCancellation({
  required String brandName,
  required String campaignName,
  required String orderRef,
  required String reason,
}) {
  return 'Your Campaign **$campaignName** **$orderRef** has been cancelled **$reason** by **$brandName**';
}

List<String> scenario671BrandCancellationRecipients({
  required List<String> selectedGroupClientEmails,
  required List<String> rejectedGroupClientEmails,
}) {
  final selected = selectedGroupClientEmails
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);
  final rejected = rejectedGroupClientEmails
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toSet();
  return selected
      .where((email) => !rejected.contains(email))
      .toList(growable: false);
}

bool scenario671ArtistHistoryVisible({
  required String currentArtistEmail,
  required String selectedArtistEmail,
  required String acceptedByArtistEmail,
}) {
  final viewer = currentArtistEmail.trim().toLowerCase();
  final selected = selectedArtistEmail.trim().toLowerCase();
  final accepted = acceptedByArtistEmail.trim().toLowerCase();
  final resolvedOwner = accepted.isNotEmpty ? accepted : selected;
  if (resolvedOwner.isEmpty) return true;
  return viewer.isNotEmpty && viewer == resolvedOwner;
}

bool scenario671ClientOrderShowsCancelled({
  required String rawStatus,
  required String cancelReason,
  required DateTime? cancelledAt,
}) {
  final status = rawStatus.trim().toLowerCase();
  if (status == 'cancelled' || status == 'canceled') return true;
  return cancelledAt != null || cancelReason.trim().isNotEmpty;
}

bool scenario671GroupClientVisibleOnCancel({
  required String viewerEmail,
  required List<String> groupClientEmails,
  required List<String> rejectedGroupClientEmails,
}) {
  final viewer = viewerEmail.trim().toLowerCase();
  if (viewer.isEmpty) return false;
  final selected = groupClientEmails
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toSet();
  final rejected = rejectedGroupClientEmails
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toSet();
  return selected.contains(viewer) && !rejected.contains(viewer);
}

bool scenario671GroupClientVisibleByIdOnCancel({
  required String viewerEmail,
  required String groupClientId,
  required List<String> knownGroupClientIds,
}) {
  final viewer = viewerEmail.trim().toLowerCase();
  final id = groupClientId.trim().toLowerCase();
  final knownIds = knownGroupClientIds
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toSet();
  return viewer.isNotEmpty && id.isNotEmpty && knownIds.contains(id);
}
