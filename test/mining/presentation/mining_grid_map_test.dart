import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mine_site_view.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_grid.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:horologium/mining/presentation/mining_grid_map.dart';
import 'package:horologium/mining/presentation/mining_visuals.dart';
import 'package:horologium/mining/site_deck_view.dart';

import '../../support/mining_visual_frames.dart';

final _content = MiningContentRegistry.stellarMining();
final _start = DateTime.utc(2026, 8, 26, 12);

MineSiteView _view(
  MiningSiteId siteId, {
  List<MiningRigPlacement> rigs = const [],
  DockBayId? selectedBayId,
  Map<DockBayId, RigTier?>? dockBays,
}) {
  final initial = MiningSave.initial(nowUtc: _start);
  final state = initial.copyWith(
    docks: dockBays == null
        ? initial.docks
        : {
            ...initial.docks,
            MiningPlanetId.homeworld: {
              ...initial.docks[MiningPlanetId.homeworld]!,
              ...dockBays,
            },
          },
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
    selectedBayId: selectedBayId,
    isBusy: false,
  );
}

Finder _rigSemantics(String label, {required bool enabled}) =>
    find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.button == true &&
          widget.properties.enabled == enabled &&
          widget.properties.label != null &&
          widget.properties.label!.contains(label),
    );

Future<void> _pumpMap(
  WidgetTester tester,
  MineSiteView view,
  void Function(MiningGridCell) onCellTap, {
  Size size = const Size(430, 500),
  EdgeInsets viewportInsets = EdgeInsets.zero,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: MiningGridMap(
        key: ValueKey(view.siteId),
        view: view,
        onCellTap: onCellTap,
        impactSequence: 0,
        reducedMotion: true,
        viewportInsets: viewportInsets,
      ),
    ),
  );
  await tester.pump();
}

Rect _surfaceRect(WidgetTester tester) =>
    tester.getRect(find.byKey(const Key('mining-grid-surface')));

