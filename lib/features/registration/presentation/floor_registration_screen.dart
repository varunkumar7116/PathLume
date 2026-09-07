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

  String _lastAction = 'NONE';
  String _lastResult = 'N/A';
  String _rejectionReason = 'NONE';
  int _anchorCount = 0;
  DateTime _lastPoseLogTime = DateTime.now();

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

  bool _ensureRegistrationActive() {
    if (_engine.state == RegistrationState.preparing) {
      developer.log('[PATHLUME][ADD_NODE] Initializing Start Point (Node 0) at ${_currentPose.position}');
      _engine.setStartPoint(_currentPose);
      _arService.addNodeAnchor(
        _currentPose.position.x,
        _currentPose.position.y,
        _currentPose.position.z,
      );
      _anchorCount++;
      _engine.startWalking();
      _lastResult = 'SUCCESS';
      _rejectionReason = 'NONE';
      return true;
    } else if (_engine.state == RegistrationState.originSet) {
      _engine.startWalking();
    } else if (_engine.state == RegistrationState.paused) {
      _engine.resumeRegistration();
    }
    return false;
  }

  bool _validateARTrackingForAction() {
    if (_isDeveloperTestMode) return true;
    if (_trackingState != ARTrackingState.tracking) {
      _lastResult = 'REJECTED';
      _rejectionReason = 'AR tracking not ready (${_trackingState.displayName}). Move phone slowly to calibrate tracking.';
      if (mounted) setState(() {});
      _showWarningSnackBar(_rejectionReason);
      return false;
    }
    return true;
  }

  void _handleAddNode() {
    _lastAction = 'ADD_NODE';
    developer.log('PATHLUME_AR NODE_CREATE_START timestamp=${_currentPose.timestamp} tracking_state=${_trackingState.displayName} pos=(${_currentPose.position.x.toStringAsFixed(2)}, ${_currentPose.position.y.toStringAsFixed(2)}, ${_currentPose.position.z.toStringAsFixed(2)}) ageMs=${_currentPose.ageMs}');

    if (!_validateARTrackingForAction()) return;

    final createdStartNode = _ensureRegistrationActive();
    if (createdStartNode) {
      developer.log('PATHLUME_AR NODE_CREATED id=0 type=START tracking_state=${_trackingState.displayName}');
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
                SizedBox(width: 8),
                Expanded(child: Text('Start Node (Node 0) Placed! Walk & tap + ADD NODE for next points.')),
              ],
            ),
            backgroundColor: Colors.grey.shade900,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final result = _engine.addNode(
      position: _currentPose.position,
      rotation: _currentPose.rotation,
      forceAdd: true,
    );
    if (result.success && result.node != null) {
      developer.log('PATHLUME_AR NODE_CREATED id=${result.node!.sequence} type=${result.node!.type.nameString} tracking_state=${_trackingState.displayName}');
    }
    _processResult(result);
  }

  void _handleReset() {
    _arService.clearNodeAnchors();
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

  Future<void> _processResult(NodeAddResult result) async {
    if (result.success && result.node != null) {
      developer.log('[PATHLUME][ADD_NODE] RegistrationEngine accepted node ${result.node!.nodeId}');
      developer.log('[PATHLUME][ADD_NODE] Sending anchor request to native ARService for (${result.node!.position.x}, ${result.node!.position.y}, ${result.node!.position.z})');

      final anchorSuccess = await _arService.addNodeAnchor(
        result.node!.position.x,
        result.node!.position.y,
        result.node!.position.z,
      );

      if (anchorSuccess) {
        _anchorCount++;
      }
      _lastResult = 'SUCCESS';
      _rejectionReason = 'NONE';

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
                const SizedBox(width: 8),
                Expanded(child: Text('Added ${result.node!.name}')),
              ],
            ),
            backgroundColor: Colors.grey.shade900,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } else if (!result.success && result.warningMessage != null) {
      _lastResult = 'REJECTED';
      _rejectionReason = result.warningMessage!;
      if (mounted) setState(() {});
      developer.log('[PATHLUME][ADD_NODE] Node add rejected: ${result.warningMessage}');
      _showWarningSnackBar(result.warningMessage!);
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
          // AR Surface PlatformView or Simulated AR View
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

    // High-performance surface composition (1:1 native resolution, zero Virtual Display blur)
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
          // Header Bar (Collapsible Toggle)
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

          // Detailed Expanded Metrics
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
                        'DIST: ${distFromLast.toStringAsFixed(2)}m (MIN: ${_engine.minNodeSpacingMeters.toStringAsFixed(2)}m)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: distFromLast >= _engine.minNodeSpacingMeters ? Colors.greenAccent : Colors.amberAccent,
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

  Widget _buildActionControls() {
    return Column(
      children: [
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
