import 'package:flutter_test/flutter_test.dart';
import 'package:jnt_app_0120/pages/artist_requests_page_redesign.dart';
import 'package:jnt_app_0120/pages/brand_custom_request_page.dart';

void main() {
  group('Scenario 2.1 UI rules', () {
    test('artist dropdown eligibility uses Sponsorship Request status', () {
      expect(
        hasReachedSponsorshipRequestStatus(<String, dynamic>{
          'sponsorshipRequest': <String, dynamic>{'status': 'requested'},
        }),
        isTrue,
      );
      expect(
        hasReachedSponsorshipRequestStatus(<String, dynamic>{
          'sponsorshipStatus': 'Sponsorship Request',
        }),
        isTrue,
      );
      expect(
        hasReachedSponsorshipRequestStatus(<String, dynamic>{
          'sponsorshipRequest': <String, dynamic>{'status': 'ineligible'},
        }),
        isFalse,
      );
    });

    test('brand partner client detection', () {
      expect(
        isBrandPartnerClient(<String, dynamic>{
          'ascension': <String, dynamic>{'status': 'brand_partner'},
        }),
        isTrue,
      );
      expect(
        isBrandPartnerClient(<String, dynamic>{
          'accountTags': <String>['Brand Partner'],
        }),
        isTrue,
      );
      expect(
        isBrandPartnerClient(<String, dynamic>{
          'ascension': <String, dynamic>{'status': 'regular'},
          'accountTags': <String>['Member'],
        }),
        isFalse,
      );
    });

    test('only selected direct artist can see after client acceptance', () {
      expect(
        shouldShowScenario21ToArtist(
          clientAccepted: false,
          isDirectRequest: true,
          selectedArtistEmail: 'artist@demo.com',
          viewerArtistEmail: 'artist@demo.com',
        ),
        isFalse,
      );
      expect(
        shouldShowScenario21ToArtist(
          clientAccepted: true,
          isDirectRequest: true,
          selectedArtistEmail: 'artist@demo.com',
          viewerArtistEmail: 'other@demo.com',
        ),
        isFalse,
      );
      expect(
        shouldShowScenario21ToArtist(
          clientAccepted: true,
          isDirectRequest: true,
          selectedArtistEmail: 'artist@demo.com',
          viewerArtistEmail: 'artist@demo.com',
        ),
        isTrue,
      );
    });

    test('client notification message on brand submit matches scenario', () {
      final message = scenario21ClientReceiveOnSubmit(
        orderRef: 'BE-12345',
        brandCompany: 'ACME',
        campaignName: 'Summer Drop',
      );
      expect(
        message,
        'You have received the Brand request BE-12345 from ACME Summer Drop. Please review and accept.',
      );
    });
  });
}
