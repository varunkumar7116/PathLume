import 'package:flutter/material.dart';
import '../../../app/app_theme.dart';
import '../../../models/ar_pose.dart';
import '../../../models/floor.dart';
import '../../../models/floor_origin.dart';
import '../../../navigation_core/graph_validator.dart';
import '../../../navigation_core/registration_engine.dart';
import '../../../services/repositories/building_repository.dart';
import '../../../services/repositories/firebase_building_repository.dart';

import '../../qr/presentation/floor_qr_screen.dart';

class RegistrationSummaryScreen extends StatefulWidget {
  final String buildingId;
  final String floorId;
  final RegistrationEngine engine;
  final RegistrationSummary summary;
  final BuildingRepository repository;

  const RegistrationSummaryScreen({
    super.key,
    required this.buildingId,
    required this.floorId,
    required this.engine,
    required this.summary,
    required this.repository,
  });

  @override
  State<RegistrationSummaryScreen> createState() => _RegistrationSummaryScreenState();
}

class _RegistrationSummaryScreenState extends State<RegistrationSummaryScreen> {
  bool _isProcessing = false;
  late final GraphValidationResult _validationResult;

  @override
  void initState() {
    super.initState();
    final graph = widget.engine.finishAndProcessGraph();
    final validator = GraphValidator();
    _validationResult = validator.validateGraph(
      graph,
      destinations: widget.engine.capturedDestinations,
    );
  }

