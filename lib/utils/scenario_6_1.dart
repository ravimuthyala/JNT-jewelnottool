Map<String, String> scenario61StatusesAfterBrandSubmit() =>
    const <String, String>{
      'brandStatus': 'pending',
      'clientStatus': 'pending',
      'artistStatus': 'pending',
    };

Map<String, String> scenario61StatusesAfterAllClientsAccepted() =>
    const <String, String>{
      'brandStatus': 'pending',
      'clientStatus': 'pending',
      'artistStatus': 'in_review',
    };

Map<String, String> scenario61StatusesAfterArtistAcceptance() =>
    const <String, String>{
      'brandStatus': 'in_progress',
      'clientStatus': 'in_progress',
      'artistStatus': 'designing',
    };

bool scenario61CanSubmitGroupOrder({
  required int selectedClientCount,
  required bool specificArtistSelected,
}) {
  return selectedClientCount >= 2 &&
      selectedClientCount <= 15 &&
      specificArtistSelected;
}

bool scenario61CanSelectAnotherClient(int selectedClientCount) {
  return selectedClientCount < 15;
}

bool scenario61HasSingleOrderNumberForGroup() => true;

bool scenario61AllSelectedClientsResponded({
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

bool scenario61DirectArtistCanSee({
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
  return scenario61AllSelectedClientsResponded(
    selectedGroupClientEmails: selectedGroupClientEmails,
    acceptedGroupClientEmails: acceptedGroupClientEmails,
    declinedGroupClientEmails: declinedGroupClientEmails,
  );
}

bool scenario61DirectArtistCanAccept({
  required String viewerArtistEmail,
  required String selectedArtistEmail,
  required String acceptedByArtistEmail,
}) {
  final viewer = viewerArtistEmail.trim().toLowerCase();
  final selectedArtist = selectedArtistEmail.trim().toLowerCase();
  final acceptedBy = acceptedByArtistEmail.trim().toLowerCase();
  if (viewer.isEmpty || selectedArtist.isEmpty || viewer != selectedArtist) {
    return false;
  }
  if (acceptedBy.isEmpty) return true;
  return acceptedBy == viewer;
}

String scenario61ClientSummary(List<String> clientNames) {
  final names = clientNames
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList(growable: false);
  if (names.isEmpty) return 'Client Group';
  return names.join(', ');
}

String scenario61ClientReceiveOnSubmit({
  required String orderRef,
  required String brandCompany,
}) {
  return 'You have received the Brand request $orderRef from $brandCompany. Please review and accept.';
}

String scenario61BrandReceiveOnClientAcceptance({
  required String clientName,
  required String campaignName,
  required String orderRef,
}) {
  return '$clientName has accepted your $campaignName brand request $orderRef';
}

String scenario61DirectArtistReceiveAfterAllAccepted({
  required String orderRef,
  required String clientSummary,
  required String brandName,
  required String campaignName,
}) {
  return 'You have received a Brand request $orderRef for $clientSummary from $brandName $campaignName';
}

String scenario61BrandReceiveOnArtistAcceptance({
  required String artistName,
  required String campaignName,
  required String orderRef,
  required String clientSummary,
}) {
  return '$artistName has accepted your $campaignName brand request $orderRef for $clientSummary';
}

String scenario61AcceptedClientReceiveOnArtistAcceptance({
  required String campaignName,
  required String orderRef,
  required String artistName,
}) {
  return 'Your $campaignName Brand request $orderRef is accepted by $artistName';
}
