import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/test_fonts.dart';
import 'mining_shell_harness.dart';

/// Mastery shell clamping and safe-area geometry assertions that depend on
/// production font bytes. Kept in its own test file so VM FontLoader state
/// never leaks into unrelated `mining_shell_test.dart` tests.
void main() {
  setUpAll(loadProductionTestFonts);
  tearDownAll(restoreProductionFontsInWebTests);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('mastery HUD-safe clamping', () {
    testWidgets('production font bytes are loaded for the clamping layout', (
      tester,
    ) async {
      final loaded = TextPainter(
        text: const TextSpan(
          text: 'Relaunch to start again',
          style: TextStyle(fontFamily: 'IBM Plex Mono', fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final missing = TextPainter(
        text: const TextSpan(
          text: 'Relaunch to start again',
          style: TextStyle(fontFamily: 'No Such Test Font', fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      expect(loaded.width, greaterThan(0));
      expect(
        loaded.width,
        isNot(closeTo(missing.width, .5)),
        reason: 'production font bytes must differ from the fallback font',
      );
      loaded.dispose();
      missing.dispose();
    });

    testWidgets(
      'final mastery at 390x720 top 47 text 1.3 keeps the close clear of the '
      'cargo gauge and all key content visible',
      (tester) async {
        await openFinalMasteryAt(
          tester,
          size: const Size(390, 720),
          safeArea: const EdgeInsets.only(top: 47, bottom: 34),
        );

        final gauge = tester.getRect(find.byKey(const Key('mine-site-cargo')));
        final close = find.bySemanticsLabel('Close FINAL PLANET MASTERED');
        final closeRect = tester.getRect(close);
        expect(
          closeRect.top,
          greaterThanOrEqualTo(gauge.bottom),
          reason: 'close $closeRect must clear gauge $gauge',
        );
        expect(gauge.overlaps(closeRect), isFalse);
        expect(close.hitTestable(), findsOneWidget);

        expectMasteryBodyContentVisible(tester, [
          find.byKey(const Key('planet-mastery-planet')),
          find.byKey(const Key('planet-mastery-reward')),
          find.text('completion reward'),
          find.text('RUN COMPLETE'),
          find.byKey(const Key('planet-mastery-multiplier')),
        ]);
        expect(find.textContaining('×2'), findsOneWidget);
        expect(
          find.byKey(const Key('planet-mastery-relaunch')).hitTestable(),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('planet-mastery-continue')).hitTestable(),
          findsOneWidget,
        );

        // The upper edge of the visible close circle is hit-testable.
        await tester.tapAt(Offset(closeRect.center.dx, closeRect.top + 4));
        await pumpSheet(tester);
        expect(find.byKey(const Key('planet-mastery-card')), findsNothing);
      },
    );

    testWidgets(
      'taps above the clamped 390x720 mastery card reach the barrier',
      (tester) async {
        await openFinalMasteryAt(
          tester,
          size: const Size(390, 720),
          safeArea: const EdgeInsets.only(top: 47, bottom: 34),
        );

        final card = tester.getRect(
          find.byKey(const Key('planet-mastery-card')),
        );
        await tester.tapAt(Offset(195, card.top - 20));
        await pumpSheet(tester);
        expect(find.byKey(const Key('planet-mastery-card')), findsNothing);
        expect(find.byKey(const Key('mine-site-screen')), findsOneWidget);
      },
    );

    for (final height in const [700.0, 701.0, 720.0]) {
      testWidgets(
        'final mastery close clears the gauge at 390x${height.toInt()} '
        'top 47 text 1.3',
        (tester) async {
          await openFinalMasteryAt(
            tester,
            size: Size(390, height),
            safeArea: const EdgeInsets.only(top: 47, bottom: 34),
          );

          final gauge = tester.getRect(
            find.byKey(const Key('mine-site-cargo')),
          );
          final close = find.bySemanticsLabel('Close FINAL PLANET MASTERED');
          final closeRect = tester.getRect(close);
          expect(
            closeRect.top,
            greaterThanOrEqualTo(gauge.bottom),
            reason: 'close $closeRect must clear gauge $gauge',
          );
          expect(gauge.overlaps(closeRect), isFalse);
          expect(close.hitTestable(), findsOneWidget);
          expectMasteryBodyContentVisible(tester, [
            find.byKey(const Key('planet-mastery-planet')),
            find.byKey(const Key('planet-mastery-reward')),
            find.text('completion reward'),
            find.text('RUN COMPLETE'),
            find.byKey(const Key('planet-mastery-multiplier')),
          ]);
          expect(
            find.byKey(const Key('planet-mastery-relaunch')).hitTestable(),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('planet-mastery-continue')).hitTestable(),
            findsOneWidget,
          );
        },
      );
    }

    testWidgets(
      'mastery opened in landscape follows rotation into 390x720 top 47 '
      'with the close clear of the gauge',
      (tester) async {
        await openFinalMasteryAt(
          tester,
          size: const Size(874, 402),
          safeArea: const EdgeInsets.fromLTRB(44, 0, 44, 21),
        );

        expect(find.byKey(const Key('planet-mastery-card')), findsOneWidget);
        tester.view.physicalSize = const Size(390, 720);
        tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
        tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
        await tester.pump();
        await pumpSheet(tester);

        final gauge = tester.getRect(find.byKey(const Key('mine-site-cargo')));
        final close = find.bySemanticsLabel('Close FINAL PLANET MASTERED');
        final closeRect = tester.getRect(close);
        expect(
          closeRect.top,
          greaterThanOrEqualTo(gauge.bottom),
          reason: 'close $closeRect must clear gauge $gauge after rotation',
        );
        expect(gauge.overlaps(closeRect), isFalse);
        expect(close.hitTestable(), findsOneWidget);
        expectMasteryBodyContentVisible(tester, [
          find.byKey(const Key('planet-mastery-planet')),
          find.byKey(const Key('planet-mastery-reward')),
          find.text('completion reward'),
          find.text('RUN COMPLETE'),
          find.byKey(const Key('planet-mastery-multiplier')),
        ]);
        expect(find.textContaining('×2'), findsOneWidget);
        expect(
          find.byKey(const Key('planet-mastery-relaunch')).hitTestable(),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('planet-mastery-continue')).hitTestable(),
          findsOneWidget,
        );
      },
    );
  });

  group('mastery card safe-area clearance', () {
    Future<void> openFinalMastery(
      WidgetTester tester, {
      required Size size,
      required double top,
      required double bottom,
      required double textScale,
    }) async {
      final repository = CountingMiningSaveRepository();
      await repository.save(nearFinalPlanetMasteryState(miningShellTestStart));
      await pumpShell(
        tester,
        repository: repository,
        viewport: size,
        theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Orbitron'),
        useViewSafeArea: true,
        safeArea: EdgeInsets.only(top: top, bottom: bottom),
        textScale: textScale,
      );
      await deployIntoMastery(
        tester,
        MiningSiteId.osmiumCaldera,
        osmiumDeployCell,
      );
    }

    for (final (size, top, bottom, textScale) in [
      (const Size(360, 640), 47.0, 34.0, 1.3),
      (const Size(430, 932), 59.0, 34.0, 1.3),
      (const Size(430, 932), 59.0, 34.0, 1.0),
      (const Size(360, 640), 47.0, 34.0, 1.0),
      (const Size(360, 640), 47.0, 0.0, 1.3),
      (const Size(360, 640), 0.0, 0.0, 1.3),
    ]) {
      final label =
          '${size.width.toInt()}x${size.height.toInt()} top $top '
          'bottom $bottom text $textScale';
      testWidgets(
        'final mastery close never covers the cargo gauge at $label',
        (tester) async {
          await openFinalMastery(
            tester,
            size: size,
            top: top,
            bottom: bottom,
            textScale: textScale,
          );

          final gauge = tester.getRect(
            find.byKey(const Key('mine-site-cargo')),
          );
          final close = find.bySemanticsLabel('Close FINAL PLANET MASTERED');
          final closeRect = tester.getRect(close);
          expect(
            closeRect.top,
            greaterThanOrEqualTo(gauge.bottom),
            reason:
                'the close hex $closeRect must clear the inline cargo gauge '
                '$gauge at $label',
          );
          expect(
            gauge.overlaps(closeRect),
            isFalse,
            reason: '$gauge $closeRect',
          );
          expect(close.hitTestable(), findsOneWidget);

          // The whole Io summary and the pinned actions stay on the first
          // frame; the card never asks the player to scroll to understand
          // the reward or relaunch.
          expectMasteryBodyContentVisible(tester, [
            find.byKey(const Key('planet-mastery-planet')),
            find.byKey(const Key('planet-mastery-reward')),
            find.text('completion reward'),
            find.text('RUN COMPLETE'),
            find.byKey(const Key('planet-mastery-multiplier')),
          ]);
          final relaunch = find.byKey(const Key('planet-mastery-relaunch'));
          final continueButton = find.byKey(
            const Key('planet-mastery-continue'),
          );
          expect(relaunch.hitTestable(), findsOneWidget);
          expect(continueButton.hitTestable(), findsOneWidget);
          expect(
            tester.getRect(relaunch).top,
            lessThan(tester.getRect(continueButton).top),
          );

          // The close control still dismisses the card onto the live site.
          await tester.tap(close);
          await pumpSheet(tester);
          expect(find.byKey(const Key('planet-mastery-card')), findsNothing);
          expect(find.byKey(const Key('mine-site-screen')), findsOneWidget);
          expect(find.byKey(const Key('mine-site-cargo')), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('mastery opened in landscape follows a rotation into a notched '
        'portrait with the close clear of the cargo gauge', (tester) async {
      final repository = CountingMiningSaveRepository();
      await repository.save(nearFinalPlanetMasteryState(miningShellTestStart));
      await pumpShell(
        tester,
        repository: repository,
        viewport: const Size(874, 402),
        theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Orbitron'),
        useViewSafeArea: true,
        safeArea: const EdgeInsets.only(left: 44, right: 44, bottom: 21),
        textScale: 1.3,
      );
      await tester.dragUntilVisible(
        find.byKey(const Key('site-card-osmiumCaldera-enter')),
        find.byKey(const Key('site-deck-scroll')),
        const Offset(0, -200),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('site-card-osmiumCaldera-enter')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('b1')));
      await tester.pump();
      await tapGridCell(tester, osmiumDeployCell);
      await pumpSheet(tester);
      expect(find.byKey(const Key('planet-mastery-card')), findsOneWidget);

      // Landscape with wide left/right insets: the card opens complete and
      // the right-hand cargo gauge is clear of the panel's left-mounted
      // close.
      final landscapeGauge = tester.getRect(
        find.byKey(const Key('mine-site-cargo')),
      );
      final landscapeClose = find.bySemanticsLabel(
        'Close FINAL PLANET MASTERED',
      );
      expect(landscapeGauge.overlaps(tester.getRect(landscapeClose)), isFalse);
      expectMasteryBodyContentVisible(tester, [
        find.byKey(const Key('planet-mastery-planet')),
        find.byKey(const Key('planet-mastery-reward')),
        find.text('completion reward'),
        find.text('RUN COMPLETE'),
        find.byKey(const Key('planet-mastery-multiplier')),
      ]);
      expect(
        find.byKey(const Key('planet-mastery-relaunch')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('planet-mastery-continue')).hitTestable(),
        findsOneWidget,
      );

      // Rotate while the card is open. The route's retained builder and the
      // inline Mine Site HUD both receive the live metrics change, so the
      // card's top inset has to follow rather than stay at its landscape
      // snapshot of zero.
      tester.view.physicalSize = const Size(430, 932);
      tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
      await tester.pump();
      await pumpSheet(tester);

      final gauge = tester.getRect(find.byKey(const Key('mine-site-cargo')));
      final close = find.bySemanticsLabel('Close FINAL PLANET MASTERED');
      final closeRect = tester.getRect(close);
      expect(
        closeRect.top,
        greaterThanOrEqualTo(gauge.bottom),
        reason:
            'the retained card $closeRect must clear the live cargo gauge '
            '$gauge after rotation',
      );
      expect(gauge.overlaps(closeRect), isFalse, reason: '$gauge $closeRect');
      expect(close.hitTestable(), findsOneWidget);

      expectMasteryBodyContentVisible(tester, [
        find.byKey(const Key('planet-mastery-planet')),
        find.byKey(const Key('planet-mastery-reward')),
        find.text('completion reward'),
        find.text('RUN COMPLETE'),
        find.byKey(const Key('planet-mastery-multiplier')),
      ]);
      final relaunch = find.byKey(const Key('planet-mastery-relaunch'));
      final continueButton = find.byKey(const Key('planet-mastery-continue'));
      expect(relaunch.hitTestable(), findsOneWidget);
      expect(continueButton.hitTestable(), findsOneWidget);
      expect(
        tester.getRect(relaunch).top,
        lessThan(tester.getRect(continueButton).top),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'nonfinal mastery keeps every Homeworld gate visible and the close '
      'clear of the cargo gauge at 360x640 top 47 text 1.3',
      (tester) async {
        final repository = CountingMiningSaveRepository();
        await repository.save(nearHomeworldMasteryState(miningShellTestStart));
        await pumpShell(
          tester,
          repository: repository,
          theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Orbitron'),
          useViewSafeArea: true,
          safeArea: const EdgeInsets.only(top: 47, bottom: 34),
          textScale: 1.3,
        );
        await deployIntoMastery(
          tester,
          MiningSiteId.graniteCrater,
          graniteCraterDeployCell,
        );

        final gauge = tester.getRect(find.byKey(const Key('mine-site-cargo')));
        final close = find.bySemanticsLabel('Close PLANET MASTERED');
        final closeRect = tester.getRect(close);
        expect(closeRect.top, greaterThanOrEqualTo(gauge.bottom));
        expect(gauge.overlaps(closeRect), isFalse);
        expect(close.hitTestable(), findsOneWidget);

        expectMasteryBodyContentVisible(tester, [
          find.byKey(const Key('planet-mastery-planet')),
          find.text('All 3 sites commissioned'),
          find.byKey(const Key('planet-mastery-successor')),
          for (var index = 0; index < 3; index++)
            find.byKey(Key('planet-mastery-requirement-$index')),
        ]);
        expect(
          find.byKey(const Key('planet-mastery-open-map')).hitTestable(),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('planet-mastery-continue')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
