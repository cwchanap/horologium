# Production Chain Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Kitchen-based downstream food chains, multi-resource upgrade costs, and deterministic production bottleneck recommendations.

**Architecture:** Keep the current `Building`/`Resources` model as the source of truth. Add focused value objects and services only where they reduce duplication: `ResourceCost` for upgrade affordability/deduction and `ProductionRecommendationEngine` for bottleneck advice. New Kitchen chains should flow through existing generation/consumption maps so the production graph and resource tick continue to work without custom graph logic.

**Tech Stack:** Dart 3, Flutter, Flame, SharedPreferences, `flutter_test`.

---

## File Structure

- Create `lib/game/resources/resource_cost.dart`: `ResourceCost` value object with affordability, missing-resource, and deduction helpers.
- Modify `lib/game/resources/resource_type.dart`: add `tortillas`, `riceMeals`, `maltDrink`, and `KitchenProduct`.
- Modify `lib/game/resources/resources.dart`: initialize/access/save-ready new resources and include them in happiness food.
- Modify `lib/game/building/building.dart`: add `BuildingType.kitchen`, `Kitchen` subclass, registry entry, and `ResourceCost upgradeCost`.
- Modify `lib/game/research/research.dart`: unlock Kitchen through `Food Processing`.
- Modify `lib/game/planet/placed_building_data.dart`: serialize/restore Kitchen product variant.
- Modify `lib/game/main_game.dart`, `lib/game/scene_widget.dart`, and `lib/widgets/game/production_overlay/production_overlay.dart`: include Kitchen variants in saved placement and graph refresh signatures.
- Modify `lib/game/services/save_service.dart`: legacy-resource fallback for new resources; JSON save already maps all entries in `Resources.resources`.
- Modify `lib/game/building/menu.dart` and `lib/widgets/game/building_options_dialog.dart`: display/deduct `ResourceCost` for upgrades.
- Modify `lib/game/building/menu.dart`: add Kitchen product dropdown because placed-building detail dialogs are rendered through `BuildingMenu.showBuildingDetailsDialog`.
- Create `lib/game/production/production_recommendation_engine.dart`: deterministic recommendation service.
- Update `lib/widgets/game/production_overlay/node_detail_panel.dart` and `lib/widgets/game/production_overlay/production_overlay.dart`: surface recommendation engine messages in the existing selected-node detail panel.
- Update tests in `test/resources/`, `test/building/`, `test/planet/`, `test/services/`, `test/game/production/`, `test/widgets/game/`, and `test/game/scene_widget_test.dart`.

---

### Task 1: Add ResourceCost Value Object

**Files:**
- Create: `lib/game/resources/resource_cost.dart`
- Test: `test/resources/resource_cost_test.dart`

- [ ] **Step 1: Write failing ResourceCost tests**

Create `test/resources/resource_cost_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/resources/resource_cost.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/game/resources/resources.dart';

void main() {
  group('ResourceCost', () {
    test('cashOnly creates a cash resource cost', () {
      final cost = ResourceCost.cashOnly(150);

      expect(cost.resources, equals({ResourceType.cash: 150}));
      expect(cost.isEmpty, isFalse);
    });

    test('canAfford returns true when every resource is available', () {
      final resources = Resources()
        ..cash = 500
        ..planks = 10
        ..stone = 5;
      final cost = ResourceCost({
        ResourceType.cash: 200,
        ResourceType.planks: 4,
        ResourceType.stone: 2,
      });

      expect(cost.canAfford(resources), isTrue);
      expect(cost.missingResources(resources), isEmpty);
    });

    test('canAfford returns false and reports all missing resources', () {
      final resources = Resources()
        ..cash = 100
        ..planks = 1
        ..stone = 0;
      final cost = ResourceCost({
        ResourceType.cash: 200,
        ResourceType.planks: 4,
        ResourceType.stone: 2,
      });

      expect(cost.canAfford(resources), isFalse);
      expect(
        cost.missingResources(resources),
        equals({
          ResourceType.cash: 100,
          ResourceType.planks: 3,
          ResourceType.stone: 2,
        }),
      );
    });

    test('deductFrom deducts atomically when affordable', () {
      final resources = Resources()
        ..cash = 500
        ..planks = 10
        ..stone = 5;
      final cost = ResourceCost({
        ResourceType.cash: 200,
        ResourceType.planks: 4,
        ResourceType.stone: 2,
      });

      expect(cost.deductFrom(resources), isTrue);
      expect(resources.cash, equals(300));
      expect(resources.planks, equals(6));
      expect(resources.stone, equals(3));
    });

    test('deductFrom does not partially deduct when unaffordable', () {
      final resources = Resources()
        ..cash = 500
        ..planks = 1
        ..stone = 5;
      final cost = ResourceCost({
        ResourceType.cash: 200,
        ResourceType.planks: 4,
        ResourceType.stone: 2,
      });

      expect(cost.deductFrom(resources), isFalse);
      expect(resources.cash, equals(500));
      expect(resources.planks, equals(1));
      expect(resources.stone, equals(5));
    });
  });
}
```

- [ ] **Step 2: Run ResourceCost tests and verify they fail**

Run:

```bash
flutter test test/resources/resource_cost_test.dart
```

Expected: FAIL because `resource_cost.dart` does not exist.

- [ ] **Step 3: Implement ResourceCost**

Create `lib/game/resources/resource_cost.dart`:

```dart
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/game/resources/resources.dart';

class ResourceCost {
  final Map<ResourceType, double> resources;

  ResourceCost(Map<ResourceType, double> resources)
    : resources = Map.unmodifiable(
        Map.fromEntries(
          resources.entries.where((entry) => entry.value > 0),
        ),
      );

  factory ResourceCost.cashOnly(num amount) {
    return ResourceCost({ResourceType.cash: amount.toDouble()});
  }

  static final empty = ResourceCost({});

  bool get isEmpty => resources.isEmpty;

  bool canAfford(Resources available) {
    return missingResources(available).isEmpty;
  }

  Map<ResourceType, double> missingResources(Resources available) {
    final missing = <ResourceType, double>{};
    for (final entry in resources.entries) {
      final current = available.getResource(entry.key);
      if (current < entry.value) {
        missing[entry.key] = entry.value - current;
      }
    }
    return missing;
  }

  bool deductFrom(Resources available) {
    if (!canAfford(available)) return false;

    for (final entry in resources.entries) {
      available.setResource(
        entry.key,
        available.getResource(entry.key) - entry.value,
      );
    }
    return true;
  }
}
```

- [ ] **Step 4: Run ResourceCost tests and verify they pass**

Run:

```bash
flutter test test/resources/resource_cost_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/game/resources/resource_cost.dart test/resources/resource_cost_test.dart
git commit -m "feat: add resource cost value object"
```

