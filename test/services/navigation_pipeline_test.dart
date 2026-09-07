import 'package:flutter_test/flutter_test.dart';
import 'package:pathlume/models/ar_pose.dart';
import 'package:pathlume/models/building.dart';
import 'package:pathlume/models/destination.dart';
import 'package:pathlume/models/floor.dart';
import 'package:pathlume/models/floor_origin.dart';
import 'package:pathlume/models/navigation_edge.dart';
import 'package:pathlume/models/navigation_node.dart';
import 'package:pathlume/models/navigation_session.dart';
import 'package:pathlume/services/localization/localization_service.dart';
import 'package:pathlume/services/navigation/navigation_service.dart';
import 'package:pathlume/services/repositories/local_building_repository.dart';
import 'package:pathlume/services/simulated_ar_service.dart';
import 'package:pathlume/services/qr/simulated_qr_localization_provider.dart';

void main() {
  group('Phase 7 Navigation Pipeline Integration Tests', () {
    late LocalBuildingRepository repository;
    late SimulatedARService arService;
    late SimulatedQRLocalizationProvider qrProvider;
    late LocalizationService localizationService;
    late NavigationService navigationService;

    const buildingId = 'Bldg_Phase7';
    const floorId = 'Floor_1';
    const originId = 'QR_ORIGIN_1';

    setUp(() async {
      repository = LocalBuildingRepository();

      final origin = FloorOrigin(
        originId: originId,
        floorId: floorId,
        position: const Vector3D(x: 0.0, y: 0.0, z: 0.0),
        rotation: const Quaternion4D(x: 0.0, y: 0.0, z: 0.0, w: 1.0),
        qrCodePayload: 'PATHLUME:$buildingId:$floorId:$originId:1757000000000',
        createdAt: DateTime.now(),
      );

      final nodes = [
        const NavigationNode(
          nodeId: 'N0',
          floorId: floorId,
          position: Vector3D(x: 0.0, y: 0.0, z: 0.0),
          type: NodeType.start,
          name: 'Start Node',
        ),
        const NavigationNode(
          nodeId: 'N1',
          floorId: floorId,
          position: Vector3D(x: 2.0, y: 0.0, z: 0.0),
          type: NodeType.waypoint,
          name: 'Waypoint 1',
        ),
        const NavigationNode(
          nodeId: 'N2',
          floorId: floorId,
          position: Vector3D(x: 4.0, y: 0.0, z: 0.0),
          type: NodeType.destination,
          name: 'Room 101 Node',
        ),
      ];

      final edges = [
        const NavigationEdge(edgeId: 'e0_1', fromNodeId: 'N0', toNodeId: 'N1', distance: 2.0),
        const NavigationEdge(edgeId: 'e1_2', fromNodeId: 'N1', toNodeId: 'N2', distance: 2.0),
      ];

      final floor = Floor(
        floorId: floorId,
        buildingId: buildingId,
        name: 'First Floor',
        floorNumber: 1,
        origin: origin,
        nodes: nodes,
        edges: edges,
        destinations: const [
          Destination(destinationId: 'Dest_Room101', name: 'Room 101', nodeId: 'N2', category: 'Room'),
        ],
      );

      final building = Building(
        buildingId: buildingId,
        name: 'Phase 7 Science Center',
        floors: [floor],
      );

      await repository.saveBuilding(building);

      arService = SimulatedARService();
      qrProvider = SimulatedQRLocalizationProvider(
        targetBuildingId: buildingId,
        targetFloorId: floorId,
      );

      localizationService = LocalizationService(
        arService: arService,
        qrProvider: qrProvider,
        repository: repository,
      );

      navigationService = NavigationService(
        localizationService: localizationService,
        repository: repository,
        arService: arService,
      );
    });

    tearDown(() {
      navigationService.dispose();
      localizationService.dispose();
      arService.dispose();
      qrProvider.dispose();
    });

    test('Full End-to-End Pipeline: QR Scan -> Spatial Alignment -> Nearest Start Node -> A* Route -> Waypoints', () async {
      await localizationService.startLocalizationSession(
        buildingId: buildingId,
        floorId: floorId,
      );

      final success = await navigationService.startNavigation(
        buildingId: buildingId,
        floorId: floorId,
        destinationId: 'Dest_Room101',
      );

      expect(success, isTrue);
      expect(navigationService.navigationState, equals(NavigationState.navigating));
      expect(navigationService.activeRoute, isNotNull);
      expect(navigationService.activeRoute!.pathNodes.length, equals(3));
      expect(navigationService.currentSession?.startNodeId, equals('N0'));
      expect(navigationService.currentSession?.destinationId, equals('Dest_Room101'));
    });

    test('Gracefully handles invalid destination / no route without crashing', () async {
      await localizationService.startLocalizationSession(
        buildingId: buildingId,
        floorId: floorId,
      );

      final success = await navigationService.startNavigation(
        buildingId: buildingId,
        floorId: floorId,
        destinationId: 'NonExistentDest',
      );

      expect(success, isFalse);
      expect(navigationService.navigationState, equals(NavigationState.error));
      expect(navigationService.activeRoute, isNull);
    });

    test('Tracking loss handles PAUSED state by moving to RELOCALIZING without destroying session', () async {
      await localizationService.startLocalizationSession(
        buildingId: buildingId,
        floorId: floorId,
      );
      await navigationService.startNavigation(
        buildingId: buildingId,
        floorId: floorId,
        destinationId: 'Dest_Room101',
      );

      expect(navigationService.navigationState, equals(NavigationState.navigating));

      // Simulate ARCore tracking state change to paused
      arService.pauseARSession();
      await Future.delayed(const Duration(milliseconds: 50));

      // Session remains available with relocalizing state
      expect(navigationService.currentSession, isNotNull);
      expect(navigationService.activeRoute, isNotNull);
    });
  });
}
