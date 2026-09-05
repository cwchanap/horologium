import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/presentation/landing_basin_mining_node_visual.dart';
import 'package:horologium/mining/presentation/mining_visuals.dart';

Future<void> _pumpVisual(
  WidgetTester tester, {
  RigTier? rig = RigTier.t1,
  double progress = 0,
  int impactSequence = 0,
  bool reducedMotion = false,
  double nodeSize = 80,
  double rigSize = 40,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: LandingBasinMiningNodeVisual(
          nodeId: MiningNodeId.n1,
          rig: rig,
          nodeSize: nodeSize,
          rigSize: rigSize,
          progress: progress,
          impactSequence: impactSequence,
          reducedMotion: reducedMotion,
        ),
      ),
    ),
  );
  await tester.pump();
}

String _nodeAsset(WidgetTester tester) {
  final images = tester
      .widgetList<Image>(
        find.descendant(
          of: find.byKey(const Key('landing-basin-deposit-n1')),
          matching: find.byType(Image),
        ),
      )
      .toList();
  expect(images, hasLength(1));
  final image = images.single.image;
  expect(image, isA<AssetImage>());
  return (image as AssetImage).assetName;
}

Transform _robotTransform(WidgetTester tester) =>
    tester.widget<Transform>(find.byKey(const Key('landing-basin-robot-n1')));

Transform _robotBodyTransform(WidgetTester tester) => tester.widget<Transform>(
  find.byKey(const Key('landing-basin-robot-body-transform-n1')),
);

Transform _robotArmTransform(WidgetTester tester) => tester.widget<Transform>(
  find.byKey(const Key('landing-basin-robot-arm-transform-n1')),
);

