import 'navigation_node.dart';

class RoutePath {
  final String routeId;
  final String startNodeId;
  final String destinationNodeId;
  final List<NavigationNode> pathNodes;
  final double totalDistance;

  const RoutePath({
    required this.routeId,
    required this.startNodeId,
    required this.destinationNodeId,
    required this.pathNodes,
    required this.totalDistance,
  });

  Map<String, dynamic> toJson() => {
        'routeId': routeId,
        'startNodeId': startNodeId,
        'destinationNodeId': destinationNodeId,
        'pathNodes': pathNodes.map((n) => n.toJson()).toList(),
        'totalDistance': totalDistance,
      };

  factory RoutePath.fromJson(Map<String, dynamic> json) {
    return RoutePath(
      routeId: json['routeId'] as String,
      startNodeId: json['startNodeId'] as String,
      destinationNodeId: json['destinationNodeId'] as String,
      pathNodes: (json['pathNodes'] as List<dynamic>?)
              ?.map((n) => NavigationNode.fromJson(n as Map<String, dynamic>))
              .toList() ??
          [],
      totalDistance: (json['totalDistance'] as num).toDouble(),
    );
  }
}
