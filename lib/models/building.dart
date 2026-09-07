import 'floor.dart';

class Building {
  final String buildingId;
  final String name;
  final String? address;
  final List<Floor> floors;

  const Building({
    required this.buildingId,
    required this.name,
    this.address,
    this.floors = const [],
  });

  Map<String, dynamic> toJson() => {
        'buildingId': buildingId,
        'name': name,
        'address': address,
        'floors': floors.map((f) => f.toJson()).toList(),
      };

  factory Building.fromJson(Map<String, dynamic> json) {
    return Building(
      buildingId: json['buildingId'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      floors: (json['floors'] as List<dynamic>?)
              ?.map((f) => Floor.fromJson(f as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
