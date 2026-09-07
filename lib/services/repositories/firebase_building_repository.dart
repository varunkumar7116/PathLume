import 'dart:async';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/building.dart';
import '../../models/destination.dart';
import '../../models/floor.dart';
import '../../models/navigation_graph.dart';
import '../../navigation_core/graph_validator.dart';
import 'building_repository.dart';
import 'local_building_repository.dart';

class FirebaseBuildingRepository implements BuildingRepository {
  final FirebaseFirestore? _explicitFirestore;
  final LocalBuildingRepository _localFallback;
  final GraphValidator _validator = GraphValidator();

  FirebaseBuildingRepository({
    FirebaseFirestore? firestore,
    LocalBuildingRepository? localFallback,
  })  : _explicitFirestore = firestore,
        _localFallback = localFallback ?? LocalBuildingRepository();

  FirebaseFirestore? get _firestore {
    if (_explicitFirestore != null) return _explicitFirestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  CollectionReference<Map<String, dynamic>>? get _buildingsRef {
    final fs = _firestore;
    return fs?.collection('buildings');
  }

  CollectionReference<Map<String, dynamic>>? _floorsRef(String buildingId) =>
      _buildingsRef?.doc(buildingId).collection('floors');

  @override
  Future<List<Building>> getAllBuildings() async {
    try {
      developer.log('PATHLUME_DATA FETCH_ALL_BUILDINGS_START');
      final ref = _buildingsRef;
      if (ref == null) throw Exception('Firebase uninitialized');
      final snapshot = await ref.get().timeout(const Duration(seconds: 5));
      final List<Building> list = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final buildingId = doc.id;
        final floors = await getFloorsForBuilding(buildingId);
        list.add(Building(
          buildingId: buildingId,
          name: (data['name'] as String?) ?? 'Building $buildingId',
          address: data['address'] as String?,
          floors: floors,
        ));
      }

      developer.log('PATHLUME_DATA FETCH_ALL_BUILDINGS_SUCCESS count=${list.length}');
      // Sync local fallback
      for (final b in list) {
        await _localFallback.saveBuilding(b);
      }
      return list;
    } catch (e) {
      developer.log('PATHLUME_DATA FETCH_ALL_BUILDINGS_FALLBACK error=$e');
      return _localFallback.getAllBuildings();
    }
  }

  @override
  Future<Building?> getBuildingById(String buildingId) async {
    try {
      developer.log('PATHLUME_DATA FETCH_BUILDING_START buildingId=$buildingId');
      final ref = _buildingsRef;
      if (ref == null) throw Exception('Firebase uninitialized');
      final doc = await ref.doc(buildingId).get().timeout(const Duration(seconds: 5));
      if (!doc.exists || doc.data() == null) {
        return await _localFallback.getBuildingById(buildingId);
      }
      final data = doc.data()!;
      final floors = await getFloorsForBuilding(buildingId);
      final building = Building(
        buildingId: buildingId,
        name: (data['name'] as String?) ?? 'Building $buildingId',
        address: data['address'] as String?,
        floors: floors,
      );
      await _localFallback.saveBuilding(building);
      return building;
    } catch (e) {
      developer.log('PATHLUME_DATA FETCH_BUILDING_FALLBACK buildingId=$buildingId error=$e');
      return await _localFallback.getBuildingById(buildingId);
    }
  }

  @override
  Future<void> saveBuilding(Building building) async {
    // Save to local cache first
    await _localFallback.saveBuilding(building);

    try {
      developer.log('PATHLUME_DATA SAVE_BUILDING_START buildingId=${building.buildingId}');
      final ref = _buildingsRef;
      if (ref == null) throw Exception('Firebase uninitialized');
      await ref.doc(building.buildingId).set({
        'buildingId': building.buildingId,
        'name': building.name,
        'address': building.address,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 5));

      for (final floor in building.floors) {
        await saveFloor(floor);
      }

      developer.log('PATHLUME_DATA SAVE_BUILDING_SUCCESS buildingId=${building.buildingId}');
    } catch (e) {
      developer.log('PATHLUME_DATA SAVE_BUILDING_FIRESTORE_ERROR buildingId=${building.buildingId} error=$e');
      // Local fallback already saved
    }
  }

  @override
  Future<void> deleteBuilding(String buildingId) async {
    await _localFallback.deleteBuilding(buildingId);
    try {
      developer.log('PATHLUME_DATA DELETE_BUILDING_START buildingId=$buildingId');
      final ref = _buildingsRef;
      final fRef = _floorsRef(buildingId);
      if (ref == null || fRef == null) throw Exception('Firebase uninitialized');
      final floorsSnap = await fRef.get();
      for (final doc in floorsSnap.docs) {
        await doc.reference.delete();
      }
      await ref.doc(buildingId).delete();
      developer.log('PATHLUME_DATA DELETE_BUILDING_SUCCESS buildingId=$buildingId');
    } catch (e) {
      developer.log('PATHLUME_DATA DELETE_BUILDING_ERROR buildingId=$buildingId error=$e');
    }
  }

