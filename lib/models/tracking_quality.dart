enum TrackingQualityState {
  good,
  fair,
  poor,
  relocalizing,
  lost;

  String get displayName {
    switch (this) {
      case TrackingQualityState.good:
        return 'GOOD';
      case TrackingQualityState.fair:
        return 'FAIR';
      case TrackingQualityState.poor:
        return 'POOR';
      case TrackingQualityState.relocalizing:
        return 'RELOCALIZING';
      case TrackingQualityState.lost:
        return 'LOST';
    }
  }
}

class TrackingQuality {
  final TrackingQualityState state;
  final int poseAgeMs;
  final double positionConfidence;
  final double rotationConfidence;
  final String imageTrackingState;
  final bool depthAvailable;
  final String anchorTrackingState;
  final double driftEstimate;
  final bool relocalizationAvailable;

  const TrackingQuality({
    this.state = TrackingQualityState.good,
    this.poseAgeMs = 0,
    this.positionConfidence = 1.0,
    this.rotationConfidence = 1.0,
    this.imageTrackingState = 'NONE',
    this.depthAvailable = false,
    this.anchorTrackingState = 'TRACKING',
    this.driftEstimate = 0.0,
    this.relocalizationAvailable = true,
  });

  bool get isUsable =>
      (state == TrackingQualityState.good || state == TrackingQualityState.fair) &&
      poseAgeMs <= 500;

  Map<String, dynamic> toJson() => {
        'state': state.displayName,
        'poseAgeMs': poseAgeMs,
        'positionConfidence': positionConfidence,
        'rotationConfidence': rotationConfidence,
        'imageTrackingState': imageTrackingState,
        'depthAvailable': depthAvailable,
        'anchorTrackingState': anchorTrackingState,
        'driftEstimate': driftEstimate,
        'relocalizationAvailable': relocalizationAvailable,
      };
}
