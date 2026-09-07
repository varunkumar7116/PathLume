import '../../models/ar_pose.dart';
import '../../models/coordinate_transform.dart';
import '../../models/floor_origin.dart';

class CoordinateAlignmentEngine {
  CoordinateTransform? _currentTransform;

  CoordinateTransform? get currentTransform => _currentTransform;

  /// Calculate the 3D rigid alignment transform connecting Floor Space to ARCore World Space
  CoordinateTransform computeAlignmentTransform({
    required FloorOrigin registeredOrigin,
    required ARPose currentARWorldPose,
  }) {
    final rotation = currentARWorldPose.rotation;

    final tempTransform = CoordinateTransform(
      translation: const Vector3D(x: 0.0, y: 0.0, z: 0.0),
      rotation: rotation,
      scale: 1.0,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    final rotatedOriginPos = tempTransform.transformFloorToAR(registeredOrigin.position);

    final translation = Vector3D(
      x: currentARWorldPose.position.x - rotatedOriginPos.x,
      y: currentARWorldPose.position.y - rotatedOriginPos.y,
      z: currentARWorldPose.position.z - rotatedOriginPos.z,
    );

    _currentTransform = CoordinateTransform(
      translation: translation,
      rotation: rotation,
      scale: 1.0,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    return _currentTransform!;
  }

  /// Converts a Floor Space coordinate (e.g. Navigation Node) to ARCore World Space
  Vector3D floorToARWorld(Vector3D floorPoint) {
    if (_currentTransform == null) return floorPoint;
    return _currentTransform!.transformFloorToAR(floorPoint);
  }

  /// Converts an ARCore World Space pose (e.g. Camera Pose) to Floor Space position
  Vector3D arWorldToFloor(Vector3D arWorldPoint) {
    if (_currentTransform == null) return arWorldPoint;
    return _currentTransform!.transformARToFloor(arWorldPoint);
  }

  void reset() {
    _currentTransform = null;
  }
}
