import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../../app/app_theme.dart';
import '../../../models/ar_pose.dart';
import '../../../models/ar_tracking_state.dart';
import '../../../services/android_ar_service.dart';
import '../../../services/ar_service.dart';

class ArTestScreen extends StatefulWidget {
  const ArTestScreen({super.key});

  @override
  State<ArTestScreen> createState() => _ArTestScreenState();
}

class _ArTestScreenState extends State<ArTestScreen> {
  late final ARService _arService;

  ARTrackingState _trackingState = ARTrackingState.initializing;
  ARPose _currentPose = const ARPose();
  bool _isCheckingARCore = true;
  bool _isCameraPermissionGranted = false;
  bool _isARSupported = true;

  StreamSubscription<ARTrackingState>? _trackingSubscription;
  StreamSubscription<ARPose>? _poseSubscription;

  @override
  void initState() {
    super.initState();
    _arService = AndroidARService();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AR TEST'),
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
          // Native ARView / Camera Surface PlatformView
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
                  _buildControlButtons(),
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
    final anchorText = _currentPose.isMarkerPlaced ? 'ACTIVE' : 'NONE';

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
                'AR DIAGNOSTICS',
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
              _buildDiagItem('Anchor', anchorText, _currentPose.isMarkerPlaced ? Colors.greenAccent : Colors.white54),
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
      description = 'Grant camera permission to start AR scan.';
    } else if (_trackingState == ARTrackingState.initializing) {
      title = 'Tracking: INITIALIZING';
      description = 'Move your phone slowly to scan the environment.';
    } else if (_trackingState == ARTrackingState.tracking) {
      if (_currentPose.isMarkerPlaced) {
        title = 'Marker: PLACED';
        description = 'Move around slowly and observe whether the marker remains fixed in the environment.';
      } else {
        title = 'Tracking: TRACKING';
        description = 'Press PLACE MARKER to position 3D anchor.';
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
              'Camera permission is required for PATHLUME AR navigation.',
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

  Widget _buildControlButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: (_trackingState == ARTrackingState.tracking && _isARSupported)
                ? () async {
                    await _arService.placeTestMarker();
                  }
                : null,
            icon: const Icon(Icons.add_location_alt_rounded),
            label: Text(_currentPose.isMarkerPlaced ? 'RE-PLACE MARKER' : 'PLACE MARKER'),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            side: const BorderSide(color: AppTheme.primaryCyan),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () async {
            await _arService.resetARSession();
          },
          child: const Text('RESET', style: TextStyle(color: AppTheme.primaryCyan)),
        ),
      ],
    );
  }
}

