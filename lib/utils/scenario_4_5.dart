import 'package:jewelnottool/models/client_request_v2.dart';

enum Scenario45RequestType {
  standard,
  directToClient,
  directToArtist,
  clientGroupOrder,
  clientGroupOrderWithDirectArtist,
  directToBothClientAndArtist,
  specificClientAndSpecificArtist,
}

Map<String, String> scenario45StatusesAfterBrandSubmit() => const <String, String>{
  'brandStatus': 'pending',
  'directClientStatus': 'pending',
};

Map<String, String> scenario45StatusesAfterClientAccept() => const <String, String>{
  'brandStatus': 'pending',
  'clientStatus': 'pending',
  'directArtistStatus': 'in_review',
};

Map<String, String> scenario45StatusesAfterBrandCancelBeforeArtistAccept() =>
    const <String, String>{
      'brandStatus': 'cancelled',
      'clientStatus': 'cancelled',
      'artistStatus': 'cancelled',
      'directClientStatus': 'cancelled',
      'directArtistStatus': 'cancelled',
    };

bool scenario45CancellationReasonRequired(String reason) =>
    reason.trim().isNotEmpty;

bool scenario45ArtistCanActAfterCancellation() => false;
bool scenario45ClientCanActAfterCancellation() => false;
bool scenario45ArtistCanFinalizeAfterCancellation() => false;

bool scenario45IsSingleOrderScope(RequestOrderTypeV2 orderType) =>
    orderType == RequestOrderTypeV2.single;

bool scenario45AppliesToRequestType(Scenario45RequestType type) {
  switch (type) {
    case Scenario45RequestType.clientGroupOrder:
    case Scenario45RequestType.clientGroupOrderWithDirectArtist:
      return false;
    default:
      return true;
  }
}

String scenario45ClientReceiveAfterBrandSubmit({
  required String orderRef,
  required String brandCompany,
}) {
  return 'You have received the Brand request $orderRef from $brandCompany. Please review and accept.';
}

String scenario45BrandReceiveAfterClientAcceptance({
  required String clientName,
  required String campaignName,
  required String orderRef,
}) {
  return '$clientName has accepted your $campaignName brand request $orderRef';
}

String scenario45DirectArtistReceiveAfterClientAcceptance({
  required String orderRef,
  required String clientName,
  required String brandName,
  required String campaignName,
}) {
  return 'You have received a Brand request $orderRef for $clientName from $brandName $campaignName';
}

String scenario45BrandReceiveAfterBrandCancellation({
  required String brandCompany,
  required String campaignName,
  required String orderRef,
  required String reason,
}) {
  return '$brandCompany cancelled your $campaignName brand request $orderRef $reason';
}

String scenario45DirectArtistReceiveAfterBrandCancellation({
  required String brandCompany,
  required String campaignName,
  required String orderRef,
  required String reason,
  required String clientName,
}) {
  return '$brandCompany cancelled $campaignName brand request $orderRef $reason for $clientName';
}

String scenario45AcceptedClientReceiveAfterBrandCancellation({
  required String brandName,
  required String campaignName,
  required String orderRef,
  required String reason,
}) {
  return 'Your $brandName $campaignName brand request $orderRef has been cancelled $reason';
}
