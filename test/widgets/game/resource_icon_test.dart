import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/constants/assets_path.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/widgets/game/resource_icon.dart';

void main() {
  final assetPaths = <ResourceType, String>{
    ResourceType.gold: Assets.goldIcon,
    ResourceType.wood: Assets.woodIcon,
    ResourceType.coal: Assets.coalIcon,
    ResourceType.electricity: Assets.electricityIcon,
    ResourceType.research: Assets.researchIcon,
    ResourceType.water: Assets.waterIcon,
    ResourceType.planks: Assets.planksIcon,
    ResourceType.stone: Assets.stoneIcon,
    ResourceType.wheat: Assets.wheatIcon,
    ResourceType.corn: Assets.cornIcon,
    ResourceType.rice: Assets.riceIcon,
    ResourceType.barley: Assets.barleyIcon,
    ResourceType.flour: Assets.flourIcon,
    ResourceType.cornmeal: Assets.cornmealIcon,
    ResourceType.polishedRice: Assets.polishedRiceIcon,
    ResourceType.maltedBarley: Assets.maltedBarleyIcon,
    ResourceType.bread: Assets.breadIcon,
    ResourceType.pastries: Assets.pastriesIcon,
  };

  final fallbackIcons = <ResourceType, IconData>{
    ResourceType.cash: Icons.attach_money,
    ResourceType.population: Icons.people,
    ResourceType.availableWorkers: Icons.work,
    ResourceType.gold: Icons.star,
    ResourceType.wood: Icons.park,
    ResourceType.coal: Icons.fireplace,
    ResourceType.electricity: Icons.bolt,
    ResourceType.research: Icons.science,
    ResourceType.water: Icons.water_drop,
    ResourceType.planks: Icons.construction,
    ResourceType.stone: Icons.terrain,
    ResourceType.wheat: Icons.grass,
    ResourceType.corn: Icons.eco,
    ResourceType.rice: Icons.grain,
    ResourceType.barley: Icons.agriculture,
    ResourceType.flour: Icons.grain,
    ResourceType.cornmeal: Icons.grain,
    ResourceType.polishedRice: Icons.grain,
    ResourceType.maltedBarley: Icons.grain,
    ResourceType.bread: Icons.bakery_dining,
    ResourceType.pastries: Icons.bakery_dining,
  };

  final fallbackColors = <ResourceType, Color>{
    ResourceType.cash: Colors.green,
    ResourceType.population: Colors.blue,
    ResourceType.availableWorkers: Colors.orange,
    ResourceType.gold: Colors.amber,
    ResourceType.wood: Colors.brown,
    ResourceType.coal: Colors.grey,
    ResourceType.electricity: Colors.yellow,
    ResourceType.research: Colors.purple,
    ResourceType.water: Colors.cyan,
    ResourceType.planks: Colors.brown,
    ResourceType.stone: Colors.grey,
    ResourceType.wheat: Colors.lightGreen,
    ResourceType.corn: Colors.orange,
    ResourceType.rice: Colors.green,
    ResourceType.barley: Colors.brown,
    ResourceType.flour: Colors.orange,
    ResourceType.cornmeal: Colors.yellow,
    ResourceType.polishedRice: Colors.lightGreen,
    ResourceType.maltedBarley: Colors.amber,
    ResourceType.bread: Colors.orange,
    ResourceType.pastries: Colors.orange,
  };

  testWidgets('uses fallback icons for non-asset resources', (
    WidgetTester tester,
  ) async {
    for (final resourceType in const [
      ResourceType.cash,
      ResourceType.population,
      ResourceType.availableWorkers,
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ResourceIcon(resourceType: resourceType)),
        ),
      );

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, equals(fallbackIcons[resourceType]));
      expect(icon.color, equals(fallbackColors[resourceType]));
    }
  });

  testWidgets('uses asset images for supported resources', (
    WidgetTester tester,
  ) async {
    for (final entry in assetPaths.entries) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ResourceIcon(resourceType: entry.key)),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      final provider = image.image;
      expect(provider, isA<AssetImage>());
      expect(
        (provider as AssetImage).assetName,
        equals('assets/images/${entry.value}'),
      );
      expect(image.width, equals(24));
      expect(image.height, equals(24));
    }
  });

  testWidgets('supports overriding the fallback color', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ResourceIcon(
            resourceType: ResourceType.cash,
            fallbackColor: Colors.red,
          ),
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.icon, equals(Icons.attach_money));
    expect(icon.color, equals(Colors.red));
  });

  testWidgets('errorBuilder falls back to the expected icon and color', (
    WidgetTester tester,
  ) async {
    for (final resourceType in assetPaths.keys) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ResourceIcon(resourceType: resourceType)),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      final context = tester.element(find.byType(Image));
      final fallback = image.errorBuilder!(
        context,
        StateError('missing'),
        StackTrace.current,
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: fallback)));

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, equals(fallbackIcons[resourceType]));
      expect(icon.color, equals(fallbackColors[resourceType]));
    }
  });
}
