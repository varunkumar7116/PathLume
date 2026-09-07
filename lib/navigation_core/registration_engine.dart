import 'dart:async';
import 'dart:developer' as developer;
import '../models/ar_pose.dart';
import '../models/ar_tracking_state.dart';
import '../models/destination.dart';
import '../models/floor_origin.dart';
import '../models/navigation_edge.dart';
import '../models/navigation_graph.dart';
import '../models/navigation_node.dart';
import '../models/qr_payload.dart';
import '../models/registration_state.dart';
import 'graph_processor.dart';

class NodeAddResult {
  final bool success;
  final NavigationNode? node;
  final String? warningMessage;

  const NodeAddResult({required this.success, this.node, this.warningMessage});
}

class RegistrationQualityMetrics {
  final int totalNodes;
  final int totalEdges;
  final double totalDistance;
  final double minSpacing;
  final double maxEdgeLength;
  final double avgEdgeLength;
  final int destinationCount;
  final int disconnectedNodeCount;
  final int trackingInterruptions;

  const RegistrationQualityMetrics({
    required this.totalNodes,
    required this.totalEdges,
    required this.totalDistance,
    required this.minSpacing,
    required this.maxEdgeLength,
    required this.avgEdgeLength,
    required this.destinationCount,
    required this.disconnectedNodeCount,
    required this.trackingInterruptions,
  });
}

class RegistrationSummary {
  final int nodeCount;
  final int edgeCount;
  final double totalDistance;
  final int destinationCount;
  final double minSpacing;
  final double avgSpacing;
  final double maxEdgeLength;
  final int orphanCount;

  const RegistrationSummary({
    required this.nodeCount,
    required this.edgeCount,
    required this.totalDistance,
    required this.destinationCount,
    required this.minSpacing,
    required this.avgSpacing,
    required this.maxEdgeLength,
    required this.orphanCount,
  });
}

class RegistrationEngine {
  final GraphProcessor _graphProcessor = GraphProcessor();
  final double minNodeSpacingMeters;

  RegistrationState _state = RegistrationState.idle;
  String? _currentFloorId;
  String? _currentBuildingId;
  FloorOrigin? _origin;

  final List<NavigationNode> _capturedNodes = [];
  final List<NavigationEdge> _capturedEdges = [];
  final List<Destination> _capturedDestinations = [];

  final StreamController<RegistrationState> _stateController =
      StreamController<RegistrationState>.broadcast();
  final StreamController<List<NavigationNode>> _nodesController =
      StreamController<List<NavigationNode>>.broadcast();

  RegistrationEngine({this.minNodeSpacingMeters = 0.8});

  RegistrationState get state => _state;
  String? get currentFloorId => _currentFloorId;
  FloorOrigin? get origin => _origin;
  List<NavigationNode> get capturedNodes => List.unmodifiable(_capturedNodes);
  List<NavigationEdge> get capturedEdges => List.unmodifiable(_capturedEdges);
  List<Destination> get capturedDestinations => List.unmodifiable(_capturedDestinations);

  Stream<RegistrationState> get stateStream => _stateController.stream;
  Stream<List<NavigationNode>> get nodesStream => _nodesController.stream;

  double get totalDistance {
    double sum = 0.0;
    for (final edge in _capturedEdges) {
      sum += edge.distance;
    }
    return sum;
  }

  void initializeRegistration({required String buildingId, required String floorId}) {
    _currentBuildingId = buildingId;
    _currentFloorId = floorId;
    _capturedNodes.clear();
    _capturedEdges.clear();
    _capturedDestinations.clear();
    _origin = null;
    _updateState(RegistrationState.preparing);
  }

  int _trackingInterruptions = 0;

  void updateTrackingState(dynamic trackingState) {
    final stateName = trackingState.toString().split('.').last.toUpperCase();
    if (_state == RegistrationState.preparing && stateName == 'INITIALIZING') {
      _updateState(RegistrationState.trackingInitializing);
    } else if ((_state == RegistrationState.preparing || _state == RegistrationState.trackingInitializing) &&
        stateName == 'TRACKING') {
      _updateState(RegistrationState.ready);
    } else if (_state == RegistrationState.registering && stateName != 'TRACKING') {
      recordTrackingInterruption();
    }
  }