  @override
  Future<List<Floor>> getFloorsForBuilding(String buildingId) async {
    try {
      developer.log('PATHLUME_DATA FETCH_FLOORS_START buildingId=$buildingId');
      final fRef = _floorsRef(buildingId);
      if (fRef == null) throw Exception('Firebase uninitialized');
      final snapshot = await fRef.get().timeout(const Duration(seconds: 5));
      final List<Floor> floors = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final floor = Floor.fromJson(data);
        floors.add(floor);
      }

      floors.sort((a, b) => a.floorNumber.compareTo(b.floorNumber));
      developer.log('PATHLUME_DATA FETCH_FLOORS_SUCCESS count=${floors.length}');

      for (final f in floors) {
        await _localFallback.saveFloor(f);
      }
      return floors;
    } catch (e) {
      developer.log('PATHLUME_DATA FETCH_FLOORS_FALLBACK buildingId=$buildingId error=$e');
      return _localFallback.getFloorsForBuilding(buildingId);
    }
  }

  @override
  Future<Floor?> getFloorById(String buildingId, String floorId) async {
    try {
      developer.log('PATHLUME_DATA FETCH_FLOOR_START buildingId=$buildingId floorId=$floorId');
      final fRef = _floorsRef(buildingId);
      if (fRef == null) throw Exception('Firebase uninitialized');
      final doc = await fRef.doc(floorId).get().timeout(const Duration(seconds: 5));
      if (!doc.exists || doc.data() == null) {
        return await _localFallback.getFloorById(buildingId, floorId);
      }
      final floor = Floor.fromJson(doc.data()!);
      await _localFallback.saveFloor(floor);
      return floor;
    } catch (e) {
      developer.log('PATHLUME_DATA FETCH_FLOOR_FALLBACK buildingId=$buildingId floorId=$floorId error=$e');
      return await _localFallback.getFloorById(buildingId, floorId);
    }
  }

  @override
  Future<void> saveFloor(Floor floor) async {
    // 1. Validate graph first
    final graph = NavigationGraph(
      floorId: floor.floorId,
      nodes: floor.nodes,
      edges: floor.edges,
    );
    final valResult = _validator.validateGraph(graph, destinations: floor.destinations);

    final targetStatus = valResult.isValid ? 'ready' : floor.registrationStatus;
    final updatedFloor = Floor(
      floorId: floor.floorId,
      buildingId: floor.buildingId,
      floorNumber: floor.floorNumber,
      name: floor.name,
      origin: floor.origin,
      nodes: floor.nodes,
      edges: floor.edges,
      destinations: floor.destinations,
      version: floor.version,
      registrationStatus: targetStatus,
      createdAt: floor.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      coordinateMetadata: floor.coordinateMetadata,
    );

    // Save to local fallback first
    await _localFallback.saveFloor(updatedFloor);

    try {
      developer.log('PATHLUME_DATA SAVE_FLOOR_START floorId=${floor.floorId} status=$targetStatus nodes=${floor.nodes.length} edges=${floor.edges.length}');
      final fRef = _floorsRef(floor.buildingId);
      if (fRef == null) throw Exception('Firebase uninitialized');

      final jsonMap = updatedFloor.toJson();
      jsonMap['updatedAt'] = FieldValue.serverTimestamp();
      if (floor.createdAt == null) {
        jsonMap['createdAt'] = FieldValue.serverTimestamp();
      }

      await fRef
          .doc(floor.floorId)
          .set(jsonMap, SetOptions(merge: true))
          .timeout(const Duration(seconds: 5));

      developer.log('PATHLUME_DATA SAVE_FLOOR_SUCCESS floorId=${floor.floorId} status=$targetStatus');
    } catch (e) {
      developer.log('PATHLUME_DATA SAVE_FLOOR_FIRESTORE_ERROR floorId=${floor.floorId} error=$e');
      // Local fallback preserved
    }
  }

  @override
  Future<void> deleteFloor(String buildingId, String floorId) async {
    await _localFallback.deleteFloor(buildingId, floorId);
    try {
      developer.log('PATHLUME_DATA DELETE_FLOOR_START buildingId=$buildingId floorId=$floorId');
      final fRef = _floorsRef(buildingId);
      if (fRef == null) throw Exception('Firebase uninitialized');
      await fRef.doc(floorId).delete();
      developer.log('PATHLUME_DATA DELETE_FLOOR_SUCCESS buildingId=$buildingId floorId=$floorId');
    } catch (e) {
      developer.log('PATHLUME_DATA DELETE_FLOOR_ERROR buildingId=$buildingId floorId=$floorId error=$e');
    }
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
