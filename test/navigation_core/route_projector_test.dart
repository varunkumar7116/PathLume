import 'package:flutter_test/flutter_test.dart';
import 'package:pathlume/models/ar_pose.dart';
import 'package:pathlume/models/navigation_node.dart';
import 'package:pathlume/models/route.dart';
import 'package:pathlume/navigation_core/route_projector.dart';

void main() {
  group('RouteProjector Phase 7 Unit Tests', () {
    late RouteProjector projector;

    setUp(() {
      projector = RouteProjector();
    });

    test('Advances waypoint index when within configurable acceptance radius (0.75m)', () {
      const n0 = NavigationNode(
        nodeId: 'N0',
        floorId: 'F1',
        position: Vector3D(x: 0.0, y: 0.0, z: 0.0),
        name: 'Node 0',
        type: NodeType.start,
      );
      const n1 = NavigationNode(
        nodeId: 'N1',
        floorId: 'F1',
        position: Vector3D(x: 2.0, y: 0.0, z: 0.0),
        name: 'Node 1',
        type: NodeType.waypoint,
      );
      const n2 = NavigationNode(
        nodeId: 'N2',
        floorId: 'F1',
        position: Vector3D(x: 4.0, y: 0.0, z: 0.0),
        name: 'Node 2',
        type: NodeType.destination,
      );

      const route = RoutePath(
        routeId: 'r1',
        startNodeId: 'N0',
        destinationNodeId: 'N2',
        pathNodes: [n0, n1, n2],
        totalDistance: 4.0,
      );

      // User at (1.0, 0, 0) - distance to N1 is 1.0m > 0.75m -> stays at index 0
      final progress1 = projector.calculateProgress(
        currentFloorPosition: const Vector3D(x: 1.0, y: 0.0, z: 0.0),
        activeRoute: route,
        previousWaypointIndex: 0,
        waypointAcceptanceRadius: 0.75,
      );
      expect(progress1.currentWaypointIndex, equals(0));

      // User at (1.5, 0, 0) - distance to N1 is 0.5m < 0.75m -> advances to index 1
      final progress2 = projector.calculateProgress(
        currentFloorPosition: const Vector3D(x: 1.5, y: 0.0, z: 0.0),
        activeRoute: route,
        previousWaypointIndex: 0,
        waypointAcceptanceRadius: 0.75,
      );
      expect(progress2.currentWaypointIndex, equals(1));
    });

    test('Classifies turn instructions correctly across all directions', () {
      const p0 = Vector3D(x: 0.0, y: 0.0, z: 0.0);
      const pStraight = Vector3D(x: 0.0, y: 0.0, z: 5.0);
      const pStraightExt = Vector3D(x: 0.0, y: 0.0, z: 10.0);
      const pRight = Vector3D(x: -5.0, y: 0.0, z: 5.0);
      const pLeft = Vector3D(x: 5.0, y: 0.0, z: 5.0);

      const routeStraight = RoutePath(
        routeId: 'r_straight',
        startNodeId: 'N0',
        destinationNodeId: 'N2',
        pathNodes: [
          NavigationNode(nodeId: 'N0', floorId: 'F1', position: p0, name: 'Node 0', type: NodeType.start),
          NavigationNode(nodeId: 'N1', floorId: 'F1', position: pStraight, name: 'Node 1', type: NodeType.waypoint),
          NavigationNode(nodeId: 'N2', floorId: 'F1', position: pStraightExt, name: 'Node 2', type: NodeType.destination),
        ],
        totalDistance: 10.0,
      );

      final progressStraight = projector.calculateProgress(
        currentFloorPosition: p0,
        activeRoute: routeStraight,
        previousWaypointIndex: 0,
      );
      expect(progressStraight.currentInstruction, equals(TurnInstruction.straight));

      const routeRight = RoutePath(
        routeId: 'r_right',
        startNodeId: 'N0',
        destinationNodeId: 'N2',
        pathNodes: [
          NavigationNode(nodeId: 'N0', floorId: 'F1', position: p0, name: 'Node 0', type: NodeType.start),
          NavigationNode(nodeId: 'N1', floorId: 'F1', position: pStraight, name: 'Node 1', type: NodeType.waypoint),
          NavigationNode(nodeId: 'N2', floorId: 'F1', position: pRight, name: 'Node 2', type: NodeType.destination),
        ],
        totalDistance: 10.0,
      );

      final progressRight = projector.calculateProgress(
        currentFloorPosition: p0,
        activeRoute: routeRight,
        previousWaypointIndex: 0,
      );
      expect(progressRight.currentInstruction, equals(TurnInstruction.right));

      const routeLeft = RoutePath(
        routeId: 'r_left',
        startNodeId: 'N0',
        destinationNodeId: 'N2',
        pathNodes: [
          NavigationNode(nodeId: 'N0', floorId: 'F1', position: p0, name: 'Node 0', type: NodeType.start),
          NavigationNode(nodeId: 'N1', floorId: 'F1', position: pStraight, name: 'Node 1', type: NodeType.waypoint),
          NavigationNode(nodeId: 'N2', floorId: 'F1', position: pLeft, name: 'Node 2', type: NodeType.destination),
        ],
        totalDistance: 10.0,
      );

      final progressLeft = projector.calculateProgress(
        currentFloorPosition: p0,
        activeRoute: routeLeft,
        previousWaypointIndex: 0,
      );
      expect(progressLeft.currentInstruction, equals(TurnInstruction.left));
    });
  });
}