---

### Task 2: Add New Food Resources And Kitchen Product Enum

**Files:**
- Modify: `lib/game/resources/resource_type.dart`
- Modify: `lib/game/resources/resources.dart`
- Test: `test/resources/resource_type_test.dart`
- Test: `test/resources/resources_test.dart`

- [ ] **Step 1: Write failing resource enum and initialization tests**

Append to `test/resources/resource_type_test.dart`:

```dart
group('KitchenProduct enum', () {
  test('contains all kitchen product modes', () {
    expect(
      KitchenProduct.values,
      containsAll([
        KitchenProduct.tortillas,
        KitchenProduct.riceMeals,
        KitchenProduct.maltDrink,
      ]),
    );
  });
});
```

Append to `test/resources/resources_test.dart`:

```dart
test('initializes kitchen finished food resources to zero', () {
  final resources = Resources();

  expect(resources.tortillas, equals(0));
  expect(resources.riceMeals, equals(0));
  expect(resources.maltDrink, equals(0));
  expect(resources.getResource(ResourceType.tortillas), equals(0));
  expect(resources.getResource(ResourceType.riceMeals), equals(0));
  expect(resources.getResource(ResourceType.maltDrink), equals(0));
});
```

- [ ] **Step 2: Run resource tests and verify they fail**

Run:

```bash
flutter test test/resources/resource_type_test.dart test/resources/resources_test.dart
```

Expected: FAIL because `KitchenProduct`, `ResourceType.tortillas`, `ResourceType.riceMeals`, `ResourceType.maltDrink`, and getters do not exist.

- [ ] **Step 3: Add resource enum values and registry entries**

Modify `lib/game/resources/resource_type.dart`:

```dart
enum ResourceType {
  cash,
  population,
  availableWorkers,
  gold,
  wood,
  coal,
  electricity,
  research,
  water,
  planks,
  stone,
  wheat,
  corn,
  rice,
  barley,
  flour,
  cornmeal,
  polishedRice,
  maltedBarley,
  bread,
  pastries,
  tortillas,
  riceMeals,
  maltDrink,
}
```

Add registry entries after `pastries`:

```dart
Resource(
  type: ResourceType.tortillas,
  name: 'Tortillas',
  value: 10,
  category: ResourceCategory.refinement,
),
Resource(
  type: ResourceType.riceMeals,
  name: 'Rice Meals',
  value: 10,
  category: ResourceCategory.refinement,
),
Resource(
  type: ResourceType.maltDrink,
  name: 'Malt Drink',
  value: 12,
  category: ResourceCategory.refinement,
),
```

Add enum:

```dart
enum KitchenProduct { tortillas, riceMeals, maltDrink }
```

- [ ] **Step 4: Add resource storage and accessors**

Modify `lib/game/resources/resources.dart` initial map:

```dart
ResourceType.tortillas: 0,
ResourceType.riceMeals: 0,
ResourceType.maltDrink: 0,
```

Add getters:

```dart
double get tortillas => resources[ResourceType.tortillas]!;
double get riceMeals => resources[ResourceType.riceMeals]!;
double get maltDrink => resources[ResourceType.maltDrink]!;
```

Add setters:

```dart
set tortillas(double value) => resources[ResourceType.tortillas] = value;
set riceMeals(double value) => resources[ResourceType.riceMeals] = value;
set maltDrink(double value) => resources[ResourceType.maltDrink] = value;
```

- [ ] **Step 5: Run resource tests and verify they pass**

Run:

```bash
flutter test test/resources/resource_type_test.dart test/resources/resources_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/game/resources/resource_type.dart lib/game/resources/resources.dart test/resources/resource_type_test.dart test/resources/resources_test.dart
git commit -m "feat: add kitchen food resources"
```

---

### Task 3: Add Kitchen Building And Recipes

**Files:**
- Modify: `lib/game/building/building.dart`
- Modify: `lib/game/research/research.dart`
- Test: `test/building/field_and_bakery_test.dart`
- Test: `test/research/research_test.dart`

- [ ] **Step 1: Write failing Kitchen recipe tests**

Append to `test/building/field_and_bakery_test.dart`:

```dart
Kitchen _makeKitchen({
  KitchenProduct productType = KitchenProduct.tortillas,
  int level = 1,
}) {
  return Kitchen(
    type: BuildingType.kitchen,
    name: 'Kitchen',
    description: 'Prepares finished foods from processed staples',
    icon: Icons.restaurant,
    color: Colors.deepOrange,
    baseCost: 180,
    requiredWorkers: 1,
    category: BuildingCategory.refinement,
    level: level,
    productType: productType,
  );
}

group('Kitchen', () {
  test('generates tortillas from cornmeal and water', () {
    final kitchen = _makeKitchen(productType: KitchenProduct.tortillas);

    expect(kitchen.generation, equals({ResourceType.tortillas: 1.0}));
    expect(
      kitchen.consumption,
      equals({ResourceType.cornmeal: 2.0, ResourceType.water: 1.0}),
    );
  });

  test('generates rice meals from polished rice and water', () {
    final kitchen = _makeKitchen(productType: KitchenProduct.riceMeals);

    expect(kitchen.generation, equals({ResourceType.riceMeals: 1.0}));
    expect(
      kitchen.consumption,
      equals({ResourceType.polishedRice: 2.0, ResourceType.water: 1.0}),
    );
  });

  test('generates malt drink from malted barley and water', () {
    final kitchen = _makeKitchen(productType: KitchenProduct.maltDrink);

    expect(kitchen.generation, equals({ResourceType.maltDrink: 1.0}));
    expect(
      kitchen.consumption,
      equals({ResourceType.maltedBarley: 2.0, ResourceType.water: 1.0}),
    );
  });

  test('level scales kitchen generation and consumption', () {
    final kitchen = _makeKitchen(
      productType: KitchenProduct.tortillas,
      level: 3,
    );

    expect(kitchen.generation, equals({ResourceType.tortillas: 3.0}));
    expect(
      kitchen.consumption,
      equals({ResourceType.cornmeal: 6.0, ResourceType.water: 3.0}),
    );
  });
});
```

Ensure `test/building/field_and_bakery_test.dart` has these imports:

```dart
import 'package:flutter/material.dart';
import 'package:horologium/game/building/category.dart';
```

Append to `test/research/research_test.dart`:

```dart
test('foodProcessing unlocks Kitchen', () {
  final foodProcessing = Research.availableResearch.firstWhere(
    (research) => research.type == ResearchType.foodProcessing,
  );

  expect(foodProcessing.unlocksBuildings, contains(BuildingType.kitchen));
});
```

