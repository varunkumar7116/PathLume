import 'package:flutter_test/flutter_test.dart';
import 'package:pathlume/models/ar_pose.dart';
import 'package:pathlume/models/navigation_node.dart';
import 'package:pathlume/models/route.dart';
import 'package:pathlume/navigation_core/off_route_detector.dart';
import 'package:pathlume/services/localization/pose_filter.dart';

void main() {
  group('PoseFilter & Hysteresis Unit Tests', () {
    test('PoseFilter Exponential Moving Average smooths noisy position jumps', () {
      final filter = PoseFilter(positionSmoothingFactor: 0.5);

      const pos1 = Vector3D(x: 0.0, y: 0.0, z: 0.0);
      const pos2 = Vector3D(x: 10.0, y: 0.0, z: 0.0); // sudden 10m noise jump

      final f1 = filter.filterPosition(pos1);
      expect(f1.x, equals(0.0));

      final f2 = filter.filterPosition(pos2);
      expect(f2.x, equals(5.0)); // 0.5 * 10 + 0.5 * 0 = 5.0m
    });

    test('OffRouteDetector Hysteresis bounds prevent rapid oscillations', () {
      final detector = OffRouteDetector();
      const n1 = NavigationNode(nodeId: 'n1', floorId: 'f1', type: NodeType.start, position: Vector3D(x: 0, y: 0, z: 0), name: 'N1');
      const n2 = NavigationNode(nodeId: 'n2', floorId: 'f1', type: NodeType.destination, position: Vector3D(x: 10, y: 0, z: 0), name: 'N2');
      const route = RoutePath(routeId: 'r1', startNodeId: 'n1', destinationNodeId: 'n2', pathNodes: [n1, n2], totalDistance: 10.0);

      const enterPos = Vector3D(x: 5.0, y: 0.0, z: 4.0); // 4m > 3.0m enter threshold
      const midPos = Vector3D(x: 5.0, y: 0.0, z: 2.0);   // 2.0m > 1.5m exit threshold (remains off-route due to hysteresis)
      const exitPos = Vector3D(x: 5.0, y: 0.0, z: 1.0);  // 1.0m <= 1.5m exit threshold (returns on-route)

      // Enter off-route after 3 persistent frames
      expect(detector.isOffRoute(currentFloorPosition: enterPos, activeRoute: route, enterThresholdMeters: 3.0, exitThresholdMeters: 1.5), isFalse);
      expect(detector.isOffRoute(currentFloorPosition: enterPos, activeRoute: route, enterThresholdMeters: 3.0, exitThresholdMeters: 1.5), isFalse);
      expect(detector.isOffRoute(currentFloorPosition: enterPos, activeRoute: route, enterThresholdMeters: 3.0, exitThresholdMeters: 1.5), isTrue);
      expect(detector.currentlyOffRoute, isTrue);

      // Mid position (2.0m) keeps off-route true because 2.0m > 1.5m exit threshold
      expect(detector.isOffRoute(currentFloorPosition: midPos, activeRoute: route, enterThresholdMeters: 3.0, exitThresholdMeters: 1.5), isTrue);
      expect(detector.currentlyOffRoute, isTrue);

      // Exit position (1.0m <= 1.5m) returns to false
      expect(detector.isOffRoute(currentFloorPosition: exitPos, activeRoute: route, enterThresholdMeters: 3.0, exitThresholdMeters: 1.5), isFalse);
      expect(detector.currentlyOffRoute, isFalse);
    });
  });
}
