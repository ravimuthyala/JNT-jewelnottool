import 'package:flutter_test/flutter_test.dart';
import 'package:jewelnottool/utils/scenario_6_7.dart';

void main() {
  group('Scenario 6.7 UI rules', () {
    test(
      'brand can create Group Clients + Direct Artist request with 2 to 15 clients',
      () {
        expect(
          scenario67CanSubmitGroupOrder(
            selectedClientCount: 2,
            specificArtistSelected: true,
          ),
          isTrue,
        );
        expect(
          scenario67CanSubmitGroupOrder(
            selectedClientCount: 15,
            specificArtistSelected: true,
          ),
          isTrue,
        );
      },
    );

    test('brand cannot submit with fewer than 2 clients', () {
      expect(
        scenario67CanSubmitGroupOrder(
          selectedClientCount: 1,
          specificArtistSelected: true,
        ),
        isFalse,
      );
    });

    test('brand must select one specific artist', () {
      expect(
        scenario67CanSubmitGroupOrder(
          selectedClientCount: 3,
          specificArtistSelected: false,
        ),
        isFalse,
      );
    });

    test('brand cannot select more than 15 clients', () {
      expect(scenario67CanSelectAnotherClient(15), isFalse);
    });

    test('one order number is created for all selected clients', () {
      expect(scenario67HasSingleOrderNumberForGroup(), isTrue);
      expect(scenario67RequestTypeLabel(), 'Direct');
      expect(
        scenario67ClientSummary(const <String>[
          'Ava',
          'Mia',
          'Noor',
          'Taylor',
          'Julie',
        ]),
        'Ava, Mia, Noor, Taylor, Julie',
      );
    });

    test('request appears only for selected clients after brand submit', () {
      expect(
        scenario67VisibleToSelectedClient(
          viewerEmail: 'a@demo.com',
          selectedGroupClientEmails: const <String>['a@demo.com', 'b@demo.com'],
          acceptedGroupClientEmails: const <String>[],
          declinedGroupClientEmails: const <String>[],
        ),
        isTrue,
      );
      expect(
        scenario67VisibleToSelectedClient(
          viewerEmail: 'x@demo.com',
          selectedGroupClientEmails: const <String>['a@demo.com', 'b@demo.com'],
          acceptedGroupClientEmails: const <String>[],
          declinedGroupClientEmails: const <String>[],
        ),
        isFalse,
      );
    });

    test(
      'request stays hidden from the direct artist until all clients respond',
      () {
        expect(
          scenario67DirectArtistCanSee(
            viewerArtistEmail: 'artist@demo.com',
            selectedArtistEmail: 'artist@demo.com',
            selectedGroupClientEmails: const <String>[
              'a@demo.com',
              'b@demo.com',
              'c@demo.com',
              'd@demo.com',
              'e@demo.com',
            ],
            acceptedGroupClientEmails: const <String>[
              'a@demo.com',
              'b@demo.com',
            ],
            declinedGroupClientEmails: const <String>['c@demo.com'],
          ),
          isFalse,
        );
      },
    );

    test('accepted clients move forward once all selected clients respond', () {
      expect(
        scenario67AllSelectedClientsResponded(
          selectedGroupClientEmails: const <String>[
            'a@demo.com',
            'b@demo.com',
            'c@demo.com',
            'd@demo.com',
            'e@demo.com',
          ],
          acceptedGroupClientEmails: const <String>['a@demo.com', 'b@demo.com'],
          declinedGroupClientEmails: const <String>[
            'c@demo.com',
            'd@demo.com',
            'e@demo.com',
          ],
        ),
        isTrue,
      );
      expect(
        scenario67DirectArtistCanSee(
          viewerArtistEmail: 'artist@demo.com',
          selectedArtistEmail: 'artist@demo.com',
          selectedGroupClientEmails: const <String>[
            'a@demo.com',
            'b@demo.com',
            'c@demo.com',
            'd@demo.com',
            'e@demo.com',
          ],
          acceptedGroupClientEmails: const <String>['a@demo.com', 'b@demo.com'],
          declinedGroupClientEmails: const <String>[
            'c@demo.com',
            'd@demo.com',
            'e@demo.com',
          ],
        ),
        isTrue,
      );
      expect(
        scenario67DirectArtistCanSeeOnlyAcceptedClients(
          selectedGroupClientEmails: const <String>[
            'a@demo.com',
            'b@demo.com',
            'c@demo.com',
            'd@demo.com',
            'e@demo.com',
          ],
          acceptedGroupClientEmails: const <String>['a@demo.com', 'b@demo.com'],
          declinedGroupClientEmails: const <String>[
            'c@demo.com',
            'd@demo.com',
            'e@demo.com',
          ],
        ),
        isTrue,
      );
    });

    test(
      'brand can cancel after all clients respond but before artist accepts',
      () {
        final statuses = scenario67StatusesAfterBrandCancelBeforeArtistAccept();
        expect(statuses['brandStatus'], 'cancelled');
        expect(statuses['acceptedClientStatus'], 'cancelled');
        expect(statuses['declinedClientStatus'], 'declined');
        expect(statuses['artistStatus'], 'cancelled');
        expect(scenario67ArtistCanActAfterBrandCancellation(), isFalse);
        expect(scenario67ClientCanActAfterBrandCancellation(), isFalse);
        expect(scenario67ArtistCanFinalizeAfterBrandCancellation(), isFalse);
      },
    );

    test('statuses update correctly through the flow', () {
      expect(scenario67StatusesAfterBrandSubmit()['brandStatus'], 'pending');
      expect(scenario67StatusesAfterBrandSubmit()['clientStatus'], 'pending');
      expect(scenario67StatusesAfterBrandSubmit()['artistStatus'], 'pending');

      expect(
        scenario67StatusesAfterPartialClientResponses()['brandStatus'],
        'pending',
      );
      expect(
        scenario67StatusesAfterPartialClientResponses()['acceptedClientStatus'],
        'pending',
      );
      expect(
        scenario67StatusesAfterPartialClientResponses()['declinedClientStatus'],
        'declined',
      );
      expect(
        scenario67StatusesAfterPartialClientResponses()['artistStatus'],
        'pending',
      );

      expect(
        scenario67StatusesAfterAllClientsResponded()['brandStatus'],
        'pending',
      );
      expect(
        scenario67StatusesAfterAllClientsResponded()['acceptedClientStatus'],
        'pending',
      );
      expect(
        scenario67StatusesAfterAllClientsResponded()['declinedClientStatus'],
        'declined',
      );
      expect(
        scenario67StatusesAfterAllClientsResponded()['artistStatus'],
        'in_review',
      );
    });

    test('brand cancellation notifies accepted and pending clients only', () {
      expect(
        scenario671BrandCancellationRecipients(
          selectedGroupClientEmails: const <String>[
            'a@demo.com',
            'b@demo.com',
            'c@demo.com',
          ],
          rejectedGroupClientEmails: const <String>['c@demo.com'],
        ),
        const <String>['a@demo.com', 'b@demo.com'],
      );
    });

    test('brand cancellation excludes rejected clients in mixed groups', () {
      expect(
        scenario671BrandCancellationRecipients(
          selectedGroupClientEmails: const <String>[
            'a@demo.com',
            'b@demo.com',
            'c@demo.com',
            'd@demo.com',
          ],
          rejectedGroupClientEmails: const <String>['b@demo.com', 'd@demo.com'],
        ),
        const <String>['a@demo.com', 'c@demo.com'],
      );
    });

    test('artist history stays scoped to the selected artist', () {
      expect(
        scenario671ArtistHistoryVisible(
          currentArtistEmail: 'artist@demo.com',
          selectedArtistEmail: 'artist@demo.com',
          acceptedByArtistEmail: '',
        ),
        isTrue,
      );
      expect(
        scenario671ArtistHistoryVisible(
          currentArtistEmail: 'other@demo.com',
          selectedArtistEmail: 'artist@demo.com',
          acceptedByArtistEmail: '',
        ),
        isFalse,
      );
    });

    test('client orders show brand cancellations as cancelled', () {
      expect(
        scenario671ClientOrderShowsCancelled(
          rawStatus: 'pending',
          cancelReason: 'Cancelled by Brand',
          cancelledAt: DateTime(2026, 6, 6),
        ),
        isTrue,
      );
    });

    test(
      'group clients see cancelled brand orders except rejected members',
      () {
        expect(
          scenario671GroupClientVisibleOnCancel(
            viewerEmail: 'emily.roy@demo.com',
            groupClientEmails: const <String>[
              'emily.roy@demo.com',
              'lily.joseph@demo.com',
            ],
            rejectedGroupClientEmails: const <String>[],
          ),
          isTrue,
        );
        expect(
          scenario671GroupClientVisibleOnCancel(
            viewerEmail: 'rejected@demo.com',
            groupClientEmails: const <String>[
              'emily.roy@demo.com',
              'rejected@demo.com',
            ],
            rejectedGroupClientEmails: const <String>['rejected@demo.com'],
          ),
          isFalse,
        );
      },
    );

    test('group client ids also match cancelled brand orders', () {
      expect(
        scenario671GroupClientVisibleByIdOnCancel(
          viewerEmail: 'emily.roy@demo.com',
          groupClientId: 'client-id-123',
          knownGroupClientIds: const <String>['client-id-123'],
        ),
        isTrue,
      );
    });

    test('notification messages match scenario 6.7', () {
      expect(
        scenario67ClientReceiveOnSubmit(
          orderRef: 'BE-67001',
          brandCompany: 'Merlin Fashion',
        ),
        'You have received the Brand request BE-67001 from Merlin Fashion. Please review and accept.',
      );
      expect(
        scenario67BrandReceiveOnClientAcceptance(
          clientName: 'Julie Molly',
          campaignName: 'Summer Drop',
          orderRef: 'BE-67001',
        ),
        'Julie Molly has accepted your Summer Drop brand request BE-67001',
      );
      expect(
        scenario67DirectArtistReceiveAfterAllResponses(
          orderRef: 'BE-67001',
          clientSummary: 'Julie Molly, Karen Roach',
          brandName: 'Merlin Fashion',
          campaignName: 'Summer Drop',
        ),
        'You have received a Brand request BE-67001 for Julie Molly, Karen Roach from Merlin Fashion Summer Drop',
      );
      expect(
        scenario67BrandReceiveAfterBrandCancellation(
          brandCompany: 'Merlin Fashion',
          campaignName: 'Summer Drop',
          orderRef: 'BE-67001',
          reason: 'Cancelled by Brand',
        ),
        '**Merlin Fashion** cancelled your Campaign: **Summer Drop** **BE-67001** **Cancelled by Brand**',
      );
      expect(
        scenario67DirectArtistReceiveAfterBrandCancellation(
          brandCompany: 'Merlin Fashion',
          campaignName: 'Summer Drop',
          orderRef: 'BE-67001',
          reason: 'Cancelled by Brand',
          clientSummary: 'Julie Molly, Karen Roach',
        ),
        '**Merlin Fashion** cancelled Campaign **Summer Drop** **BE-67001** **Cancelled by Brand** for **Julie Molly, Karen Roach**',
      );
      expect(
        scenario67AcceptedClientReceiveAfterBrandCancellation(
          brandName: 'Merlin Fashion',
          campaignName: 'Summer Drop',
          orderRef: 'BE-67001',
          reason: 'Cancelled by Brand',
        ),
        'Your Campaign **Summer Drop** **BE-67001** has been cancelled **Cancelled by Brand** by **Merlin Fashion**',
      );
    });
  });
}
