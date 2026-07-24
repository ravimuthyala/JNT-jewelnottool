import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jewelnottool/services/nail_measurement_service.dart';

void main() {
  test('isConfigured is false by default (feature flag off)', () {
    expect(NailMeasurementService.isConfigured, isFalse);
  });

  test('measureNailWidthMm returns null without calling the network when not configured', () {
    expect(
      NailMeasurementService.measureNailWidthMm(
        imageBytes: Uint8List.fromList([1, 2, 3]),
        hand: 'left',
        finger: 'thumb',
        coinName: 'US Penny (1¢)',
        coinDiameterMm: 19.05,
      ),
      completion(isNull),
    );
  });
}