- [ ] **Step 2: Run Kitchen tests and verify they fail**

Run:

```bash
flutter test test/building/field_and_bakery_test.dart test/research/research_test.dart
```

Expected: FAIL because `Kitchen`, `BuildingType.kitchen`, and `KitchenProduct` usage in building code do not exist.

- [ ] **Step 3: Implement Kitchen building**

Modify `lib/game/building/building.dart`:

```dart
enum BuildingType {
  powerPlant,
  researchLab,
  house,
  largeHouse,
  goldMine,
  woodFactory,
  coalMine,
  waterTreatment,
  sawmill,
  quarry,
  field,
  windMill,
  grinderMill,
  riceHuller,
  maltHouse,
  bakery,
  kitchen,
}
```

Add after `Bakery`:

```dart
class Kitchen extends Building {
  KitchenProduct productType;

  Kitchen({
    super.id,
    required super.type,
    required super.name,
    required super.description,
    required super.icon,
    super.assetPath,
    required super.color,
    required super.baseCost,
    super.baseGeneration = const {},
    super.baseConsumption = const {},
    super.basePopulation = 0,
    super.maxLevel = 5,
    super.gridSize = 4,
    super.baseBuildingLimit = 4,
    super.requiredWorkers = 1,
    required super.category,
    super.level = 1,
    this.productType = KitchenProduct.tortillas,
  });

  @override
  Map<ResourceType, double> get generation {
    switch (productType) {
      case KitchenProduct.tortillas:
        return {ResourceType.tortillas: 1.0 * level};
      case KitchenProduct.riceMeals:
        return {ResourceType.riceMeals: 1.0 * level};
      case KitchenProduct.maltDrink:
        return {ResourceType.maltDrink: 1.0 * level};
    }
  }

  @override
  Map<ResourceType, double> get consumption {
    switch (productType) {
      case KitchenProduct.tortillas:
        return {
          ResourceType.cornmeal: 2.0 * level,
          ResourceType.water: 1.0 * level,
        };
      case KitchenProduct.riceMeals:
        return {
          ResourceType.polishedRice: 2.0 * level,
          ResourceType.water: 1.0 * level,
        };
      case KitchenProduct.maltDrink:
        return {
          ResourceType.maltedBarley: 2.0 * level,
          ResourceType.water: 1.0 * level,
        };
    }
  }
}
```

Add registry entry after `Bakery`:

```dart
Kitchen(
  type: BuildingType.kitchen,
  name: 'Kitchen',
  description: 'Prepares tortillas, rice meals, or malt drinks.',
  icon: Icons.restaurant,
  color: Colors.deepOrange,
  baseCost: 180,
  requiredWorkers: 1,
  category: BuildingCategory.refinement,
),
```

- [ ] **Step 4: Unlock Kitchen through Food Processing**

Modify `lib/game/research/research.dart`:

```dart
Research(
  type: ResearchType.foodProcessing,
  name: 'Food Processing',
  description: 'Unlocks Bakeries and Kitchens for producing finished foods',
  icon: Icons.bakery_dining,
  color: Colors.orange,
  cost: 30,
  prerequisites: [ResearchType.grainProcessing],
  unlocksBuildings: [BuildingType.bakery, BuildingType.kitchen],
),
```

- [ ] **Step 5: Run Kitchen tests and verify they pass**

Run:

```bash
flutter test test/building/field_and_bakery_test.dart test/research/research_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/game/building/building.dart lib/game/research/research.dart test/building/field_and_bakery_test.dart test/research/research_test.dart
git commit -m "feat: add kitchen production building"
```

---

### Task 4: Persist Kitchen Variants And New Resources

**Files:**
- Modify: `lib/game/planet/placed_building_data.dart`
- Modify: `lib/game/main_game.dart`
- Modify: `lib/game/scene_widget.dart`
- Modify: `lib/widgets/game/production_overlay/production_overlay.dart`
- Modify: `lib/game/services/save_service.dart`
- Test: `test/planet/placed_building_data_variants_test.dart`
- Test: `test/services/save_service_test.dart`
- Test: `test/widgets/game/production_overlay_test.dart`

- [ ] **Step 1: Write failing persistence and signature tests**

Append to `test/planet/placed_building_data_variants_test.dart`:

```dart
test('restores Kitchen product variant', () {
  final data = PlacedBuildingData(
    id: 'kitchen-1',
    x: 2,
    y: 3,
    type: BuildingType.kitchen,
    variant: KitchenProduct.riceMeals.name,
  );

  final building = data.createBuilding();

  expect(building, isA<Kitchen>());
  expect((building! as Kitchen).productType, equals(KitchenProduct.riceMeals));
});

test('falls back to tortillas for unknown Kitchen variant', () {
  final data = PlacedBuildingData(
    id: 'kitchen-1',
    x: 2,
    y: 3,
    type: BuildingType.kitchen,
    variant: 'unknown',
  );

  final building = data.createBuilding();

  expect(building, isA<Kitchen>());
  expect((building! as Kitchen).productType, equals(KitchenProduct.tortillas));
});
```

Add save-service assertions to an existing planet save/load test in `test/services/save_service_test.dart`:

```dart
planet.resources.tortillas = 7;
planet.resources.riceMeals = 8;
planet.resources.maltDrink = 9;
```

After load:

```dart
expect(loaded.resources.tortillas, equals(7));
expect(loaded.resources.riceMeals, equals(8));
expect(loaded.resources.maltDrink, equals(9));
```

Append to `test/widgets/game/production_overlay_test.dart` near Field/Bakery signature tests:

```dart
testWidgets('rebuilds graph when Kitchen productType changes', (tester) async {
  final kitchen = Kitchen(
    type: BuildingType.kitchen,
    name: 'Kitchen',
    description: 'Prepares food',
    icon: Icons.restaurant,
    color: Colors.deepOrange,
    baseCost: 180,
    requiredWorkers: 1,
    category: BuildingCategory.refinement,
    productType: KitchenProduct.tortillas,
  )..assignWorker();

  await tester.pumpWidget(
    MaterialApp(
      home: ProductionOverlay(
        getBuildings: () => [kitchen],
        getResources: () => Resources(),
        onClose: () {},
      ),
    ),
  );

  expect(find.text('tortillas'), findsWidgets);

  kitchen.productType = KitchenProduct.riceMeals;
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();

  expect(find.text('riceMeals'), findsWidgets);
});
```

- [ ] **Step 2: Run persistence tests and verify they fail**

Run:

```bash
flutter test test/planet/placed_building_data_variants_test.dart test/services/save_service_test.dart test/widgets/game/production_overlay_test.dart
```

Expected: FAIL because Kitchen variants and overlay signatures do not include Kitchen yet.

