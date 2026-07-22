import 'package:flutter_test/flutter_test.dart';
import 'package:jewelnottool/models/client_request_v2.dart';
import 'package:jewelnottool/utils/scenario_4_5.dart';

void main() {
  group('Scenario 4.5 UI rules', () {
    test('brand can cancel before artist accepts and statuses become cancelled', () {
      final statuses = scenario45StatusesAfterBrandCancelBeforeArtistAccept();
      expect(statuses['brandStatus'], 'cancelled');
      expect(statuses['clientStatus'], 'cancelled');
      expect(statuses['artistStatus'], 'cancelled');
      expect(statuses['directClientStatus'], 'cancelled');
      expect(statuses['directArtistStatus'], 'cancelled');
    });

    test('cancellation reason is required', () {
      expect(scenario45CancellationReasonRequired(''), isFalse);
      expect(scenario45CancellationReasonRequired('   '), isFalse);
      expect(scenario45CancellationReasonRequired('Cancelled by Brand'), isTrue);
    });

    test('client and artist cannot act after cancellation', () {
      expect(scenario45ClientCanActAfterCancellation(), isFalse);
      expect(scenario45ArtistCanActAfterCancellation(), isFalse);
      expect(scenario45ArtistCanFinalizeAfterCancellation(), isFalse);
    });

    test('single-order only scope', () {
      expect(scenario45IsSingleOrderScope(RequestOrderTypeV2.single), isTrue);
      expect(scenario45IsSingleOrderScope(RequestOrderTypeV2.group), isFalse);
    });

    test('applicable request routing types match scenario list for single-order flow', () {
      expect(
        scenario45AppliesToRequestType(Scenario45RequestType.standard),
        isTrue,
      );
      expect(
        scenario45AppliesToRequestType(Scenario45RequestType.directToClient),
        isTrue,
      );
      expect(
        scenario45AppliesToRequestType(Scenario45RequestType.directToArtist),
        isTrue,
      );
      expect(
        scenario45AppliesToRequestType(
          Scenario45RequestType.directToBothClientAndArtist,
        ),
        isTrue,
      );
      expect(
        scenario45AppliesToRequestType(
          Scenario45RequestType.specificClientAndSpecificArtist,
        ),
        isTrue,
      );
      expect(
        scenario45AppliesToRequestType(Scenario45RequestType.clientGroupOrder),
        isFalse,
      );
      expect(
        scenario45AppliesToRequestType(
          Scenario45RequestType.clientGroupOrderWithDirectArtist,
        ),
        isFalse,
      );
    });

    test('notification messages match scenario 4.5 expected text', () {
      expect(
        scenario45ClientReceiveAfterBrandSubmit(
          orderRef: 'BE-45001',
          brandCompany: 'Merlin Fashion',
        ),
        'You have received the Brand request BE-45001 from Merlin Fashion. Please review and accept.',
      );
      expect(
        scenario45BrandReceiveAfterClientAcceptance(
          clientName: 'Taylor',
          campaignName: 'Summer Drop',
          orderRef: 'BE-45001',
        ),
        'Taylor has accepted your Summer Drop brand request BE-45001',
      );
      expect(
        scenario45DirectArtistReceiveAfterClientAcceptance(
          orderRef: 'BE-45001',
          clientName: 'Taylor',
          brandName: 'Merlin Fashion',
          campaignName: 'Summer Drop',
        ),
        'You have received a Brand request BE-45001 for Taylor from Merlin Fashion Summer Drop',
      );
      expect(
        scenario45BrandReceiveAfterBrandCancellation(
          brandCompany: 'Merlin Fashion',
          campaignName: 'Summer Drop',
          orderRef: 'BE-45001',
          reason: 'Cancelled by Brand',
        ),
        'Merlin Fashion cancelled your Summer Drop brand request BE-45001 Cancelled by Brand',
      );
      expect(
        scenario45DirectArtistReceiveAfterBrandCancellation(
          brandCompany: 'Merlin Fashion',
          campaignName: 'Summer Drop',
          orderRef: 'BE-45001',
          reason: 'Cancelled by Brand',
          clientName: 'Taylor',
        ),
        'Merlin Fashion cancelled Summer Drop brand request BE-45001 Cancelled by Brand for Taylor',
      );
      expect(
        scenario45AcceptedClientReceiveAfterBrandCancellation(
          brandName: 'Merlin Fashion',
          campaignName: 'Summer Drop',
          orderRef: 'BE-45001',
          reason: 'Cancelled by Brand',
        ),
        'Your Merlin Fashion Summer Drop brand request BE-45001 has been cancelled Cancelled by Brand',
      );
    });
  });
}
