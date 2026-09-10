import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../app/app_theme.dart';
import '../../../models/navigation_graph.dart';
import '../../../models/qr_payload.dart';
import '../../../navigation_core/graph_validator.dart';
import '../../../services/repositories/building_repository.dart';

class QrScannerScreen extends StatefulWidget {
  final String? buildingId;
  final String? floorId;
  final String? floorName;
  final BuildingRepository repository;

  const QrScannerScreen({
    super.key,
    this.buildingId,
    this.floorId,
    this.floorName,
    required this.repository,
  });

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    autoStart: true,
    cameraResolution: const Size(1920, 1080),
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _isProcessing = false;
  String? _statusMessage;
  String? _errorMessage;
  final GraphValidator _graphValidator = GraphValidator();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        _isProcessing = true; // Synchronous lock to eliminate camera frame blinking
        _controller.stop();
        _validateAndReturn(barcode.rawValue!);
        break;
      }
    }
  }

  Future<void> _validateAndReturn(String rawContent) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _statusMessage = '✓ QR code detected';
    });

    final payload = QRPayload.deserialize(rawContent);

    if (payload == null) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = null;
          _errorMessage = 'Invalid QR code format. Enter code like B001/F001 or full PATHLUME_V1 string.';
        });
        _controller.start();
      }
      return;
    }

    if (widget.buildingId != null && payload.buildingId != widget.buildingId) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = null;
          _errorMessage = 'QR belongs to a different building (${payload.buildingId}).';
        });
        _controller.start();
      }
      return;
    }

    if (widget.floorId != null && payload.floorId != widget.floorId) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = null;
          _errorMessage = 'QR belongs to a different floor (${payload.floorId}).';
        });
        _controller.start();
      }
      return;
    }

    if (mounted) {
      setState(() {
        _statusMessage = '☁ Fetching floor route (${payload.buildingId} / ${payload.floorId}) from cloud...';
      });
    }

    try {
      final floor = await widget.repository.getFloorByQrPayload(rawContent);

      if (floor == null) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _statusMessage = null;
            _errorMessage = 'Floor route not found in cloud.';
          });
          _controller.start();
        }
        return;
      }

      // Verify retrieved floor against QR
      if (floor.buildingId != payload.buildingId ||
          floor.floorId != payload.floorId) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _statusMessage = null;
            _errorMessage = 'QR and route data do not match.';
          });
          _controller.start();
        }
        return;
      }

      // Reconstruct and validate graph
      final graph = NavigationGraph(
        floorId: floor.floorId,
        nodes: floor.nodes,
        edges: floor.edges,
      );

      final valResult = _graphValidator.validateGraph(
        graph,
        destinations: floor.destinations,
      );

      if (!valResult.isValid) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _statusMessage = null;
            _errorMessage = 'Downloaded route data is invalid: ${valResult.errors.join("; ")}';
          });
          _controller.start();
        }
        return;
      }

      if (floor.destinations.isEmpty) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _statusMessage = null;
            _errorMessage = 'No destinations registered for this floor.';
          });
          _controller.start();
        }
        return;
      }

      if (mounted) {
        setState(() {
          _statusMessage = '✓ ${floor.name} route loaded! Select destination';
        });
      }

      await Future.delayed(const Duration(milliseconds: 50));

      if (mounted) {
        await _controller.stop();
        if (mounted) {
          Navigator.of(context).pop(payload);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = null;
          _errorMessage = 'Unable to connect to PATHLUME cloud.';
        });
        _controller.start();
      }
    }
  }

  void _showManualInputDialog() {
    final defaultBId = widget.buildingId ?? 'B001';
    final defaultFId = widget.floorId ?? 'F001';
    final textController = TextEditingController(
      text: '$defaultBId/$defaultFId',
    );

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.cardDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.vpn_key_rounded, color: AppTheme.primaryCyan),
                  SizedBox(width: 10),
                  Text('Enter Route Code Manually', style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter your building and floor unique ID (e.g. B001/F001 or PATHLUME_V1|B001|F001|O001):',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryCyan),
                        onPressed: () {
                          setDialogState(() {
                            textController.text = '$defaultBId/$defaultFId';
                          });
                        },
                        icon: const Icon(Icons.numbers_rounded, size: 14),
                        label: Text('$defaultBId/$defaultFId', style: const TextStyle(fontSize: 12)),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.white70),
                        onPressed: () {
                          setDialogState(() {
                            textController.text = 'PATHLUME_V1|$defaultBId|$defaultFId|O001';
                          });
                        },
                        icon: const Icon(Icons.qr_code_2_rounded, size: 14),
                        label: const Text('V1 QR Format', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: textController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 2,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.white30),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.primaryCyan),
                      ),
                      labelText: 'Route Code / Unique Payload',
                      labelStyle: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryCyan,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    final code = textController.text.trim();
                    if (code.isNotEmpty) {
                      Navigator.of(context).pop();
                      _validateAndReturn(code);
                    }
                  },
                  icon: const Icon(Icons.cloud_download_rounded, size: 18),
                  label: const Text('FETCH & NAVIGATE'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.floorName != null ? 'Scan Floor QR: ${widget.floorName}' : 'Scan Floor QR'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded),
            onPressed: _showManualInputDialog,
            tooltip: 'Manual QR Payload Input',
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleBarcode,
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.cardDark.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Point camera at the official Floor Origin QR code to align navigation.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                  const Spacer(),

                  if (_statusMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.green.shade900.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.greenAccent),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.greenAccent),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _statusMessage!,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_errorMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.shade900.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.white),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryCyan, foregroundColor: Colors.black),
                    onPressed: _showManualInputDialog,
                    icon: const Icon(Icons.keyboard_alt_rounded),
                    label: const Text('ENTER QR MANUALLY'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

