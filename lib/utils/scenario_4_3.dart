import 'package:jewelnottool/models/client_request_v2.dart';
import 'package:jewelnottool/utils/scenario_4_1.dart';

Map<String, String> scenario43StatusesAfterBrandSubmit() =>
    scenario41StatusesAfterBrandSubmit();

Map<String, String> scenario43StatusesAfterDirectClientDecline() =>
    const <String, String>{
      'brandStatus': 'pending',
      'directClientStatus': 'declined',
      'clientPoolStatus': 'pending',
      'artistStatus': 'pending',
    };

Map<String, String> scenario43StatusesAfterPoolClientAcceptance() =>
    const <String, String>{
      'brandStatus': 'pending',
      'clientStatus': 'pending',
      'directArtistStatus': 'in_review',
    };

Map<String, String> scenario43StatusesAfterDirectArtistDecline() =>
    const <String, String>{
      'brandStatus': 'pending',
      'clientStatus': 'pending',
      'directArtistStatus': 'declined',
      'artistPoolStatus': 'in_review',
    };

Map<String, String> scenario43StatusesAfterArtistPoolAcceptance() =>
    scenario41StatusesAfterArtistAcceptance();

bool shouldShowScenario43ToArtistPool({
  required bool isDirectRequest,
  required bool fallbackToPool,
  required List<String> declinedByArtistEmails,
  required String acceptedByArtistEmail,
  required String viewerArtistEmail,
}) {
  final viewer = viewerArtistEmail.trim().toLowerCase();
  if (viewer.isEmpty) return false;
  if (acceptedByArtistEmail.trim().isNotEmpty) return false;
  if (isDirectRequest) return false;
  if (!fallbackToPool) return false;
  final declined = declinedByArtistEmails
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toSet();
  return !declined.contains(viewer);
}

String scenario43BrandReceiveOnDirectArtistDecline({
  required String artistName,
  required String brandName,
  required String campaignName,
  required String orderRef,
  required String clientName,
}) {
  return '$artistName has denied $brandName $campaignName brand request $orderRef for $clientName';
}

String scenario43ArtistPoolReceiveOnDirectArtistDecline({
  required String orderRef,
  required String clientName,
  required String brandName,
  required String campaignName,
}) {
  return scenario41DirectArtistReceiveOnClientAcceptance(
    orderRef: orderRef,
    clientName: clientName,
    brandName: brandName,
    campaignName: campaignName,
  );
}

bool isScenario43SingleOrder(RequestOrderTypeV2 orderType) {
  return orderType == RequestOrderTypeV2.single;
}
