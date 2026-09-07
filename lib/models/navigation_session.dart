import 'ar_pose.dart';
import 'coordinate_transform.dart';
import 'localization_state.dart';
import 'route.dart';
import 'user_world_pose.dart';
import '../navigation_core/route_projector.dart';

enum NavigationState {
  idle,
  localizing,
  calculatingRoute,
  navigating,
  offRoute,
  relocalizing,
  arrived,
  error,
}

extension NavigationStateX on NavigationState {
  String get displayName {
    switch (this) {
      case NavigationState.idle:
        return 'IDLE';
      case NavigationState.localizing:
        return 'LOCALIZING';
      case NavigationState.calculatingRoute:
        return 'CALCULATING ROUTE';
      case NavigationState.navigating:
        return 'NAVIGATING';
      case NavigationState.offRoute:
        return 'OFF ROUTE';
      case NavigationState.relocalizing:
        return 'RELOCALIZING';
      case NavigationState.arrived:
        return 'ARRIVED';
      case NavigationState.error:
        return 'ERROR';
    }
  }
}

class NavigationSession {
  final String buildingId;
  final String floorId;
  final String originId;
  final String? destinationId;
  final String? startNodeId;
  final LocalizationState localizationState;
  final NavigationState navigationState;
  final UserWorldPose? currentWorldPose;
  final Vector3D? currentFloorPosition;
  final CoordinateTransform? transform;
  final LocalizationConfidence confidence;
  final RoutePath? activeRoute;
  final int currentWaypointIndex;
  final TurnInstruction nextInstruction;
  final double distanceRemainingMeters;
  final double distanceTraveledMeters;
  final int timestamp;

  const NavigationSession({
    required this.buildingId,
    required this.floorId,
    required this.originId,
    this.destinationId,
    this.startNodeId,
    this.localizationState = LocalizationState.idle,
    this.navigationState = NavigationState.idle,
    this.currentWorldPose,
    this.currentFloorPosition,
    this.transform,
    this.confidence = LocalizationConfidence.unknown,
    this.activeRoute,
    this.currentWaypointIndex = 0,
    this.nextInstruction = TurnInstruction.straight,
    this.distanceRemainingMeters = 0.0,
    this.distanceTraveledMeters = 0.0,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'buildingId': buildingId,
        'floorId': floorId,
        'originId': originId,
        'destinationId': destinationId,
        'startNodeId': startNodeId,
        'localizationState': localizationState.displayName,
        'navigationState': navigationState.displayName,
        'currentWorldPose': currentWorldPose?.toJson(),
        'currentFloorPosition': currentFloorPosition?.toJson(),
        'transform': transform?.toJson(),
        'confidence': confidence.displayName,
        'activeRoute': activeRoute?.toJson(),
        'currentWaypointIndex': currentWaypointIndex,
        'nextInstruction': nextInstruction.displayName,
        'distanceRemainingMeters': distanceRemainingMeters,
        'distanceTraveledMeters': distanceTraveledMeters,
        'timestamp': timestamp,
      };

  factory NavigationSession.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return NavigationSession(
        buildingId: '',
        floorId: '',
        originId: '',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
    }
    return NavigationSession(
      buildingId: json['buildingId'] as String? ?? '',
      floorId: json['floorId'] as String? ?? '',
      originId: json['originId'] as String? ?? '',
      destinationId: json['destinationId'] as String?,
      startNodeId: json['startNodeId'] as String?,
      localizationState: LocalizationState.values.firstWhere(
        (s) => s.displayName == json['localizationState'],
        orElse: () => LocalizationState.idle,
      ),
      navigationState: NavigationState.values.firstWhere(
        (s) => s.displayName == json['navigationState'],
        orElse: () => NavigationState.idle,
      ),
      currentWorldPose: json['currentWorldPose'] != null
          ? UserWorldPose.fromJson(json['currentWorldPose'] as Map<String, dynamic>)
          : null,
      currentFloorPosition: Vector3D.fromJson(json['currentFloorPosition'] as Map<String, dynamic>?),
      transform: json['transform'] != null
          ? CoordinateTransform.fromJson(json['transform'] as Map<String, dynamic>)
          : null,
      confidence: LocalizationConfidence.values.firstWhere(
        (c) => c.displayName == json['confidence'],
        orElse: () => LocalizationConfidence.unknown,
      ),
      activeRoute: json['activeRoute'] != null
          ? RoutePath.fromJson(json['activeRoute'] as Map<String, dynamic>)
          : null,
      currentWaypointIndex: (json['currentWaypointIndex'] as num?)?.toInt() ?? 0,
      nextInstruction: TurnInstruction.values.firstWhere(
        (t) => t.displayName == json['nextInstruction'],
        orElse: () => TurnInstruction.straight,
      ),
      distanceRemainingMeters: (json['distanceRemainingMeters'] as num?)?.toDouble() ?? 0.0,
      distanceTraveledMeters: (json['distanceTraveledMeters'] as num?)?.toDouble() ?? 0.0,
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
    );
  }
}
