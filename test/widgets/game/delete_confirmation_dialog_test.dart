import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/widgets/game/delete_confirmation_dialog.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/building/category.dart';

void main() {
  group('DeleteConfirmationDialog Widget Tests', () {
    late Building testBuilding;
    bool confirmPressed = false;

    setUp(() {
      testBuilding = Building(
        type: BuildingType.house,
        name: 'House',
        description: 'A basic house',
        icon: Icons.home,
        color: Colors.brown,
        baseCost: 100,
        category: BuildingCategory.residential,
        basePopulation: 4,
        requiredWorkers: 0,
      );
      confirmPressed = false;
    });

    testWidgets('displays building name and cost correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeleteConfirmationDialog(
              building: testBuilding,
              onConfirm: () => confirmPressed = true,
            ),
          ),
        ),
      );

      // Check title contains building name
      expect(find.text('Delete ${testBuilding.name}?'), findsOneWidget);
      
      // Check content mentions refund cost
      expect(find.text('This will refund ${testBuilding.cost} cash.'), findsOneWidget);
    });

    testWidgets('has Cancel and Delete buttons', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeleteConfirmationDialog(
              building: testBuilding,
              onConfirm: () => confirmPressed = true,
            ),
          ),
        ),
      );

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.byType(TextButton), findsNWidgets(2));
    });

    testWidgets('calls onConfirm when Delete button is tapped', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeleteConfirmationDialog(
              building: testBuilding,
              onConfirm: () => confirmPressed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Delete'));
      await tester.pump();

      expect(confirmPressed, isTrue);
    });

    testWidgets('does not call onConfirm when Cancel button is tapped', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeleteConfirmationDialog(
              building: testBuilding,
              onConfirm: () => confirmPressed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Cancel'));
      await tester.pump();

      expect(confirmPressed, isFalse);
    });

    testWidgets('static show method creates dialog', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => DeleteConfirmationDialog.show(
                  context: context,
                  building: testBuilding,
                  onConfirm: () => confirmPressed = true,
                ),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      // Tap button to show dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Check dialog is displayed
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Delete ${testBuilding.name}?'), findsOneWidget);
    });

    testWidgets('dialog can be dismissed by tapping outside', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => DeleteConfirmationDialog.show(
                  context: context,
                  building: testBuilding,
                  onConfirm: () => confirmPressed = true,
                ),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      // Show dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);

      // Tap outside dialog (on barrier)
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(confirmPressed, isFalse);
    });
  });
}