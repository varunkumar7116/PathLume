import 'package:flutter_test/flutter_test.dart';
import 'package:pathlume/models/ar_pose.dart';
import 'package:pathlume/models/building.dart';
import 'package:pathlume/models/floor.dart';
import 'package:pathlume/models/floor_origin.dart';
import 'package:pathlume/models/navigation_edge.dart';
import 'package:pathlume/models/navigation_graph.dart';
import 'package:pathlume/models/navigation_node.dart';
import 'package:pathlume/models/registration_state.dart';
import 'package:pathlume/navigation_core/a_star.dart';
import 'package:pathlume/navigation_core/graph_validator.dart';
import 'package:pathlume/navigation_core/registration_engine.dart';
import 'package:pathlume/services/localization/localization_service.dart';
import 'package:pathlume/services/navigation/navigation_service.dart';
import 'package:pathlume/services/qr/simulated_qr_localization_provider.dart';
import 'package:pathlume/services/repositories/local_building_repository.dart';
import 'package:pathlume/services/simulated_ar_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-End Registration -> Graph Validation -> Persistence -> Navigation Pipeline', () {
    late LocalBuildingRepository repository;
    const buildingId = 'bldg_e2e_001';
    const floorId = 'floor_e2e_001';

    setUp(() async {
      repository = LocalBuildingRepository();
    });

    test('Complete pipeline execution with deterministic graph', () async {
      // -----------------------------------------------------------------------
      // STEP 1: CREATE BUILDING & FLOOR
      // -----------------------------------------------------------------------
      const building = Building(
        buildingId: buildingId,
        name: 'Science Complex',
        address: '100 University Way',
      );
      await repository.saveBuilding(building);

      const initialFloor = Floor(
        floorId: floorId,
        buildingId: buildingId,
        floorNumber: 1,
        name: 'Level 1 Lab Floor',
        registrationStatus: 'draft',
      );
      await repository.saveFloor(initialFloor);

      // -----------------------------------------------------------------------
      // STEP 2: REGISTRATION ENGINE STATE MACHINE & NODE CAPTURE
      // -----------------------------------------------------------------------
      final engine = RegistrationEngine(
        minNodeSpacingMeters: 1.0,
      );

      engine.initializeRegistration(buildingId: buildingId, floorId: floorId);
      expect(engine.state, equals(RegistrationState.preparing));

      engine.updateTrackingState('INITIALIZING');
      expect(engine.state, equals(RegistrationState.trackingInitializing));

      engine.updateTrackingState('TRACKING');
      expect(engine.state, equals(RegistrationState.ready));

      // Node 0: START origin (0, 0, 0)
      engine.setStartPoint(
        const ARPose(position: Vector3D(x: 0, y: 0, z: 0)),
      );
      expect(engine.state, equals(RegistrationState.originSet));
      expect(engine.capturedNodes.length, equals(1));
      expect(engine.capturedNodes.first.type, equals(NodeType.start));

      engine.startWalking();
      expect(engine.state, equals(RegistrationState.registering));

      // Node 1: WAYPOINT at (0, 0, 5)
      final r1 = engine.addNode(
        position: const Vector3D(x: 0, y: 0, z: 5),
        type: NodeType.waypoint,
      );
      expect(r1.success, isTrue);

      // Node 2: TURN at (5, 0, 5)
      final r2 = engine.addNode(
        position: const Vector3D(x: 5, y: 0, z: 5),
        type: NodeType.turn,
      );
      expect(r2.success, isTrue);

      // Node 3: WAYPOINT at (5, 0, 10)
      final r3 = engine.addNode(
        position: const Vector3D(x: 5, y: 0, z: 10),
        type: NodeType.waypoint,
      );
      expect(r3.success, isTrue);

      // Node 4: DESTINATION "Room 101" at (5, 0, 15)
      final r4 = engine.markDestination(
        position: const Vector3D(x: 5, y: 0, z: 15),
        name: 'Room 101',
        category: 'Lab',
      );
      expect(r4.success, isTrue);

      final n1 = engine.capturedNodes[1];
      final n4 = engine.capturedNodes[4];

      // Add alternate longer branch for A* testing:
      // Node 5: WAYPOINT at (-10, 0, 15)
      final r5 = engine.addNode(
        position: const Vector3D(x: -10, y: 0, z: 15),
        type: NodeType.waypoint,
      );
      expect(r5.success, isTrue);

      // Node 6: WAYPOINT at (-10, 0, 5)
      final r6 = engine.addNode(
        position: const Vector3D(x: -10, y: 0, z: 5),
        type: NodeType.waypoint,
      );
      expect(r6.success, isTrue);

      // -----------------------------------------------------------------------
      // STEP 3: GRAPH VALIDATION & QUALITY METRICS
      // -----------------------------------------------------------------------
      final capturedGraph = engine.finishAndProcessGraph();
      expect(capturedGraph, isNotNull);
      expect(engine.state, equals(RegistrationState.completed));

      final validator = GraphValidator();
      final validationResult = validator.validateGraph(
        capturedGraph,
        destinations: engine.capturedDestinations,
      );

      expect(validationResult.isValid, isTrue, reason: validationResult.summaryText);
      expect(validationResult.errors, isEmpty);

      final metrics = engine.getQualityMetrics();
      expect(metrics.totalNodes, equals(7));
      expect(metrics.destinationCount, equals(1));
      expect(metrics.disconnectedNodeCount, equals(0));

      // -----------------------------------------------------------------------
      // STEP 4: PERSISTENCE (SAVE & LOAD RESTORATION)
      // -----------------------------------------------------------------------
      final originObj = engine.origin ??
          FloorOrigin(
            originId: 'orig_001',
            floorId: floorId,
            position: const Vector3D(x: 0, y: 0, z: 0),
            rotation: const Quaternion4D(w: 1, x: 0, y: 0, z: 0),
            qrCodePayload: 'PATHLUME_V1|$buildingId|$floorId|orig_001',
            createdAt: DateTime.now(),
          );

      final node1 = engine.capturedNodes[1];
      final node6 = engine.capturedNodes[6];
      final extraEdge = NavigationEdge(
        edgeId: 'edge_6_1',
        fromNodeId: node6.nodeId,
        toNodeId: node1.nodeId,
        distance: 10.0,
        accessible: true,
      );

      final allEdges = [...engine.capturedEdges, extraEdge];

      final savedFloor = Floor(
        floorId: floorId,
        buildingId: buildingId,
        floorNumber: 1,
        name: 'Level 1 Lab Floor',
        origin: originObj,
        nodes: engine.capturedNodes,
        edges: allEdges,
        destinations: engine.capturedDestinations,
        registrationStatus: 'ready',
        version: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.saveFloor(savedFloor);

      // Reload floor from repository
      final loadedFloor = await repository.getFloorById(buildingId, floorId);

      expect(loadedFloor, isNotNull);
      expect(loadedFloor!.isReady, isTrue);
      expect(loadedFloor.registrationStatus, equals('ready'));
      expect(loadedFloor.nodes.length, equals(7));
      expect(loadedFloor.edges.length, equals(allEdges.length));
      expect(loadedFloor.destinations.length, equals(1));
      expect(loadedFloor.destinations.first.name, equals('Room 101'));

      // Verify node IDs & positions survive persistence 100% identically
      for (int i = 0; i < engine.capturedNodes.length; i++) {
        final original = engine.capturedNodes[i];
        final reloaded = loadedFloor.nodes[i];
        expect(reloaded.nodeId, equals(original.nodeId));
        expect(reloaded.sequence, equals(original.sequence));
        expect(reloaded.type, equals(original.type));
        expect(reloaded.position.x, equals(original.position.x));
        expect(reloaded.position.y, equals(original.position.y));
        expect(reloaded.position.z, equals(original.position.z));
      }

      // -----------------------------------------------------------------------
      // STEP 5: A* ROUTING & SHORTEST PATH VERIFICATION
      // -----------------------------------------------------------------------
      final navGraph = NavigationGraph(
        floorId: floorId,
        nodes: loadedFloor.nodes,
        edges: loadedFloor.edges,
      );

      final n0 = engine.capturedNodes[0];
      final n2 = engine.capturedNodes[2];
      final n3 = engine.capturedNodes[3];

      final router = AStarPathfinder();
      final route = router.findPath(
        graph: navGraph,
        startNodeId: n0.nodeId,
        targetNodeId: n4.nodeId,
      );

      expect(route, isNotNull);
      // Path must choose: 0 -> 1 -> 2 -> 3 -> 4 (20m total length)
      // and NOT 0 -> 1 -> 5 -> 6 -> 4 (40m total length)
      final pathNodeIds = route!.pathNodes.map((n) => n.nodeId).toList();
      expect(
        pathNodeIds,
        equals([n0.nodeId, n1.nodeId, n2.nodeId, n3.nodeId, n4.nodeId]),
      );
      expect(route.totalDistance, equals(20.0));

      // -----------------------------------------------------------------------
      // STEP 6: SIMULATED NAVIGATION MOVEMENT & WAYPOINT ADVANCEMENT
      // -----------------------------------------------------------------------
      final simulatedAR = SimulatedARService();
      final qrProvider = SimulatedQRLocalizationProvider();
      final locService = LocalizationService(
        arService: simulatedAR,
        qrProvider: qrProvider,
        repository: repository,
      );

      final navService = NavigationService(
        localizationService: locService,
        repository: repository,
        arService: simulatedAR,
      );

      // Start localization session
      await locService.startLocalizationSession(
        buildingId: buildingId,
        floorId: floorId,
      );

      // Start navigation session to Destination
      final destId = loadedFloor.destinations.first.destinationId;
      final startNavSuccess = await navService.startNavigation(
        buildingId: buildingId,
        floorId: floorId,
        destinationId: destId,
      );

      expect(startNavSuccess, isTrue);
      expect(navService.activeRoute, isNotNull);
      expect(navService.activeRoute!.pathNodes.length, equals(5));

      navService.dispose();
      locService.dispose();
      simulatedAR.dispose();
    });
  });
}
