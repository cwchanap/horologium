import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/constants/assets_path.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/building/category.dart';
import 'package:horologium/game/building/menu.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/game/resources/resources.dart';

void main() {
  Future<void> openDialog(
    WidgetTester tester, {
    required Building building,
    required Resources resources,
    VoidCallback? onResourcesChanged,
    VoidCallback? onBuildingUpgraded,
    VoidCallback? onBuildingDeleted,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  BuildingMenu.showBuildingDetailsDialog(
                    context: context,
                    x: 0,
                    y: 0,
                    building: building,
                    resources: resources,
                    onResourcesChanged: onResourcesChanged ?? () {},
                    onBuildingUpgraded: onBuildingUpgraded ?? () {},
                    onBuildingDeleted: onBuildingDeleted ?? () {},
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Building powerPlant({
    int level = 1,
    int maxLevel = 3,
    int requiredWorkers = 1,
    String? assetPath,
  }) {
    return Building(
      type: BuildingType.powerPlant,
      name: 'Power Plant',
      description: 'Generates electricity',
      icon: Icons.bolt,
      assetPath: assetPath,
      color: Colors.yellow,
      baseCost: 100,
      baseGeneration: const {ResourceType.electricity: 2},
      baseConsumption: const {ResourceType.coal: 1},
      requiredWorkers: requiredWorkers,
      level: level,
      maxLevel: maxLevel,
      category: BuildingCategory.services,
    );
  }

  testWidgets('renders core details and closes cleanly', (
    WidgetTester tester,
  ) async {
    final building = powerPlant(requiredWorkers: 0);
    final resources = Resources();

    await openDialog(tester, building: building, resources: resources);

    expect(find.text('Power Plant'), findsOneWidget);
    expect(find.text('Level 1/3'), findsOneWidget);
    expect(find.text('Generates electricity'), findsOneWidget);
    expect(find.text('Cost'), findsOneWidget);
    expect(find.text('100 cash'), findsOneWidget);
    expect(find.byIcon(Icons.bolt), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('uses a Flutter asset path when the building has an asset', (
    WidgetTester tester,
  ) async {
    final building = powerPlant(requiredWorkers: 0, assetPath: Assets.house);
    final resources = Resources();

    await openDialog(tester, building: building, resources: resources);

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image;
    expect(provider, isA<AssetImage>());
    expect(
      (provider as AssetImage).assetName,
      equals('assets/images/${Assets.house}'),
    );
  });

  testWidgets('shows accommodation for residential buildings', (
    WidgetTester tester,
  ) async {
    final building = Building(
      type: BuildingType.house,
      name: 'House',
      description: 'Shelters residents',
      icon: Icons.house,
      color: Colors.green,
      baseCost: 120,
      basePopulation: 2,
      requiredWorkers: 0,
      category: BuildingCategory.residential,
    );
    final resources = Resources();

    await openDialog(tester, building: building, resources: resources);

    expect(find.text('Accommodation'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('assigns and unassigns workers from the dialog controls', (
    WidgetTester tester,
  ) async {
    final building = powerPlant(requiredWorkers: 2);
    building.assignWorker();
    final resources = Resources()..availableWorkers = 3;
    int resourcesChanged = 0;

    await openDialog(
      tester,
      building: building,
      resources: resources,
      onResourcesChanged: () => resourcesChanged++,
    );

    expect(find.text('1/2'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();

    expect(building.assignedWorkers, equals(2));
    expect(resources.availableWorkers, equals(2));
    expect(resourcesChanged, equals(1));
    expect(find.text('2/2'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.remove_circle_outline));
    await tester.pumpAndSettle();

    expect(building.assignedWorkers, equals(1));
    expect(resources.availableWorkers, equals(3));
    expect(resourcesChanged, equals(2));
    expect(find.text('1/2'), findsOneWidget);
  });

  testWidgets('shows warning state when production requirements are not met', (
    WidgetTester tester,
  ) async {
    final building = powerPlant(requiredWorkers: 1);
    final resources = Resources()
      ..coal = 0
      ..availableWorkers = 0;

    await openDialog(tester, building: building, resources: resources);

    expect(find.byIcon(Icons.warning), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data != null &&
            RegExp(r'^\+0(?:\.0)?/sec$').hasMatch(widget.data!),
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data != null &&
            RegExp(r'^-1(?:\.0)?/sec$').hasMatch(widget.data!),
      ),
      findsOneWidget,
    );
  });

  testWidgets('falls back to enum names when the registry has no label', (
    WidgetTester tester,
  ) async {
    final building = Building(
      type: BuildingType.powerPlant,
      name: 'Fallback Plant',
      description: 'Uses non-registered resource labels',
      icon: Icons.factory,
      color: Colors.orange,
      baseCost: 100,
      baseGeneration: const {ResourceType.population: 1},
      baseConsumption: const {ResourceType.availableWorkers: 1},
      requiredWorkers: 1,
      category: BuildingCategory.services,
    )..assignWorker();
    final resources = Resources();

    await openDialog(tester, building: building, resources: resources);

    expect(find.text('population'), findsOneWidget);
    expect(find.text('availableWorkers'), findsOneWidget);
  });

  testWidgets('updates field crop selection from the dropdown', (
    WidgetTester tester,
  ) async {
    final field = Field(
      type: BuildingType.field,
      name: 'Field',
      description: 'Grows crops',
      icon: Icons.grass,
      color: Colors.green,
      baseCost: 50,
      requiredWorkers: 1,
      category: BuildingCategory.foodResources,
    );
    final resources = Resources();

    await openDialog(tester, building: field, resources: resources);

    expect(find.text('Crop Type:'), findsOneWidget);
    expect(field.cropType, equals(CropType.wheat));

    await tester.tap(
      find.byWidgetPredicate((widget) => widget is DropdownButton<CropType>),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('corn').last);
    await tester.pumpAndSettle();

    expect(field.cropType, equals(CropType.corn));
  });

  testWidgets('updates bakery product selection from the dropdown', (
    WidgetTester tester,
  ) async {
    final bakery = Bakery(
      type: BuildingType.bakery,
      name: 'Bakery',
      description: 'Produces baked goods',
      icon: Icons.bakery_dining,
      color: Colors.orange,
      baseCost: 150,
      requiredWorkers: 1,
      category: BuildingCategory.refinement,
    );
    final resources = Resources();

    await openDialog(tester, building: bakery, resources: resources);

    expect(find.text('Product Type:'), findsOneWidget);
    expect(bakery.productType, equals(BakeryProduct.bread));

    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is DropdownButton<BakeryProduct>,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('pastries').last);
    await tester.pumpAndSettle();

    expect(bakery.productType, equals(BakeryProduct.pastries));
  });

  testWidgets(
    'upgrades the building and dismisses the dialog when affordable',
    (WidgetTester tester) async {
      final building = powerPlant(requiredWorkers: 0);
      final resources = Resources()..cash = 500;
      int resourcesChanged = 0;
      int upgrades = 0;

      await openDialog(
        tester,
        building: building,
        resources: resources,
        onResourcesChanged: () => resourcesChanged++,
        onBuildingUpgraded: () => upgrades++,
      );

      await tester.tap(find.text('Upgrade (200)'));
      await tester.pumpAndSettle();

      expect(building.level, equals(2));
      expect(resources.cash, equals(300));
      expect(resourcesChanged, equals(1));
      expect(upgrades, equals(1));
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets(
    'shows a snackbar instead of upgrading when cash is insufficient',
    (WidgetTester tester) async {
      final building = powerPlant(requiredWorkers: 0);
      final resources = Resources()..cash = 50;
      int upgrades = 0;

      await openDialog(
        tester,
        building: building,
        resources: resources,
        onBuildingUpgraded: () => upgrades++,
      );

      await tester.tap(find.text('Upgrade (200)'));
      await tester.pump();

      expect(building.level, equals(1));
      expect(upgrades, equals(0));
      expect(find.text('Not enough cash!'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
    },
  );
}
