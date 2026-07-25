import 'package:flutter_test/flutter_test.dart';
import 'package:jewelnottool/services/ambassador_role_service.dart';

void main() {
  group('AmbassadorRoleService.isAmbassadorFromData', () {
    test('recognizes an admin-provided Brand Ambassador label', () {
      expect(
        AmbassadorRoleService.isAmbassadorFromData({
          'client': {'partnerStatus': 'Brand Ambassador'},
        }),
        isTrue,
      );
    });

    test('recognizes Ambassador account tags', () {
      expect(
        AmbassadorRoleService.isAmbassadorFromData({
          'ascension': {
            'tags': ['client', 'Ambassador'],
          },
        }),
        isTrue,
      );
    });

    test('recognizes map-based Ambassador tags written by admin tools', () {
      expect(
        AmbassadorRoleService.isAmbassadorFromData({
          'profile': {
            'accountTags': {'ambassador': true},
          },
        }),
        isTrue,
      );
    });

    test('does not treat Not Ambassador as Ambassador', () {
      expect(
        AmbassadorRoleService.isAmbassadorFromData({
          'profile': {'partner_status': 'Not Ambassador'},
        }),
        isFalse,
      );
    });
  });
}