- [ ] **Step 3: Restore Kitchen from PlacedBuildingData**

Modify `lib/game/planet/placed_building_data.dart` after the Bakery branch:

```dart
if (template is Kitchen) {
  KitchenProduct productType = KitchenProduct.tortillas;
  if (variant != null) {
    final matched = KitchenProduct.values
        .where((e) => e.name == variant)
        .firstOrNull;
    if (matched != null) {
      productType = matched;
    } else {
      debugPrint(
        'Warning: Unknown kitchen variant "$variant" for Kitchen at ($x,$y). '
        'Falling back to tortillas.',
      );
    }
  }
  return Kitchen(
    id: id,
    type: template.type,
    name: template.name,
    description: template.description,
    icon: template.icon,
    assetPath: template.assetPath,
    color: template.color,
    baseCost: template.baseCost,
    basePopulation: template.basePopulation,
    maxLevel: template.maxLevel,
    gridSize: template.gridSize,
    baseBuildingLimit: template.baseBuildingLimit,
    requiredWorkers: template.requiredWorkers,
    category: template.category,
    level: level,
    productType: productType,
  )..assignedWorkers = assignedWorkers;
}
```

- [ ] **Step 4: Save Kitchen variants from runtime buildings**

Modify variant capture in `lib/game/main_game.dart`:

```dart
if (building is Field) {
  variant = building.cropType.name;
} else if (building is Bakery) {
  variant = building.productType.name;
} else if (building is Kitchen) {
  variant = building.productType.name;
}
```

Make the same variant capture change in `lib/game/scene_widget.dart`.

Modify `lib/widgets/game/production_overlay/production_overlay.dart` signature:

```dart
if (b is Field) {
  signature += ':${b.cropType.name}';
} else if (b is Bakery) {
  signature += ':${b.productType.name}';
} else if (b is Kitchen) {
  signature += ':${b.productType.name}';
}
```

- [ ] **Step 5: Add legacy fallback resource loading**

Modify `_loadLegacyResources` in `lib/game/services/save_service.dart` after pastries:

```dart
resources.tortillas =
    prefs.getDouble(_planetResourceKey(planetId, 'tortillas')) ?? 0.0;
resources.riceMeals =
    prefs.getDouble(_planetResourceKey(planetId, 'riceMeals')) ?? 0.0;
resources.maltDrink =
    prefs.getDouble(_planetResourceKey(planetId, 'maltDrink')) ?? 0.0;
```

No JSON save change is needed because `savePlanet` serializes `planet.resources.resources`.

- [ ] **Step 6: Run persistence tests and verify they pass**

Run:

```bash
flutter test test/planet/placed_building_data_variants_test.dart test/services/save_service_test.dart test/widgets/game/production_overlay_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/game/planet/placed_building_data.dart lib/game/main_game.dart lib/game/scene_widget.dart lib/widgets/game/production_overlay/production_overlay.dart lib/game/services/save_service.dart test/planet/placed_building_data_variants_test.dart test/services/save_service_test.dart test/widgets/game/production_overlay_test.dart
git commit -m "feat: persist kitchen production variants"
```

---

### Task 5: Include New Finished Foods In Happiness

**Files:**
- Modify: `lib/game/resources/resources.dart`
- Test: `test/resources/resources_test.dart`

- [ ] **Step 1: Write failing happiness test**

Append to `test/resources/resources_test.dart`:

```dart
test('happiness food factor includes kitchen finished foods', () {
  final resources = Resources()
    ..population = 20
    ..availableWorkers = 20
    ..bread = 0
    ..pastries = 0
    ..tortillas = 4
    ..riceMeals = 0
    ..maltDrink = 0;

  resources.update([]);

  expect(resources.happiness, greaterThan(45));
});
```

This uses the existing smoothing behavior from an initial happiness of 50. With 4 total finished foods for 20 population, food satisfaction is full and happiness should not collapse from missing bread/pastries alone.

- [ ] **Step 2: Run the happiness test and verify it fails**

Run:

```bash
flutter test test/resources/resources_test.dart --plain-name "happiness food factor includes kitchen finished foods"
```

Expected: FAIL because only bread and pastries count.

- [ ] **Step 3: Include Kitchen foods in happiness calculation**

Modify `_updateHappiness` in `lib/game/resources/resources.dart`:

```dart
final totalFood = bread + pastries + tortillas + riceMeals + maltDrink;
```

- [ ] **Step 4: Run the happiness test and verify it passes**

Run:

```bash
flutter test test/resources/resources_test.dart --plain-name "happiness food factor includes kitchen finished foods"
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/game/resources/resources.dart test/resources/resources_test.dart
git commit -m "feat: count kitchen foods in happiness"
```

---

### Task 6: Convert Building Upgrade Cost To ResourceCost

**Files:**
- Modify: `lib/game/building/building.dart`
- Modify: `lib/game/scene_widget.dart`
- Modify: `lib/game/building/menu.dart`
- Modify: `lib/widgets/game/building_options_dialog.dart`
- Test: `test/building/building_upgrade_test.dart`
- Test: `test/widgets/game/building_options_dialog_test.dart`
- Test: `test/building/building_menu_test.dart`
- Test: `test/game/scene_widget_test.dart`

- [ ] **Step 1: Write failing upgrade-cost tests**

Update `test/building/building_upgrade_test.dart` tests that expect `building.upgradeCost` as an int. Replace with:

```dart
test('upgradeCost includes cash for the next level', () {
  expect(
    testBuilding.upgradeCost.resources[ResourceType.cash],
    equals(200),
  );

  testBuilding.upgrade();

  expect(
    testBuilding.upgradeCost.resources[ResourceType.cash],
    equals(300),
  );
});
```

Add:

```dart
test('processing building upgradeCost includes planks and stone', () {
  final sawmill = BuildingRegistry.availableBuildings.firstWhere(
    (building) => building.type == BuildingType.sawmill,
  );

  expect(sawmill.upgradeCost.resources[ResourceType.cash], equals(200));
  expect(sawmill.upgradeCost.resources[ResourceType.planks], greaterThan(0));
  expect(sawmill.upgradeCost.resources[ResourceType.stone], greaterThan(0));
});
```

- [ ] **Step 2: Run upgrade tests and verify they fail**

Run:

```bash
flutter test test/building/building_upgrade_test.dart
```

Expected: FAIL because `upgradeCost` is still `int`.

- [ ] **Step 3: Change Building.upgradeCost type and formula**

Import `resource_cost.dart` in `lib/game/building/building.dart`:

```dart
import 'package:horologium/game/resources/resource_cost.dart';
```

Replace:

```dart
int get upgradeCost => baseCost * (level + 1);
```

with:

