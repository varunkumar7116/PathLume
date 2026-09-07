import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../../app/app_theme.dart';
import '../../../models/destination.dart';
import '../../../models/localization_state.dart';
import '../../../models/navigation_session.dart';
import '../../../models/qr_payload.dart';
import '../../../navigation_core/route_projector.dart';
import '../../../services/android_ar_service.dart';
import '../../../services/ar_service.dart';
import '../../../services/localization/localization_service.dart';
import '../../../services/navigation/navigation_service.dart';
import '../../../services/qr/qr_localization_provider.dart';
import '../../../services/qr/simulated_qr_localization_provider.dart';
import '../../../services/repositories/building_repository.dart';
import '../../../services/simulated_ar_service.dart';
import 'navigation_diagnostics_screen.dart';
import '../../localization/presentation/qr_scanner_screen.dart';

class NavigationScreen extends StatefulWidget {
  final String buildingId;
  final String floorId;
  final String buildingName;
  final String floorName;
  final Destination destination;
  final BuildingRepository repository;

  const NavigationScreen({
    super.key,
    required this.buildingId,
    required this.floorId,
    required this.buildingName,
    required this.floorName,
    required this.destination,
    required this.repository,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  bool _isLoading = true;
  bool _isTestMode = false;

  late ARService _arService;
  late QRLocalizationProvider _qrProvider;
  late LocalizationService _localizationService;
  late NavigationService _navigationService;

  NavigationSession? _session;
  StreamSubscription<NavigationSession>? _navSessionSub;

  @override
  void initState() {
    super.initState();
    _initServices();
    _startSession();
  }

  void _initServices() {
    _navSessionSub?.cancel();
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

    _navigationService = NavigationService(
      localizationService: _localizationService,
      repository: widget.repository,
      arService: _arService,
    );

    _navSessionSub = _navigationService.sessionStream.listen((session) {
      if (mounted) {
        setState(() {
          _session = session;
        });
      }
    });
  }

  Future<void> _startSession() async {
    setState(() => _isLoading = true);

    if (_isTestMode) {
      await _localizationService.startLocalizationSession(
        buildingId: widget.buildingId,
        floorId: widget.floorId,
      );
      await _navigationService.startNavigation(
        buildingId: widget.buildingId,
        floorId: widget.floorId,
        destinationId: widget.destination.destinationId,
      );
    } else {
      await _promptQrScan();
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _promptQrScan() async {
    final payload = await Navigator.of(context).push<QRPayload>(
      MaterialPageRoute(
        builder: (_) => QrScannerScreen(
          buildingId: widget.buildingId,
          floorId: widget.floorId,
          floorName: widget.floorName,
          repository: widget.repository,
        ),
      ),
    );

    if (payload != null) {
      await _localizationService.startLocalizationSession(
        buildingId: widget.buildingId,
        floorId: widget.floorId,
      );
      await _navigationService.startNavigation(
        buildingId: widget.buildingId,
        floorId: widget.floorId,
        destinationId: widget.destination.destinationId,
      );
    }
  }

  void _toggleTestMode(bool val) {
    setState(() {
      _isTestMode = val;
    });
    _navigationService.dispose();
    _localizationService.dispose();
    _initServices();
    _startSession();
  }

  @override
  void dispose() {
    _navSessionSub?.cancel();
    _navigationService.dispose();
    _localizationService.dispose();
    super.dispose();
  }

  Future<bool> _confirmExitNavigation() async {
    if (_session?.navigationState == NavigationState.arrived) {
      _navigationService.stopNavigation();
      return true;
    }
    final shouldStop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop Navigation?'),
        content: Text('Are you sure you want to end active navigation to "${widget.destination.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('STOP NAVIGATION'),
          ),
        ],
      ),
    );
    if (shouldStop == true) {
      _navigationService.stopNavigation();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _confirmExitNavigation();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('AR Nav: ${widget.destination.name}'),
          actions: [
            Row(
              children: [
                const Text('TEST', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
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
                    builder: (_) => NavigationDiagnosticsScreen(
                      buildingName: widget.buildingName,
                      floorName: widget.floorName,
                      navigationService: _navigationService,
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
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          if (_isTestMode) _buildSimulationBadge(),
                          if (_session?.navigationState == NavigationState.relocalizing)
                            _buildTrackingPausedWarning(),
                          _buildTurnInstructionHeader(),
                          const SizedBox(height: 16),
                          _buildNavigationStateCard(),
                          const Spacer(),
                          if (_session?.navigationState == NavigationState.arrived)
                            _buildArrivalBanner(),
                          if (_isTestMode) _buildSimulatedMovementControl(),
                          const SizedBox(height: 16),
                          _buildBottomControls(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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

  Widget _buildSimulationBadge() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.amber.shade900.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amberAccent),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.science_rounded, color: Colors.amberAccent, size: 16),
          SizedBox(width: 8),
          Text(
            'SIMULATION MODE ACTIVE (DEV TESTING ONLY)',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingPausedWarning() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.orange.shade900.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orangeAccent),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'AR tracking paused. Move phone slowly to recover tracking or scan QR code.',
              style: TextStyle(fontSize: 11, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTurnInstructionHeader() {
    final instruction = _session?.nextInstruction ?? TurnInstruction.straight;
    final dist = _session?.distanceRemainingMeters ?? 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryCyan.withValues(alpha: 0.15),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: AppTheme.primaryCyan,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getInstructionIcon(instruction),
              size: 36,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  instruction.displayName.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${dist.toStringAsFixed(1)} meters remaining',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.primaryCyan,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getInstructionIcon(TurnInstruction inst) {
    switch (inst) {
      case TurnInstruction.straight:
        return Icons.arrow_upward_rounded;
      case TurnInstruction.slightLeft:
        return Icons.turn_slight_left_rounded;
      case TurnInstruction.left:
        return Icons.turn_left_rounded;
      case TurnInstruction.slightRight:
        return Icons.turn_slight_right_rounded;
      case TurnInstruction.right:
        return Icons.turn_right_rounded;
      case TurnInstruction.uTurn:
        return Icons.u_turn_left_rounded;
      case TurnInstruction.arriving:
        return Icons.check_circle_rounded;
    }
  }

  Widget _buildNavigationStateCard() {
    final navState = _session?.navigationState ?? NavigationState.idle;
    final locState = _localizationService.state;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardDark.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildInfoItem('DESTINATION', widget.destination.name),
          _buildInfoItem('NAV STATE', navState.displayName, _getNavStateColor(navState)),
          _buildInfoItem('AR TRACKING', locState.displayName, Colors.greenAccent),
        ],
      ),
    );
  }

  Color _getNavStateColor(NavigationState state) {
    switch (state) {
      case NavigationState.navigating:
        return Colors.greenAccent;
      case NavigationState.arrived:
        return AppTheme.primaryCyan;
      case NavigationState.offRoute:
      case NavigationState.relocalizing:
        return Colors.amberAccent;
      case NavigationState.error:
        return Colors.redAccent;
      default:
        return Colors.white70;
    }
  }

  Widget _buildInfoItem(String label, String val, [Color color = Colors.white]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54)),
        const SizedBox(height: 2),
        Text(val, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildArrivalBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.green.shade900.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.greenAccent),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.stars_rounded, color: Colors.amberAccent, size: 36),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'YOU HAVE ARRIVED!',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'Destination (${widget.destination.name}) reached.',
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () {
                _navigationService.stopNavigation();
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text('DONE', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulatedMovementControl() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade900.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('SIMULATE USER STEP:', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentBlue),
            onPressed: () {
              if (_arService is SimulatedARService) {
                (_arService as SimulatedARService).advanceSimulatedPose();
              }
            },
            icon: const Icon(Icons.directions_walk_rounded, size: 16),
            label: const Text('WALK FORWARD', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              side: const BorderSide(color: AppTheme.primaryCyan),
            ),
            onPressed: () {
              _localizationService.requestRelocalization();
              if (!_isTestMode) _promptQrScan();
            },
            icon: const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.primaryCyan),
            label: const Text('RELOCALIZE', style: TextStyle(color: AppTheme.primaryCyan)),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade900,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(16),
          ),
          onPressed: () async {
            final shouldExit = await _confirmExitNavigation();
            if (shouldExit && mounted) {
              Navigator.of(context).pop();
            }
          },
          icon: const Icon(Icons.stop_rounded),
          label: const Text('EXIT NAV'),
        ),
      ],
    );
  }
}
