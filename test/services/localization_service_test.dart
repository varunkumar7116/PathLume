import 'package:flutter_test/flutter_test.dart';
import 'package:pathlume/models/building.dart';
import 'package:pathlume/models/floor.dart';
import 'package:pathlume/models/floor_origin.dart';
import 'package:pathlume/models/ar_pose.dart';
import 'package:pathlume/models/localization_state.dart';
import 'package:pathlume/services/localization/localization_service.dart';
import 'package:pathlume/services/qr/simulated_qr_localization_provider.dart';
import 'package:pathlume/services/repositories/local_building_repository.dart';
import 'package:pathlume/services/simulated_ar_service.dart';

void main() {
  group('LocalizationService Integration Tests', () {
    late SimulatedARService arService;
    late SimulatedQRLocalizationProvider qrProvider;
    late LocalBuildingRepository repository;
    late LocalizationService service;

    setUp(() async {
      arService = SimulatedARService();
      qrProvider = SimulatedQRLocalizationProvider(
        targetBuildingId: 'bld_sim',
        targetFloorId: 'flr_sim',
        targetOriginId: 'orig_sim',
      );
      repository = LocalBuildingRepository();

      await repository.saveBuilding(
        const Building(buildingId: 'bld_sim', name: 'Sim Building'),
      );
      await repository.saveFloor(
        Floor(
          floorId: 'flr_sim',
          buildingId: 'bld_sim',
          floorNumber: 0,
          name: 'Ground Floor',
          origin: FloorOrigin(
            originId: 'orig_sim',
            floorId: 'flr_sim',
            position: const Vector3D(x: 0, y: 0, z: 0),
            rotation: const Quaternion4D(x: 0, y: 0, z: 0, w: 1),
            qrCodePayload: 'PATHLUME:bld_sim:flr_sim:orig_sim:1757000000000',
            createdAt: DateTime.now(),
          ),
        ),
      );

      service = LocalizationService(
        arService: arService,
        qrProvider: qrProvider,
        repository: repository,
      );
    });

    tearDown(() {
      service.dispose();
      simulatedDispose(qrProvider, arService);
    });

    test('Full simulated localization workflow (Scenario A: Perfect Match With 6DoF Pose)', () async {
      qrProvider.setScenario(SimulationScenario.perfectMatchWithPose);

      await service.startLocalizationSession(
        buildingId: 'bld_sim',
        floorId: 'flr_sim',
      );

      // Give event loop time to process QR stream and AR init
      await Future.delayed(const Duration(milliseconds: 100));

      expect(service.state, equals(LocalizationState.tracking));

      // Advance pose in simulator to trigger initial pose update
      arService.advanceSimulatedPose();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(service.confidence, equals(LocalizationConfidence.high));
      expect(service.currentSession, isNotNull);
      expect(service.currentSession!.currentFloorPosition, isNotNull);
    });

    test('Payload-only detection WITHOUT spatial pose stays in WAITING_FOR_QR_POSE (No fake localization)', () async {
      qrProvider.setScenario(SimulationScenario.payloadOnlyNoPose);

      await service.startLocalizationSession(
        buildingId: 'bld_sim',
        floorId: 'flr_sim',
      );

      await Future.delayed(const Duration(milliseconds: 100));

      // Must NOT become localized or tracking! Must remain waitingForQrPose!
      expect(service.state, equals(LocalizationState.waitingForQrPose));
      expect(service.currentSession, isNull);
    });

    test('Rejects wrong floor QR code (Scenario E: Wrong Floor)', () async {
      qrProvider.setScenario(SimulationScenario.wrongFloor);

      await service.startLocalizationSession(
        buildingId: 'bld_sim',
        floorId: 'flr_sim',
      );

      await Future.delayed(const Duration(milliseconds: 100));

      expect(service.state, equals(LocalizationState.error));
    });

    test('Relocalization resets tracking state cleanly', () async {
      qrProvider.setScenario(SimulationScenario.perfectMatchWithPose);

      await service.startLocalizationSession(
        buildingId: 'bld_sim',
        floorId: 'flr_sim',
      );
      await Future.delayed(const Duration(milliseconds: 100));
      expect(service.state, equals(LocalizationState.tracking));

      await service.requestRelocalization();
      await Future.delayed(const Duration(milliseconds: 100));
      expect(service.state, equals(LocalizationState.tracking));
    });

    test('Reset clears session and returns to idle state', () {
      service.reset();
      expect(service.state, equals(LocalizationState.idle));
      expect(service.currentSession, isNull);
    });
  });
}

void simulatedDispose(SimulatedQRLocalizationProvider qr, SimulatedARService ar) {
  qr.dispose();
  ar.dispose();
}

