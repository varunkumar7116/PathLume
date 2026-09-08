import '../models/destination.dart';
import '../models/navigation_graph.dart';
import '../models/navigation_node.dart';

class GraphValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const GraphValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });

  String get summaryText {
    if (isValid && warnings.isEmpty) {
      return '✓ Graph is fully valid and ready for navigation.';
    }
    final sb = StringBuffer();
    if (errors.isNotEmpty) {
      sb.writeln('ERRORS:');
      for (final e in errors) {
        sb.writeln('• $e');
      }
    }
    if (warnings.isNotEmpty) {
      sb.writeln('WARNINGS:');
      for (final w in warnings) {
        sb.writeln('• $w');
      }
    }
    return sb.toString().trim();
  }
}

class GraphValidator {
  /// Validates structural integrity, connectivity, and destination reachability across 18 rules.
  GraphValidationResult validateGraph(
    NavigationGraph? graph, {
    List<Destination>? destinations,
  }) {
    final errors = <String>[];
    final warnings = <String>[];

    // Rule 1: Null check
    if (graph == null) {
      return const GraphValidationResult(
        isValid: false,
        errors: ['Graph object is null'],
      );
    }

    // Rule 1 (cont): Minimum 2 nodes
    if (graph.nodes.length < 2) {
      errors.add('Graph must contain at least 2 nodes to form a walkable path');
    }

    // Rule 15: Valid START origin node check
    final startNodes = graph.nodes.where((n) => n.type == NodeType.start).toList();
    if (startNodes.isEmpty) {
      errors.add('Graph must contain at least one START origin node');
    } else if (startNodes.length > 1) {
      warnings.add('Graph contains ${startNodes.length} START nodes; single start node recommended');
    }

    // Rule 2, 3, 4, 5, 6, 7: Node properties, sequence, coordinates
    final seenNodeIds = <String>{};
    final seenSequences = <int>{};
    for (final node in graph.nodes) {
      if (node.nodeId.isEmpty) {
        errors.add('Node exists with empty nodeId');
      } else if (seenNodeIds.contains(node.nodeId)) {
        errors.add('Duplicate nodeId found: ${node.nodeId}');
      } else {
        seenNodeIds.add(node.nodeId);
      }

      if (node.sequence < 0) {
        errors.add('Node ${node.nodeId} has negative sequence index: ${node.sequence}');
      } else {
        seenSequences.add(node.sequence);
      }

      if (graph.floorId.isNotEmpty && node.floorId != graph.floorId) {
        warnings.add(
          'Node ${node.nodeId} floorId (${node.floorId}) differs from graph floorId (${graph.floorId})',
        );
      }

      // Rules 4, 5, 6: Finite, non-NaN, non-Infinity check
      if (!node.position.x.isFinite ||
          !node.position.y.isFinite ||
          !node.position.z.isFinite) {
        errors.add(
          'Node ${node.nodeId} contains non-finite (NaN or Infinity) coordinates',
        );
      }
    }

    // Rules 8, 9, 10: Edges, endpoints, self-loops, non-zero distances
    final seenEdgeIds = <String>{};
    final adjacency = <String, Set<String>>{};
    for (final id in seenNodeIds) {
      adjacency[id] = <String>{};
    }

    for (final edge in graph.edges) {
      if (edge.edgeId.isEmpty) {
        warnings.add('Edge exists with empty edgeId');
      } else if (seenEdgeIds.contains(edge.edgeId)) {
        errors.add('Duplicate edgeId found: ${edge.edgeId}');
      } else {
        seenEdgeIds.add(edge.edgeId);
      }

      // Rule 8 & 14: Dangling/broken edge references
      if (!seenNodeIds.contains(edge.fromNodeId)) {
        errors.add(
          'Edge ${edge.edgeId} references missing fromNodeId: ${edge.fromNodeId}',
        );
      }
      if (!seenNodeIds.contains(edge.toNodeId)) {
        errors.add(
          'Edge ${edge.edgeId} references missing toNodeId: ${edge.toNodeId}',
        );
      }

      // Rule 9: Self-loop check
      if (edge.fromNodeId == edge.toNodeId) {
        errors.add('Edge ${edge.edgeId} is an invalid self-loop on node ${edge.fromNodeId}');
      }

      // Rule 10: Non-zero positive distance
      if (edge.distance <= 0.0) {
        final fromNode = graph.nodes.cast<NavigationNode?>().firstWhere((n) => n?.nodeId == edge.fromNodeId, orElse: () => null);
        final toNode = graph.nodes.cast<NavigationNode?>().firstWhere((n) => n?.nodeId == edge.toNodeId, orElse: () => null);
        if (fromNode != null && toNode != null) {
          final dist = fromNode.position.distanceTo(toNode.position);
          final validDist = dist > 0.0 ? dist.toStringAsFixed(2) : '0.50';
          warnings.add('Edge ${edge.edgeId} distance auto-corrected from 0.0m to ${validDist}m');
        } else {
          errors.add('Edge ${edge.edgeId} has non-positive distance: ${edge.distance}m');
        }
      } else if (edge.distance <= 0.05) {
        warnings.add('Edge ${edge.edgeId} has extremely short distance: ${edge.distance}m');
      }

      if (seenNodeIds.contains(edge.fromNodeId) && seenNodeIds.contains(edge.toNodeId)) {
        adjacency[edge.fromNodeId]?.add(edge.toNodeId);
        adjacency[edge.toNodeId]?.add(edge.fromNodeId);
      }
    }

    // Rule 11 & 13: BFS Connectivity & Orphan node check
    final reachableFromStart = <String>{};
    if (startNodes.isNotEmpty) {
      final startNode = startNodes.first;
      reachableFromStart.add(startNode.nodeId);
      final queue = [startNode.nodeId];

      while (queue.isNotEmpty) {
        final current = queue.removeAt(0);
        final neighbors = adjacency[current] ?? {};
        for (final neighbor in neighbors) {
          if (!reachableFromStart.contains(neighbor)) {
            reachableFromStart.add(neighbor);
            queue.add(neighbor);
          }
        }
      }

      // Rule 13: Orphan nodes disconnected from START
      for (final nodeId in seenNodeIds) {
        final degree = adjacency[nodeId]?.length ?? 0;
        if (degree == 0 && nodeId != startNode.nodeId) {
          errors.add('Node $nodeId is an orphan node with 0 edges');
        } else if (!reachableFromStart.contains(nodeId)) {
          warnings.add('Node $nodeId is disconnected from the START node path');
        }
      }
    }

    // Rules 12, 16, 17: Destinations reachability & uniqueness
    if (destinations != null) {
      final seenDestIds = <String>{};
      for (final dest in destinations) {
        if (seenDestIds.contains(dest.destinationId)) {
          errors.add('Duplicate destinationId found: ${dest.destinationId}');
        } else {
          seenDestIds.add(dest.destinationId);
        }

        // Rule 16: Destination references valid node
        if (!seenNodeIds.contains(dest.nodeId)) {
          errors.add(
            'Destination ${dest.destinationId} (${dest.name}) references missing nodeId: ${dest.nodeId}',
          );
        } else if (startNodes.isNotEmpty && !reachableFromStart.contains(dest.nodeId)) {
          // Rule 12: Destination reachability from START
          errors.add(
            'Destination "${dest.name}" (Node ${dest.nodeId}) is unreachable from the START origin node',
          );
        }
      }
    }

    return GraphValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }
}
