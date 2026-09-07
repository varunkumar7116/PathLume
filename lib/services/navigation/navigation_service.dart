import 'dart:async';
import 'dart:developer' as developer;
import '../../models/ar_pose.dart';
import '../../models/destination.dart';
import '../../models/localization_state.dart';
import '../../models/navigation_graph.dart';
import '../../models/navigation_node.dart';
import '../../models/navigation_session.dart';
import '../../models/route.dart';
import '../../navigation_core/a_star.dart';
import '../../navigation_core/graph_validator.dart';
import '../../navigation_core/off_route_detector.dart';
import '../../navigation_core/route_projector.dart';
import '../ar_service.dart';
import '../localization/localization_service.dart';
import '../localization/pose_filter.dart';
import '../repositories/building_repository.dart';

class NavigationService {
  final LocalizationService _localizationService;
  final BuildingRepository _repository;
  final ARService _arService;

  final AStarPathfinder _pathfinder = AStarPathfinder();
  final OffRouteDetector _offRouteDetector = OffRouteDetector();
  final RouteProjector _routeProjector = RouteProjector();
  final GraphValidator _graphValidator = GraphValidator();
  final PoseFilter _poseFilter = PoseFilter(positionSmoothingFactor: 0.35);

  NavigationSession? _currentSession;
  NavigationGraph? _activeGraph;
  Destination? _targetDestination;
  RoutePath? _activeRoute;

  NavigationState _navigationState = NavigationState.idle;
  int _currentWaypointIndex = 0;
  TurnInstruction _currentInstruction = TurnInstruction.straight;
  double _distanceRemainingMeters = 0.0;
  int _arrivalCounter = 0;

  int _lastRecalculationTimestamp = 0;
  static const int minRecalculationIntervalMs = 3000;

  StreamSubscription<NavigationSession>? _localizationSub;

  final StreamController<NavigationSession> _sessionController =
      StreamController<NavigationSession>.broadcast();

  NavigationService({
    required LocalizationService localizationService,
    required BuildingRepository repository,
    required ARService arService,
  })  : _localizationService = localizationService,
        _repository = repository,
        _arService = arService {
    _initLocalizationSubscription();
  }

  NavigationSession? get currentSession => _currentSession;
  NavigationState get navigationState => _navigationState;
  RoutePath? get activeRoute => _activeRoute;
  PoseFilter get poseFilter => _poseFilter;
  Stream<NavigationSession> get sessionStream => _sessionController.stream;

  void _initLocalizationSubscription() {
    _localizationSub?.cancel();
    _localizationSub = _localizationService.sessionStream.listen((locSession) {
      _handleLocalizationUpdate(locSession);
    });
  }

  Future<bool> startNavigation({
    required String buildingId,
    required String floorId,
    required String destinationId,
  }) async {
    _navigationState = NavigationState.calculatingRoute;
    _log('Starting navigation for building: $buildingId, floor: $floorId, dest: $destinationId');

    _activeGraph = await _repository.getGraphByFloorId(buildingId, floorId);
    _targetDestination = await _repository.getDestinationById(buildingId, floorId, destinationId);

    if (_targetDestination == null) {
      _log('Target destination $destinationId not found on floor $floorId');
      _navigationState = NavigationState.error;
      _notifyUpdate();
      return false;
    }

    // 1. Graph validation check
    final validation = _graphValidator.validateGraph(
      _activeGraph,
      destinations: [_targetDestination!],
    );

    if (!validation.isValid) {
      _log('Graph validation failed: ${validation.errors}');
      _navigationState = NavigationState.error;
      _notifyUpdate();
      return false;
    }

    final rawUserFloorPos = _localizationService.currentSession?.currentFloorPosition ?? const Vector3D();
    final userFloorPos = _poseFilter.filterPosition(rawUserFloorPos);

    final startNode = _findNearestNode(userFloorPos, _activeGraph!.nodes);

    if (startNode == null) {
      _log('No nearest start node found for user position: $userFloorPos');
      _navigationState = NavigationState.error;
      _notifyUpdate();
      return false;
    }

    final route = _pathfinder.findPath(
      graph: _activeGraph!,
      startNodeId: startNode.nodeId,
      targetNodeId: _targetDestination!.nodeId,
    );

    if (route == null) {
      _log('A* pathfinder returned no valid route to $destinationId');
      _navigationState = NavigationState.error;
      _notifyUpdate();
      return false;
    }

    _activeRoute = route;
    _currentWaypointIndex = 0;
    _arrivalCounter = 0;
    _offRouteDetector.reset();
    _poseFilter.reset();
    _navigationState = NavigationState.navigating;

    _log('Route successfully calculated with ${route.pathNodes.length} nodes, distance: ${route.totalDistance.toStringAsFixed(1)}m');

    await _updateNativeARRendering();
    _notifyUpdate();
    return true;
  }