```dart
ResourceCost get upgradeCost {
  final nextLevel = level + 1;
  final costs = <ResourceType, double>{
    ResourceType.cash: (baseCost * nextLevel).toDouble(),
  };

  void add(ResourceType type, double amount) {
    costs.update(type, (value) => value + amount, ifAbsent: () => amount);
  }

  switch (category) {
    case BuildingCategory.residential:
      add(ResourceType.planks, 2.0 * nextLevel);
      if (type == BuildingType.largeHouse) {
        add(ResourceType.stone, 1.0 * nextLevel);
      }
      break;
    case BuildingCategory.rawMaterials:
    case BuildingCategory.foodResources:
      add(ResourceType.planks, 1.0 * nextLevel);
      break;
    case BuildingCategory.services:
      add(ResourceType.stone, 2.0 * nextLevel);
      break;
    case BuildingCategory.primaryFactory:
    case BuildingCategory.processing:
    case BuildingCategory.refinement:
      add(ResourceType.planks, 2.0 * nextLevel);
      add(ResourceType.stone, 1.0 * nextLevel);
      break;
  }

  if (type == BuildingType.kitchen) {
    costs[ResourceType.stone] = 0;
    costs[ResourceType.planks] = 2.0 * nextLevel;
  }

  return ResourceCost(costs);
}
```

- [ ] **Step 4: Update upgrade flow deduction**

In `lib/game/scene_widget.dart`, replace cash-only check/deduct:

```dart
if (!building.upgradeCost.canAfford(widget.planet.resources)) return;

setState(() {
  final deducted = building.upgradeCost.deductFrom(widget.planet.resources);
  if (!deducted) return;
  building.upgrade();
  _updatePlanetBuildingLevel(x, y, building.level);
});
```

In `lib/game/building/menu.dart`, replace:

```dart
if (resources.cash >= building.upgradeCost) {
  resources.cash -= building.upgradeCost;
```

with:

```dart
if (building.upgradeCost.deductFrom(resources)) {
```

and update the snack text to:

```dart
const SnackBar(content: Text('Not enough resources!'))
```

- [ ] **Step 5: Update BuildingOptionsDialog affordability**

Change constructor from `currentCash` to `Resources resources` in `lib/widgets/game/building_options_dialog.dart`. The dialog needs access to all resources:

```dart
final Resources resources;
```

Import:

```dart
import '../../game/resources/resources.dart';
```

Replace:

```dart
final canAffordUpgrade = currentCash >= building.upgradeCost;
```

with:

```dart
final canAffordUpgrade = building.upgradeCost.canAfford(resources);
```

Add a helper:

```dart
String _formatCost(ResourceCost cost) {
  return cost.resources.entries
      .map(
        (entry) =>
            '${entry.value.toStringAsFixed(entry.value.truncateToDouble() == entry.value ? 0 : 1)} ${_getResourceDisplayName(entry.key)}',
      )
      .join(', ');
}
```

Use:

```dart
child: Text('Upgrade (${_formatCost(building.upgradeCost)})'),
```

Update call site in `lib/game/scene_widget.dart`:

```dart
resources: widget.planet.resources,
```

- [ ] **Step 6: Update tests for ResourceCost UI**

In `test/widgets/game/building_options_dialog_test.dart`, replace `currentCash: 1000` with:

```dart
resources: Resources()..cash = 1000,
```

Where material costs need affordability, also set:

```dart
..planks = 100
..stone = 100
```

Update text expectations from raw `200` to either `Cash` or `Upgrade (`:

```dart
expect(find.textContaining('Upgrade'), findsOneWidget);
expect(find.textContaining('Cash'), findsWidgets);
```

In `test/building/building_menu_test.dart`, update taps:

```dart
await tester.tap(find.textContaining('Upgrade'));
```

Ensure test resources include enough `planks` and `stone` where needed.

- [ ] **Step 7: Run upgrade UI tests and verify they pass**

Run:

```bash
flutter test test/building/building_upgrade_test.dart test/widgets/game/building_options_dialog_test.dart test/building/building_menu_test.dart test/game/scene_widget_test.dart
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/game/building/building.dart lib/game/scene_widget.dart lib/game/building/menu.dart lib/widgets/game/building_options_dialog.dart test/building/building_upgrade_test.dart test/widgets/game/building_options_dialog_test.dart test/building/building_menu_test.dart test/game/scene_widget_test.dart
git commit -m "feat: support multi-resource upgrade costs"
```

---

### Task 7: Add Kitchen UI And Resource Icon Coverage

**Files:**
- Modify: `lib/game/building/menu.dart`
- Modify: `lib/widgets/game/building_options_dialog.dart`
- Modify: `lib/widgets/game/resource_icon.dart`
- Modify: `lib/pages/resources_page.dart`
- Modify: `lib/pages/trade_page.dart`
- Test: `test/building/building_menu_test.dart`
- Test: `test/widgets/game/building_options_dialog_test.dart`
- Test: `test/widgets/game/resource_icon_test.dart`
- Test: `test/pages/resources_page_test.dart`

- [ ] **Step 1: Write failing Kitchen UI tests**

Append to `test/building/building_menu_test.dart`:

```dart
testWidgets('shows Kitchen product selector and updates product', (tester) async {
  final kitchen = Kitchen(
    type: BuildingType.kitchen,
    name: 'Kitchen',
    description: 'Prepares food',
    icon: Icons.restaurant,
    color: Colors.deepOrange,
    baseCost: 180,
    requiredWorkers: 1,
    category: BuildingCategory.refinement,
  );

  await pumpBuildingMenu(tester, kitchen);

  expect(find.text('Product Type:'), findsOneWidget);
  expect(find.byType(DropdownButton<KitchenProduct>), findsOneWidget);

  await tester.tap(find.byType(DropdownButton<KitchenProduct>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('riceMeals').last);
  await tester.pumpAndSettle();

  expect(kitchen.productType, equals(KitchenProduct.riceMeals));
});
```

Append to `test/widgets/game/resource_icon_test.dart`:

```dart
testWidgets('renders kitchen food resource icons', (tester) async {
  for (final type in [
    ResourceType.tortillas,
    ResourceType.riceMeals,
    ResourceType.maltDrink,
  ]) {
    await tester.pumpWidget(MaterialApp(home: ResourceIcon(resourceType: type)));
    expect(find.byType(ResourceIcon), findsOneWidget);
  }
});
```

- [ ] **Step 2: Run UI tests and verify they fail**

Run:

```bash
flutter test test/building/building_menu_test.dart test/widgets/game/resource_icon_test.dart test/pages/resources_page_test.dart
```

Expected: FAIL because Kitchen selector and resource icon mappings are missing.

