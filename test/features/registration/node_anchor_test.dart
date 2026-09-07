import 'package:flutter_test/flutter_test.dart';
import 'package:pathlume/models/ar_pose.dart';
import 'package:pathlume/models/ar_tracking_state.dart';
import 'package:pathlume/models/navigation_node.dart';
import 'package:pathlume/navigation_core/registration_engine.dart';
import 'package:pathlume/services/simulated_ar_service.dart';

void main() {
  group('AR Node Anchor Creation Tests', () {
    late RegistrationEngine engine;
    late SimulatedARService arService;

    setUp(() {
      engine = RegistrationEngine(minNodeSpacingMeters: 0.8);
      engine.initializeRegistration(buildingId: 'b_anchor', floorId: 'f_anchor');
      arService = SimulatedARService();
    });

    test('ADD NODE captures AR pose and creates initial anchor', () async {
      const pose0 = ARPose(
        position: Vector3D(x: 1.0, y: 0.0, z: 2.0),
        trackingState: ARTrackingState.tracking,
      );

      engine.setStartPoint(pose0);
      engine.startWalking();

      final anchorPlaced = await arService.addNodeAnchor(
        pose0.position.x,
        pose0.position.y,
        pose0.position.z,
      );

      expect(anchorPlaced, isTrue);
      expect(engine.capturedNodes.length, equals(1));
      expect(engine.capturedNodes.first.position.x, equals(1.0));
      expect(engine.capturedNodes.first.position.z, equals(2.0));
    });

    test('TEST 8: Node and anchor counts remain synchronized across sequential node additions', () async {
      int anchorCount = 0;

      const pose0 = ARPose(position: Vector3D(x: 0.0, y: 0.0, z: 0.0));
      const pose1 = ARPose(position: Vector3D(x: 0.0, y: 0.0, z: 1.5));
      const pose2 = ARPose(position: Vector3D(x: 0.0, y: 0.0, z: 3.0));

      engine.setStartPoint(pose0);
      engine.startWalking();
      if (await arService.addNodeAnchor(pose0.position.x, pose0.position.y, pose0.position.z)) {
        anchorCount++;
      }

      final res1 = engine.addNode(position: pose1.position);
      expect(res1.success, isTrue);
      if (await arService.addNodeAnchor(pose1.position.x, pose1.position.y, pose1.position.z)) {
        anchorCount++;
      }

      final res2 = engine.addNode(position: pose2.position);
      expect(res2.success, isTrue);
      if (await arService.addNodeAnchor(pose2.position.x, pose2.position.y, pose2.position.z)) {
        anchorCount++;
      }

      expect(engine.capturedNodes.length, equals(3));
      expect(anchorCount, equals(3));
    });

    test('TEST 9: Adding Node 1 appends to graph without replacing Node 0', () async {
      const pose0 = ARPose(position: Vector3D(x: 0.0, y: 0.0, z: 0.0));
      const pose1 = ARPose(position: Vector3D(x: 1.2, y: 0.0, z: 0.0));

      engine.setStartPoint(pose0);
      engine.startWalking();
      expect(engine.capturedNodes.length, equals(1));
      expect(engine.capturedNodes.first.type, equals(NodeType.start));

      final res1 = engine.addNode(position: pose1.position);
      expect(res1.success, isTrue);
      expect(engine.capturedNodes.length, equals(2));
      expect(engine.capturedNodes[0].type, equals(NodeType.start));
      expect(engine.capturedNodes[1].type, equals(NodeType.waypoint));
      expect(engine.capturedNodes[0].position.x, equals(0.0));
      expect(engine.capturedNodes[1].position.x, equals(1.2));
    });

    test('Too close ADD NODE does not create duplicate node or anchor', () async {
      const pose0 = ARPose(position: Vector3D(x: 0.0, y: 0.0, z: 0.0));
      const poseTooClose = ARPose(position: Vector3D(x: 0.2, y: 0.0, z: 0.0));

      engine.setStartPoint(pose0);
      engine.startWalking();

      final res = engine.addNode(position: poseTooClose.position);
      expect(res.success, isFalse);
      expect(res.warningMessage, contains('Move at least 0.8 m'));
      expect(engine.capturedNodes.length, equals(1));
    });
  });
}
