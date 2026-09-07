import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathlume/models/building.dart';
import 'package:pathlume/models/floor.dart';
import 'package:pathlume/services/repositories/local_building_repository.dart';

void main() {
  group('BuildingRepository Tests', () {
    late Directory tempDir;
    late LocalBuildingRepository repository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('pathlume_test_repo');
      repository = LocalBuildingRepository(overrideDirectory: tempDir);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Save and retrieve building and floors', () async {
      const building = Building(
        buildingId: 'b_001',
        name: 'College Main Building',
        address: '123 University Campus',
      );

      await repository.saveBuilding(building);

      final fetched = await repository.getBuildingById('b_001');
      expect(fetched, isNotNull);
      expect(fetched!.name, equals('College Main Building'));

      const floor = Floor(
        floorId: 'f_001',
        buildingId: 'b_001',
        floorNumber: 0,
        name: 'Ground Floor',
      );

      await repository.saveFloor(floor);

      final floors = await repository.getFloorsForBuilding('b_001');
      expect(floors.length, equals(1));
      expect(floors.first.name, equals('Ground Floor'));
    });
  });
}
