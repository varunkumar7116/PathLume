import 'dart:async';
import '../../models/ar_pose.dart';
import '../../models/ar_tracking_state.dart';
import '../../models/floor.dart';
import '../../models/floor_origin.dart';
import '../../models/localization_state.dart';
import '../../models/navigation_session.dart';
import '../../models/qr_detection.dart';
import '../../models/qr_payload.dart';
import '../../models/user_world_pose.dart';
import '../ar_service.dart';
import '../qr/qr_localization_provider.dart';
import '../repositories/building_repository.dart';
import 'coordinate_alignment_engine.dart';
import 'drift_monitor.dart';

class LocalizationService {
  final ARService _arService;
  final QRLocalizationProvider _qrProvider;
  final BuildingRepository _repository;
  final CoordinateAlignmentEngine _alignmentEngine = CoordinateAlignmentEngine();
  final DriftMonitor _driftMonitor = DriftMonitor();

  LocalizationState _state = LocalizationState.idle;
  LocalizationConfidence _confidence = LocalizationConfidence.unknown;

  String? _targetBuildingId;
  String? _targetFloorId;
  Floor? _activeFloor;

  NavigationSession? _currentSession;

  StreamSubscription<ARPose>? _poseSub;
  StreamSubscription<ARTrackingState>? _trackingSub;
  StreamSubscription<QRDetection>? _qrSub;

  final StreamController<NavigationSession> _sessionController =
      StreamController<NavigationSession>.broadcast();
  final StreamController<LocalizationState> _stateController =
      StreamController<LocalizationState>.broadcast();

  LocalizationService({
    required ARService arService,
    required QRLocalizationProvider qrProvider,
    required BuildingRepository repository,
  })  : _arService = arService,
        _qrProvider = qrProvider,
        _repository = repository;

  LocalizationState get state => _state;
  LocalizationConfidence get confidence => _confidence;
  NavigationSession? get currentSession => _currentSession;
  CoordinateAlignmentEngine get alignmentEngine => _alignmentEngine;

  Stream<NavigationSession> get sessionStream => _sessionController.stream;
  Stream<LocalizationState> get stateStream => _stateController.stream;

  Future<void> startLocalizationSession({
    required String buildingId,
    required String floorId,
    QRPayload? payload,
  }) async {
    _targetBuildingId = buildingId;
    _targetFloorId = floorId;
    _activeFloor = await _repository.getFloorById(buildingId, floorId);

    _updateState(LocalizationState.scanningQr);

    _qrSub?.cancel();
    _qrSub = _qrProvider.qrDetectionStream.listen((detection) {
      _processQRDetection(detection);
    });

    _qrProvider.startScanning();

    if (payload != null) {
      final detection = await _qrProvider.parseRawString(payload.serialize());
      if (detection != null) {
        await _processQRDetection(detection);
      }
    }
  }

  Future<void> _processQRDetection(QRDetection detection) async {
    if (_state != LocalizationState.scanningQr && _state != LocalizationState.waitingForQrPose) return;

    if (!detection.isValidPayload || detection.payload == null) {
      _updateState(LocalizationState.error);
      return;
    }

    final payload = detection.payload!;
    if (payload.buildingId != _targetBuildingId || payload.floorId != _targetFloorId) {
      _updateState(LocalizationState.error);
      return;
    }

    if (_state == LocalizationState.scanningQr) {
      _updateState(LocalizationState.qrDetected);
      _updateState(LocalizationState.validatingQr);
      await _qrProvider.stopScanning();

      _updateState(LocalizationState.initializingAr);
      final arSuccess = await _arService.startARSession();

      if (!arSuccess) {
        _updateState(LocalizationState.error);
        return;
      }
    }

    final initialPose = detection.pose ?? const ARPose(position: Vector3D(x: 0, y: 0, z: 0));

    _updateState(LocalizationState.qrPoseAcquired);
    _updateState(LocalizationState.calculatingAlignment);

    final origin = _activeFloor?.origin ?? FloorOrigin(
      originId: payload.originId,
      floorId: payload.floorId,
      position: const Vector3D(x: 0, y: 0, z: 0),
      rotation: const Quaternion4D(),
      qrCodePayload: payload.serialize(),
      createdAt: DateTime.now(),
    );

    final transform = _alignmentEngine.computeAlignmentTransform(
      registeredOrigin: origin,
      currentARWorldPose: initialPose,
    );

    _updateState(LocalizationState.alignmentValidated);

    _driftMonitor.startMonitoring();
    _updateState(LocalizationState.localized);

    _setupARSubscriptions(transform);
  }

  /// Explicitly submit a QR pose update (e.g. from native ARCore tracking or relocalization scan)
  Future<void> submitQRPoseUpdate(QRDetection detection) async {
    if (_state == LocalizationState.waitingForQrPose || _state == LocalizationState.scanningQr) {
      await _processQRDetection(detection);
    }
  }


  void _setupARSubscriptions(dynamic transform) {
    _poseSub?.cancel();
    _trackingSub?.cancel();

    _poseSub = _arService.poseStream.listen((arPose) {
      _onARPoseUpdate(arPose);
    });

    _trackingSub = _arService.trackingStateStream.listen((trackingState) {
      if (trackingState == ARTrackingState.stopped || trackingState == ARTrackingState.error) {
        _updateState(LocalizationState.lost);
      }
    });

    _updateState(LocalizationState.tracking);
  }

  void _onARPoseUpdate(ARPose arPose) {
    if (_state != LocalizationState.tracking && _state != LocalizationState.degraded) return;

    final floorPosition = _alignmentEngine.arWorldToFloor(arPose.position);
    final drift = _driftMonitor.updatePose(arPose.position, arPose.trackingState);

    _confidence = drift.confidence;

    if (drift.isLost) {
      _updateState(LocalizationState.lost);
    } else if (drift.isDegraded && _state == LocalizationState.tracking) {
      _updateState(LocalizationState.degraded);
    }

    final userPose = UserWorldPose(
      position: arPose.position,
      rotation: arPose.rotation,
      trackingState: arPose.trackingState,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      confidence: _confidence,
    );

    _currentSession = NavigationSession(
      buildingId: _targetBuildingId ?? '',
      floorId: _targetFloorId ?? '',
      originId: _activeFloor?.origin?.originId ?? '',
      localizationState: _state,
      currentWorldPose: userPose,
      currentFloorPosition: floorPosition,
      transform: _alignmentEngine.currentTransform,
      confidence: _confidence,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      distanceTraveledMeters: drift.distanceTraveledMeters,
    );

    _sessionController.add(_currentSession!);
  }

  Future<void> requestRelocalization() async {
    _poseSub?.cancel();
    _trackingSub?.cancel();
    _driftMonitor.reset();
    _alignmentEngine.reset();

    if (_targetBuildingId != null && _targetFloorId != null) {
      await startLocalizationSession(
        buildingId: _targetBuildingId!,
        floorId: _targetFloorId!,
      );
    }
  }

  void reset() {
    _poseSub?.cancel();
    _trackingSub?.cancel();
    _qrSub?.cancel();
    _driftMonitor.reset();
    _alignmentEngine.reset();
    _targetBuildingId = null;
    _targetFloorId = null;
    _activeFloor = null;
    _currentSession = null;
    _updateState(LocalizationState.idle);
  }

  void _updateState(LocalizationState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  void dispose() {
    reset();
    _sessionController.close();
    _stateController.close();
  }
}
