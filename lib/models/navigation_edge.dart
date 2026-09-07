class NavigationEdge {
  final String edgeId;
  final String fromNodeId;
  final String toNodeId;
  final double distance;
  final bool accessible;

  const NavigationEdge({
    required this.edgeId,
    required this.fromNodeId,
    required this.toNodeId,
    required this.distance,
    this.accessible = true,
  });

  Map<String, dynamic> toJson() => {
        'edgeId': edgeId,
        'fromNodeId': fromNodeId,
        'toNodeId': toNodeId,
        'distance': distance,
        'accessible': accessible,
      };

  factory NavigationEdge.fromJson(Map<String, dynamic> json) {
    return NavigationEdge(
      edgeId: json['edgeId'] as String,
      fromNodeId: json['fromNodeId'] as String,
      toNodeId: json['toNodeId'] as String,
      distance: (json['distance'] as num).toDouble(),
      accessible: json['accessible'] as bool? ?? true,
    );
  }
}
