import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathlume/models/building.dart';
import 'package:pathlume/models/destination.dart';
import 'package:pathlume/models/floor.dart';
import 'package:pathlume/models/floor_origin.dart';
import 'package:pathlume/models/navigation_edge.dart';
import 'package:pathlume/models/navigation_node.dart';
import 'package:pathlume/models/ar_pose.dart';
import 'package:pathlume/features/navigation/presentation/destination_selection_screen.dart';
import 'package:pathlume/services/repositories/local_building_repository.dart';

void main() {
  late Directory tempDir;
  late LocalBuildingRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pathlume_dest_test');
    repository = LocalBuildingRepository(overrideDirectory: tempDir);

    await repository.saveBuilding(const Building(buildingId: 'bld_ui', name: 'Science Complex'));

    const nodeStart = NavigationNode(nodeId: 'n0', floorId: 'flr_ui', type: NodeType.start, position: Vector3D(x: 0, y: 0, z: 0), name: 'Start');
    const nodeRoom = NavigationNode(nodeId: 'n1', floorId: 'flr_ui', type: NodeType.destination, position: Vector3D(x: 5, y: 0, z: 0), name: 'Room 101');
    const nodeLab = NavigationNode(nodeId: 'n2', floorId: 'flr_ui', type: NodeType.destination, position: Vector3D(x: 10, y: 0, z: 0), name: 'AI Lab');

    const destRoom = Destination(destinationId: 'd1', nodeId: 'n1', name: 'Room 101', category: 'Room');
    const destLab = Destination(destinationId: 'd2', nodeId: 'n2', name: 'AI Lab', category: 'Lab');

    await repository.saveFloor(
      Floor(
        floorId: 'flr_ui',
        buildingId: 'bld_ui',
        floorNumber: 1,
        name: 'Ground Floor',
        origin: FloorOrigin(
          originId: 'orig_ui',
          floorId: 'flr_ui',
          position: const Vector3D(x: 0, y: 0, z: 0),
          rotation: const Quaternion4D(x: 0, y: 0, z: 0, w: 1),
          qrCodePayload: 'PATHLUME:bld_ui:flr_ui:orig_ui:1757000000000',
          createdAt: DateTime.now(),
        ),
        nodes: const [nodeStart, nodeRoom, nodeLab],
        edges: const [
          NavigationEdge(edgeId: 'e1', fromNodeId: 'n0', toNodeId: 'n1', distance: 5.0),
          NavigationEdge(edgeId: 'e2', fromNodeId: 'n1', toNodeId: 'n2', distance: 5.0),
        ],
        destinations: const [destRoom, destLab],
      ),
    );

    // Empty floor for testing empty state
    await repository.saveFloor(
      const Floor(
        floorId: 'flr_empty',
        buildingId: 'bld_ui',
        floorNumber: 2,
        name: 'Second Floor',
        nodes: [],
        edges: [],
        destinations: [],
      ),
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Widget buildWidget(String floorId, String floorName) {
    return MaterialApp(
      home: DestinationSelectionScreen(
        buildingId: 'bld_ui',
        floorId: floorId,
        buildingName: 'Science Complex',
        floorName: floorName,
        repository: repository,
      ),
    );
  }

  testWidgets('DestinationSelectionScreen loads registered destinations', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(buildWidget('flr_ui', 'Ground Floor'));
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(find.text('Science Complex'), findsOneWidget);
    expect(find.text('Ground Floor'), findsOneWidget);
    expect(find.text('Room 101'), findsOneWidget);
    expect(find.text('AI Lab'), findsOneWidget);
  });

  testWidgets('Filtering destinations by search query works', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(buildWidget('flr_ui', 'Ground Floor'));
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'AI');
    await tester.pump();

    expect(find.text('AI Lab'), findsOneWidget);
    expect(find.text('Room 101'), findsNothing);
  });

  testWidgets('Tapping destination opens READY TO NAVIGATE modal', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(buildWidget('flr_ui', 'Ground Floor'));
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    await tester.tap(find.text('Room 101'));
    await tester.pump();

    expect(find.text('READY TO NAVIGATE'), findsOneWidget);
    expect(find.text('START NAVIGATION'), findsWidgets);
  });

  testWidgets('Empty floor displays empty state card', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(buildWidget('flr_empty', 'Second Floor'));
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(find.text('No Destinations Registered'), findsOneWidget);
    expect(find.text('GO BACK TO FLOOR DETAILS'), findsOneWidget);
  });
}
