import 'package:flutter_test/flutter_test.dart';
import 'package:pathlume/models/qr_payload.dart';

void main() {
  group('QRPayload Tests', () {
    test('Serialize and deserialize PATHLUME_V1 pipe-delimited payload', () {
      const payload = QRPayload(
        buildingId: 'bld_eng_01',
        floorId: 'flr_02',
        originId: 'orig_main_desk',
        timestamp: 1600000000,
      );

      final rawString = payload.serialize();
      expect(rawString, 'PATHLUME_V1|bld_eng_01|flr_02|orig_main_desk');

      final deserialized = QRPayload.deserialize(rawString);
      expect(deserialized, isNotNull);
      expect(deserialized!.buildingId, 'bld_eng_01');
      expect(deserialized.floorId, 'flr_02');
      expect(deserialized.originId, 'orig_main_desk');
    });

    test('Deserialize legacy colon-delimited QR payload', () {
      const rawString = 'PATHLUME:bld_eng_01:flr_02:orig_main_desk:1600000000';
      final deserialized = QRPayload.deserialize(rawString);

      expect(deserialized, isNotNull);
      expect(deserialized!.buildingId, 'bld_eng_01');
      expect(deserialized.floorId, 'flr_02');
      expect(deserialized.originId, 'orig_main_desk');
      expect(deserialized.timestamp, 1600000000);
    });

    test('Deserialize URI standard format', () {
      const rawUri = 'pathlume://site/bld_eng_01/floor/flr_02/qr/orig_main_desk';
      final deserialized = QRPayload.deserialize(rawUri);

      expect(deserialized, isNotNull);
      expect(deserialized!.buildingId, 'bld_eng_01');
      expect(deserialized.floorId, 'flr_02');
      expect(deserialized.originId, 'orig_main_desk');
    });

    test('Deserialize invalid string returns null', () {
      expect(QRPayload.deserialize('INVALID_FORMAT'), isNull);
      expect(QRPayload.deserialize('pathlume://invalid'), isNull);
    });
  });
}
