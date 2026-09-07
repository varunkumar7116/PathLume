import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../models/building.dart';
import '../../models/destination.dart';
import '../../models/floor.dart';
import '../../models/navigation_graph.dart';
import 'building_repository.dart';

class LocalBuildingRepository implements BuildingRepository {
  final Directory? _overrideDirectory;
  final Map<String, Building> _memoryBuildings = {};
  final Map<String, Map<String, Floor>> _memoryFloors = {};

  LocalBuildingRepository({Directory? overrideDirectory})
      : _overrideDirectory = overrideDirectory;

  Future<Directory> _getBuildingsDir() async {
    if (_overrideDirectory != null) {
      final dir = Directory('${_overrideDirectory!.path}/local_data/buildings');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${appDocDir.path}/local_data/buildings');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    } catch (_) {
      final tempDir = Directory.systemTemp;
      final dir = Directory('${tempDir.path}/pathlume_data/buildings');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
  }

  @override
  Future<List<Building>> getAllBuildings() async {
    final List<Building> list = [];
    try {
      final baseDir = await _getBuildingsDir();
      if (await baseDir.exists()) {
        final bDirs = baseDir.listSync().whereType<Directory>();
        for (final bDir in bDirs) {
          final bFile = File('${bDir.path}/building.json');
          if (await bFile.exists()) {
            final content = await bFile.readAsString();
            final jsonMap = jsonDecode(content) as Map<String, dynamic>;
            final building = Building.fromJson(jsonMap);
            final floors = await getFloorsForBuilding(building.buildingId);
            list.add(Building(
              buildingId: building.buildingId,
              name: building.name,
              address: building.address,
              floors: floors,
            ));
          }
        }
      }
    } catch (_) {}

    // Combine/fallback with memory buildings if empty
    for (final b in _memoryBuildings.values) {
      if (!list.any((item) => item.buildingId == b.buildingId)) {
        final floors = _memoryFloors[b.buildingId]?.values.toList() ?? [];
        list.add(Building(
          buildingId: b.buildingId,
          name: b.name,
          address: b.address,
          floors: floors,
        ));
      }
    }

    return list;
  }

  @override
  Future<Building?> getBuildingById(String buildingId) async {
    final all = await getAllBuildings();
    try {
      return all.firstWhere((b) => b.buildingId == buildingId);
    } catch (_) {
      return _memoryBuildings[buildingId];
    }
  }

  @override
  Future<void> saveBuilding(Building building) async {
    _memoryBuildings[building.buildingId] = building;
    try {
      final baseDir = await _getBuildingsDir();
      final bDir = Directory('${baseDir.path}/${building.buildingId}');
      if (!await bDir.exists()) {
        await bDir.create(recursive: true);
      }
      final bFile = File('${bDir.path}/building.json');
      await bFile.writeAsString(jsonEncode(building.toJson()));

      for (final floor in building.floors) {
        await saveFloor(floor);
      }
    } catch (_) {}
  }

  @override
  Future<void> deleteBuilding(String buildingId) async {
    _memoryBuildings.remove(buildingId);
    _memoryFloors.remove(buildingId);
    try {
      final baseDir = await _getBuildingsDir();
      final bDir = Directory('${baseDir.path}/$buildingId');
      if (await bDir.exists()) {
        await bDir.delete(recursive: true);
      }
    } catch (_) {}
  }

  @override
  Future<List<Floor>> getFloorsForBuilding(String buildingId) async {
    final List<Floor> floors = [];
    try {
      final baseDir = await _getBuildingsDir();
      final fDir = Directory('${baseDir.path}/$buildingId/floors');
      if (await fDir.exists()) {
        final files = fDir.listSync().whereType<File>();
        for (final f in files) {
          if (f.path.endsWith('.json')) {
            final content = await f.readAsString();
            final jsonMap = jsonDecode(content) as Map<String, dynamic>;
            floors.add(Floor.fromJson(jsonMap));
          }
        }
      }
    } catch (_) {}

    final memFloors = _memoryFloors[buildingId]?.values ?? [];
    for (final mf in memFloors) {
      if (!floors.any((f) => f.floorId == mf.floorId)) {
        floors.add(mf);
      }
    }

    floors.sort((a, b) => a.floorNumber.compareTo(b.floorNumber));
    return floors;
  }

  @override
  Future<Floor?> getFloorById(String buildingId, String floorId) async {
    final floors = await getFloorsForBuilding(buildingId);
    try {
      return floors.firstWhere((f) => f.floorId == floorId);
    } catch (_) {
      return _memoryFloors[buildingId]?[floorId];
    }
  }

  @override
  Future<void> saveFloor(Floor floor) async {
    _memoryFloors.putIfAbsent(floor.buildingId, () => {})[floor.floorId] = floor;
    try {
      final baseDir = await _getBuildingsDir();
      final fDir = Directory('${baseDir.path}/${floor.buildingId}/floors');
      if (!await fDir.exists()) {
        await fDir.create(recursive: true);
      }
      final fFile = File('${fDir.path}/${floor.floorId}.json');
      await fFile.writeAsString(jsonEncode(floor.toJson()));
    } catch (_) {}
  }

  @override
  Future<void> deleteFloor(String buildingId, String floorId) async {
    _memoryFloors[buildingId]?.remove(floorId);
    try {
      final baseDir = await _getBuildingsDir();
      final fFile = File('${baseDir.path}/$buildingId/floors/$floorId.json');
      if (await fFile.exists()) {
        await fFile.delete();
      }
    } catch (_) {}
  }

  @override
  Future<NavigationGraph?> getGraphByFloorId(String buildingId, String floorId) async {
    final floor = await getFloorById(buildingId, floorId);
    if (floor == null) return null;
    return NavigationGraph(
      floorId: floor.floorId,
      nodes: floor.nodes,
      edges: floor.edges,
    );
  }

  @override
  Future<List<Destination>> getDestinations(String buildingId, String floorId) async {
    final floor = await getFloorById(buildingId, floorId);
    return floor?.destinations ?? [];
  }

  @override
  Future<Destination?> getDestinationById(String buildingId, String floorId, String destinationId) async {
    final dests = await getDestinations(buildingId, floorId);
    try {
      return dests.firstWhere((d) => d.destinationId == destinationId);
    } catch (_) {
      return null;
    }
  }
}
