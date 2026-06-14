import 'package:flutter_test/flutter_test.dart';
import 'package:jnt_app_0120/models/client_request_v2.dart';
import 'package:jnt_app_0120/pages/artist_requests_page_redesign.dart';
import 'package:jnt_app_0120/pages/client_requests_page.dart';
import 'package:jnt_app_0120/pages/company_custom_request_page.dart';

void main() {
  group('Scenario 3.1 UI rules', () {
    test('brand can configure Specific Client + Artist Pool message payload', () {
      final message = scenario21ClientReceiveOnSubmit(
        orderRef: 'BE-31001',
        brandCompany: 'ACME',
        campaignName: 'Summer Drop',
      );
      expect(
        message,
        'You have received the Brand request BE-31001 from ACME Summer Drop. Please review and accept.',
      );
    });

    test('request appears only for selected direct client before acceptance', () {
      expect(
        shouldShowScenario31ToDirectClient(
          openToClientPool: false,
          orderType: RequestOrderTypeV2.single,
          selectedClientEmail: 'direct@demo.com',
          selectedGroupClientEmails: const <String>[],
          viewerEmail: 'direct@demo.com',
        ),
        isTrue,
      );
      expect(
        shouldShowScenario31ToDirectClient(
          openToClientPool: false,
          orderType: RequestOrderTypeV2.single,
          selectedClientEmail: 'direct@demo.com',
          selectedGroupClientEmails: const <String>[],
          viewerEmail: 'other@demo.com',
        ),
        isFalse,
      );
    });

    test('artist pool can see request only after direct client acceptance', () {
      expect(
        shouldShowScenario31ToArtistPool(
          clientAccepted: false,
          requestStatus: 'pending',
          acceptedByArtistEmail: '',
          viewerArtistEmail: 'artist1@demo.com',
        ),
        isFalse,
      );
      expect(
        shouldShowScenario31ToArtistPool(
          clientAccepted: true,
          requestStatus: 'in_review',
          acceptedByArtistEmail: '',
          viewerArtistEmail: 'artist1@demo.com',
        ),
        isTrue,
      );
    });

    test('artist pool request is removed for others after one artist accepts', () {
      expect(
        shouldShowScenario31ToArtistPool(
          clientAccepted: true,
          requestStatus: 'designing',
          acceptedByArtistEmail: 'artist1@demo.com',
          viewerArtistEmail: 'artist2@demo.com',
        ),
        isFalse,
      );
      expect(
        shouldShowScenario31ToArtistPool(
          clientAccepted: true,
          requestStatus: 'designing',
          acceptedByArtistEmail: 'artist1@demo.com',
          viewerArtistEmail: 'artist1@demo.com',
        ),
        isTrue,
      );
    });

    test('brand receives client-acceptance notification message', () {
      final message = scenario31BrandReceiveOnClientAcceptance(
        clientName: 'Taylor',
        campaignName: 'Summer Drop',
        orderRef: 'BE-31001',
      );
      expect(
        message,
        'Taylor has accepted your Summer Drop brand request BE-31001',
      );
    });

    test('artist pool receives client-acceptance notification message', () {
      final message = scenario31ArtistPoolReceiveOnClientAcceptance(
        orderRef: 'BE-31001',
        clientName: 'Taylor',
        brandName: 'ACME',
        campaignName: 'Summer Drop',
      );
      expect(
        message,
        'You have received a Brand request BE-31001 for Taylor from ACME Summer Drop.',
      );
    });

    test('brand receives artist-acceptance notification message', () {
      final message = scenario31BrandReceiveOnArtistAcceptance(
        artistName: 'Mia',
        campaignName: 'Summer Drop',
        orderRef: 'BE-31001',
        clientName: 'Taylor',
      );
      expect(
        message,
        'Mia has accepted your Summer Drop brand request BE-31001 for Taylor.',
      );
    });

    test('direct client receives artist-acceptance notification message', () {
      final message = scenario31DirectClientReceiveOnArtistAcceptance(
        campaignName: 'Summer Drop',
        orderRef: 'BE-31001',
        artistName: 'Mia',
      );
      expect(
        message,
        'Your Summer Drop Brand request BE-31001 is accepted by Mia.',
      );
    });
  });
}