// Resolve the finite gold frame set in real async before the visual mounts,
// so its _precacheFrames Future.wait completes from cache hits and
// _framesReady becomes true via actual precache completion (the deferral
// budget drops a stalled impact, it does not fire it). A bare host gives
// precacheImage a Directionality context; the global image cache persists
// across the subsequent pumpWidget that mounts the visual.
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
  // The visual defers its first one-shot impact until the finite gold frames
  // finish precaching, and readiness is tied only to actual Future.wait
  // completion (the deferral budget drops a stalled impact, it does not fire
  // it). In the fake-async test environment a cold image cache never decodes
  // those frames, so impact tests warm the finite frame set in real async via
  // [warmGoldFrames] before mounting the visual; its _precacheFrames then
  // completes from cache hits and _framesReady becomes true. Clearing the
  // cache before each test keeps non-impact tests cold and deterministic.
  setUp(() => imageCache.clear());

  testWidgets('renders the staged plate and omits the rig without a rig', (
    tester,
  ) async {
    await _pumpVisual(tester, rig: null, reducedMotion: true);

    expect(find.byKey(const Key('landing-basin-deposit-n1')), findsOneWidget);
    expect(find.byKey(const Key('landing-basin-robot-n1')), findsNothing);
    expect(_nodeAsset(tester), MiningVisuals.goldNodeStageAsset(1));
  });

  testWidgets('keeps gapless playback on the changing deposit image', (
    tester,
  ) async {
    await _pumpVisual(tester);

    final image = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const Key('landing-basin-deposit-n1')),
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
      await _pumpVisual(tester, progress: entry.key, reducedMotion: true);
      expect(_nodeAsset(tester), entry.value);
    }
  });

  testWidgets('loops the four S1 idle frames every 125ms', (tester) async {
    await _pumpVisual(tester, reducedMotion: false);
    expect(_nodeAsset(tester), MiningVisuals.goldNodeIdleAsset(1));

    await tester.pump(const Duration(milliseconds: 125));
    expect(_nodeAsset(tester), MiningVisuals.goldNodeIdleAsset(2));
    await tester.pump(const Duration(milliseconds: 125));
    expect(_nodeAsset(tester), MiningVisuals.goldNodeIdleAsset(3));
    await tester.pump(const Duration(milliseconds: 125));
    expect(_nodeAsset(tester), MiningVisuals.goldNodeIdleAsset(4));
    await tester.pump(const Duration(milliseconds: 125));
    expect(_nodeAsset(tester), MiningVisuals.goldNodeIdleAsset(1));
  });

  testWidgets('stops the idle loop outside S1', (tester) async {
    await _pumpVisual(tester, progress: 0);
    await tester.pump(const Duration(milliseconds: 125));
    expect(_nodeAsset(tester), MiningVisuals.goldNodeIdleAsset(2));

    await _pumpVisual(tester, progress: .25);
    expect(_nodeAsset(tester), MiningVisuals.goldNodeStageAsset(2));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_nodeAsset(tester), MiningVisuals.goldNodeStageAsset(2));

    await _pumpVisual(tester, progress: 0);
    expect(_nodeAsset(tester), MiningVisuals.goldNodeIdleAsset(1));
  });

  testWidgets(
    'selects every S1 hit frame while the chassis stays fixed',
    (tester) async {
      await warmGoldFrames(tester);
      await _pumpVisual(tester, impactSequence: 0);
      final restBody = _robotBodyTransform(tester).transform;
      final restArm = _robotArmTransform(tester).transform;

      // With the finite frames warmed, _framesReady is true and the one-shot
      // impact fires immediately on the sequence change (no deferral budget).
      // Advance into the S1 hit window and step through the three hit frames.
      await _pumpVisual(tester, impactSequence: 1);
      await tester.pump(const Duration(milliseconds: 240));
      expect(_nodeAsset(tester), MiningVisuals.goldNodeHitAsset(1));
      expect(_robotBodyTransform(tester).transform, equals(restBody));
      expect(_robotArmTransform(tester).transform, isNot(equals(restArm)));

      await tester.pump(const Duration(milliseconds: 84));
      expect(_nodeAsset(tester), MiningVisuals.goldNodeHitAsset(2));
      expect(_robotBodyTransform(tester).transform, equals(restBody));
      expect(_robotArmTransform(tester).transform, isNot(equals(restArm)));

      await tester.pump(const Duration(milliseconds: 84));
      expect(_nodeAsset(tester), MiningVisuals.goldNodeHitAsset(3));
      expect(_robotBodyTransform(tester).transform, equals(restBody));
      expect(_robotArmTransform(tester).transform, isNot(equals(restArm)));
    },
    // Finite-frame precache needs the VM asset channel; frame selection is
    // pure Dart covered on VM. The cold-cache drop path is covered on web.
    skip: kIsWeb,
  );

  testWidgets(
    'plays exhaust frames only when progress crosses into S4',
    (tester) async {
      await warmGoldFrames(tester);
      await _pumpVisual(tester, progress: .899, impactSequence: 0);
      expect(_nodeAsset(tester), MiningVisuals.goldNodeStageAsset(3));

      // With the finite frames warmed, _framesReady is true and the exhaust
      // one-shot fires immediately on the sequence change. The controller parks
      // at value 0 so the S3 wind-up hold shows before the exhaust window.
      await _pumpVisual(tester, progress: .90, impactSequence: 1);
      expect(_nodeAsset(tester), MiningVisuals.goldNodeStageAsset(3));

      await tester.pump(const Duration(milliseconds: 240));
      expect(_nodeAsset(tester), MiningVisuals.goldNodeExhaustAsset(1));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_nodeAsset(tester), MiningVisuals.goldNodeExhaustAsset(2));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_nodeAsset(tester), MiningVisuals.goldNodeExhaustAsset(3));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_nodeAsset(tester), MiningVisuals.goldNodeExhaustAsset(4));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_nodeAsset(tester), MiningVisuals.goldNodeStageAsset(4));

      await _pumpVisual(tester, progress: 0, impactSequence: 1);
      expect(_nodeAsset(tester), MiningVisuals.goldNodeIdleAsset(1));
    },
    // Finite-frame precache needs the VM asset channel; frame selection is
    // pure Dart covered on VM. The cold-cache drop path is covered on web.
    skip: kIsWeb,
  );

  // The deferral budget drops a stalled first impact instead of firing it
  // against unresolved frames. This is the cold-cache correctness path the
  // reviewer flagged: readiness stays tied to actual precache completion, so
  // a >budget decode keeps the node static. Runs on both VM and web since it
  // needs no real image decode (the cache stays cold on purpose).
  testWidgets(
    'drops a stalled first impact and keeps the node static on a cold cache',
    (tester) async {
      await _pumpVisual(tester, impactSequence: 0);
      await _pumpVisual(tester, impactSequence: 1);
      // The impact is deferred while the finite frames are still cold. Pumping
      // the deferral budget drops it without marking ready or firing the
      // one-shot, so the node stays on its resting S1 idle loop (never a hit
      // or exhaust frame) and the controller rests at value 1.
      await tester.pump(const Duration(milliseconds: 200));
      final idleFrames = {
        for (var f = 1; f <= 4; f++) MiningVisuals.goldNodeIdleAsset(f),
      };
      final impactFrames = {
        for (var f = 1; f <= 3; f++) MiningVisuals.goldNodeHitAsset(f),
        for (var f = 1; f <= 4; f++) MiningVisuals.goldNodeExhaustAsset(f),
      };
      expect(idleFrames, contains(_nodeAsset(tester)));
      expect(impactFrames, isNot(contains(_nodeAsset(tester))));

      // A second impact while still cold defers and drops again; no historical
      // replay and no frame ever advances into the hit/exhaust window.
      await _pumpVisual(tester, impactSequence: 2);
      await tester.pump(const Duration(milliseconds: 200));
      expect(idleFrames, contains(_nodeAsset(tester)));
      expect(impactFrames, isNot(contains(_nodeAsset(tester))));
    },
  );

  testWidgets(
    'reduced motion keeps the static stage and rig transforms fixed',
    (tester) async {
      await _pumpVisual(tester, reducedMotion: true, impactSequence: 0);
      final restRobot = _robotTransform(tester).transform;
      final restBody = _robotBodyTransform(tester).transform;
      final restArm = _robotArmTransform(tester).transform;

      await _pumpVisual(tester, reducedMotion: true, impactSequence: 1);
      await tester.pump(const Duration(milliseconds: 500));

      expect(_nodeAsset(tester), MiningVisuals.goldNodeStageAsset(1));
      expect(_robotTransform(tester).transform, equals(restRobot));
      expect(_robotBodyTransform(tester).transform, equals(restBody));
      expect(_robotArmTransform(tester).transform, equals(restArm));
    },
  );

  testWidgets('does not expose obsolete procedural effect keys', (
    tester,
  ) async {
    await _pumpVisual(tester, impactSequence: 1);
    await tester.pump(const Duration(milliseconds: 300));

    for (final key in [
      'landing-basin-impact-n1',
      'landing-basin-sparks-n1',
      'landing-basin-rock-chips-n1',
      'landing-basin-dust-n1',
      'landing-basin-gold-glow-n1',
    ]) {
      expect(find.byKey(Key(key)), findsNothing);
    }
  });

  testWidgets('disposes both animation controllers when removed', (
    tester,
  ) async {
    await _pumpVisual(tester, reducedMotion: false, impactSequence: 1);
    await tester.pump(const Duration(milliseconds: 100));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('selects articulated body and arm layers for every rig tier', (
    tester,
  ) async {
    for (final tier in RigTier.values) {
      await _pumpVisual(tester, rig: tier, reducedMotion: true);

      final bodyImage = tester.widget<Image>(
        find.descendant(
          of: find.byKey(const Key('landing-basin-robot-body-transform-n1')),
          matching: find.byType(Image),
        ),
      );
      final armImage = tester.widget<Image>(
        find.descendant(
          of: find.byKey(const Key('landing-basin-robot-arm-transform-n1')),
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
    await _pumpVisual(tester);

    expect(_robotArmTransform(tester).alignment, const Alignment(.33, -.24));
  });
}
