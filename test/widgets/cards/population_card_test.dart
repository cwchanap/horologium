import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/widgets/cards/population_card.dart';

void main() {
  testWidgets('PopulationCard displays values and status labels', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PopulationCard(population: 42, availableWorkers: 7),
        ),
      ),
    );

    expect(find.text('Population'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('Available Workers: 7'), findsOneWidget);
    expect(find.text('Citizens'), findsOneWidget);
    expect(find.byIcon(Icons.people), findsOneWidget);
    expect(find.byIcon(Icons.home), findsOneWidget);
  });
}
