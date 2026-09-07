import 'dart:math';
import 'ar_tracking_state.dart';

class Vector3D {
  final double x;
  final double y;
  final double z;

  const Vector3D({this.x = 0.0, this.y = 0.0, this.z = 0.0});

  double distanceTo(Vector3D other) {
    final dx = x - other.x;
    final dy = y - other.y;
    final dz = z - other.z;
    return sqrt(dx * dx + dy * dy + dz * dz);
  }

  bool get isFinite => x.isFinite && y.isFinite && z.isFinite;

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'z': z};

  factory Vector3D.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const Vector3D();
    return Vector3D(
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      z: (json['z'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class Quaternion4D {
  final double x;
  final double y;
  final double z;
  final double w;

  const Quaternion4D({this.x = 0.0, this.y = 0.0, this.z = 0.0, this.w = 1.0});

  bool get isFinite => x.isFinite && y.isFinite && z.isFinite && w.isFinite;

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'z': z, 'w': w};

  factory Quaternion4D.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const Quaternion4D();
    return Quaternion4D(
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      z: (json['z'] as num?)?.toDouble() ?? 0.0,
      w: (json['w'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

class ARPose {
  final Vector3D position;
  final Quaternion4D rotation;
  final ARTrackingState trackingState;
  final int timestamp;
  final bool isMarkerPlaced;

  const ARPose({
    this.position = const Vector3D(),
    this.rotation = const Quaternion4D(),
    this.trackingState = ARTrackingState.initializing,
    this.timestamp = 0,
    this.isMarkerPlaced = false,
  });

  bool get isValid {
    return trackingState == ARTrackingState.tracking &&
        position.x.isFinite &&
        position.y.isFinite &&
        position.z.isFinite &&
        rotation.x.isFinite &&
        rotation.y.isFinite &&
        rotation.z.isFinite &&
        rotation.w.isFinite;
  }

  int get ageMs {
    if (timestamp == 0) return 999999;
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    return age < 0 ? 0 : age;
  }

  bool isFresh({int maxAgeMs = 500}) {
    if (!isValid) return false;
    if (timestamp == 0) return false;
    return ageMs <= maxAgeMs;
  }

  Map<String, dynamic> toJson() => {
        'position': position.toJson(),
        'rotation': rotation.toJson(),
        'trackingState': trackingState.displayName,
        'timestamp': timestamp,
        'isMarkerPlaced': isMarkerPlaced,
      };

  factory ARPose.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ARPose();
    final rawTimestamp = (json['timestamp'] as num?)?.toInt() ?? 0;
    return ARPose(
      position: Vector3D.fromJson(json['position'] as Map<String, dynamic>?),
      rotation: Quaternion4D.fromJson(json['rotation'] as Map<String, dynamic>?),
      trackingState: ARTrackingStateX.fromString(json['trackingState'] as String?),
      timestamp: rawTimestamp > 0 ? rawTimestamp : DateTime.now().millisecondsSinceEpoch,
      isMarkerPlaced: json['isMarkerPlaced'] as bool? ?? false,
    );
  }
}
