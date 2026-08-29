import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/presentation/mining_hud.dart';

void main() {
  testWidgets('cash chip keeps the prototype one-sided trapezoid and alpha', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Align(child: MiningCashChip(cash: 412))),
    );

    final container = tester.widget<Container>(
      find.byKey(const Key('mining-cash-chip')),
    );
    final decoration = container.decoration! as ShapeDecoration;
    final rect = tester.getRect(find.byKey(const Key('mining-cash-chip')));
    final path = decoration.shape.getOuterPath(
      Rect.fromLTWH(0, 0, rect.width, rect.height),
    );

    expect(decoration.color, const Color.fromRGBO(255, 213, 74, .16));
    expect(path.contains(Offset(rect.width - 2, 2)), isTrue);
    expect(path.contains(Offset(rect.width - 2, rect.height - 2)), isFalse);
    expect(path.contains(Offset(2, rect.height - 2)), isTrue);
  });

  testWidgets('cargo gauge uses the prototype ring width and colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: MiningCargoGauge(
            cargo: 143,
            capacity: 207,
            projectedValue: 572,
            size: 80,
          ),
        ),
      ),
    );

    final indicator = tester.widget<CircularProgressIndicator>(
      find.descendant(
        of: find.byKey(const Key('mining-cargo-gauge')),
        matching: find.byType(CircularProgressIndicator),
      ),
    );
    expect(indicator.strokeWidth, 5);
    expect(indicator.color, const Color(0xFF53D4E8));
    expect(indicator.backgroundColor, const Color.fromRGBO(255, 255, 255, .13));
  });

  testWidgets('landscape cash chip uses the compact prototype metrics', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Align(child: MiningCashChip(cash: 412, compact: true)),
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('mining-cash-chip'))).height,
      39,
    );
  });
}
