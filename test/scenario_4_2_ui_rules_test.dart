import 'package:flutter_test/flutter_test.dart';
import 'package:jewelnottool/models/client_request_v2.dart';
import 'package:jewelnottool/utils/scenario_4_1.dart';
import 'package:jewelnottool/utils/scenario_4_2.dart';

void main() {
  group('Scenario 4.2 UI rules', () {
    test('brand can create request with Specific Client + Specific Artist', () {
      final statuses = scenario42StatusesAfterBrandSubmit();
      expect(statuses['brandStatus'], 'pending');
      expect(statuses['clientStatus'], 'pending');
      expect(statuses['artistStatus'], 'pending');
      expect(isScenario42SingleOrder(RequestOrderTypeV2.single), isTrue);
    });

    test('request appears only for selected direct client after brand submit', () {
      expect(
        shouldShowScenario41ToDirectClient(
          openToClientPool: false,
          orderType: RequestOrderTypeV2.single,
          selectedClientEmail: 'direct@demo.com',
          selectedGroupClientEmails: const <String>[],
          viewerEmail: 'direct@demo.com',
        ),
        isTrue,
      );
      expect(
        shouldShowScenario41ToDirectClient(
          openToClientPool: false,
          orderType: RequestOrderTypeV2.single,
          selectedClientEmail: 'direct@demo.com',
          selectedGroupClientEmails: const <String>[],
          viewerEmail: 'other@demo.com',
        ),
        isFalse,
      );
    });

    test('direct client decline updates statuses and moves request to client pool', () {
      final statuses = scenario42StatusesAfterDirectClientDecline();
      expect(statuses['brandStatus'], 'pending');
      expect(statuses['directClientStatus'], 'declined');
      expect(statuses['clientPoolStatus'], 'pending');

      expect(
        shouldShowScenario42ToPoolClient(
          openToClientPool: true,
          viewerEmail: 'pool1@demo.com',
          declinedByClientEmails: const <String>['direct@demo.com'],
          acceptedByClientEmail: '',
        ),
        isTrue,
      );
      expect(
        shouldShowScenario42ToPoolClient(
          openToClientPool: true,
          viewerEmail: 'direct@demo.com',
          declinedByClientEmails: const <String>['direct@demo.com'],
          acceptedByClientEmail: '',
        ),
        isFalse,
      );
    });

    test('one pool client can accept and request is removed for other pool clients', () {
      expect(
        shouldShowScenario42ToPoolClient(
          openToClientPool: true,
          viewerEmail: 'pool2@demo.com',
          declinedByClientEmails: const <String>['direct@demo.com'],
          acceptedByClientEmail: 'pool1@demo.com',
        ),
        isFalse,
      );

      final statuses = scenario42StatusesAfterPoolClientAcceptance();
      expect(statuses['brandStatus'], 'pending');
      expect(statuses['clientStatus'], 'pending');
      expect(statuses['artistStatus'], 'in_review');
    });

    test('only selected direct artist can see after pool client acceptance', () {
      expect(
        shouldShowScenario42DirectArtistAfterPoolAcceptance(
          selectedArtistEmail: 'artist@demo.com',
          viewerArtistEmail: 'artist@demo.com',
        ),
        isTrue,
      );
      expect(
        shouldShowScenario42DirectArtistAfterPoolAcceptance(
          selectedArtistEmail: 'artist@demo.com',
          viewerArtistEmail: 'other@demo.com',
        ),
        isFalse,
      );
    });

    test('artist acceptance transitions statuses to in-progress/designing', () {
      final statuses = scenario42StatusesAfterArtistAcceptance();
      expect(statuses['brandStatus'], 'in_progress');
      expect(statuses['clientStatus'], 'in_progress');
      expect(statuses['artistStatus'], 'designing');
    });

    test('notification messages match scenario 4.2 text', () {
      expect(
        scenario42ClientReceiveOnSubmit(
          orderRef: 'BE-42001',
          brandCompany: 'ACME',
          campaignName: 'Summer Drop',
        ),
        'You have received the Brand request BE-42001 from ACME Summer Drop. Please review and accept.',
      );
      expect(
        scenario42BrandReceiveOnPoolClientAcceptance(
          clientName: 'Taylor',
          campaignName: 'Summer Drop',
          orderRef: 'BE-42001',
        ),
        'Taylor has accepted your Summer Drop brand request BE-42001',
      );
      expect(
        scenario42DirectArtistReceiveOnPoolClientAcceptance(
          orderRef: 'BE-42001',
          clientName: 'Taylor',
          brandName: 'ACME',
          campaignName: 'Summer Drop',
        ),
        'You have received a Brand request BE-42001 for Taylor from ACME Summer Drop',
      );
      expect(
        scenario42BrandReceiveOnArtistAcceptance(
          artistName: 'Mia',
          campaignName: 'Summer Drop',
          orderRef: 'BE-42001',
          clientName: 'Taylor',
        ),
        'Mia has accepted your Summer Drop brand request BE-42001 for Taylor',
      );
      expect(
        scenario42AcceptedClientReceiveOnArtistAcceptance(
          campaignName: 'Summer Drop',
          orderRef: 'BE-42001',
          artistName: 'Mia',
        ),
        'Your Summer Drop Brand request BE-42001 is accepted by Mia',
      );
    });
  });
}
