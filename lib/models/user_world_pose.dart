import 'ar_pose.dart';
import 'ar_tracking_state.dart';
import 'localization_state.dart';

class UserWorldPose {
  final Vector3D position;
  final Quaternion4D rotation;
  final ARTrackingState trackingState;
  final int timestamp;
  final LocalizationConfidence confidence;

  const UserWorldPose({
    this.position = const Vector3D(),
    this.rotation = const Quaternion4D(),
    this.trackingState = ARTrackingState.initializing,
    required this.timestamp,
    this.confidence = LocalizationConfidence.unknown,
  });

  int get ageMs {
    if (timestamp <= 0) return 999999;
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - timestamp;
    return diff < 0 ? 0 : diff;
  }

  bool isFresh({int maxAgeMs = 500}) {
    return timestamp > 0 && ageMs <= maxAgeMs && position.isFinite && rotation.isFinite;
  }

  Map<String, dynamic> toJson() => {
        'position': position.toJson(),
        'rotation': rotation.toJson(),
        'trackingState': trackingState.displayName,
        'timestamp': timestamp,
        'confidence': confidence.displayName,
      };

  factory UserWorldPose.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return UserWorldPose(timestamp: DateTime.now().millisecondsSinceEpoch);
    }
    return UserWorldPose(
      position: Vector3D.fromJson(json['position'] as Map<String, dynamic>?),
      rotation: Quaternion4D.fromJson(json['rotation'] as Map<String, dynamic>?),
      trackingState: ARTrackingStateX.fromString(json['trackingState'] as String?),
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
      confidence: LocalizationConfidence.values.firstWhere(
        (c) => c.displayName == json['confidence'],
        orElse: () => LocalizationConfidence.unknown,
      ),
    );
  }
}
