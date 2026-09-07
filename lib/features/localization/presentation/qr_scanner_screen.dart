import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../app/app_theme.dart';
import '../../../models/qr_payload.dart';
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
  String? _errorMessage;

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
        _validateAndReturn(barcode.rawValue!);
        break;
      }
    }
  }

  Future<void> _validateAndReturn(String rawContent) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final payload = QRPayload.deserialize(rawContent);

    if (payload == null) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Invalid PATHLUME QR format.';
        });
      }
      return;
    }

    if (widget.buildingId != null && payload.buildingId != widget.buildingId) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'This QR belongs to another building (${payload.buildingId}).';
        });
      }
      return;
    }

    if (widget.floorId != null && payload.floorId != widget.floorId) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'This QR belongs to another floor (${payload.floorId}).';
        });
      }
      return;
    }

    final floor = await widget.repository.getFloorById(payload.buildingId, payload.floorId);
    if (floor == null) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'This floor is not registered on this device.';
        });
      }
      return;
    }

    if (mounted) {
      Navigator.of(context).pop(payload);
    }
  }

  void _showManualInputDialog() {
    final textController = TextEditingController(
      text: 'PATHLUME:${widget.buildingId ?? "building_demo"}:${widget.floorId ?? "floor_demo"}:origin_001:${DateTime.now().millisecondsSinceEpoch}',
    );

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Manual QR Payload Entry'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Enter or choose PATHLUME QR format for developer testing:'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setDialogState(() {
                              textController.text = 'PATHLUME:${widget.buildingId}:${widget.floorId}:origin_001:${DateTime.now().millisecondsSinceEpoch}';
                            });
                          },
                          child: const Text('Colon Format', style: TextStyle(fontSize: 11)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setDialogState(() {
                              textController.text = 'pathlume://site/${widget.buildingId}/floor/${widget.floorId}/qr/origin_001';
                            });
                          },
                          child: const Text('URI Format', style: TextStyle(fontSize: 11)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: textController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'QR Payload String',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _validateAndReturn(textController.text.trim());
                  },
                  child: const Text('SUBMIT QR'),
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
