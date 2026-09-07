import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../../app/app_theme.dart';
import '../../../models/ar_pose.dart';
import '../../../models/building.dart';
import '../../../models/floor.dart';
import '../../../models/localization_state.dart';
import '../../../models/navigation_session.dart';
import '../../../models/qr_payload.dart';
import '../../../services/android_ar_service.dart';
import '../../../services/ar_service.dart';
import '../../../services/localization/localization_service.dart';
import '../../../services/qr/qr_localization_provider.dart';
import '../../../services/qr/simulated_qr_localization_provider.dart';
import '../../../services/repositories/building_repository.dart';
import '../../../services/simulated_ar_service.dart';
import '../../navigation/presentation/destination_selection_screen.dart';
import 'localization_diagnostics_screen.dart';
import 'qr_scanner_screen.dart';

class LocalizationScreen extends StatefulWidget {
  final String buildingId;
  final String floorId;
  final BuildingRepository repository;

  const LocalizationScreen({
    super.key,
    required this.buildingId,
    required this.floorId,
    required this.repository,
  });

  @override
  State<LocalizationScreen> createState() => _LocalizationScreenState();
}

class _LocalizationScreenState extends State<LocalizationScreen> {
  Building? _building;
  Floor? _floor;
  bool _isLoading = true;
  bool _isTestMode = false;

  late ARService _arService;
  late QRLocalizationProvider _qrProvider;
  late LocalizationService _localizationService;

  NavigationSession? _session;
  StreamSubscription<NavigationSession>? _sessionSub;

  @override
  void initState() {
    super.initState();
    _initServices();
    _loadDataAndStart();
  }

  void _initServices() {
    _sessionSub?.cancel();
    if (_isTestMode) {
      _arService = SimulatedARService();
      _qrProvider = SimulatedQRLocalizationProvider(
        targetBuildingId: widget.buildingId,
        targetFloorId: widget.floorId,
      );
    } else {
      _arService = AndroidARService();
      _qrProvider = AndroidQRLocalizationProvider();
    }

    _localizationService = LocalizationService(
      arService: _arService,
      qrProvider: _qrProvider,
      repository: widget.repository,
    );

    _sessionSub = _localizationService.sessionStream.listen((session) {
      if (mounted) {
        setState(() {
          _session = session;
        });
      }
    });
  }

  Future<void> _loadDataAndStart() async {
    setState(() => _isLoading = true);
    _building = await widget.repository.getBuildingById(widget.buildingId);
    _floor = await widget.repository.getFloorById(widget.buildingId, widget.floorId);

    setState(() => _isLoading = false);

    if (_isTestMode) {
      _localizationService.startLocalizationSession(
        buildingId: widget.buildingId,
        floorId: widget.floorId,
      );
    } else {
      _promptQrScan();
    }
  }

  Future<void> _promptQrScan() async {
    final payload = await Navigator.of(context).push<QRPayload>(
      MaterialPageRoute(
        builder: (_) => QrScannerScreen(
          buildingId: widget.buildingId,
          floorId: widget.floorId,
          floorName: _floor?.name ?? 'Floor',
          repository: widget.repository,
        ),
      ),
    );

    if (payload != null) {
      _localizationService.startLocalizationSession(
        buildingId: widget.buildingId,
        floorId: widget.floorId,
      );
    }
  }

