import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/resources/resource_category.dart';

void main() {
  group('ResourceCategory.displayName', () {
    test('rawMaterials returns "Raw Materials"', () {
      expect(ResourceCategory.rawMaterials.displayName, equals('Raw Materials'));
    });

    test('foodResources returns "Food Resources"', () {
      expect(
        ResourceCategory.foodResources.displayName,
        equals('Food Resources'),
      );
    });

    test('stapleGrains returns "Staple Grains"', () {
      expect(
        ResourceCategory.stapleGrains.displayName,
        equals('Staple Grains'),
      );
    });

    test('refinement returns "Refinement"', () {
      expect(ResourceCategory.refinement.displayName, equals('Refinement'));
    });

    test('all categories have non-empty displayNames', () {
      for (final category in ResourceCategory.values) {
        expect(
          category.displayName,
          isNotEmpty,
          reason: '$category displayName should not be empty',
        );
      }
    });
  });

  group('ResourceCategory.icon', () {
    test('rawMaterials returns Icons.build', () {
      expect(ResourceCategory.rawMaterials.icon, equals(Icons.build));
    });

    test('foodResources returns Icons.restaurant', () {
      expect(ResourceCategory.foodResources.icon, equals(Icons.restaurant));
    });

    test('stapleGrains returns Icons.grain', () {
      expect(ResourceCategory.stapleGrains.icon, equals(Icons.grain));
    });

    test('refinement returns Icons.bakery_dining', () {
      expect(ResourceCategory.refinement.icon, equals(Icons.bakery_dining));
    });

    test('all categories have an icon', () {
      for (final category in ResourceCategory.values) {
        expect(
          category.icon,
          isNotNull,
          reason: '$category should have a non-null icon',
        );
      }
    });

    test('all category icons are distinct', () {
      final icons = ResourceCategory.values.map((c) => c.icon).toList();
      final distinctIcons = icons.toSet();
      expect(
        distinctIcons.length,
        equals(icons.length),
        reason: 'Each category should have a unique icon',
      );
    });
  });
}
