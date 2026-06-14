import 'package:flutter_test/flutter_test.dart';
import 'package:jnt_app_0120/models/client_request_v2.dart';
import 'package:jnt_app_0120/utils/scenario_4_1.dart';
import 'package:jnt_app_0120/utils/scenario_4_2.dart';
import 'package:jnt_app_0120/utils/scenario_4_3.dart';

void main() {
  group('Scenario 4.3 UI rules', () {
    test('brand can create request with specific client + specific artist + fallback yes', () {
      final statuses = scenario43StatusesAfterBrandSubmit();
      expect(statuses['brandStatus'], 'pending');
      expect(statuses['clientStatus'], 'pending');
      expect(statuses['artistStatus'], 'pending');
      expect(isScenario43SingleOrder(RequestOrderTypeV2.single), isTrue);
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
          viewerEmail: 'pool@demo.com',
        ),
        isFalse,
      );
    });

    test('direct client decline sets direct status declined and opens client pool', () {
      final statuses = scenario43StatusesAfterDirectClientDecline();
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
    });

    test('one pool client can accept and request is removed from client pool', () {
      expect(
        shouldShowScenario42ToPoolClient(
          openToClientPool: true,
          viewerEmail: 'pool2@demo.com',
          declinedByClientEmails: const <String>['direct@demo.com'],
          acceptedByClientEmail: 'pool1@demo.com',
        ),
        isFalse,
      );
      final statuses = scenario43StatusesAfterPoolClientAcceptance();
      expect(statuses['brandStatus'], 'pending');
      expect(statuses['clientStatus'], 'pending');
      expect(statuses['directArtistStatus'], 'in_review');
    });

    test('only selected direct artist can see after pool client acceptance', () {
      expect(
        shouldShowScenario42DirectArtistAfterPoolAcceptance(
          selectedArtistEmail: 'directartist@demo.com',
          viewerArtistEmail: 'directartist@demo.com',
        ),
        isTrue,
      );
      expect(
        shouldShowScenario42DirectArtistAfterPoolAcceptance(
          selectedArtistEmail: 'directartist@demo.com',
          viewerArtistEmail: 'other@demo.com',
        ),
        isFalse,
      );
    });

    test('direct artist decline moves request to artist pool when fallback yes', () {
      final statuses = scenario43StatusesAfterDirectArtistDecline();
      expect(statuses['brandStatus'], 'pending');
      expect(statuses['clientStatus'], 'pending');
      expect(statuses['directArtistStatus'], 'declined');
      expect(statuses['artistPoolStatus'], 'in_review');

      expect(
        shouldShowScenario43ToArtistPool(
          isDirectRequest: false,
          fallbackToPool: true,
          declinedByArtistEmails: const <String>['directartist@demo.com'],
          acceptedByArtistEmail: '',
          viewerArtistEmail: 'poolartist@demo.com',
        ),
        isTrue,
      );
      expect(
        shouldShowScenario43ToArtistPool(
          isDirectRequest: false,
          fallbackToPool: true,
          declinedByArtistEmails: const <String>['directartist@demo.com'],
          acceptedByArtistEmail: '',
          viewerArtistEmail: 'directartist@demo.com',
        ),
        isFalse,
      );
    });

    test('one artist pool artist can accept + finalize and remove request from pool', () {
      expect(
        shouldShowScenario43ToArtistPool(
          isDirectRequest: false,
          fallbackToPool: true,
          declinedByArtistEmails: const <String>['directartist@demo.com'],
          acceptedByArtistEmail: 'poolartist@demo.com',
          viewerArtistEmail: 'otherpool@demo.com',
        ),
        isFalse,
      );
      final statuses = scenario43StatusesAfterArtistPoolAcceptance();
      expect(statuses['brandStatus'], 'in_progress');
      expect(statuses['clientStatus'], 'in_progress');
      expect(statuses['artistStatus'], 'designing');
    });

    test('notification messages match scenario 4.3 text', () {
      expect(
        scenario42ClientReceiveOnSubmit(
          orderRef: 'BE-43001',
          brandCompany: 'Merlin Fashion',
          campaignName: 'Summer Drop',
        ),
        'You have received the Brand request BE-43001 from Merlin Fashion Summer Drop. Please review and accept.',
      );
      expect(
        scenario42BrandReceiveOnPoolClientAcceptance(
          clientName: 'Ava',
          campaignName: 'Summer Drop',
          orderRef: 'BE-43001',
        ),
        'Ava has accepted your Summer Drop brand request BE-43001',
      );
      expect(
        scenario42DirectArtistReceiveOnPoolClientAcceptance(
          orderRef: 'BE-43001',
          clientName: 'Ava',
          brandName: 'Merlin Fashion',
          campaignName: 'Summer Drop',
        ),
        'You have received a Brand request BE-43001 for Ava from Merlin Fashion Summer Drop',
      );
      expect(
        scenario43BrandReceiveOnDirectArtistDecline(
          artistName: 'Mia',
          brandName: 'Merlin Fashion',
          campaignName: 'Summer Drop',
          orderRef: 'BE-43001',
          clientName: 'Ava',
        ),
        'Mia has denied Merlin Fashion Summer Drop brand request BE-43001 for Ava',
      );
      expect(
        scenario43ArtistPoolReceiveOnDirectArtistDecline(
          orderRef: 'BE-43001',
          clientName: 'Ava',
          brandName: 'Merlin Fashion',
          campaignName: 'Summer Drop',
        ),
        'You have received a Brand request BE-43001 for Ava from Merlin Fashion Summer Drop',
      );
      expect(
        scenario42BrandReceiveOnArtistAcceptance(
          artistName: 'Noor',
          campaignName: 'Summer Drop',
          orderRef: 'BE-43001',
          clientName: 'Ava',
        ),
        'Noor has accepted your Summer Drop brand request BE-43001 for Ava',
      );
      expect(
        scenario42AcceptedClientReceiveOnArtistAcceptance(
          campaignName: 'Summer Drop',
          orderRef: 'BE-43001',
          artistName: 'Noor',
        ),
        'Your Summer Drop Brand request BE-43001 is accepted by Noor',
      );
    });
  });
}
