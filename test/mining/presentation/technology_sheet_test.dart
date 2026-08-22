import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_progression_views.dart';
import 'package:horologium/mining/presentation/technology_sheet.dart';

const _viewports = [Size(360, 640), Size(430, 932)];

TechnologySheetView _view() => const TechnologySheetView(
  tracks: [
    TechnologyTrackView(
      track: TechnologyTrack.extraction,
      name: 'Extraction',
      level: 0,
      currentEffect: 'Mining rate ×1.00',
      nextEffect: 'Mining rate ×1.10',
      cost: 300,
      gateSectorName: 'Landing Basin',
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
      gateSectorName: 'Landing Basin',
      isGateSatisfied: false,
      isAffordable: true,
      isMaxLevel: false,
      disabledReason: 'Build the Landing Basin mine first.',
    ),
    TechnologyTrackView(
      track: TechnologyTrack.surveying,
      name: 'Surveying',
      level: 5,
      currentEffect: '6 of 6 sectors revealable',
      nextEffect: null,
      cost: null,
      gateSectorName: null,
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

void main() {
  for (final viewport in _viewports) {
    testWidgets('renders track affordances from the view at $viewport', (
      tester,
    ) async {
      await _pumpSheet(tester, viewport);

      expect(find.byKey(const Key('mining-technology-sheet')), findsOneWidget);
      expect(find.textContaining('Extraction · Level 0'), findsOneWidget);
      expect(find.textContaining('Level 0'), findsWidgets);
      expect(find.text('Mining rate ×1.00'), findsOneWidget);
      expect(find.text('Next: Mining rate ×1.10'), findsOneWidget);

      // Unmet gate reason flows straight from the view model.
      expect(find.text('Build the Landing Basin mine first.'), findsOneWidget);

      // Max level shows no next effect and no cost row.
      expect(find.text('6 of 6 sectors revealable'), findsOneWidget);
      expect(find.textContaining('Next:'), findsNWidgets(2));

      expect(tester.takeException(), isNull);
    });

    testWidgets('purchase buttons meet the 48px minimum at $viewport', (
      tester,
    ) async {
      await _pumpSheet(tester, viewport);

      for (final track in TechnologyTrack.values) {
        final size = tester.getSize(
          find.byKey(Key('mining-technology-buy-${track.name}')),
        );
        expect(size.height, greaterThanOrEqualTo(48));
        expect(size.width, greaterThanOrEqualTo(48));
      }
    });
  }

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

    await tester.tap(find.byKey(const Key('mining-technology-buy-extraction')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(purchases, [TechnologyTrack.extraction]);

    // Gated and max-level tracks stay inert.
    await openSheet();
    final logistics = tester.widget<ElevatedButton>(
      find.descendant(
        of: find.byKey(const Key('mining-technology-buy-logistics')),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(logistics.onPressed, isNull);
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
