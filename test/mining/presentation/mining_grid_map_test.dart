import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mine_site_view.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_grid.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:horologium/mining/presentation/mining_grid_map.dart';
import 'package:horologium/mining/presentation/mining_visuals.dart';

import '../../support/mining_visual_frames.dart';

final _content = MiningContentRegistry.stellarMining();
final _start = DateTime.utc(2026, 8, 26, 12);

MineSiteView _view(
  MiningSiteId siteId, {
  List<MiningRigPlacement> rigs = const [],
  DockBayId? selectedBayId,
  Map<DockBayId, RigTier?>? dockBays,
  int surveying = 0,
}) {
  final initial = MiningSave.initial(nowUtc: _start);
  final state = initial.copyWith(
    technology: TechnologyLevels(surveying: surveying),
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

Key _chipKey(MiningGridCell cell) => Key('mining-rig-chip-${cell.x}-${cell.y}');

Finder _chips() => find.byWidgetPredicate(
  (widget) =>
      widget.key is ValueKey<String> &&
      (widget.key! as ValueKey<String>).value.startsWith('mining-rig-chip-'),
);

/// Bands in map-depth order: the top row is the Motherlode.
List<MiningBand> _depthOrder() =>
    [...MiningBand.values]..sort((a, b) => a.labelRow.compareTo(b.labelRow));

/// Every rig semantics widget, regardless of label: each rig owns exactly one.
/// Deploy-cell actions also mention a rig position, so exclude them.
Finder _rigSemanticsNodes() => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      widget.properties.button == true &&
      (widget.properties.label?.contains('rig at (') ?? false) &&
      !(widget.properties.label?.startsWith('Place ') ?? false),
);

String _chipLabel(WidgetTester tester, MiningGridCell cell) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(_chipKey(cell)),
        matching: find.byType(Text),
      ),
    )
    .data!;

Color? _chipColor(WidgetTester tester, MiningGridCell cell) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(_chipKey(cell)),
        matching: find.byType(Text),
      ),
    )
    .style
    ?.color;

Color? _chipFill(WidgetTester tester, MiningGridCell cell) =>
    (tester
                .widget<Container>(
                  find.descendant(
                    of: find.byKey(_chipKey(cell)),
                    matching: find.byType(Container),
                  ),
                )
                .decoration
            as BoxDecoration?)
        ?.color;

/// WCAG 2.0 relative-luminance contrast ratio between two opaque colors.
double _contrastRatio(Color foreground, Color background) {
  final a = foreground.computeLuminance();
  final b = background.computeLuminance();
  return a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
}

Future<void> _pumpMap(
  WidgetTester tester,
  MineSiteView view,
  void Function(MiningGridCell) onCellTap, {
  Size size = const Size(430, 500),
  EdgeInsets viewportInsets = EdgeInsets.zero,
  int impactSequence = 0,
  bool reducedMotion = true,
  double textScale = 1,
  double railTop = 0,
  double railBottom = double.infinity,
  double railRight = 8,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: MiningGridMap(
          key: ValueKey(view.siteId),
          view: view,
          onCellTap: onCellTap,
          impactSequence: impactSequence,
          reducedMotion: reducedMotion,
          viewportInsets: viewportInsets,
          railTop: railTop,
          railBottom: railBottom,
          railRight: railRight,
        ),
      ),
    ),
  );
  await tester.pump();
}

Rect _surfaceRect(WidgetTester tester) =>
    tester.getRect(find.byKey(const Key('mining-grid-surface')));

Rect _mapRect(WidgetTester tester) =>
    tester.getRect(find.byKey(const Key('mining-grid-map')));

double _sceneScale(WidgetTester tester) =>
    _surfaceRect(tester).width / miningGridSceneWidth;

ScrollPosition _position(WidgetTester tester) {
  final scrollable = find.descendant(
    of: find.byKey(const Key('mining-grid-scroll')),
    matching: find.byType(Scrollable),
  );
  return tester.state<ScrollableState>(scrollable.first).position;
}

Offset _cellPoint(WidgetTester tester, MiningGridCell cell) {
  final surface = _surfaceRect(tester);
  final scale = _sceneScale(tester);
  return surface.topLeft +
      Offset(
        (cell.x + .5) * miningGridCellSize * scale,
        (cell.y + .5) * miningGridCellSize * scale,
      );
}

/// Scrolls [cell] into the map's clear band, then returns its screen center.
Future<Offset> _revealCell(WidgetTester tester, MiningGridCell cell) async {
  final map = _mapRect(tester);
  final position = _position(tester);
  for (var i = 0; i < 6; i++) {
    final point = _cellPoint(tester, cell);
    if (point.dy < map.top + 12) {
      position.jumpTo(position.pixels - (map.top + 12 - point.dy));
    } else if (point.dy > map.bottom - 12) {
      position.jumpTo(position.pixels + (point.dy - (map.bottom - 12)));
    } else {
      break;
    }
    await tester.pump();
  }
  return _cellPoint(tester, cell);
}

