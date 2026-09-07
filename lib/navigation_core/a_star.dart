import '../models/navigation_graph.dart';
import '../models/navigation_node.dart';
import '../models/route.dart';

class AStarPathfinder {
  /// Calculate optimal route using A* pathfinding algorithm
  RoutePath? findPath({
    required NavigationGraph graph,
    required String startNodeId,
    required String targetNodeId,
  }) {
    if (graph.nodes.isEmpty) return null;

    final nodeMap = {for (final n in graph.nodes) n.nodeId: n};
    final startNode = nodeMap[startNodeId];
    final targetNode = nodeMap[targetNodeId];

    if (startNode == null || targetNode == null) return null;

    if (startNodeId == targetNodeId) {
      return RoutePath(
        routeId: 'route_${startNodeId}_$targetNodeId',
        startNodeId: startNodeId,
        destinationNodeId: targetNodeId,
        pathNodes: [startNode],
        totalDistance: 0.0,
      );
    }

    // Build adjacency list: nodeId -> list of neighbors with edge weights
    final adj = <String, List<_EdgeInfo>>{};
    for (final node in graph.nodes) {
      adj[node.nodeId] = [];
    }

    for (final edge in graph.edges) {
      if (!edge.accessible) continue;
      final from = edge.fromNodeId;
      final to = edge.toNodeId;
      final dist = edge.distance > 0 ? edge.distance : _heuristic(nodeMap[from], nodeMap[to]);

      if (adj.containsKey(from)) {
        adj[from]!.add(_EdgeInfo(targetId: to, distance: dist));
      }
      if (adj.containsKey(to)) {
        adj[to]!.add(_EdgeInfo(targetId: from, distance: dist));
      }
    }

    final gScore = <String, double>{startNodeId: 0.0};
    final fScore = <String, double>{startNodeId: _heuristic(startNode, targetNode)};
    final cameFrom = <String, String>{};
    final openSet = <String>{startNodeId};

    while (openSet.isNotEmpty) {
      // Find node in openSet with lowest fScore = g(n) + h(n)
      String current = openSet.first;
      double minF = fScore[current] ?? double.infinity;

      for (final id in openSet) {
        final score = fScore[id] ?? double.infinity;
        if (score < minF) {
          minF = score;
          current = id;
        }
      }

      if (current == targetNodeId) {
        // Reconstruct path
        final pathNodes = <NavigationNode>[];
        String? curr = targetNodeId;
        while (curr != null) {
          final n = nodeMap[curr];
          if (n != null) pathNodes.add(n);
          curr = cameFrom[curr];
        }
        final reversedPath = pathNodes.reversed.toList();
        final totalDist = gScore[targetNodeId] ?? 0.0;

        return RoutePath(
          routeId: 'route_${startNodeId}_$targetNodeId',
          startNodeId: startNodeId,
          destinationNodeId: targetNodeId,
          pathNodes: reversedPath,
          totalDistance: totalDist,
        );
      }

      openSet.remove(current);

      final currentG = gScore[current] ?? double.infinity;
      final neighbors = adj[current] ?? [];

      for (final neighbor in neighbors) {
        final neighborId = neighbor.targetId;
        final tentativeG = currentG + neighbor.distance;

        if (tentativeG < (gScore[neighborId] ?? double.infinity)) {
          cameFrom[neighborId] = current;
          gScore[neighborId] = tentativeG;
          final neighborNode = nodeMap[neighborId];
          fScore[neighborId] = tentativeG + _heuristic(neighborNode, targetNode);
          openSet.add(neighborId);
        }
      }
    }

    return null; // No accessible route found
  }

  /// Euclidean distance heuristic h(n)
  static double _heuristic(NavigationNode? a, NavigationNode? b) {
    if (a == null || b == null) return 0.0;
    return a.position.distanceTo(b.position);
  }
}

class _EdgeInfo {
  final String targetId;
  final double distance;
  const _EdgeInfo({required this.targetId, required this.distance});
}
