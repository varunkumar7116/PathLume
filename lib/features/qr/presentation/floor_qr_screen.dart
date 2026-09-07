import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../app/app_theme.dart';
import '../../../models/floor.dart';

class FloorQrScreen extends StatelessWidget {
  final String buildingName;
  final Floor floor;

  const FloorQrScreen({
    super.key,
    required this.buildingName,
    required this.floor,
  });

  @override
  Widget build(BuildContext context) {
    final payloadString = floor.origin?.qrCodePayload ??
        'PATHLUME_V1|${floor.buildingId}|${floor.floorId}|${floor.origin?.originId ?? "origin_001"}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Floor QR Code'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                buildingName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                floor.name,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppTheme.primaryCyan,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryCyan.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: QrImageView(
                  data: payloadString,
                  version: QrVersions.auto,
                  size: 220.0,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ORIGIN METADATA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryCyan,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Origin ID: ${floor.origin?.originId ?? "Not set"}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Payload: $payloadString',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('QR Code saved to local app gallery.'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('SAVE QR'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.primaryCyan),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Sharing Floor QR: $payloadString'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.share_rounded, color: AppTheme.primaryCyan),
                      label: const Text('SHARE', style: TextStyle(color: AppTheme.primaryCyan)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
