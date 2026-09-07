import 'ar_pose.dart';

class CoordinateTransform {
  final Vector3D translation;
  final Quaternion4D rotation;
  final double scale;
  final int createdAt;

  const CoordinateTransform({
    this.translation = const Vector3D(x: 0.0, y: 0.0, z: 0.0),
    this.rotation = const Quaternion4D(x: 0.0, y: 0.0, z: 0.0, w: 1.0),
    this.scale = 1.0,
    required this.createdAt,
  });

  /// Forward transform: Floor Space -> ARCore World Space
  /// ARWorldPoint = T(FloorPoint) = R * (FloorPoint * scale) + translation
  Vector3D transformFloorToAR(Vector3D floorPoint) {
    // Scaled point
    final sx = floorPoint.x * scale;
    final sy = floorPoint.y * scale;
    final sz = floorPoint.z * scale;

    // Rotate using Quaternion rotation
    final rx = rotation.x;
    final ry = rotation.y;
    final rz = rotation.z;
    final rw = rotation.w;

    // Quaternion multiplication: q * v * q^-1
    final ix = rw * sx + ry * sz - rz * sy;
    final iy = rw * sy + rz * sx - rx * sz;
    final iz = rw * sz + rx * sy - ry * sx;
    final iw = -rx * sx - ry * sy - rz * sz;

    final rotX = ix * rw + iw * -rx + iy * -rz - iz * -ry;
    final rotY = iy * rw + iw * -ry + iz * -rx - ix * -rz;
    final rotZ = iz * rw + iw * -rz + ix * -ry - iy * -rx;

    return Vector3D(
      x: rotX + translation.x,
      y: rotY + translation.y,
      z: rotZ + translation.z,
    );
  }

  /// Inverse transform: ARCore World Space -> Floor Space
  /// FloorPoint = T^-1(ARWorldPoint) = R^-1 * (ARWorldPoint - translation) / scale
  Vector3D transformARToFloor(Vector3D arPoint) {
    final dx = arPoint.x - translation.x;
    final dy = arPoint.y - translation.y;
    final dz = arPoint.z - translation.z;

    // Inverse quaternion: (-x, -y, -z, w)
    final rx = -rotation.x;
    final ry = -rotation.y;
    final rz = -rotation.z;
    final rw = rotation.w;

    final ix = rw * dx + ry * dz - rz * dy;
    final iy = rw * dy + rz * dx - rx * dz;
    final iz = rw * dz + rx * dy - ry * dx;
    final iw = -rx * dx - ry * dy - rz * dz;

    final rotX = ix * rw + iw * -rx + iy * -rz - iz * -ry;
    final rotY = iy * rw + iw * -ry + iz * -rx - ix * -rz;
    final rotZ = iz * rw + iw * -rz + ix * -ry - iy * -rx;

    final invScale = scale == 0.0 ? 1.0 : 1.0 / scale;

    return Vector3D(
      x: rotX * invScale,
      y: rotY * invScale,
      z: rotZ * invScale,
    );
  }

  Map<String, dynamic> toJson() => {
        'translation': translation.toJson(),
        'rotation': rotation.toJson(),
        'scale': scale,
        'createdAt': createdAt,
      };

  factory CoordinateTransform.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return CoordinateTransform(createdAt: DateTime.now().millisecondsSinceEpoch);
    }
    return CoordinateTransform(
      translation: Vector3D.fromJson(json['translation'] as Map<String, dynamic>?),
      rotation: Quaternion4D.fromJson(json['rotation'] as Map<String, dynamic>?),
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
    );
  }
}
