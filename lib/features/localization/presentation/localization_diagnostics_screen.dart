import 'package:flutter/material.dart';
import '../../../app/app_theme.dart';
import '../../../models/ar_pose.dart';
import '../../../models/ar_tracking_state.dart';
import '../../../models/localization_state.dart';
import '../../../services/localization/localization_service.dart';

class LocalizationDiagnosticsScreen extends StatelessWidget {
  final String buildingName;
  final String floorName;
  final LocalizationService service;

  const LocalizationDiagnosticsScreen({
    super.key,
    required this.buildingName,
    required this.floorName,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    final session = service.currentSession;
    final worldPose = session?.currentWorldPose;
    final floorPos = session?.currentFloorPosition ?? const Vector3D();
    final transform = session?.transform;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Diagnostics'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DEVELOPER DIAGNOSTICS PANEL',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryCyan,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              _buildDiagCard('CONTEXT METADATA', [
                _buildRow('Building', buildingName),
                _buildRow('Floor', floorName),
                _buildRow('Origin ID', session?.originId ?? 'Not initialized'),
              ]),
              const SizedBox(height: 16),
              _buildDiagCard('STATE & CONFIDENCE', [
                _buildRow('Localization State', service.state.displayName),
                _buildRow('Confidence', service.confidence.displayName),
                _buildRow('Distance Traveled', '${(session?.distanceTraveledMeters ?? 0.0).toStringAsFixed(1)} m'),
              ]),
              const SizedBox(height: 16),
              _buildDiagCard('RAW ARCORE WORLD POSE', [
                _buildRow('World Position (X,Y,Z)', '[${(worldPose?.position.x ?? 0.0).toStringAsFixed(2)}, ${(worldPose?.position.y ?? 0.0).toStringAsFixed(2)}, ${(worldPose?.position.z ?? 0.0).toStringAsFixed(2)}]'),
                _buildRow('World Rotation (X,Y,Z,W)', '[${(worldPose?.rotation.x ?? 0.0).toStringAsFixed(2)}, ${(worldPose?.rotation.y ?? 0.0).toStringAsFixed(2)}, ${(worldPose?.rotation.z ?? 0.0).toStringAsFixed(2)}, ${(worldPose?.rotation.w ?? 1.0).toStringAsFixed(2)}]'),
                _buildRow('ARCore Tracking', worldPose?.trackingState.displayName ?? 'INITIALIZING'),
              ]),
              const SizedBox(height: 16),
              _buildDiagCard('RIGID ALIGNMENT TRANSFORM (T)', [
                _buildRow('Translation Offset (t)', '[${(transform?.translation.x ?? 0.0).toStringAsFixed(2)}, ${(transform?.translation.y ?? 0.0).toStringAsFixed(2)}, ${(transform?.translation.z ?? 0.0).toStringAsFixed(2)}]'),
                _buildRow('Rotation Delta (R)', '[${(transform?.rotation.x ?? 0.0).toStringAsFixed(2)}, ${(transform?.rotation.y ?? 0.0).toStringAsFixed(2)}, ${(transform?.rotation.z ?? 0.0).toStringAsFixed(2)}, ${(transform?.rotation.w ?? 1.0).toStringAsFixed(2)}]'),
                _buildRow('Scale', '${transform?.scale ?? 1.0}'),
              ]),
              const SizedBox(height: 16),
              _buildDiagCard('TRANSFORMED USER FLOOR POSITION', [
                _buildRow('Floor Position (X,Y,Z)', '[${floorPos.x.toStringAsFixed(2)}, ${floorPos.y.toStringAsFixed(2)}, ${floorPos.z.toStringAsFixed(2)}]'),
              ]),
              const SizedBox(height: 16),
              _buildDiagCard('SPATIAL DEBUG MARKERS', [
                _buildRow('QR ORIGIN MARKER', '● World [0.0, 0.0, 0.0]'),
                _buildRow('USER MARKER', '● Floor [${floorPos.x.toStringAsFixed(1)}, ${floorPos.y.toStringAsFixed(1)}, ${floorPos.z.toStringAsFixed(1)}]'),
                _buildRow('TEST POINT MARKER', '● Floor [1.0, 0.0, 2.0]'),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiagCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppTheme.accentBlue,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Colors.white),
          ),
        ],
      ),
    );
  }
}
