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
