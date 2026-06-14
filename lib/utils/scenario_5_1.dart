Map<String, String> scenario51StatusesAfterBrandSubmit() =>
    const <String, String>{
      'brandStatus': 'pending',
      'clientStatus': 'pending',
      'artistStatus': 'pending',
    };

Map<String, String> scenario51StatusesAfterAllClientsAccepted() =>
    const <String, String>{
      'brandStatus': 'pending',
      'clientStatus': 'pending',
      'artistStatus': 'in_review',
    };

Map<String, String> scenario51StatusesAfterArtistAcceptance() =>
    const <String, String>{
      'brandStatus': 'in_progress',
      'clientStatus': 'in_progress',
      'artistStatus': 'designing',
    };

bool scenario51CanSubmitGroupOrder(int selectedClientCount) {
  return selectedClientCount >= 2 && selectedClientCount <= 15;
}

bool scenario51CanSelectAnotherClient(int selectedClientCount) {
  return selectedClientCount < 15;
}

bool scenario51HasSingleOrderNumberForGroup() => true;

bool scenario51VisibleToSelectedClient({
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

bool scenario51AllSelectedClientsResponded({
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

bool scenario51ArtistPoolCanSee({
  required List<String> selectedGroupClientEmails,
  required List<String> acceptedGroupClientEmails,
  required List<String> declinedGroupClientEmails,
}) {
  return scenario51AllSelectedClientsResponded(
    selectedGroupClientEmails: selectedGroupClientEmails,
    acceptedGroupClientEmails: acceptedGroupClientEmails,
    declinedGroupClientEmails: declinedGroupClientEmails,
  );
}

bool scenario51ArtistPoolCanAccept({
  required String acceptedByArtistEmail,
  required String viewerArtistEmail,
}) {
  final owner = acceptedByArtistEmail.trim().toLowerCase();
  final viewer = viewerArtistEmail.trim().toLowerCase();
  if (viewer.isEmpty) return false;
  if (owner.isEmpty) return true;
  return owner == viewer;
}

String scenario51ClientSummary(List<String> clientNames) {
  final names = clientNames
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList(growable: false);
  if (names.isEmpty) return 'Client Group';
  return names.join(', ');
}

String scenario51ClientReceiveOnSubmit({
  required String orderRef,
  required String brandCompany,
}) {
  return 'You have received the Brand request $orderRef from $brandCompany. Please review and accept.';
}

String scenario51BrandReceiveOnClientAcceptance({
  required String clientName,
  required String campaignName,
  required String orderRef,
}) {
  return '$clientName has accepted your $campaignName brand request $orderRef';
}

String scenario51ArtistPoolReceiveAfterAllAccepted({
  required String orderRef,
  required String clientSummary,
  required String brandName,
  required String campaignName,
}) {
  return 'You have received a Brand request $orderRef for $clientSummary from $brandName $campaignName';
}

String scenario51BrandReceiveOnArtistAcceptance({
  required String artistName,
  required String campaignName,
  required String orderRef,
  required String clientSummary,
}) {
  return '$artistName has accepted your $campaignName brand request $orderRef for $clientSummary';
}

String scenario51AcceptedClientReceiveOnArtistAcceptance({
  required String campaignName,
  required String orderRef,
  required String artistName,
}) {
  return 'Your $campaignName Brand request $orderRef is accepted by $artistName';
}
