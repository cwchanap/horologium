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
      expect(find.byKey(const Key('landing-basin-impact-n1')), findsOneWidget);
      expect(
        _depositTransform(tester).transform.storage[0],
        closeTo(.94, .001),
      );
      expect(
        tester
            .widget<Opacity>(find.byKey(const Key('landing-basin-impact-n1')))
            .opacity,
        closeTo(1, .001),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(_robotTransform(tester).transform, isNot(equals(restRobot)));
      expect(_robotTransform(tester).transform.storage[12], greaterThan(0));
      expect(
        _depositTransform(tester).transform.storage[0],
        closeTo(.94 + (.1 / .14 * .06), .002),
      );
      expect(
        tester.getSize(find.byType(LandingBasinMiningNodeVisual)),
        restSize,
      );

      await _pumpVisual(tester, impactSequence: 1);
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        _robotTransform(tester).transform.storage[12],
        closeTo(.12 * 40 - (.06 / .56 * .04 * 40), .02),
      );

      await _pumpVisual(tester, impactSequence: 4);
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

  testWidgets('reaches the authored robot and deposit phase endpoints', (
    tester,
  ) async {
    await _pumpVisual(tester, impactSequence: 0);
    await _pumpVisual(tester, impactSequence: 1);

    await tester.pump(const Duration(milliseconds: 140));
    expect(
      _robotTransform(tester).transform.storage[12],
      closeTo(.12 * 40, .02),
    );
    expect(_depositTransform(tester).transform.storage[0], closeTo(1, .001));

    await tester.pump(const Duration(milliseconds: 40));
    expect(
      tester
          .widget<Opacity>(find.byKey(const Key('landing-basin-impact-n1')))
          .opacity,
      closeTo(0, .001),
    );

    await tester.pump(const Duration(milliseconds: 520));
    expect(
      _robotTransform(tester).transform.storage[12],
      closeTo(.08 * 40, .02),
    );

    await tester.pump(const Duration(milliseconds: 300));
    expect(_robotTransform(tester).transform.storage[12], closeTo(0, .02));
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
    expect(find.byKey(const Key('landing-basin-impact-n1')), findsOneWidget);
    expect(tester.getSize(find.byType(LandingBasinMiningNodeVisual)), restSize);

    await tester.pump(const Duration(milliseconds: 900));
    expect(find.byKey(const Key('landing-basin-impact-n1')), findsNothing);
    expect(_robotTransform(tester).transform, equals(restRobot));
    expect(_depositTransform(tester).transform, equals(restDeposit));
    expect(tester.getSize(find.byType(LandingBasinMiningNodeVisual)), restSize);
  });

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