  void _toggleTestMode(bool val) {
    setState(() {
      _isTestMode = val;
    });
    _localizationService.dispose();
    _initServices();
    _loadDataAndStart();
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    _localizationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_floor?.name ?? "Floor"} Localization'),
        actions: [
          Row(
            children: [
              const Text('TEST MODE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              Switch(
                value: _isTestMode,
                onChanged: _toggleTestMode,
                activeThumbColor: AppTheme.primaryCyan,
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.bug_report_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LocalizationDiagnosticsScreen(
                    buildingName: _building?.name ?? 'Building',
                    floorName: _floor?.name ?? 'Floor',
                    service: _localizationService,
                  ),
                ),
              );
            },
            tooltip: 'Developer Diagnostics',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                _buildARView(),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderCard(),
                        const SizedBox(height: 20),
                        if (_localizationService.state == LocalizationState.waitingForQrPose)
                          _buildWaitingForPoseNotice(),
                        _buildStatusCard(),
                        const SizedBox(height: 20),
                        _buildPositionCard(),
                        const Spacer(),
                        if (_isTestMode) _buildSimulatedStepControl(),
                        const SizedBox(height: 16),
                        _buildActionButtons(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildARView() {
    if (_isTestMode) return const SizedBox.shrink();

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

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _building?.name ?? 'Building',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            _floor?.name ?? 'Floor',
            style: const TextStyle(fontSize: 14, color: AppTheme.primaryCyan, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final state = _localizationService.state;
    final conf = _localizationService.confidence;

    final isQrDetected = state != LocalizationState.scanningQr && state != LocalizationState.idle && state != LocalizationState.error;
    final isPoseAcquired = state == LocalizationState.localized || state == LocalizationState.tracking || state == LocalizationState.degraded || state == LocalizationState.qrPoseAcquired;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatusItem('QR PAYLOAD', isQrDetected ? '✓ MATCHED' : 'SCANNING', isQrDetected ? Colors.greenAccent : Colors.amber),
              _buildStatusItem('3D SPATIAL POSE', isPoseAcquired ? '✓ ACQUIRED' : (state == LocalizationState.waitingForQrPose ? 'PENDING' : 'SEARCHING'), isPoseAcquired ? Colors.greenAccent : Colors.amber),
              _buildStatusItem('CONFIDENCE', conf.displayName, _getConfidenceColor(conf)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingForPoseNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.amber.shade900.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amberAccent),
      ),
      child: const Row(
        children: [
          Icon(Icons.center_focus_weak_rounded, color: Colors.amberAccent, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'QR detected! PATHLUME identified this floor, but the physical 3D QR position could not yet be established.\nMove the camera closer and keep the QR tag centered.',
              style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Color _getConfidenceColor(LocalizationConfidence conf) {
    switch (conf) {
      case LocalizationConfidence.high:
        return Colors.greenAccent;
      case LocalizationConfidence.medium:
        return Colors.orangeAccent;
      case LocalizationConfidence.low:
        return Colors.amber;
      case LocalizationConfidence.unknown:
        return Colors.redAccent;
    }
  }

  Widget _buildStatusItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildPositionCard() {
    final pos = _session?.currentFloorPosition ?? const Vector3D();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardDark.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_on_rounded, color: AppTheme.primaryCyan, size: 20),
              SizedBox(width: 8),
              Text(
                'CURRENT USER FLOOR POSITION',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryCyan,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCoord('X', pos.x.toStringAsFixed(2)),
              _buildCoord('Y', pos.y.toStringAsFixed(2)),
              _buildCoord('Z', pos.z.toStringAsFixed(2)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Distance Traveled: ${(_session?.distanceTraveledMeters ?? 0.0).toStringAsFixed(1)} m',
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
        ],
      ),
    );
  }

  Widget _buildCoord(String axis, String val) {
    return Column(
      children: [
        Text(axis, style: const TextStyle(fontSize: 11, color: Colors.white54)),
        const SizedBox(height: 4),
        Text(
          '$val m',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildSimulatedStepControl() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade900.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TEST SCENARIOS:', style: TextStyle(fontSize: 11, color: Colors.white70)),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      if (_qrProvider is SimulatedQRLocalizationProvider) {
                        (_qrProvider as SimulatedQRLocalizationProvider).setScenario(SimulationScenario.payloadOnlyNoPose);
                        _localizationService.requestRelocalization();
                      }
                    },
                    child: const Text('NO POSE', style: TextStyle(fontSize: 10, color: Colors.amberAccent)),
                  ),
                  TextButton(
                    onPressed: () {
                      if (_qrProvider is SimulatedQRLocalizationProvider) {
                        (_qrProvider as SimulatedQRLocalizationProvider).setScenario(SimulationScenario.perfectMatchWithPose);
                        _localizationService.requestRelocalization();
                      }
                    },
                    child: const Text('WITH POSE', style: TextStyle(fontSize: 10, color: Colors.greenAccent)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentBlue),
                onPressed: () {
                  if (_arService is SimulatedARService) {
                    (_arService as SimulatedARService).advanceSimulatedPose();
                  }
                },
                icon: const Icon(Icons.directions_walk_rounded, size: 16),
                label: const Text('SIMULATE MOVEMENT', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryCyan,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.all(16),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DestinationSelectionScreen(
                    buildingId: widget.buildingId,
                    floorId: widget.floorId,
                    buildingName: _building?.name ?? 'Building',
                    floorName: _floor?.name ?? 'Floor',
                    repository: widget.repository,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.navigation_rounded),
            label: const Text('START NAVIGATION'),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.all(16),
            side: const BorderSide(color: AppTheme.primaryCyan),
          ),
          onPressed: () {
            _localizationService.requestRelocalization();
            if (!_isTestMode) {
              _promptQrScan();
            }
          },
          icon: const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.primaryCyan),
          label: const Text('RELOCALIZE', style: TextStyle(color: AppTheme.primaryCyan)),
        ),
      ],
    );
  }
}
