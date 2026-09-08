import '../../models/building.dart';
import '../../models/destination.dart';
import '../../models/floor.dart';
import '../../models/navigation_graph.dart';

abstract class BuildingRepository {
  Future<List<Building>> getAllBuildings();
  Future<Building?> getBuildingById(String buildingId);
  Future<void> saveBuilding(Building building);
  Future<void> deleteBuilding(String buildingId);

  Future<List<Floor>> getFloorsForBuilding(String buildingId);
  Future<Floor?> getFloorById(String buildingId, String floorId);
  Future<Floor?> getFloorByQrPayload(String payload);
  Future<void> saveFloor(Floor floor);
  Future<void> deleteFloor(String buildingId, String floorId);


  Future<NavigationGraph?> getGraphByFloorId(String buildingId, String floorId);
  Future<List<Destination>> getDestinations(String buildingId, String floorId);
  Future<Destination?> getDestinationById(String buildingId, String floorId, String destinationId);
}
