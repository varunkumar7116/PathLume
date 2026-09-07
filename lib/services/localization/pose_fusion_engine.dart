import 'dart:developer' as developer;
import '../../models/ar_pose.dart';
import '../../models/ar_tracking_state.dart';
import '../../models/tracking_quality.dart';

class FusedPoseResult {
  final ARPose fusedPose;
  final TrackingQuality quality;
  final bool isOutlier;
  final String source;

  const FusedPoseResult({
    required this.fusedPose,
    required this.quality,
    this.isOutlier = false,
    this.source = 'arcore',
  });
}

class PoseFusionEngine {
  final double maxVelocityMetersPerSec;
  final double maxRotationDegPerSec;
  final int maxPoseAgeMs;
  final double alphaSmoothing;

  ARPose? _lastAcceptedPose;
  int _lastAcceptedTime = 0;
  int _consecutiveOutliers = 0;

  PoseFusionEngine({
    this.maxVelocityMetersPerSec = 3.5, // Max human indoor walking + turn velocity
    this.maxRotationDegPerSec = 360.0,
    this.maxPoseAgeMs = 500,
    this.alphaSmoothing = 0.85, // Low latency, 85% fresh / 15% smoothed
  });

  void reset() {
    _lastAcceptedPose = null;
    _lastAcceptedTime = 0;
    _consecutiveOutliers = 0;
  }

  FusedPoseResult processPose({
    required ARPose rawPose,
    Map<String, dynamic>? augmentedImageMap,
    bool depthAvailable = false,
    String anchorState = 'TRACKING',
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. Timestamp Validation
    if (rawPose.timestamp <= 0) {
      return _buildFallbackResult(rawPose, 'invalid_timestamp');
    }
    final ageMs = rawPose.ageMs;
    if (ageMs > maxPoseAgeMs) {
      return _buildFallbackResult(rawPose, 'stale_pose');
    }

    // 2. Outlier Rejection via Velocity Check
    bool isOutlier = false;
    if (_lastAcceptedPose != null && _lastAcceptedTime > 0) {
      final dtSec = (now - _lastAcceptedTime) / 1000.0;
      if (dtSec > 0.001) {
        final dist = rawPose.position.distanceTo(_lastAcceptedPose!.position);
        final velocity = dist / dtSec;

        if (velocity > maxVelocityMetersPerSec) {
          _consecutiveOutliers++;
          developer.log('[PATHLUME][FUSION] Outlier velocity detected: ${velocity.toStringAsFixed(2)} m/s (max: $maxVelocityMetersPerSec m/s), consecutive: $_consecutiveOutliers');

          // Hysteresis: Allow fast jump if 5 consecutive frames confirm movement
          if (_consecutiveOutliers < 5) {
            isOutlier = true;
          } else {
            _consecutiveOutliers = 0;
            developer.log('[PATHLUME][FUSION] Hysteresis reset: accepting new position trajectory after 5 consecutive frames');
          }
        } else {
          _consecutiveOutliers = 0;
        }
      }
    }

    final activePose = (isOutlier && _lastAcceptedPose != null)
        ? _lastAcceptedPose!
        : rawPose;

    // 3. Low-Latency Temporal Smoothing (Exponential Moving Average)
    Vector3D smoothedPosition = activePose.position;
    if (_lastAcceptedPose != null && !isOutlier) {
      smoothedPosition = Vector3D(
        x: _lastAcceptedPose!.position.x * (1.0 - alphaSmoothing) + activePose.position.x * alphaSmoothing,
        y: _lastAcceptedPose!.position.y * (1.0 - alphaSmoothing) + activePose.position.y * alphaSmoothing,
        z: _lastAcceptedPose!.position.z * (1.0 - alphaSmoothing) + activePose.position.z * alphaSmoothing,
      );
    }

    final fusedPose = ARPose(
      position: smoothedPosition,
      rotation: activePose.rotation,
      trackingState: activePose.trackingState,
      timestamp: now,
      isMarkerPlaced: activePose.isMarkerPlaced,
    );

    if (!isOutlier) {
      _lastAcceptedPose = fusedPose;
      _lastAcceptedTime = now;
    }

    // 4. Derive Tracking Quality Metrics
    final String imageState = augmentedImageMap?['trackingState'] as String? ?? 'NONE';
    final TrackingQualityState qualityState = _calculateQualityState(
      rawPose: rawPose,
      isOutlier: isOutlier,
      ageMs: ageMs,
      imageState: imageState,
    );

    final quality = TrackingQuality(
      state: qualityState,
      poseAgeMs: ageMs,
      positionConfidence: isOutlier ? 0.3 : (rawPose.trackingState == ARTrackingState.tracking ? 0.95 : 0.5),
      rotationConfidence: rawPose.trackingState == ARTrackingState.tracking ? 0.95 : 0.5,
      imageTrackingState: imageState,
      depthAvailable: depthAvailable,
      anchorTrackingState: anchorState,
      driftEstimate: isOutlier ? 0.5 : 0.05,
      relocalizationAvailable: imageState == 'TRACKING',
    );

    return FusedPoseResult(
      fusedPose: fusedPose,
      quality: quality,
      isOutlier: isOutlier,
      source: imageState == 'TRACKING' ? 'augmented_image_fused' : 'arcore_6dof',
    );
  }

  TrackingQualityState _calculateQualityState({
    required ARPose rawPose,
    required bool isOutlier,
    required int ageMs,
    required String imageState,
  }) {
    if (rawPose.trackingState == ARTrackingState.error || rawPose.trackingState == ARTrackingState.stopped) {
      return TrackingQualityState.lost;
    }
    if (rawPose.trackingState == ARTrackingState.initializing || rawPose.trackingState == ARTrackingState.paused) {
      return TrackingQualityState.relocalizing;
    }
    if (isOutlier || ageMs > 300) {
      return TrackingQualityState.poor;
    }
    if (imageState == 'TRACKING' || rawPose.trackingState == ARTrackingState.tracking) {
      return TrackingQualityState.good;
    }
    return TrackingQualityState.fair;
  }

  FusedPoseResult _buildFallbackResult(ARPose rawPose, String reason) {
    return FusedPoseResult(
      fusedPose: _lastAcceptedPose ?? rawPose,
      quality: const TrackingQuality(
        state: TrackingQualityState.poor,
        poseAgeMs: 999,
        positionConfidence: 0.0,
        rotationConfidence: 0.0,
      ),
      isOutlier: true,
      source: 'fallback_$reason',
    );
  }
}
