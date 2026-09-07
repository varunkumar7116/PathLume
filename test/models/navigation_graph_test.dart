import 'package:flutter_test/flutter_test.dart';
import 'package:pathlume/models/ar_pose.dart';
import 'package:pathlume/models/navigation_edge.dart';
import 'package:pathlume/models/navigation_graph.dart';
import 'package:pathlume/models/navigation_node.dart';

void main() {
  group('NavigationGraph Tests', () {
    test('Graph serialization and structure', () {
      const nodeA = NavigationNode(
        nodeId: 'n1',
        floorId: 'fl1',
        type: NodeType.start,
        position: Vector3D(x: 0, y: 0, z: 0),
        name: 'Start Origin',
      );

      const nodeB = NavigationNode(
        nodeId: 'n2',
        floorId: 'fl1',
        type: NodeType.destination,
        position: Vector3D(x: 5, y: 0, z: 0),
        name: 'Room 101',
      );

      const edgeAB = NavigationEdge(
        edgeId: 'e1',
        fromNodeId: 'n1',
        toNodeId: 'n2',
        distance: 5.0,
      );

      const graph = NavigationGraph(
        floorId: 'fl1',
        nodes: [nodeA, nodeB],
        edges: [edgeAB],
      );

      final json = graph.toJson();
      final restored = NavigationGraph.fromJson(json);

      expect(restored.floorId, 'fl1');
      expect(restored.nodes.length, 2);
      expect(restored.edges.length, 1);
      expect(restored.nodes.first.type, NodeType.start);
      expect(restored.edges.first.distance, 5.0);
    });
  });
}
