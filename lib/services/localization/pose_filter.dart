import '../../models/ar_pose.dart';

class PoseFilter {
  double positionSmoothingFactor; // alpha parameter: 0.0 (max smooth) to 1.0 (no filter)
  bool enabled;

  Vector3D? _filteredPosition;
  Quaternion4D? _filteredRotation;

  PoseFilter({
    this.positionSmoothingFactor = 0.35,
    this.enabled = true,
  });

  /// Filter position vector using Exponential Moving Average (EMA)
  Vector3D filterPosition(Vector3D rawPosition) {
    if (!enabled) return rawPosition;

    if (_filteredPosition == null) {
      _filteredPosition = rawPosition;
      return rawPosition;
    }

    final alpha = positionSmoothingFactor.clamp(0.01, 1.0);
    final smoothX = alpha * rawPosition.x + (1.0 - alpha) * _filteredPosition!.x;
    final smoothY = alpha * rawPosition.y + (1.0 - alpha) * _filteredPosition!.y;
    final smoothZ = alpha * rawPosition.z + (1.0 - alpha) * _filteredPosition!.z;

    _filteredPosition = Vector3D(x: smoothX, y: smoothY, z: smoothZ);
    return _filteredPosition!;
  }

  /// Filter orientation quaternion using Normalized Linear Interpolation (NLERP)
  Quaternion4D filterRotation(Quaternion4D rawRotation) {
    if (!enabled) return rawRotation;

    if (_filteredRotation == null) {
      _filteredRotation = rawRotation;
      return rawRotation;
    }

    final alpha = positionSmoothingFactor.clamp(0.01, 1.0);
    final interpX = alpha * rawRotation.x + (1.0 - alpha) * _filteredRotation!.x;
    final interpY = alpha * rawRotation.y + (1.0 - alpha) * _filteredRotation!.y;
    final interpZ = alpha * rawRotation.z + (1.0 - alpha) * _filteredRotation!.z;
    final interpW = alpha * rawRotation.w + (1.0 - alpha) * _filteredRotation!.w;

    _filteredRotation = Quaternion4D(x: interpX, y: interpY, z: interpZ, w: interpW);
    return _filteredRotation!;
  }

  void reset() {
    _filteredPosition = null;
    _filteredRotation = null;
  }
}
