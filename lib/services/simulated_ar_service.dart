import 'dart:async';
import '../models/ar_pose.dart';
import '../models/ar_tracking_state.dart';
import 'ar_service.dart';

class SimulatedARService implements ARService {
  final StreamController<ARTrackingState> _trackingController =
      StreamController<ARTrackingState>.broadcast();
  final StreamController<ARPose> _poseController =
      StreamController<ARPose>.broadcast();

  ARTrackingState _currentState = ARTrackingState.initializing;
  ARPose _currentPose = const ARPose(
    position: Vector3D(x: 0.0, y: 0.0, z: 0.0),
    trackingState: ARTrackingState.tracking,
  );

  final List<Vector3D> predefinedPoses = const [
    Vector3D(x: 0.0, y: 0.0, z: 0.0),
    Vector3D(x: 0.0, y: 0.0, z: 1.0),
    Vector3D(x: 0.0, y: 0.0, z: 2.0),
    Vector3D(x: 1.0, y: 0.0, z: 2.0),
    Vector3D(x: 2.0, y: 0.0, z: 2.0),
    Vector3D(x: 3.0, y: 0.0, z: 2.0),
  ];

  int _stepIndex = 0;

  @override
  Stream<ARTrackingState> get trackingStateStream => _trackingController.stream;

  @override
  Stream<ARPose> get poseStream => _poseController.stream;

  @override
  Future<bool> isARSupported() async => true;

  @override
  Future<bool> checkCameraPermission() async => true;

  @override
  Future<bool> requestCameraPermission() async => true;

  @override
  Future<bool> startARSession() async {
    _currentState = ARTrackingState.tracking;
    _trackingController.add(_currentState);
    _poseController.add(_currentPose);
    return true;
  }

  @override
  Future<bool> stopARSession() async {
    _currentState = ARTrackingState.stopped;
    _trackingController.add(_currentState);
    return true;
  }

  @override
  Future<bool> pauseARSession() async {
    _currentState = ARTrackingState.paused;
    _trackingController.add(_currentState);
    return true;
  }

  @override
  Future<bool> resetARSession() async {
    _stepIndex = 0;
    _currentPose = ARPose(
      position: predefinedPoses[0],
      trackingState: ARTrackingState.tracking,
    );
    _poseController.add(_currentPose);
    return true;
  }

  @override
  Future<bool> placeTestMarker() async {
    _currentPose = ARPose(
      position: _currentPose.position,
      rotation: _currentPose.rotation,
      trackingState: ARTrackingState.tracking,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      isMarkerPlaced: true,
    );
    _poseController.add(_currentPose);
    return true;
  }

  @override
  Future<bool> addNodeAnchor(double x, double y, double z) async => true;

  @override
  Future<bool> clearNodeAnchors() async => true;

  List<Vector3D> _activeRoutePoints = [];
  int _routeStepIndex = 0;

  @override
  Future<bool> updateNavigationRoute(
    List<Vector3D> routePoints,
    Vector3D destinationPoint,
  ) async {
    _activeRoutePoints = List.from(routePoints);
    _routeStepIndex = 0;
    return true;
  }

  @override
  Future<bool> clearNavigationRoute() async {
    _activeRoutePoints.clear();
    _routeStepIndex = 0;
    return true;
  }

  /// Advance to the next simulated 3D pose in developer test mode
  ARPose advanceSimulatedPose() {
    Vector3D nextPos;
    if (_activeRoutePoints.isNotEmpty) {
      _routeStepIndex = (_routeStepIndex + 1) % _activeRoutePoints.length;
      nextPos = _activeRoutePoints[_routeStepIndex];
    } else {
      _stepIndex = (_stepIndex + 1) % predefinedPoses.length;
      nextPos = predefinedPoses[_stepIndex];
    }

    _currentPose = ARPose(
      position: nextPos,
      trackingState: ARTrackingState.tracking,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      isMarkerPlaced: _currentPose.isMarkerPlaced,
    );
    _poseController.add(_currentPose);
    return _currentPose;
  }

  @override
  Future<Map<String, dynamic>> getCameraDiagnostics() async {
    return {
      'cameraConfigResolution': '1920x1080 (Simulated)',
      'cameraConfigImageSize': '1920x1080 (Simulated)',
      'cameraConfigFps': '30',
      'focusMode': 'AUTO',
      'trackingState': _currentState.name,
      'anchorCount': 0,
    };
  }

  void dispose() {
    _trackingController.close();
    _poseController.close();
  }
}
