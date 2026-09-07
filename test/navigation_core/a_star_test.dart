import 'package:flutter_test/flutter_test.dart';
import 'package:pathlume/models/ar_pose.dart';
import 'package:pathlume/models/navigation_edge.dart';
import 'package:pathlume/models/navigation_graph.dart';
import 'package:pathlume/models/navigation_node.dart';
import 'package:pathlume/navigation_core/a_star.dart';

void main() {
  group('AStarPathfinder Unit Tests', () {
    late AStarPathfinder pathfinder;

    setUp(() {
      pathfinder = AStarPathfinder();
    });

    test('Finds shortest path on linear graph A -> B -> C', () {
      const nodeA = NavigationNode(
        nodeId: 'n_a',
        floorId: 'flr_1',
        type: NodeType.start,
        position: Vector3D(x: 0, y: 0, z: 0),
        name: 'Node A',
      );
      const nodeB = NavigationNode(
        nodeId: 'n_b',
        floorId: 'flr_1',
        type: NodeType.waypoint,
        position: Vector3D(x: 5, y: 0, z: 0),
        name: 'Node B',
      );
      const nodeC = NavigationNode(
        nodeId: 'n_c',
        floorId: 'flr_1',
        type: NodeType.destination,
        position: Vector3D(x: 10, y: 0, z: 0),
        name: 'Node C',
      );

      const graph = NavigationGraph(
        floorId: 'flr_1',
        nodes: [nodeA, nodeB, nodeC],
        edges: [
          NavigationEdge(edgeId: 'e1', fromNodeId: 'n_a', toNodeId: 'n_b', distance: 5.0),
          NavigationEdge(edgeId: 'e2', fromNodeId: 'n_b', toNodeId: 'n_c', distance: 5.0),
        ],
      );

      final route = pathfinder.findPath(
        graph: graph,
        startNodeId: 'n_a',
        targetNodeId: 'n_c',
      );

      expect(route, isNotNull);
      expect(route!.pathNodes.length, equals(3));
      expect(route.pathNodes.first.nodeId, equals('n_a'));
      expect(route.pathNodes.last.nodeId, equals('n_c'));
      expect(route.totalDistance, equals(10.0));
    });

    test('Picks shorter branch when alternative path exists', () {
      const nStart = NavigationNode(nodeId: 'start', floorId: 'f1', type: NodeType.start, position: Vector3D(x: 0, y: 0, z: 0), name: 'Start');
      const nShort = NavigationNode(nodeId: 'short', floorId: 'f1', type: NodeType.waypoint, position: Vector3D(x: 2, y: 0, z: 0), name: 'Short');
      const nLong1 = NavigationNode(nodeId: 'long1', floorId: 'f1', type: NodeType.waypoint, position: Vector3D(x: 0, y: 0, z: 10), name: 'Long 1');
      const nEnd = NavigationNode(nodeId: 'end', floorId: 'f1', type: NodeType.destination, position: Vector3D(x: 5, y: 0, z: 0), name: 'End');

      const graph = NavigationGraph(
        floorId: 'f1',
        nodes: [nStart, nShort, nLong1, nEnd],
        edges: [
          NavigationEdge(edgeId: 'e_s1', fromNodeId: 'start', toNodeId: 'short', distance: 2.0),
          NavigationEdge(edgeId: 'e_s2', fromNodeId: 'short', toNodeId: 'end', distance: 3.0),
          NavigationEdge(edgeId: 'e_l1', fromNodeId: 'start', toNodeId: 'long1', distance: 10.0),
          NavigationEdge(edgeId: 'e_l2', fromNodeId: 'long1', toNodeId: 'end', distance: 10.0),
        ],
      );

      final route = pathfinder.findPath(
        graph: graph,
        startNodeId: 'start',
        targetNodeId: 'end',
      );

      expect(route, isNotNull);
      expect(route!.pathNodes.map((n) => n.nodeId).toList(), equals(['start', 'short', 'end']));
      expect(route.totalDistance, equals(5.0));
    });

    test('Ignores inaccessible edges (accessible == false)', () {
      const nStart = NavigationNode(nodeId: 'start', floorId: 'f1', type: NodeType.start, position: Vector3D(x: 0, y: 0, z: 0), name: 'Start');
      const nBlocked = NavigationNode(nodeId: 'blocked', floorId: 'f1', type: NodeType.waypoint, position: Vector3D(x: 1, y: 0, z: 0), name: 'Blocked');
      const nEnd = NavigationNode(nodeId: 'end', floorId: 'f1', type: NodeType.destination, position: Vector3D(x: 2, y: 0, z: 0), name: 'End');

      const graph = NavigationGraph(
        floorId: 'f1',
        nodes: [nStart, nBlocked, nEnd],
        edges: [
          NavigationEdge(edgeId: 'e1', fromNodeId: 'start', toNodeId: 'blocked', distance: 1.0, accessible: false),
          NavigationEdge(edgeId: 'e2', fromNodeId: 'blocked', toNodeId: 'end', distance: 1.0),
        ],
      );

      final route = pathfinder.findPath(
        graph: graph,
        startNodeId: 'start',
        targetNodeId: 'end',
      );

      expect(route, isNull);
    });

    test('Returns null when no path connects start and target', () {
      const n1 = NavigationNode(nodeId: 'n1', floorId: 'f1', type: NodeType.start, position: Vector3D(), name: 'N1');
      const n2 = NavigationNode(nodeId: 'n2', floorId: 'f1', type: NodeType.destination, position: Vector3D(x: 10, y: 0, z: 0), name: 'N2');

      const graph = NavigationGraph(floorId: 'f1', nodes: [n1, n2], edges: []);

      final route = pathfinder.findPath(graph: graph, startNodeId: 'n1', targetNodeId: 'n2');
      expect(route, isNull);
    });
  });
}
