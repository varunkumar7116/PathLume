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

  bool get isReady => registrationStatus.toLowerCase() == 'ready' && nodes.isNotEmpty;

  String get originId => origin?.originId ?? 'O001';
  int get graphVersion => version;
  String get qrPayload =>
      (origin?.qrCodePayload != null && origin!.qrCodePayload.isNotEmpty)
          ? origin!.qrCodePayload
          : 'PATHLUME_V1|$buildingId|$floorId|$originId';

  Map<String, dynamic> toJson() => {
        'floorId': floorId,
        'buildingId': buildingId,
        'floorNumber': floorNumber,
        'name': name,
        'status': registrationStatus.toUpperCase(),
        'originId': originId,
        'graphVersion': graphVersion,
        'qrPayload': qrPayload,
        'origin': origin?.toJson(),
        'nodes': nodes.map((n) => n.toJson()).toList(),
        'edges': edges.map((e) => e.toJson()).toList(),
        'destinations': destinations.map((d) => d.toJson()).toList(),
        'version': version,
        'registrationStatus': registrationStatus,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'coordinateSystem': coordinateMetadata,
        'coordinateMetadata': coordinateMetadata,
      };

  factory Floor.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String? ?? json['registrationStatus'] as String?;
    final normStatus = (statusStr ?? ((json['nodes'] as List<dynamic>?)?.isNotEmpty == true ? 'ready' : 'draft')).toLowerCase();

    final graphVer = (json['graphVersion'] as num?)?.toInt() ?? (json['version'] as num?)?.toInt() ?? 1;

    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is String) return DateTime.tryParse(val);
      if (val.runtimeType.toString().contains('Timestamp')) {
        try {
          return (val as dynamic).toDate() as DateTime?;
        } catch (_) {}
      }
      return null;
    }

    final nodesList = (json['nodes'] as List<dynamic>?)
            ?.map((n) => NavigationNode.fromJson(n as Map<String, dynamic>))
            .toList() ??
        [];

    final rawEdgesList = (json['edges'] as List<dynamic>?)
            ?.map((e) => NavigationEdge.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    // Auto-heal zero-distance edges by computing 3D Euclidean node distance
    final nodeMap = {for (final n in nodesList) n.nodeId: n};
    final healedEdges = rawEdgesList.map((e) {
      if (e.distance <= 0.0) {
        final fromNode = nodeMap[e.fromNodeId];
        final toNode = nodeMap[e.toNodeId];
        if (fromNode != null && toNode != null) {
          final computedDist = fromNode.position.distanceTo(toNode.position);
          final validDist = computedDist > 0.0 ? double.parse(computedDist.toStringAsFixed(2)) : 0.5;
          return NavigationEdge(
            edgeId: e.edgeId,
            fromNodeId: e.fromNodeId,
            toNodeId: e.toNodeId,
            distance: validDist > 0.0 ? validDist : 0.5,
            accessible: e.accessible,
          );
        }
        return NavigationEdge(
          edgeId: e.edgeId,
          fromNodeId: e.fromNodeId,
          toNodeId: e.toNodeId,
          distance: 0.5,
          accessible: e.accessible,
        );
      }
      return e;
    }).toList();

    return Floor(
      floorId: json['floorId'] as String? ?? '',
      buildingId: json['buildingId'] as String? ?? '',
      floorNumber: (json['floorNumber'] as num?)?.toInt() ?? 1,
      name: json['name'] as String? ?? 'Floor ${json['floorId']}',
      origin: json['origin'] != null
          ? FloorOrigin.fromJson(json['origin'] as Map<String, dynamic>)
          : null,
      nodes: nodesList,
      edges: healedEdges,
      destinations: (json['destinations'] as List<dynamic>?)
              ?.map((d) => Destination.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
      version: graphVer,
      registrationStatus: normStatus,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      coordinateMetadata: (json['coordinateSystem'] as Map<String, dynamic>?) ??
          (json['coordinateMetadata'] as Map<String, dynamic>?) ??
          const {
            'floorUnits': 'meters',
            'arWorldUnits': 'meters',
            'transformType': 'rigid',
            'scale': 1.0,
          },
    );
  }
}