  void recordTrackingInterruption() {
    _trackingInterruptions++;
    developer.log('[PATHLUME][REGISTRATION] Tracking interruption recorded (total: $_trackingInterruptions)');
  }

  RegistrationQualityMetrics getQualityMetrics() {
    double minEdge = _capturedEdges.isEmpty ? 0.0 : double.infinity;
    double maxEdge = 0.0;
    double sumEdge = 0.0;

    for (final edge in _capturedEdges) {
      if (edge.distance < minEdge) minEdge = edge.distance;
      if (edge.distance > maxEdge) maxEdge = edge.distance;
      sumEdge += edge.distance;
    }
    if (minEdge == double.infinity) minEdge = 0.0;
    final avgEdge = _capturedEdges.isEmpty ? 0.0 : sumEdge / _capturedEdges.length;

    final connectedNodeIds = <String>{};
    for (final edge in _capturedEdges) {
      connectedNodeIds.add(edge.fromNodeId);
      connectedNodeIds.add(edge.toNodeId);
    }
    final disconnectedCount = _capturedNodes.where((n) => !connectedNodeIds.contains(n.nodeId) && n.type != NodeType.start).length;

    return RegistrationQualityMetrics(
      totalNodes: _capturedNodes.length,
      totalEdges: _capturedEdges.length,
      totalDistance: totalDistance,
      minSpacing: minEdge,
      maxEdgeLength: maxEdge,
      avgEdgeLength: double.parse(avgEdge.toStringAsFixed(2)),
      destinationCount: _capturedDestinations.length,
      disconnectedNodeCount: disconnectedCount,
      trackingInterruptions: _trackingInterruptions,
    );
  }

