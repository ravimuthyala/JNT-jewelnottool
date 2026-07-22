import 'package:flutter_test/flutter_test.dart';
import 'package:jewelnottool/utils/scenario_6_5.dart';

void main() {
  group('Scenario 6.5 UI rules', () {
    test('rejected client shows declined in client orders', () {
      expect(
        scenario65ClientOrderStatusForViewer(
          viewerEmail: 'reject@demo.com',
          selectedGroupClientEmails: const <String>[
            'accept@demo.com',
            'reject@demo.com',
          ],
          acceptedGroupClientEmails: const <String>['accept@demo.com'],
          declinedGroupClientEmails: const <String>['reject@demo.com'],
        ),
        'declined',
      );
    });

    test('only accepted clients are visible to the artist', () {
      expect(
        scenario65ArtistVisibleClientEmails(
          selectedGroupClientEmails: const <String>[
            'accept@demo.com',
            'reject@demo.com',
          ],
          acceptedGroupClientEmails: const <String>['accept@demo.com'],
          declinedGroupClientEmails: const <String>['reject@demo.com'],
        ),
        const <String>['accept@demo.com'],
      );
    });
  });
}
