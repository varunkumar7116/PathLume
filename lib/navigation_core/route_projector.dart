import 'dart:math';
import '../models/ar_pose.dart';
import '../models/route.dart';

enum TurnInstruction {
  straight,
  slightLeft,
  left,
  slightRight,
  right,
  uTurn,
  arriving,
}

extension TurnInstructionX on TurnInstruction {
  String get displayName {
    switch (this) {
      case TurnInstruction.straight:
        return 'Go Straight';
      case TurnInstruction.slightLeft:
        return 'Bear Left';
      case TurnInstruction.left:
        return 'Turn Left';
      case TurnInstruction.slightRight:
        return 'Bear Right';
      case TurnInstruction.right:
        return 'Turn Right';
      case TurnInstruction.uTurn:
        return 'Make a U-Turn';
      case TurnInstruction.arriving:
        return 'Arriving at Destination';
    }
  }
}

class RouteProgress {
  final int currentWaypointIndex;
  final double distanceRemainingMeters;
  final TurnInstruction currentInstruction;

  const RouteProgress({
    required this.currentWaypointIndex,
    required this.distanceRemainingMeters,
    required this.currentInstruction,
  });
}

class RouteProjector {
  /// Compute current waypoint index, remaining route distance, and turn instruction
  RouteProgress calculateProgress({
    required Vector3D currentFloorPosition,
    required RoutePath activeRoute,
    required int previousWaypointIndex,
    double waypointAcceptanceRadius = 0.75,
  }) {
    if (activeRoute.pathNodes.isEmpty) {
      return const RouteProgress(
        currentWaypointIndex: 0,
        distanceRemainingMeters: 0.0,
        currentInstruction: TurnInstruction.arriving,
      );
    }

    final nodes = activeRoute.pathNodes;
    int closestSegmentIndex = previousWaypointIndex.clamp(0, max(0, nodes.length - 1));

    // Advance waypoint index if within waypointAcceptanceRadius of current target waypoint node
    if (closestSegmentIndex < nodes.length - 1) {
      final targetWaypointPos = nodes[closestSegmentIndex + 1].position;
      final distToNextWaypoint = currentFloorPosition.distanceTo(targetWaypointPos);
      if (distToNextWaypoint < waypointAcceptanceRadius) {
        closestSegmentIndex = min(nodes.length - 1, closestSegmentIndex + 1);
      }
    }

    // Calculate remaining distance along route from user's position
    double distRemaining = 0.0;

    if (closestSegmentIndex >= nodes.length - 1) {
      distRemaining = currentFloorPosition.distanceTo(nodes.last.position);
    } else {
      // Distance from current position to next waypoint
      distRemaining += currentFloorPosition.distanceTo(nodes[closestSegmentIndex + 1].position);
      // Sum distance for remaining segments
      for (int i = closestSegmentIndex + 1; i < nodes.length - 1; i++) {
        distRemaining += nodes[i].position.distanceTo(nodes[i + 1].position);
      }
    }

    // Turn instruction calculation
    TurnInstruction instruction = TurnInstruction.straight;

    if (closestSegmentIndex >= nodes.length - 1) {
      instruction = TurnInstruction.arriving;
    } else {
      final p1 = nodes[closestSegmentIndex].position;
      final p2 = nodes[closestSegmentIndex + 1].position;

      if (closestSegmentIndex + 2 < nodes.length) {
        final p3 = nodes[closestSegmentIndex + 2].position;
        instruction = _calculateTurnAngle(p1, p2, p3);
      } else {
        instruction = TurnInstruction.straight;
      }
    }

    return RouteProgress(
      currentWaypointIndex: closestSegmentIndex,
      distanceRemainingMeters: max(0.0, distRemaining),
      currentInstruction: instruction,
    );
  }

  /// Classifies turn angle between vector P1->P2 and P2->P3
  static TurnInstruction _calculateTurnAngle(Vector3D p1, Vector3D p2, Vector3D p3) {
    final v1x = p2.x - p1.x;
    final v1z = p2.z - p1.z;
    final v2x = p3.x - p2.x;
    final v2z = p3.z - p2.z;

    final angle1 = atan2(v1z, v1x);
    final angle2 = atan2(v2z, v2x);

    double delta = (angle2 - angle1) * (180.0 / pi);
    while (delta > 180.0) {
      delta -= 360.0;
    }
    while (delta < -180.0) {
      delta += 360.0;
    }

    if (delta.abs() < 20.0) {
      return TurnInstruction.straight;
    } else if (delta >= 20.0 && delta < 60.0) {
      return TurnInstruction.slightRight;
    } else if (delta >= 60.0 && delta < 120.0) {
      return TurnInstruction.right;
    } else if (delta <= -20.0 && delta > -60.0) {
      return TurnInstruction.slightLeft;
    } else if (delta <= -60.0 && delta > -120.0) {
      return TurnInstruction.left;
    } else {
      return TurnInstruction.uTurn;
    }
  }
}