- [ ] **Step 3: Add Kitchen product selector to BuildingMenu**

In `lib/game/building/menu.dart`, after Bakery selector:

```dart
if (building is Kitchen) ...[
  const SizedBox(height: 16),
  const Text(
    'Product Type:',
    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
  ),
  DropdownButton<KitchenProduct>(
    value: building.productType,
    onChanged: (KitchenProduct? newValue) {
      if (newValue != null) {
        setState(() {
          building.productType = newValue;
        });
      }
    },
    items: KitchenProduct.values
        .map<DropdownMenuItem<KitchenProduct>>((KitchenProduct value) {
          return DropdownMenuItem<KitchenProduct>(
            value: value,
            child: Text(value.name),
          );
        })
        .toList(),
  ),
],
```

Do not add Kitchen product selection to `BuildingOptionsDialog` in this task. That dialog is used for compact upgrade/delete options in `MainGameWidget`; product selection remains in `BuildingMenu.showBuildingDetailsDialog`, matching the existing Field and Bakery controls.

- [ ] **Step 4: Add resource icon/name mappings**

In `lib/widgets/game/resource_icon.dart`, add cases for:

```dart
case ResourceType.tortillas:
case ResourceType.riceMeals:
case ResourceType.maltDrink:
```

Use existing fallback icon/color patterns if no asset exists. Do not add generated assets in this task.

In `lib/pages/resources_page.dart`, add `tortillas`, `riceMeals`, and `maltDrink` to the resource list used to build resource cards.

In `lib/pages/trade_page.dart`, inspect the existing buy/sell resource source. If it already derives options from `ResourceRegistry.availableResources`, make no code change and leave the file unstaged. If it has a hard-coded resource list, add `ResourceType.tortillas`, `ResourceType.riceMeals`, and `ResourceType.maltDrink` to that list in the same ordering as `ResourceRegistry.availableResources`.

- [ ] **Step 5: Run UI tests and verify they pass**

Run:

```bash
flutter test test/building/building_menu_test.dart test/widgets/game/resource_icon_test.dart test/pages/resources_page_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/game/building/menu.dart lib/widgets/game/building_options_dialog.dart lib/widgets/game/resource_icon.dart lib/pages/resources_page.dart lib/pages/trade_page.dart test/building/building_menu_test.dart test/widgets/game/building_options_dialog_test.dart test/widgets/game/resource_icon_test.dart test/pages/resources_page_test.dart
git commit -m "feat: expose kitchen foods in ui"
```

---

### Task 8: Add ProductionRecommendationEngine

**Files:**
- Create: `lib/game/production/production_recommendation_engine.dart`
- Test: `test/game/production/production_recommendation_engine_test.dart`

- [ ] **Step 1: Write failing recommendation engine tests**

Create `test/game/production/production_recommendation_engine_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/building/category.dart';
import 'package:horologium/game/production/flow_analyzer.dart';
import 'package:horologium/game/production/production_graph.dart';
import 'package:horologium/game/production/production_recommendation_engine.dart';
import 'package:horologium/game/research/research.dart';
import 'package:horologium/game/research/research_type.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/game/resources/resources.dart';

void main() {
  group('ProductionRecommendationEngine', () {
    test('recommends assigning workers to idle producer first', () {
      final coalMine = _building(
        type: BuildingType.coalMine,
        generation: {ResourceType.coal: 1},
        assignedWorkers: 0,
      );
      final powerPlant = _building(
        type: BuildingType.powerPlant,
        consumption: {ResourceType.coal: 1},
        assignedWorkers: 1,
      );
      final graph = FlowAnalyzer.analyzeGraph(
        ProductionGraph.fromBuildings([coalMine, powerPlant], Resources()),
      );

      final recommendations = ProductionRecommendationEngine.recommend(
        graph: graph,
        buildings: [coalMine, powerPlant],
        resources: Resources(),
        researchManager: ResearchManager(),
        buildingLimitManager: BuildingLimitManager(),
      );

      expect(recommendations[ResourceType.coal]!.type, RecommendationType.assignWorkers);
      expect(recommendations[ResourceType.coal]!.targetBuildingType, BuildingType.coalMine);
    });

    test('recommends switching Field crop for crop shortages', () {
      final field = Field(
        type: BuildingType.field,
        name: 'Field',
        description: 'Grows crops',
        icon: Icons.grass,
        color: Colors.green,
        baseCost: 50,
        requiredWorkers: 1,
        category: BuildingCategory.foodResources,
        cropType: CropType.wheat,
      )..assignWorker();
      final grinder = _building(
        type: BuildingType.grinderMill,
        consumption: {ResourceType.corn: 4},
        assignedWorkers: 1,
      );
      final graph = FlowAnalyzer.analyzeGraph(
        ProductionGraph.fromBuildings([field, grinder], Resources()),
      );

      final recommendations = ProductionRecommendationEngine.recommend(
        graph: graph,
        buildings: [field, grinder],
        resources: Resources(),
        researchManager: ResearchManager(),
        buildingLimitManager: BuildingLimitManager(),
      );

      expect(recommendations[ResourceType.corn]!.type, RecommendationType.switchRecipe);
      expect(recommendations[ResourceType.corn]!.message, contains('corn'));
    });

    test('recommends researching locked producer', () {
      final consumer = _building(
        type: BuildingType.largeHouse,
        consumption: {ResourceType.electricity: 1},
        assignedWorkers: 0,
        requiredWorkers: 0,
      );
      final graph = FlowAnalyzer.analyzeGraph(
        ProductionGraph.fromBuildings([consumer], Resources()),
      );

      final recommendations = ProductionRecommendationEngine.recommend(
        graph: graph,
        buildings: [consumer],
        resources: Resources(),
        researchManager: ResearchManager(),
        buildingLimitManager: BuildingLimitManager(),
      );

      expect(recommendations[ResourceType.electricity]!.type, RecommendationType.research);
      expect(recommendations[ResourceType.electricity]!.researchType, ResearchType.electricity);
    });

    test('recommends no producer fallback for unavailable resource', () {
      final graph = ProductionGraph(
        id: 'test',
        generatedAt: DateTime.now(),
        nodes: [
          BuildingNode(
            id: 'consumer',
            name: 'Consumer',
            type: BuildingType.house,
            category: BuildingCategory.residential,
            inputs: const [
              ResourcePort(
                resourceType: ResourceType.availableWorkers,
                ratePerSecond: 1,
                status: FlowStatus.deficit,
              ),
            ],
            outputs: const [],
            status: FlowStatus.deficit,
            hasWorkers: true,
          ),
        ],
        edges: [],
        bottlenecks: [
          BottleneckInsight(
            id: 'bottleneck_availableWorkers',
            resourceType: ResourceType.availableWorkers,
            severity: BottleneckSeverity.high,
            description: 'availableWorkers missing',
            recommendation: 'No producer available',
            impactedNodeIds: const ['consumer'],
          ),
        ],
      );

      final recommendations = ProductionRecommendationEngine.recommend(
        graph: graph,
        buildings: const [],
        resources: Resources(),
        researchManager: ResearchManager(),
        buildingLimitManager: BuildingLimitManager(),
      );

      expect(recommendations[ResourceType.availableWorkers]!.type, RecommendationType.noProducer);
    });
  });
}

Building _building({
  required BuildingType type,
  Map<ResourceType, double> generation = const {},
  Map<ResourceType, double> consumption = const {},
  int assignedWorkers = 0,
  int requiredWorkers = 1,
}) {
  return Building(
    type: type,
    name: type.name,
    description: type.name,
    icon: Icons.factory,
    color: Colors.blue,
    baseCost: 100,
    baseGeneration: generation,
    baseConsumption: consumption,
    requiredWorkers: requiredWorkers,
    category: BuildingCategory.rawMaterials,
  )..assignedWorkers = assignedWorkers;
}
```

