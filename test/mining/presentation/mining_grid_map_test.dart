import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mine_site_view.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_grid.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:horologium/mining/presentation/mining_grid_map.dart';

final _content = MiningContentRegistry.stellarMining();
final _start = DateTime.utc(2026, 8, 26, 12);

MineSiteView _view(
  MiningSiteId siteId, {
  List<MiningRigPlacement> rigs = const [],
}) {
  final initial = MiningSave.initial(nowUtc: _start);
  final state = initial.copyWith(
    sites: {
      ...initial.sites,
      siteId: initial.sites[siteId]!.copyWith(
        unlocked: true,
        rigPlacements: rigs,
      ),
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
      expect(find.byKey(const Key('mining-deposit-1-1-2')), findsOneWidget);

      final viewport = tester.getRect(
        find.byKey(const Key('mining-grid-interactive')),
      );
      final deposit = tester.getRect(
        find.byKey(const Key('mining-deposit-1-1-2')),
      );
      expect(viewport.overlaps(deposit), isTrue);

      await tester.drag(
        find.byKey(const Key('mining-grid-interactive')),
        const Offset(-600, 0),
      );
      await tester.pumpAndSettle();
      expect(taps, isEmpty);

      final far = tester.getRect(
        find.byKey(const Key('mining-deposit-16-1-3')),
      );
      await tester.tapAt(Offset(far.center.dx, far.top - 28));
      await tester.pump();
      expect(taps.single, const MiningGridCell(17, 0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('renders exactly 100 resource images on a static site', (
    tester,
  ) async {
    final view = _view(MiningSiteId.carbonRidge);
    await _pumpMap(tester, view, (_) {});

    expect(view.deposits.length, 100);
    expect(
      find.descendant(
        of: find.byKey(const Key('static-mining-grid-visual-layer')),
        matching: find.byType(Image),
      ),
      findsNWidgets(100),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('dims unsurveyed resources, keeps surveyed art full', (
    tester,
  ) async {
    final view = _view(MiningSiteId.carbonRidge);
    await _pumpMap(tester, view, (_) {});

    // Carbon Ridge progression levels are 0,1,2,3: at Surveying 0 the level-0
    // resource is surveyed and the rest of the field is locked.
    Key depositNodeKey(MineSiteDepositView deposit) => Key(
      'static-deposit-${deposit.definition.x}-'
      '${deposit.definition.y}-${deposit.definition.size}',
    );
    final surveyed = view.deposits.firstWhere((deposit) => deposit.isSurveyed);
    final locked = view.deposits.firstWhere((deposit) => !deposit.isSurveyed);

    final surveyedImage = tester.widget<Image>(
      find.descendant(
        of: find.byKey(depositNodeKey(surveyed)),
        matching: find.byType(Image),
      ),
    );
    expect(surveyedImage.opacity, isNull);

    final lockedImage = tester.widget<Image>(
      find.descendant(
        of: find.byKey(depositNodeKey(locked)),
        matching: find.byType(Image),
      ),
    );
    expect(lockedImage.opacity, isA<AlwaysStoppedAnimation<double>>());
    expect(lockedImage.opacity!.value, .62);
    expect(tester.takeException(), isNull);
  });

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
    expect(find.byKey(const Key('mining-deposit-1-1-2')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keys resource overlays by x-y-size geometry', (tester) async {
    await _pumpMap(tester, _view(MiningSiteId.landingBasin), (_) {});

    // Authored dense-field deposits: (1,1) size 2 and (16,1) size 3.
    expect(find.byKey(const Key('mining-deposit-1-1-2')), findsOneWidget);
    expect(find.byKey(const Key('mining-deposit-16-1-3')), findsOneWidget);
    expect(find.byKey(const Key('mining-deposit-d1')), findsNothing);
  });

  testWidgets('tiles the cavern background instead of stretching it', (
    tester,
  ) async {
    final view = _view(MiningSiteId.carbonRidge);
    await _pumpMap(tester, view, (_) {});

    final background = tester.widget<Image>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                view.definition.cavernAsset,
      ),
    );
    expect(background.fit, BoxFit.none);
    expect(background.alignment, Alignment.topLeft);
    expect(background.repeat, ImageRepeat.repeat);
  });

  testWidgets('does not repeat a floating lock badge across the field', (
    tester,
  ) async {
    await _pumpMap(tester, _view(MiningSiteId.landingBasin), (_) {});

    expect(find.text('Surveying 1'), findsNothing);
    expect(find.text('Surveying 2'), findsNothing);
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

  testWidgets('exposes the rig recall tap action to semantics', (tester) async {
    final handle = tester.ensureSemantics();
    final taps = <MiningGridCell>[];
    await _pumpMap(
      tester,
      _view(
        MiningSiteId.landingBasin,
        rigs: const [
          MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(3, 2)),
        ],
      ),
      taps.add,
    );

    // performAction throws unless the node exposes SemanticsAction.tap, so
    // this both asserts the action survives the overlay IgnorePointer and
    // proves it forwards the rig's saved cell through onCellTap.
    tester.semantics.performAction(
      find.semantics.byLabel(
        RegExp(r'T1 rig at \(3,2\) mining deposit \(1,1\)'),
      ),
      SemanticsAction.tap,
    );
    expect(taps.single, const MiningGridCell(3, 2));
    handle.dispose();
  });

  testWidgets('labels deposits with footprint, miners, and free slots', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pumpMap(
      tester,
      _view(
        MiningSiteId.landingBasin,
        rigs: const [
          MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(2, 3)),
        ],
      ),
      (_) {},
    );

    // The rig at (2,3) mines the 2x2 resource at (1,1): one miner, seven of
    // eight perimeter slots free.
    expect(
      find.bySemanticsLabel(
        RegExp(r'Gold resource 2x2, 1 miners, 7 of 8 perimeter slots free\.'),
      ),
      findsOneWidget,
    );
    // Locked resources keep their Surveying requirement in semantics.
    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Gold resource \d+x\d+, 0 miners, \d+ of \d+ perimeter slots '
          r'free\. Requires Surveying 1\.',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Gold resource \d+x\d+, 0 miners, \d+ of \d+ perimeter slots '
          r'free\. Requires Surveying 2\.',
        ),
      ),
      findsWidgets,
    );
    handle.dispose();
  });
}
