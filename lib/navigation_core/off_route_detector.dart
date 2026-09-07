import 'dart:math';
import '../models/ar_pose.dart';
import '../models/route.dart';

class OffRouteDetector {
  int _consecutiveOffRouteCount = 0;
  bool _currentlyOffRoute = false;

  bool get currentlyOffRoute => _currentlyOffRoute;

  /// Evaluates off-route status with dual-threshold hysteresis
  bool isOffRoute({
    required Vector3D currentFloorPosition,
    required RoutePath activeRoute,
    double thresholdMeters = 3.0,
    double enterThresholdMeters = 3.0,
    double exitThresholdMeters = 1.5,
    int persistenceCount = 3,
  }) {
    if (activeRoute.pathNodes.isEmpty) return false;

    final enterDist = enterThresholdMeters > 0 ? enterThresholdMeters : thresholdMeters;
    final exitDist = exitThresholdMeters > 0 ? exitThresholdMeters : (enterDist * 0.5);

    double minDistance = double.infinity;

    if (activeRoute.pathNodes.length == 1) {
      minDistance = currentFloorPosition.distanceTo(activeRoute.pathNodes.first.position);
    } else {
      for (int i = 0; i < activeRoute.pathNodes.length - 1; i++) {
        final a = activeRoute.pathNodes[i].position;
        final b = activeRoute.pathNodes[i + 1].position;
        final dist = _distanceToSegment(currentFloorPosition, a, b);
        if (dist < minDistance) {
          minDistance = dist;
        }
      }
    }

    if (_currentlyOffRoute) {
      // Hysteresis exit: user must return within exitDist to be considered back on-route
      if (minDistance <= exitDist) {
        _consecutiveOffRouteCount = 0;
        _currentlyOffRoute = false;
        return false;
      }
      return true;
    } else {
      // Hysteresis enter: user must exceed enterDist for persistenceCount frames
      if (minDistance > enterDist) {
        _consecutiveOffRouteCount++;
        if (_consecutiveOffRouteCount >= persistenceCount) {
          _currentlyOffRoute = true;
          return true;
        }
      } else {
        _consecutiveOffRouteCount = 0;
      }
      return false;
    }
  }

  void reset() {
    _consecutiveOffRouteCount = 0;
    _currentlyOffRoute = false;
  }

  /// Calculates perpendicular distance from point P to line segment AB
  static double _distanceToSegment(Vector3D p, Vector3D a, Vector3D b) {
    final abX = b.x - a.x;
    final abY = b.y - a.y;
    final abZ = b.z - a.z;

    final abLenSq = abX * abX + abY * abY + abZ * abZ;
    if (abLenSq == 0.0) return p.distanceTo(a);

    final apX = p.x - a.x;
    final apY = p.y - a.y;
    final apZ = p.z - a.z;

    double t = (apX * abX + apY * abY + apZ * abZ) / abLenSq;
    t = max(0.0, min(1.0, t));

    final closestX = a.x + t * abX;
    final closestY = a.y + t * abY;
    final closestZ = a.z + t * abZ;

    final closest = Vector3D(x: closestX, y: closestY, z: closestZ);
    return p.distanceTo(closest);
  }
}