  void _handleLocalizationUpdate(NavigationSession locSession) {
    if (_navigationState != NavigationState.navigating &&
        _navigationState != NavigationState.offRoute &&
        _navigationState != NavigationState.relocalizing) {
      _currentSession = locSession;
      _sessionController.add(locSession);
      return;
    }

    // Check tracking state gating
    if (locSession.localizationState == LocalizationState.lost ||
        locSession.confidence == LocalizationConfidence.unknown) {
      if (_navigationState != NavigationState.relocalizing) {
        _log('ARCore tracking lost or confidence unknown — transitioning to RELOCALIZING state');
        _navigationState = NavigationState.relocalizing;
      }
      _notifyUpdate();
      return;
    } else if (_navigationState == NavigationState.relocalizing) {
      _log('ARCore tracking recovered — restoring NAVIGATING state');
      _navigationState = NavigationState.navigating;
    }

    final rawUserFloorPos = locSession.currentFloorPosition ?? const Vector3D();
    final userFloorPos = _poseFilter.filterPosition(rawUserFloorPos);

    final route = _activeRoute;

    if (route != null && route.pathNodes.isNotEmpty) {
      // 1. Route progress & turn instruction calculation
      final progress = _routeProjector.calculateProgress(
        currentFloorPosition: userFloorPos,
        activeRoute: route,
        previousWaypointIndex: _currentWaypointIndex,
      );

      _currentWaypointIndex = progress.currentWaypointIndex;
      _distanceRemainingMeters = progress.distanceRemainingMeters;
      _currentInstruction = progress.currentInstruction;

      // 2. Off-route detection with hysteresis
      final isOff = _offRouteDetector.isOffRoute(
        currentFloorPosition: userFloorPos,
        activeRoute: route,
        enterThresholdMeters: 3.0,
        exitThresholdMeters: 1.5,
      );

      if (isOff) {
        if (_navigationState != NavigationState.offRoute) {
          _log('Off-route detected (>3.0m offset) — attempting auto-recalculation');
          _navigationState = NavigationState.offRoute;
        }
        _recalculateRoute(userFloorPos);
        return;
      }

      // 3. Arrival detection
      final destNodePos = route.pathNodes.last.position;
      final distToDest = userFloorPos.distanceTo(destNodePos);
      if (distToDest < 1.5) {
        _arrivalCounter++;
        if (_arrivalCounter >= 3 && _navigationState != NavigationState.arrived) {
          _log('Destination arrival confirmed (distance < 1.5m sustained)');
          _navigationState = NavigationState.arrived;
          _currentInstruction = TurnInstruction.arriving;
        }
      } else {
        _arrivalCounter = 0;
      }
    }

    _notifyUpdate();
  }

