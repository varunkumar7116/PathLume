import 'package:flutter_test/flutter_test.dart';
import 'package:pathlume/models/navigation_node.dart';
import 'package:pathlume/navigation_core/registration_engine.dart';
import 'package:pathlume/services/simulated_ar_service.dart';

void main() {
  group('Developer AR Simulation Tests', () {
    test('SimulatedARService advances poses correctly', () {
      final simService = SimulatedARService();
      expect(simService.predefinedPoses.length, greaterThanOrEqualTo(5));

      final pose1 = simService.advanceSimulatedPose();
      expect(pose1.position.z, equals(1.0));

      final pose2 = simService.advanceSimulatedPose();
      expect(pose2.position.z, equals(2.0));
    });

    test('Full registration workflow using simulated AR poses', () {
      final simService = SimulatedARService();
      final engine = RegistrationEngine(minNodeSpacingMeters: 0.8);
      engine.initializeRegistration(buildingId: 'b_sim', floorId: 'f_sim');

      // 1. Set start point
      engine.setStartPoint(
        simService.advanceSimulatedPose(), // 0,0,0
      );
      engine.startWalking();

      // 2. Add nodes along simulated route: (0,0,1), (0,0,2), (1,0,2), (2,0,2)
      for (int i = 1; i < simService.predefinedPoses.length; i++) {
        final pose = simService.advanceSimulatedPose();
        engine.addNode(
          type: i == simService.predefinedPoses.length - 1
              ? NodeType.destination
              : (i == 3 ? NodeType.turn : NodeType.waypoint),
          position: pose.position,
          name: i == simService.predefinedPoses.length - 1 ? 'End Lab' : null,
        );
      }

      final summary = engine.getSummary();
      expect(summary.nodeCount, greaterThanOrEqualTo(5));
      expect(summary.edgeCount, greaterThanOrEqualTo(4));
      expect(summary.destinationCount, equals(1));

      final graph = engine.finishAndProcessGraph();
      expect(graph, isNotNull);
      expect(graph!.nodes.length, equals(summary.nodeCount));
    });
  });
}
