import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/next_goal_view.dart';
import 'package:horologium/mining/presentation/mining_next_goal_strip.dart';

const _commissionGoal = MiningNextGoalView(
  kind: MiningGoalKind.commissionSite,
  title: 'Commission Landing Basin',
  detail: 'Deploy a rig beside a resource.',
  target: MiningGoalTarget.mineSite(MiningSiteId.landingBasin),
  cash: 100,
);

const _unlockGoal = MiningNextGoalView(
  kind: MiningGoalKind.unlockSite,
  title: 'Unlock Carbon Ridge',
  detail: 'Unlock it on its site card.',
  target: MiningGoalTarget.none(),
  cash: 100,
  cashCost: 250,
);

Future<void> _pumpStrip(
  WidgetTester tester,
  MiningNextGoalView goal, {
  ValueChanged<MiningGoalTarget>? onSelected,
  bool compact = false,
  double width = 332,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Orbitron'),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: MiningNextGoalStrip(
                goal: goal,
                compact: compact,
                onSelected: onSelected ?? (_) {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  // Real Orbitron metrics: the test font's square glyphs understate line
  // height and overstate width, hiding both overflow and truncation.
  setUpAll(() async {
    if (kIsWeb) return;
    final loader = FontLoader('Orbitron')
      ..addFont(
        File(
          'assets/fonts/Orbitron-Variable.ttf',
        ).readAsBytes().then(ByteData.sublistView),
      );
    await loader.load();
  });

  testWidgets('renders the label, title, and detail', (tester) async {
    await _pumpStrip(tester, _commissionGoal);

    expect(find.textContaining('NEXT GOAL'), findsOneWidget);
    expect(find.textContaining('Commission Landing Basin'), findsOneWidget);
    expect(find.text('Deploy a rig beside a resource.'), findsOneWidget);
    expect(find.byKey(const Key('next-goal-cash')), findsNothing);
    expect(find.byKey(const Key('next-goal-progress-track')), findsNothing);
  });

  testWidgets('cash-gated goal shows its cash label and progress fill', (
    tester,
  ) async {
    await _pumpStrip(tester, _unlockGoal);

    expect(find.text('100 / 250'), findsOneWidget);
    final track = tester.getRect(
      find.byKey(const Key('next-goal-progress-track')),
    );
    final fill = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('next-goal-progress-fill')),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(fill.left, track.left);
    expect(fill.width, closeTo(track.width * 0.4, 0.01));
    expect(track.height, 3);
  });

  testWidgets('navigable goal is a semantic button that reports its target', (
    tester,
  ) async {
    final selected = <MiningGoalTarget>[];
    await _pumpStrip(tester, _commissionGoal, onSelected: selected.add);
    final semantics = tester.ensureSemantics();

    expect(find.byKey(const Key('next-goal-chevron')), findsOneWidget);
    final node = tester
        .getSemantics(find.byType(MiningNextGoalStrip))
        .getSemanticsData();
    expect(
      node.label,
      'Next goal: Commission Landing Basin. Deploy a rig beside a resource.',
    );
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.hasAction(SemanticsAction.tap), isTrue);

    await tester.tap(find.byType(MiningNextGoalStrip));
    await tester.pump();
    expect(selected, [
      const MiningGoalTarget.mineSite(MiningSiteId.landingBasin),
    ]);

    tester.semantics.performAction(
      find.semantics.byLabel(_commissionGoal.semanticsLabel),
      SemanticsAction.tap,
    );
    expect(selected, hasLength(2));
    expect(tester.getSize(find.byType(MiningNextGoalStrip)).height, 56);
    semantics.dispose();
  });

  testWidgets('untargeted goal has no chevron, button flag, or tap', (
    tester,
  ) async {
    final selected = <MiningGoalTarget>[];
    await _pumpStrip(tester, _unlockGoal, onSelected: selected.add);
    final semantics = tester.ensureSemantics();

    expect(find.byKey(const Key('next-goal-chevron')), findsNothing);
    final node = tester
        .getSemantics(find.byType(MiningNextGoalStrip))
        .getSemanticsData();
    expect(
      node.label,
      'Next goal: Unlock Carbon Ridge. Unlock it on its site card. '
      '100 of 250 cash.',
    );
    expect(node.flagsCollection.isButton, isFalse);
    expect(node.hasAction(SemanticsAction.tap), isFalse);

    await tester.tap(find.byType(MiningNextGoalStrip));
    await tester.pump();
    expect(selected, isEmpty);
    semantics.dispose();
  });

  testWidgets('compact variant is a single 48 px row', (tester) async {
    await _pumpStrip(tester, _unlockGoal, compact: true, width: 760);

    expect(tester.getSize(find.byType(MiningNextGoalStrip)).height, 48);
    expect(find.textContaining('Unlock it on its site card.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a navigable goal without a handler is informational', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MiningNextGoalStrip(goal: _commissionGoal, onSelected: null),
        ),
      ),
    );
    final semantics = tester.ensureSemantics();

    expect(find.byKey(const Key('next-goal-chevron')), findsNothing);
    final node = tester
        .getSemantics(find.byType(MiningNextGoalStrip))
        .getSemanticsData();
    expect(node.flagsCollection.isButton, isFalse);
    expect(node.hasAction(SemanticsAction.tap), isFalse);
    semantics.dispose();
  });

  testWidgets('large text keeps both lines visible at the 1.3 cap', (
    tester,
  ) async {
    for (final textScale in [1.5, 2.0, 3.0]) {
      for (final goal in [_commissionGoal, _unlockGoal]) {
        for (final compact in [false, true]) {
          final reason = '$textScale ${goal.title} compact=$compact';
          await _pumpStrip(
            tester,
            goal,
            compact: compact,
            width: compact ? 850 : 332,
            textScale: textScale,
          );

          expect(tester.takeException(), isNull, reason: reason);
          final strip = tester.getRect(find.byType(MiningNextGoalStrip));
          expect(strip.height, compact ? 48 : 56, reason: reason);
          expect(
            find.byKey(const Key('next-goal-cash')),
            goal.isCashGated ? findsOneWidget : findsNothing,
            reason: reason,
          );
          final title = find.textContaining(goal.title);
          expect(
            tester.renderObject<RenderParagraph>(title).textScaler.scale(10),
            closeTo(13, 0.001),
            reason: reason,
          );
          if (compact) continue;

          // Portrait keeps the detail on its own line inside the strip.
          final detail = find.text(goal.detail);
          expect(detail, findsOneWidget, reason: reason);
          final detailRect = tester.getRect(detail);
          expect(detailRect.top, greaterThan(tester.getRect(title).top));
          expect(detailRect.bottom, lessThanOrEqualTo(strip.bottom));
        }
      }
    }
  });

  testWidgets('portrait title keeps its own full line beside a large cost', (
    tester,
  ) async {
    const goal = MiningNextGoalView(
      kind: MiningGoalKind.unlockSite,
      title: 'Unlock Cobalt Chasm',
      detail: 'Unlock it on its site card.',
      target: MiningGoalTarget.none(),
      cash: 25_000,
      cashCost: 30_000,
    );
    // 332 and 374 are the strip widths on 360 and 402 px portrait decks.
    for (final (width, textScale) in [(332.0, 1.0), (374.0, 2.0)]) {
      final reason = '$width at $textScale';
      await _pumpStrip(tester, goal, width: width, textScale: textScale);

      expect(tester.takeException(), isNull, reason: reason);
      expect(
        tester
            .renderObject<RenderParagraph>(find.textContaining(goal.title))
            .didExceedMaxLines,
        isFalse,
        reason: reason,
      );
      expect(
        tester.getCenter(find.byKey(const Key('next-goal-cash'))).dy,
        closeTo(tester.getCenter(find.text(goal.detail)).dy, 2),
        reason: 'cash shares the detail line: $reason',
      );
    }
  }, skip: kIsWeb);

  testWidgets('long copy ellipsizes at 1.3 text scale without overflow', (
    tester,
  ) async {
    const longGoal = MiningNextGoalView(
      kind: MiningGoalKind.commissionSite,
      title: 'Commission Titanium Highlands',
      detail: 'Last Mars Frontier site: mastery pays +20.00M cash.',
      target: MiningGoalTarget.mineSite(MiningSiteId.titaniumHighlands),
      cash: 12_000,
      cashCost: 25_000,
    );
    for (final compact in [false, true]) {
      await _pumpStrip(
        tester,
        longGoal,
        compact: compact,
        width: compact ? 850 : 332,
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull, reason: 'compact=$compact');
    }
  });
}
