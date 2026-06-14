import 'package:jnt_app_0120/models/client_request_v2.dart';
import 'package:jnt_app_0120/utils/scenario_4_1.dart';

Map<String, String> scenario42StatusesAfterBrandSubmit() =>
    scenario41StatusesAfterBrandSubmit();

Map<String, String> scenario42StatusesAfterDirectClientDecline() =>
    const <String, String>{
      'brandStatus': 'pending',
      'directClientStatus': 'declined',
      'clientPoolStatus': 'pending',
      'artistStatus': 'pending',
    };

Map<String, String> scenario42StatusesAfterPoolClientAcceptance() =>
    scenario41StatusesAfterClientAcceptance();

Map<String, String> scenario42StatusesAfterArtistAcceptance() =>
    scenario41StatusesAfterArtistAcceptance();

bool shouldShowScenario42ToPoolClient({
  required bool openToClientPool,
  required String viewerEmail,
  required List<String> declinedByClientEmails,
  required String acceptedByClientEmail,
}) {
  final viewer = viewerEmail.trim().toLowerCase();
  if (viewer.isEmpty) return false;
  if (!openToClientPool) return false;
  if (acceptedByClientEmail.trim().isNotEmpty) return false;
  final declined = declinedByClientEmails
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toSet();
  return !declined.contains(viewer);
}

String scenario42ClientReceiveOnSubmit({
  required String orderRef,
  required String brandCompany,
  required String campaignName,
}) {
  return scenario41ClientReceiveOnSubmit(
    orderRef: orderRef,
    brandCompany: brandCompany,
    campaignName: campaignName,
  );
}

String scenario42BrandReceiveOnPoolClientAcceptance({
  required String clientName,
  required String campaignName,
  required String orderRef,
}) {
  return scenario41BrandReceiveOnClientAcceptance(
    clientName: clientName,
    campaignName: campaignName,
    orderRef: orderRef,
  );
}

String scenario42DirectArtistReceiveOnPoolClientAcceptance({
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

String scenario42BrandReceiveOnArtistAcceptance({
  required String artistName,
  required String campaignName,
  required String orderRef,
  required String clientName,
}) {
  return scenario41BrandReceiveOnArtistAcceptance(
    artistName: artistName,
    campaignName: campaignName,
    orderRef: orderRef,
    clientName: clientName,
  );
}

String scenario42AcceptedClientReceiveOnArtistAcceptance({
  required String campaignName,
  required String orderRef,
  required String artistName,
}) {
  return scenario41DirectClientReceiveOnArtistAcceptance(
    campaignName: campaignName,
    orderRef: orderRef,
    artistName: artistName,
  );
}

bool shouldShowScenario42DirectArtistAfterPoolAcceptance({
  required String selectedArtistEmail,
  required String viewerArtistEmail,
}) {
  return shouldShowScenario41ToDirectArtist(
    clientAccepted: true,
    isDirectRequest: true,
    selectedArtistEmail: selectedArtistEmail,
    acceptedByArtistEmail: '',
    viewerArtistEmail: viewerArtistEmail,
  );
}

bool isScenario42SingleOrder(RequestOrderTypeV2 orderType) {
  return orderType == RequestOrderTypeV2.single;
}
