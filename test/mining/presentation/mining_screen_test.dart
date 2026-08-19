import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_save_repository.dart';
import 'package:horologium/mining/presentation/mining_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DelayedMiningSaveRepository extends MiningSaveRepository {
  final saveStarted = Completer<void>();
  final allowSave = Completer<void>();

  @override
  Future<void> save(state) async {
    if (!saveStarted.isCompleted) {
      saveStarted.complete();
      await allowSave.future;
    }
    await super.save(state);
  }
}

const _viewports = [Size(360, 640), Size(430, 932)];
final _now = DateTime.utc(2026, 8, 18, 12);

Future<void> pumpMiningScreen(
  WidgetTester tester,
  Size viewport, {
  MiningSaveRepository? repository,
  DateTime Function()? nowUtc,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = viewport;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: MiningScreen(
        content: MiningContentRegistry.phaseOne(),
        repository: repository,
        nowUtc: nowUtc ?? () => _now,
      ),
    ),
  );

  for (var i = 0; i < 80; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump();
}

void expectMiningStatusToStayFocused(WidgetTester tester) {
  for (final label in const [
    'Population',
    'Workers',
    'Happiness',
    'Research',
  ]) {
    expect(find.text(label), findsNothing);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  for (final viewport in _viewports) {
    testWidgets('renders without overflow at $viewport', (tester) async {
      await pumpMiningScreen(tester, viewport);

      expect(find.text('Landing Basin'), findsWidgets);
      expect(find.text('SELL ALL CARGO'), findsOneWidget);
      expectMiningStatusToStayFocused(tester);
      expect(tester.takeException(), isNull);

      final buttonSize = tester.getSize(
        find.byKey(const Key('mining-primary-action')),
      );
      expect(buttonSize.height, greaterThanOrEqualTo(56));
    });

    testWidgets(
      'builds Landing Basin and exposes its upgrade state at $viewport',
      (tester) async {
        await pumpMiningScreen(tester, viewport);

        await tester.tap(find.byKey(const Key('mining-sector-landingBasin')));
        await tester.pump();
        expect(find.textContaining('Build'), findsWidgets);

        await tester.tap(find.byKey(const Key('mining-primary-action')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.textContaining('Level 1'), findsOneWidget);
        expect(find.textContaining('Upgrade'), findsWidgets);
        expect(find.text('Mine built.'), findsOneWidget);
        expectMiningStatusToStayFocused(tester);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('disables the primary action while a mutation is saving', (
    tester,
  ) async {
    final repository = DelayedMiningSaveRepository();
    await pumpMiningScreen(tester, _viewports.first, repository: repository);

    await tester.tap(find.byKey(const Key('mining-sector-landingBasin')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mining-primary-action')));
    await repository.saveStarted.future;
    await tester.pump();

    final button = tester.widget<ElevatedButton>(
      find.descendant(
        of: find.byKey(const Key('mining-primary-action')),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(button.onPressed, isNull);

    repository.allowSave.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  });
}
