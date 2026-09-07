import 'package:flutter_test/flutter_test.dart';
import 'package:pathlume/models/ar_pose.dart';
import 'package:pathlume/models/building.dart';
import 'package:pathlume/models/destination.dart';
import 'package:pathlume/models/floor.dart';
import 'package:pathlume/models/floor_origin.dart';
import 'package:pathlume/models/navigation_edge.dart';
import 'package:pathlume/models/navigation_node.dart';
import 'package:pathlume/services/repositories/firebase_building_repository.dart';
import 'package:pathlume/services/repositories/local_building_repository.dart';

void main() {
  group('FirebaseBuildingRepository Tests', () {
    late FirebaseBuildingRepository repository;
    late LocalBuildingRepository localCache;

    setUp(() {
      localCache = LocalBuildingRepository();
      repository = FirebaseBuildingRepository(localFallback: localCache);
    });

    test('Save and load building through repository layer', () async {
      const b = Building(
        buildingId: 'b_fb_test',
        name: 'Firebase Test Building',
        address: '123 Cloud St',
      );

      await repository.saveBuilding(b);
      final retrieved = await repository.getBuildingById('b_fb_test');

      expect(retrieved, isNotNull);
      expect(retrieved!.name, equals('Firebase Test Building'));
    });

    test('Save floor with valid graph sets status ready and reconstructs exact coordinates', () async {
      const startNode = NavigationNode(
        nodeId: 'n0',
        floorId: 'flr_fb_01',
        type: NodeType.start,
        position: Vector3D(x: 0.0, y: 0.0, z: 0.0),
        sequence: 0,
        name: 'Start Origin',
      );

      const destNode = NavigationNode(
        nodeId: 'n1',
        floorId: 'flr_fb_01',
        type: NodeType.destination,
        position: Vector3D(x: 3.5, y: 0.0, z: -2.1),
        sequence: 1,
        name: 'Lab 1',
      );

      const edge = NavigationEdge(
        edgeId: 'e0_1',
        fromNodeId: 'n0',
        toNodeId: 'n1',
        distance: 4.08,
      );

      const dest = Destination(
        destinationId: 'd1',
        nodeId: 'n1',
        name: 'Lab 1',
        category: 'Lab',
      );

      final floor = Floor(
        floorId: 'flr_fb_01',
        buildingId: 'b_fb_test',
        floorNumber: 1,
        name: 'First Floor',
        nodes: const [startNode, destNode],
        edges: const [edge],
        destinations: const [dest],
        registrationStatus: 'ready',
        origin: FloorOrigin(
          originId: 'o1',
          floorId: 'flr_fb_01',
          position: const Vector3D(x: 0.0, y: 0.0, z: 0.0),
          rotation: const Quaternion4D(x: 0.0, y: 0.0, z: 0.0, w: 1.0),
          qrCodePayload: 'PATHLUME_V1|b_fb_test|flr_fb_01|o1',
          createdAt: DateTime.now(),
        ),
      );

      await repository.saveFloor(floor);

      final retrievedFloor = await repository.getFloorById('b_fb_test', 'flr_fb_01');
      expect(retrievedFloor, isNotNull);
      expect(retrievedFloor!.registrationStatus, equals('ready'));
      expect(retrievedFloor.nodes.length, equals(2));
      expect(retrievedFloor.nodes[1].position.x, equals(3.5));
      expect(retrievedFloor.nodes[1].position.z, equals(-2.1));
      expect(retrievedFloor.destinations.length, equals(1));
    });
  });
}
