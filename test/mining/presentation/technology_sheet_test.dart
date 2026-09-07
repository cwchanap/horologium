import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_progression_views.dart';
import 'package:horologium/mining/presentation/technology_sheet.dart';

const _viewports = [
  Size(360, 640),
  Size(402, 874),
  Size(430, 932),
  Size(874, 402),
];

TechnologySheetView _view() => const TechnologySheetView(
  tracks: [
    TechnologyTrackView(
      track: TechnologyTrack.extraction,
      name: 'Extraction',
      level: 0,
      currentEffect: 'Mining rate ×1.00',
      nextEffect: 'Mining rate ×1.10',
      cost: 300,
      gateSiteName: 'Landing Basin',
      isGateSatisfied: true,
      isAffordable: true,
      isMaxLevel: false,
      disabledReason: null,
    ),
    TechnologyTrackView(
      track: TechnologyTrack.logistics,
      name: 'Logistics',
      level: 0,
      currentEffect: 'Mine capacity ×1.00, offline cap 8h',
      nextEffect: 'Mine capacity ×1.15, offline cap 10h',
      cost: 300,
      gateSiteName: 'Landing Basin',
      isGateSatisfied: false,
      isAffordable: true,
      isMaxLevel: false,
      disabledReason: 'Commission the Landing Basin site first.',
    ),
    TechnologyTrackView(
      track: TechnologyTrack.surveying,
      name: 'Surveying',
      level: 5,
      currentEffect: '9 of 9 sites revealable',
      nextEffect: null,
      cost: null,
      gateSiteName: null,
      isGateSatisfied: true,
      isAffordable: true,
      isMaxLevel: true,
      disabledReason: 'Technology is at max level.',
    ),
  ],
);

Future<void> _pumpSheet(WidgetTester tester, Size viewport) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = viewport;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TechnologySheet(view: _view(), onPurchase: (_) {}),
      ),
    ),
  );
  await tester.pump();
}

String _trackDisplayName(TechnologyTrack track) => switch (track) {
  TechnologyTrack.extraction => 'Extraction',
  TechnologyTrack.logistics => 'Logistics',
  TechnologyTrack.surveying => 'Surveying',
};

void main() {
  for (final viewport in _viewports) {
    testWidgets('renders track affordances from the view at $viewport', (
      tester,
    ) async {
      await _pumpSheet(tester, viewport);

      expect(find.byKey(const Key('mining-technology-sheet')), findsOneWidget);
      expect(
        find.byKey(const Key('technology-node-extraction-1')),
        findsOneWidget,
      );
      if (viewport.width > viewport.height) {
        expect(
          tester.getRect(find.byKey(const Key('technology-root'))).right,
          lessThan(
            tester
                .getRect(find.byKey(const Key('technology-node-extraction-1')))
                .left,
          ),
        );
        expect(
          tester.getSize(find.byKey(const Key('technology-tree'))),
          const Size(482, 196),
        );
      }
      expect(find.text('×1.00'), findsOneWidget);
      expect(find.text('×1.10'), findsOneWidget);
      await tester.tap(find.byKey(const Key('technology-track-logistics')));
      await tester.pump();
      expect(find.text('Commission Landing Basin'), findsOneWidget);
      await tester.tap(find.byKey(const Key('technology-track-surveying')));
      await tester.pump();
      expect(find.text('9 of 9 sites revealable'), findsOneWidget);
      expect(find.text('Max Level'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('purchase buttons meet the 48px minimum at $viewport', (
      tester,
    ) async {
      await _pumpSheet(tester, viewport);

      for (final track in TechnologyTrack.values) {
        await tester.ensureVisible(
          find.byKey(Key('technology-track-${track.name}')),
        );
        await tester.tap(find.byKey(Key('technology-track-${track.name}')));
        await tester.pump();
        final size = tester.getSize(
          find.byKey(Key('mining-technology-buy-${track.name}')),
        );
        expect(size.height, greaterThanOrEqualTo(48));
        expect(size.width, greaterThanOrEqualTo(48));
      }
    });
  }

  testWidgets('portrait upgrade action fits without scrolling', (tester) async {
    await _pumpSheet(tester, const Size(402, 874));
    final action = find.byKey(const Key('mining-technology-buy-extraction'));
    expect(action.hitTestable(), findsOneWidget);
    final root = find.byKey(const Key('technology-root'));
    expect(root, findsOneWidget);
    expect(
      tester.getRect(root).top,
      greaterThan(
        tester
            .getRect(find.byKey(const Key('technology-node-extraction-1')))
            .bottom,
      ),
    );
    expect(
      tester.getRect(action).top,
      greaterThan(tester.getRect(root).bottom),
    );
    expect(tester.getRect(action).bottom, lessThanOrEqualTo(874));
  });

  testWidgets('landscape track selectors expose their name as semantics', (
    tester,
  ) async {
    // In landscape the visible track-name Text is omitted and the icon has no
    // semantic label, so the track selector must contribute its name through
    // the wrapping Semantics node for screen readers.
    await _pumpSheet(tester, const Size(874, 402));

    for (final track in TechnologyTrack.values) {
      expect(find.bySemanticsLabel(_trackDisplayName(track)), findsOneWidget);
    }

    // Selection toggles the `selected` flag on the named node.
    await tester.tap(find.byKey(const Key('technology-track-logistics')));
    await tester.pump();
    final logistics = tester.widget<Semantics>(
      find
          .ancestor(
            of: find.byKey(const Key('technology-track-logistics')),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(logistics.properties.selected, isTrue);
    expect(logistics.properties.label, 'Logistics');
  });

  testWidgets('enabled purchase buttons fire the callback with the track', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final purchases = <TechnologyTrack>[];
    Future<void> openSheet() async {
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
                    builder: (_) => TechnologySheet(
                      view: _view(),
                      onPurchase: purchases.add,
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    await openSheet();

    await tester.ensureVisible(
      find.byKey(const Key('mining-technology-buy-extraction')),
    );
    await tester.tap(find.byKey(const Key('mining-technology-buy-extraction')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(purchases, [TechnologyTrack.extraction]);

    // Gated and max-level tracks stay inert.
    await openSheet();
    await tester.tap(find.byKey(const Key('technology-track-logistics')));
    await tester.pump();
    final logistics = tester.widget<ElevatedButton>(
      find.descendant(
        of: find.byKey(const Key('mining-technology-buy-logistics')),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(logistics.onPressed, isNull);
    await tester.tap(find.byKey(const Key('technology-track-surveying')));
    await tester.pump();
    final surveying = tester.widget<ElevatedButton>(
      find.descendant(
        of: find.byKey(const Key('mining-technology-buy-surveying')),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(surveying.onPressed, isNull);
    expect(find.text('Max Level'), findsOneWidget);
  });
}
