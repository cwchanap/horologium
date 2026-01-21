import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/widgets/game/resource_display.dart';
import 'package:horologium/game/resources/resources.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/building/category.dart';

void main() {
  group('ResourceDisplay Widget Tests', () {
    late Resources testResources;

    setUp(() {
      testResources = Resources();
      testResources.cash = 1500.0;
      testResources.research = 25.0;
      testResources.population = 100;
      testResources.availableWorkers = 50;
    });

    testWidgets('displays all resource values correctly', (
      WidgetTester tester,
    ) async {
      testResources.happiness = 75.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ResourceDisplay(resources: testResources)),
        ),
      );

      // Check that all resource values are displayed
      expect(find.text('1500'), findsOneWidget); // Cash
      expect(find.text('25'), findsOneWidget); // Research
      expect(find.text('75%'), findsOneWidget); // Happiness
      expect(find.text('100'), findsOneWidget); // Population
      // Note: availableWorkers = 50, but happiness also shows 50 by default if not set

      // Check that icons are present
      expect(find.byIcon(Icons.attach_money), findsOneWidget);
      expect(find.byIcon(Icons.science), findsOneWidget);
      expect(
        find.byIcon(Icons.sentiment_very_satisfied),
        findsOneWidget,
      ); // Happiness icon
      expect(find.byIcon(Icons.people), findsOneWidget);
      expect(find.byIcon(Icons.work), findsOneWidget);
    });

    testWidgets('displays zero values correctly', (WidgetTester tester) async {
      testResources.cash = 0.0;
      testResources.research = 0.0;
      testResources.population = 0;
      testResources.availableWorkers = 0;
      testResources.happiness = 0.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ResourceDisplay(resources: testResources)),
        ),
      );

      // Cash, research, population, workers show 0; happiness shows 0%
      expect(find.text('0'), findsNWidgets(4));
      expect(find.text('0%'), findsOneWidget);
    });

    testWidgets('displays large numbers correctly', (
      WidgetTester tester,
    ) async {
      testResources.cash = 999999.0;
      testResources.research = 1000.0;
      testResources.population = 5000;
      testResources.availableWorkers = 2500;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ResourceDisplay(resources: testResources)),
        ),
      );

      expect(find.text('999999'), findsOneWidget);
      expect(find.text('1000'), findsOneWidget);
      expect(find.text('5000'), findsOneWidget);
      expect(find.text('2500'), findsOneWidget);
    });

    testWidgets('has correct styling and layout', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ResourceDisplay(resources: testResources)),
        ),
      );

      // Check container decoration
      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.decoration, isA<BoxDecoration>());

      // Check that the widget uses Column layout
      expect(find.byType(Column), findsOneWidget);

      // Check that there are Row widgets for each resource
      // (cash, research, happiness, population, workers)
      expect(find.byType(Row), findsNWidgets(5));
    });

    testWidgets('workers display is indented correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ResourceDisplay(resources: testResources)),
        ),
      );

      // Find all SizedBox widgets and check for the indentation
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      final indentationBoxes = sizedBoxes.where((box) => box.width == 16);
      expect(indentationBoxes.length, greaterThan(0));
    });

    testWidgets('shows growth indicator with spare housing and high happiness', (
      WidgetTester tester,
    ) async {
      testResources.population = 10;
      testResources.happiness = 70.0; // Above high threshold (60)

      // Create houses with total accommodation greater than population
      // Each house accommodates 2 people, so we need at least 6 houses to have spare capacity
      final List<Building> houses = List.generate(
        6,
        (_) => Building(
          type: BuildingType.house,
          name: 'House',
          description: 'Provides housing',
          icon: Icons.home,
          assetPath: 'assets/images/building/house.png',
          color: Colors.blue,
          baseCost: 100,
          baseGeneration: {},
          baseConsumption: {},
          basePopulation: 2, // Each house accommodates 2 people
          requiredWorkers: 0,
          category: BuildingCategory.residential,
        ),
      );
      // Total accommodation = 6 houses * 2 people/house = 12 > population (10)

      // Update resources to set totalAccommodation
      testResources.update(houses);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ResourceDisplay(resources: testResources)),
        ),
      );

      // Should show growth arrow
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward), findsNothing);
    });

    testWidgets('does NOT show growth indicator when housing is exactly full', (
      WidgetTester tester,
    ) async {
      testResources.population = 10;
      testResources.happiness = 70.0; // Above high threshold (60)

      // Create a house with accommodation capacity equal to population
      final house = Building(
        type: BuildingType.largeHouse,
        name: 'Large House',
        description: 'Provides more housing',
        icon: Icons.home,
        assetPath: 'assets/images/building/large_house.png',
        color: Colors.blue,
        baseCost: 200,
        baseGeneration: {},
        baseConsumption: {},
        basePopulation: 10, // Set basePopulation to match population exactly
        requiredWorkers: 0,
        category: BuildingCategory.residential,
      );

      // Update resources to set totalAccommodation
      testResources.update([house]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ResourceDisplay(resources: testResources)),
        ),
      );

      // Should NOT show growth arrow (housing exactly full)
      expect(find.byIcon(Icons.arrow_upward), findsNothing);
      expect(find.byIcon(Icons.remove), findsOneWidget); // Stable
      expect(find.byIcon(Icons.arrow_downward), findsNothing);
    });

    testWidgets('does NOT show growth indicator with unsheltered population', (
      WidgetTester tester,
    ) async {
      testResources.population = 20;
      testResources.happiness = 70.0; // Above high threshold (60)

      // No houses at all, so unsheltered population > 0
      testResources.update([]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ResourceDisplay(resources: testResources)),
        ),
      );

      // Should NOT show growth arrow (no housing capacity)
      expect(find.byIcon(Icons.arrow_upward), findsNothing);
      expect(find.byIcon(Icons.remove), findsOneWidget); // Stable
      expect(find.byIcon(Icons.arrow_downward), findsNothing);
    });

    testWidgets('shows shrink indicator with low happiness', (
      WidgetTester tester,
    ) async {
      testResources.population = 10;
      testResources.happiness = 25.0; // Below low threshold (30)

      // Has spare housing but low happiness
      final house = Building(
        type: BuildingType.house,
        name: 'House',
        description: 'Provides housing',
        icon: Icons.home,
        assetPath: 'assets/images/building/house.png',
        color: Colors.blue,
        baseCost: 100,
        baseGeneration: {},
        baseConsumption: {},
        requiredWorkers: 0,
        category: BuildingCategory.residential,
      );

      testResources.update([house]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ResourceDisplay(resources: testResources)),
        ),
      );

      // Should show shrink arrow due to low happiness
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsNothing);
    });

    testWidgets('shows stable indicator with medium happiness', (
      WidgetTester tester,
    ) async {
      testResources.population = 10;
      testResources.happiness = 50.0; // Between low (30) and high (60)

      // Has spare housing but medium happiness
      final house = Building(
        type: BuildingType.house,
        name: 'House',
        description: 'Provides housing',
        icon: Icons.home,
        assetPath: 'assets/images/building/house.png',
        color: Colors.blue,
        baseCost: 100,
        baseGeneration: {},
        baseConsumption: {},
        requiredWorkers: 0,
        category: BuildingCategory.residential,
      );

      testResources.update([house]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ResourceDisplay(resources: testResources)),
        ),
      );

      // Should show stable indicator
      expect(find.byIcon(Icons.remove), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsNothing);
      expect(find.byIcon(Icons.arrow_downward), findsNothing);
    });
  });
}
