import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mine_site_view.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_grid.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:horologium/mining/presentation/animated_mining_grid_visual_layer.dart';
import 'package:horologium/mining/presentation/mining_visuals.dart';

import '../../support/mining_grid_fixtures.dart';
import '../../support/mining_visual_frames.dart';

final _content = MiningContentRegistry.stellarMining();
final _start = DateTime.utc(2026, 8, 26, 12);
const _defaultCell = MiningGridCell(2, 3);

final _landing = _content.site(MiningSiteId.landingBasin);

/// The default rig at (2,3) uniquely mines the pinned first progression
/// resource (1,1,2,0) from the content contract: an authored 2x2 at (1,1).
final _minedDeposit = _landing.deposits.singleWhere(
  (d) => d.x == 1 && d.y == 1 && d.size == 2,
);

/// An authored deposit with no rig on it.
final _unminedDeposit = _landing.deposits[1];

final _deployableCells = deployableMiningCells(_landing);

Key _depositKey(MiningDepositDefinition deposit) =>
    Key('landing-basin-deposit-${deposit.x}-${deposit.y}-${deposit.size}');

Key _hpKey(MiningDepositDefinition deposit) =>
    Key('landing-basin-hp-${deposit.x}-${deposit.y}-${deposit.size}');

String _hpText(WidgetTester tester, [MiningDepositDefinition? deposit]) =>
    tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(_hpKey(deposit ?? _minedDeposit)),
            matching: find.byType(Text),
          ),
        )
        .data!;

Key _damageKey(MiningGridCell cell) =>
    Key('landing-basin-damage-${cell.x}-${cell.y}');

String _damageText(WidgetTester tester, MiningGridCell cell) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(_damageKey(cell)),
        matching: find.byType(Text),
      ),
    )
    .data!;

double _damageOpacity(WidgetTester tester, MiningGridCell cell) => tester
    .widget<Opacity>(
      find.descendant(
        of: find.byKey(_damageKey(cell)),
        matching: find.byType(Opacity),
      ),
    )
    .opacity;

Offset _damageTopLeft(WidgetTester tester, MiningGridCell cell) =>
    tester.getTopLeft(
      find.descendant(
        of: find.byKey(_damageKey(cell)),
        matching: find.byType(Text),
      ),
    );

/// Two legal perimeter cells of the default mined deposit, so two rigs can
/// share one resource body (a break needs more damage than one T5 strike).
final _sharedAdjacentCells = _deployableCells
    .where((cell) => _minedDeposit.isOrthogonallyAdjacent(cell))
    .take(2)
    .toList();

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
  AssetBundle? assetBundle,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 932);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  Widget home = AnimatedMiningGridVisualLayer(
    view: _view(
      rigTier: rigTier,
      cell: cell,
      withRig: withRig,
      progress: progress,
      rigs: rigs,
    ),
    frames: MiningDepositFrames.gold,
    impactSequence: impactSequence,
    onMiningImpact: onMiningImpact,
    reducedMotion: reducedMotion,
    cellSize: 56,
  );
  if (assetBundle != null) {
    home = DefaultAssetBundle(bundle: assetBundle, child: home);
  }
  await tester.pumpWidget(MaterialApp(home: home));
  await tester.pump();
}

