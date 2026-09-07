import '../models/ar_pose.dart';
import '../models/ar_tracking_state.dart';

abstract class ARService {
  Future<bool> isARSupported();
  Future<bool> checkCameraPermission();
  Future<bool> requestCameraPermission();
  Future<bool> startARSession();
  Future<bool> pauseARSession();
  Future<bool> stopARSession();
  Future<bool> placeTestMarker();
  Future<bool> addNodeAnchor(double x, double y, double z);
  Future<bool> clearNodeAnchors();
  Future<bool> resetARSession();

  Future<bool> updateNavigationRoute(List<Vector3D> routePoints, Vector3D destinationPoint);
  Future<bool> clearNavigationRoute();
  Future<Map<String, dynamic>> getCameraDiagnostics();

  Stream<ARTrackingState> get trackingStateStream;
  Stream<ARPose> get poseStream;
}
