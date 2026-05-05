import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/building/category.dart';
import 'package:horologium/game/resources/resource_type.dart';

Field _makeField({CropType cropType = CropType.wheat, int level = 1}) {
  return Field(
    type: BuildingType.field,
    name: 'Field',
    description: 'Grows crops',
    icon: Icons.grass,
    color: Colors.lightGreen,
    baseCost: 50,
    requiredWorkers: 1,
    category: BuildingCategory.foodResources,
    cropType: cropType,
    level: level,
  );
}

Bakery _makeBakery({
  BakeryProduct productType = BakeryProduct.bread,
  int level = 1,
}) {
  return Bakery(
    type: BuildingType.bakery,
    name: 'Bakery',
    description: 'Bakes goods',
    icon: Icons.bakery_dining,
    color: Colors.orange,
    baseCost: 150,
    requiredWorkers: 1,
    category: BuildingCategory.refinement,
    productType: productType,
    level: level,
  );
}

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

void main() {
  group('Field building', () {
    group('generation by crop type', () {
      test('generates wheat for CropType.wheat', () {
        final field = _makeField(cropType: CropType.wheat);
        expect(field.generation[ResourceType.wheat], equals(1.0));
        expect(field.generation.length, equals(1));
      });

      test('generates corn for CropType.corn', () {
        final field = _makeField(cropType: CropType.corn);
        expect(field.generation[ResourceType.corn], equals(1.0));
        expect(field.generation.containsKey(ResourceType.wheat), isFalse);
      });

      test('generates rice for CropType.rice', () {
        final field = _makeField(cropType: CropType.rice);
        expect(field.generation[ResourceType.rice], equals(1.0));
      });

      test('generates barley for CropType.barley', () {
        final field = _makeField(cropType: CropType.barley);
        expect(field.generation[ResourceType.barley], equals(1.0));
      });
    });

    group('generation scales with level', () {
      test('wheat output doubles at level 2', () {
        final field = _makeField(cropType: CropType.wheat, level: 2);
        expect(field.generation[ResourceType.wheat], equals(2.0));
      });

      test('corn output at level 3', () {
        final field = _makeField(cropType: CropType.corn, level: 3);
        expect(field.generation[ResourceType.corn], equals(3.0));
      });
    });

    group('crop type is mutable', () {
      test('changing cropType changes output resource', () {
        final field = _makeField(cropType: CropType.wheat);
        expect(field.generation[ResourceType.wheat], equals(1.0));

        field.cropType = CropType.rice;
        expect(field.generation[ResourceType.rice], equals(1.0));
        expect(field.generation.containsKey(ResourceType.wheat), isFalse);
      });
    });

    group('default crop type', () {
      test('defaults to wheat when no cropType specified', () {
        final field = Field(
          type: BuildingType.field,
          name: 'Field',
          description: 'Grows crops',
          icon: Icons.grass,
          color: Colors.lightGreen,
          baseCost: 50,
          requiredWorkers: 1,
          category: BuildingCategory.foodResources,
        );
        expect(field.cropType, equals(CropType.wheat));
        expect(field.generation[ResourceType.wheat], equals(1.0));
      });
    });
  });

  group('Bakery building', () {
    group('generation by product type', () {
      test('generates bread for BakeryProduct.bread', () {
        final bakery = _makeBakery(productType: BakeryProduct.bread);
        expect(bakery.generation[ResourceType.bread], equals(1.0));
        expect(bakery.generation.length, equals(1));
      });

      test('generates pastries for BakeryProduct.pastries', () {
        final bakery = _makeBakery(productType: BakeryProduct.pastries);
        expect(bakery.generation[ResourceType.pastries], equals(1.0));
        expect(bakery.generation.containsKey(ResourceType.bread), isFalse);
      });
    });

    group('consumption by product type', () {
      test('consumes flour for bread (2 flour per level)', () {
        final bakery = _makeBakery(productType: BakeryProduct.bread);
        expect(bakery.consumption[ResourceType.flour], equals(2.0));
      });

      test('consumes more flour for pastries (3 flour per level)', () {
        final bakery = _makeBakery(productType: BakeryProduct.pastries);
        expect(bakery.consumption[ResourceType.flour], equals(3.0));
      });
    });

    group('scales with level', () {
      test('bread generation doubles at level 2', () {
        final bakery = _makeBakery(productType: BakeryProduct.bread, level: 2);
        expect(bakery.generation[ResourceType.bread], equals(2.0));
        expect(bakery.consumption[ResourceType.flour], equals(4.0));
      });

      test('pastries generation at level 3', () {
        final bakery = _makeBakery(
          productType: BakeryProduct.pastries,
          level: 3,
        );
        expect(bakery.generation[ResourceType.pastries], equals(3.0));
        expect(bakery.consumption[ResourceType.flour], equals(9.0));
      });
    });

    group('product type is mutable', () {
      test('switching productType changes generation and consumption', () {
        final bakery = _makeBakery(productType: BakeryProduct.bread);
        expect(bakery.generation[ResourceType.bread], equals(1.0));
        expect(bakery.consumption[ResourceType.flour], equals(2.0));

        bakery.productType = BakeryProduct.pastries;
        expect(bakery.generation[ResourceType.pastries], equals(1.0));
        expect(bakery.consumption[ResourceType.flour], equals(3.0));
        expect(bakery.generation.containsKey(ResourceType.bread), isFalse);
      });
    });

    group('default product type', () {
      test('defaults to bread when no productType specified', () {
        final bakery = Bakery(
          type: BuildingType.bakery,
          name: 'Bakery',
          description: 'Bakes goods',
          icon: Icons.bakery_dining,
          color: Colors.orange,
          baseCost: 150,
          requiredWorkers: 1,
          category: BuildingCategory.refinement,
        );
        expect(bakery.productType, equals(BakeryProduct.bread));
        expect(bakery.generation[ResourceType.bread], equals(1.0));
      });
    });
  });

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

  group('copyForPlacement isolation', () {
    test('resets assignedWorkers to zero for base Building', () {
      final building = Building(
        type: BuildingType.powerPlant,
        name: 'Power Plant',
        description: 'Test',
        icon: Icons.bolt,
        color: Colors.yellow,
        baseCost: 100,
        requiredWorkers: 1,
        category: BuildingCategory.rawMaterials,
      )..assignWorker();

      expect(building.assignedWorkers, equals(1));

      final copy = building.copyForPlacement();
      expect(copy.assignedWorkers, equals(0));
      expect(copy.id, isNot(equals(building.id)));
      expect(copy.type, equals(building.type));
    });

    test('resets assignedWorkers to zero for Field', () {
      final field = _makeField(cropType: CropType.corn)..assignWorker();

      expect(field.assignedWorkers, equals(1));

      final copy = field.copyForPlacement();
      expect(copy.assignedWorkers, equals(0));
      expect(copy.cropType, equals(CropType.corn));
    });

    test('resets assignedWorkers to zero for Kitchen', () {
      final kitchen = _makeKitchen(productType: KitchenProduct.riceMeals)
        ..assignWorker();

      expect(kitchen.assignedWorkers, equals(1));

      final copy = kitchen.copyForPlacement();
      expect(copy.assignedWorkers, equals(0));
      expect(copy.productType, equals(KitchenProduct.riceMeals));
    });

    test('does not share mutable generation map with template', () {
      final building = Building(
        type: BuildingType.powerPlant,
        name: 'Power Plant',
        description: 'Test',
        icon: Icons.bolt,
        color: Colors.yellow,
        baseCost: 100,
        baseGeneration: {ResourceType.electricity: 1},
        requiredWorkers: 1,
        category: BuildingCategory.rawMaterials,
      );

      final copy = building.copyForPlacement();

      // Mutating the copy's generation should not affect the template
      copy.baseGeneration[ResourceType.electricity] = 99;
      expect(building.baseGeneration[ResourceType.electricity], equals(1));
    });
  });
}