  Future<void> _recalculateRoute(Vector3D userFloorPos) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastRecalculationTimestamp < minRecalculationIntervalMs) {
      // Throttle recalculation to prevent CPU / A* spamming
      return;
    }
    _lastRecalculationTimestamp = now;

    if (_activeGraph == null || _targetDestination == null) return;

    final startNode = _findNearestNode(userFloorPos, _activeGraph!.nodes);
    if (startNode == null) return;

    _log('Recalculating A* route from nearest node: ${startNode.nodeId}');

    final newRoute = _pathfinder.findPath(
      graph: _activeGraph!,
      startNodeId: startNode.nodeId,
      targetNodeId: _targetDestination!.nodeId,
    );

    if (newRoute != null) {
      _activeRoute = newRoute;
      _currentWaypointIndex = 0;
      _offRouteDetector.reset();
      _navigationState = NavigationState.navigating;
      _log('Recalculation complete. New route nodes: ${newRoute.pathNodes.length}');
      await _updateNativeARRendering();
    }
  }

  Future<void> _updateNativeARRendering() async {
    final transform = _localizationService.currentSession?.transform;
    final route = _activeRoute;

    if (transform == null || route == null || route.pathNodes.isEmpty) {
      await _arService.clearNavigationRoute();
      return;
    }

    // Convert route floor positions to AR World Space coordinates with slight floor height offset (+0.05m)
    final arWorldPoints = route.pathNodes.map((node) {
      final floorPosWithHeight = Vector3D(x: node.position.x, y: node.position.y + 0.05, z: node.position.z);
      return transform.transformFloorToAR(floorPosWithHeight);
    }).toList();

    final destFloorPos = route.pathNodes.last.position;
    final destWorldPos = transform.transformFloorToAR(
      Vector3D(x: destFloorPos.x, y: destFloorPos.y + 0.05, z: destFloorPos.z),
    );

    await _arService.updateNavigationRoute(arWorldPoints, destWorldPos);
  }

  NavigationNode? _findNearestNode(Vector3D userPos, List<NavigationNode> nodes) {
    if (nodes.isEmpty) return null;
    NavigationNode nearest = nodes.first;
    double minDist = userPos.distanceTo(nearest.position);

    for (final node in nodes) {
      final dist = userPos.distanceTo(node.position);
      if (dist < minDist) {
        minDist = dist;
        nearest = node;
      }
    }
    return nearest;
  }

  void stopNavigation() {
    _log('Stopping navigation session');
    _navigationState = NavigationState.idle;
    _activeRoute = null;
    _targetDestination = null;
    _currentWaypointIndex = 0;
    _distanceRemainingMeters = 0.0;
    _currentInstruction = TurnInstruction.straight;
    _offRouteDetector.reset();
    _poseFilter.reset();
    _arService.clearNavigationRoute();
    _notifyUpdate();
  }

  void _notifyUpdate() {
    final locSession = _localizationService.currentSession;
    _currentSession = NavigationSession(
      buildingId: locSession?.buildingId ?? '',
      floorId: locSession?.floorId ?? '',
      originId: locSession?.originId ?? '',
      destinationId: _targetDestination?.destinationId,
      startNodeId: _activeRoute?.startNodeId,
      localizationState: locSession?.localizationState ?? LocalizationState.idle,
      navigationState: _navigationState,
      currentWorldPose: locSession?.currentWorldPose,
      currentFloorPosition: locSession?.currentFloorPosition,
      transform: locSession?.transform,
      confidence: locSession?.confidence ?? LocalizationConfidence.unknown,
      activeRoute: _activeRoute,
      currentWaypointIndex: _currentWaypointIndex,
      nextInstruction: _currentInstruction,
      distanceRemainingMeters: _distanceRemainingMeters,
      distanceTraveledMeters: locSession?.distanceTraveledMeters ?? 0.0,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    _sessionController.add(_currentSession!);
  }

  void _log(String message) {
    developer.log('[PATHLUME_NavService] $message', name: 'PATHLUME.Navigation');
  }

  void dispose() {
    stopNavigation();
    _localizationSub?.cancel();
    _sessionController.close();
  }
}
