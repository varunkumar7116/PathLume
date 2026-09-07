import 'floor_origin.dart';
import 'navigation_node.dart';
import 'navigation_edge.dart';
import 'destination.dart';

class Floor {
  final String floorId;
  final String buildingId;
  final int floorNumber;
  final String name;
  final FloorOrigin? origin;
  final List<NavigationNode> nodes;
  final List<NavigationEdge> edges;
  final List<Destination> destinations;

  // Versioning & Registration Status Metadata
  final int version;
  final String registrationStatus; // 'draft', 'registering', 'validating', 'ready', 'error'
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> coordinateMetadata;

  const Floor({
    required this.floorId,
    required this.buildingId,
    required this.floorNumber,
    required this.name,
    this.origin,
    this.nodes = const [],
    this.edges = const [],
    this.destinations = const [],
    this.version = 1,
    this.registrationStatus = 'draft',
    this.createdAt,
    this.updatedAt,
    this.coordinateMetadata = const {
      'floorUnits': 'meters',
      'arWorldUnits': 'meters',
      'transformType': 'rigid',
      'scale': 1.0,
    },
  });

  bool get isReady => registrationStatus == 'ready' && nodes.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'floorId': floorId,
        'buildingId': buildingId,
        'floorNumber': floorNumber,
        'name': name,
        'origin': origin?.toJson(),
        'nodes': nodes.map((n) => n.toJson()).toList(),
        'edges': edges.map((e) => e.toJson()).toList(),
        'destinations': destinations.map((d) => d.toJson()).toList(),
        'version': version,
        'registrationStatus': registrationStatus,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'coordinateMetadata': coordinateMetadata,
      };

  factory Floor.fromJson(Map<String, dynamic> json) {
    return Floor(
      floorId: json['floorId'] as String,
      buildingId: json['buildingId'] as String,
      floorNumber: json['floorNumber'] as int,
      name: json['name'] as String,
      origin: json['origin'] != null
          ? FloorOrigin.fromJson(json['origin'] as Map<String, dynamic>)
          : null,
      nodes: (json['nodes'] as List<dynamic>?)
              ?.map((n) => NavigationNode.fromJson(n as Map<String, dynamic>))
              .toList() ??
          [],
      edges: (json['edges'] as List<dynamic>?)
              ?.map((e) => NavigationEdge.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      destinations: (json['destinations'] as List<dynamic>?)
              ?.map((d) => Destination.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
      version: (json['version'] as num?)?.toInt() ?? 1,
      registrationStatus: (json['registrationStatus'] as String?) ??
          ((json['nodes'] as List<dynamic>?)?.isNotEmpty == true ? 'ready' : 'draft'),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'] as String) : null,
      coordinateMetadata: (json['coordinateMetadata'] as Map<String, dynamic>?) ??
          const {
            'floorUnits': 'meters',
            'arWorldUnits': 'meters',
            'transformType': 'rigid',
            'scale': 1.0,
          },
    );
  }
}
