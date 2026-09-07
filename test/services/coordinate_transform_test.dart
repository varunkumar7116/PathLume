import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathlume/models/ar_pose.dart';
import 'package:pathlume/models/coordinate_transform.dart';

void main() {
  group('CoordinateTransform Tests', () {
    test('Forward and Inverse Transform Round-Trip Precision', () {
      const transform = CoordinateTransform(
        translation: Vector3D(x: 3.5, y: 0.2, z: -10.0),
        rotation: Quaternion4D(x: 0.0, y: 0.0, z: 0.0, w: 1.0),
        scale: 1.0,
        createdAt: 0,
      );

      const originalFloorPoint = Vector3D(x: 4.2, y: 0.0, z: 12.7);

      // Forward: Floor -> AR World
      final arWorldPoint = transform.transformFloorToAR(originalFloorPoint);
      expect(arWorldPoint.x, closeTo(7.7, 1e-4));
      expect(arWorldPoint.y, closeTo(0.2, 1e-4));
      expect(arWorldPoint.z, closeTo(2.7, 1e-4));

      // Inverse: AR World -> Floor
      final recoveredFloorPoint = transform.transformARToFloor(arWorldPoint);
      expect(recoveredFloorPoint.x, closeTo(originalFloorPoint.x, 1e-4));
      expect(recoveredFloorPoint.y, closeTo(originalFloorPoint.y, 1e-4));
      expect(recoveredFloorPoint.z, closeTo(originalFloorPoint.z, 1e-4));
    });

    test('90 Degree Y-Axis Rotation Transform Round-Trip', () {
      // 90 degrees rotation around Y axis: sin(45 deg) = 0.7071
      const halfAngle = 90.0 * (pi / 180.0) / 2.0;
      final rotY90 = Quaternion4D(
        x: 0.0,
        y: sin(halfAngle),
        z: 0.0,
        w: cos(halfAngle),
      );

      final transform = CoordinateTransform(
        translation: const Vector3D(x: 2.0, y: 0.0, z: 5.0),
        rotation: rotY90,
        scale: 1.0,
        createdAt: 0,
      );

      const floorPoint = Vector3D(x: 1.0, y: 0.0, z: 0.0);
      final arPoint = transform.transformFloorToAR(floorPoint);

      // Round trip check
      final recoveredPoint = transform.transformARToFloor(arPoint);
      expect(recoveredPoint.x, closeTo(floorPoint.x, 1e-4));
      expect(recoveredPoint.y, closeTo(floorPoint.y, 1e-4));
      expect(recoveredPoint.z, closeTo(floorPoint.z, 1e-4));
    });

    test('180 Degree Y-Axis Rotation Transform Round-Trip', () {
      const rotY180 = Quaternion4D(x: 0.0, y: 1.0, z: 0.0, w: 0.0);

      const transform = CoordinateTransform(
        translation: Vector3D(x: 0.0, y: 0.0, z: 0.0),
        rotation: rotY180,
        scale: 1.0,
        createdAt: 0,
      );

      const floorPoint = Vector3D(x: 3.0, y: 0.0, z: 4.0);
      final arPoint = transform.transformFloorToAR(floorPoint);

      final recoveredPoint = transform.transformARToFloor(arPoint);
      expect(recoveredPoint.x, closeTo(floorPoint.x, 1e-4));
      expect(recoveredPoint.y, closeTo(floorPoint.y, 1e-4));
      expect(recoveredPoint.z, closeTo(floorPoint.z, 1e-4));
    });

    test('270 Degree Y-Axis Rotation Transform Round-Trip', () {
      const halfAngle = 270.0 * (pi / 180.0) / 2.0;
      final rotY270 = Quaternion4D(
        x: 0.0,
        y: sin(halfAngle),
        z: 0.0,
        w: cos(halfAngle),
      );

      final transform = CoordinateTransform(
        translation: const Vector3D(x: -1.0, y: 0.5, z: 3.0),
        rotation: rotY270,
        scale: 1.0,
        createdAt: 0,
      );

      const floorPoint = Vector3D(x: 5.0, y: 1.0, z: -2.0);
      final arPoint = transform.transformFloorToAR(floorPoint);

      final recoveredPoint = transform.transformARToFloor(arPoint);
      expect(recoveredPoint.x, closeTo(floorPoint.x, 1e-4));
      expect(recoveredPoint.y, closeTo(floorPoint.y, 1e-4));
      expect(recoveredPoint.z, closeTo(floorPoint.z, 1e-4));
    });

  });
}

