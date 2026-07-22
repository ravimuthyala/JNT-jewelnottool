import 'package:jewelnottool/models/client_request_v2.dart';

const String scenario41BrandStatusPending = 'pending';
const String scenario41BrandStatusInProgress = 'in_progress';
const String scenario41ClientStatusPending = 'pending';
const String scenario41ClientStatusInProgress = 'in_progress';
const String scenario41ArtistStatusPending = 'pending';
const String scenario41ArtistStatusInReview = 'in_review';
const String scenario41ArtistStatusDesigning = 'designing';

Map<String, String> scenario41StatusesAfterBrandSubmit() =>
    const <String, String>{
      'brandStatus': scenario41BrandStatusPending,
      'clientStatus': scenario41ClientStatusPending,
      'artistStatus': scenario41ArtistStatusPending,
    };

Map<String, String> scenario41StatusesAfterClientAcceptance() =>
    const <String, String>{
      'brandStatus': scenario41BrandStatusPending,
      'clientStatus': scenario41ClientStatusPending,
      'artistStatus': scenario41ArtistStatusInReview,
    };

Map<String, String> scenario41StatusesAfterArtistAcceptance() =>
    const <String, String>{
      'brandStatus': scenario41BrandStatusInProgress,
      'clientStatus': scenario41ClientStatusInProgress,
      'artistStatus': scenario41ArtistStatusDesigning,
    };

bool shouldShowScenario41ToDirectClient({
  required bool openToClientPool,
  required RequestOrderTypeV2 orderType,
  required String selectedClientEmail,
  required List<String> selectedGroupClientEmails,
  required String viewerEmail,
}) {
  final viewer = viewerEmail.trim().toLowerCase();
  if (viewer.isEmpty) return false;
  if (openToClientPool) return true;

  final selected = selectedClientEmail.trim().toLowerCase();
  final selectedGroup = selectedGroupClientEmails
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toSet();

  if (orderType == RequestOrderTypeV2.group) {
    return selectedGroup.contains(viewer);
  }
  return selected.isNotEmpty && selected == viewer;
}

bool shouldShowScenario41ToDirectArtist({
  required bool clientAccepted,
  required bool isDirectRequest,
  required String selectedArtistEmail,
  required String acceptedByArtistEmail,
  required String viewerArtistEmail,
}) {
  if (!clientAccepted) return false;

  final viewer = viewerArtistEmail.trim().toLowerCase();
  if (viewer.isEmpty) return false;

  final owner = acceptedByArtistEmail.trim().toLowerCase();
  if (owner.isNotEmpty) return owner == viewer;

  if (!isDirectRequest) return true;

  final selected = selectedArtistEmail.trim().toLowerCase();
  if (selected.isEmpty) return false;
  return selected == viewer;
}

String scenario41ClientReceiveOnSubmit({
  required String orderRef,
  required String brandCompany,
  required String campaignName,
}) {
  final brand = brandCompany.trim();
  final campaign = campaignName.trim();
  if (brand.isNotEmpty && campaign.isNotEmpty) {
    return 'Received brand request from $brand, $campaign';
  }
  if (brand.isNotEmpty) {
    return 'Received brand request from $brand';
  }
  if (campaign.isNotEmpty) {
    return 'Received brand request, $campaign';
  }
  return 'Received brand request';
}

String scenario41BrandReceiveOnClientAcceptance({
  required String clientName,
  required String campaignName,
  required String orderRef,
}) {
  return '$clientName has accepted your $campaignName brand request $orderRef';
}

String scenario41DirectArtistReceiveOnClientAcceptance({
  required String orderRef,
  required String clientName,
  required String brandName,
  required String campaignName,
}) {
  return 'You have received a Brand request $orderRef for $clientName from $brandName $campaignName';
}

String scenario41BrandReceiveOnArtistAcceptance({
  required String artistName,
  required String campaignName,
  required String orderRef,
  required String clientName,
}) {
  return '$artistName has accepted your $campaignName brand request $orderRef for $clientName';
}

String scenario41DirectClientReceiveOnArtistAcceptance({
  required String campaignName,
  required String orderRef,
  required String artistName,
}) {
  return 'Your $campaignName Brand request $orderRef is accepted by $artistName';
}
