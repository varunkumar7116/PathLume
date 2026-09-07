import 'package:flutter_test/flutter_test.dart';
import 'package:pathlume/models/ar_pose.dart';
import 'package:pathlume/models/ar_tracking_state.dart';

void main() {
  group('ARPose Tests', () {
    test('ARPose default values', () {
      const pose = ARPose();
      expect(pose.position.x, 0.0);
      expect(pose.position.y, 0.0);
      expect(pose.position.z, 0.0);
      expect(pose.rotation.w, 1.0);
      expect(pose.trackingState, ARTrackingState.initializing);
      expect(pose.isMarkerPlaced, false);
    });

    test('ARPose serialization & deserialization', () {
      const pose = ARPose(
        position: Vector3D(x: 1.2, y: 0.5, z: -3.4),
        rotation: Quaternion4D(x: 0.0, y: 0.707, z: 0.0, w: 0.707),
        trackingState: ARTrackingState.tracking,
        timestamp: 123456789,
        isMarkerPlaced: true,
      );

      final json = pose.toJson();
      final restored = ARPose.fromJson(json);

      expect(restored.position.x, 1.2);
      expect(restored.position.y, 0.5);
      expect(restored.position.z, -3.4);
      expect(restored.rotation.w, 0.707);
      expect(restored.trackingState, ARTrackingState.tracking);
      expect(restored.isMarkerPlaced, true);
    });
  });
}
