import 'package:flutter_test/flutter_test.dart';
import 'package:pathlume/models/ar_pose.dart';
import 'package:pathlume/models/destination.dart';
import 'package:pathlume/models/floor.dart';
import 'package:pathlume/models/floor_origin.dart';
import 'package:pathlume/models/navigation_edge.dart';
import 'package:pathlume/models/navigation_graph.dart';
import 'package:pathlume/models/navigation_node.dart';
import 'package:pathlume/models/qr_payload.dart';
import 'package:pathlume/navigation_core/graph_validator.dart';
import 'package:pathlume/services/repositories/firebase_building_repository.dart';
import 'package:pathlume/services/repositories/local_building_repository.dart';

void main() {
  group('Cloud QR + Path Storage & Retrieval Unit & Integration Tests', () {
    late LocalBuildingRepository localRepo;
    late FirebaseBuildingRepository firebaseRepo;

    setUp(() {
      localRepo = LocalBuildingRepository();
      firebaseRepo = FirebaseBuildingRepository(localFallback: localRepo);
    });

    test('QR Payload parsing extracts buildingId, floorId, originId', () {
      const payloadStr = 'PATHLUME_V1|B001|F001|O001';
      final parsed = QRPayload.deserialize(payloadStr);

      expect(parsed, isNotNull);
      expect(parsed!.buildingId, 'B001');
      expect(parsed.floorId, 'F001');
      expect(parsed.originId, 'O001');
      expect(parsed.serialize(), payloadStr);
    });

    test('Firestore serialization and deserialization round-trip', () {
      final origin = FloorOrigin(
        originId: 'O001',
        floorId: 'F001',
        position: const Vector3D(x: 0, y: 0, z: 0),
        rotation: const Quaternion4D(),
        qrCodePayload: 'PATHLUME_V1|B001|F001|O001',
        createdAt: DateTime.utc(2026, 1, 1),
      );

      final nodes = [
        const NavigationNode(nodeId: 'n0', floorId: 'F001', type: NodeType.start, position: Vector3D(x: 0, y: 0, z: 0), name: 'Origin Node 0'),
        const NavigationNode(nodeId: 'n1', floorId: 'F001', type: NodeType.waypoint, position: Vector3D(x: 2, y: 0, z: 0), name: 'Waypoint 1'),
        const NavigationNode(nodeId: 'n2', floorId: 'F001', type: NodeType.destination, position: Vector3D(x: 5, y: 0, z: 0), name: 'Reception'),
      ];

      final edges = [
        const NavigationEdge(edgeId: 'e0_1', fromNodeId: 'n0', toNodeId: 'n1', distance: 2.0),
        const NavigationEdge(edgeId: 'e1_2', fromNodeId: 'n1', toNodeId: 'n2', distance: 3.0),
      ];

      final destinations = [
        const Destination(destinationId: 'd1', nodeId: 'n2', name: 'Reception', category: 'ROOM'),
      ];

      final originalFloor = Floor(
        floorId: 'F001',
        buildingId: 'B001',
        floorNumber: 1,
        name: 'Ground Floor',
        origin: origin,
        nodes: nodes,
        edges: edges,
        destinations: destinations,
        registrationStatus: 'ready',
        version: 1,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      final jsonMap = originalFloor.toJson();

      expect(jsonMap['buildingId'], 'B001');
      expect(jsonMap['floorId'], 'F001');
      expect(jsonMap['originId'], 'O001');
      expect(jsonMap['qrPayload'], 'PATHLUME_V1|B001|F001|O001');
      expect(jsonMap['status'], 'READY');
      expect(jsonMap['graphVersion'], 1);
      expect((jsonMap['nodes'] as List).length, 3);
      expect((jsonMap['edges'] as List).length, 2);
      expect((jsonMap['destinations'] as List).length, 1);

      final reconstructedFloor = Floor.fromJson(jsonMap);

      expect(reconstructedFloor.buildingId, 'B001');
      expect(reconstructedFloor.floorId, 'F001');
      expect(reconstructedFloor.originId, 'O001');
      expect(reconstructedFloor.qrPayload, 'PATHLUME_V1|B001|F001|O001');
      expect(reconstructedFloor.nodes.length, 3);
      expect(reconstructedFloor.edges.length, 2);
      expect(reconstructedFloor.destinations.length, 1);
      expect(reconstructedFloor.destinations.first.name, 'Reception');
    });

    test('NavigationGraph round-trip serialization', () {
      final nodes = [
        const NavigationNode(nodeId: 'n0', floorId: 'F001', type: NodeType.start, position: Vector3D(x: 0, y: 0, z: 0), name: 'Start'),
        const NavigationNode(nodeId: 'n1', floorId: 'F001', type: NodeType.destination, position: Vector3D(x: 3, y: 0, z: 0), name: 'End'),
      ];
      final edges = [
        const NavigationEdge(edgeId: 'e0_1', fromNodeId: 'n0', toNodeId: 'n1', distance: 3.0),
      ];

      final graph = NavigationGraph(floorId: 'F001', nodes: nodes, edges: edges);
      final jsonMap = graph.toJson();

      final reconstructedGraph = NavigationGraph.fromJson(jsonMap);
      expect(reconstructedGraph.floorId, 'F001');
      expect(reconstructedGraph.nodes.length, 2);
      expect(reconstructedGraph.edges.length, 1);
    });

    test('QR → Firestore lookup returns saved floor route', () async {
      const payloadStr = 'PATHLUME_V1|B001|F001|O001';
      final origin = FloorOrigin(
        originId: 'O001',
        floorId: 'F001',
        position: const Vector3D(),
        rotation: const Quaternion4D(),
        qrCodePayload: payloadStr,
        createdAt: DateTime.now(),
      );

      final floor = Floor(
        floorId: 'F001',
        buildingId: 'B001',
        floorNumber: 1,
        name: 'Main Hall Floor',
        origin: origin,
        nodes: const [
          NavigationNode(nodeId: 'n0', floorId: 'F001', type: NodeType.start, position: Vector3D(x: 0, y: 0, z: 0), name: 'Node 0'),
          NavigationNode(nodeId: 'n1', floorId: 'F001', type: NodeType.destination, position: Vector3D(x: 1, y: 0, z: 0), name: 'Lab 101'),
        ],
        edges: const [
          NavigationEdge(edgeId: 'e0_1', fromNodeId: 'n0', toNodeId: 'n1', distance: 1.0),
        ],
        destinations: const [
          Destination(destinationId: 'd1', nodeId: 'n1', name: 'Lab 101', category: 'LAB'),
        ],
        registrationStatus: 'ready',
      );

      await firebaseRepo.saveFloor(floor);

      final fetchedFloor = await firebaseRepo.getFloorByQrPayload(payloadStr);

      expect(fetchedFloor, isNotNull);
      expect(fetchedFloor!.buildingId, 'B001');
      expect(fetchedFloor.floorId, 'F001');
      expect(fetchedFloor.originId, 'O001');
      expect(fetchedFloor.destinations.length, 1);
    });

    test('Missing document returns null', () async {
      const payloadStr = 'PATHLUME_V1|B999|F999|O999';
      final fetchedFloor = await firebaseRepo.getFloorByQrPayload(payloadStr);
      expect(fetchedFloor, isNull);
    });

    test('Invalid QR string returns null', () async {
      final fetchedFloor = await firebaseRepo.getFloorByQrPayload('INVALID_STRING_XYZ');
      expect(fetchedFloor, isNull);
    });

    test('QR payload lookup matches buildingId and floorId even if originId differs', () async {
      const validPayloadStr = 'PATHLUME_V1|B001|F001|O001';
      final origin = FloorOrigin(
        originId: 'O001',
        floorId: 'F001',
        position: const Vector3D(),
        rotation: const Quaternion4D(),
        qrCodePayload: validPayloadStr,
        createdAt: DateTime.now(),
      );

      final floor = Floor(
        floorId: 'F001',
        buildingId: 'B001',
        floorNumber: 1,
        name: 'Ground Floor',
        origin: origin,
        nodes: const [NavigationNode(nodeId: 'n0', floorId: 'F001', type: NodeType.start, position: Vector3D(), name: 'N0')],
        registrationStatus: 'ready',
      );

      await firebaseRepo.saveFloor(floor);

      // Attempt lookup with mismatching originId (O999 instead of O001)
      const mismatchPayloadStr = 'PATHLUME_V1|B001|F001|O999';
      final fetchedFloor = await firebaseRepo.getFloorByQrPayload(mismatchPayloadStr);

      expect(fetchedFloor, isNotNull);
      expect(fetchedFloor!.floorId, 'F001');
    });

    test('GraphValidator validates downloaded cloud graph', () async {
      final validator = GraphValidator();

      const validGraph = NavigationGraph(
        floorId: 'F001',
        nodes: [
          NavigationNode(nodeId: 'n0', floorId: 'F001', type: NodeType.start, position: Vector3D(x: 0, y: 0, z: 0), name: 'Start'),
          NavigationNode(nodeId: 'n1', floorId: 'F001', type: NodeType.destination, position: Vector3D(x: 4, y: 0, z: 0), name: 'Office'),
        ],
        edges: [
          NavigationEdge(edgeId: 'e0_1', fromNodeId: 'n0', toNodeId: 'n1', distance: 4.0),
        ],
      );

      final validResult = validator.validateGraph(validGraph, destinations: [
        const Destination(destinationId: 'd1', nodeId: 'n1', name: 'Office', category: 'OFFICE'),
      ]);

      expect(validResult.isValid, isTrue);

      const orphanGraph = NavigationGraph(
        floorId: 'F001',
        nodes: [
          NavigationNode(nodeId: 'n0', floorId: 'F001', type: NodeType.start, position: Vector3D(x: 0, y: 0, z: 0), name: 'Start'),
          NavigationNode(nodeId: 'n1', floorId: 'F001', type: NodeType.waypoint, position: Vector3D(x: 10, y: 0, z: 0), name: 'Disconnected'),
        ],
        edges: [],
      );


      final invalidResult = validator.validateGraph(orphanGraph);
      expect(invalidResult.isValid, isFalse);
    });

    test('Destination retrieval comes directly from stored floor', () async {
      const payloadStr = 'PATHLUME_V1|B002|F002|O002';
      final floor = Floor(
        floorId: 'F002',
        buildingId: 'B002',
        floorNumber: 2,
        name: 'Second Floor',
        origin: FloorOrigin(
          originId: 'O002',
          floorId: 'F002',
          position: const Vector3D(),
          rotation: const Quaternion4D(),
          qrCodePayload: payloadStr,
          createdAt: DateTime.now(),
        ),
        destinations: const [
          Destination(destinationId: 'dest_library', nodeId: 'n_lib', name: 'Library', category: 'ROOM'),
          Destination(destinationId: 'dest_lab', nodeId: 'n_lab', name: 'Robotics Lab', category: 'LAB'),
        ],
      );

      await firebaseRepo.saveFloor(floor);

      final fetchedDests = await firebaseRepo.getDestinations('B002', 'F002');

      expect(fetchedDests.length, 2);
      expect(fetchedDests.map((d) => d.name), containsAll(['Library', 'Robotics Lab']));
    });
  });
}