/// Lets the layer's in-flight decode attempt actually settle before the next
/// step: each frame path resolves to the same completer the attempt is
/// driving, so precaching it here returns only after the codec delivered its
/// error or frame, and the trailing event turn lets the layer's Future.wait
/// continuation run its eviction/latch callbacks. A corrupt attempt still
/// settles, just with a failure; the provider is evicted like the layer's own
/// onError so the drain never leaves a failed completer pending for the
/// retry. Decode work never completes under fake-async pumps, so each attempt
/// must drain here before the bundle flips or HP is asserted.
Future<void> _drainDecodes(WidgetTester tester) async {
  final context = tester.element(find.byType(AnimatedMiningGridVisualLayer));
  await tester.runAsync(() async {
    for (final path in MiningDepositFrames.gold.all) {
      final provider = AssetImage(path);
      await precacheImage(
        provider,
        context,
        onError: (error, stackTrace) {
          provider.evict(configuration: createLocalImageConfiguration(context));
        },
      );
    }
    await Future<void>.delayed(Duration.zero);
  });
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

MineSiteRigView _rig(
  RigTier tier,
  MiningGridCell cell,
  MiningDepositDefinition target,
) => MineSiteRigView(
  placement: MiningRigPlacement(tier: tier, cell: cell),
  target: target,
  canRecall: true,
  disabledReason: null,
);

MiningGridCell _firstAdjacentCell(MiningDepositDefinition deposit) =>
    _deployableCells
        .where((cell) => deposit.isOrthogonallyAdjacent(cell))
        .first;

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

/// A commissioned view of [siteId] at [progress] with one T1 rig on the
/// site's first legal cell at its first playable Surveying level (the first
/// progression resource's requirement).
MineSiteView _animatedSiteView(MiningSiteId siteId, {double progress = 0}) {
  final site = _content.site(siteId);
  final placements = [
    MiningRigPlacement(tier: RigTier.t1, cell: firstPlayableCell(site)),
  ];
  final initial = MiningSave.initial(nowUtc: _start);
  final capacity = _content.effectiveSiteCapacity(siteId, [RigTier.t1], 0);
  final state = initial.copyWith(
    technology: TechnologyLevels(
      surveying: site.deposits.first.requiredSurveyingLevel,
    ),
    sites: {
      ...initial.sites,
      siteId: initial.sites[siteId]!.copyWith(
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
    siteId: siteId,
    selectedBayId: null,
    isBusy: false,
  );
}

Future<void> _pumpAnimatedSite(
  WidgetTester tester,
  MiningSiteId siteId, {
  double progress = 0,
  int impactSequence = 0,
  bool reducedMotion = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 932);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: AnimatedMiningGridVisualLayer(
        view: _animatedSiteView(siteId, progress: progress),
        frames: MiningVisuals.depositFramesFor(siteId)!,
        impactSequence: impactSequence,
        reducedMotion: reducedMotion,
        cellSize: 56,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('feedback math', () {
    test('scales resource max HP by body size', () {
      expect(miningResourceMaxHp(1), 40);
      expect(miningResourceMaxHp(2), 80);
      expect(miningResourceMaxHp(3), 120);
    });

    test('scales strike damage by rig tier', () {
      expect(
        [for (final tier in RigTier.values) miningStrikeDamage(tier)],
        [10, 20, 30, 40, 50],
      );
    });

    test('groups strike damage of rigs targeting one resource', () {
      final cell = _firstAdjacentCell(_minedDeposit);
      final groups = miningGroupedDamage([
        _rig(RigTier.t1, cell, _minedDeposit),
        _rig(RigTier.t5, _defaultCell, _minedDeposit),
      ]);
      expect(groups, {_minedDeposit: 60});
    });

    test('keeps rigs targeting different resources in separate groups', () {
      expect(_unminedDeposit, isNot(equals(_minedDeposit)));
      final groups = miningGroupedDamage([
        _rig(RigTier.t1, _firstAdjacentCell(_minedDeposit), _minedDeposit),
        _rig(RigTier.t2, _firstAdjacentCell(_unminedDeposit), _unminedDeposit),
      ]);
      expect(groups, {_minedDeposit: 10, _unminedDeposit: 20});
    });

    test('clamps remaining HP at zero and discards overkill', () {
      expect(miningRemainingHpAfterStrike(40, 10), 30);
      expect(miningRemainingHpAfterStrike(30, 50), 0);
      expect(miningRemainingHpAfterStrike(10, 50), 0);
      expect(miningRemainingHpAfterStrike(0, 10), 0);
    });
  });

  // The layer defers its first one-shot impact until the finite deposit frames
  // finish precaching, and readiness is tied only to actual Future.wait
  // completion (the deferral budget drops a stalled impact, it does not fire
  // it). In the fake-async test environment a cold image cache never decodes
  // those frames, so impact tests warm the finite frame set in real async via
  // [warmDepositFrames] before mounting the layer. Clearing the cache before each
  // test keeps non-impact tests cold and deterministic.
  setUp(() {
    imageCache.clear();
    imageCache.clearLiveImages();
  });

  testWidgets(
    'emits one sound at a visible strike, never on load or reduced motion',
    (tester) async {
      await warmDepositFrames(tester, MiningDepositFrames.gold);
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
    expect(_depositAsset(tester), MiningDepositFrames.gold.stage(1));
  });

  testWidgets('animates only the mined deposit and keeps others static', (
    tester,
  ) async {
    // The default rig at (2,3) mines the (1,1) deposit only: it runs its idle
    // loop while unmined deposits stay on their static stage plate.
    await _pumpLayer(tester, reducedMotion: false);
    expect(_depositAsset(tester), MiningDepositFrames.gold.idle(1));
    expect(
      _depositAsset(tester, _unminedDeposit),
      MiningDepositFrames.gold.stage(1),
    );

    await tester.pump(const Duration(milliseconds: 125));
    expect(_depositAsset(tester), MiningDepositFrames.gold.idle(2));
    expect(
      _depositAsset(tester, _unminedDeposit),
      MiningDepositFrames.gold.stage(1),
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
    expect(_depositAsset(tester), MiningDepositFrames.gold.idle(1));

    await tester.pump(const Duration(milliseconds: 125));
    expect(_depositAsset(tester), MiningDepositFrames.gold.idle(2));
    await tester.pump(const Duration(milliseconds: 125));
    expect(_depositAsset(tester), MiningDepositFrames.gold.idle(3));
    await tester.pump(const Duration(milliseconds: 125));
    expect(_depositAsset(tester), MiningDepositFrames.gold.idle(4));
    await tester.pump(const Duration(milliseconds: 125));
    expect(_depositAsset(tester), MiningDepositFrames.gold.idle(1));
  });

  testWidgets('stops the idle loop outside S1', (tester) async {
    await _pumpLayer(tester, progress: 0);
    await tester.pump(const Duration(milliseconds: 125));
    expect(_depositAsset(tester), MiningDepositFrames.gold.idle(2));

    await _pumpLayer(tester, progress: .25);
    expect(_depositAsset(tester), MiningDepositFrames.gold.stage(2));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_depositAsset(tester), MiningDepositFrames.gold.stage(2));

    await _pumpLayer(tester, progress: 0);
    expect(_depositAsset(tester), MiningDepositFrames.gold.idle(1));
  });

  testWidgets(
    'selects every S1 hit frame while the chassis stays fixed',
    (tester) async {
      await warmDepositFrames(tester, MiningDepositFrames.gold);
      await _pumpLayer(tester, impactSequence: 0);
      final restBody = _robotBodyTransform(tester, _defaultCell).transform;
      final restArm = _robotArmTransform(tester, _defaultCell).transform;

      // With the finite frames warmed, _framesReady is true and the one-shot
      // impact fires immediately on the sequence change (no deferral budget).
      // Advance into the S1 hit window and step through the three hit frames.
      await _pumpLayer(tester, impactSequence: 1);
      await tester.pump(const Duration(milliseconds: 240));
      expect(_depositAsset(tester), MiningDepositFrames.gold.hit(1));
      // The impact one-shot animates the mined deposit, never unmined ones.
      expect(
        _depositAsset(tester, _unminedDeposit),
        MiningDepositFrames.gold.stage(1),
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
      expect(_depositAsset(tester), MiningDepositFrames.gold.hit(2));
      expect(
        _robotBodyTransform(tester, _defaultCell).transform,
        equals(restBody),
      );
      expect(
        _robotArmTransform(tester, _defaultCell).transform,
        isNot(equals(restArm)),
      );

      await tester.pump(const Duration(milliseconds: 84));
      expect(_depositAsset(tester), MiningDepositFrames.gold.hit(3));
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
      await warmDepositFrames(tester, MiningDepositFrames.gold);
      await _pumpLayer(tester, progress: .899, impactSequence: 0);
      expect(_depositAsset(tester), MiningDepositFrames.gold.stage(3));

      // With the finite frames warmed, _framesReady is true and the exhaust
      // one-shot fires immediately on the sequence change. The controller parks
      // at value 0 so the S3 wind-up hold shows before the exhaust window.
      await _pumpLayer(tester, progress: .90, impactSequence: 1);
      expect(_depositAsset(tester), MiningDepositFrames.gold.stage(3));

      await tester.pump(const Duration(milliseconds: 240));
      expect(_depositAsset(tester), MiningDepositFrames.gold.exhaust(1));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_depositAsset(tester), MiningDepositFrames.gold.exhaust(2));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_depositAsset(tester), MiningDepositFrames.gold.exhaust(3));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_depositAsset(tester), MiningDepositFrames.gold.exhaust(4));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_depositAsset(tester), MiningDepositFrames.gold.stage(4));

      await _pumpLayer(tester, progress: 0, impactSequence: 1);
      expect(_depositAsset(tester), MiningDepositFrames.gold.idle(1));
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
        for (var f = 1; f <= 4; f++) MiningDepositFrames.gold.idle(f),
      };
      final impactFrames = {
        for (var f = 1; f <= 3; f++) MiningDepositFrames.gold.hit(f),
        for (var f = 1; f <= 4; f++) MiningDepositFrames.gold.exhaust(f),
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

  // Missing art degrades to the errorBuilder's empty box per image — the
  // grid keeps its deposits and rigs laid out and nothing reports an error.
  testWidgets(
    'renders empty fallbacks when deposit and robot art cannot load',
    (tester) async {
      await _pumpLayer(
        tester,
        reducedMotion: true,
        assetBundle: _MissingMiningArtBundle(),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byKey(_depositKey(_minedDeposit)),
          matching: find.byType(SizedBox),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(_depositKey(_unminedDeposit)),
          matching: find.byType(SizedBox),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(Key('landing-basin-robot-body-transform-2-3')),
          matching: find.byType(SizedBox),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(Key('landing-basin-robot-arm-transform-2-3')),
          matching: find.byType(SizedBox),
        ),
        findsOneWidget,
      );
    },
    // A failing asset bundle needs the VM image path; web loads images by
    // URL and never asks the bundle.
    skip: kIsWeb,
  );

  // A settled-but-failed precache frees the latch, so a later impact retries
  // the family inside its defer window instead of staying dropped until the
  // site is reopened. The bundle fails the initial attempt, the first impact
  // defers/retries/drops, the family warms out of band, and the next impact's
  // retry resolves from the cache so that live pending impact fires — the
  // earlier dropped impact is already discarded and never replays.
  testWidgets('a failed precache retries on a later impact', (tester) async {
    final bundle = _FlakyMiningArtBundle();
    await _pumpLayer(tester, impactSequence: 0, assetBundle: bundle);
    await tester.pump();

    await _pumpLayer(tester, impactSequence: 1, assetBundle: bundle);
    await tester.pump(const Duration(milliseconds: 200));
    expect(_hpText(tester), '80/80');

    bundle.failMining = false;
    await tester.runAsync(() async {
      final context = tester.element(
        find.byType(AnimatedMiningGridVisualLayer),
      );
      for (final path in MiningDepositFrames.gold.all) {
        await precacheImage(AssetImage(path), context);
      }
    });
    await _pumpLayer(tester, impactSequence: 2, assetBundle: bundle);
    await tester.pump(const Duration(milliseconds: 470));
    expect(_hpText(tester), '70/80');
  }, skip: kIsWeb);

  // A missing asset self-evicts through AssetBundleImageProvider, but a
  // decode failure does not: the corrupt bytes leave the provider's failed
  // completer pending in the image cache, so an unguarded retry resolves the
  // same errored stream and never reloads. The layer evicts each failed
  // provider before freeing its latch, so once the art goes valid the retry
  // really decodes it and fires the live pending impact.
  testWidgets(
    'a decode failure evicts the failed provider so a retry loads valid bytes',
    (tester) async {
      final bundle = _CorruptMiningArtBundle();
      await _pumpLayer(tester, impactSequence: 0, assetBundle: bundle);
      await _drainDecodes(tester);

      bundle.corruptMining = false;
      await _pumpLayer(tester, impactSequence: 1, assetBundle: bundle);
      await _drainDecodes(tester);
      // The deferred impact's controller forward lands inside the real-async
      // settle, so its ticker starts counting on this pump; the next pump
      // carries it through contact.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 470));
      expect(_hpText(tester), '70/80');
    },
    skip: kIsWeb,
  );

  // A mounted Image never leaves its errorBuilder on a plain rebuild:
  // Image.didUpdateWidget re-resolves only on provider inequality and a
  // rebuilt AssetImage of the same path is value-equal, so the recovered
  // family must remount its frame widgets under the epoch key. Corrupt the
  // family, let every deposit render its empty fallback, then serve valid
  // bytes: after the retry settles, both the mined deposit (animated
  // subtree) and an unmined one (the static AnimatedBuilder.child) draw real
  // art again.
  testWidgets(
    'a recovered frame family remounts deposits out of the error fallback',
    (tester) async {
      final bundle = _CorruptMiningArtBundle();
      await _pumpLayer(tester, impactSequence: 0, assetBundle: bundle);
      await _drainDecodes(tester);
      await tester.pump();

      Finder rawImageIn(Key depositKey) => find.descendant(
        of: find.byKey(depositKey),
        matching: find.byType(RawImage),
      );
      Finder fallbackIn(Key depositKey) => find.descendant(
        of: find.byKey(depositKey),
        matching: find.byType(SizedBox),
      );
      expect(fallbackIn(_depositKey(_minedDeposit)), findsOneWidget);
      expect(fallbackIn(_depositKey(_unminedDeposit)), findsOneWidget);
      expect(rawImageIn(_depositKey(_minedDeposit)), findsNothing);
      expect(rawImageIn(_depositKey(_unminedDeposit)), findsNothing);

      bundle.corruptMining = false;
      await _pumpLayer(tester, impactSequence: 1, assetBundle: bundle);
      await _drainDecodes(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 470));
      expect(_hpText(tester), '70/80');
      for (final deposit in [_minedDeposit, _unminedDeposit]) {
        final rawImage = rawImageIn(_depositKey(deposit));
        expect(rawImage, findsOneWidget, reason: '$deposit');
        expect(tester.widget<RawImage>(rawImage).image, isNotNull);
        expect(fallbackIn(_depositKey(deposit)), findsNothing);
      }
    },
    skip: kIsWeb,
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

      expect(_depositAsset(tester), MiningDepositFrames.gold.stage(1));
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
        MiningVisuals.miningRobotBodyAsset(tier),
      );
      expect(
        (armImage.image as AssetImage).assetName,
        MiningVisuals.miningRobotArmAsset(tier),
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

  group('resource HP chrome', () {
    testWidgets('renders HP chrome for mined resources only', (tester) async {
      await _pumpLayer(tester, reducedMotion: true);

      expect(find.byKey(_hpKey(_minedDeposit)), findsOneWidget);
      expect(find.byKey(_hpKey(_unminedDeposit)), findsNothing);
    });

    testWidgets('a warmed valid T1 contact drops visible HP exactly once', (
      tester,
    ) async {
      await warmDepositFrames(tester, MiningDepositFrames.gold);
      await _pumpLayer(tester, impactSequence: 0);
      expect(_hpText(tester), '80/80');

      await _pumpLayer(tester, impactSequence: 1);
      await tester.pump(const Duration(milliseconds: 450));
      expect(_hpText(tester), '80/80');
      await tester.pump(const Duration(milliseconds: 20));
      expect(_hpText(tester), '70/80');

      await tester.pump(const Duration(seconds: 1));
      expect(_hpText(tester), '70/80');
    }, skip: kIsWeb);

    testWidgets('a cargo update without a new impact keeps the struck HP', (
      tester,
    ) async {
      await warmDepositFrames(tester, MiningDepositFrames.gold);
      await _pumpLayer(tester, impactSequence: 0);
      await _pumpLayer(tester, impactSequence: 1);
      await tester.pump(const Duration(milliseconds: 470));
      expect(_hpText(tester), '70/80');

      await _pumpLayer(tester, impactSequence: 1, progress: .5);
      expect(_hpText(tester), '70/80');
      await tester.pump(const Duration(seconds: 1));
      expect(_hpText(tester), '70/80');
    }, skip: kIsWeb);

    // Cold on purpose and cross-platform: a dropped impact must never mutate
    // HP, mirroring the stalled-first-impact drop above.
    testWidgets('a cold-cache dropped impact keeps full HP', (tester) async {
      await _pumpLayer(tester, impactSequence: 0);
      expect(_hpText(tester), '80/80');

      await _pumpLayer(tester, impactSequence: 1);
      await tester.pump(const Duration(milliseconds: 200));
      expect(_hpText(tester), '80/80');
    });

    testWidgets('a warmed late miss at or past 0.62 keeps full HP', (
      tester,
    ) async {
      await warmDepositFrames(tester, MiningDepositFrames.gold);
      await _pumpLayer(tester, impactSequence: 0);
      await _pumpLayer(tester, impactSequence: 1);
      await tester.pump(const Duration(milliseconds: 450));
      expect(_hpText(tester), '80/80');

      await tester.pump(const Duration(milliseconds: 200));
      expect(_hpText(tester), '80/80');
      await tester.pump(const Duration(seconds: 1));
      expect(_hpText(tester), '80/80');
    }, skip: kIsWeb);

    testWidgets('remounting the layer resets visible HP', (tester) async {
      await warmDepositFrames(tester, MiningDepositFrames.gold);
      await _pumpLayer(tester, impactSequence: 0);
      await _pumpLayer(tester, impactSequence: 1);
      await tester.pump(const Duration(milliseconds: 470));
      expect(_hpText(tester), '70/80');

      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpLayer(tester, impactSequence: 1);
      expect(_hpText(tester), '80/80');
    }, skip: kIsWeb);
  });

  group('damage labels and break beat', () {
    testWidgets('one valid multi-rig impact renders one label per rig', (
      tester,
    ) async {
      final rigs = [
        (RigTier.t1, _sharedAdjacentCells[0]),
        (RigTier.t2, _sharedAdjacentCells[1]),
      ];
      await warmDepositFrames(tester, MiningDepositFrames.gold);
      await _pumpLayer(tester, rigs: rigs, impactSequence: 0);
      await _pumpLayer(tester, rigs: rigs, impactSequence: 1);
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.byKey(_damageKey(_sharedAdjacentCells[0])), findsNothing);
      expect(find.byKey(_damageKey(_sharedAdjacentCells[1])), findsNothing);

      await tester.pump(const Duration(milliseconds: 20));
      expect(find.byKey(_damageKey(_sharedAdjacentCells[0])), findsOneWidget);
      expect(find.byKey(_damageKey(_sharedAdjacentCells[1])), findsOneWidget);
      expect(_damageText(tester, _sharedAdjacentCells[0]), '-10');
      expect(_damageText(tester, _sharedAdjacentCells[1]), '-20');
      expect(
        find.descendant(
          of: find.byKey(_damageKey(_sharedAdjacentCells[0])),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
    }, skip: kIsWeb);

    testWidgets(
      'reduced motion still applies HP and fades the value in place',
      (tester) async {
        await warmDepositFrames(tester, MiningDepositFrames.gold);
        await _pumpLayer(tester, impactSequence: 0, reducedMotion: true);
        await _pumpLayer(tester, impactSequence: 1, reducedMotion: true);
        await tester.pump(const Duration(milliseconds: 450));
        expect(_hpText(tester), '80/80');
        expect(find.byKey(_damageKey(_defaultCell)), findsNothing);

        await tester.pump(const Duration(milliseconds: 30));
        expect(_hpText(tester), '70/80');
        expect(find.byKey(_damageKey(_defaultCell)), findsOneWidget);
        expect(_damageText(tester, _defaultCell), '-10');
        final restTopLeft = _damageTopLeft(tester, _defaultCell);
        final firstOpacity = _damageOpacity(tester, _defaultCell);

        await tester.pump(const Duration(milliseconds: 300));
        // No translated label: the fade happens exactly in place through the
        // post-contact tail.
        expect(_damageTopLeft(tester, _defaultCell), restTopLeft);
        expect(_damageOpacity(tester, _defaultCell), lessThan(firstOpacity));
      },
      skip: kIsWeb,
    );

    testWidgets('a breaking hit shows visible zero then the fresh max at end', (
      tester,
    ) async {
      final rigs = [
        (RigTier.t5, _sharedAdjacentCells[0]),
        (RigTier.t5, _sharedAdjacentCells[1]),
      ];
      await warmDepositFrames(tester, MiningDepositFrames.gold);
      await _pumpLayer(
        tester,
        rigs: rigs,
        impactSequence: 0,
        reducedMotion: true,
      );
      await _pumpLayer(
        tester,
        rigs: rigs,
        impactSequence: 1,
        reducedMotion: true,
      );
      await tester.pump(const Duration(milliseconds: 470));
      expect(_hpText(tester), '0/80');

      await tester.pump(const Duration(seconds: 1));
      expect(_hpText(tester), '80/80');
    }, skip: kIsWeb);

    testWidgets('damage labels are gone at timeline end', (tester) async {
      await warmDepositFrames(tester, MiningDepositFrames.gold);
      await _pumpLayer(tester, impactSequence: 0);
      await _pumpLayer(tester, impactSequence: 1);
      await tester.pump(const Duration(milliseconds: 470));
      expect(find.byKey(_damageKey(_defaultCell)), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(_damageKey(_defaultCell)), findsNothing);
    }, skip: kIsWeb);

    // Cold on purpose and cross-platform: a dropped impact renders no labels,
    // mirroring the kept-full-HP drop test above.
    testWidgets('a cold-cache dropped impact renders no damage labels', (
      tester,
    ) async {
      await _pumpLayer(tester, impactSequence: 0);
      await _pumpLayer(tester, impactSequence: 1);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(_damageKey(_defaultCell)), findsNothing);
      expect(_hpText(tester), '80/80');
    });

    testWidgets('a warmed late miss at or past 0.62 renders no damage labels', (
      tester,
    ) async {
      await warmDepositFrames(tester, MiningDepositFrames.gold);
      await _pumpLayer(tester, impactSequence: 0);
      await _pumpLayer(tester, impactSequence: 1);
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.byKey(_damageKey(_defaultCell)), findsNothing);

      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(_damageKey(_defaultCell)), findsNothing);
      expect(_hpText(tester), '80/80');
    }, skip: kIsWeb);
  });

  for (final siteId in animatedMiningSiteIds) {
    group(_content.site(siteId).name, () {
      final site = _content.site(siteId);
      final cell = firstPlayableCell(site);
      final deposit = uniqueAdjacentDeposit(
        deposits: site.deposits,
        cell: cell,
      )!;
      final frames = MiningVisuals.depositFramesFor(siteId)!;
      final prefix = MiningVisuals.siteKeyPrefix(siteId);

      String asset(WidgetTester tester) {
        final image = tester.widget<Image>(
          find.descendant(
            of: find.byKey(
              Key('$prefix-deposit-${deposit.x}-${deposit.y}-${deposit.size}'),
            ),
            matching: find.byType(Image),
          ),
        );
        return (image.image as AssetImage).assetName;
      }

      String hpText(WidgetTester tester) => tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(
                Key('$prefix-hp-${deposit.x}-${deposit.y}-${deposit.size}'),
              ),
              matching: find.byType(Text),
            ),
          )
          .data!;

      Key damageKey() => Key('$prefix-damage-${cell.x}-${cell.y}');

      testWidgets(
        'selects the staged ${frames.slug} plate at progress boundaries',
        (tester) async {
          for (final entry in {
            .24: frames.stage(1),
            .25: frames.stage(2),
            .60: frames.stage(3),
            .90: frames.stage(4),
          }.entries) {
            await _pumpAnimatedSite(
              tester,
              siteId,
              progress: entry.key,
              reducedMotion: true,
            );
            expect(asset(tester), entry.value, reason: '${entry.key}');
          }
        },
      );

      testWidgets(
        'loops the four ${frames.slug} idle frames and stops outside S1',
        (tester) async {
          await _pumpAnimatedSite(tester, siteId);
          for (var frame = 1; frame <= 4; frame++) {
            expect(asset(tester), frames.idle(frame));
            await tester.pump(const Duration(milliseconds: 125));
          }
          expect(asset(tester), frames.idle(1));

          await _pumpAnimatedSite(tester, siteId, progress: .25);
          await tester.pump(const Duration(milliseconds: 500));
          expect(asset(tester), frames.stage(2));
        },
      );

      testWidgets(
        'a warmed impact plays the ${frames.slug} hit and drops HP once',
        (tester) async {
          await warmDepositFrames(tester, frames);
          await _pumpAnimatedSite(tester, siteId);
          final maxHp = miningResourceMaxHp(deposit.size);
          expect(hpText(tester), '$maxHp/$maxHp');

          await _pumpAnimatedSite(tester, siteId, impactSequence: 1);
          await tester.pump(const Duration(milliseconds: 240));
          expect(asset(tester), frames.hit(1));
          await tester.pump(const Duration(milliseconds: 84));
          expect(asset(tester), frames.hit(2));
          await tester.pump(const Duration(milliseconds: 84));
          expect(asset(tester), frames.hit(3));

          await tester.pump(const Duration(milliseconds: 62));
          expect(find.byKey(damageKey()), findsOneWidget);
          expect(hpText(tester), '${maxHp - 10}/$maxHp');
          await tester.pump(const Duration(seconds: 1));
          expect(hpText(tester), '${maxHp - 10}/$maxHp');
          expect(find.byKey(damageKey()), findsNothing);
        },
        skip: kIsWeb,
      );

      testWidgets(
        'crossing into S4 plays the ${frames.slug} exhaust and settles on S4',
        (tester) async {
          await warmDepositFrames(tester, frames);
          await _pumpAnimatedSite(tester, siteId, progress: .899);
          expect(asset(tester), frames.stage(3));

          await _pumpAnimatedSite(
            tester,
            siteId,
            progress: .90,
            impactSequence: 1,
          );
          await tester.pump(const Duration(milliseconds: 240));
          for (var frame = 1; frame <= 4; frame++) {
            expect(asset(tester), frames.exhaust(frame));
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(asset(tester), frames.stage(4));
        },
        skip: kIsWeb,
      );

      testWidgets('a cold-cache impact is dropped with full HP and no label', (
        tester,
      ) async {
        final maxHp = miningResourceMaxHp(deposit.size);
        await _pumpAnimatedSite(tester, siteId);
        await _pumpAnimatedSite(tester, siteId, impactSequence: 1);
        await tester.pump(const Duration(milliseconds: 200));
        expect(hpText(tester), '$maxHp/$maxHp');
        expect(find.byKey(damageKey()), findsNothing);
        expect({
          for (var f = 1; f <= 4; f++) frames.idle(f),
        }, contains(asset(tester)));
      });

      testWidgets('reduced motion shows the static plate and a still arm', (
        tester,
      ) async {
        Matrix4 arm() => tester
            .widget<Transform>(
              find.byKey(
                Key('$prefix-robot-arm-transform-${cell.x}-${cell.y}'),
              ),
            )
            .transform;
        await _pumpAnimatedSite(tester, siteId, reducedMotion: true);
        final rest = arm();
        await _pumpAnimatedSite(
          tester,
          siteId,
          reducedMotion: true,
          impactSequence: 1,
        );
        await tester.pump(const Duration(milliseconds: 500));
        expect(asset(tester), frames.stage(1));
        expect(arm(), equals(rest));
      });
    });
  }
}