void main() {
  test('the shared static fixture site is not animated', () {
    expect(MiningVisuals.depositFramesFor(staticMiningSiteId), isNull);
  });

  testWidgets(
    'hosts one Landing object layer over a full-bleed scroll background',
    (tester) async {
      final taps = <MiningGridCell>[];
      await _pumpMap(tester, _view(MiningSiteId.landingBasin), taps.add);

      expect(find.byKey(const Key('mining-grid-scroll')), findsOneWidget);
      expect(find.byKey(const Key('mining-grid-surface')), findsOneWidget);
      expect(
        find.byKey(const Key('landing-basin-grid-visual-layer')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('static-mining-grid-visual-layer')),
        findsNothing,
      );
      expect(find.byKey(const Key('mining-deposit-2-2-4')), findsOneWidget);

      // The cavern tile is behind the scroll view, not inside the 448dp scene.
      final background = find.byKey(const Key('mining-grid-background'));
      expect(background, findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('mining-grid-scroll')),
          matching: background,
        ),
        findsNothing,
      );
      expect(
        tester.getRect(background),
        tester.getRect(find.byKey(const Key('mining-grid-map'))),
      );

      final point = await _revealCell(tester, const MiningGridCell(0, 20));
      await tester.tapAt(point);
      await tester.pump();
      expect(taps.single, const MiningGridCell(0, 20));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('renders exactly ten resource images on a static site', (
    tester,
  ) async {
    final view = _view(staticMiningSiteId);
    await _pumpMap(tester, view, (_) {});

    expect(view.deposits.length, 10);
    expect(
      find.descendant(
        of: find.byKey(const Key('static-mining-grid-visual-layer')),
        matching: find.byType(Image),
      ),
      findsNWidgets(10),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('dims unsurveyed resources, keeps surveyed art full', (
    tester,
  ) async {
    final view = _view(staticMiningSiteId);
    await _pumpMap(tester, view, (_) {});

    // Granite Crater progression levels are 0,1,2,3: at Surveying 0 only the
    // pockets band is surveyed.
    Key depositNodeKey(MineSiteDepositView deposit) => Key(
      'static-deposit-${deposit.definition.x}-'
      '${deposit.definition.y}-${deposit.definition.size}',
    );
    final surveyed = view.deposits.firstWhere(
      (deposit) => bandForDeposit(deposit.definition) == MiningBand.pockets,
    );
    final locked = view.deposits.firstWhere(
      (deposit) => bandForDeposit(deposit.definition) == MiningBand.seams,
    );
    expect(surveyed.isSurveyed, isTrue);
    expect(locked.isSurveyed, isFalse);

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
    // The authored Motherlode is the 4x4 at (2,2); a literal key keeps this
    // overlay check able to fail.
    expect(find.byKey(const Key('mining-deposit-2-2-4')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keys resource overlays by x-y-size geometry', (tester) async {
    await _pumpMap(tester, _view(MiningSiteId.landingBasin), (_) {});

    expect(find.byKey(const Key('mining-deposit-0-20-1')), findsOneWidget);
    expect(find.byKey(const Key('mining-deposit-2-2-4')), findsOneWidget);
    expect(find.byKey(const Key('mining-deposit-d1')), findsNothing);
  });

  testWidgets('tiles the cavern background instead of stretching it', (
    tester,
  ) async {
    final view = _view(staticMiningSiteId);
    await _pumpMap(tester, view, (_) {});

    final background = tester.widget<Image>(
      find.byKey(const Key('mining-grid-background')),
    );
    expect(background.fit, BoxFit.none);
    expect(background.alignment, Alignment.topLeft);
    expect(background.repeat, ImageRepeat.repeat);
  });

  testWidgets('labels every band and one chip per locked band', (tester) async {
    await _pumpMap(tester, _view(MiningSiteId.landingBasin), (_) {});

    for (final band in MiningBand.values) {
      expect(
        find.byKey(Key('mining-band-label-${band.name}')),
        findsOneWidget,
        reason: band.name,
      );
    }
    // Landing Basin is 0,0,1,2: pockets and seams are open, lodes and the
    // Motherlode each show exactly one Surveying chip.
    expect(find.text('Surveying 1 opens the lodes'), findsOneWidget);
    expect(find.text('Surveying 2 opens the motherlode'), findsOneWidget);
    expect(find.text('Surveying 0 opens the pockets'), findsNothing);
    expect(find.text('Surveying 0 opens the seams'), findsNothing);
  });

  testWidgets('tap outside any interaction still resolves a grid cell', (
    tester,
  ) async {
    final taps = <MiningGridCell>[];
    await _pumpMap(tester, _view(MiningSiteId.landingBasin), taps.add);

    final point = await _revealCell(tester, const MiningGridCell(0, 0));
    await tester.tapAt(point);
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
          MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(0, 14)),
        ],
      ),
      taps.add,
    );

    tester.semantics.performAction(
      find.semantics.byLabel(
        RegExp(r'T1 rig at \(0,14\) mining deposit \(0,15\)'),
      ),
      SemanticsAction.tap,
    );
    expect(taps.single, const MiningGridCell(0, 14));
    handle.dispose();
  });

  testWidgets('keeps a rig action bound to its rig as rigs scroll in', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final taps = <MiningGridCell>[];
    // The lode rig was placed first, so revealing it inserts it ahead of the
    // seam rig's overlay node: without a stable key that node could be
    // reused for the newly visible rig while the seam rig stays on screen.
    await _pumpMap(
      tester,
      _view(
        MiningSiteId.landingBasin,
        rigs: const [
          MiningRigPlacement(tier: RigTier.t2, cell: MiningGridCell(0, 8)),
          MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(0, 14)),
        ],
      ),
      taps.add,
    );

    // Only the seam rig is in view at this offset.
    _position(tester).jumpTo(550);
    await tester.pump();
    final seam = tester.getSemantics(
      _rigSemantics('rig at (0,14)', enabled: true),
    );

    // Scrolling up reveals the earlier-placed lode rig ahead of it.
    _position(tester).jumpTo(450);
    await tester.pump();
    seam.owner!.performAction(seam.id, SemanticsAction.tap);
    expect(taps.single, const MiningGridCell(0, 14));
    handle.dispose();
  });

  testWidgets('exposes a deploy action with its own cell per legal cell', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final taps = <MiningGridCell>[];
    await _pumpMap(
      tester,
      _view(
        MiningSiteId.landingBasin,
        surveying: 1,
        selectedBayId: DockBayId.b1,
      ),
      taps.add,
    );

    // A legal cell in view owns its exact action; a cell scrolled out of the
    // viewport exposes none until the map scrolls it back into view.
    const offscreen = MiningGridCell(7, 21);
    final inView = find.semantics.byLabel('Place T1 rig at (3,10).');
    expect(inView, findsOneWidget);
    tester.semantics.performAction(inView, SemanticsAction.tap);
    expect(find.semantics.byLabel('Place T1 rig at (7,21).'), findsNothing);

    await _revealCell(tester, offscreen);
    await tester.pump();
    final revealed = find.semantics.byLabel('Place T1 rig at (7,21).');
    expect(revealed, findsOneWidget);
    tester.semantics.performAction(revealed, SemanticsAction.tap);
    expect(taps, const [MiningGridCell(3, 10), MiningGridCell(7, 21)]);

    // A legal but Surveying-locked Motherlode cell has no deploy action.
    expect(find.bySemanticsLabel('Place T1 rig at (2,1).'), findsNothing);
    handle.dispose();
  });

  testWidgets('aligns deploy action hit areas with the visible cells', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pumpMap(
      tester,
      _view(
        MiningSiteId.landingBasin,
        surveying: 1,
        selectedBayId: DockBayId.b1,
      ),
      (_) {},
      size: const Size(390, 844),
      viewportInsets: const EdgeInsets.fromLTRB(58, 134, 96, 196),
    );
    await tester.pump(); // let the initial frame and overlay settle

    const cell = MiningGridCell(3, 10);
    void expectAligned() {
      final node = tester.getSemantics(
        find.byKey(const Key('mining-deploy-cell-3-10')),
      );
      final global = MatrixUtils.transformRect(node.transform!, node.rect);
      // A hit area must not inherit the scene's FittedBox scale; that scale
      // was what displaced the browser rect from the visible cell.
      expect(node.transform!.entry(0, 0), closeTo(1, .001));
      expect(node.transform!.entry(1, 1), closeTo(1, .001));
      final center = _cellPoint(tester, cell);
      final size = miningGridCellSize * _sceneScale(tester);
      expect(global.center.dx, closeTo(center.dx, .5));
      expect(global.center.dy, closeTo(center.dy, .5));
      expect(global.width, closeTo(size, .1));
    }

    expectAligned();
    final target = math.min(
      _position(tester).pixels + 120,
      _position(tester).maxScrollExtent,
    );
    _position(tester).jumpTo(target);
    await tester.pump();
    expectAligned();
    handle.dispose();
  });

  testWidgets('re-syncs action hit areas after a resize clamps the scroll', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pumpMap(
      tester,
      _view(MiningSiteId.landingBasin, selectedBayId: DockBayId.b1),
      (_) {},
      size: const Size(390, 844),
      viewportInsets: const EdgeInsets.fromLTRB(58, 134, 96, 303.5),
    );
    await tester.pump(); // initial clamped frame

    const cell = MiningGridCell(7, 19);
    void expectAligned() {
      final node = tester.getSemantics(
        find.byKey(const Key('mining-deploy-cell-7-19')),
      );
      final global = MatrixUtils.transformRect(node.transform!, node.rect);
      final center = _cellPoint(tester, cell);
      final size = miningGridCellSize * _sceneScale(tester);
      expect(global.center.dx, closeTo(center.dx, .5));
      expect(global.center.dy, closeTo(center.dy, .5));
      expect(global.width, closeTo(size, .1));
    }

    expectAligned();
    // Growing the viewport shrinks the scroll extent from 666 to 562 and
    // clamps the offset during layout, without a normal scroll notification.
    // The first frame after the resize must already carry aligned hit areas;
    // do not wait for a later post-frame recovery.
    tester.view.physicalSize = const Size(390, 948);
    await tester.pump();
    expectAligned();
    handle.dispose();
  });

  testWidgets('prevents bounce overscroll from displacing action hit areas', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final handle = tester.ensureSemantics();
    await _pumpMap(
      tester,
      _view(MiningSiteId.landingBasin, selectedBayId: DockBayId.b1),
      (_) {},
      size: const Size(390, 844),
      viewportInsets: const EdgeInsets.fromLTRB(58, 134, 96, 303.5),
    );
    await tester.pump(); // initial clamped bottom frame
    final position = _position(tester);
    expect(position.pixels, closeTo(position.maxScrollExtent, .5));

    // Drag upward past the bottom and hold: iOS bouncing physics would paint
    // the grid past the extent while clamped action rects stay behind.
    final gesture = await tester.startGesture(const Offset(195, 500));
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump();
    }

    expect(
      position.pixels,
      lessThanOrEqualTo(position.maxScrollExtent + .5),
      reason: 'the map must not overscroll; hitboxes cannot track a bounce',
    );

    final node = tester.getSemantics(
      find.byKey(const Key('mining-deploy-cell-7-19')),
    );
    final action = MatrixUtils.transformRect(node.transform!, node.rect);
    final scale = _sceneScale(tester);
    final cellSize = miningGridCellSize * scale;
    final expectedY =
        _mapRect(tester).top + 134 + 19.5 * cellSize - position.pixels;
    expect(action.center.dy, closeTo(expectedY, .5));

    await gesture.up();
    await tester.pumpAndSettle();
    // Reset in-body: the post-test foundation-variable check can run before
    // tearDown callbacks on some platforms.
    debugDefaultTargetPlatformOverride = null;
    handle.dispose();
  });

  testWidgets('prevents bounce overscroll above the top from moving actions', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final handle = tester.ensureSemantics();
    await _pumpMap(
      tester,
      _view(MiningSiteId.landingBasin, selectedBayId: DockBayId.b1),
      (_) {},
      size: const Size(390, 844),
      viewportInsets: const EdgeInsets.fromLTRB(58, 134, 96, 303.5),
    );
    final position = _position(tester);
    position.jumpTo(0);
    await tester.pump();

    // Drag downward past the top and hold: iOS bouncing physics would paint
    // the grid above the extent while clamped action rects stay behind.
    final gesture = await tester.startGesture(const Offset(195, 300));
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
    }

    expect(
      position.pixels,
      greaterThanOrEqualTo(-.5),
      reason: 'the map must not overscroll; hitboxes cannot track a bounce',
    );

    final node = tester.getSemantics(
      find.byKey(const Key('mining-deploy-cell-7-14')),
    );
    final action = MatrixUtils.transformRect(node.transform!, node.rect);
    final scale = _sceneScale(tester);
    final cellSize = miningGridCellSize * scale;
    final expectedTop = _mapRect(tester).top + 134 + 14 * cellSize;
    expect(action.top, closeTo(expectedTop, .5));

    await gesture.up();
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;
    handle.dispose();
  });

  testWidgets('keeps the whole-map tap action off merged deposit semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pumpMap(
      tester,
      _view(
        MiningSiteId.landingBasin,
        surveying: 1,
        selectedBayId: DockBayId.b1,
      ),
      (_) {},
    );

    final motherlode = tester.getSemantics(
      find.bySemanticsLabel(RegExp(r'Gold resource 4x4, 0 miners')),
    );
    expect(
      motherlode.getSemanticsData().hasAction(SemanticsAction.tap),
      isFalse,
      reason: 'the map must not expose a single centre tap over all resources',
    );
    handle.dispose();
  });

  testWidgets('physical taps still place at the exact cell with a rig '
      'selected', (tester) async {
    final taps = <MiningGridCell>[];
    await _pumpMap(
      tester,
      _view(
        MiningSiteId.landingBasin,
        surveying: 1,
        selectedBayId: DockBayId.b1,
      ),
      taps.add,
    );

    for (final cell in const [MiningGridCell(3, 10), MiningGridCell(7, 21)]) {
      final point = await _revealCell(tester, cell);
      await tester.tapAt(point);
      await tester.pump();
      expect(taps, contains(cell));
    }
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
          MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(0, 14)),
        ],
      ),
      (_) {},
    );

    // The rig at (0,14) mines the 2x2 seam at (0,15): one miner, three of
    // four perimeter slots free.
    expect(
      find.bySemanticsLabel(
        RegExp(r'Gold resource 2x2, 1 miners, 3 of 4 perimeter slots free\.'),
      ),
      findsOneWidget,
    );
    // Locked bands keep their Surveying requirement in semantics.
    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Gold resource 3x3, 0 miners, \d+ of \d+ perimeter slots '
          r'free\. Requires Surveying 1\.',
        ),
      ),
      findsWidgets,
    );
    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Gold resource 4x4, 0 miners, \d+ of \d+ perimeter slots '
          r'free\. Requires Surveying 2\.',
        ),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('scales the scene to the viewport width and frames the highest '
      'open band', (tester) async {
    const insets = EdgeInsets.fromLTRB(58, 100, 96, 196);
    final view = _view(MiningSiteId.landingBasin);
    await _pumpMap(
      tester,
      view,
      (_) {},
      size: const Size(390, 844),
      viewportInsets: insets,
    );

    final surface = _surfaceRect(tester);
    expect(surface.width, closeTo(390, .01));
    expect(
      surface.height,
      closeTo(miningGridSceneHeight * 390 / miningGridSceneWidth, .01),
    );
    // Highest open band is seams (row 13): the specified target is
    // topPadding + scaled row offset, clamped to the scroll extent.
    final expected = math.min(
      insets.top + 13 * miningGridCellSize * 390 / miningGridSceneWidth,
      _position(tester).maxScrollExtent,
    );
    expect(_position(tester).pixels, closeTo(expected, .5));
  });

  testWidgets('frames once and never reframes on a Surveying purchase', (
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
    final framed = _position(tester).pixels;

    // The locked lodes band is exposed on the rail and the label row.
    final semantics = tester.ensureSemantics();
    expect(
      find.bySemanticsLabel('Jump to Lodes band. Requires Surveying 1.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('mining-band-lock-lodes')), findsOneWidget);

    // The entry frame sits at the maximum extent here; jump in range toward
    // the top so a reframe to the initial or newly opened band is detectable.
    _position(tester).jumpTo(framed - 120);
    await tester.pump();
    final scrolled = _position(tester).pixels;
    expect(scrolled, isNot(framed));

    // The same site key rebuilds with a newly opened lode band; the rail
    // updates but the player's scroll position stays put.
    await _pumpMap(
      tester,
      _view(MiningSiteId.landingBasin, surveying: 1),
      (_) {},
      size: const Size(390, 844),
      viewportInsets: insets,
    );
    expect(_position(tester).pixels, scrolled);
    expect(find.text('Surveying 1 opens the lodes'), findsNothing);
    expect(find.text('Surveying 2 opens the motherlode'), findsOneWidget);
    expect(find.byKey(const Key('mining-band-lock-lodes')), findsNothing);
    expect(
      find.byKey(const Key('mining-band-lock-motherlode')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Jump to Lodes band'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Jump to Motherlode band. Requires Surveying 2.'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('centers the scene on wide viewports without horizontal pan', (
    tester,
  ) async {
    await _pumpMap(
      tester,
      _view(MiningSiteId.landingBasin),
      (_) {},
      size: const Size(1024, 768),
    );

    final surface = _surfaceRect(tester);
    expect(surface.width, miningGridSceneWidth);
    expect(surface.left, closeTo((1024 - miningGridSceneWidth) / 2, .01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the scroll position across a same-site view rebuild', (
    tester,
  ) async {
    const rigs = [
      MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(0, 14)),
    ];
    const insets = EdgeInsets.fromLTRB(58, 100, 96, 196);
    await _pumpMap(
      tester,
      _view(MiningSiteId.landingBasin, rigs: rigs),
      (_) {},
      size: const Size(390, 844),
      viewportInsets: insets,
    );
    _position(tester).jumpTo(80);
    await tester.pump();
    final scrolled = _position(tester).pixels;

    await _pumpMap(
      tester,
      _view(MiningSiteId.landingBasin, rigs: rigs),
      (_) {},
      size: const Size(390, 844),
      viewportInsets: insets,
    );
    expect(_position(tester).pixels, scrolled);
  });

  testWidgets('frames fresh on site change and re-entry', (tester) async {
    const insets = EdgeInsets.fromLTRB(58, 100, 96, 196);
    await _pumpMap(
      tester,
      _view(MiningSiteId.landingBasin),
      (_) {},
      size: const Size(390, 844),
      viewportInsets: insets,
    );
    final framed = _position(tester).pixels;
    // framed is the maximum extent here; an in-range offset keeps this
    // deterministic and still differs from a fresh frame.
    _position(tester).jumpTo(framed - 100);
    await tester.pump();

    // A site swap remounts the keyed map with its own fresh frame.
    await _pumpMap(
      tester,
      _view(MiningSiteId.carbonRidge),
      (_) {},
      size: const Size(390, 844),
      viewportInsets: insets,
    );
    expect(_position(tester).pixels, closeTo(framed, .5));

    // Re-entry after the map unmounts also frames fresh.
    _position(tester).jumpTo(framed - 100);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpMap(
      tester,
      _view(MiningSiteId.landingBasin),
      (_) {},
      size: const Size(390, 844),
      viewportInsets: insets,
    );
    expect(_position(tester).pixels, closeTo(framed, .5));
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
          MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(0, 14)),
        ],
        selectedBayId: DockBayId.b1,
      ),
      taps.add,
    );

    final upgrade = _rigSemantics(
      'T1 rig at (0,14) mining deposit (0,15). Upgrade to T2.',
      enabled: true,
    );
    expect(upgrade, findsOneWidget);

    tester.semantics.performAction(
      find.semantics.byLabel(
        RegExp(r'T1 rig at \(0,14\) mining deposit \(0,15\)\. Upgrade to T2\.'),
      ),
      SemanticsAction.tap,
    );
    expect(taps.single, const MiningGridCell(0, 14));
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
          MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(0, 14)),
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

    expect(
      _rigSemantics(
        'T1 rig at (0,14) mining deposit (0,15). Upgrade to T2.',
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
        MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(0, 14)),
        MiningRigPlacement(tier: RigTier.t5, cell: MiningGridCell(1, 14)),
      ],
      selectedBayId: DockBayId.b1,
      dockBays: const {DockBayId.b1: RigTier.t5},
    );
    await _pumpMap(tester, view, (_) {});

    expect(
      _rigSemantics(
        'T1 rig at (0,14) mining deposit (0,15). Rigs must be the same tier.',
        enabled: false,
      ),
      findsOneWidget,
    );
    expect(
      _rigSemantics(
        'T5 rig at (1,14) mining deposit (0,15). T5 rigs cannot merge.',
        enabled: false,
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('feeds upgrade targets to the grid painter as a second set', (
    tester,
  ) async {
    const cells = [MiningGridCell(0, 14), MiningGridCell(7, 14)];
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
    expect(painter.width, 8);
    expect(painter.height, 22);
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
          MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(0, 14)),
        ],
      ),
      (_) {},
    );

    expect(
      _rigSemantics('T1 rig at (0,14) mining deposit (0,15).', enabled: true),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('Upgrade to')), findsNothing);
    handle.dispose();
  });

  testWidgets('renders one tier chip and one actionable rig node per rig', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    // One animated and one static site, with two legal rigs on distinct
    // resources.
    final cases = <(MiningSiteId, List<MiningRigPlacement>)>[
      (
        MiningSiteId.landingBasin,
        const [
          MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(0, 14)),
          MiningRigPlacement(tier: RigTier.t3, cell: MiningGridCell(7, 14)),
        ],
      ),
      (
        staticMiningSiteId,
        const [
          MiningRigPlacement(tier: RigTier.t1, cell: MiningGridCell(0, 14)),
          MiningRigPlacement(tier: RigTier.t3, cell: MiningGridCell(7, 14)),
        ],
      ),
    ];
    for (final (siteId, rigs) in cases) {
      await _pumpMap(tester, _view(siteId, rigs: rigs), (_) {});

      expect(_chips(), findsNWidgets(rigs.length), reason: siteId.name);
      expect(
        _rigSemanticsNodes(),
        findsNWidgets(rigs.length),
        reason: siteId.name,
      );
      for (final rig in rigs) {
        final chip = find.byKey(_chipKey(rig.cell));
        expect(chip, findsOneWidget, reason: '${siteId.name} ${rig.cell}');
        expect(
          find.descendant(of: chip, matching: find.byType(IgnorePointer)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: chip, matching: find.byType(ExcludeSemantics)),
          findsOneWidget,
        );
        expect(
          _chipLabel(tester, rig.cell),
          rig.tier.name.toUpperCase(),
          reason: '${siteId.name} ${rig.cell}',
        );
      }
    }
    handle.dispose();
  });

  testWidgets('golds the same chip only for a matching upgrade target', (
    tester,
  ) async {
    const eligible = MiningGridCell(0, 14);
    const mismatched = MiningGridCell(1, 14);
    const topTier = MiningGridCell(7, 14);
    const gold = Color(0xFFF5B44C);
    final view = _view(
      MiningSiteId.landingBasin,
      rigs: const [
        MiningRigPlacement(tier: RigTier.t1, cell: eligible),
        MiningRigPlacement(tier: RigTier.t2, cell: mismatched),
        MiningRigPlacement(tier: RigTier.t5, cell: topTier),
      ],
      selectedBayId: DockBayId.b1,
      dockBays: const {DockBayId.b1: RigTier.t1},
    );
    expect(view.upgradeableCells, {eligible});
    await _pumpMap(tester, view, (_) {});

    expect(_chips(), findsNWidgets(3));
    expect(_chipLabel(tester, eligible), 'T1→T2');
    expect(_chipLabel(tester, mismatched), 'T2');
    expect(_chipLabel(tester, topTier), 'T5');
    expect(_chipFill(tester, eligible), gold);
    expect(_chipColor(tester, eligible), const Color(0xFF04121A));
    expect(_chipFill(tester, mismatched), isNot(gold));
    expect(_chipColor(tester, mismatched), isNot(const Color(0xFF04121A)));
    expect(_chipFill(tester, topTier), isNot(gold));
    expect(_chipColor(tester, topTier), isNot(const Color(0xFF04121A)));
  });

  testWidgets('keeps the widest T4→T5 chip legible at both text scales', (
    tester,
  ) async {
    const cell = MiningGridCell(0, 14);
    const darkInk = Color(0xFF04121A);
    const upgradeGold = Color(0xFFF5B44C);
    final chipHeights = <double>[];
    for (final scale in [1.0, 1.3]) {
      final view = _view(
        MiningSiteId.landingBasin,
        rigs: const [MiningRigPlacement(tier: RigTier.t4, cell: cell)],
        selectedBayId: DockBayId.b1,
        dockBays: const {DockBayId.b1: RigTier.t4},
      );
      expect(view.upgradeableCells, {cell});
      await _pumpMap(tester, view, (_) {}, textScale: scale);

      expect(_chips(), findsOneWidget, reason: 'text scale $scale');
      expect(_rigSemanticsNodes(), findsOneWidget, reason: 'text scale $scale');
      final chip = find.byKey(_chipKey(cell));
      chipHeights.add(tester.getRect(chip).height);
      final label = find.descendant(of: chip, matching: find.byType(Text));
      expect(tester.widget<Text>(label).data, 'T4→T5');
      expect(
        tester.getRect(label).height,
        greaterThanOrEqualTo(6),
        reason: 'text scale $scale',
      );

      expect(_chipFill(tester, cell), upgradeGold);
      final ink = _chipColor(tester, cell)!;
      expect(ink, darkInk);
      expect(
        _contrastRatio(ink, upgradeGold),
        greaterThanOrEqualTo(4.5),
        reason: 'text scale $scale',
      );
    }
    // The top-edge anchor has a fixed scene-space height: text scale changes
    // the label inside it, never the chip chrome.
    expect(chipHeights[1], chipHeights[0]);
  });

  testWidgets('never golds a chip while no dock rig is selected', (
    tester,
  ) async {
    const cell = MiningGridCell(0, 14);
    final view = _view(
      MiningSiteId.landingBasin,
      rigs: const [MiningRigPlacement(tier: RigTier.t1, cell: cell)],
    );
    expect(view.upgradeableCells, isEmpty);
    await _pumpMap(tester, view, (_) {});

    expect(_chipLabel(tester, cell), 'T1');
    expect(find.textContaining('→'), findsNothing);
  });

  testWidgets('keeps a below-rig damage label clear of the tier chip', (
    tester,
  ) async {
    // A legal rig below the pocket at (0,20) has its strike midpoint label
    // exactly on the rig cell's top edge, where the top-anchored chip paints.
    const rigCell = MiningGridCell(0, 21);
    const damageKey = Key('landing-basin-damage-0-21');
    await warmDepositFrames(tester, MiningDepositFrames.gold);
    final view = _view(
      MiningSiteId.landingBasin,
      rigs: const [MiningRigPlacement(tier: RigTier.t1, cell: rigCell)],
    );
    for (final scale in [1.0, 1.3, 2.0]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpMap(
        tester,
        view,
        (_) {},
        impactSequence: 0,
        reducedMotion: true,
        textScale: scale,
      );
      await _pumpMap(
        tester,
        view,
        (_) {},
        impactSequence: 1,
        reducedMotion: true,
        textScale: scale,
      );
      await tester.pump(const Duration(milliseconds: 470));

      final label = find.byKey(damageKey);
      expect(label, findsOneWidget, reason: 'text scale $scale');
      final chip = tester.getRect(find.byKey(_chipKey(rigCell)));
      final damage = tester.getRect(label);
      expect(
        chip.overlaps(damage),
        isFalse,
        reason: 'text scale $scale: chip $chip overlaps damage label $damage',
      );
      expect(
        damage.bottom,
        lessThanOrEqualTo(chip.top),
        reason: 'text scale $scale',
      );
    }
  }, skip: kIsWeb);

  testWidgets('draws one static Motherlode halo behind the object layer', (
    tester,
  ) async {
    for (final siteId in [MiningSiteId.landingBasin, staticMiningSiteId]) {
      await _pumpMap(tester, _view(siteId), (_) {}, reducedMotion: false);
      expect(
        find.byKey(const Key('mining-motherlode-halo')),
        findsOneWidget,
        reason: siteId.name,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('mining-motherlode-halo')),
          matching: find.byType(TickerMode),
        ),
        findsNothing,
        reason: 'the halo never gets a ticker',
      );
    }

    await _pumpMap(tester, _view(MiningSiteId.landingBasin), (_) {});
    expect(find.byKey(const Key('mining-motherlode-halo')), findsNothing);
  });

  testWidgets('depth rail exposes four semantic targets and scrolls bands', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pumpMap(
      tester,
      _view(MiningSiteId.landingBasin),
      (_) {},
      size: const Size(390, 844),
      viewportInsets: const EdgeInsets.fromLTRB(58, 100, 96, 196),
    );

    for (final band in MiningBand.values) {
      expect(find.byKey(Key('mining-depth-rail-${band.name}')), findsOneWidget);
    }
    expect(find.bySemanticsLabel('Jump to Pockets band'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Jump to Lodes band. Requires Surveying 1.'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Jump to Motherlode band. Requires Surveying 2.'),
      findsOneWidget,
    );

    tester.semantics.performAction(
      find.semantics.byLabel('Jump to Pockets band'),
      SemanticsAction.tap,
    );
    await tester.pumpAndSettle();
    expect(
      _position(tester).pixels,
      closeTo(
        math.min(
          100 +
              18 *
                  miningGridCellSize *
                  (390 / miningGridSceneWidth).clamp(0.0, 1.0),
          _position(tester).maxScrollExtent,
        ),
        .5,
      ),
    );
    handle.dispose();
  });

  testWidgets('depth rail Tab traversal reaches each band once and activates', (
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

    MiningBand focusedBand() {
      final context = FocusManager.instance.primaryFocus!.context!;
      final focused = find.byElementPredicate(
        (element) => identical(element, context),
      );
      for (final band in MiningBand.values) {
        if (find
            .ancestor(
              of: focused,
              matching: find.byKey(Key('mining-depth-rail-${band.name}')),
            )
            .evaluate()
            .isNotEmpty) {
          return band;
        }
      }
      fail('no depth rail target owns the focused node');
    }

    double target(MiningBand band) => math.min(
      insets.top +
          band.labelRow *
              miningGridCellSize *
              (390 / miningGridSceneWidth).clamp(0.0, 1.0),
      _position(tester).maxScrollExtent,
    );

    final visited = <MiningBand>[];
    for (var i = 0; i < MiningBand.values.length; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final band = focusedBand();
      expect(visited, isNot(contains(band)), reason: 'duplicate Tab stop');
      visited.add(band);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(
        _position(tester).pixels,
        closeTo(target(band), .5),
        reason: '${band.name} Enter activation',
      );
    }
    expect(visited.toSet(), MiningBand.values.toSet());
  });

  testWidgets('uses the scale-aware target from a nonzero top padding', (
    tester,
  ) async {
    const insets = EdgeInsets.only(top: 50, bottom: 50);
    await _pumpMap(
      tester,
      _view(MiningSiteId.landingBasin),
      (_) {},
      size: const Size(430, 423),
      viewportInsets: insets,
    );

    final scale = 430 / miningGridSceneWidth;
    final maxExtent = _position(tester).maxScrollExtent;
    final seamsTarget = 50 + MiningBand.seams.labelRow * 56 * scale;
    expect(seamsTarget, lessThan(maxExtent), reason: 'target must be clear');
    expect(_position(tester).pixels, closeTo(seamsTarget, .5));

    // The Motherlode row 0 target is exactly the top padding, not zero.
    await tester.tap(find.byKey(const Key('mining-depth-rail-motherlode')));
    await tester.pump();
    expect(_position(tester).pixels, 50);
  });

  testWidgets('retargets an in-flight rail jump after a viewport change', (
    tester,
  ) async {
    await _pumpMap(
      tester,
      _view(MiningSiteId.landingBasin),
      (_) {},
      size: const Size(390, 844),
      reducedMotion: false,
    );

    // The entry frame already sits at the Pockets target (the maximum
    // extent), which would no-op the jump; start from the top so the rail
    // tap produces a real in-flight animation.
    _position(tester).jumpTo(0);
    await tester.pump();
    await tester.tap(find.byKey(const Key('mining-depth-rail-pockets')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100)); // mid-flight

    // The band's scale-aware target moves with the new scale and extent; the
    // jump must not land on the stale 228.5dp offset.
    tester.view.physicalSize = const Size(480, 350);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // finish the jump

    final position = _position(tester);
    expect(position.pixels, closeTo(position.maxScrollExtent, .5));
  });

  testWidgets('keeps a vertical rail with reduced gaps above 176dp plus the '
      'reserved bottom row', (tester) async {
    Future<List<Rect>> pumpRail(double top, double bottom) async {
      await _pumpMap(
        tester,
        _view(MiningSiteId.landingBasin),
        (_) {},
        size: const Size(390, 844),
        railTop: top,
        railBottom: bottom,
      );
      return [
        for (final band in _depthOrder())
          tester.getRect(find.byKey(Key('mining-depth-rail-${band.name}'))),
      ];
    }

    // A 248.75dp clear band leaves a 48.75dp bottom-row reserve and 200dp of
    // rail room: one column, gaps shrink to 8 so the four 44dp targets fit.
    // Map-depth order puts the Motherlode target first.
    var buttons = await pumpRail(100, 348.75);
    expect(buttons.map((rect) => rect.left).toSet(), hasLength(1));
    for (var i = 0; i < buttons.length; i++) {
      expect(buttons[i].height, greaterThanOrEqualTo(44 - .01));
      if (i > 0) {
        expect(buttons[i].top - buttons[i - 1].bottom, 8);
        expect(buttons[i].overlaps(buttons[i - 1]), isFalse);
      }
    }
    expect(buttons.first.top, 100);
    expect(buttons.last.bottom, 300);
    expect(
      buttons.last.bottom,
      lessThanOrEqualTo(
        348.75 - miningGridCellSize * 390 / miningGridSceneWidth,
      ),
    );

    // 200dp fits four vertical targets but not the reserved bottom row: the
    // rail falls back to the high horizontal row instead of covering the
    // bottom-right cell's scrollable strip.
    buttons = await pumpRail(100, 300);
    expect(buttons.map((rect) => rect.top).toSet(), hasLength(1));
    expect(buttons.map((rect) => rect.left).toSet(), hasLength(4));
    for (final button in buttons) {
      expect(button.height, greaterThanOrEqualTo(44 - .01));
      expect(button.bottom, lessThanOrEqualTo(100 + 44 + .01));
    }
  });

  testWidgets('uses one high horizontal row of 44dp targets below 176dp', (
    tester,
  ) async {
    await _pumpMap(
      tester,
      _view(MiningSiteId.landingBasin),
      (_) {},
      size: const Size(390, 844),
      railTop: 134,
      railBottom: 289,
    );
    final rail = tester.getRect(find.byKey(const Key('mining-depth-rail')));
    final buttons = [
      for (final band in _depthOrder())
        tester.getRect(find.byKey(Key('mining-depth-rail-${band.name}'))),
    ];

    // 155dp measured band: four independent 44dp targets sit high in one
    // row, leaving the band below clear for map interaction.
    expect(rail.top, 134);
    expect(rail.height, 44);
    expect(rail.width, 200);
    expect(rail.right, lessThanOrEqualTo(390 - 8 + .01));
    expect(buttons.map((rect) => rect.top).toSet(), hasLength(1));
    expect(buttons.map((rect) => rect.left).toSet(), hasLength(4));
    // The horizontal row reads left-to-right in the same map-depth order.
    for (var i = 1; i < buttons.length; i++) {
      expect(buttons[i].left, greaterThan(buttons[i - 1].right));
    }
    for (var i = 0; i < buttons.length; i++) {
      expect(buttons[i].width, greaterThanOrEqualTo(44 - .01));
      expect(buttons[i].height, greaterThanOrEqualTo(44 - .01));
      expect(buttons[i].bottom, lessThanOrEqualTo(rail.bottom + .01));
      for (var j = i + 1; j < buttons.length; j++) {
        expect(
          buttons[i].overlaps(buttons[j]),
          isFalse,
          reason: 'horizontal targets $i and $j overlap',
        );
      }
    }

    // The measured 360x640 worst case has only 108dp: the 44dp row still
    // leaves 64dp of clear band below it for the bottom-right cell.
    await _pumpMap(
      tester,
      _view(MiningSiteId.landingBasin),
      (_) {},
      size: const Size(390, 844),
      railTop: 181,
      railBottom: 289,
    );
    final worstRail = tester.getRect(
      find.byKey(const Key('mining-depth-rail')),
    );
    expect(worstRail.top, 181);
    expect(worstRail.height, 44);
    expect(worstRail.bottom, lessThanOrEqualTo(289 - 44));

    // The horizontal arrangement keeps the same semantic and keyboard path.
    final handle = tester.ensureSemantics();
    expect(
      find.bySemanticsLabel('Jump to Lodes band. Requires Surveying 1.'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Jump to Motherlode band. Requires Surveying 2.'),
      findsOneWidget,
    );
    // The target widgets are the same shared focusable button used by the
    // dedicated keyboard test; the horizontal layout only changes position.
    expect(
      find.byKey(const Key('mining-depth-rail-button-motherlode')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets(
    'rail markers identify every band in map-depth order and navigate',
    (tester) async {
      const insets = EdgeInsets.fromLTRB(58, 100, 96, 196);
      await _pumpMap(
        tester,
        _view(MiningSiteId.landingBasin),
        (_) {},
        size: const Size(390, 844),
        viewportInsets: insets,
      );

      final order = _depthOrder();
      final buttons = [
        for (final band in order)
          tester.getRect(find.byKey(Key('mining-depth-rail-${band.name}'))),
      ];
      for (var i = 1; i < buttons.length; i++) {
        expect(
          buttons[i].top,
          greaterThan(buttons[i - 1].bottom),
          reason: '${order[i].name} must sit below ${order[i - 1].name}',
        );
      }

      final letters = <String>{};
      for (final band in const [
        MiningBand.pockets,
        MiningBand.seams,
        MiningBand.lodes,
      ]) {
        final marker = find.byKey(Key('mining-depth-marker-${band.name}'));
        expect(marker, findsOneWidget, reason: band.name);
        letters.add(tester.widget<Text>(marker).data!);
      }
      expect(letters, {'P', 'S', 'L'});
      expect(
        tester
            .widget<Icon>(
              find.byKey(const Key('mining-depth-marker-motherlode')),
            )
            .icon,
        Icons.auto_awesome,
      );

      final surface = _surfaceRect(tester);
      final scale = surface.width / miningGridSceneWidth;
      for (final band in order) {
        await tester.tap(find.byKey(Key('mining-depth-rail-${band.name}')));
        await tester.pump();
        expect(
          _position(tester).pixels,
          closeTo(
            math.min(
              insets.top + band.labelRow * miningGridCellSize * scale,
              _position(tester).maxScrollExtent,
            ),
            .5,
          ),
          reason: '${band.name} rail target',
        );
      }
    },
  );

  testWidgets('reduced motion jumps the rail and hides the halo', (
    tester,
  ) async {
    await _pumpMap(
      tester,
      _view(MiningSiteId.landingBasin),
      (_) {},
      size: const Size(390, 844),
      viewportInsets: const EdgeInsets.fromLTRB(58, 100, 96, 196),
    );
    expect(find.byKey(const Key('mining-motherlode-halo')), findsNothing);

    final before = _position(tester).pixels;
    await tester.tap(find.byKey(const Key('mining-depth-rail-motherlode')));
    await tester.pump();
    final after = _position(tester).pixels;
    expect(after, isNot(before));
    expect(after, 100);
  });

  testWidgets('draws the 4x4 Motherlode and one halo on every site', (
    tester,
  ) async {
    for (final siteId in MiningSiteId.values) {
      await _pumpMap(tester, _view(siteId), (_) {}, reducedMotion: false);
      expect(
        find.byKey(const Key('mining-deposit-2-2-4')),
        findsOneWidget,
        reason: siteId.name,
      );
      expect(
        find.byKey(const Key('mining-motherlode-halo')),
        findsOneWidget,
        reason: siteId.name,
      );
      if (MiningVisuals.depositFramesFor(siteId) == null) {
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                widget.image is AssetImage &&
                (widget.image as AssetImage).assetName ==
                    _content.site(siteId).depositAsset,
          ),
          findsWidgets,
          reason: siteId.name,
        );
      }
    }
  });

  testWidgets('depth rail only absorbs pointers on its four targets', (
    tester,
  ) async {
    final taps = <MiningGridCell>[];
    await _pumpMap(
      tester,
      _view(MiningSiteId.landingBasin),
      taps.add,
      size: const Size(390, 844),
      viewportInsets: const EdgeInsets.fromLTRB(58, 100, 96, 196),
    );

    final rail = tester.getRect(find.byKey(const Key('mining-depth-rail')));
    // The region beside the 44dp target column is pointer transparent: the
    // map gesture surface still resolves the cell below.
    await tester.tapAt(Offset(rail.left - 4, rail.top + 4));
    await tester.pump();
    expect(taps, hasLength(1));
  });

  test('paints a gold upgrade ring and keeps the cyan deploy fill', () {
    const deploy = MiningGridCell(1, 1);
    const upgrade = MiningGridCell(2, 1);
    final painter = MiningGridPainter(
      width: 4,
      height: 4,
      deployableCells: {deploy},
      upgradeableCells: {upgrade},
    );
    final canvas = _RecordingCanvas();
    painter.paint(canvas, const Size(224, 224));

    final fill = canvas.rects.singleWhere(
      (entry) => entry.$2.style == PaintingStyle.fill,
    );
    expect(fill.$1, const Rect.fromLTWH(56, 56, 56, 56));
    expect(
      fill.$2.color.toARGB32(),
      const Color.fromRGBO(83, 212, 232, .16).toARGB32(),
    );

    final ring = canvas.rects.singleWhere(
      (entry) => entry.$2.style == PaintingStyle.stroke,
    );
    expect(ring.$1, const Rect.fromLTWH(112, 56, 56, 56).deflate(1));
    expect(ring.$2.color.toARGB32(), 0xFFF5B44C);
    expect(ring.$2.strokeWidth, 2);
  });

  testWidgets('routes a chip tap through the existing map gesture surface', (
    tester,
  ) async {
    const cell = MiningGridCell(0, 14);
    final taps = <MiningGridCell>[];
    await _pumpMap(
      tester,
      _view(
        MiningSiteId.landingBasin,
        rigs: const [MiningRigPlacement(tier: RigTier.t1, cell: cell)],
      ),
      taps.add,
    );

    expect(
      find.descendant(
        of: find.byKey(const Key('mining-grid-surface')),
        matching: find.byType(GestureDetector),
      ),
      findsOneWidget,
    );
    await _revealCell(tester, cell);
    // Tap the rendered chip itself (its top 18px), not the cell centre.
    await tester.tapAt(tester.getCenter(find.byKey(_chipKey(cell))));
    await tester.pump();
    expect(taps.single, cell);
  });

  testWidgets('keeps top-anchored chips clear of mined 1x1 and 3x3 HP', (
    tester,
  ) async {
    // (0,19) mines the pocket above; (1,8) mines the 3x3 lode below.
    const oneByOneRig = MiningGridCell(0, 19);
    const threeByThreeRig = MiningGridCell(1, 8);
    final view = _view(
      MiningSiteId.landingBasin,
      surveying: 2,
      rigs: const [
        MiningRigPlacement(tier: RigTier.t1, cell: oneByOneRig),
        MiningRigPlacement(tier: RigTier.t1, cell: threeByThreeRig),
      ],
    );
    await _pumpMap(tester, view, (_) {});

    final surface = _surfaceRect(tester);
    final scale = _sceneScale(tester);
    final hpByRig = {
      oneByOneRig: const Key('landing-basin-hp-0-20-1'),
      threeByThreeRig: const Key('landing-basin-hp-0-9-3'),
    };
    for (final entry in hpByRig.entries) {
      final chip = tester.getRect(find.byKey(_chipKey(entry.key)));
      final hp = tester.getRect(find.byKey(entry.value));
      expect(
        chip.overlaps(hp),
        isFalse,
        reason: '${entry.key} chip $chip overlaps HP $hp',
      );
      expect(
        chip.topLeft,
        surface.topLeft +
            Offset(
              entry.key.x * miningGridCellSize * scale,
              entry.key.y * miningGridCellSize * scale,
            ),
        reason: '${entry.key}',
      );
    }
  });
}

/// Records only rect paints: the grid painter's cell fills and upgrade ring.
class _RecordingCanvas implements ui.Canvas {
  final rects = <(Rect, Paint)>[];

  @override
  void drawRect(Rect rect, Paint paint) => rects.add((rect, paint));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
