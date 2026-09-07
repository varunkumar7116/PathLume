enum RegistrationState {
  idle,
  preparing,
  trackingInitializing,
  ready,
  originSet,
  registering,
  paused,
  completing,
  validating,
  processing,
  completed,
  error,
}

extension RegistrationStateX on RegistrationState {
  String get displayName {
    switch (this) {
      case RegistrationState.idle:
        return 'IDLE';
      case RegistrationState.preparing:
        return 'PREPARING';
      case RegistrationState.trackingInitializing:
        return 'TRACKING INIT';
      case RegistrationState.ready:
        return 'READY';
      case RegistrationState.originSet:
        return 'ORIGIN SET';
      case RegistrationState.registering:
        return 'REGISTERING';
      case RegistrationState.paused:
        return 'PAUSED';
      case RegistrationState.completing:
        return 'COMPLETING';
      case RegistrationState.validating:
        return 'VALIDATING';
      case RegistrationState.processing:
        return 'PROCESSING';
      case RegistrationState.completed:
        return 'COMPLETED';
      case RegistrationState.error:
        return 'ERROR';
    }
  }
}
