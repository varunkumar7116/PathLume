import 'dart:async';
import '../../models/ar_pose.dart';
import '../../models/ar_tracking_state.dart';
import '../../models/qr_detection.dart';
import '../../models/qr_payload.dart';
import 'qr_localization_provider.dart';

enum SimulationScenario {
  perfectMatchWithPose,
  payloadOnlyNoPose,
  invalidPayload,
  wrongFloor,
}

class SimulatedQRLocalizationProvider implements QRLocalizationProvider {
  final StreamController<QRDetection> _controller = StreamController<QRDetection>.broadcast();
  SimulationScenario _scenario = SimulationScenario.perfectMatchWithPose;

  String targetBuildingId;
  String targetFloorId;
  String targetOriginId;
  Vector3D simulatedPosePosition;
  Quaternion4D simulatedPoseRotation;

  SimulatedQRLocalizationProvider({
    this.targetBuildingId = 'building_001',
    this.targetFloorId = 'floor_001',
    this.targetOriginId = 'origin_001',
    this.simulatedPosePosition = const Vector3D(x: 2.0, y: 0.0, z: 3.0),
    this.simulatedPoseRotation = const Quaternion4D(x: 0.0, y: 0.0, z: 0.0, w: 1.0),
  });

  void setScenario(SimulationScenario scenario) {
    _scenario = scenario;
  }

  @override
  Stream<QRDetection> get qrDetectionStream => _controller.stream;

  @override
  Future<QRDetection?> parseRawString(String rawString) async {
    final payload = QRPayload.deserialize(rawString);
    return QRDetection(
      payload: payload,
      rawContent: rawString,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      isValidPayload: payload != null,
      poseAvailable: false,
      poseSource: QRPoseSource.none,
    );
  }

  @override
  Future<void> startScanning() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    late QRDetection detection;

    switch (_scenario) {
      case SimulationScenario.perfectMatchWithPose:
        final payload = QRPayload(
          buildingId: targetBuildingId,
          floorId: targetFloorId,
          originId: targetOriginId,
          timestamp: timestamp,
        );
        detection = QRDetection(
          payload: payload,
          rawContent: payload.serialize(),
          pose: ARPose(
            position: simulatedPosePosition,
            rotation: simulatedPoseRotation,
            trackingState: ARTrackingState.tracking,
          ),
          poseAvailable: true,
          poseSource: QRPoseSource.simulated,
          timestamp: timestamp,
          isValidPayload: true,
        );
        break;

      case SimulationScenario.payloadOnlyNoPose:
        final payload = QRPayload(
          buildingId: targetBuildingId,
          floorId: targetFloorId,
          originId: targetOriginId,
          timestamp: timestamp,
        );
        detection = QRDetection(
          payload: payload,
          rawContent: payload.serialize(),
          pose: null,
          poseAvailable: false,
          poseSource: QRPoseSource.none,
          timestamp: timestamp,
          isValidPayload: true,
        );
        break;

      case SimulationScenario.invalidPayload:
        detection = QRDetection(
          payload: null,
          rawContent: 'INVALID_CORRUPTED_QR_DATA',
          poseAvailable: false,
          poseSource: QRPoseSource.none,
          timestamp: timestamp,
          isValidPayload: false,
        );
        break;

      case SimulationScenario.wrongFloor:
        final payload = QRPayload(
          buildingId: targetBuildingId,
          floorId: 'floor_WRONG_999',
          originId: 'origin_WRONG_999',
          timestamp: timestamp,
        );
        detection = QRDetection(
          payload: payload,
          rawContent: payload.serialize(),
          poseAvailable: false,
          poseSource: QRPoseSource.none,
          timestamp: timestamp,
          isValidPayload: true,
        );
        break;
    }

    _controller.add(detection);
  }

  @override
  Future<void> stopScanning() async {}

  void dispose() {
    _controller.close();
  }
}