  void setStartPoint(ARPose pose) {
    if (_capturedNodes.any((n) => n.type == NodeType.start)) {
      return;
    }
    if (_state != RegistrationState.preparing &&
        _state != RegistrationState.trackingInitializing &&
        _state != RegistrationState.ready) {
      return;
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final originId = 'origin_${_currentFloorId}_$timestamp';
    final payload = QRPayload(
      buildingId: _currentBuildingId ?? '',
      floorId: _currentFloorId ?? '',
      originId: originId,
      timestamp: timestamp,
    ).serialize();

    _origin = FloorOrigin(
      originId: originId,
      floorId: _currentFloorId ?? '',
      position: pose.position,
      rotation: pose.rotation,
      qrCodePayload: payload,
      createdAt: DateTime.now(),
    );

    // Create START node at origin
    final startNode = NavigationNode(
      nodeId: 'node_${_currentFloorId}_0',
      floorId: _currentFloorId ?? '',
      type: NodeType.start,
      position: pose.position,
      rotation: pose.rotation,
      sequence: 0,
      name: 'Start Origin',
    );

    _capturedNodes.add(startNode);
    developer.log(
      '[PATHLUME][NODE_CREATED] id=0 floor=$_currentFloorId world=(${pose.position.x.toStringAsFixed(2)}, ${pose.position.y.toStringAsFixed(2)}, ${pose.position.z.toStringAsFixed(2)}) timestamp=$timestamp tracking=${pose.trackingState.displayName}',
    );
    _notifyNodesChanged();
    _updateState(RegistrationState.originSet);
  }

  void startWalking() {
    if (_state == RegistrationState.originSet || _state == RegistrationState.paused) {
      _updateState(RegistrationState.registering);
    }
  }

  NodeAddResult addNode({
    NodeType type = NodeType.waypoint,
    required Vector3D position,
    Quaternion4D rotation = const Quaternion4D(),
    String? name,
    String? destinationCategory,
    bool forceAdd = false,
  }) {
    if (_state != RegistrationState.registering) {
      return const NodeAddResult(
        success: false,
        warningMessage: 'Registration is not currently active.',
      );
    }

    if (_capturedNodes.isNotEmpty) {
      final lastNode = _capturedNodes.last;
      final dist = position.distanceTo(lastNode.position);
      final requiredSpacing = forceAdd ? 0.05 : minNodeSpacingMeters;
      final isAccepted = dist >= requiredSpacing;
      developer.log(
        '[PATHLUME][SPACING_CHECK] PREVIOUS_NODE_WORLD: (${lastNode.position.x.toStringAsFixed(2)}, ${lastNode.position.y.toStringAsFixed(2)}, ${lastNode.position.z.toStringAsFixed(2)}) CURRENT_CAMERA_WORLD: (${position.x.toStringAsFixed(2)}, ${position.y.toStringAsFixed(2)}, ${position.z.toStringAsFixed(2)}) DISTANCE: ${dist.toStringAsFixed(2)}m MIN_REQUIRED: ${requiredSpacing.toStringAsFixed(2)}m RESULT: ${isAccepted ? "ACCEPT" : "REJECT"}',
      );
      if (!isAccepted) {
        return NodeAddResult(
          success: false,
          warningMessage:
              'Move at least ${requiredSpacing.toStringAsFixed(1)} m away from the previous node (${dist.toStringAsFixed(2)}m / min ${requiredSpacing.toStringAsFixed(2)}m).',
        );
      }
    }

    final seq = _capturedNodes.length;
    final nodeId = 'node_${_currentFloorId}_$seq';
    final defaultName = name ?? '${type.nameString} $seq';

    final node = NavigationNode(
      nodeId: nodeId,
      floorId: _currentFloorId ?? '',
      type: type,
      position: position,
      rotation: rotation,
      sequence: seq,
      name: defaultName,
    );

    // Connect to previous node with calculated spatial Euclidean distance
    if (_capturedNodes.isNotEmpty) {
      final prevNode = _capturedNodes.last;
      final dist = position.distanceTo(prevNode.position);
      final edgeId = 'edge_${prevNode.nodeId}_${node.nodeId}';
      final edge = NavigationEdge(
        edgeId: edgeId,
        fromNodeId: prevNode.nodeId,
        toNodeId: node.nodeId,
        distance: double.parse(dist.toStringAsFixed(2)),
      );
      _capturedEdges.add(edge);
    }

    _capturedNodes.add(node);

    // Record Destination metadata if node is DESTINATION type
    if (type == NodeType.destination) {
      final destId = 'dest_${_currentFloorId}_${_capturedDestinations.length}';
      final dest = Destination(
        destinationId: destId,
        nodeId: nodeId,
        name: defaultName,
        category: destinationCategory ?? 'General',
      );
      _capturedDestinations.add(dest);
    }

    _notifyNodesChanged();
    return NodeAddResult(success: true, node: node);
  }

  /// Mark a turn at current position with manual force add or reuse current node
  NodeAddResult markTurn({
    required Vector3D position,
    Quaternion4D rotation = const Quaternion4D(),
    String? name,
  }) {
    if (_capturedNodes.isNotEmpty) {
      final lastNode = _capturedNodes.last;
      if (position.distanceTo(lastNode.position) < 0.05) {
        final updated = lastNode.copyWith(
          type: NodeType.turn,
          name: name ?? lastNode.name,
        );
        _capturedNodes[_capturedNodes.length - 1] = updated;
        _notifyNodesChanged();
        return NodeAddResult(success: true, node: updated);
      }
    }
    return addNode(
      type: NodeType.turn,
      position: position,
      rotation: rotation,
      name: name ?? 'Turn Node',
      forceAdd: true,
    );
  }

  /// Mark a door at current position with manual force add or reuse current node
  NodeAddResult markDoor({
    required Vector3D position,
    Quaternion4D rotation = const Quaternion4D(),
    String? name,
  }) {
    if (_capturedNodes.isNotEmpty) {
      final lastNode = _capturedNodes.last;
      if (position.distanceTo(lastNode.position) < 0.05) {
        final updated = lastNode.copyWith(
          type: NodeType.door,
          name: name ?? lastNode.name,
        );
        _capturedNodes[_capturedNodes.length - 1] = updated;
        _notifyNodesChanged();
        return NodeAddResult(success: true, node: updated);
      }
    }
    return addNode(
      type: NodeType.door,
      position: position,
      rotation: rotation,
      name: name ?? 'Door Node',
      forceAdd: true,
    );
  }

  /// Mark a destination at current position with manual force add or reuse current node
  NodeAddResult markDestination({
    required Vector3D position,
    Quaternion4D rotation = const Quaternion4D(),
    required String name,
    String? category,
  }) {
    if (_capturedNodes.isNotEmpty) {
      final lastNode = _capturedNodes.last;
      if (position.distanceTo(lastNode.position) < 0.05) {
        final updated = lastNode.copyWith(
          type: NodeType.destination,
          name: name,
        );
        _capturedNodes[_capturedNodes.length - 1] = updated;

        final existingIdx = _capturedDestinations.indexWhere((d) => d.nodeId == updated.nodeId);
        final dest = Destination(
          destinationId: existingIdx >= 0
              ? _capturedDestinations[existingIdx].destinationId
              : 'dest_${_currentFloorId}_${_capturedDestinations.length}',
          nodeId: updated.nodeId,
          name: name,
          category: category ?? 'General',
        );
        if (existingIdx >= 0) {
          _capturedDestinations[existingIdx] = dest;
        } else {
          _capturedDestinations.add(dest);
        }

        _notifyNodesChanged();
        return NodeAddResult(success: true, node: updated);
      }
    }
    return addNode(
      type: NodeType.destination,
      position: position,
      rotation: rotation,
      name: name,
      destinationCategory: category ?? 'General',
      forceAdd: true,
    );
  }

  /// Foundation for distance-based automatic waypoint sampling
  NodeAddResult? tryAutomaticSamplingCandidate(Vector3D currentPosition) {
    if (_state != RegistrationState.registering || _capturedNodes.isEmpty) return null;
    final lastNode = _capturedNodes.last;
    final dist = currentPosition.distanceTo(lastNode.position);

    // Auto-sample when moved beyond 2x minimum spacing
    if (dist >= minNodeSpacingMeters * 2.0) {
      return addNode(
        type: NodeType.waypoint,
        position: currentPosition,
        name: 'Auto Waypoint ${_capturedNodes.length}',
      );
    }
    return null;
  }

  void pauseRegistration() {
    if (_state == RegistrationState.registering) {
      _updateState(RegistrationState.paused);
    }
  }

  void resumeRegistration() {
    if (_state == RegistrationState.paused) {
      _updateState(RegistrationState.registering);
    }
  }

  RegistrationSummary getSummary() {
    final metrics = getQualityMetrics();
    return RegistrationSummary(
      nodeCount: _capturedNodes.length,
      edgeCount: _capturedEdges.length,
      totalDistance: totalDistance,
      destinationCount: _capturedDestinations.length,
      minSpacing: metrics.minSpacing,
      avgSpacing: metrics.avgEdgeLength,
      maxEdgeLength: metrics.maxEdgeLength,
      orphanCount: metrics.disconnectedNodeCount,
    );
  }

  NavigationGraph? finishAndProcessGraph() {
    _updateState(RegistrationState.processing);

    final graph = _graphProcessor.processNodesAndEdges(
      floorId: _currentFloorId ?? '',
      nodes: _capturedNodes,
      edges: _capturedEdges,
      destinations: _capturedDestinations,
    );

    if (graph != null) {
      _updateState(RegistrationState.completed);
    } else {
      _updateState(RegistrationState.error);
    }

    return graph;
  }

  void reset() {
    _capturedNodes.clear();
    _capturedEdges.clear();
    _capturedDestinations.clear();
    _origin = null;
    _currentFloorId = null;
    _currentBuildingId = null;
    _updateState(RegistrationState.idle);
  }

  void _updateState(RegistrationState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  void _notifyNodesChanged() {
    _nodesController.add(List.unmodifiable(_capturedNodes));
  }

  void dispose() {
    _stateController.close();
    _nodesController.close();
  }
}
