import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/widgets/game/resource_display.dart';
import 'package:horologium/game/resources/resources.dart';

void main() {
  group('ResourceDisplay Widget Tests', () {
    late Resources testResources;

    setUp(() {
      testResources = Resources();
      testResources.money = 1500.0;
      testResources.research = 25.0;
      testResources.population = 100;
      testResources.availableWorkers = 50;
    });

    testWidgets('displays all resource values correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResourceDisplay(resources: testResources),
          ),
        ),
      );

      // Check that all resource values are displayed
      expect(find.text('1500'), findsOneWidget); // Money
      expect(find.text('25'), findsOneWidget); // Research
      expect(find.text('100'), findsOneWidget); // Population
      expect(find.text('50'), findsOneWidget); // Available workers

      // Check that icons are present
      expect(find.byIcon(Icons.attach_money), findsOneWidget);
      expect(find.byIcon(Icons.science), findsOneWidget);
      expect(find.byIcon(Icons.people), findsOneWidget);
      expect(find.byIcon(Icons.work), findsOneWidget);
    });

    testWidgets('displays zero values correctly', (WidgetTester tester) async {
      testResources.money = 0.0;
      testResources.research = 0.0;
      testResources.population = 0;
      testResources.availableWorkers = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResourceDisplay(resources: testResources),
          ),
        ),
      );

      expect(find.text('0'), findsNWidgets(4)); // All resources should show 0
    });

    testWidgets('displays large numbers correctly', (WidgetTester tester) async {
      testResources.money = 999999.0;
      testResources.research = 1000.0;
      testResources.population = 5000;
      testResources.availableWorkers = 2500;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResourceDisplay(resources: testResources),
          ),
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
          home: Scaffold(
            body: ResourceDisplay(resources: testResources),
          ),
        ),
      );

      // Check container decoration
      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.decoration, isA<BoxDecoration>());
      
      // Check that the widget uses Column layout
      expect(find.byType(Column), findsOneWidget);
      
      // Check that there are Row widgets for each resource
      expect(find.byType(Row), findsNWidgets(4));
    });

    testWidgets('workers display is indented correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResourceDisplay(resources: testResources),
          ),
        ),
      );

      // Find all SizedBox widgets and check for the indentation
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      final indentationBoxes = sizedBoxes.where((box) => box.width == 16);
      expect(indentationBoxes.length, greaterThan(0));
    });
  });
}