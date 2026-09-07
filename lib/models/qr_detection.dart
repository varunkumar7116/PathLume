import 'ar_pose.dart';
import 'qr_payload.dart';

enum QRPoseSource {
  none,
  nativeArCore,
  simulated,
}

class QRDetection {
  final QRPayload? payload;
  final String rawContent;
  final List<Vector3D> imageCorners;
  final double? physicalSizeMeters;
  final double? physicalWidthMeters;
  final double? physicalHeightMeters;
  final ARPose? pose;
  final bool poseAvailable;
  final QRPoseSource poseSource;
  final int timestamp;
  final bool isValidPayload;

  const QRDetection({
    this.payload,
    required this.rawContent,
    this.imageCorners = const [],
    this.physicalSizeMeters,
    this.physicalWidthMeters,
    this.physicalHeightMeters,
    this.pose,
    this.poseAvailable = false,
    this.poseSource = QRPoseSource.none,
    required this.timestamp,
    required this.isValidPayload,
  });

  double get effectiveWidthMeters => physicalWidthMeters ?? physicalSizeMeters ?? 0.20;
  double get effectiveHeightMeters => physicalHeightMeters ?? physicalSizeMeters ?? 0.20;

  Map<String, dynamic> toJson() => {
        'payload': payload?.toJson(),
        'rawContent': rawContent,
        'imageCorners': imageCorners.map((c) => c.toJson()).toList(),
        'physicalSizeMeters': physicalSizeMeters,
        'physicalWidthMeters': effectiveWidthMeters,
        'physicalHeightMeters': effectiveHeightMeters,
        'pose': pose?.toJson(),
        'poseAvailable': poseAvailable,
        'poseSource': poseSource.name,
        'timestamp': timestamp,
        'isValidPayload': isValidPayload,
      };

  factory QRDetection.fromJson(Map<String, dynamic> json) {
    final sourceName = json['poseSource'] as String? ?? 'none';
    final source = QRPoseSource.values.firstWhere(
      (e) => e.name == sourceName,
      orElse: () => QRPoseSource.none,
    );

    final size = (json['physicalSizeMeters'] as num?)?.toDouble();
    return QRDetection(
      payload: json['payload'] != null
          ? QRPayload.fromJson(json['payload'] as Map<String, dynamic>)
          : null,
      rawContent: json['rawContent'] as String? ?? '',
      imageCorners: (json['imageCorners'] as List<dynamic>?)
              ?.map((c) => Vector3D.fromJson(c as Map<String, dynamic>?))
              .toList() ??
          const [],
      physicalSizeMeters: size,
      physicalWidthMeters: (json['physicalWidthMeters'] as num?)?.toDouble() ?? size,
      physicalHeightMeters: (json['physicalHeightMeters'] as num?)?.toDouble() ?? size,
      pose: json['pose'] != null
          ? ARPose.fromJson(json['pose'] as Map<String, dynamic>)
          : null,
      poseAvailable: json['poseAvailable'] as bool? ?? false,
      poseSource: source,
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
      isValidPayload: json['isValidPayload'] as bool? ?? false,
    );
  }
}

