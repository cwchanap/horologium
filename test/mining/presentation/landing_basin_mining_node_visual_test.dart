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

void main() {
  testWidgets('renders the staged plate and omits the rig without a rig', (
    tester,
  ) async {
    await _pumpVisual(tester, rig: null, reducedMotion: true);

    expect(find.byKey(const Key('landing-basin-deposit-n1')), findsOneWidget);
    expect(find.byKey(const Key('landing-basin-robot-n1')), findsNothing);
    expect(_nodeAsset(tester), MiningVisuals.goldNodeStageAsset(1));
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

  testWidgets('selects every S1 hit frame while the chassis stays fixed', (
    tester,
  ) async {
    await _pumpVisual(tester, impactSequence: 0);
    final restBody = _robotBodyTransform(tester).transform;
    final restArm = _robotArmTransform(tester).transform;

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
  });

  testWidgets('plays exhaust frames only when progress crosses into S4', (
    tester,
  ) async {
    await _pumpVisual(tester, progress: .899, impactSequence: 0);
    expect(_nodeAsset(tester), MiningVisuals.goldNodeStageAsset(3));

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
  });

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
