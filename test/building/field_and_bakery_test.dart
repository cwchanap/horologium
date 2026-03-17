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
        final bakery = _makeBakery(productType: BakeryProduct.pastries, level: 3);
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
}
