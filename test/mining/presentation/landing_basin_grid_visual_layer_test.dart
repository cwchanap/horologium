import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mine_site_view.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_grid.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:horologium/mining/presentation/landing_basin_grid_visual_layer.dart';
import 'package:horologium/mining/presentation/mining_visuals.dart';

import '../../support/mining_grid_fixtures.dart';
import '../../support/mining_visual_frames.dart';

final _content = MiningContentRegistry.stellarMining();
final _start = DateTime.utc(2026, 8, 26, 12);
const _defaultCell = MiningGridCell(2, 3);

final _landing = _content.site(MiningSiteId.landingBasin);

/// The default rig at (2,3) uniquely mines this authored 2x2 deposit at (1,1).
final _minedDeposit = _landing.deposits.first;

/// An authored deposit with no rig on it.
final _unminedDeposit = _landing.deposits[1];

final _deployableCells = deployableMiningCells(_landing);

Key _depositKey(MiningDepositDefinition deposit) =>
    Key('landing-basin-deposit-${deposit.x}-${deposit.y}-${deposit.size}');

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
  VoidCallback? onMiningImpact,
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
        onMiningImpact: onMiningImpact,
        reducedMotion: reducedMotion,
        cellSize: 56,
      ),
    ),
  );
  await tester.pump();
}

Animation<double>? _depositOpacity(
  WidgetTester tester, [
  MiningDepositDefinition? deposit,
]) => tester
    .widget<Image>(
      find.descendant(
        of: find.byKey(_depositKey(deposit ?? _minedDeposit)),
        matching: find.byType(Image),
      ),
    )
    .opacity;

