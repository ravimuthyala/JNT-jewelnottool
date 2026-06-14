import 'package:flutter_test/flutter_test.dart';
import 'package:jnt_app_0120/utils/scenario_6_1.dart';

void main() {
  group('Scenario 6.1 UI rules', () {
    test('brand can create Group Clients + Specific Artist request with 2 to 15 clients', () {
      expect(
        scenario61CanSubmitGroupOrder(
          selectedClientCount: 2,
          specificArtistSelected: true,
        ),
        isTrue,
      );
      expect(
        scenario61CanSubmitGroupOrder(
          selectedClientCount: 15,
          specificArtistSelected: true,
        ),
        isTrue,
      );
    });

    test('brand cannot submit with fewer than 2 clients', () {
      expect(
        scenario61CanSubmitGroupOrder(
          selectedClientCount: 1,
          specificArtistSelected: true,
        ),
        isFalse,
      );
    });

    test('brand cannot select more than 15 clients', () {
      expect(scenario61CanSelectAnotherClient(15), isFalse);
    });

    test('brand must select one specific artist', () {
      expect(
        scenario61CanSubmitGroupOrder(
          selectedClientCount: 3,
          specificArtistSelected: false,
        ),
        isFalse,
      );
    });

    test('one order number is created for all selected clients', () {
      expect(scenario61HasSingleOrderNumberForGroup(), isTrue);
    });

    test('direct artist cannot see until all selected clients respond', () {
      expect(
        scenario61DirectArtistCanSee(
          viewerArtistEmail: 'artist@demo.com',
          selectedArtistEmail: 'artist@demo.com',
          selectedGroupClientEmails: const <String>['a@demo.com', 'b@demo.com'],
          acceptedGroupClientEmails: const <String>['a@demo.com'],
          declinedGroupClientEmails: const <String>[],
        ),
        isFalse,
      );
    });

    test('only selected direct artist sees after all selected clients accept', () {
      expect(
        scenario61DirectArtistCanSee(
          viewerArtistEmail: 'artist@demo.com',
          selectedArtistEmail: 'artist@demo.com',
          selectedGroupClientEmails: const <String>['a@demo.com', 'b@demo.com'],
          acceptedGroupClientEmails: const <String>[
            'a@demo.com',
            'b@demo.com',
          ],
          declinedGroupClientEmails: const <String>[],
        ),
        isTrue,
      );
      expect(
        scenario61DirectArtistCanSee(
          viewerArtistEmail: 'other@demo.com',
          selectedArtistEmail: 'artist@demo.com',
          selectedGroupClientEmails: const <String>['a@demo.com', 'b@demo.com'],
          acceptedGroupClientEmails: const <String>[
            'a@demo.com',
            'b@demo.com',
          ],
          declinedGroupClientEmails: const <String>[],
        ),
        isFalse,
      );
    });

    test('direct artist acceptance is exclusive', () {
      expect(
        scenario61DirectArtistCanAccept(
          viewerArtistEmail: 'artist@demo.com',
          selectedArtistEmail: 'artist@demo.com',
          acceptedByArtistEmail: '',
        ),
        isTrue,
      );
      expect(
        scenario61DirectArtistCanAccept(
          viewerArtistEmail: 'artist@demo.com',
          selectedArtistEmail: 'artist@demo.com',
          acceptedByArtistEmail: 'artist@demo.com',
        ),
        isTrue,
      );
      expect(
        scenario61DirectArtistCanAccept(
          viewerArtistEmail: 'other@demo.com',
          selectedArtistEmail: 'artist@demo.com',
          acceptedByArtistEmail: 'artist@demo.com',
        ),
        isFalse,
      );
    });

    test('statuses update correctly', () {
      expect(scenario61StatusesAfterBrandSubmit()['brandStatus'], 'pending');
      expect(scenario61StatusesAfterAllClientsAccepted()['artistStatus'], 'in_review');
      expect(scenario61StatusesAfterArtistAcceptance()['brandStatus'], 'in_progress');
      expect(scenario61StatusesAfterArtistAcceptance()['clientStatus'], 'in_progress');
      expect(scenario61StatusesAfterArtistAcceptance()['artistStatus'], 'designing');
    });

    test('notification messages match scenario 6.1', () {
      expect(
        scenario61ClientReceiveOnSubmit(
          orderRef: 'BE-61001',
          brandCompany: 'Merlin Fashion',
        ),
        'You have received the Brand request BE-61001 from Merlin Fashion. Please review and accept.',
      );
      expect(
        scenario61BrandReceiveOnClientAcceptance(
          clientName: 'Julie Molly',
          campaignName: 'Summer Drop',
          orderRef: 'BE-61001',
        ),
        'Julie Molly has accepted your Summer Drop brand request BE-61001',
      );
      expect(
        scenario61DirectArtistReceiveAfterAllAccepted(
          orderRef: 'BE-61001',
          clientSummary: 'Julie Molly, Karen Roach',
          brandName: 'Merlin Fashion',
          campaignName: 'Summer Drop',
        ),
        'You have received a Brand request BE-61001 for Julie Molly, Karen Roach from Merlin Fashion Summer Drop',
      );
      expect(
        scenario61BrandReceiveOnArtistAcceptance(
          artistName: 'Noor',
          campaignName: 'Summer Drop',
          orderRef: 'BE-61001',
          clientSummary: 'Julie Molly, Karen Roach',
        ),
        'Noor has accepted your Summer Drop brand request BE-61001 for Julie Molly, Karen Roach',
      );
      expect(
        scenario61AcceptedClientReceiveOnArtistAcceptance(
          campaignName: 'Summer Drop',
          orderRef: 'BE-61001',
          artistName: 'Noor',
        ),
        'Your Summer Drop Brand request BE-61001 is accepted by Noor',
      );
    });
  });
}
