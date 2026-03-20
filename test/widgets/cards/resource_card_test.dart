import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/widgets/cards/resource_card.dart';

void main() {
  test('ResourceCard requires either an icon or a resourceType', () {
    expect(
      () => ResourceCard(name: 'Cash', amount: 10, color: Colors.green),
      throwsAssertionError,
    );
  });

  testWidgets('renders icon branch and negative trend badge', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ResourceCard(
            name: 'Cash',
            amount: 12.3,
            color: Colors.green,
            icon: Icons.attach_money,
            productionRate: 1.0,
            consumptionRate: 2.5,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.attach_money), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('12.3'), findsOneWidget);
    expect(find.byIcon(Icons.trending_down), findsOneWidget);
    expect(find.text('-1.5/s'), findsOneWidget);
    expect(find.text('Production'), findsOneWidget);
    expect(find.text('Consumption'), findsOneWidget);
  });

  testWidgets('renders resourceType branch and research-specific formatting', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ResourceCard(
            name: 'Research',
            amount: 12.7,
            color: Colors.purple,
            resourceType: ResourceType.research,
            productionRate: 0.5,
            consumptionRate: 0.1,
          ),
        ),
      ),
    );

    expect(find.text('Research'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('+4.0/s'), findsOneWidget);
    expect(find.text('5.0/s'), findsOneWidget);
    expect(find.text('0.1/s'), findsOneWidget);
    expect(find.byType(ResourceCard), findsOneWidget);
  });

  testWidgets('hides the trend badge when net rate is zero', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ResourceCard(
            name: 'Water',
            amount: 3,
            color: Colors.cyan,
            icon: Icons.water_drop,
            productionRate: 1,
            consumptionRate: 1,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.trending_up), findsNothing);
    expect(find.byIcon(Icons.trending_down), findsNothing);
  });
}
