import 'ar_pose.dart';

enum NodeType {
  start,
  waypoint,
  turn,
  intersection,
  door,
  stair,
  elevator,
  destination,
}

extension NodeTypeX on NodeType {
  String get nameString {
    return toString().split('.').last.toUpperCase();
  }

  static NodeType fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'START':
        return NodeType.start;
      case 'TURN':
        return NodeType.turn;
      case 'INTERSECTION':
        return NodeType.intersection;
      case 'DOOR':
        return NodeType.door;
      case 'STAIR':
        return NodeType.stair;
      case 'ELEVATOR':
        return NodeType.elevator;
      case 'DESTINATION':
        return NodeType.destination;
      case 'WAYPOINT':
      default:
        return NodeType.waypoint;
    }
  }
}

class NavigationNode {
  final String nodeId;
  final String floorId;
  final NodeType type;
  final Vector3D position;
  final Quaternion4D rotation;
  final int sequence;
  final String name;

  const NavigationNode({
    required this.nodeId,
    required this.floorId,
    required this.type,
    required this.position,
    this.rotation = const Quaternion4D(),
    this.sequence = 0,
    required this.name,
  });

  NavigationNode copyWith({
    String? nodeId,
    String? floorId,
    NodeType? type,
    Vector3D? position,
    Quaternion4D? rotation,
    int? sequence,
    String? name,
  }) {
    return NavigationNode(
      nodeId: nodeId ?? this.nodeId,
      floorId: floorId ?? this.floorId,
      type: type ?? this.type,
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      sequence: sequence ?? this.sequence,
      name: name ?? this.name,
    );
  }

  Map<String, dynamic> toJson() => {
        'nodeId': nodeId,
        'id': nodeId,
        'floorId': floorId,
        'type': type.nameString,
        'position': position.toJson(),
        'rotation': rotation.toJson(),
        'sequence': sequence,
        'name': name,
      };

  factory NavigationNode.fromJson(Map<String, dynamic> json) {
    final id = json['nodeId'] as String? ?? json['id'] as String? ?? '';
    return NavigationNode(
      nodeId: id,
      floorId: json['floorId'] as String? ?? '',
      type: NodeTypeX.fromString(json['type'] as String?),
      position: Vector3D.fromJson(json['position'] as Map<String, dynamic>?),
      rotation: Quaternion4D.fromJson(json['rotation'] as Map<String, dynamic>?),
      sequence: (json['sequence'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
    );
  }
}
