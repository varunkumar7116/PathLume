import 'package:flutter_test/flutter_test.dart';
import 'package:pathlume/models/ar_pose.dart';
import 'package:pathlume/models/navigation_edge.dart';
import 'package:pathlume/models/navigation_node.dart';
import 'package:pathlume/navigation_core/graph_processor.dart';

void main() {
  group('GraphProcessor Tests', () {
    late GraphProcessor processor;

    setUp(() {
      processor = GraphProcessor();
    });

    test('Validates graph requiring at least 1 START node', () {
      final nodes = [
        const NavigationNode(
          nodeId: 'n_1',
          floorId: 'f_1',
          type: NodeType.waypoint,
          position: Vector3D(x: 0, y: 0, z: 0),
          name: 'Waypoint 1',
        ),
        const NavigationNode(
          nodeId: 'n_2',
          floorId: 'f_1',
          type: NodeType.waypoint,
          position: Vector3D(x: 1, y: 0, z: 0),
          name: 'Waypoint 2',
        ),
      ];

      final edges = [
        const NavigationEdge(
          edgeId: 'e_1',
          fromNodeId: 'n_1',
          toNodeId: 'n_2',
          distance: 1.0,
        )
      ];

      final validation = processor.validateGraph(nodes: nodes, edges: edges);
      expect(validation.isValid, isFalse);
      expect(validation.errors.first, contains('START node'));
    });

    test('Processes valid graph successfully', () {
      final nodes = [
        const NavigationNode(
          nodeId: 'n_1',
          floorId: 'f_1',
          type: NodeType.start,
          position: Vector3D(x: 0, y: 0, z: 0),
          name: 'Start',
        ),
        const NavigationNode(
          nodeId: 'n_2',
          floorId: 'f_1',
          type: NodeType.waypoint,
          position: Vector3D(x: 1, y: 0, z: 0),
          name: 'Waypoint',
        ),
      ];

      final edges = [
        const NavigationEdge(
          edgeId: 'e_1',
          fromNodeId: 'n_1',
          toNodeId: 'n_2',
          distance: 1.0,
        )
      ];

      final graph = processor.processNodesAndEdges(
        floorId: 'f_1',
        nodes: nodes,
        edges: edges,
      );

      expect(graph, isNotNull);
      expect(graph!.nodes.length, equals(2));
      expect(graph.edges.length, equals(1));
    });
  });
}
