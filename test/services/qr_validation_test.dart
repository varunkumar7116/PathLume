import 'package:flutter_test/flutter_test.dart';
import 'package:pathlume/services/qr/qr_localization_provider.dart';

void main() {
  group('QR Validation Tests', () {
    late AndroidQRLocalizationProvider provider;

    setUp(() {
      provider = AndroidQRLocalizationProvider();
    });

    test('Validates and deserializes valid PATHLUME QR payload', () async {
      const validStr = 'PATHLUME:b_001:f_001:orig_001:1757000000000';
      final detection = await provider.parseRawString(validStr);

      expect(detection, isNotNull);
      expect(detection!.isValidPayload, isTrue);
      expect(detection.payload, isNotNull);
      expect(detection.payload!.buildingId, equals('b_001'));
      expect(detection.payload!.floorId, equals('f_001'));
      expect(detection.payload!.originId, equals('orig_001'));
    });

    test('Rejects malformed and invalid QR strings', () async {
      const invalidStr = 'INVALID_NON_PATHLUME_STRING';
      final detection = await provider.parseRawString(invalidStr);

      expect(detection, isNotNull);
      expect(detection!.isValidPayload, isFalse);
      expect(detection.payload, isNull);
    });
  });
}