void main() {
  test('the shared static fixture site is not animated', () {
    expect(MiningVisuals.depositFramesFor(staticMiningSiteId), isNull);
  });

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

      await tester.timedDrag(
        find.byKey(const Key('mining-grid-interactive')),
        const Offset(-600, 0),
        const Duration(milliseconds: 300),
      );
      await tester.pump(const Duration(seconds: 2));
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
    final view = _view(staticMiningSiteId);
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
    final view = _view(staticMiningSiteId);
    await _pumpMap(tester, view, (_) {});

    // Granite Crater progression levels are 0,1,2,3: at Surveying 0 the
    // level-0 resource is surveyed and the rest of the field is locked.
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

  testWidgets('hosts each keyed animated layer and no static layer', (
    tester,
  ) async {
    // The loop below derives expected keys with the same siteKeyPrefix
    // production uses, so it cannot catch a prefix regression. This literal
    // key pins the contract.
    await _pumpMap(tester, _view(MiningSiteId.carbonRidge), (_) {});
    expect(
      find.byKey(const Key('carbon-ridge-grid-visual-layer')),
      findsOneWidget,
    );

    for (final id in animatedMiningSiteIds) {
      await _pumpMap(tester, _view(id), (_) {});

      expect(
        find.byKey(Key('${MiningVisuals.siteKeyPrefix(id)}-grid-visual-layer')),
        findsOneWidget,
        reason: id.name,
      );
      expect(
        find.byKey(const Key('static-mining-grid-visual-layer')),
        findsNothing,
        reason: id.name,
      );
      expect(tester.takeException(), isNull, reason: id.name);
    }
  });

  testWidgets('hosts the static object layer for non-animated sites', (
    tester,
  ) async {
    final taps = <MiningGridCell>[];
    final view = _view(staticMiningSiteId);
    await _pumpMap(tester, view, taps.add);

    expect(
      find.byKey(const Key('static-mining-grid-visual-layer')),
      findsOneWidget,
    );
    for (final id in animatedMiningSiteIds) {
      expect(
        find.byKey(Key('${MiningVisuals.siteKeyPrefix(id)}-grid-visual-layer')),
        findsNothing,
        reason: id.name,
      );
    }
    // Granite Crater's first generated deposit is a 2x2 at (1,2); a literal
    // key keeps this overlay check able to fail.
    expect(find.byKey(const Key('mining-deposit-1-2-2')), findsOneWidget);
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
    final view = _view(staticMiningSiteId);
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

  testWidgets('converts screen insets into scene pan boundaries and frames the '
      'starter deposit', (tester) async {
    const insets = EdgeInsets.fromLTRB(58, 100, 96, 196);
    final view = _view(MiningSiteId.landingBasin);
    // deployableCells stays empty until a dock rig is selected; the
    // starter frame must still land on the first surveyed deposit.
    expect(view.deployableCells, isEmpty);
    await _pumpMap(
      tester,
      view,
      (_) {},
      size: const Size(390, 844),
      viewportInsets: insets,
    );

    final viewer = tester.widget<InteractiveViewer>(
      find.byKey(const Key('mining-grid-interactive')),
    );
    expect(viewer.minScale, 0.8);
    expect(viewer.maxScale, 1.6);
    expect(
      viewer.boundaryMargin,
      const EdgeInsets.fromLTRB(72.5, 125, 120, 245),
    );

    // The (1,1) 2x2 starter deposit centers inside the unoccluded band
    // as far as the clamped pan bounds allow: (176, 237) at this size.
    final deposit = tester.getRect(
      find.byKey(const Key('mining-deposit-1-1-2')),
    );
    expect(deposit.center, const Offset(176, 237));
  });

  testWidgets('centers the initial camera on the placed-rig bounding box', (
    tester,
  ) async {
    // Rigs at (6,0) and (8,4) bound cells x 6-8, y 0-4: child-space
    // center (420, 140).
    await _pumpMap(
      tester,
      _view(
        MiningSiteId.landingBasin,
        rigs: const [
          MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(6, 0)),
          MiningRigPlacement(tier: RigTier.t3, cell: MiningGridCell(8, 4)),
        ],
      ),
      (_) {},
      size: const Size(390, 844),
      viewportInsets: const EdgeInsets.fromLTRB(58, 100, 96, 196),
    );

    // Unoccluded center (176, 374) would translate to (-244, 234); the
    // top boundary clamps ty to the 125 margin.
    expect(_surfaceRect(tester).topLeft, const Offset(-244, 125));
  });

  testWidgets('zeros the axis on a viewport wider than the child', (
    tester,
  ) async {
    // A wide web window can exceed the 2800px grid: the reversed x bounds
    // must not reach num.clamp and start at 0.0 matching InteractiveViewer's
    // clamp translation so the grid does not jump on first pan.
    await _pumpMap(
      tester,
      _view(MiningSiteId.landingBasin),
      (_) {},
      size: const Size(3100, 900),
    );

    expect(_surfaceRect(tester).topLeft, Offset.zero);
    expect(tester.takeException(), isNull);
  });

  testWidgets('zeros the axis on a viewport taller than the child', (
    tester,
  ) async {
    await _pumpMap(
      tester,
      _view(MiningSiteId.landingBasin),
      (_) {},
      size: const Size(390, 3100),
    );

    expect(_surfaceRect(tester).topLeft, Offset.zero);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the identity camera when no focus qualifies', (
    tester,
  ) async {
    final definition = _content.site(MiningSiteId.landingBasin);
    final starter = definition.deposits.first;
    // The only surveyed deposit has every perimeter slot mined, so no
    // deposit qualifies and no rigs exist: the camera stays at identity.
    final view = MineSiteView(
      siteId: MiningSiteId.landingBasin,
      planetId: MiningPlanetId.homeworld,
      definition: definition,
      isUnlocked: true,
      surveyingLevel: 0,
      deposits: [
        MineSiteDepositView(
          definition: starter,
          minerCount: 8,
          slotCount: 8,
          isSurveyed: true,
        ),
      ],
      rigs: const [],
      deployableCells: const {},
      upgradeableCells: const {},
      deployedRigs: const [],
      rate: 0,
      capacity: 1,
      cargo: 0,
      projectedSale: 0,
      activePlanetCargo: 0,
      activePlanetProjectedSale: 0,
      sale: MiningSaleAffordance.from(
        isBusy: false,
        cargo: 0,
        projectedValue: 0,
      ),
      isActivePlanet: true,
      selectedBayId: null,
      selectedRig: null,
      isBusy: false,
    );
    await _pumpMap(
      tester,
      view,
      (_) {},
      size: const Size(390, 844),
      viewportInsets: const EdgeInsets.fromLTRB(58, 100, 96, 196),
    );

    expect(_surfaceRect(tester).topLeft, Offset.zero);
  });

  testWidgets('keeps the panned camera across a same-site view rebuild', (
    tester,
  ) async {
    const rigs = [
      MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(3, 2)),
    ];
    const insets = EdgeInsets.fromLTRB(58, 100, 96, 196);
    await _pumpMap(
      tester,
      _view(MiningSiteId.landingBasin, rigs: rigs),
      (_) {},
      size: const Size(390, 844),
      viewportInsets: insets,
    );
    // The rig's bounding-box frame lands before the first pan.
    expect(_surfaceRect(tester).topLeft, const Offset(-20, 125));
    await tester.timedDrag(
      find.byKey(const Key('mining-grid-interactive')),
      const Offset(-160, -90),
      const Duration(milliseconds: 300),
    );
    await tester.pump(const Duration(seconds: 2));
    final panned = _surfaceRect(tester).topLeft;
    expect(panned, isNot(const Offset(-20, 125)));

    // The next-second refresh supplies a fresh view instance behind the
    // same site key: the widget-local camera must not move.
    await _pumpMap(
      tester,
      _view(MiningSiteId.landingBasin, rigs: rigs),
      (_) {},
      size: const Size(390, 844),
      viewportInsets: insets,
    );
    expect(_surfaceRect(tester).topLeft, panned);
  });

  testWidgets('reframes the camera on site change and re-entry', (
    tester,
  ) async {
    const insets = EdgeInsets.fromLTRB(58, 100, 96, 196);
    await _pumpMap(
      tester,
      _view(MiningSiteId.landingBasin),
      (_) {},
      size: const Size(390, 844),
      viewportInsets: insets,
    );
    expect(_surfaceRect(tester).topLeft, const Offset(64, 125));

    await tester.timedDrag(
      find.byKey(const Key('mining-grid-interactive')),
      const Offset(-160, -90),
      const Duration(milliseconds: 300),
    );
    await tester.pump(const Duration(seconds: 2));
    final panned = _surfaceRect(tester).topLeft;
    expect(panned, isNot(const Offset(64, 125)));

    // A site swap remounts the keyed map: the fresh frame lands on the
    // new site's surveyed starter deposit instead of the panned camera.
    await _pumpMap(
      tester,
      _view(MiningSiteId.carbonRidge),
      (_) {},
      size: const Size(390, 844),
      viewportInsets: insets,
    );
    expect(_surfaceRect(tester).topLeft, const Offset(64, 125));

    // Re-entry after the map unmounts also frames fresh.
    await _pumpMap(
      tester,
      _view(MiningSiteId.landingBasin),
      (_) {},
      size: const Size(390, 844),
      viewportInsets: insets,
    );
    await tester.timedDrag(
      find.byKey(const Key('mining-grid-interactive')),
      const Offset(-160, -90),
      const Duration(milliseconds: 300),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(_surfaceRect(tester).topLeft, isNot(const Offset(64, 125)));
    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpMap(
      tester,
      _view(MiningSiteId.landingBasin),
      (_) {},
      size: const Size(390, 844),
      viewportInsets: insets,
    );
    expect(_surfaceRect(tester).topLeft, const Offset(64, 125));
  });

  testWidgets('announces the upgrade action on a matching selected rig', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final taps = <MiningGridCell>[];
    await _pumpMap(
      tester,
      _view(
        MiningSiteId.landingBasin,
        rigs: const [
          MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(3, 2)),
        ],
        selectedBayId: DockBayId.b1,
      ),
      taps.add,
    );

    final upgrade = _rigSemantics(
      'T1 rig at (3,2) mining deposit (1,1). Upgrade to T2.',
      enabled: true,
    );
    expect(upgrade, findsOneWidget);

    // The semantic tap routes the same cell as the physical tap.
    tester.semantics.performAction(
      find.semantics.byLabel(
        RegExp(r'T1 rig at \(3,2\) mining deposit \(1,1\)\. Upgrade to T2\.'),
      ),
      SemanticsAction.tap,
    );
    expect(taps.single, const MiningGridCell(3, 2));
    handle.dispose();
  });

  testWidgets('a full dock still enables a valid placed upgrade', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pumpMap(
      tester,
      _view(
        MiningSiteId.landingBasin,
        rigs: const [
          MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(3, 2)),
        ],
        selectedBayId: DockBayId.b1,
        dockBays: const {
          DockBayId.b1: RigTier.t1,
          DockBayId.b2: RigTier.t1,
          DockBayId.b3: RigTier.t1,
          DockBayId.b4: RigTier.t1,
        },
      ),
      (_) {},
    );

    // Recall is impossible with a full dock, but the selected T1 upgrades
    // the placed T1: the node stays enabled and never says "Dock is full.".
    expect(
      _rigSemantics(
        'T1 rig at (3,2) mining deposit (1,1). Upgrade to T2.',
        enabled: true,
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('Dock is full')), findsNothing);
    handle.dispose();
  });

  testWidgets('reports merge-rule failures on selected upgrade targets', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final view = _view(
      MiningSiteId.landingBasin,
      rigs: const [
        MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(3, 2)),
        MiningRigPlacement(tier: RigTier.t5, cell: MiningGridCell(3, 1)),
      ],
      selectedBayId: DockBayId.b1,
      dockBays: const {DockBayId.b1: RigTier.t5},
    );
    await _pumpMap(tester, view, (_) {});

    expect(
      _rigSemantics(
        'T1 rig at (3,2) mining deposit (1,1). Rigs must be the same tier.',
        enabled: false,
      ),
      findsOneWidget,
    );
    expect(
      _rigSemantics(
        'T5 rig at (3,1) mining deposit (1,1). T5 rigs cannot merge.',
        enabled: false,
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('feeds upgrade targets to the grid painter as a second set', (
    tester,
  ) async {
    const cells = [MiningGridCell(3, 2), MiningGridCell(3, 1)];
    final view = _view(
      MiningSiteId.landingBasin,
      rigs: [
        MiningRigPlacement(tier: RigTier.t1, cell: cells[0]),
        MiningRigPlacement(tier: RigTier.t5, cell: cells[1]),
      ],
      selectedBayId: DockBayId.b1,
    );
    expect(view.upgradeableCells, {cells[0]});
    await _pumpMap(tester, view, (_) {});

    final painter =
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byKey(const Key('mining-grid-surface')),
                    matching: find.byWidgetPredicate(
                      (widget) =>
                          widget is CustomPaint &&
                          widget.painter is MiningGridPainter,
                    ),
                  ),
                )
                .painter
            as MiningGridPainter;
    expect(painter.upgradeableCells, {cells[0]});
    expect(painter.deployableCells, view.deployableCells);
  });

  testWidgets('keeps recall semantics while no dock rig is selected', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pumpMap(
      tester,
      _view(
        MiningSiteId.landingBasin,
        rigs: const [
          MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(3, 2)),
        ],
      ),
      (_) {},
    );

    expect(
      _rigSemantics('T1 rig at (3,2) mining deposit (1,1).', enabled: true),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('Upgrade to')), findsNothing);
    handle.dispose();
  });
}
