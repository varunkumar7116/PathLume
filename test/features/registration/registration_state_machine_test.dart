import 'package:flutter_test/flutter_test.dart';
import 'package:pathlume/models/ar_pose.dart';
import 'package:pathlume/models/ar_tracking_state.dart';
import 'package:pathlume/models/navigation_graph.dart';
import 'package:pathlume/models/navigation_node.dart';
import 'package:pathlume/models/registration_state.dart';
import 'package:pathlume/navigation_core/graph_validator.dart';
import 'package:pathlume/navigation_core/registration_engine.dart';

void main() {
  group('Phase 6 Registration State Machine & Robustness Tests', () {
    late RegistrationEngine engine;
    late GraphValidator validator;

    setUp(() {
      engine = RegistrationEngine(minNodeSpacingMeters: 0.8);
      engine.initializeRegistration(buildingId: 'b_ph6', floorId: 'f_ph6');
      validator = GraphValidator();
    });

    test('State machine transitions: preparing -> trackingInitializing -> ready -> registering', () {
      expect(engine.state, equals(RegistrationState.preparing));

      engine.updateTrackingState(ARTrackingState.initializing);
      expect(engine.state, equals(RegistrationState.trackingInitializing));

      engine.updateTrackingState(ARTrackingState.tracking);
      expect(engine.state, equals(RegistrationState.ready));

      const pose0 = ARPose(
        position: Vector3D(x: 0, y: 0, z: 0),
        trackingState: ARTrackingState.tracking,
      );
      engine.setStartPoint(pose0);
      engine.startWalking();

      expect(engine.state, equals(RegistrationState.registering));
    });

    test('Node 0 is created exactly once on setStartPoint and subsequent calls are ignored', () {
      const pose0 = ARPose(position: Vector3D(x: 1, y: 0, z: 1));
      engine.setStartPoint(pose0);

      expect(engine.capturedNodes.length, equals(1));
      expect(engine.capturedNodes.first.type, equals(NodeType.start));

      // Attempt second setStartPoint call
      const poseAlt = ARPose(position: Vector3D(x: 5, y: 0, z: 5));
      engine.setStartPoint(poseAlt);

      expect(engine.capturedNodes.length, equals(1));
      expect(engine.capturedNodes.first.position.x, equals(1.0));
    });

    test('ARPose freshness and validity predicates operate correctly', () {
      final validFreshPose = ARPose(
        position: const Vector3D(x: 1, y: 2, z: 3),
        rotation: const Quaternion4D(x: 0, y: 0, z: 0, w: 1),
        trackingState: ARTrackingState.tracking,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      expect(validFreshPose.isValid, isTrue);
      expect(validFreshPose.isFresh(maxAgeMs: 500), isTrue);

      const invalidPose = ARPose(
        position: Vector3D(x: double.nan, y: 0, z: 0),
        trackingState: ARTrackingState.tracking,
      );
      expect(invalidPose.isValid, isFalse);
      expect(invalidPose.isFresh(maxAgeMs: 500), isFalse);

      const stalePose = ARPose(
        position: Vector3D(x: 1, y: 1, z: 1),
        trackingState: ARTrackingState.tracking,
        timestamp: 1000, // Very old timestamp compared to now
      );
      expect(stalePose.isValid, isTrue);
      expect(stalePose.isFresh(maxAgeMs: 500), isFalse);
    });

    test('RegistrationQualityMetrics evaluates path metrics and interruptions accurately', () {
      const pose0 = ARPose(position: Vector3D(x: 0, y: 0, z: 0));
      engine.setStartPoint(pose0);
      engine.startWalking();

      engine.addNode(position: const Vector3D(x: 1.5, y: 0, z: 0));
      engine.addNode(position: const Vector3D(x: 3.5, y: 0, z: 0));

      engine.recordTrackingInterruption();

      final metrics = engine.getQualityMetrics();
      expect(metrics.totalNodes, equals(3));
      expect(metrics.totalEdges, equals(2));
      expect(metrics.totalDistance, equals(3.5));
      expect(metrics.minSpacing, equals(1.5));
      expect(metrics.maxEdgeLength, equals(2.0));
      expect(metrics.trackingInterruptions, equals(1));
      expect(metrics.disconnectedNodeCount, equals(0));
    });

    test('GraphValidator reports disconnected nodes and missing START node', () {
      const invalidGraph = NavigationGraph(
        floorId: 'f_ph6',
        nodes: [
          NavigationNode(nodeId: 'n1', floorId: 'f_ph6', type: NodeType.waypoint, position: Vector3D(x: 0, y: 0, z: 0), name: 'N1'),
          NavigationNode(nodeId: 'n2', floorId: 'f_ph6', type: NodeType.waypoint, position: Vector3D(x: 1, y: 0, z: 0), name: 'N2'),
        ],
        edges: [],
      );

      final result = validator.validateGraph(invalidGraph);
      expect(result.isValid, isFalse);
      expect(result.errors, contains('Graph must contain at least one START origin node'));
    });
  });
}
