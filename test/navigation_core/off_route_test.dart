import 'package:flutter_test/flutter_test.dart';
import 'package:pathlume/models/ar_pose.dart';
import 'package:pathlume/models/navigation_node.dart';
import 'package:pathlume/models/route.dart';
import 'package:pathlume/navigation_core/off_route_detector.dart';
import 'package:pathlume/navigation_core/route_projector.dart';

void main() {
  group('OffRouteDetector & RouteProjector Tests', () {
    late OffRouteDetector offRouteDetector;
    late RouteProjector routeProjector;
    late RoutePath sampleRoute;

    setUp(() {
      offRouteDetector = OffRouteDetector();
      routeProjector = RouteProjector();

      const n1 = NavigationNode(nodeId: 'n1', floorId: 'f1', type: NodeType.start, position: Vector3D(x: 0, y: 0, z: 0), name: 'N1');
      const n2 = NavigationNode(nodeId: 'n2', floorId: 'f1', type: NodeType.turn, position: Vector3D(x: 10, y: 0, z: 0), name: 'N2');
      const n3 = NavigationNode(nodeId: 'n3', floorId: 'f1', type: NodeType.destination, position: Vector3D(x: 10, y: 0, z: 10), name: 'N3');

      sampleRoute = const RoutePath(
        routeId: 'r1',
        startNodeId: 'n1',
        destinationNodeId: 'n3',
        pathNodes: [n1, n2, n3],
        totalDistance: 20.0,
      );
    });

    test('User on path does not trigger off-route', () {
      const userOnPath = Vector3D(x: 5.0, y: 0.0, z: 0.2); // 0.2m offset from segment
      final isOff = offRouteDetector.isOffRoute(
        currentFloorPosition: userOnPath,
        activeRoute: sampleRoute,
        thresholdMeters: 3.0,
      );
      expect(isOff, isFalse);
    });

    test('User > 3.0m off route triggers off-route after persistence threshold', () {
      const userFarOff = Vector3D(x: 5.0, y: 0.0, z: 10.0); // 10m perpendicular offset from first segment

      expect(offRouteDetector.isOffRoute(currentFloorPosition: userFarOff, activeRoute: sampleRoute, persistenceCount: 3), isFalse);
      expect(offRouteDetector.isOffRoute(currentFloorPosition: userFarOff, activeRoute: sampleRoute, persistenceCount: 3), isFalse);
      expect(offRouteDetector.isOffRoute(currentFloorPosition: userFarOff, activeRoute: sampleRoute, persistenceCount: 3), isTrue);
    });

    test('RouteProjector computes progress and turn instruction correctly', () {
      const userPos = Vector3D(x: 2.0, y: 0.0, z: 0.0);
      final progress = routeProjector.calculateProgress(
        currentFloorPosition: userPos,
        activeRoute: sampleRoute,
        previousWaypointIndex: 0,
      );

      expect(progress.currentWaypointIndex, equals(0));
      expect(progress.distanceRemainingMeters, closeTo(18.0, 0.5));
      expect(progress.currentInstruction, equals(TurnInstruction.right));
    });
  });
}
