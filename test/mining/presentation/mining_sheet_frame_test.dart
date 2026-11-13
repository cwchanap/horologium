import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/presentation/mining_navigation.dart';
import 'package:horologium/mining/presentation/mining_sheet_frame.dart';

Future<void> _pumpFrame(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MiningSheetFrame(
          key: const Key('mining-sheet-frame'),
          title: 'Technology',
          icon: const Icon(Icons.memory),
          child: const SizedBox(height: 120, child: Text('body')),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'landscape close control stays inside the right safe-area inset',
    (tester) async {
      // The panel contents use SafeArea, but the positioned close control is a
      // sibling overlay. On a notched landscape device with a nonzero right
      // inset, the 52px dismiss target must not sit under the system cutout.
      const padRight = 44.0;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(874, 402);
      tester.view.padding = const FakeViewPadding(
        left: 0,
        top: 0,
        right: padRight,
        bottom: 0,
      );
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
      });

      await _pumpFrame(tester);

      final close = tester.getRect(find.bySemanticsLabel('Close Technology'));
      // The control's right edge is offset by the right safe-area inset.
      expect(close.right, 874 - 14 - padRight);
      // And it stays strictly inside the unsafe horizontal region.
      expect(close.right, lessThanOrEqualTo(874 - padRight));
    },
  );

  testWidgets('the scene cargo ring reports the real sellable value', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: MiningSheetScene(
          backgroundAsset: MiningContentRegistry.stellarMining()
              .site(MiningSiteId.landingBasin)
              .cavernAsset,
          destination: MiningNavigationDestination.technology,
          cash: 100,
          cargo: 12,
          capacity: 40,
          projectedValue: 48,
          onDestinationSelected: (_) {},
          child: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.bySemanticsLabel(RegExp(r'^Cargo 12\.0 of 40\.0, value 48 cash')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a pinned footer stays fixed while the body scrolls', (
    tester,
  ) async {
    const padBottom = 24.0;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    tester.view.padding = const FakeViewPadding(
      left: 0,
      top: 0,
      right: 0,
      bottom: padBottom,
    );
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: MiningSheetFrame(
              key: const Key('mining-sheet-frame'),
              title: 'Technology',
              icon: const Icon(Icons.memory),
              pinnedFooter: const Text('pinned footer'),
              child: const Column(
                children: [
                  SizedBox(height: 400),
                  Text('body middle'),
                  SizedBox(height: 400),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final body = tester.getRect(find.byKey(const Key('mining-sheet-body')));
    final footerBefore = tester.getRect(
      find.byKey(const Key('mining-sheet-pinned-footer')),
    );
    expect(body.bottom, lessThanOrEqualTo(footerBefore.top));
    expect(footerBefore.bottom, lessThanOrEqualTo(640 - padBottom));
    expect(find.text('pinned footer').hitTestable(), findsOneWidget);
    expect(find.text('body middle').hitTestable(), findsNothing);

    await tester.drag(
      find.byKey(const Key('mining-sheet-body')),
      const Offset(0, -200),
    );
    await tester.pump();

    expect(
      tester.getRect(find.byKey(const Key('mining-sheet-pinned-footer'))),
      footerBefore,
    );
    expect(find.text('pinned footer').hitTestable(), findsOneWidget);
    expect(find.text('body middle').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('omitting the pinned footer keeps the content-sized panel', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: MiningSheetFrame(
              key: const Key('mining-sheet-frame'),
              title: 'Technology',
              icon: const Icon(Icons.memory),
              child: const SizedBox(height: 120, child: Text('short body')),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final panel = tester.getRect(find.byKey(const Key('mining-sheet-panel')));
    expect(panel.bottom, 640);
    expect(panel.height, lessThan(300));
    expect(find.byKey(const Key('mining-sheet-body')), findsNothing);
    expect(find.byKey(const Key('mining-sheet-pinned-footer')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
