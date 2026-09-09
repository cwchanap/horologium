import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mine_site_view.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_grid.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:horologium/mining/presentation/landing_basin_grid_visual_layer.dart';
import 'package:horologium/mining/presentation/mining_visuals.dart';

final _content = MiningContentRegistry.stellarMining();
final _start = DateTime.utc(2026, 8, 26, 12);
const _defaultCell = MiningGridCell(2, 3);

MineSiteView _view({
  RigTier rigTier = RigTier.t1,
  MiningGridCell cell = _defaultCell,
  bool withRig = true,
  double progress = 0,
  List<(RigTier, MiningGridCell)> rigs = const [],
}) {
  final placements = [
    if (rigs.isNotEmpty)
      ...rigs.map((entry) => MiningRigPlacement(tier: entry.$1, cell: entry.$2))
    else if (withRig)
      MiningRigPlacement(tier: rigTier, cell: cell),
  ];
  final initial = MiningSave.initial(nowUtc: _start);
  final tiers = placements.map((placement) => placement.tier).toList();
  final capacity = _content.effectiveSiteCapacity(
    MiningSiteId.landingBasin,
    tiers,
    0,
  );
  final state = initial.copyWith(
    sites: {
      ...initial.sites,
      MiningSiteId.landingBasin: initial.sites[MiningSiteId.landingBasin]!
          .copyWith(
            unlocked: true,
            commissioned: true,
            storedAmount: (progress * capacity).clamp(0.0, capacity),
            rigPlacements: placements,
          ),
    },
  );
  return MineSiteView.from(
    state: state,
    content: _content,
    siteId: MiningSiteId.landingBasin,
    selectedBayId: null,
    isBusy: false,
  );
}

Future<void> _pumpLayer(
  WidgetTester tester, {
  RigTier rigTier = RigTier.t1,
  MiningGridCell cell = _defaultCell,
  bool withRig = true,
  double progress = 0,
  int impactSequence = 0,
  bool reducedMotion = false,
  List<(RigTier, MiningGridCell)> rigs = const [],
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 932);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: LandingBasinGridVisualLayer(
        view: _view(
          rigTier: rigTier,
          cell: cell,
          withRig: withRig,
          progress: progress,
          rigs: rigs,
        ),
        impactSequence: impactSequence,
        reducedMotion: reducedMotion,
        cellSize: 56,
      ),
    ),
  );
  await tester.pump();
}

Animation<double>? _depositOpacity(WidgetTester tester, {String id = 'd1'}) =>
    tester
        .widget<Image>(
          find.descendant(
            of: find.byKey(Key('landing-basin-deposit-$id')),
            matching: find.byType(Image),
          ),
        )
        .opacity;

String _depositAsset(WidgetTester tester, {String id = 'd1'}) {
  final images = tester
      .widgetList<Image>(
        find.descendant(
          of: find.byKey(Key('landing-basin-deposit-$id')),
          matching: find.byType(Image),
        ),
      )
      .toList();
  expect(images, hasLength(1));
  final image = images.single.image;
  expect(image, isA<AssetImage>());
  return (image as AssetImage).assetName;
}

String _robotCellKey(MiningGridCell cell) =>
    'landing-basin-robot-${cell.x}-${cell.y}';

Key _robotKey(MiningGridCell cell) => Key(_robotCellKey(cell));

Transform _robotFlipTransform(WidgetTester tester, MiningGridCell cell) =>
    tester.widget<Transform>(
      find.byKey(Key('landing-basin-robot-flip-${cell.x}-${cell.y}')),
    );

Transform _robotBodyTransform(WidgetTester tester, MiningGridCell cell) =>
    tester.widget<Transform>(
      find.byKey(Key('landing-basin-robot-body-transform-${cell.x}-${cell.y}')),
    );

Transform _robotArmTransform(WidgetTester tester, MiningGridCell cell) =>
    tester.widget<Transform>(
      find.byKey(Key('landing-basin-robot-arm-transform-${cell.x}-${cell.y}')),
    );

// Resolve the finite gold frame set in real async before the layer mounts,
// so its _precacheFrames Future.wait completes from cache hits and
// _framesReady becomes true via actual precache completion (the deferral
// budget drops a stalled impact, it does not fire it). A bare host gives
// precacheImage a Directionality context; the global image cache persists
// across the subsequent pumpWidget that mounts the layer.
Future<void> warmGoldFrames(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
  final context = tester.element(find.byType(MaterialApp));
  await tester.runAsync(() async {
    for (final path in [
      for (var stage = 1; stage <= 4; stage++)
        MiningVisuals.goldNodeStageAsset(stage),
      for (var frame = 1; frame <= 4; frame++)
        MiningVisuals.goldNodeIdleAsset(frame),
      for (var frame = 1; frame <= 3; frame++)
        MiningVisuals.goldNodeHitAsset(frame),
      for (var frame = 1; frame <= 4; frame++)
        MiningVisuals.goldNodeExhaustAsset(frame),
    ]) {
      await precacheImage(AssetImage(path), context);
    }
  });
  await tester.pump();
}

