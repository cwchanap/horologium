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

      // Raw Materials is the default — Gold should be visible immediately
      expect(find.text('Gold'), findsOneWidget);
    });

    testWidgets('tapping a category tab switches the display', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text('Food Resources'));
      await tester.pump();

      // Food Resources tab should show Wheat instead of Gold
      expect(find.text('Wheat'), findsOneWidget);
    });

    testWidgets('tapping all category tabs does not throw', (tester) async {
      await pumpPage(tester);

      for (final category in ResourceCategory.values) {
        await tester.tap(find.text(category.displayName));
        await tester.pump();
      }

      // Final tab (Refinement) should show Bread
      expect(find.text('Bread'), findsOneWidget);
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
      final mine = Building(
        type: BuildingType.coalMine,
        name: 'Coal Mine',
        description: 'Produces coal',
        icon: Icons.fireplace,
        color: Colors.grey,
        baseCost: 90,
        baseGeneration: {ResourceType.coal: 1.0},
        requiredWorkers: 1,
        category: BuildingCategory.rawMaterials,
      );
      mine.assignedWorkers = 1;
      grid.placeBuilding(0, 0, mine, notifyCallbacks: false);

      resources.resources[ResourceType.coal] = 50;

      await pumpPage(tester);

      // Coal is in the Raw Materials category — verify the rate is shown
      expect(find.text('Coal'), findsOneWidget);
      expect(find.text('1.0/s'), findsWidgets);
    });
  });
}
