import '../models/destination.dart';
import '../models/navigation_edge.dart';
import '../models/navigation_graph.dart';
import '../models/navigation_node.dart';

class GraphValidationResult {
  final bool isValid;
  final List<String> errors;

  const GraphValidationResult({required this.isValid, this.errors = const []});
}

class GraphProcessor {
  GraphValidationResult validateGraph({
    required List<NavigationNode> nodes,
    required List<NavigationEdge> edges,
    List<Destination> destinations = const [],
  }) {
    final List<String> errors = [];

    if (nodes.isEmpty) {
      errors.add('Graph contains no nodes.');
      return GraphValidationResult(isValid: false, errors: errors);
    }

    final hasStart = nodes.any((n) => n.type == NodeType.start);
    if (!hasStart) {
      errors.add('Graph must contain at least one START node.');
    }

    if (nodes.length < 2) {
      errors.add('Graph must contain at least 2 nodes to form a walkable path.');
    }

    // Check duplicate node IDs
    final nodeIds = <String>{};
    for (final node in nodes) {
      if (nodeIds.contains(node.nodeId)) {
        errors.add('Duplicate node ID detected: ${node.nodeId}');
      }
      nodeIds.add(node.nodeId);

      // Check coordinates
      if (node.position.x.isNaN || node.position.y.isNaN || node.position.z.isNaN) {
        errors.add('Invalid NaN coordinate in node ${node.nodeId}');
      }
    }

    // Validate edges
    for (final edge in edges) {
      if (!nodeIds.contains(edge.fromNodeId)) {
        errors.add('Edge ${edge.edgeId} references missing fromNode: ${edge.fromNodeId}');
      }
      if (!nodeIds.contains(edge.toNodeId)) {
        errors.add('Edge ${edge.edgeId} references missing toNode: ${edge.toNodeId}');
      }
      if (edge.distance <= 0) {
        errors.add('Edge ${edge.edgeId} must have a positive distance.');
      }
    }

    // Validate destinations
    for (final dest in destinations) {
      if (!nodeIds.contains(dest.nodeId)) {
        errors.add('Destination ${dest.name} references non-existent node ${dest.nodeId}');
      }
    }

    return GraphValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  NavigationGraph? processNodesAndEdges({
    required String floorId,
    required List<NavigationNode> nodes,
    List<NavigationEdge> edges = const [],
    List<Destination> destinations = const [],
  }) {
    final validation = validateGraph(nodes: nodes, edges: edges, destinations: destinations);
    if (!validation.isValid) {
      return null;
    }

    return NavigationGraph(
      floorId: floorId,
      nodes: nodes,
      edges: edges,
    );
  }
}
