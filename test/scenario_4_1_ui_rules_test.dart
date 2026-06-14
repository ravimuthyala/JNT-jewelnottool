import 'package:flutter_test/flutter_test.dart';
import 'package:jnt_app_0120/models/client_request_v2.dart';
import 'package:jnt_app_0120/utils/scenario_4_1.dart';

void main() {
  group('Scenario 4.1 UI rules', () {
    test('brand can create request with Specific Client + Specific Artist defaults', () {
      final statuses = scenario41StatusesAfterBrandSubmit();
      expect(statuses['brandStatus'], 'pending');
      expect(statuses['clientStatus'], 'pending');
      expect(statuses['artistStatus'], 'pending');
    });

    test('direct client request tab shows request only for selected client', () {
      expect(
        shouldShowScenario41ToDirectClient(
          openToClientPool: false,
          orderType: RequestOrderTypeV2.single,
          selectedClientEmail: 'direct.client@demo.com',
          selectedGroupClientEmails: const <String>[],
          viewerEmail: 'direct.client@demo.com',
        ),
        isTrue,
      );
      expect(
        shouldShowScenario41ToDirectClient(
          openToClientPool: false,
          orderType: RequestOrderTypeV2.single,
          selectedClientEmail: 'direct.client@demo.com',
          selectedGroupClientEmails: const <String>[],
          viewerEmail: 'other.client@demo.com',
        ),
        isFalse,
      );
    });

    test('after client acceptance only selected direct artist can see the request', () {
      expect(
        shouldShowScenario41ToDirectArtist(
          clientAccepted: true,
          isDirectRequest: true,
          selectedArtistEmail: 'artist.selected@demo.com',
          acceptedByArtistEmail: '',
          viewerArtistEmail: 'artist.selected@demo.com',
        ),
        isTrue,
      );
      expect(
        shouldShowScenario41ToDirectArtist(
          clientAccepted: true,
          isDirectRequest: true,
          selectedArtistEmail: 'artist.selected@demo.com',
          acceptedByArtistEmail: '',
          viewerArtistEmail: 'artist.other@demo.com',
        ),
        isFalse,
      );
    });

    test('once direct artist accepts, request remains assigned only to accepted artist', () {
      expect(
        shouldShowScenario41ToDirectArtist(
          clientAccepted: true,
          isDirectRequest: true,
          selectedArtistEmail: 'artist.selected@demo.com',
          acceptedByArtistEmail: 'artist.selected@demo.com',
          viewerArtistEmail: 'artist.selected@demo.com',
        ),
        isTrue,
      );
      expect(
        shouldShowScenario41ToDirectArtist(
          clientAccepted: true,
          isDirectRequest: true,
          selectedArtistEmail: 'artist.selected@demo.com',
          acceptedByArtistEmail: 'artist.selected@demo.com',
          viewerArtistEmail: 'artist.pool@demo.com',
        ),
        isFalse,
      );
    });

    test('statuses update after client acceptance', () {
      final statuses = scenario41StatusesAfterClientAcceptance();
      expect(statuses['brandStatus'], 'pending');
      expect(statuses['clientStatus'], 'pending');
      expect(statuses['artistStatus'], 'in_review');
    });

    test('statuses update after artist acceptance and amount finalization stage', () {
      final statuses = scenario41StatusesAfterArtistAcceptance();
      expect(statuses['brandStatus'], 'in_progress');
      expect(statuses['clientStatus'], 'in_progress');
      expect(statuses['artistStatus'], 'designing');
    });

    test('notification messages match scenario text', () {
      expect(
        scenario41ClientReceiveOnSubmit(
          orderRef: 'BE-41001',
          brandCompany: 'ACME',
          campaignName: 'Summer Drop',
        ),
        'You have received the Brand request BE-41001 from ACME Summer Drop. Please review and accept.',
      );

      expect(
        scenario41BrandReceiveOnClientAcceptance(
          clientName: 'Taylor',
          campaignName: 'Summer Drop',
          orderRef: 'BE-41001',
        ),
        'Taylor has accepted your Summer Drop brand request BE-41001',
      );

      expect(
        scenario41DirectArtistReceiveOnClientAcceptance(
          orderRef: 'BE-41001',
          clientName: 'Taylor',
          brandName: 'ACME',
          campaignName: 'Summer Drop',
        ),
        'You have received a Brand request BE-41001 for Taylor from ACME Summer Drop',
      );

      expect(
        scenario41BrandReceiveOnArtistAcceptance(
          artistName: 'Mia',
          campaignName: 'Summer Drop',
          orderRef: 'BE-41001',
          clientName: 'Taylor',
        ),
        'Mia has accepted your Summer Drop brand request BE-41001 for Taylor',
      );

      expect(
        scenario41DirectClientReceiveOnArtistAcceptance(
          campaignName: 'Summer Drop',
          orderRef: 'BE-41001',
          artistName: 'Mia',
        ),
        'Your Summer Drop Brand request BE-41001 is accepted by Mia',
      );
    });
  });
}
