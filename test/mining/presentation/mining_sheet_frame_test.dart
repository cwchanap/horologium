import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
