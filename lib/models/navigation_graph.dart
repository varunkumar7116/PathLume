import 'navigation_node.dart';
import 'navigation_edge.dart';

class NavigationGraph {
  final String floorId;
  final List<NavigationNode> nodes;
  final List<NavigationEdge> edges;

  const NavigationGraph({
    required this.floorId,
    this.nodes = const [],
    this.edges = const [],
  });

  Map<String, dynamic> toJson() => {
        'floorId': floorId,
        'nodes': nodes.map((n) => n.toJson()).toList(),
        'edges': edges.map((e) => e.toJson()).toList(),
      };

  factory NavigationGraph.fromJson(Map<String, dynamic> json) {
    return NavigationGraph(
      floorId: json['floorId'] as String,
      nodes: (json['nodes'] as List<dynamic>?)
              ?.map((n) => NavigationNode.fromJson(n as Map<String, dynamic>))
              .toList() ??
          [],
      edges: (json['edges'] as List<dynamic>?)
              ?.map((e) => NavigationEdge.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
