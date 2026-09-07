import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../../app/app_theme.dart';
import '../../../models/ar_pose.dart';
import '../../../models/ar_tracking_state.dart';
import '../../../models/floor.dart';
import '../../../models/navigation_node.dart';
import '../../../models/registration_state.dart';
import '../../../navigation_core/graph_validator.dart';
import '../../../navigation_core/registration_engine.dart';
import '../../../services/android_ar_service.dart';
import '../../../services/ar_service.dart';
import '../../../services/repositories/building_repository.dart';
import '../../../services/simulated_ar_service.dart';
import '../../qr/presentation/floor_qr_screen.dart';

class FloorRegistrationScreen extends StatefulWidget {
  final String buildingId;
  final String floorId;
  final String floorName;
  final BuildingRepository repository;

  const FloorRegistrationScreen({
    super.key,
    required this.buildingId,
    required this.floorId,
    required this.floorName,
    required this.repository,
  });

  @override
  State<FloorRegistrationScreen> createState() => _FloorRegistrationScreenState();
}

class _FloorRegistrationScreenState extends State<FloorRegistrationScreen> {
  late ARService _arService;
  late final RegistrationEngine _engine;

  ARPose _currentPose = const ARPose();
  ARTrackingState _trackingState = ARTrackingState.initializing;
  bool _isDeveloperTestMode = false;
  bool _hasCameraPermission = true;
  bool _isDiagnosticsExpanded = false;

  StreamSubscription<ARTrackingState>? _trackingSub;
  StreamSubscription<ARPose>? _poseSub;
  StreamSubscription<RegistrationState>? _stateSub;
  StreamSubscription<List<NavigationNode>>? _nodesSub;