- [ ] **Step 2: Run recommendation tests and verify they fail**

Run:

```bash
flutter test test/game/production/production_recommendation_engine_test.dart
```

Expected: FAIL because the engine does not exist.

- [ ] **Step 3: Implement recommendation models and public API**

Create `lib/game/production/production_recommendation_engine.dart`:

```dart
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/production/production_graph.dart';
import 'package:horologium/game/research/research.dart';
import 'package:horologium/game/research/research_type.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/game/resources/resources.dart';

enum RecommendationType {
  assignWorkers,
  switchRecipe,
  upgrade,
  missingUpgradeResources,
  build,
  research,
  noProducer,
}

class ProductionRecommendation {
  final RecommendationType type;
  final ResourceType resourceType;
  final String message;
  final BuildingType? targetBuildingType;
  final ResearchType? researchType;
  final Map<ResourceType, double> missingResources;

  const ProductionRecommendation({
    required this.type,
    required this.resourceType,
    required this.message,
    this.targetBuildingType,
    this.researchType,
    this.missingResources = const {},
  });
}

class ProductionRecommendationEngine {
  static Map<ResourceType, ProductionRecommendation> recommend({
    required ProductionGraph graph,
    required List<Building> buildings,
    required Resources resources,
    required ResearchManager researchManager,
    required BuildingLimitManager buildingLimitManager,
  }) {
    final result = <ResourceType, ProductionRecommendation>{};
    for (final bottleneck in graph.bottlenecks) {
      result[bottleneck.resourceType] = _recommendForResource(
        bottleneck.resourceType,
        buildings,
        resources,
        researchManager,
        buildingLimitManager,
      );
    }
    return result;
  }
}
```

- [ ] **Step 4: Implement deterministic rules**

In the same file, add private helpers:

```dart
static ProductionRecommendation _recommendForResource(
  ResourceType resourceType,
  List<Building> buildings,
  Resources resources,
  ResearchManager researchManager,
  BuildingLimitManager buildingLimitManager,
) {
  final producers = buildings
      .where((building) => building.generation.containsKey(resourceType))
      .toList();

  final idleProducer = producers.where((building) => !building.hasWorkers).firstOrNull;
  if (idleProducer != null) {
    return ProductionRecommendation(
      type: RecommendationType.assignWorkers,
      resourceType: resourceType,
      targetBuildingType: idleProducer.type,
      message: 'Assign workers to ${idleProducer.name}.',
    );
  }

  final switchRecommendation = _switchRecipeRecommendation(resourceType, buildings);
  if (switchRecommendation != null) return switchRecommendation;

  final upgradeProducer = producers.where((building) => building.canUpgrade).firstOrNull;
  if (upgradeProducer != null) {
    final missing = upgradeProducer.upgradeCost.missingResources(resources);
    if (missing.isEmpty) {
      return ProductionRecommendation(
        type: RecommendationType.upgrade,
        resourceType: resourceType,
        targetBuildingType: upgradeProducer.type,
        message: 'Upgrade ${upgradeProducer.name}.',
      );
    }
    return ProductionRecommendation(
      type: RecommendationType.missingUpgradeResources,
      resourceType: resourceType,
      targetBuildingType: upgradeProducer.type,
      missingResources: missing,
      message: 'Gather more resources to upgrade ${upgradeProducer.name}.',
    );
  }

  final producerTemplate = _producerTemplateFor(resourceType);
  if (producerTemplate == null) {
    return ProductionRecommendation(
      type: RecommendationType.noProducer,
      resourceType: resourceType,
      message: 'No producer is available for ${resourceType.name}.',
    );
  }

  final requiredResearch = _researchForBuilding(producerTemplate.type);
  if (requiredResearch != null && !researchManager.isResearched(requiredResearch)) {
    return ProductionRecommendation(
      type: RecommendationType.research,
      resourceType: resourceType,
      targetBuildingType: producerTemplate.type,
      researchType: requiredResearch,
      message: 'Research ${requiredResearch.id} to unlock ${producerTemplate.name}.',
    );
  }

  return ProductionRecommendation(
    type: RecommendationType.build,
    resourceType: resourceType,
    targetBuildingType: producerTemplate.type,
    message: 'Build a ${producerTemplate.name}.',
  );
}
```

Add dynamic helpers:

```dart
static ProductionRecommendation? _switchRecipeRecommendation(
  ResourceType resourceType,
  List<Building> buildings,
) {
  final crop = _cropFor(resourceType);
  if (crop != null) {
    final field = buildings
        .whereType<Field>()
        .where((building) => building.cropType != crop)
        .firstOrNull;
    if (field != null) {
      return ProductionRecommendation(
        type: RecommendationType.switchRecipe,
        resourceType: resourceType,
        targetBuildingType: BuildingType.field,
        message: 'Switch a Field to ${crop.name}.',
      );
    }
  }

  final kitchenProduct = _kitchenProductFor(resourceType);
  if (kitchenProduct != null) {
    final kitchen = buildings
        .whereType<Kitchen>()
        .where((building) => building.productType != kitchenProduct)
        .firstOrNull;
    if (kitchen != null) {
      return ProductionRecommendation(
        type: RecommendationType.switchRecipe,
        resourceType: resourceType,
        targetBuildingType: BuildingType.kitchen,
        message: 'Switch a Kitchen to ${kitchenProduct.name}.',
      );
    }
  }

  return null;
}
```

Add mapping helpers:

```dart
static CropType? _cropFor(ResourceType resourceType) => switch (resourceType) {
  ResourceType.wheat => CropType.wheat,
  ResourceType.corn => CropType.corn,
  ResourceType.rice => CropType.rice,
  ResourceType.barley => CropType.barley,
  _ => null,
};

static KitchenProduct? _kitchenProductFor(ResourceType resourceType) =>
    switch (resourceType) {
      ResourceType.tortillas => KitchenProduct.tortillas,
      ResourceType.riceMeals => KitchenProduct.riceMeals,
      ResourceType.maltDrink => KitchenProduct.maltDrink,
      _ => null,
    };

static Building? _producerTemplateFor(ResourceType resourceType) {
  return BuildingRegistry.availableBuildings
      .where((building) => building.generation.containsKey(resourceType))
      .firstOrNull;
}

static ResearchType? _researchForBuilding(BuildingType buildingType) {
  for (final research in Research.availableResearch) {
    if (research.unlocksBuildings.contains(buildingType)) {
      return research.type;
    }
  }
  return null;
}
```

Note: after Task 6, `upgradeCost` returns `ResourceCost`; implement this task after Task 6.

- [ ] **Step 5: Run recommendation tests and verify they pass**

Run:

```bash
flutter test test/game/production/production_recommendation_engine_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/game/production/production_recommendation_engine.dart test/game/production/production_recommendation_engine_test.dart
git commit -m "feat: add production recommendation engine"
```

---

### Task 9: Surface Recommendation Engine In Production Overlay

**Files:**
- Modify: `lib/widgets/game/production_overlay/production_overlay.dart`
- Modify: `lib/widgets/game/production_overlay/node_detail_panel.dart`
- Test: `test/widgets/game/production_overlay_test.dart`

- [ ] **Step 1: Write failing overlay recommendation test**

Append to `test/widgets/game/production_overlay_test.dart`:

```dart
testWidgets('shows recommendation engine message for selected bottleneck', (tester) async {
  final coalMine = Building(
    type: BuildingType.coalMine,
    name: 'Coal Mine',
    description: 'Produces coal',
    icon: Icons.fireplace,
    color: Colors.grey,
    baseCost: 90,
    baseGeneration: {ResourceType.coal: 1},
    requiredWorkers: 1,
    category: BuildingCategory.rawMaterials,
  );
  final powerPlant = Building(
    type: BuildingType.powerPlant,
    name: 'Power Plant',
    description: 'Uses coal',
    icon: Icons.bolt,
    color: Colors.yellow,
    baseCost: 100,
    baseConsumption: {ResourceType.coal: 1},
    baseGeneration: {ResourceType.electricity: 1},
    requiredWorkers: 1,
    category: BuildingCategory.services,
  )..assignWorker();

  await tester.pumpWidget(
    MaterialApp(
      home: ProductionOverlay(
        getBuildings: () => [coalMine, powerPlant],
        getResources: () => Resources(),
        onClose: () {},
      ),
    ),
  );

  await tester.tap(find.text('Coal Mine'));
  await tester.pumpAndSettle();

  expect(find.textContaining('Assign workers'), findsOneWidget);
});
```

- [ ] **Step 2: Run overlay recommendation test and verify it fails**

Run:

```bash
flutter test test/widgets/game/production_overlay_test.dart --plain-name "shows recommendation engine message for selected bottleneck"
```

Expected: FAIL because overlay still uses old bottleneck recommendation text.

- [ ] **Step 3: Compute recommendations in ProductionOverlay**

Import engine:

```dart
import 'package:horologium/game/production/production_recommendation_engine.dart';
```

Add state:

```dart
Map<ResourceType, ProductionRecommendation> _recommendations = {};
```

After graph analysis in `_buildGraph`, compute:

```dart
final recommendations = ProductionRecommendationEngine.recommend(
  graph: graph,
  buildings: buildings,
  resources: resources,
  researchManager: ResearchManager(),
  buildingLimitManager: BuildingLimitManager(),
);
```

Add nullable widget parameters to `ProductionOverlay` because it currently receives only building/resource callbacks:

```dart
final ResearchManager? researchManager;
final BuildingLimitManager? buildingLimitManager;
```

Use provided managers when available, and fresh empty managers as fallback for tests.

In `MainGameWidget`, pass:

```dart
researchManager: _gameStateManager.researchManager,
buildingLimitManager: _gameStateManager.buildingLimitManager,
```

- [ ] **Step 4: Display recommendation message in NodeDetailPanel**

Change `NodeDetailPanel` constructor:

```dart
final ProductionRecommendation? recommendation;
```

Where the bottleneck recommendation text is shown, prefer:

```dart
Text(
  recommendation?.message ?? bottleneck!.recommendation,
  ...
)
```

When selecting a node in overlay, choose a recommendation for the first bottleneck whose `impactedNodeIds` contains `node.id`, or whose resource appears in the node inputs/outputs.

- [ ] **Step 5: Run overlay recommendation test and verify it passes**

Run:

```bash
flutter test test/widgets/game/production_overlay_test.dart --plain-name "shows recommendation engine message for selected bottleneck"
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/game/production_overlay/production_overlay.dart lib/widgets/game/production_overlay/node_detail_panel.dart lib/game/scene_widget.dart test/widgets/game/production_overlay_test.dart
git commit -m "feat: show production recommendations in overlay"
```

---

### Task 10: Full Verification

**Files:**
- All changed files

- [ ] **Step 1: Run targeted test suites**

Run:

```bash
flutter test test/resources test/building test/planet test/services test/game/production test/widgets/game test/game/scene_widget_test.dart test/research/research_test.dart
```

Expected: PASS.

- [ ] **Step 2: Run analyzer**

Run:

```bash
flutter analyze --fatal-infos
```

Expected: PASS with no issues.

- [ ] **Step 3: Run formatting check**

Run:

```bash
dart format --output=none --set-exit-if-changed .
```

Expected: PASS with no formatting changes required.

- [ ] **Step 4: Run full test suite**

Run:

```bash
flutter test
```

Expected: PASS.

- [ ] **Step 5: Commit verification fixes if needed**

If any verification command required code changes, commit them:

```bash
git add .
git commit -m "fix: stabilize production chain expansion"
```

If no changes were needed, do not create an empty commit.

---

## Self-Review Checklist

- Spec coverage: Kitchen building, new food resources, happiness, multi-resource upgrades, direct planks/stone upgrade use, persistence, UI, recommendation engine, and tests are covered.
- Scope control: partial utilization, ghost nodes, full recipe abstraction, trade, and custom generated art remain out of scope.
- Type consistency: `ResourceCost`, `KitchenProduct`, `Kitchen`, and `ProductionRecommendationEngine` are introduced before later tasks use them.
- Test-first flow: each implementation task starts with failing tests and a command to verify failure.
