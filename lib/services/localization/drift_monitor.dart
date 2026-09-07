import '../../models/ar_pose.dart';
import '../../models/ar_tracking_state.dart';
import '../../models/localization_state.dart';

class DriftStatus {
  final LocalizationConfidence confidence;
  final double distanceTraveledMeters;
  final int durationSeconds;
  final bool isDegraded;
  final bool isLost;

  const DriftStatus({
    required this.confidence,
    required this.distanceTraveledMeters,
    required this.durationSeconds,
    required this.isDegraded,
    required this.isLost,
  });
}

class DriftMonitor {
  int? _localizationTimestamp;
  Vector3D? _lastPosePosition;
  double _distanceTraveled = 0.0;

  void startMonitoring() {
    _localizationTimestamp = DateTime.now().millisecondsSinceEpoch;
    _lastPosePosition = null;
    _distanceTraveled = 0.0;
  }

  DriftStatus updatePose(Vector3D currentPosition, ARTrackingState trackingState) {
    if (_lastPosePosition != null) {
      final delta = currentPosition.distanceTo(_lastPosePosition!);
      // Filter out small jitter (< 0.02m)
      if (delta > 0.02 && delta < 5.0) {
        _distanceTraveled += delta;
      }
    }
    _lastPosePosition = currentPosition;

    final now = DateTime.now().millisecondsSinceEpoch;
    final durationSec = _localizationTimestamp != null ? (now - _localizationTimestamp!) ~/ 1000 : 0;

    final isLost = trackingState == ARTrackingState.stopped || trackingState == ARTrackingState.error;
    final isDegraded = trackingState == ARTrackingState.paused || durationSec > 600 || _distanceTraveled > 100;

    LocalizationConfidence confidence = LocalizationConfidence.high;
    if (isLost) {
      confidence = LocalizationConfidence.unknown;
    } else if (isDegraded || durationSec > 300 || _distanceTraveled > 50) {
      confidence = LocalizationConfidence.medium;
    } else if (durationSec > 900 || _distanceTraveled > 200) {
      confidence = LocalizationConfidence.low;
    }

    return DriftStatus(
      confidence: confidence,
      distanceTraveledMeters: _distanceTraveled,
      durationSeconds: durationSec,
      isDegraded: isDegraded,
      isLost: isLost,
    );
  }

  void reset() {
    _localizationTimestamp = null;
    _lastPosePosition = null;
    _distanceTraveled = 0.0;
  }
}
