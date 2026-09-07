import 'dart:async';
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
import '../../../navigation_core/graph_validator.dart';
import '../../../navigation_core/registration_engine.dart';
import '../../../services/android_ar_service.dart';
import '../../../services/ar_service.dart';
import '../../../services/repositories/building_repository.dart';
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
  late final ARService _arService;
  late final RegistrationEngine _engine;

  ARTrackingState _trackingState = ARTrackingState.initializing;
  ARPose _currentPose = const ARPose();
  bool _isCheckingARCore = true;
  bool _isCameraPermissionGranted = false;
  bool _isARSupported = true;

  StreamSubscription<ARTrackingState>? _trackingSubscription;
  StreamSubscription<ARPose>? _poseSubscription;

  int _placedAnchorCount = 0;

  @override
  void initState() {
    super.initState();
    _arService = AndroidARService();
    _engine = RegistrationEngine();
    _engine.initializeRegistration(
      buildingId: widget.buildingId,
      floorId: widget.floorId,
    );
    _initializeAR();
  }

  Future<void> _initializeAR() async {
    setState(() {
      _isCheckingARCore = true;
    });

    final supported = await _arService.isARSupported();
    if (!mounted) return;

    if (!supported) {
      setState(() {
        _isARSupported = false;
        _isCheckingARCore = false;
        _trackingState = ARTrackingState.error;
      });
      return;
    }

    final hasPermission = await _arService.checkCameraPermission();
    if (!hasPermission) {
      final granted = await _arService.requestCameraPermission();
      if (!mounted) return;
      if (!granted) {
        setState(() {
          _isCameraPermissionGranted = false;
          _isCheckingARCore = false;
          _trackingState = ARTrackingState.error;
        });
        return;
      }
    }

    setState(() {
      _isCameraPermissionGranted = true;
      _isCheckingARCore = false;
    });

    _trackingSubscription = _arService.trackingStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _trackingState = state;
        });
      }
    });

    _poseSubscription = _arService.poseStream.listen((pose) {
      if (mounted) {
        setState(() {
          _currentPose = pose;
        });
      }
    });

    final success = await _arService.startARSession();
    if (mounted) {
      setState(() {
        if (!success) {
          _trackingState = ARTrackingState.error;
        }
      });
    }
  }

  @override
  void dispose() {
    _trackingSubscription?.cancel();
    _poseSubscription?.cancel();
    _arService.stopARSession();
    _engine.dispose();
    super.dispose();
  }

  void _handleAddNode() async {
    // 1. Send native marker anchor request (Exact AR TEST mechanism)
    final anchorSuccess = await _arService.placeTestMarker();
    if (anchorSuccess) {
      _placedAnchorCount++;
    } else {
      await _arService.addNodeAnchor(
        _currentPose.position.x,
        _currentPose.position.y,
        _currentPose.position.z,
      );
      _placedAnchorCount++;
    }

    // 2. Add node to Registration Engine
    if (_engine.capturedNodes.isEmpty) {
      _engine.setStartPoint(_currentPose);
      _engine.startWalking();
      _engine.addNode(
        position: _currentPose.position,
        rotation: _currentPose.rotation,
        forceAdd: true,
      );
    } else {
      _engine.startWalking();
      _engine.addNode(
        position: _currentPose.position,
        rotation: _currentPose.rotation,
        forceAdd: true,
      );
    }

    // 3. Update native 3D route ribbon geometry
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
    await _arService.updateNavigationRoute(
      points,
      dest ?? (points.isNotEmpty ? points.last : const Vector3D()),
    );

    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _engine.capturedNodes.length == 1
                      ? 'Node 0 (Start Origin) Placed!'
                      : 'Node ${_engine.capturedNodes.length - 1} Added (${_engine.capturedNodes.last.name})',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.grey.shade900,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _handleReset() async {
    await _arService.resetARSession();
    await _arService.clearNodeAnchors();
    await _arService.clearNavigationRoute();
    _engine.initializeRegistration(
      buildingId: widget.buildingId,
      floorId: widget.floorId,
    );
    setState(() {
      _placedAnchorCount = 0;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration & AR Session Reset cleanly.'),
          backgroundColor: Colors.grey,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleMarkTag(NodeType type) {
    if (_engine.capturedNodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one node first before tagging.')),
      );
      return;
    }

    final lastNode = _engine.capturedNodes.last;
    if (type == NodeType.destination) {
      _showDestinationDialog(lastNode);
    } else if (type == NodeType.turn) {
      _engine.markTurn(position: lastNode.position, name: 'Turn ${lastNode.sequence}');
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Node ${lastNode.sequence} tagged as TURN')),
        );
      }
    } else if (type == NodeType.door) {
      _engine.markDoor(position: lastNode.position, name: 'Door ${lastNode.sequence}');
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Node ${lastNode.sequence} tagged as DOOR')),
        );
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
            Text(
              'Tagging Node ${lastNode.sequence} at [${lastNode.position.x.toStringAsFixed(1)}, ${lastNode.position.z.toStringAsFixed(1)}]:',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
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
                Navigator.of(context).pop();
                if (mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Destination "$name" tagged at Node ${lastNode.sequence}')),
                  );
                }
              }
            },
            child: const Text('SAVE DESTINATION', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
            },
            tooltip: 'Reset AR Session',
          )
        ],
      ),
      body: Stack(
        children: [
          // Native Golden Reference ARView / Camera Surface PlatformView
          _buildARView(),

          // AR Overlay Controls & HUD
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDiagnosticsPanel(),
                  const SizedBox(height: 12),
                  _buildGuidanceCard(),
                  const Spacer(),
                  if (!_isCameraPermissionGranted && !_isCheckingARCore && _isARSupported)
                    _buildPermissionErrorCard(),
                  if (!_isARSupported && !_isCheckingARCore)
                    _buildUnsupportedCard(),
                  const SizedBox(height: 16),
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
    const String viewType = 'com.pathlume.app/ar_view';
    const Map<String, dynamic> creationParams = <String, dynamic>{};

    return PlatformViewLink(
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

  Widget _buildDiagnosticsPanel() {
    final arCoreText = _isCheckingARCore
        ? 'CHECKING...'
        : (_isARSupported ? 'READY' : 'UNSUPPORTED');
    final cameraText = _isCameraPermissionGranted ? 'GRANTED' : 'DENIED';
    final trackingText = _trackingState.displayName.toUpperCase();
    final anchorText = _placedAnchorCount > 0 ? 'ACTIVE ($_placedAnchorCount)' : 'NONE';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardDark.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.monitor_heart_rounded, size: 16, color: AppTheme.primaryCyan),
              SizedBox(width: 6),
              Text(
                'AR DIAGNOSTICS & FLOOR MODULE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryCyan,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDiagItem('ARCore', arCoreText, _isARSupported ? Colors.greenAccent : Colors.redAccent),
              _buildDiagItem('Camera', cameraText, _isCameraPermissionGranted ? Colors.greenAccent : Colors.redAccent),
              _buildDiagItem('Tracking', trackingText, _getTrackingColor()),
              _buildDiagItem('Anchors', anchorText, _placedAnchorCount > 0 ? Colors.greenAccent : Colors.white54),
              _buildDiagItem('Nodes', '${_engine.capturedNodes.length}', AppTheme.primaryCyan),
            ],
          ),
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
      case ARTrackingState.paused:
        return Colors.amber;
      case ARTrackingState.error:
      case ARTrackingState.stopped:
        return Colors.redAccent;
    }
  }

  Widget _buildDiagItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.white54),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildGuidanceCard() {
    String title = '';
    String description = '';

    if (_isCheckingARCore) {
      title = 'Checking ARCore...';
      description = 'Verifying AR capabilities on your device.';
    } else if (!_isARSupported) {
      title = 'ARCore Unsupported';
      description = 'This device does not support PATHLUME AR.';
    } else if (!_isCameraPermissionGranted) {
      title = 'Camera Permission Needed';
      description = 'Grant camera permission to start AR registration.';
    } else if (_trackingState == ARTrackingState.initializing) {
      title = 'Tracking: INITIALIZING';
      description = 'Move your phone slowly to scan the environment.';
    } else if (_trackingState == ARTrackingState.tracking) {
      if (_engine.capturedNodes.isEmpty) {
        title = 'Tracking: TRACKING';
        description = 'Press "+ ADD NODE" to place Node 0 (Start Origin).';
      } else {
        title = 'Nodes Registered: ${_engine.capturedNodes.length}';
        description = 'Walk to next position and tap "+ ADD NODE", or tap "SAVE ROUTE".';
      }
    } else {
      title = 'Tracking: ${_trackingState.displayName.toUpperCase()}';
      description = 'Re-orient phone or press RESET to restart session.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardDark.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionErrorCard() {
    return Card(
      color: Colors.red.shade900.withValues(alpha: 0.9),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 40),
            const SizedBox(height: 8),
            const Text(
              'Camera Permission Required',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 4),
            const Text(
              'Camera permission is required for PATHLUME AR floor registration.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _initializeAR,
              child: const Text('GRANT PERMISSION'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnsupportedCard() {
    return Card(
      color: Colors.amber.shade900.withValues(alpha: 0.9),
      child: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white, size: 40),
            SizedBox(height: 8),
            Text(
              'This device does not support PATHLUME AR.',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Text(
              'Google ARCore is not available on this Android device.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionControls() {
    return Column(
      children: [
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
        Row(
          children: [
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppTheme.primaryCyan,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: (_trackingState == ARTrackingState.tracking && _isARSupported)
                    ? _handleAddNode
                    : null,
                icon: const Icon(Icons.add_location_alt_rounded),
                label: Text(
                  _engine.capturedNodes.isEmpty
                      ? '+ ADD START NODE (NODE 0)'
                      : '+ ADD NODE (${_engine.capturedNodes.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                side: const BorderSide(color: AppTheme.primaryCyan),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _handleReset,
              child: const Text('RESET', style: TextStyle(color: AppTheme.primaryCyan, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        if (_engine.capturedNodes.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _saveAndGenerateQR,
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text(
                'SAVE ROUTE & GENERATE QR',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