String _depositAsset(WidgetTester tester, [MiningDepositDefinition? deposit]) {
  final images = tester
      .widgetList<Image>(
        find.descendant(
          of: find.byKey(_depositKey(deposit ?? _minedDeposit)),
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

  testWidgets(
    'emits one sound at a visible strike, never on load or reduced motion',
    (tester) async {
      await warmGoldFrames(tester);
      var impacts = 0;
      void onImpact() => impacts++;
      await _pumpLayer(tester, impactSequence: 8, onMiningImpact: onImpact);
      await tester.pump(const Duration(seconds: 1));
      expect(impacts, 0);
      await _pumpLayer(tester, impactSequence: 9, onMiningImpact: onImpact);
      await tester.pump(const Duration(milliseconds: 450));
      expect(impacts, 0);
      await tester.pump(const Duration(milliseconds: 20));
      expect(impacts, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(impacts, 1);
      await _pumpLayer(
        tester,
        impactSequence: 10,
        reducedMotion: true,
        onMiningImpact: onImpact,
      );
      await tester.pump(const Duration(seconds: 1));
      expect(impacts, 1);
      await _pumpLayer(tester, impactSequence: 11, onMiningImpact: onImpact);
      await _pumpLayer(
        tester,
        impactSequence: 11,
        withRig: false,
        onMiningImpact: onImpact,
      );
      await tester.pump(const Duration(seconds: 1));
      expect(impacts, 1);
      await _pumpLayer(tester, impactSequence: 12, onMiningImpact: onImpact);
      await tester.pump(const Duration(seconds: 1));
      expect(impacts, 1, reason: 'A missed strike must not play late.');
    },
    skip: kIsWeb,
  );

  testWidgets('renders the staged plate and omits the rig without a rig', (
    tester,
  ) async {
    await _pumpLayer(tester, withRig: false, reducedMotion: true);

    expect(find.byKey(_depositKey(_minedDeposit)), findsOneWidget);
    expect(find.byKey(_robotKey(_defaultCell)), findsNothing);
    expect(_depositAsset(tester), MiningVisuals.goldNodeStageAsset(1));
  });

  testWidgets('animates only the mined deposit and keeps others static', (
    tester,
  ) async {
    // The default rig at (2,3) mines the (1,1) deposit only: it runs its idle
    // loop while unmined deposits stay on their static stage plate.
    await _pumpLayer(tester, reducedMotion: false);
    expect(_depositAsset(tester), MiningVisuals.goldNodeIdleAsset(1));
    expect(
      _depositAsset(tester, _unminedDeposit),
      MiningVisuals.goldNodeStageAsset(1),
    );

    await tester.pump(const Duration(milliseconds: 125));
    expect(_depositAsset(tester), MiningVisuals.goldNodeIdleAsset(2));
    expect(
      _depositAsset(tester, _unminedDeposit),
      MiningVisuals.goldNodeStageAsset(1),
    );
  });

  testWidgets('renders two rigs targeting one resource without duplication', (
    tester,
  ) async {
    // Two legal perimeter cells of the same authored deposit: two robots may
    // mine one resource body, which renders exactly once and undimmed.
    final sharedCells = _deployableCells
        .where((cell) => _minedDeposit.isOrthogonallyAdjacent(cell))
        .take(2)
        .toList();
    expect(sharedCells, hasLength(2));

    await _pumpLayer(
      tester,
      rigs: [(RigTier.t1, sharedCells[0]), (RigTier.t2, sharedCells[1])],
      reducedMotion: true,
    );

    expect(find.byKey(_robotKey(sharedCells[0])), findsOneWidget);
    expect(find.byKey(_robotKey(sharedCells[1])), findsOneWidget);
    expect(find.byKey(_depositKey(_minedDeposit)), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(_depositKey(_minedDeposit)),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );
    expect(_depositOpacity(tester, _minedDeposit), isNull);
  });

  testWidgets('dims only deposits without a miner', (tester) async {
    await _pumpLayer(tester, reducedMotion: true);

    expect(_depositOpacity(tester), isNull);
    final dimmed = _depositOpacity(tester, _unminedDeposit);
    expect(dimmed, isA<AlwaysStoppedAnimation<double>>());
    expect(dimmed!.value, .62);
  });

  testWidgets('renders the three survey tiers on the deposit art', (
    tester,
  ) async {
    // Landing Basin progression levels are 0,0,1,2: at Surveying 0 the
    // default target and its surveyed unmined peer are visible while the
    // rest of the field is locked.
    final unsurveyed = _landing.deposits.firstWhere(
      (deposit) => deposit.requiredSurveyingLevel > 0,
    );
    await _pumpLayer(tester, reducedMotion: true);

    expect(_depositOpacity(tester, _minedDeposit), isNull);
    final surveyed = _depositOpacity(tester, _unminedDeposit);
    expect(surveyed, isA<AlwaysStoppedAnimation<double>>());
    expect(surveyed!.value, .62);
    final locked = _depositOpacity(tester, unsurveyed);
    expect(locked, isA<AlwaysStoppedAnimation<double>>());
    expect(locked!.value, .35);
  });

  testWidgets('keeps gapless playback on the changing deposit image', (
    tester,
  ) async {
    await _pumpLayer(tester);

    final image = tester.widget<Image>(
      find.descendant(
        of: find.byKey(_depositKey(_minedDeposit)),
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
      // The impact one-shot animates the mined deposit, never unmined ones.
      expect(
        _depositAsset(tester, _unminedDeposit),
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
    // The default target occupies (1,1) with size 2, so its center-X is 2.0.
    // The robot mirrors whenever that center sits right of the rig cell so
    // the arm strikes toward the resource; the chassis never rotates
    // vertically for deposits above or below.
    final cases = <(MiningGridCell, bool)>[
      // Right of the deposit: target center is left of the rig.
      (const MiningGridCell(3, 1), false),
      // Left of the deposit: target center is right of the rig.
      (const MiningGridCell(0, 2), true),
      // Above, rig center-X right of the deposit center.
      (const MiningGridCell(2, 0), false),
      // Below, rig center-X left of the deposit center.
      (const MiningGridCell(1, 3), true),
    ];

    for (final (cell, expectedMirror) in cases) {
      await _pumpLayer(tester, cell: cell, reducedMotion: true);
      final flip = _robotFlipTransform(tester, cell).transform.storage[0];
      expect(flip, expectedMirror ? -1 : 1, reason: '$cell');
    }
  });
}