  String _lastAction = 'NONE';
  String _lastResult = 'N/A';
  String _rejectionReason = 'NONE';
  int _anchorCount = 0;
  DateTime _lastPoseLogTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _engine = RegistrationEngine();
    _arService = AndroidARService();
    _engine.initializeRegistration(
      buildingId: widget.buildingId,
      floorId: widget.floorId,
    );
    _initPermissionsAndAR();
  }

  Future<void> _initPermissionsAndAR() async {
    if (_isDeveloperTestMode) {
      _setupAR();
      return;
    }

    final hasPerm = await _arService.checkCameraPermission();
    if (!hasPerm) {
      final granted = await _arService.requestCameraPermission();
      if (mounted) {
        setState(() => _hasCameraPermission = granted);
      }
      if (!granted) return;
    } else {
      if (mounted) {
        setState(() => _hasCameraPermission = true);
      }
    }

    _setupAR();
  }

  void _setupAR() {
    _trackingSub?.cancel();
    _poseSub?.cancel();
    _stateSub?.cancel();
    _nodesSub?.cancel();

    _trackingSub = _arService.trackingStateStream.listen((state) {
      if (mounted) {
        setState(() => _trackingState = state);
      }
    });

    _poseSub = _arService.poseStream.listen((pose) {
      if (mounted) {
        setState(() => _currentPose = pose);
        final now = DateTime.now();
        if (now.difference(_lastPoseLogTime).inMilliseconds >= 1000) {
          _lastPoseLogTime = now;
          developer.log('[PATHLUME][POSE] x=${pose.position.x.toStringAsFixed(2)} y=${pose.position.y.toStringAsFixed(2)} z=${pose.position.z.toStringAsFixed(2)} tracking=${_trackingState.name}');
        }
      }
    });

    _stateSub = _engine.stateStream.listen((state) {
      if (mounted) setState(() {});
    });

    _nodesSub = _engine.nodesStream.listen((nodes) {
      if (mounted) setState(() {});
    });

    _arService.startARSession();
  }

  void _toggleDeveloperTestMode(bool value) {
    setState(() {
      _isDeveloperTestMode = value;
    });

    _arService.stopARSession();

    if (_isDeveloperTestMode) {
      _arService = SimulatedARService();
      _setupAR();
    } else {
      _arService = AndroidARService();
      _initPermissionsAndAR();
    }
  }

  @override
  void dispose() {
    _trackingSub?.cancel();
    _poseSub?.cancel();
    _stateSub?.cancel();
    _nodesSub?.cancel();
    _arService.stopARSession();
    _engine.dispose();
    super.dispose();
  }

  void _updateNative3DRoute() {
    final points = _engine.capturedNodes.map((n) => n.position).toList();
    Vector3D? dest;
    if (_engine.capturedDestinations.isNotEmpty) {
      final lastDestNodeId = _engine.capturedDestinations.last.nodeId;
      final destNode = _engine.capturedNodes.firstWhere(
        (n) => n.nodeId == lastDestNodeId,
        orElse: () => _engine.capturedNodes.last,
      );
      dest = destNode.position;
    }
    _arService.updateNavigationRoute(points, dest ?? (points.isNotEmpty ? points.last : const Vector3D()));
  }

  void _handleAddNode() async {
    _lastAction = 'ADD_NODE';
    developer.log('PATHLUME_AR NODE_CREATE_START timestamp=${_currentPose.timestamp} tracking_state=${_trackingState.displayName} pos=(${_currentPose.position.x.toStringAsFixed(2)}, ${_currentPose.position.y.toStringAsFixed(2)}, ${_currentPose.position.z.toStringAsFixed(2)})');

    if (!_isDeveloperTestMode && _trackingState != ARTrackingState.tracking && _trackingState != ARTrackingState.initializing) {
      _lastResult = 'REJECTED';
      _rejectionReason = 'AR tracking state is ${_trackingState.displayName}. Calibrating...';
      if (mounted) setState(() {});
      _showWarningSnackBar(_rejectionReason);
      return;
    }

    final Vector3D pos = _currentPose.position;
    final Quaternion4D rot = _currentPose.rotation;

    if (_engine.capturedNodes.isEmpty) {
      _engine.setStartPoint(_currentPose);
      _engine.startWalking();

      _engine.addNode(
        position: pos,
        rotation: rot,
        forceAdd: true,
      );

      await _arService.addNodeAnchor(pos.x, pos.y, pos.z);
      _anchorCount++;
      _lastResult = 'SUCCESS';
      _rejectionReason = 'NONE';

      _updateNative3DRoute();

      if (mounted) {
        setState(() {});
        _showSuccessSnackBar('Start Node (Node 0) Placed! Walk & tap + ADD NODE for next points.');
      }
      return;
    }

    if (_engine.state == RegistrationState.preparing || _engine.state == RegistrationState.originSet) {
      _engine.startWalking();
    } else if (_engine.state == RegistrationState.paused) {
      _engine.resumeRegistration();
    }

    final result = _engine.addNode(
      position: pos,
      rotation: rot,
      forceAdd: true,
    );

    if (result.success && result.node != null) {
      await _arService.addNodeAnchor(pos.x, pos.y, pos.z);
      _anchorCount++;
      _lastResult = 'SUCCESS';
      _rejectionReason = 'NONE';

      _updateNative3DRoute();

      if (mounted) {
        setState(() {});
        _showSuccessSnackBar('Added Node ${result.node!.sequence} (${result.node!.name})');
      }
    } else {
      _lastResult = 'REJECTED';
      _rejectionReason = result.warningMessage ?? 'Could not add node';
      if (mounted) setState(() {});
      _showWarningSnackBar(_rejectionReason);
    }
  }

  void _handleMarkTag(NodeType type) async {
    if (_engine.capturedNodes.isEmpty) {
      _showWarningSnackBar('Add at least one node first before tagging.');
      return;
    }

    final lastNode = _engine.capturedNodes.last;
    if (type == NodeType.destination) {
      _showDestinationDialog(lastNode);
    } else if (type == NodeType.turn) {
      _engine.markTurn(position: lastNode.position, name: 'Turn ${lastNode.sequence}');
      _lastAction = 'MARK_TURN';
      _lastResult = 'SUCCESS';
      _rejectionReason = 'NONE';
      _updateNative3DRoute();
      if (mounted) {
        setState(() {});
        _showSuccessSnackBar('Tagged Node ${lastNode.sequence} as TURN');
      }
    } else if (type == NodeType.door) {
      _engine.markDoor(position: lastNode.position, name: 'Door ${lastNode.sequence}');
      _lastAction = 'MARK_DOOR';
      _lastResult = 'SUCCESS';
      _rejectionReason = 'NONE';
      _updateNative3DRoute();
      if (mounted) {
        setState(() {});
        _showSuccessSnackBar('Tagged Node ${lastNode.sequence} as DOOR');
      }
    }
  }

  void _showDestinationDialog(NavigationNode lastNode) {
    final controller = TextEditingController(text: 'Destination ${_engine.capturedDestinations.length + 1}');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text('Mark Destination Node', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tagging Node ${lastNode.sequence} at [${lastNode.position.x.toStringAsFixed(1)}, ${lastNode.position.z.toStringAsFixed(1)}]:',
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Destination Name (e.g. Room 101, Lobby)',
                labelStyle: const TextStyle(color: AppTheme.primaryCyan),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white24),
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppTheme.primaryCyan),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryCyan),
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                _engine.markDestination(position: lastNode.position, name: name);
                _lastAction = 'MARK_DESTINATION';
                _lastResult = 'SUCCESS';
                _rejectionReason = 'NONE';
                _updateNative3DRoute();
                Navigator.of(context).pop();
                if (mounted) {
                  setState(() {});
                  _showSuccessSnackBar('Destination "$name" tagged at Node ${lastNode.sequence}');
                }
              }
            },
            child: const Text('SAVE DESTINATION', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleReset() {
    _arService.clearNodeAnchors();
    _arService.clearNavigationRoute();
    _engine.initializeRegistration(
      buildingId: widget.buildingId,
      floorId: widget.floorId,
    );
    _anchorCount = 0;
    _lastAction = 'RESET';
    _lastResult = 'SUCCESS';
    _rejectionReason = 'NONE';
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration Reset cleanly. Tap "+ ADD NODE" to place Node 0.'),
          backgroundColor: Colors.grey,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.grey.shade900,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showWarningSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.amber),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.grey.shade900,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _saveAndGenerateQR() async {
    final graph = _engine.finishAndProcessGraph();
    final validator = GraphValidator();
    final validationResult = validator.validateGraph(
      graph,
      destinations: _engine.capturedDestinations,
    );

    final targetStatus = validationResult.isValid ? 'ready' : 'draft';

    final existingFloor = await widget.repository.getFloorById(widget.buildingId, widget.floorId);
    final updatedFloor = Floor(
      floorId: existingFloor?.floorId ?? widget.floorId,
      buildingId: existingFloor?.buildingId ?? widget.buildingId,
      floorNumber: existingFloor?.floorNumber ?? 1,
      name: existingFloor?.name ?? widget.floorName,
      origin: _engine.origin ?? existingFloor?.origin,
      nodes: _engine.capturedNodes,
      edges: _engine.capturedEdges,
      destinations: _engine.capturedDestinations,
      registrationStatus: targetStatus,
      updatedAt: DateTime.now(),
      createdAt: existingFloor?.createdAt ?? DateTime.now(),
      version: existingFloor?.version ?? 1,
    );

    await widget.repository.saveFloor(updatedFloor);

    final building = await widget.repository.getBuildingById(widget.buildingId);
    final buildingName = building?.name ?? 'Building';

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: validationResult.isValid ? Colors.green : Colors.orange,
        content: Text(
          validationResult.isValid
              ? 'Floor navigation graph saved and QR code generated!'
              : 'Floor saved as DRAFT. Add destinations to complete graph.',
        ),
      ),
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => FloorQrScreen(
          buildingName: buildingName,
          floor: updatedFloor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Register: ${widget.floorName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _arService.resetARSession();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('AR Session Reset. Recalibrating tracking...'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            tooltip: 'Reset AR Session',
          ),
          Row(
            children: [
              const Text('TEST MODE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              Switch(
                value: _isDeveloperTestMode,
                onChanged: _toggleDeveloperTestMode,
                activeThumbColor: AppTheme.primaryCyan,
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // Native Golden Reference AR Surface PlatformView
          _buildARView(),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildSafetyBanner(),
                  const SizedBox(height: 8),
                  _buildDiagnosticsDropdown(),
                  const Spacer(),
                  if (_isDeveloperTestMode) _buildDeveloperControls(),
                  const SizedBox(height: 12),
                  _buildActionControls(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildARView() {
    if (!_hasCameraPermission && !_isDeveloperTestMode) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              color: AppTheme.cardDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.camera_alt_outlined, size: 56, color: Colors.orangeAccent),
                    const SizedBox(height: 16),
                    const Text(
                      'Camera Permission Required',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Camera permission is required to register a floor using live ARCore spatial tracking.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryCyan),
                      onPressed: _initPermissionsAndAR,
                      icon: const Icon(Icons.check_circle_outline, color: Colors.black),
                      label: const Text('ALLOW CAMERA / TRY AGAIN', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (_isDeveloperTestMode) {
      return Container(
        color: Colors.black87,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.developer_mode_rounded, size: 64, color: AppTheme.primaryCyan),
              const SizedBox(height: 12),
              const Text(
                'DEVELOPER TEST MODE',
                style: TextStyle(
                  color: AppTheme.primaryCyan,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Current 3D Pose: [${_currentPose.position.x.toStringAsFixed(1)}, ${_currentPose.position.y.toStringAsFixed(1)}, ${_currentPose.position.z.toStringAsFixed(1)}]',
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
      );
    }

    const String viewType = 'com.pathlume.app/ar_view';
    const Map<String, dynamic> creationParams = <String, dynamic>{};

    return PlatformViewLink(
      key: const ValueKey('pathlume_registration_ar_view'),
      viewType: viewType,
      surfaceFactory: (context, controller) {
        return AndroidViewSurface(
          controller: controller as AndroidViewController,
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        );
      },
      onCreatePlatformView: (params) {
        return PlatformViewsService.initSurfaceAndroidView(
          id: params.id,
          viewType: viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () {
            params.onFocusChanged(true);
          },
        )
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..create();
      },
    );
  }

  Widget _buildSafetyBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.amber.shade900.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Stay aware of your surroundings while walking. Do not use device on stairs.',
              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticsDropdown() {
    final lastNodePos = _engine.capturedNodes.isNotEmpty
        ? _engine.capturedNodes.last.position
        : null;
    final distFromLast = lastNodePos != null
        ? _currentPose.position.distanceTo(lastNodePos)
        : 0.0;
    final poseAge = _currentPose.ageMs;
    final isPoseFresh = _currentPose.isFresh();

    return Card(
      color: AppTheme.cardDark.withValues(alpha: 0.92),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppTheme.primaryCyan.withValues(alpha: 0.4)),
      ),
      elevation: 6,
      margin: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () {
              setState(() => _isDiagnosticsExpanded = !_isDiagnosticsExpanded);
            },
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 10,
                        color: _getTrackingColor(),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'TRACKING: ${_trackingState.displayName.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _getTrackingColor(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryCyan.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_engine.capturedNodes.length} Node(s) • ${_engine.totalDistance.toStringAsFixed(1)}m',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryCyan,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        _isDiagnosticsExpanded ? 'Hide Details' : 'Status Panel ▾',
                        style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _isDiagnosticsExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.primaryCyan,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (_isDiagnosticsExpanded) ...[
            const Divider(height: 1, color: Colors.white12),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetric('TRACKING', _trackingState.displayName, _getTrackingColor()),
                      _buildMetric('POSE FRESH', isPoseFresh ? 'YES' : 'NO', isPoseFresh ? Colors.greenAccent : Colors.redAccent),
                      _buildMetric('NODES', '${_engine.capturedNodes.length}', Colors.white),
                      _buildMetric('ANCHORS', '$_anchorCount', Colors.cyanAccent),
                      _buildMetric('POSE AGE', poseAge > 9000 ? 'N/A' : '$poseAge ms', poseAge <= 500 ? Colors.greenAccent : Colors.orangeAccent),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'AR SESSION: ACTIVE | VIEW: ALIVE | STATE: ${_engine.state.name.toUpperCase()}',
                        style: const TextStyle(fontSize: 10, color: AppTheme.primaryCyan, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                      ),
                      const Text(
                        'GL SURFACE: ALIVE',
                        style: TextStyle(fontSize: 10, color: Colors.greenAccent, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CURRENT: (${_currentPose.position.x.toStringAsFixed(2)}, ${_currentPose.position.y.toStringAsFixed(2)}, ${_currentPose.position.z.toStringAsFixed(2)})',
                        style: const TextStyle(fontSize: 10, color: Colors.white70, fontFamily: 'monospace'),
                      ),
                      Text(
                        'LAST NODE: ${lastNodePos != null ? "(${lastNodePos.x.toStringAsFixed(2)}, ${lastNodePos.y.toStringAsFixed(2)}, ${lastNodePos.z.toStringAsFixed(2)})" : "N/A"}',
                        style: const TextStyle(fontSize: 10, color: Colors.white70, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'DIST: ${distFromLast.toStringAsFixed(2)}m',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: distFromLast >= 0.1 ? Colors.greenAccent : Colors.amberAccent,
                        ),
                      ),
                      Text(
                        'ACTION: $_lastAction | RESULT: $_lastResult',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _lastResult == 'SUCCESS' ? Colors.greenAccent : (_lastResult == 'REJECTED' ? Colors.redAccent : Colors.white70),
                        ),
                      ),
                    ],
                  ),
                  if (_rejectionReason.isNotEmpty && _rejectionReason != 'NONE') ...[
                    const SizedBox(height: 4),
                    Text(
                      'REASON: $_rejectionReason',
                      style: const TextStyle(fontSize: 10, color: Colors.orangeAccent, fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getTrackingColor() {
    switch (_trackingState) {
      case ARTrackingState.tracking:
        return Colors.greenAccent;
      case ARTrackingState.initializing:
        return Colors.orangeAccent;
      default:
        return Colors.redAccent;
    }
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildDeveloperControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade900.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('SIMULATE WALKING:', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              backgroundColor: AppTheme.accentBlue,
            ),
            onPressed: () {
              if (_arService is SimulatedARService) {
                final pose = (_arService as SimulatedARService).advanceSimulatedPose();
                if (_engine.state == RegistrationState.registering) {
                  _engine.tryAutomaticSamplingCandidate(pose.position);
                }
              }
            },
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: const Text('SIMULATE STEP', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionControls() {
    return Column(
      children: [
        // Tagging Toolbar
        if (_engine.capturedNodes.isNotEmpty) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.turn_right_rounded, size: 16, color: AppTheme.primaryCyan),
                  label: const Text('MARK TURN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  backgroundColor: AppTheme.cardDark,
                  side: const BorderSide(color: AppTheme.primaryCyan),
                  onPressed: () => _handleMarkTag(NodeType.turn),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.door_front_door_rounded, size: 16, color: Colors.purpleAccent),
                  label: const Text('MARK DOOR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  backgroundColor: AppTheme.cardDark,
                  side: const BorderSide(color: Colors.purpleAccent),
                  onPressed: () => _handleMarkTag(NodeType.door),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.place_rounded, size: 16, color: Colors.greenAccent),
                  label: const Text('MARK DESTINATION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  backgroundColor: AppTheme.cardDark,
                  side: const BorderSide(color: Colors.greenAccent),
                  onPressed: () => _handleMarkTag(NodeType.destination),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Primary Action Button: + ADD NODE
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryCyan,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
            ),
            onPressed: _handleAddNode,
            icon: const Icon(Icons.add_location_alt_rounded, size: 24),
            label: Text(
              _engine.capturedNodes.isEmpty
                  ? '+ ADD START NODE (NODE 0)'
                  : '+ ADD NODE (${_engine.capturedNodes.length})',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // RESET Button
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: Colors.amber.shade400, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _handleReset,
                icon: Icon(Icons.refresh_rounded, color: Colors.amber.shade400, size: 18),
                label: Text(
                  'RESET',
                  style: TextStyle(color: Colors.amber.shade400, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // SAVE ROUTE Button
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: _engine.capturedNodes.isNotEmpty ? Colors.greenAccent : Colors.grey.shade800,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                onPressed: _engine.capturedNodes.isNotEmpty ? _saveAndGenerateQR : null,
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text(
                  'SAVE ROUTE',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