  Future<void> _processAndSave({bool forceSaveDraft = false, bool generateQr = false}) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });

    try {
      if (!_validationResult.isValid && !forceSaveDraft) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(
              'Cannot mark floor ready: ${_validationResult.errors.firstOrNull ?? "Graph validation failed"}',
            ),
          ),
        );
        return;
      }

      final targetStatus = _validationResult.isValid ? 'ready' : (forceSaveDraft ? 'draft' : 'error');

      final existingFloor = await widget.repository.getFloorById(widget.buildingId, widget.floorId);
      final originId = widget.engine.origin?.originId ?? existingFloor?.originId ?? 'O001';
      final qrPayloadStr = 'PATHLUME_V1|${widget.buildingId}|${widget.floorId}|$originId';

      final finalOrigin = FloorOrigin(
        originId: originId,
        floorId: widget.floorId,
        position: widget.engine.origin?.position ?? existingFloor?.origin?.position ?? const Vector3D(),
        rotation: widget.engine.origin?.rotation ?? existingFloor?.origin?.rotation ?? const Quaternion4D(),
        qrCodePayload: qrPayloadStr,
        createdAt: widget.engine.origin?.createdAt ?? existingFloor?.origin?.createdAt ?? DateTime.now(),
      );

      final updatedFloor = Floor(
        floorId: existingFloor?.floorId ?? widget.floorId,
        buildingId: existingFloor?.buildingId ?? widget.buildingId,
        floorNumber: existingFloor?.floorNumber ?? 1,
        name: existingFloor?.name ?? 'Floor ${widget.floorId}',
        origin: finalOrigin,
        nodes: widget.engine.capturedNodes,
        edges: widget.engine.capturedEdges,
        destinations: widget.engine.capturedDestinations,
        registrationStatus: targetStatus,
        updatedAt: DateTime.now(),
        createdAt: existingFloor?.createdAt ?? DateTime.now(),
        version: existingFloor?.version ?? 1,
      );

      if (widget.repository is FirebaseBuildingRepository) {
        await (widget.repository as FirebaseBuildingRepository)
            .saveFloor(updatedFloor, rethrowCloudErrors: true);
      } else {
        await widget.repository.saveFloor(updatedFloor);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _validationResult.isValid ? Colors.green : Colors.orange,
          content: Text(
            _validationResult.isValid
                ? 'Route Saved Successfully! Floor marked READY.'
                : 'Floor saved as DRAFT. Add destinations to make navigation-ready.',
          ),
        ),
      );

      if (generateQr) {
        final building = await widget.repository.getBuildingById(widget.buildingId);
        final buildingName = building?.name ?? 'Building';

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => FloorQrScreen(
                buildingName: buildingName,
                floor: updatedFloor,
              ),
            ),
          );
        }
        return;
      }

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 6),
            content: Text('Failed to save route to cloud: $e'),
            action: SnackBarAction(
              label: 'RETRY',
              textColor: Colors.white,
              onPressed: () => _processAndSave(forceSaveDraft: forceSaveDraft, generateQr: generateQr),
            ),
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registration Summary'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Registration Summary',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Building ID: ${widget.buildingId} • Floor ID: ${widget.floorId}',
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 16),
                
                // Status Banner
                _buildStatusBanner(),

                const SizedBox(height: 16),

                // Graph Metrics Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'GRAPH METRICS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: AppTheme.primaryCyan,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildSummaryRow(Icons.account_tree_rounded, 'Nodes Captured', '${widget.summary.nodeCount}'),
                        const Divider(color: Colors.white10),
                        _buildSummaryRow(Icons.timeline_rounded, 'Edges Generated', '${widget.summary.edgeCount}'),
                        const Divider(color: Colors.white10),
                        _buildSummaryRow(Icons.straighten_rounded, 'Total Distance', '${widget.summary.totalDistance.toStringAsFixed(1)} m'),
                        const Divider(color: Colors.white10),
                        _buildSummaryRow(Icons.flag_rounded, 'Destinations', '${widget.summary.destinationCount}'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Quality Metrics Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'QUALITY METRICS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: AppTheme.accentBlue,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildSummaryRow(
                          Icons.space_bar_rounded,
                          'Min Node Spacing',
                          widget.summary.minSpacing < double.infinity ? '${widget.summary.minSpacing.toStringAsFixed(2)} m' : 'N/A',
                        ),
                        const Divider(color: Colors.white10),
                        _buildSummaryRow(
                          Icons.straighten_rounded,
                          'Avg Node Spacing',
                          '${widget.summary.avgSpacing.toStringAsFixed(2)} m',
                        ),
                        const Divider(color: Colors.white10),
                        _buildSummaryRow(
                          Icons.link_off_rounded,
                          'Orphan Nodes',
                          '${widget.summary.orphanCount}',
                          isWarning: widget.summary.orphanCount > 0,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Action Buttons
                if (_validationResult.isValid) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryCyan,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.all(16),
                          ),
                          onPressed: _isProcessing ? null : () => _processAndSave(forceSaveDraft: false, generateQr: false),
                          icon: _isProcessing
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.save_rounded, size: 18),
                          label: const Text('SAVE ROUTE'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.all(16),
                          ),
                          onPressed: _isProcessing ? null : () => _processAndSave(forceSaveDraft: false, generateQr: true),
                          icon: const Icon(Icons.qr_code_rounded, size: 18),
                          label: const Text('GENERATE QR'),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.all(16),
                    ),
                    onPressed: _isProcessing ? null : () => _processAndSave(forceSaveDraft: true),
                    icon: const Icon(Icons.save_as_rounded),
                    label: const Text('SAVE AS DRAFT'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      side: const BorderSide(color: AppTheme.primaryCyan),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.edit_location_alt_rounded, color: AppTheme.primaryCyan),
                    label: const Text('RETURN TO REGISTRATION', style: TextStyle(color: AppTheme.primaryCyan)),
                  ),
                ],

                const SizedBox(height: 12),

                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    side: const BorderSide(color: Colors.redAccent),
                  ),
                  onPressed: () {
                    widget.engine.reset();
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  label: const Text('DISCARD', style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    final isValid = _validationResult.isValid;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isValid ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isValid ? Colors.green : Colors.redAccent,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isValid ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: isValid ? Colors.green : Colors.redAccent,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                isValid ? '✓ READY FOR NAVIGATION' : '✕ NOT READY FOR NAVIGATION',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isValid ? Colors.green : Colors.redAccent,
                ),
              ),
            ],
          ),
          if (_validationResult.errors.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Validation Errors:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 13),
            ),
            const SizedBox(height: 4),
            ..._validationResult.errors.map(
              (err) => Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: Text('• $err', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12)),
              ),
            ),
          ],
          if (_validationResult.warnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Warnings:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orangeAccent, fontSize: 13),
            ),
            const SizedBox(height: 4),
            ..._validationResult.warnings.map(
              (warn) => Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: Text('• $warn', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value, {bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: isWarning ? Colors.orangeAccent : AppTheme.primaryCyan, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 15, color: Colors.white),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isWarning ? Colors.orangeAccent : AppTheme.accentBlue,
            ),
          ),
        ],
      ),
    );
  }
}

