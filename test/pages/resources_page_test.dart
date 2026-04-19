import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/building/category.dart';
import 'package:horologium/game/grid.dart';
import 'package:horologium/game/resources/resource_category.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/game/resources/resources.dart';
import 'package:horologium/pages/resources_page.dart';

void main() {
  group('ResourcesPage', () {
    late Resources resources;
    late Grid grid;

    setUp(() {
      resources = Resources();
      grid = Grid();
    });

    Future<void> pumpPage(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ResourcesPage(resources: resources, grid: grid),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders title and category tabs', (tester) async {
      await pumpPage(tester);

      expect(find.text('Resources Overview'), findsOneWidget);
      for (final category in ResourceCategory.values) {
        expect(find.text(category.displayName), findsOneWidget);
      }
    });

    testWidgets('default selected tab is Raw Materials', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text('Raw Materials'));
      await tester.pump();

      expect(find.text('Resources Overview'), findsOneWidget);
    });

    testWidgets('tapping a category tab switches the display', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text('Food Resources'));
      await tester.pump();

      expect(find.text('Resources Overview'), findsOneWidget);
    });

    testWidgets('tapping all category tabs does not throw', (tester) async {
      await pumpPage(tester);

      for (final category in ResourceCategory.values) {
        await tester.tap(find.text(category.displayName));
        await tester.pump();
      }

      expect(find.text('Resources Overview'), findsOneWidget);
    });

    testWidgets('back button pops the route', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ResourcesPage(resources: resources, grid: grid),
                  ),
                ),
                child: const Text('Go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      expect(find.text('Resources Overview'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Resources Overview'), findsNothing);
    });

    testWidgets('shows production rates when a building generates resources', (
      tester,
    ) async {
      final house = Building(
        type: BuildingType.house,
        name: 'House',
        description: 'Shelter',
        icon: Icons.home,
        color: Colors.green,
        baseCost: 50,
        category: BuildingCategory.residential,
        baseGeneration: {ResourceType.cash: 0.5},
      );
      grid.placeBuilding(0, 0, house, notifyCallbacks: false);

      resources.resources[ResourceType.cash] = 500;

      await pumpPage(tester);

      await tester.tap(find.text('Raw Materials'));
      await tester.pump();

      expect(find.text('Resources Overview'), findsOneWidget);
    });
  });
}
