import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/presentation/landing_basin_mining_node_visual.dart';

Future<void> _pumpVisual(
  WidgetTester tester, {
  RigTier? rig = RigTier.t1,
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
          impactSequence: impactSequence,
          reducedMotion: reducedMotion,
        ),
      ),
    ),
  );
  await tester.pump();
}

Transform _robotTransform(WidgetTester tester) =>
    tester.widget<Transform>(find.byKey(const Key('landing-basin-robot-n1')));

Transform _depositTransform(WidgetTester tester) =>
    tester.widget<Transform>(find.byKey(const Key('landing-basin-deposit-n1')));

Transform _depositResponseTransform(WidgetTester tester) =>
    tester.widget<Transform>(
      find.byKey(const Key('landing-basin-deposit-response-n1')),
    );

Transform _depositRotationTransform(WidgetTester tester) =>
    tester.widget<Transform>(
      find.byKey(const Key('landing-basin-deposit-rotation-n1')),
    );

Transform _transformByKey(WidgetTester tester, String key) =>
    tester.widget<Transform>(find.byKey(Key(key)));

double _effectOpacity(WidgetTester tester, String key) =>
    tester.widget<Opacity>(find.byKey(Key(key))).opacity;

void main() {
  testWidgets(
    'renders stable N1/T1 roots and omits rig feedback without a rig',
    (tester) async {
      await _pumpVisual(tester);

      expect(find.byKey(const Key('landing-basin-deposit-n1')), findsOneWidget);
      expect(find.byKey(const Key('landing-basin-robot-n1')), findsOneWidget);

      await _pumpVisual(tester, rig: null);

      expect(find.byKey(const Key('landing-basin-deposit-n1')), findsOneWidget);
      expect(find.byKey(const Key('landing-basin-robot-n1')), findsNothing);
      expect(find.byKey(const Key('landing-basin-impact-n1')), findsNothing);
    },
  );

  testWidgets(
    'plays one one-second contact sequence and does not restart same sequence',
    (tester) async {
      await _pumpVisual(tester, impactSequence: 0);
      final restRobot = _robotTransform(tester).transform;
      final restSize = tester.getSize(
        find.byType(LandingBasinMiningNodeVisual),
      );

      await _pumpVisual(tester, impactSequence: 1);
      expect(find.byKey(const Key('landing-basin-impact-n1')), findsNothing);
      expect(_depositTransform(tester).transform.storage[0], closeTo(1, .001));

      await tester.pump(const Duration(milliseconds: 100));
      expect(_robotTransform(tester).transform, isNot(equals(restRobot)));
      expect(_robotTransform(tester).transform.storage[12], greaterThan(0));
      expect(
        _depositTransform(tester).transform.storage[0],
        closeTo(.986, .002),
      );
      expect(
        tester.getSize(find.byType(LandingBasinMiningNodeVisual)),
        restSize,
      );

      final continuingRobotDx = _robotTransform(tester).transform.storage[12];
      await _pumpVisual(tester, impactSequence: 1);
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        _robotTransform(tester).transform.storage[12],
        greaterThan(continuingRobotDx),
      );

      await _pumpVisual(tester, impactSequence: 4);
      expect(find.byKey(const Key('landing-basin-impact-n1')), findsNothing);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('landing-basin-impact-n1')), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));

      expect(find.byKey(const Key('landing-basin-impact-n1')), findsNothing);
      expect(_robotTransform(tester).transform, equals(restRobot));
      expect(_depositTransform(tester).transform.storage[0], closeTo(1, .001));
      expect(
        tester.getSize(find.byType(LandingBasinMiningNodeVisual)),
        restSize,
      );
    },
  );

  testWidgets('separates wind-up, strike, and layered aftermath beats', (
    tester,
  ) async {
    await _pumpVisual(tester, impactSequence: 0);
    final restRobot = _robotTransform(tester).transform;

    await _pumpVisual(tester, impactSequence: 1);
    await tester.pump(const Duration(milliseconds: 100));

    expect(_robotTransform(tester).transform.storage[12], greaterThan(0));
    expect(_depositTransform(tester).transform.storage[0], lessThan(1));
    expect(find.byKey(const Key('landing-basin-impact-n1')), findsNothing);
    expect(find.byKey(const Key('landing-basin-sparks-n1')), findsNothing);

    await tester.pump(const Duration(milliseconds: 300));

    expect(_robotTransform(tester).transform.storage[12], lessThan(0));
    expect(
      _depositResponseTransform(tester).transform.storage[12].abs() +
          _depositResponseTransform(tester).transform.storage[13].abs(),
      greaterThan(0),
    );
    expect(
      _depositRotationTransform(tester).transform.storage[1].abs(),
      greaterThan(.01),
    );
    expect(find.byKey(const Key('landing-basin-impact-n1')), findsOneWidget);
    expect(find.byKey(const Key('landing-basin-sparks-n1')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 180));

    for (final key in [
      'landing-basin-sparks-n1',
      'landing-basin-rock-chips-n1',
      'landing-basin-dust-n1',
      'landing-basin-gold-glow-n1',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget);
      expect(_effectOpacity(tester, key), greaterThan(0));
    }
    expect(_robotTransform(tester).transform.storage[12], greaterThan(0));

    await tester.pump(const Duration(milliseconds: 420));

    expect(find.byKey(const Key('landing-basin-impact-n1')), findsNothing);
    expect(find.byKey(const Key('landing-basin-sparks-n1')), findsNothing);
    expect(find.byKey(const Key('landing-basin-rock-chips-n1')), findsNothing);
    expect(find.byKey(const Key('landing-basin-dust-n1')), findsNothing);
    expect(find.byKey(const Key('landing-basin-gold-glow-n1')), findsNothing);
    expect(_robotTransform(tester).transform, equals(restRobot));
  });

  testWidgets('reaches the authored robot and deposit phase endpoints', (
    tester,
  ) async {
    await _pumpVisual(tester, impactSequence: 0);
    await _pumpVisual(tester, impactSequence: 1);

    await tester.pump(const Duration(milliseconds: 140));
    expect(_robotTransform(tester).transform.storage[12], closeTo(9.92, .02));
    expect(_depositTransform(tester).transform.storage[0], closeTo(.973, .001));

    await tester.pump(const Duration(milliseconds: 100));
    expect(_robotTransform(tester).transform.storage[12], closeTo(12, .02));
    expect(_depositTransform(tester).transform.storage[0], closeTo(.92, .001));

    await tester.pump(const Duration(milliseconds: 220));
    expect(_robotTransform(tester).transform.storage[12], closeTo(-7.2, .02));
    expect(_depositTransform(tester).transform.storage[0], closeTo(1.08, .001));

    await tester.pump(const Duration(milliseconds: 160));
    expect(_robotTransform(tester).transform.storage[12], closeTo(4, .02));

    await tester.pump(const Duration(milliseconds: 380));
    expect(_robotTransform(tester).transform.storage[12], closeTo(0, .02));
    expect(_depositTransform(tester).transform.storage[0], closeTo(1, .001));
    expect(find.byKey(const Key('landing-basin-impact-n1')), findsNothing);
  });

  testWidgets('reduced motion keeps spatial transforms and bounds fixed', (
    tester,
  ) async {
    await _pumpVisual(tester, impactSequence: 0, reducedMotion: true);
    final restRobot = _robotTransform(tester).transform;
    final restDeposit = _depositTransform(tester).transform;
    final restSize = tester.getSize(find.byType(LandingBasinMiningNodeVisual));

    await _pumpVisual(tester, impactSequence: 1, reducedMotion: true);
    await tester.pump(const Duration(milliseconds: 100));

    expect(_robotTransform(tester).transform, equals(restRobot));
    expect(_depositTransform(tester).transform, equals(restDeposit));
    expect(find.byKey(const Key('landing-basin-impact-n1')), findsNothing);
    expect(tester.getSize(find.byType(LandingBasinMiningNodeVisual)), restSize);

    await tester.pump(const Duration(milliseconds: 300));
    for (final key in [
      'landing-basin-sparks-n1',
      'landing-basin-rock-chips-n1',
      'landing-basin-dust-n1',
      'landing-basin-gold-glow-n1',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget);
      expect(
        _transformByKey(tester, '$key-transform').transform,
        equals(Matrix4.identity()),
      );
      expect(
        _transformByKey(tester, '$key-scale').transform,
        equals(Matrix4.identity()),
      );
    }
    for (final key in [
      'landing-basin-robot-response-n1',
      'landing-basin-robot-scale-n1',
      'landing-basin-deposit-response-n1',
      'landing-basin-deposit-rotation-n1',
      'landing-basin-deposit-n1',
    ]) {
      expect(
        _transformByKey(tester, key).transform,
        equals(Matrix4.identity()),
      );
    }
    expect(_robotTransform(tester).transform, equals(restRobot));
    expect(_depositTransform(tester).transform, equals(restDeposit));

    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const Key('landing-basin-impact-n1')), findsNothing);
    expect(_robotTransform(tester).transform, equals(restRobot));
    expect(_depositTransform(tester).transform, equals(restDeposit));
    expect(tester.getSize(find.byType(LandingBasinMiningNodeVisual)), restSize);
  });

  testWidgets(
    'keeps reduced-motion effects visible for the authored sequence window',
    (tester) async {
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      await _pumpVisual(tester, impactSequence: 0, reducedMotion: true);
      await _pumpVisual(tester, impactSequence: 1, reducedMotion: true);
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const Key('landing-basin-gold-glow-n1')),
        findsOneWidget,
      );
      expect(
        _effectOpacity(tester, 'landing-basin-gold-glow-n1'),
        greaterThan(0),
      );
    },
  );

  testWidgets('disposes the animation controller when the visual is removed', (
    tester,
  ) async {
    await _pumpVisual(tester, impactSequence: 0, reducedMotion: true);
    await _pumpVisual(tester, impactSequence: 1, reducedMotion: true);
    await tester.pump(const Duration(milliseconds: 100));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
