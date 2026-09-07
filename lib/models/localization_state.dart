enum LocalizationState {
  idle,
  scanningQr,
  qrDetected,
  validatingQr,
  initializingAr,
  waitingForQrPose,
  qrPoseAcquired,
  calculatingAlignment,
  alignmentValidated,
  localized,
  tracking,
  degraded,
  lost,
  error,
}

extension LocalizationStateX on LocalizationState {
  String get displayName {
    switch (this) {
      case LocalizationState.idle:
        return 'IDLE';
      case LocalizationState.scanningQr:
        return 'SCANNING QR';
      case LocalizationState.qrDetected:
        return 'QR DETECTED';
      case LocalizationState.validatingQr:
        return 'VALIDATING QR';
      case LocalizationState.initializingAr:
        return 'INITIALIZING AR';
      case LocalizationState.waitingForQrPose:
        return 'WAITING FOR QR POSE';
      case LocalizationState.qrPoseAcquired:
        return 'QR POSE ACQUIRED';
      case LocalizationState.calculatingAlignment:
        return 'CALCULATING ALIGNMENT';
      case LocalizationState.alignmentValidated:
        return 'ALIGNMENT VALIDATED';
      case LocalizationState.localized:
        return 'LOCALIZED';
      case LocalizationState.tracking:
        return 'TRACKING';
      case LocalizationState.degraded:
        return 'DEGRADED';
      case LocalizationState.lost:
        return 'LOST';
      case LocalizationState.error:
        return 'ERROR';
    }
  }
}


enum LocalizationConfidence {
  high,
  medium,
  low,
  unknown,
}

extension LocalizationConfidenceX on LocalizationConfidence {
  String get displayName {
    switch (this) {
      case LocalizationConfidence.high:
        return 'HIGH';
      case LocalizationConfidence.medium:
        return 'MEDIUM';
      case LocalizationConfidence.low:
        return 'LOW';
      case LocalizationConfidence.unknown:
        return 'UNKNOWN';
    }
  }
}
