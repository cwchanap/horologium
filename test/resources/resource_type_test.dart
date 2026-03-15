import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/resources/resource_category.dart';
import 'package:horologium/game/resources/resource_type.dart';

void main() {
  group('ResourceRegistry', () {
    group('find', () {
      test('returns resource for known type', () {
        final resource = ResourceRegistry.find(ResourceType.gold);
        expect(resource, isNotNull);
        expect(resource!.type, equals(ResourceType.gold));
      });

      test('returns correct name for each registered resource', () {
        final expectations = {
          ResourceType.gold: 'Gold',
          ResourceType.wood: 'Wood',
          ResourceType.coal: 'Coal',
          ResourceType.electricity: 'Electricity',
          ResourceType.research: 'Research',
          ResourceType.water: 'Water',
          ResourceType.planks: 'Planks',
          ResourceType.stone: 'Stone',
          ResourceType.wheat: 'Wheat',
          ResourceType.corn: 'Corn',
          ResourceType.rice: 'Rice',
          ResourceType.barley: 'Barley',
          ResourceType.flour: 'Flour',
          ResourceType.cornmeal: 'Cornmeal',
          ResourceType.polishedRice: 'Polished Rice',
          ResourceType.maltedBarley: 'Malted Barley',
          ResourceType.bread: 'Bread',
          ResourceType.pastries: 'Pastries',
        };
        for (final entry in expectations.entries) {
          final resource = ResourceRegistry.find(entry.key);
          expect(
            resource?.name,
            equals(entry.value),
            reason: 'Expected ${entry.key} to have name "${entry.value}"',
          );
        }
      });

      test('returns null for types not in the registry (cash, population)', () {
        // cash, population, and availableWorkers are not in ResourceRegistry
        expect(ResourceRegistry.find(ResourceType.cash), isNull);
        expect(ResourceRegistry.find(ResourceType.population), isNull);
        expect(ResourceRegistry.find(ResourceType.availableWorkers), isNull);
      });

      test('returns resources with positive values', () {
        for (final resource in ResourceRegistry.availableResources) {
          expect(
            resource.value,
            greaterThan(0),
            reason: '${resource.type} should have a positive value',
          );
        }
      });

      test('all registered resources have non-empty names', () {
        for (final resource in ResourceRegistry.availableResources) {
          expect(
            resource.name,
            isNotEmpty,
            reason: '${resource.type} has empty name',
          );
        }
      });
    });

    group('categories', () {
      test('food resources have foodResources category', () {
        final foodTypes = [
          ResourceType.wheat,
          ResourceType.corn,
          ResourceType.rice,
          ResourceType.barley,
        ];
        for (final type in foodTypes) {
          final resource = ResourceRegistry.find(type);
          expect(
            resource?.category,
            equals(ResourceCategory.foodResources),
            reason: '$type should be in foodResources category',
          );
        }
      });

      test('processed grains have stapleGrains category', () {
        final grainTypes = [
          ResourceType.flour,
          ResourceType.cornmeal,
          ResourceType.polishedRice,
          ResourceType.maltedBarley,
        ];
        for (final type in grainTypes) {
          final resource = ResourceRegistry.find(type);
          expect(
            resource?.category,
            equals(ResourceCategory.stapleGrains),
            reason: '$type should be in stapleGrains category',
          );
        }
      });

      test('refined products have refinement category', () {
        final refinedTypes = [ResourceType.bread, ResourceType.pastries];
        for (final type in refinedTypes) {
          final resource = ResourceRegistry.find(type);
          expect(
            resource?.category,
            equals(ResourceCategory.refinement),
            reason: '$type should be in refinement category',
          );
        }
      });

      test('raw materials have rawMaterials category', () {
        final rawTypes = [
          ResourceType.gold,
          ResourceType.wood,
          ResourceType.coal,
          ResourceType.electricity,
          ResourceType.research,
          ResourceType.water,
          ResourceType.planks,
          ResourceType.stone,
        ];
        for (final type in rawTypes) {
          final resource = ResourceRegistry.find(type);
          expect(
            resource?.category,
            equals(ResourceCategory.rawMaterials),
            reason: '$type should be in rawMaterials category',
          );
        }
      });
    });

    group('value ordering', () {
      test('bread has higher value than flour', () {
        final bread = ResourceRegistry.find(ResourceType.bread);
        final flour = ResourceRegistry.find(ResourceType.flour);
        expect(bread!.value, greaterThan(flour!.value));
      });

      test('pastries have higher value than bread', () {
        final pastries = ResourceRegistry.find(ResourceType.pastries);
        final bread = ResourceRegistry.find(ResourceType.bread);
        expect(pastries!.value, greaterThan(bread!.value));
      });

      test('planks have higher value than raw wood-adjacent resources', () {
        final planks = ResourceRegistry.find(ResourceType.planks);
        final coal = ResourceRegistry.find(ResourceType.coal);
        expect(planks!.value, greaterThan(coal!.value));
      });
    });
  });

  group('ResourceCategory extension', () {
    group('displayName', () {
      test('rawMaterials displays as Raw Materials', () {
        expect(
          ResourceCategory.rawMaterials.displayName,
          equals('Raw Materials'),
        );
      });

      test('foodResources displays as Food Resources', () {
        expect(
          ResourceCategory.foodResources.displayName,
          equals('Food Resources'),
        );
      });

      test('stapleGrains displays as Staple Grains', () {
        expect(
          ResourceCategory.stapleGrains.displayName,
          equals('Staple Grains'),
        );
      });

      test('refinement displays as Refinement', () {
        expect(ResourceCategory.refinement.displayName, equals('Refinement'));
      });

      test('all categories have non-empty display names', () {
        for (final category in ResourceCategory.values) {
          expect(
            category.displayName,
            isNotEmpty,
            reason: '$category has empty displayName',
          );
        }
      });
    });

    group('icon', () {
      test('each category has an icon', () {
        for (final category in ResourceCategory.values) {
          // Just verify the icon getter doesn't throw and returns an IconData
          expect(category.icon, isA<IconData>());
        }
      });

      test('rawMaterials uses build icon', () {
        expect(ResourceCategory.rawMaterials.icon, equals(Icons.build));
      });

      test('foodResources uses restaurant icon', () {
        expect(ResourceCategory.foodResources.icon, equals(Icons.restaurant));
      });

      test('stapleGrains uses grain icon', () {
        expect(ResourceCategory.stapleGrains.icon, equals(Icons.grain));
      });

      test('refinement uses bakery_dining icon', () {
        expect(ResourceCategory.refinement.icon, equals(Icons.bakery_dining));
      });
    });
  });

  group('BakeryProduct enum', () {
    test('has bread and pastries variants', () {
      expect(BakeryProduct.values, contains(BakeryProduct.bread));
      expect(BakeryProduct.values, contains(BakeryProduct.pastries));
    });

    test('contains all expected variants', () {
      expect(
        BakeryProduct.values,
        containsAll([BakeryProduct.bread, BakeryProduct.pastries]),
      );
    });
  });

  group('CropType enum', () {
    test('has wheat, corn, rice, and barley variants', () {
      expect(CropType.values, contains(CropType.wheat));
      expect(CropType.values, contains(CropType.corn));
      expect(CropType.values, contains(CropType.rice));
      expect(CropType.values, contains(CropType.barley));
    });

    test('contains all expected variants', () {
      expect(
        CropType.values,
        containsAll([
          CropType.wheat,
          CropType.corn,
          CropType.rice,
          CropType.barley,
        ]),
      );
    });
  });
}
