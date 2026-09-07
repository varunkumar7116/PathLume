import 'ar_pose.dart';

class FloorOrigin {
  final String originId;
  final String floorId;
  final Vector3D position;
  final Quaternion4D rotation;
  final String qrCodePayload;
  final double qrPhysicalWidthMeters;
  final double qrOrientationDegrees;
  final DateTime createdAt;

  const FloorOrigin({
    required this.originId,
    required this.floorId,
    required this.position,
    required this.rotation,
    required this.qrCodePayload,
    this.qrPhysicalWidthMeters = 0.20,
    this.qrOrientationDegrees = 0.0,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'originId': originId,
        'floorId': floorId,
        'position': position.toJson(),
        'rotation': rotation.toJson(),
        'qrCodePayload': qrCodePayload,
        'qrPhysicalWidthMeters': qrPhysicalWidthMeters,
        'qrOrientationDegrees': qrOrientationDegrees,
        'createdAt': createdAt.toIso8601String(),
      };

  factory FloorOrigin.fromJson(Map<String, dynamic> json) {
    return FloorOrigin(
      originId: json['originId'] as String,
      floorId: json['floorId'] as String,
      position: Vector3D.fromJson(json['position'] as Map<String, dynamic>?),
      rotation: Quaternion4D.fromJson(json['rotation'] as Map<String, dynamic>?),
      qrCodePayload: json['qrCodePayload'] as String? ?? '',
      qrPhysicalWidthMeters: (json['qrPhysicalWidthMeters'] as num?)?.toDouble() ?? 0.20,
      qrOrientationDegrees: (json['qrOrientationDegrees'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

