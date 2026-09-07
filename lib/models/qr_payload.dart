class QRPayload {
  final String buildingId;
  final String floorId;
  final String originId;
  final int timestamp;

  const QRPayload({
    required this.buildingId,
    required this.floorId,
    required this.originId,
    required this.timestamp,
  });

  String serialize() => 'PATHLUME_V1|$buildingId|$floorId|$originId';

  String serializeLegacy() => 'PATHLUME:$buildingId:$floorId:$originId:$timestamp';

  static QRPayload? deserialize(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('PATHLUME_V1|')) {
      final parts = trimmed.split('|');
      if (parts.length < 4) return null;
      return QRPayload(
        buildingId: parts[1],
        floorId: parts[2],
        originId: parts[3],
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
    }

    if (trimmed.startsWith('PATHLUME:')) {
      final parts = trimmed.split(':');
      if (parts.length < 4) return null;
      return QRPayload(
        buildingId: parts[1],
        floorId: parts[2],
        originId: parts[3],
        timestamp: parts.length >= 5 ? int.tryParse(parts[4]) ?? 0 : 0,
      );
    }

    if (trimmed.startsWith('pathlume://')) {
      try {
        final uri = Uri.parse(trimmed);
        final pathSegments = uri.pathSegments;
        String? buildingId;
        String? floorId;
        String? originId;
        int timestamp = 0;

        final host = uri.host.toLowerCase();
        if (host.isNotEmpty && host != 'site' && host != 'building') {
          buildingId = uri.host;
        }

        if ((host == 'site' || host == 'building') && pathSegments.isNotEmpty) {
          buildingId = pathSegments[0];
        }

        for (int i = 0; i < pathSegments.length; i++) {
          final seg = pathSegments[i].toLowerCase();
          if ((seg == 'site' || seg == 'building') && i + 1 < pathSegments.length) {
            buildingId = pathSegments[i + 1];
          } else if (seg == 'floor' && i + 1 < pathSegments.length) {
            floorId = pathSegments[i + 1];
          } else if ((seg == 'qr' || seg == 'origin') && i + 1 < pathSegments.length) {
            originId = pathSegments[i + 1];
          }
        }

        if (buildingId != null && floorId != null && originId != null) {
          return QRPayload(
            buildingId: buildingId,
            floorId: floorId,
            originId: originId,
            timestamp: timestamp,
          );
        }
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  Map<String, dynamic> toJson() => {
        'buildingId': buildingId,
        'floorId': floorId,
        'originId': originId,
        'timestamp': timestamp,
      };

  factory QRPayload.fromJson(Map<String, dynamic> json) {
    return QRPayload(
      buildingId: json['buildingId'] as String,
      floorId: json['floorId'] as String,
      originId: json['originId'] as String,
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
    );
  }
}