/// Every mining image path misses, so each animated-layer [Image.asset]
/// resolves through its errorBuilder instead of decoded art.
class _MissingMiningArtBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key.startsWith('assets/images/mining/')) {
      throw FlutterError('Missing $key');
    }
    return rootBundle.load(key);
  }
}

/// Mining image paths miss only while [failMining] holds, so a test can fail
/// a precache attempt and then let a retry resolve the real art.
class _FlakyMiningArtBundle extends CachingAssetBundle {
  bool failMining = true;

  @override
  Future<ByteData> load(String key) async {
    if (failMining && key.startsWith('assets/images/mining/')) {
      throw FlutterError('Missing $key');
    }
    return rootBundle.load(key);
  }
}

/// Mining image paths serve undecodable bytes only while [corruptMining]
/// holds. Unlike a missing asset, a decode failure does not self-evict the
/// provider from the image cache, so it covers the evict-on-error retry path.
class _CorruptMiningArtBundle extends CachingAssetBundle {
  bool corruptMining = true;

  @override
  Future<ByteData> load(String key) async {
    if (corruptMining && key.startsWith('assets/images/mining/')) {
      return ByteData.sublistView(
        Uint8List.fromList(const [0, 1, 2, 3, 4, 5, 6, 7]),
      );
    }
    return rootBundle.load(key);
  }
}
