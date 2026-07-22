import 'package:flutter_test/flutter_test.dart';
import 'package:jewelnottool/utils/scenario_5_1.dart';

void main() {
  group('Scenario 5.1 UI rules', () {
    test(
      'brand can create Group Clients + Artist Pool request with 2 to 15 clients',
      () {
        expect(scenario51CanSubmitGroupOrder(2), isTrue);
        expect(scenario51CanSubmitGroupOrder(15), isTrue);
      },
    );

    test('brand cannot submit with fewer than 2 clients', () {
      expect(scenario51CanSubmitGroupOrder(0), isFalse);
      expect(scenario51CanSubmitGroupOrder(1), isFalse);
    });

    test('brand cannot select more than 15 clients', () {
      expect(scenario51CanSelectAnotherClient(14), isTrue);
      expect(scenario51CanSelectAnotherClient(15), isFalse);
    });

    test('one order number is created for all selected clients', () {
      expect(scenario51HasSingleOrderNumberForGroup(), isTrue);
    });

    test('request appears only for selected clients', () {
      expect(
        scenario51VisibleToSelectedClient(
          viewerEmail: 'a@demo.com',
          selectedGroupClientEmails: const <String>['a@demo.com', 'b@demo.com'],
          acceptedGroupClientEmails: const <String>[],
          declinedGroupClientEmails: const <String>[],
        ),
        isTrue,
      );
      expect(
        scenario51VisibleToSelectedClient(
          viewerEmail: 'x@demo.com',
          selectedGroupClientEmails: const <String>['a@demo.com', 'b@demo.com'],
          acceptedGroupClientEmails: const <String>[],
          declinedGroupClientEmails: const <String>[],
        ),
        isFalse,
      );
    });

    test(
      'each selected client can accept and artist pool hidden until all respond',
      () {
        expect(
          scenario51ArtistPoolCanSee(
            selectedGroupClientEmails: const <String>[
              'a@demo.com',
              'b@demo.com',
            ],
            acceptedGroupClientEmails: const <String>['a@demo.com'],
            declinedGroupClientEmails: const <String>[],
          ),
          isFalse,
        );
        expect(
          scenario51ArtistPoolCanSee(
            selectedGroupClientEmails: const <String>[
              'a@demo.com',
              'b@demo.com',
            ],
            acceptedGroupClientEmails: const <String>[
              'a@demo.com',
              'b@demo.com',
            ],
            declinedGroupClientEmails: const <String>[],
          ),
          isTrue,
        );
      },
    );

    test('statuses after transitions', () {
      expect(scenario51StatusesAfterBrandSubmit()['brandStatus'], 'pending');
      expect(scenario51StatusesAfterBrandSubmit()['clientStatus'], 'pending');
      expect(scenario51StatusesAfterBrandSubmit()['artistStatus'], 'pending');

      expect(
        scenario51StatusesAfterAllClientsAccepted()['artistStatus'],
        'in_review',
      );

      expect(
        scenario51StatusesAfterArtistAcceptance()['brandStatus'],
        'in_progress',
      );
      expect(
        scenario51StatusesAfterArtistAcceptance()['clientStatus'],
        'in_progress',
      );
      expect(
        scenario51StatusesAfterArtistAcceptance()['artistStatus'],
        'designing',
      );
    });

    test('artist pool acceptance is exclusive after one accepts', () {
      expect(
        scenario51ArtistPoolCanAccept(
          acceptedByArtistEmail: '',
          viewerArtistEmail: 'pool1@demo.com',
        ),
        isTrue,
      );
      expect(
        scenario51ArtistPoolCanAccept(
          acceptedByArtistEmail: 'pool1@demo.com',
          viewerArtistEmail: 'pool2@demo.com',
        ),
        isFalse,
      );
    });

    test('group client summary renders readable list', () {
      expect(
        scenario51ClientSummary(const <String>['Julie Molly', 'Karen Roach']),
        'Julie Molly, Karen Roach',
      );
    });

    test('notification messages match scenario 5.1', () {
      expect(
        scenario51ClientReceiveOnSubmit(
          orderRef: 'BE-51001',
          brandCompany: 'Merlin Fashion',
        ),
        'You have received the Brand request BE-51001 from Merlin Fashion. Please review and accept.',
      );

      expect(
        scenario51BrandReceiveOnClientAcceptance(
          clientName: 'Julie Molly',
          campaignName: 'Summer Drop',
          orderRef: 'BE-51001',
        ),
        'Julie Molly has accepted your Summer Drop brand request BE-51001',
      );

      expect(
        scenario51ArtistPoolReceiveAfterAllAccepted(
          orderRef: 'BE-51001',
          clientSummary: 'Julie Molly, Karen Roach',
          brandName: 'Merlin Fashion',
          campaignName: 'Summer Drop',
        ),
        'You have received a Brand request BE-51001 for Julie Molly, Karen Roach from Merlin Fashion Summer Drop',
      );

      expect(
        scenario51BrandReceiveOnArtistAcceptance(
          artistName: 'Noor',
          campaignName: 'Summer Drop',
          orderRef: 'BE-51001',
          clientSummary: 'Julie Molly, Karen Roach',
        ),
        'Noor has accepted your Summer Drop brand request BE-51001 for Julie Molly, Karen Roach',
      );

      expect(
        scenario51AcceptedClientReceiveOnArtistAcceptance(
          campaignName: 'Summer Drop',
          orderRef: 'BE-51001',
          artistName: 'Noor',
        ),
        'Your Summer Drop Brand request BE-51001 is accepted by Noor',
      );
    });
  });
}