void main() {
  // The layer defers its first one-shot impact until the finite gold frames
  // finish precaching, and readiness is tied only to actual Future.wait
  // completion (the deferral budget drops a stalled impact, it does not fire
  // it). In the fake-async test environment a cold image cache never decodes
  // those frames, so impact tests warm the finite frame set in real async via
  // [warmGoldFrames] before mounting the layer. Clearing the cache before each
  // test keeps non-impact tests cold and deterministic.
  setUp(() {
    imageCache.clear();
    imageCache.clearLiveImages();
  });

  testWidgets('renders the staged plate and omits the rig without a rig', (
    tester,
  ) async {
    await _pumpLayer(tester, withRig: false, reducedMotion: true);

    expect(find.byKey(const Key('landing-basin-deposit-d1')), findsOneWidget);
    expect(find.byKey(_robotKey(_defaultCell)), findsNothing);
    expect(_depositAsset(tester), MiningVisuals.goldNodeStageAsset(1));
  });

  testWidgets('animates only the mined deposit and keeps others static', (
    tester,
  ) async {
    // The default rig at (2,3) mines d1 only: d1 runs its idle loop while
    // unmined d2 stays on its static stage plate.
    await _pumpLayer(tester, reducedMotion: false);
    expect(_depositAsset(tester, id: 'd1'), MiningVisuals.goldNodeIdleAsset(1));
    expect(
      _depositAsset(tester, id: 'd2'),
      MiningVisuals.goldNodeStageAsset(1),
    );

    await tester.pump(const Duration(milliseconds: 125));
    expect(_depositAsset(tester, id: 'd1'), MiningVisuals.goldNodeIdleAsset(2));
    expect(
      _depositAsset(tester, id: 'd2'),
      MiningVisuals.goldNodeStageAsset(1),
    );
  });

  testWidgets('dims only deposits without a miner', (tester) async {
    await _pumpLayer(tester, reducedMotion: true);

    expect(_depositOpacity(tester, id: 'd1'), isNull);
    final dimmed = _depositOpacity(tester, id: 'd2');
    expect(dimmed, isA<AlwaysStoppedAnimation<double>>());
    expect(dimmed!.value, .62);
  });

  testWidgets('keeps gapless playback on the changing deposit image', (
    tester,
  ) async {
    await _pumpLayer(tester);

    final image = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const Key('landing-basin-deposit-d1')),
        matching: find.byType(Image),
      ),
    );

    expect(image.gaplessPlayback, isTrue);
  });

  testWidgets('selects the staged gold plate at progress boundaries', (
    tester,
  ) async {
    final cases = {
      0.0: 'assets/images/mining/nodes/node-gold-s1.png',
      .249: 'assets/images/mining/nodes/node-gold-s1.png',
      .25: 'assets/images/mining/nodes/node-gold-s2.png',
      .599: 'assets/images/mining/nodes/node-gold-s2.png',
      .60: 'assets/images/mining/nodes/node-gold-s3.png',
      .899: 'assets/images/mining/nodes/node-gold-s3.png',
      .90: 'assets/images/mining/nodes/node-gold-s4.png',
      1.0: 'assets/images/mining/nodes/node-gold-s4.png',
    };

    for (final entry in cases.entries) {
      await _pumpLayer(tester, progress: entry.key, reducedMotion: true);
      expect(_depositAsset(tester), entry.value);
    }
  });

  testWidgets('loops the four S1 idle frames every 125ms', (tester) async {
    await _pumpLayer(tester, reducedMotion: false);
    expect(_depositAsset(tester), MiningVisuals.goldNodeIdleAsset(1));

    await tester.pump(const Duration(milliseconds: 125));
    expect(_depositAsset(tester), MiningVisuals.goldNodeIdleAsset(2));
    await tester.pump(const Duration(milliseconds: 125));
    expect(_depositAsset(tester), MiningVisuals.goldNodeIdleAsset(3));
    await tester.pump(const Duration(milliseconds: 125));
    expect(_depositAsset(tester), MiningVisuals.goldNodeIdleAsset(4));
    await tester.pump(const Duration(milliseconds: 125));
    expect(_depositAsset(tester), MiningVisuals.goldNodeIdleAsset(1));
  });

  testWidgets('stops the idle loop outside S1', (tester) async {
    await _pumpLayer(tester, progress: 0);
    await tester.pump(const Duration(milliseconds: 125));
    expect(_depositAsset(tester), MiningVisuals.goldNodeIdleAsset(2));

    await _pumpLayer(tester, progress: .25);
    expect(_depositAsset(tester), MiningVisuals.goldNodeStageAsset(2));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_depositAsset(tester), MiningVisuals.goldNodeStageAsset(2));

    await _pumpLayer(tester, progress: 0);
    expect(_depositAsset(tester), MiningVisuals.goldNodeIdleAsset(1));
  });

  testWidgets(
    'selects every S1 hit frame while the chassis stays fixed',
    (tester) async {
      await warmGoldFrames(tester);
      await _pumpLayer(tester, impactSequence: 0);
      final restBody = _robotBodyTransform(tester, _defaultCell).transform;
      final restArm = _robotArmTransform(tester, _defaultCell).transform;

      // With the finite frames warmed, _framesReady is true and the one-shot
      // impact fires immediately on the sequence change (no deferral budget).
      // Advance into the S1 hit window and step through the three hit frames.
      await _pumpLayer(tester, impactSequence: 1);
      await tester.pump(const Duration(milliseconds: 240));
      expect(_depositAsset(tester), MiningVisuals.goldNodeHitAsset(1));
      // The impact one-shot animates the mined d1, never unmined d2.
      expect(
        _depositAsset(tester, id: 'd2'),
        MiningVisuals.goldNodeStageAsset(1),
      );
      expect(
        _robotBodyTransform(tester, _defaultCell).transform,
        equals(restBody),
      );
      expect(
        _robotArmTransform(tester, _defaultCell).transform,
        isNot(equals(restArm)),
      );

      await tester.pump(const Duration(milliseconds: 84));
      expect(_depositAsset(tester), MiningVisuals.goldNodeHitAsset(2));
      expect(
        _robotBodyTransform(tester, _defaultCell).transform,
        equals(restBody),
      );
      expect(
        _robotArmTransform(tester, _defaultCell).transform,
        isNot(equals(restArm)),
      );

      await tester.pump(const Duration(milliseconds: 84));
      expect(_depositAsset(tester), MiningVisuals.goldNodeHitAsset(3));
      expect(
        _robotBodyTransform(tester, _defaultCell).transform,
        equals(restBody),
      );
      expect(
        _robotArmTransform(tester, _defaultCell).transform,
        isNot(equals(restArm)),
      );
    },
    // Finite-frame precache needs the VM asset channel; frame selection is
    // pure Dart covered on VM. The cold-cache drop path is covered on web.
    skip: kIsWeb,
  );

  testWidgets(
    'plays exhaust frames only when progress crosses into S4',
    (tester) async {
      await warmGoldFrames(tester);
      await _pumpLayer(tester, progress: .899, impactSequence: 0);
      expect(_depositAsset(tester), MiningVisuals.goldNodeStageAsset(3));

      // With the finite frames warmed, _framesReady is true and the exhaust
      // one-shot fires immediately on the sequence change. The controller parks
      // at value 0 so the S3 wind-up hold shows before the exhaust window.
      await _pumpLayer(tester, progress: .90, impactSequence: 1);
      expect(_depositAsset(tester), MiningVisuals.goldNodeStageAsset(3));

      await tester.pump(const Duration(milliseconds: 240));
      expect(_depositAsset(tester), MiningVisuals.goldNodeExhaustAsset(1));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_depositAsset(tester), MiningVisuals.goldNodeExhaustAsset(2));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_depositAsset(tester), MiningVisuals.goldNodeExhaustAsset(3));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_depositAsset(tester), MiningVisuals.goldNodeExhaustAsset(4));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_depositAsset(tester), MiningVisuals.goldNodeStageAsset(4));

      await _pumpLayer(tester, progress: 0, impactSequence: 1);
      expect(_depositAsset(tester), MiningVisuals.goldNodeIdleAsset(1));
    },
    // Finite-frame precache needs the VM asset channel; frame selection is
    // pure Dart covered on VM. The cold-cache drop path is covered on web.
    skip: kIsWeb,
  );

  // The deferral budget drops a stalled first impact instead of firing it
  // against unresolved frames. Readiness stays tied to actual precache
  // completion, so a >budget decode keeps the grid static. Runs on both VM
  // and web since it needs no real image decode (the cache stays cold on
  // purpose).
  testWidgets(
    'drops a stalled first impact and keeps the node static on a cold cache',
    (tester) async {
      await _pumpLayer(tester, impactSequence: 0);
      await _pumpLayer(tester, impactSequence: 1);
      // The impact is deferred while the finite frames are still cold. Pumping
      // the deferral budget drops it without marking ready or firing the
      // one-shot, so the deposit stays on its resting S1 idle loop (never a
      // hit or exhaust frame) and the controller rests at value 1.
      await tester.pump(const Duration(milliseconds: 200));
      final idleFrames = {
        for (var f = 1; f <= 4; f++) MiningVisuals.goldNodeIdleAsset(f),
      };
      final impactFrames = {
        for (var f = 1; f <= 3; f++) MiningVisuals.goldNodeHitAsset(f),
        for (var f = 1; f <= 4; f++) MiningVisuals.goldNodeExhaustAsset(f),
      };
      expect(idleFrames, contains(_depositAsset(tester)));
      expect(impactFrames, isNot(contains(_depositAsset(tester))));

      // A second impact while still cold defers and drops again; no historical
      // replay and no frame ever advances into the hit/exhaust window.
      await _pumpLayer(tester, impactSequence: 2);
      await tester.pump(const Duration(milliseconds: 200));
      expect(idleFrames, contains(_depositAsset(tester)));
      expect(impactFrames, isNot(contains(_depositAsset(tester))));
    },
  );

  testWidgets(
    'reduced motion keeps the static stage and rig transforms fixed',
    (tester) async {
      await _pumpLayer(tester, reducedMotion: true, impactSequence: 0);
      final restFlip = _robotFlipTransform(tester, _defaultCell).transform;
      final restBody = _robotBodyTransform(tester, _defaultCell).transform;
      final restArm = _robotArmTransform(tester, _defaultCell).transform;

      await _pumpLayer(tester, reducedMotion: true, impactSequence: 1);
      await tester.pump(const Duration(milliseconds: 500));

      expect(_depositAsset(tester), MiningVisuals.goldNodeStageAsset(1));
      expect(
        _robotFlipTransform(tester, _defaultCell).transform,
        equals(restFlip),
      );
      expect(
        _robotBodyTransform(tester, _defaultCell).transform,
        equals(restBody),
      );
      expect(
        _robotArmTransform(tester, _defaultCell).transform,
        equals(restArm),
      );
    },
  );

  testWidgets('does not expose obsolete procedural effect keys', (
    tester,
  ) async {
    await _pumpLayer(tester, impactSequence: 1);
    await tester.pump(const Duration(milliseconds: 300));

    for (final key in [
      'landing-basin-impact-2-3',
      'landing-basin-sparks-2-3',
      'landing-basin-rock-chips-2-3',
      'landing-basin-dust-2-3',
      'landing-basin-gold-glow-2-3',
    ]) {
      expect(find.byKey(Key(key)), findsNothing);
    }
  });

  testWidgets('disposes both animation controllers when removed', (
    tester,
  ) async {
    await _pumpLayer(tester, reducedMotion: false, impactSequence: 1);
    await tester.pump(const Duration(milliseconds: 100));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('selects articulated body and arm layers for every rig tier', (
    tester,
  ) async {
    for (final tier in RigTier.values) {
      await _pumpLayer(tester, rigTier: tier, reducedMotion: true);

      final bodyImage = tester.widget<Image>(
        find.descendant(
          of: find.byKey(Key('landing-basin-robot-body-transform-2-3')),
          matching: find.byType(Image),
        ),
      );
      final armImage = tester.widget<Image>(
        find.descendant(
          of: find.byKey(Key('landing-basin-robot-arm-transform-2-3')),
          matching: find.byType(Image),
        ),
      );

      expect(
        (bodyImage.image as AssetImage).assetName,
        MiningVisuals.landingBasinRobotBodyAsset(tier),
      );
      expect(
        (armImage.image as AssetImage).assetName,
        MiningVisuals.landingBasinRobotArmAsset(tier),
      );
    }
  });

  testWidgets('pins the arm rotation to the authored shoulder pivot', (
    tester,
  ) async {
    await _pumpLayer(tester);

    expect(
      _robotArmTransform(tester, _defaultCell).alignment,
      const Alignment(.33, -.24),
    );
  });

  testWidgets('mirrors the robot only when the deposit sits to its right', (
    tester,
  ) async {
    // d1 occupies (3,3) with size 1, so its center-X is 3.5. Rig cells to the
    // left/right of the deposit make the target center-X sit right/left of the
    // rig; above/below cells keep the center-X equal. Expected mirrors:
    // right-of-deposit -> false, left-of-deposit -> true, above -> false,
    // below -> false.
    final cases = <(MiningGridCell, bool)>[
      (const MiningGridCell(4, 3), false),
      (const MiningGridCell(2, 3), true),
      (const MiningGridCell(3, 2), false),
      (const MiningGridCell(3, 4), false),
    ];

    for (final (cell, expectedMirror) in cases) {
      await _pumpLayer(tester, cell: cell, reducedMotion: true);
      final flip = _robotFlipTransform(tester, cell).transform.storage[0];
      expect(flip, expectedMirror ? -1 : 1, reason: '$cell');
    }
  });
}
