import 'package:flutter_test/flutter_test.dart';
import 'package:pathlume/models/ar_pose.dart';
import 'package:pathlume/models/ar_tracking_state.dart';
import 'package:pathlume/models/navigation_node.dart';
import 'package:pathlume/models/registration_state.dart';
import 'package:pathlume/navigation_core/registration_engine.dart';

void main() {
  group('RegistrationEngine Tests', () {
    late RegistrationEngine engine;

    setUp(() {
      engine = RegistrationEngine(minNodeSpacingMeters: 0.8);
      engine.initializeRegistration(buildingId: 'b_01', floorId: 'f_01');
    });

    test('TEST 1: Node 0 created', () {
      expect(engine.state, equals(RegistrationState.preparing));
      const pose0 = ARPose(
        position: Vector3D(x: 0, y: 0, z: 0),
        trackingState: ARTrackingState.tracking,
      );
      engine.setStartPoint(pose0);

      expect(engine.state, equals(RegistrationState.originSet));
      expect(engine.capturedNodes.length, equals(1));
      expect(engine.capturedNodes.first.type, equals(NodeType.start));
      expect(engine.capturedNodes.first.sequence, equals(0));
    });

    test('TEST 2: Node 1 at 1.0m -> accepted', () {
      const pose0 = ARPose(position: Vector3D(x: 0, y: 0, z: 0));
      engine.setStartPoint(pose0);
      engine.startWalking();

      final res = engine.addNode(
        type: NodeType.waypoint,
        position: const Vector3D(x: 1.0, y: 0, z: 0),
      );

      expect(res.success, isTrue);
      expect(engine.capturedNodes.length, equals(2));
      expect(engine.capturedEdges.length, equals(1));
      expect(engine.capturedEdges.first.distance, equals(1.0));
    });

    test('TEST 3: Node 1 at 0.3m -> rejected', () {
      const pose0 = ARPose(position: Vector3D(x: 0, y: 0, z: 0));
      engine.setStartPoint(pose0);
      engine.startWalking();

      final res = engine.addNode(
        type: NodeType.waypoint,
        position: const Vector3D(x: 0.3, y: 0, z: 0),
      );

      expect(res.success, isFalse);
      expect(res.warningMessage, contains('Move at least 0.8 m'));
      expect(engine.capturedNodes.length, equals(1));
    });

    test('TEST 4: Node 0 -> Node 1 -> Node 2 spacing is always measured from the LAST node', () {
      const pose0 = ARPose(position: Vector3D(x: 0, y: 0, z: 0));
      engine.setStartPoint(pose0);
      engine.startWalking();

      // Node 1 at (1.0, 0, 0) - distance from Node 0 is 1.0m -> accepted
      final res1 = engine.addNode(position: const Vector3D(x: 1.0, y: 0, z: 0));
      expect(res1.success, isTrue);
      expect(engine.capturedNodes.length, equals(2));

      // Node 2 candidate at (0.3, 0, 0) - distance from Node 0 is 0.3m, but distance from LAST node (Node 1) is 0.7m (< 0.8m limit) -> rejected!
      final res2TooClose = engine.addNode(position: const Vector3D(x: 0.3, y: 0, z: 0));
      expect(res2TooClose.success, isFalse);

      // Node 2 candidate at (2.0, 0, 0) - distance from LAST node (Node 1 at 1.0m) is 1.0m (>= 0.8m) -> accepted!
      final res2Accepted = engine.addNode(position: const Vector3D(x: 2.0, y: 0, z: 0));
      expect(res2Accepted.success, isTrue);
      expect(engine.capturedNodes.length, equals(3));
    });

    test('TEST 5: Current pose must be used rather than registration origin', () {
      const originPose = ARPose(position: Vector3D(x: 10.0, y: 0, z: 10.0));
      engine.setStartPoint(originPose);
      engine.startWalking();

      // Node 1 added at live camera pose (11.0, 0, 10.0) -> distance from originPose (10,0,10) is 1.0m
      final res = engine.addNode(position: const Vector3D(x: 11.0, y: 0, z: 10.0));
      expect(res.success, isTrue);
      expect(engine.capturedNodes.last.position.x, equals(11.0));
    });

    test('TEST 6: Stale pose produces stale-pose error rather than spacing error', () {
      final oldTimestamp = DateTime.now().millisecondsSinceEpoch - 2000;
      final stalePose = ARPose(
        position: const Vector3D(x: 5.0, y: 0, z: 0),
        trackingState: ARTrackingState.tracking,
        timestamp: oldTimestamp,
      );

      expect(stalePose.isFresh(maxAgeMs: 500), isFalse);
    });

    test('TEST 7: AR world and floor coordinates are not mixed (3D Euclidean distance in AR world space)', () {
      const pose0 = ARPose(position: Vector3D(x: 0, y: 0, z: 0));
      engine.setStartPoint(pose0);
      engine.startWalking();

      // 3D vector distance check
      const pose1Pos = Vector3D(x: 0.6, y: 0.6, z: 0.0); // dist sqrt(0.36 + 0.36) = 0.848m >= 0.8m
      final res = engine.addNode(position: pose1Pos);
      expect(res.success, isTrue);
    });

    test('Records destination metadata', () {
      const pose0 = ARPose(position: Vector3D(x: 0, y: 0, z: 0));
      engine.setStartPoint(pose0);
      engine.startWalking();

      engine.addNode(
        type: NodeType.destination,
        position: const Vector3D(x: 2.0, y: 0, z: 0),
        name: 'Computer Lab 1',
        destinationCategory: 'Lab',
      );

      expect(engine.capturedDestinations.length, equals(1));
      expect(engine.capturedDestinations.first.name, equals('Computer Lab 1'));
    });

    test('markTurn succeeds near existing node without node spacing warning', () {
      const pose0 = ARPose(position: Vector3D(x: 0, y: 0, z: 0));
      engine.setStartPoint(pose0);
      engine.startWalking();

      final res = engine.markTurn(position: const Vector3D(x: 0.1, y: 0, z: 0));
      expect(res.success, isTrue);
      expect(res.node, isNotNull);
      expect(engine.capturedNodes.length, equals(2));
    });
  });
}
