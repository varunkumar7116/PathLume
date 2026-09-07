enum ARTrackingState {
  initializing,
  tracking,
  paused,
  stopped,
  error,
}

extension ARTrackingStateX on ARTrackingState {
  String get displayName {
    switch (this) {
      case ARTrackingState.initializing:
        return 'INITIALIZING';
      case ARTrackingState.tracking:
        return 'TRACKING';
      case ARTrackingState.paused:
        return 'PAUSED';
      case ARTrackingState.stopped:
        return 'STOPPED';
      case ARTrackingState.error:
        return 'ERROR';
    }
  }

  static ARTrackingState fromString(String? state) {
    switch (state?.toUpperCase()) {
      case 'TRACKING':
        return ARTrackingState.tracking;
      case 'PAUSED':
        return ARTrackingState.paused;
      case 'STOPPED':
        return ARTrackingState.stopped;
      case 'ERROR':
        return ARTrackingState.error;
      case 'INITIALIZING':
      default:
        return ARTrackingState.initializing;
    }
  }
}
