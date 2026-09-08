import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mine_site_view.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_grid.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:horologium/mining/presentation/mining_grid_map.dart';

final _content = MiningContentRegistry.stellarMining();
final _start = DateTime.utc(2026, 8, 26, 12);

MineSiteView _view(MiningSiteId siteId) {
  final initial = MiningSave.initial(nowUtc: _start);
  final state = initial.copyWith(
    sites: {
      ...initial.sites,
      siteId: initial.sites[siteId]!.copyWith(unlocked: true),
    },
  );
  return MineSiteView.from(
    state: state,
    content: _content,
    siteId: siteId,
    selectedBayId: null,
    isBusy: false,
  );
}

Future<void> _pumpMap(
  WidgetTester tester,
  MineSiteView view,
  void Function(MiningGridCell) onCellTap,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 500);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: MiningGridMap(
        view: view,
        onCellTap: onCellTap,
        impactSequence: 0,
        reducedMotion: true,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'maps taps through the transform and hosts one Landing object layer',
    (tester) async {
      final taps = <MiningGridCell>[];
      await _pumpMap(tester, _view(MiningSiteId.landingBasin), taps.add);

      expect(find.byKey(const Key('mining-grid-interactive')), findsOneWidget);
      expect(find.byKey(const Key('mining-grid-surface')), findsOneWidget);
      expect(
        find.byKey(const Key('landing-basin-grid-visual-layer')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('static-mining-grid-visual-layer')),
        findsNothing,
      );
      expect(find.byKey(const Key('mining-deposit-d1')), findsOneWidget);

      final viewport = tester.getRect(
        find.byKey(const Key('mining-grid-interactive')),
      );
      final d1 = tester.getRect(find.byKey(const Key('mining-deposit-d1')));
      expect(viewport.overlaps(d1), isTrue);

      await tester.drag(
        find.byKey(const Key('mining-grid-interactive')),
        const Offset(-600, 0),
      );
      await tester.pumpAndSettle();
      expect(taps, isEmpty);

      final d2 = tester.getRect(find.byKey(const Key('mining-deposit-d2')));
      await tester.tapAt(Offset(d2.center.dx, d2.top - 28));
      await tester.pump();
      expect(taps.single, const MiningGridCell(16, 2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('hosts the static object layer for non-Landing sites', (
    tester,
  ) async {
    final taps = <MiningGridCell>[];
    await _pumpMap(tester, _view(MiningSiteId.carbonRidge), taps.add);

    expect(
      find.byKey(const Key('static-mining-grid-visual-layer')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('landing-basin-grid-visual-layer')),
      findsNothing,
    );
    expect(find.byKey(const Key('mining-deposit-d1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tap outside any interaction still resolves a grid cell', (
    tester,
  ) async {
    final taps = <MiningGridCell>[];
    await _pumpMap(tester, _view(MiningSiteId.landingBasin), taps.add);

    await tester.tapAt(const Offset(30, 30));
    await tester.pump();
    expect(taps.single, const MiningGridCell(0, 0));
  });
}
