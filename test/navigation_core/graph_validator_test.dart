import 'package:flutter_test/flutter_test.dart';
import 'package:pathlume/models/ar_pose.dart';
import 'package:pathlume/models/destination.dart';
import 'package:pathlume/models/navigation_edge.dart';
import 'package:pathlume/models/navigation_graph.dart';
import 'package:pathlume/models/navigation_node.dart';
import 'package:pathlume/navigation_core/graph_validator.dart';

void main() {
  group('GraphValidator Unit Tests', () {
    late GraphValidator validator;

    setUp(() {
      validator = GraphValidator();
    });

    test('Valid graph passes inspection', () {
      const nodeA = NavigationNode(nodeId: 'n_a', floorId: 'f1', type: NodeType.start, position: Vector3D(x: 0, y: 0, z: 0), name: 'A');
      const nodeB = NavigationNode(nodeId: 'n_b', floorId: 'f1', type: NodeType.destination, position: Vector3D(x: 5, y: 0, z: 0), name: 'B');
      const dest = Destination(destinationId: 'd1', nodeId: 'n_b', name: 'Dest B', category: 'Office');

      const graph = NavigationGraph(
        floorId: 'f1',
        nodes: [nodeA, nodeB],
        edges: [NavigationEdge(edgeId: 'e1', fromNodeId: 'n_a', toNodeId: 'n_b', distance: 5.0)],
      );

      final result = validator.validateGraph(graph, destinations: [dest]);
      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });

    test('Duplicate node IDs fail validation', () {
      const nodeA1 = NavigationNode(nodeId: 'n_dup', floorId: 'f1', type: NodeType.start, position: Vector3D(x: 0, y: 0, z: 0), name: 'A1');
      const nodeA2 = NavigationNode(nodeId: 'n_dup', floorId: 'f1', type: NodeType.waypoint, position: Vector3D(x: 1, y: 0, z: 0), name: 'A2');

      const graph = NavigationGraph(floorId: 'f1', nodes: [nodeA1, nodeA2], edges: []);
      final result = validator.validateGraph(graph);

      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('Duplicate nodeId')), isTrue);
    });

    test('Invalid edge endpoints fail validation', () {
      const nodeA = NavigationNode(nodeId: 'n_a', floorId: 'f1', type: NodeType.start, position: Vector3D(), name: 'A');
      const graph = NavigationGraph(
        floorId: 'f1',
        nodes: [nodeA],
        edges: [NavigationEdge(edgeId: 'e1', fromNodeId: 'n_a', toNodeId: 'n_missing', distance: 5.0)],
      );

      final result = validator.validateGraph(graph);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('missing toNodeId')), isTrue);
    });

    test('Destination referencing missing node fails validation', () {
      const nodeA = NavigationNode(nodeId: 'n_a', floorId: 'f1', type: NodeType.start, position: Vector3D(), name: 'A');
      const dest = Destination(destinationId: 'd1', nodeId: 'n_nonexistent', name: 'Bad Dest', category: 'General');

      const graph = NavigationGraph(floorId: 'f1', nodes: [nodeA], edges: []);
      final result = validator.validateGraph(graph, destinations: [dest]);

      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('missing nodeId')), isTrue);
    });
  });
}
