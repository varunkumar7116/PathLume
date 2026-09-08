import 'dart:async';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/building.dart';
import '../../models/destination.dart';
import '../../models/floor.dart';
import '../../models/navigation_graph.dart';
import '../../models/qr_payload.dart';
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
  Future<Floor?> getFloorByQrPayload(String payload) async {
    developer.log('[PATHLUME_FIRESTORE] QR_RETRIEVAL_STARTED');
    developer.log('[PATHLUME_FIRESTORE] QR_PAYLOAD=$payload');

    final qrPayload = QRPayload.deserialize(payload);
    if (qrPayload == null) {
      developer.log('[PATHLUME_FIRESTORE] QR_DESERIALIZATION_FAILED');
      return null;
    }

    final docPath = 'buildings/${qrPayload.buildingId}/floors/${qrPayload.floorId}';
    developer.log('[PATHLUME_FIRESTORE] DOCUMENT_PATH=$docPath');

    // Fast Path 1: Check local cache first for sub-millisecond instant retrieval
    final localFloor = await _localFallback.getFloorByQrPayload(payload);
    if (localFloor != null) {
      developer.log('[PATHLUME_FIRESTORE] FAST_LOCAL_CACHE_HIT floorId=${localFloor.floorId}');
      developer.log('[PATHLUME_FIRESTORE] BUILDING_ID=${localFloor.buildingId}');
      developer.log('[PATHLUME_FIRESTORE] FLOOR_ID=${localFloor.floorId}');
      developer.log('[PATHLUME_FIRESTORE] NODE_COUNT=${localFloor.nodes.length}');
      developer.log('[PATHLUME_FIRESTORE] EDGE_COUNT=${localFloor.edges.length}');
      developer.log('[PATHLUME_FIRESTORE] DESTINATION_COUNT=${localFloor.destinations.length}');
      developer.log('[PATHLUME_FIRESTORE] QR_RETRIEVAL_SUCCESS');
      developer.log('[PATHLUME_FIRESTORE] GRAPH_DESERIALIZATION_SUCCESS');
      developer.log('[PATHLUME_FIRESTORE] DESTINATIONS_LOADED');
      return localFloor;
    }

    // Fast Path 2: Fetch from Firestore (try SDK cache first, then cloud server)
    try {
      final fRef = _floorsRef(qrPayload.buildingId);
      if (fRef == null) throw Exception('Firebase uninitialized');

      DocumentSnapshot<Map<String, dynamic>>? doc;

      // Try local Firestore SDK cache
      try {
        final cacheDoc = await fRef.doc(qrPayload.floorId).get(const GetOptions(source: Source.cache));
        if (cacheDoc.exists && cacheDoc.data() != null) {
          doc = cacheDoc;
          developer.log('[PATHLUME_FIRESTORE] FIRESTORE_SDK_CACHE_HIT');
        }
      } catch (_) {}

      // If not in cache, fetch from Firestore cloud server
      if (doc == null || !doc.exists) {
        doc = await fRef.doc(qrPayload.floorId).get(const GetOptions(source: Source.server)).timeout(const Duration(seconds: 3, milliseconds: 500));
      }

      if (!doc.exists || doc.data() == null) {
        developer.log('[PATHLUME_FIRESTORE] QR_RETRIEVAL_FAILED: Document not found in cloud');
        return null;
      }

      final data = doc.data()!;
      final floor = Floor.fromJson(data);

      developer.log('[PATHLUME_FIRESTORE] QR_RETRIEVAL_SUCCESS');
      developer.log('[PATHLUME_FIRESTORE] BUILDING_ID=${floor.buildingId}');
      developer.log('[PATHLUME_FIRESTORE] FLOOR_ID=${floor.floorId}');
      developer.log('[PATHLUME_FIRESTORE] NODE_COUNT=${floor.nodes.length}');
      developer.log('[PATHLUME_FIRESTORE] EDGE_COUNT=${floor.edges.length}');
      developer.log('[PATHLUME_FIRESTORE] DESTINATION_COUNT=${floor.destinations.length}');
      developer.log('[PATHLUME_FIRESTORE] GRAPH_DESERIALIZATION_SUCCESS');
      developer.log('[PATHLUME_FIRESTORE] DESTINATIONS_LOADED');

      await _localFallback.saveFloor(floor);
      return floor;
    } catch (e) {
      developer.log('[PATHLUME_FIRESTORE] QR_RETRIEVAL_ERROR error=$e');
      return await _localFallback.getFloorByQrPayload(payload);
    }
  }


  @override
  Future<void> saveFloor(Floor floor, {bool rethrowCloudErrors = false}) async {
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
      developer.log('[PATHLUME_FIRESTORE] SAVE_ROUTE_STARTED');
      developer.log('[PATHLUME_FIRESTORE] BUILDING_ID=${floor.buildingId}');
      developer.log('[PATHLUME_FIRESTORE] FLOOR_ID=${floor.floorId}');
      developer.log('[PATHLUME_FIRESTORE] QR_PAYLOAD=${updatedFloor.qrPayload}');
      developer.log('[PATHLUME_FIRESTORE] NODE_COUNT=${floor.nodes.length}');
      developer.log('[PATHLUME_FIRESTORE] EDGE_COUNT=${floor.edges.length}');
      developer.log('[PATHLUME_FIRESTORE] DESTINATION_COUNT=${floor.destinations.length}');
      developer.log('[PATHLUME_FIRESTORE] DOCUMENT_PATH=buildings/${floor.buildingId}/floors/${floor.floorId}');
      developer.log('[PATHLUME_FIRESTORE] WRITE_STARTED');

      final bRef = _buildingsRef;
      final fRef = _floorsRef(floor.buildingId);
      if (bRef == null || fRef == null) throw Exception('Firebase uninitialized');

      // 1. Create / update parent building document first
      final existingBuilding = await _localFallback.getBuildingById(floor.buildingId);
      final buildingName = existingBuilding?.name ?? 'Building ${floor.buildingId}';

      await bRef.doc(floor.buildingId).set({
        'buildingId': floor.buildingId,
        'name': buildingName,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 5));

      developer.log('[PATHLUME_FIRESTORE] PARENT_BUILDING_WRITE_SUCCESS: buildings/${floor.buildingId}');

      // 2. Create / update floor document
      final jsonMap = updatedFloor.toJson();
      jsonMap['updatedAt'] = FieldValue.serverTimestamp();
      if (floor.createdAt == null) {
        jsonMap['createdAt'] = FieldValue.serverTimestamp();
      }

      await fRef
          .doc(floor.floorId)
          .set(jsonMap, SetOptions(merge: true))
          .timeout(const Duration(seconds: 5));

      developer.log('[PATHLUME_FIRESTORE] WRITE_SUCCESS');
    } catch (e, stack) {
      developer.log('[PATHLUME_FIRESTORE] WRITE_FAILED: $e');
      developer.log('[PATHLUME_FIRESTORE] STACK: $stack');
      if (rethrowCloudErrors) {
        rethrow;
      }
    }

  }

  Future<void> testFirestoreConnection() async {
    final db = _firestore;
    if (db == null) {
      developer.log('[PATHLUME_FIRESTORE] TEST_WRITE_FAILED: Firebase uninitialized');
      return;
    }
    try {
      developer.log('[PATHLUME_FIRESTORE] TEST_WRITE_STARTED');
      await db.collection('_pathlume_test').doc('connection').set({
        'message': 'PATHLUME Firestore connection successful',
        'timestamp': FieldValue.serverTimestamp(),
      });
      developer.log('[PATHLUME_FIRESTORE] TEST_WRITE_SUCCESS');
    } catch (e, stack) {
      developer.log('[PATHLUME_FIRESTORE] TEST_WRITE_FAILED: $e');
      developer.log('[PATHLUME_FIRESTORE] STACK: $stack');
      rethrow;
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
