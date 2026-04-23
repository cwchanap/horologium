import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/resources/resources.dart';
import 'package:horologium/pages/trade_page.dart';

void main() {
  group('TradePage', () {
    late Resources resources;

    setUp(() {
      resources = Resources();
    });

    Future<void> pumpTradePage(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: TradePage(resources: resources)),
      );
      await tester.pumpAndSettle();
    }

    Finder resourceRow(String resourceName) {
      return find
          .ancestor(of: find.text(resourceName), matching: find.byType(Row))
          .first;
    }

    Finder actionButtonFor(String resourceName, String actionLabel) {
      return find.descendant(
        of: resourceRow(resourceName),
        matching: find.widgetWithText(ElevatedButton, actionLabel),
      );
    }

    testWidgets('research is not listed in the market', (tester) async {
      resources.research = 99;

      await pumpTradePage(tester);

      expect(find.text('Research'), findsNothing);
      expect(find.text('Gold'), findsOneWidget);
      expect(find.text('Wood'), findsOneWidget);
      expect(find.text('Coal'), findsOneWidget);
    });

    testWidgets('invalid buy input shows a validation snackbar', (
      tester,
    ) async {
      await pumpTradePage(tester);

      await tester.tap(actionButtonFor('Gold', 'BUY'));
      await tester.pumpAndSettle();

      expect(find.text('Buy Gold'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '-5');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Buy'));
      await tester.pump();

      expect(find.text('Please enter a valid positive number'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(resources.cash, 1000);
      expect(resources.gold, 0);
    });

    testWidgets(
      'successful sell updates resources and shows a success snackbar',
      (tester) async {
        resources.cash = 100;
        resources.wood = 20;

        await pumpTradePage(tester);

        await tester.tap(actionButtonFor('Wood', 'SELL'));
        await tester.pumpAndSettle();

        expect(find.text('Sell Wood'), findsOneWidget);

        await tester.enterText(find.byType(TextField), '5');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Sell'));
        await tester.pumpAndSettle();

        expect(
          find.text('Sale successful! Sold 5.0 Wood for 40.0 cash'),
          findsOneWidget,
        );
        expect(resources.cash, 140);
        expect(resources.wood, 15);
        expect(
          find.descendant(of: resourceRow('Wood'), matching: find.text('15.0')),
          findsOneWidget,
        );
      },
    );

    testWidgets('buy dialog cancel closes without changing resources', (
      tester,
    ) async {
      await pumpTradePage(tester);

      await tester.tap(actionButtonFor('Gold', 'BUY'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(resources.cash, 1000);
      expect(resources.gold, 0);
    });

    testWidgets('buy with insufficient cash shows an error snackbar', (
      tester,
    ) async {
      resources.cash = 5;

      await pumpTradePage(tester);

      await tester.tap(actionButtonFor('Gold', 'BUY'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '1');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Buy'));
      await tester.pumpAndSettle();

      expect(find.text('Not enough cash for this purchase!'), findsOneWidget);
      expect(resources.cash, 5);
      expect(resources.gold, 0);
    });

    testWidgets('sell dialog cancel closes without changing resources', (
      tester,
    ) async {
      resources.wood = 4;

      await pumpTradePage(tester);

      await tester.tap(actionButtonFor('Wood', 'SELL'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(resources.wood, 4);
    });

    testWidgets('selling more than available shows a detailed error', (
      tester,
    ) async {
      resources.wood = 3;

      await pumpTradePage(tester);

      await tester.tap(actionButtonFor('Wood', 'SELL'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '5');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sell'));
      await tester.pumpAndSettle();

      expect(
        find.text('Not enough Wood! You have 3.0 but need 5.0'),
        findsOneWidget,
      );
      expect(resources.wood, 3);
    });
  });
}
