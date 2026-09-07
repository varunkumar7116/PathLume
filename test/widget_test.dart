import 'package:flutter_test/flutter_test.dart';
import 'package:pathlume/app/app.dart';
import 'package:pathlume/services/repositories/local_building_repository.dart';

void main() {
  testWidgets('PATHLUME HomeScreen loads cleanly with primary actions', (WidgetTester tester) async {
    await tester.pumpWidget(PathlumeApp(repository: LocalBuildingRepository()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('PATHLUME'), findsAtLeastNWidgets(1));
    expect(find.text('Indoor AR Navigation System'), findsOneWidget);
    expect(find.text('REGISTER BUILDING'), findsOneWidget);
    expect(find.text('NAVIGATE'), findsOneWidget);
    expect(find.text('REGISTERED BUILDINGS'), findsOneWidget);
  });
}
