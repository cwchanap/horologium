import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/building/category.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/widgets/game/building_options_dialog.dart';

void main() {
  group('BuildingOptionsDialog Widget Tests', () {
    late Building testBuilding;

    setUp(() {
      testBuilding = Building(
        type: BuildingType.powerPlant,
        name: 'Power Plant',
        description: 'Generates electricity',
        icon: Icons.bolt,
        color: Colors.yellow,
        baseCost: 100,
        baseGeneration: {ResourceType.electricity: 1},
        baseConsumption: {ResourceType.coal: 1},
        maxLevel: 5,
        requiredWorkers: 1,
        category: BuildingCategory.services,
        level: 1,
      );
    });

    testWidgets('displays building name and level', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BuildingOptionsDialog(
              building: testBuilding,
              currentCash: 1000,
              onUpgrade: () {},
              onDelete: () {},
            ),
          ),
        ),
      );

      expect(find.text('Power Plant'), findsOneWidget);
      expect(find.text('Level 1'), findsOneWidget);
    });

    testWidgets('displays upgrade button when can upgrade', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BuildingOptionsDialog(
              building: testBuilding,
              currentCash: 1000,
              onUpgrade: () {},
              onDelete: () {},
            ),
          ),
        ),
      );

      expect(find.textContaining('Upgrade'), findsOneWidget);
      expect(find.textContaining('200'), findsOneWidget); // Upgrade cost
    });

    testWidgets('upgrade button disabled when insufficient cash', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BuildingOptionsDialog(
              building: testBuilding,
              currentCash: 50, // Not enough for upgrade cost of 200
              onUpgrade: () {},
              onDelete: () {},
            ),
          ),
        ),
      );

      final upgradeButton = tester.widget<ElevatedButton>(
        find.byWidgetPredicate(
          (widget) =>
              widget is ElevatedButton &&
              widget.child is Text &&
              (widget.child as Text).data?.contains('Upgrade') == true,
        ),
      );
      expect(upgradeButton.onPressed, isNull);
    });

    testWidgets('upgrade button disabled at max level', (
      WidgetTester tester,
    ) async {
      testBuilding = Building(
        type: BuildingType.powerPlant,
        name: 'Power Plant',
        description: 'Generates electricity',
        icon: Icons.bolt,
        color: Colors.yellow,
        baseCost: 100,
        baseGeneration: {ResourceType.electricity: 1},
        baseConsumption: {ResourceType.coal: 1},
        maxLevel: 5,
        requiredWorkers: 1,
        category: BuildingCategory.services,
        level: 5, // Max level
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BuildingOptionsDialog(
              building: testBuilding,
              currentCash: 10000,
              onUpgrade: () {},
              onDelete: () {},
            ),
          ),
        ),
      );

      expect(find.text('Max Level'), findsOneWidget);
    });

    testWidgets('calls onUpgrade when upgrade button tapped', (
      WidgetTester tester,
    ) async {
      bool upgradeCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BuildingOptionsDialog(
              building: testBuilding,
              currentCash: 1000,
              onUpgrade: () => upgradeCalled = true,
              onDelete: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.textContaining('Upgrade'));
      await tester.pumpAndSettle();

      expect(upgradeCalled, isTrue);
    });

    testWidgets('displays delete button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BuildingOptionsDialog(
              building: testBuilding,
              currentCash: 1000,
              onUpgrade: () {},
              onDelete: () {},
            ),
          ),
        ),
      );

      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('calls onDelete when delete button tapped', (
      WidgetTester tester,
    ) async {
      bool deleteCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BuildingOptionsDialog(
              building: testBuilding,
              currentCash: 1000,
              onUpgrade: () {},
              onDelete: () => deleteCalled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(deleteCalled, isTrue);
    });

    testWidgets('shows current and next level stats', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BuildingOptionsDialog(
              building: testBuilding,
              currentCash: 1000,
              onUpgrade: () {},
              onDelete: () {},
            ),
          ),
        ),
      );

      // Should show production stats
      expect(find.textContaining('Electricity'), findsWidgets);
    });

    testWidgets(
      'shows production stats for Field with crop generation override',
      (WidgetTester tester) async {
        final field = Field(
          type: BuildingType.field,
          name: 'Field',
          description: 'Grows crops',
          icon: Icons.grass,
          color: Colors.lightGreen,
          baseCost: 50,
          requiredWorkers: 1,
          category: BuildingCategory.foodResources,
          cropType: CropType.wheat,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BuildingOptionsDialog(
                building: field,
                currentCash: 1000,
                onUpgrade: () {},
                onDelete: () {},
              ),
            ),
          ),
        );

        // Should show current level production
        expect(find.textContaining('Wheat'), findsWidgets);
        expect(find.textContaining('1.0'), findsWidgets);

        // Upgrade preview should show next level production
        expect(find.textContaining('Level 2 Preview'), findsOneWidget);
        expect(find.textContaining('2.0'), findsWidgets);
      },
    );

    testWidgets(
      'shows production and consumption stats for Bakery with override',
      (WidgetTester tester) async {
        final bakery = Bakery(
          type: BuildingType.bakery,
          name: 'Bakery',
          description: 'Produces bread from flour.',
          icon: Icons.bakery_dining,
          color: Colors.orange,
          baseCost: 150,
          requiredWorkers: 1,
          category: BuildingCategory.refinement,
          productType: BakeryProduct.bread,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BuildingOptionsDialog(
                building: bakery,
                currentCash: 1000,
                onUpgrade: () {},
                onDelete: () {},
              ),
            ),
          ),
        );

        // Should show current level production and consumption
        expect(find.textContaining('Bread'), findsWidgets);
        expect(find.textContaining('Flour'), findsWidgets);
        expect(find.textContaining('1.0'), findsWidgets);
        expect(find.textContaining('2.0'), findsWidgets);

        // Upgrade preview should show next level production and consumption
        expect(find.textContaining('Level 2 Preview'), findsOneWidget);
        expect(
          find.textContaining('2.0'),
          findsWidgets,
        ); // Next level bread: 2.0
        expect(
          find.textContaining('4.0'),
          findsWidgets,
        ); // Next level flour: 4.0
      },
    );

    testWidgets('shows correct stats for Bakery with pastries product type', (
      WidgetTester tester,
    ) async {
      final bakery = Bakery(
        type: BuildingType.bakery,
        name: 'Bakery',
        description: 'Produces pastries from flour.',
        icon: Icons.bakery_dining,
        color: Colors.orange,
        baseCost: 150,
        requiredWorkers: 1,
        category: BuildingCategory.refinement,
        productType: BakeryProduct.pastries,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BuildingOptionsDialog(
              building: bakery,
              currentCash: 1000,
              onUpgrade: () {},
              onDelete: () {},
            ),
          ),
        ),
      );

      // Should show pastries production
      expect(find.textContaining('Pastries'), findsWidgets);
      expect(find.textContaining('1.0'), findsWidgets);

      // Upgrade preview should show next level stats
      expect(find.textContaining('Level 2 Preview'), findsOneWidget);
    });
  });
}
