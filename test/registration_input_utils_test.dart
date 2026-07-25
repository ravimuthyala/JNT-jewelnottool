import 'package:flutter_test/flutter_test.dart';
import 'package:jewelnottool/utils/registration_input_utils.dart';

void main() {
  group('registration age eligibility', () {
    final today = DateTime(2026, 7, 24);

    test('allows a user on their fourteenth birthday', () {
      expect(
        RegistrationInputUtils.isEligibleByDateOfBirth(
          DateTime(2012, 7, 24),
          onDate: today,
        ),
        isTrue,
      );
    });

    test('blocks a user who is still thirteen', () {
      expect(
        RegistrationInputUtils.isEligibleByDateOfBirth(
          DateTime(2012, 7, 25),
          onDate: today,
        ),
        isFalse,
      );
    });

    test('blocks users younger than thirteen', () {
      expect(
        RegistrationInputUtils.isEligibleByDateOfBirth(
          DateTime(2015, 1, 1),
          onDate: today,
        ),
        isFalse,
      );
    });
  });
}
