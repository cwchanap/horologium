import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/presentation/mining_sheet_frame.dart';
import 'package:horologium/mining/presentation/relaunch_sheet.dart';

Future<void> _pumpSheet(
  WidgetTester tester, {
  required int relaunchCount,
  Size viewport = const Size(360, 640),
  bool textScaleBoost = false,
  VoidCallback? onConfirm,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = viewport;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        textScaler: TextScaler.linear(textScaleBoost ? 1.3 : 1),
      ),
      child: MaterialApp(
        theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Orbitron'),
        home: Scaffold(
          body: RelaunchSheet(
            relaunchCount: relaunchCount,
            onConfirm: onConfirm ?? () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpModalSheet(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Orbitron'),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) =>
                    const RelaunchSheet(relaunchCount: 1, onConfirm: _noop),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void _noop() {}

void main() {
  testWidgets('lists what resets, what stays, and the next multiplier', (
    tester,
  ) async {
    await _pumpSheet(tester, relaunchCount: 1);

    expect(
      tester
          .widget<MiningSheetFrame>(
            find.byKey(const Key('mining-relaunch-sheet')),
          )
          .title,
      'Relaunch',
    );
    expect(find.byKey(const Key('relaunch-confirm')), findsOneWidget);
    for (final reset in ['Cash', 'Technology', 'Rigs', 'Planets', 'Cargo']) {
      expect(find.text(reset), findsOneWidget);
    }
    expect(find.text('Relaunch count'), findsOneWidget);
    expect(find.text('Sale multiplier'), findsOneWidget);
    expect(find.text('NEXT SALES ×2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancel dismisses the sheet without confirming', (tester) async {
    await _pumpModalSheet(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mining-relaunch-sheet')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('relaunch-cancel')));
    await tester.tap(find.byKey(const Key('relaunch-cancel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mining-relaunch-sheet')), findsNothing);
  });

  testWidgets('confirm reports back once and dismisses the sheet', (
    tester,
  ) async {
    var confirms = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => RelaunchSheet(
                    relaunchCount: 1,
                    onConfirm: () => confirms++,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('relaunch-confirm')));
    await tester.tap(find.byKey(const Key('relaunch-confirm')));
    await tester.pumpAndSettle();

    expect(confirms, 1);
    expect(find.byKey(const Key('mining-relaunch-sheet')), findsNothing);
  });

  for (final viewport in const [Size(360, 640), Size(430, 932)]) {
    testWidgets(
      'confirmation fits ${viewport.width.toInt()}x${viewport.height.toInt()} '
      'at text scale 1.3',
      (tester) async {
        await _pumpSheet(
          tester,
          relaunchCount: 2,
          viewport: viewport,
          textScaleBoost: true,
        );

        expect(find.text('NEXT SALES ×2.5'), findsOneWidget);
        expect(find.byKey(const Key('relaunch-cancel')), findsOneWidget);
        expect(find.byKey(const Key('relaunch-confirm')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
