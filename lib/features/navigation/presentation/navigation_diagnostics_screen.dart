import 'package:flutter/material.dart';
import '../../../app/app_theme.dart';
import '../../../models/ar_pose.dart';
import '../../../models/ar_tracking_state.dart';
import '../../../models/localization_state.dart';
import '../../../models/navigation_session.dart';
import '../../../navigation_core/route_projector.dart';
import '../../../services/navigation/navigation_service.dart';

class NavigationDiagnosticsScreen extends StatelessWidget {
  final String buildingName;
  final String floorName;
  final NavigationService navigationService;

  const NavigationDiagnosticsScreen({
    super.key,
    required this.buildingName,
    required this.floorName,
    required this.navigationService,
  });

  @override
  Widget build(BuildContext context) {
    final session = navigationService.currentSession;
    final worldPose = session?.currentWorldPose;
    final floorPos = session?.currentFloorPosition ?? const Vector3D();
    final activeRoute = session?.activeRoute;
    final waypointCount = activeRoute?.pathNodes.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigation Diagnostics'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DEVELOPER NAVIGATION DIAGNOSTICS',
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
              _buildDiagCard('ARCORE TRACKING & POSE', [
                _buildRow(
                  'AR Tracking State',
                  worldPose?.trackingState.displayName ?? 'INITIALIZING',
                ),
                _buildRow(
                  'Pose Age / Freshness',
                  worldPose != null ? '${worldPose.ageMs}ms · ${worldPose.isFresh() ? "FRESH" : "STALE"}' : 'N/A',
                ),
                _buildRow(
                  'User World Pos (X,Y,Z)',
                  '[${(worldPose?.position.x ?? 0.0).toStringAsFixed(2)}, ${(worldPose?.position.y ?? 0.0).toStringAsFixed(2)}, ${(worldPose?.position.z ?? 0.0).toStringAsFixed(2)}]',
                ),
                _buildRow(
                  'User Floor Pos (X,Y,Z)',
                  '[${floorPos.x.toStringAsFixed(2)}, ${floorPos.y.toStringAsFixed(2)}, ${floorPos.z.toStringAsFixed(2)}]',
                ),
              ]),
              const SizedBox(height: 16),
              _buildDiagCard('COORDINATE ALIGNMENT', [
                _buildRow('Floor Coordinate System', 'Meters (Rigid Transform)'),
                _buildRow('AR World Coordinate System', 'Meters (ARCore 6DoF)'),
                _buildRow('Transform Scale Factor', '1.0 (Fixed Rigid)'),
                _buildRow('Confidence Level', session?.confidence.name.toUpperCase() ?? 'UNKNOWN'),
              ]),
              const SizedBox(height: 16),
              _buildDiagCard('ROUTE & WAYPOINTS', [
                _buildRow('Start Node ID', session?.startNodeId ?? 'N/A'),
                _buildRow('Destination ID', session?.destinationId ?? 'N/A'),
                _buildRow('Current Waypoint', '${session?.currentWaypointIndex ?? 0} / $waypointCount'),
                _buildRow('Remaining Distance', '${(session?.distanceRemainingMeters ?? 0.0).toStringAsFixed(1)} m'),
                _buildRow('Next Instruction', session?.nextInstruction.displayName ?? 'Straight'),
              ]),
              const SizedBox(height: 16),
              _buildDiagCard('PIPELINE & RELOCALIZATION', [
                _buildRow('Navigation Status', session?.navigationState.displayName ?? 'IDLE'),
                _buildRow('Localization Status', session?.localizationState.displayName ?? 'IDLE'),
                _buildRow('Off-Route Status', session?.navigationState == NavigationState.offRoute ? 'TRUE' : 'FALSE'),
                _buildRow('3D OpenGL Route Nodes', '$waypointCount path waypoints'),
                _buildRow('Observed Anchor Displacement', '0.000 m (Diagnostic Locked)'),
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
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
