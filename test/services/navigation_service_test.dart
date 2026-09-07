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
import 'package:pathlume/services/qr/simulated_qr_localization_provider.dart';
import 'package:pathlume/services/repositories/local_building_repository.dart';
import 'package:pathlume/services/simulated_ar_service.dart';

void main() {
  group('NavigationService Integration Tests', () {
    late SimulatedARService arService;
    late SimulatedQRLocalizationProvider qrProvider;
    late LocalBuildingRepository repository;
    late LocalizationService localizationService;
    late NavigationService navigationService;

    setUp(() async {
      arService = SimulatedARService();
      qrProvider = SimulatedQRLocalizationProvider(
        targetBuildingId: 'bld_nav',
        targetFloorId: 'flr_nav',
        targetOriginId: 'orig_nav',
      );
      repository = LocalBuildingRepository();

      await repository.saveBuilding(const Building(buildingId: 'bld_nav', name: 'Nav Building'));

      const nodeStart = NavigationNode(nodeId: 'n_start', floorId: 'flr_nav', type: NodeType.start, position: Vector3D(x: 0, y: 0, z: 0), name: 'Start');
      const nodeMid = NavigationNode(nodeId: 'n_mid', floorId: 'flr_nav', type: NodeType.waypoint, position: Vector3D(x: 5, y: 0, z: 0), name: 'Mid');
      const nodeDest = NavigationNode(nodeId: 'n_dest', floorId: 'flr_nav', type: NodeType.destination, position: Vector3D(x: 10, y: 0, z: 0), name: 'Dest');
      const dest = Destination(destinationId: 'dest_01', nodeId: 'n_dest', name: 'Conference Room 101', category: 'Office');

      await repository.saveFloor(
        Floor(
          floorId: 'flr_nav',
          buildingId: 'bld_nav',
          floorNumber: 1,
          name: 'First Floor',
          origin: FloorOrigin(
            originId: 'orig_nav',
            floorId: 'flr_nav',
            position: const Vector3D(x: 0, y: 0, z: 0),
            rotation: const Quaternion4D(x: 0, y: 0, z: 0, w: 1),
            qrCodePayload: 'PATHLUME:bld_nav:flr_nav:orig_nav:1757000000000',
            createdAt: DateTime.now(),
          ),
          nodes: const [nodeStart, nodeMid, nodeDest],
          edges: const [
            NavigationEdge(edgeId: 'e1', fromNodeId: 'n_start', toNodeId: 'n_mid', distance: 5.0),
            NavigationEdge(edgeId: 'e2', fromNodeId: 'n_mid', toNodeId: 'n_dest', distance: 5.0),
          ],
          destinations: const [dest],
        ),
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
      qrProvider.dispose();
      arService.dispose();
    });

    test('Full Navigation Lifecycle: Start -> Calculate Route -> Navigating', () async {
      qrProvider.setScenario(SimulationScenario.perfectMatchWithPose);

      await localizationService.startLocalizationSession(
        buildingId: 'bld_nav',
        floorId: 'flr_nav',
      );
      await Future.delayed(const Duration(milliseconds: 100));

      final success = await navigationService.startNavigation(
        buildingId: 'bld_nav',
        floorId: 'flr_nav',
        destinationId: 'dest_01',
      );

      expect(success, isTrue);
      expect(navigationService.navigationState, equals(NavigationState.navigating));
      expect(navigationService.activeRoute, isNotNull);
      expect(navigationService.activeRoute!.pathNodes.length, equals(3));
      expect(navigationService.activeRoute!.startNodeId, equals('n_start'));
      expect(navigationService.activeRoute!.destinationNodeId, equals('n_dest'));
    });

    test('Stop Navigation resets active route and state', () async {
      qrProvider.setScenario(SimulationScenario.perfectMatchWithPose);
      await localizationService.startLocalizationSession(buildingId: 'bld_nav', floorId: 'flr_nav');
      await Future.delayed(const Duration(milliseconds: 100));

      await navigationService.startNavigation(buildingId: 'bld_nav', floorId: 'flr_nav', destinationId: 'dest_01');
      expect(navigationService.navigationState, equals(NavigationState.navigating));

      navigationService.stopNavigation();
      expect(navigationService.navigationState, equals(NavigationState.idle));
      expect(navigationService.activeRoute, isNull);
    });
  });
}
