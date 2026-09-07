import 'dart:async';
import '../../core/platform/ar_channel.dart';
import '../../models/ar_pose.dart';
import '../../models/qr_detection.dart';
import '../../models/qr_payload.dart';

abstract class QRLocalizationProvider {
  Stream<QRDetection> get qrDetectionStream;
  Future<QRDetection?> parseRawString(String rawString);
  Future<void> startScanning();
  Future<void> stopScanning();
}

class AndroidQRLocalizationProvider implements QRLocalizationProvider {
  final StreamController<QRDetection> _controller = StreamController<QRDetection>.broadcast();
  bool _isScanning = false;

  bool get isScanning => _isScanning;

  @override
  Stream<QRDetection> get qrDetectionStream => _controller.stream;

  @override
  Future<QRDetection?> parseRawString(String rawString, {ARPose? pose, double? physicalSizeMeters}) async {
    final payload = QRPayload.deserialize(rawString);
    final detection = QRDetection(
      payload: payload,
      rawContent: rawString,
      physicalSizeMeters: physicalSizeMeters,
      pose: pose,
      poseAvailable: pose != null,
      poseSource: pose != null ? QRPoseSource.nativeArCore : QRPoseSource.none,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      isValidPayload: payload != null,
    );
    if (_isScanning) {
      _controller.add(detection);
    }
    return detection;
  }

  void emitDetection(QRDetection detection) {
    _controller.add(detection);
  }

  Future<QRDetection?> requestNativeQRPose(QRPayload payload) async {
    try {
      final Map<dynamic, dynamic>? res = await ARChannel.methodChannel.invokeMethod('requestQRPose');
      if (res != null && res['poseAvailable'] == true && res['pose'] != null) {
        final poseMap = Map<String, dynamic>.from(res['pose'] as Map);
        final arPose = ARPose.fromJson(poseMap);
        final detection = QRDetection(
          payload: payload,
          rawContent: payload.serialize(),
          pose: arPose,
          poseAvailable: true,
          poseSource: QRPoseSource.nativeArCore,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          isValidPayload: true,
        );
        _controller.add(detection);
        return detection;
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> startScanning() async {
    _isScanning = true;
  }

  @override
  Future<void> stopScanning() async {
    _isScanning = false;
  }

  void dispose() {
    _controller.close();
  }
}
