import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_save_repository.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:horologium/mining/presentation/mine_site_screen.dart';
import 'package:horologium/mining/presentation/mining_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/mining_grid_fixtures.dart';
import '../../support/test_fonts.dart';
import 'mining_shell_harness.dart';

/// Narrow-landscape result-panel clearance that depends on production Orbitron
/// metrics: the recovery notice is the longest authored message, and only the
/// real font wraps it into the multiline geometry that can reach the landscape
/// Mine Site Sell. Kept in its own test file so VM FontLoader state never
/// leaks into unrelated `mining_shell_test.dart` tests.
void main() {
  setUpAll(loadProductionTestFonts);
  tearDownAll(restoreProductionFontsInWebTests);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const recoveryMessage =
      'Mining progress could not be loaded, so a fresh mining save was '
      'started.';

  /// Asserts the visible result panel's rect does not intersect [chrome].
  void expectPanelClearOf(WidgetTester tester, Finder chrome) {
    expect(chrome, findsOneWidget, reason: 'chrome $chrome must be present');
    final panel = tester.getRect(find.byKey(const Key('mining-result-panel')));
    final blocked = tester.getRect(chrome);
    final intersects =
        panel.left < blocked.right &&
        panel.right > blocked.left &&
        panel.top < blocked.bottom &&
        panel.bottom > blocked.top;
    expect(
      intersects,
      isFalse,
      reason: 'result panel $panel overlaps $chrome at $blocked',
    );
  }

  /// Installs a filter that swallows only the pre-existing chrome
  /// RenderFlex overflows thrown at extreme text scales or sub-500px
  /// heights: each exception's error-causing element is walked up to a
  /// keyed ancestor and drained only when that ancestor is fixed HUD or
  /// surface chrome. `takeException` cannot see the source — it returns
  /// only the summary string and bundles simultaneous exceptions — so the
  /// check runs in `FlutterError.onError`, where the details still carry
  /// it. Any other error — including a result-panel failure, which is a
  /// Stack sibling of every keyed surface below — is forwarded to the
  /// previous handler, stays pending, and fails the test.
  void swallowOnlyChromeOverflows() {
    const chromeKeys = {
      'mine-site-screen',
      'stellar-map-screen',
      'mining-bottom-navigation',
      'mining-shell-placeholder',
      'site-deck-scroll',
      'site-deck-planet-progress',
      'site-deck-next-goal',
      'site-deck-sell',
      'site-deck-header-art',
    };
    final previous = FlutterError.onError;
    addTearDown(() => FlutterError.onError = previous);
    FlutterError.onError = (details) {
      final exception = details.exception;
      var isChromeOverflow =
          exception is FlutterError &&
          exception.message.startsWith('A RenderFlex overflowed by');
      if (isChromeOverflow) {
        var underChrome = false;
        for (final node
            in details.informationCollector?.call() ??
                const <DiagnosticsNode>[]) {
          if (node is DiagnosticsDebugCreator && node.value is DebugCreator) {
            (node.value as DebugCreator).element.visitAncestorElements((
              ancestor,
            ) {
              final key = ancestor.widget.key;
              if (key is ValueKey<String> && chromeKeys.contains(key.value)) {
                underChrome = true;
              }
              return !underChrome;
            });
          }
        }
        isChromeOverflow = underChrome;
      }
      if (!isChromeOverflow) previous?.call(details);
    };
  }

  /// Boots a recovered (malformed) save so the shell's longest authored
  /// message is visible on the current primary surface.
  Future<void> pumpRecoveryNotice(
    WidgetTester tester, {
    required Size viewport,
    double textScale = 1.0,
    bool boldText = false,
    EdgeInsets safeArea = const EdgeInsets.only(left: 44, right: 44),
  }) async {
    SharedPreferences.setMockInitialValues({
      MiningSaveRepository.saveKey: '{ malformed mining json',
    });
    await pumpShell(
      tester,
      repository: CountingMiningSaveRepository(),
      viewport: viewport,
      safeArea: safeArea,
      useViewSafeArea: true,
      textScale: textScale,
      boldText: boldText,
      pumpCycles: 12,
    );
  }

  /// Boots a recovered (malformed) save so the shell's longest authored
  /// message is visible, then enters Landing Basin so the landscape Mine Site
  /// chrome is on screen beneath the still-visible notice.
  Future<void> pumpMineSiteWithRecoveryNotice(
    WidgetTester tester, {
    required Size viewport,
    double textScale = 1.0,
    bool boldText = false,
    EdgeInsets safeArea = const EdgeInsets.only(left: 44, right: 44),
  }) async {
    await pumpRecoveryNotice(
      tester,
      viewport: viewport,
      textScale: textScale,
      boldText: boldText,
      safeArea: safeArea,
    );

    final enter = find.byKey(const Key('site-card-landingBasin-enter'));
    await tester.ensureVisible(enter);
    await tester.pump();
    await tester.tap(enter);
    await tester.pump();
  }

  /// Boots a valid save with sellable cargo, enters Landing Basin, and sells
  /// so a real one-line sale notice is visible over the landscape Mine Site.
  Future<void> pumpMineSiteWithSaleNotice(
    WidgetTester tester, {
    required Size viewport,
    double textScale = 1.0,
    EdgeInsets safeArea = const EdgeInsets.only(left: 44, right: 44),
  }) async {
    final repository = CountingMiningSaveRepository();
    final base = MiningSave.initial(nowUtc: miningShellTestStart);
    final deployCell = deployableMiningCells(
      MiningContentRegistry.stellarMining().site(MiningSiteId.landingBasin),
    ).first;
    await repository.save(
      base.copyWith(
        sites: {
          ...base.sites,
          MiningSiteId.landingBasin: base.sites[MiningSiteId.landingBasin]!
              .copyWith(
                commissioned: true,
                storedAmount: 10,
                rigPlacements: [
                  MiningRigPlacement(tier: RigTier.t1, cell: deployCell),
                ],
              ),
        },
      ),
    );
    await pumpShell(
      tester,
      repository: repository,
      viewport: viewport,
      safeArea: safeArea,
      useViewSafeArea: true,
      textScale: textScale,
    );

    final enter = find.byKey(const Key('site-card-landingBasin-enter'));
    await tester.ensureVisible(enter);
    await tester.pump();
    await tester.tap(enter);
    await tester.pump();
    await tester.tap(find.byKey(const Key('mine-site-sell')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Sold'), findsOneWidget);
  }

  for (final viewport in const [Size(640, 360), Size(667, 375)]) {
    for (final textScale in const [1.0, 1.3]) {
      final label =
          '${viewport.width.toInt()}x${viewport.height.toInt()} '
          'text $textScale';
      testWidgets(
        'recovery notice clears landscape Mine Site chrome at $label',
        (tester) async {
          await pumpMineSiteWithRecoveryNotice(
            tester,
            viewport: viewport,
            textScale: textScale,
          );

          expect(find.text(recoveryMessage), findsOneWidget);
          for (final key in const [
            'mining-cash-chip',
            'mine-site-cargo',
            'mine-site-right-rail',
            'mine-site-sell',
            'mining-bottom-navigation',
          ]) {
            expectPanelClearOf(tester, find.byKey(Key(key)));
          }
        },
      );
    }
  }

  for (final textScale in const [1.0, 1.3]) {
    testWidgets(
      'one-line sale notice keeps landscape Sell clearance and guard gap '
      'at 640x360 text $textScale',
      (tester) async {
        await pumpMineSiteWithSaleNotice(
          tester,
          viewport: const Size(640, 360),
          textScale: textScale,
        );

        final panel = tester.getRect(
          find.byKey(const Key('mining-result-panel')),
        );
        final sell = tester.getRect(find.byKey(const Key('mine-site-sell')));
        final intersects =
            panel.left < sell.right &&
            panel.right > sell.left &&
            panel.top < sell.bottom &&
            panel.bottom > sell.top;
        expect(intersects, isFalse, reason: 'panel $panel vs sell $sell');
        if (panel.left >= sell.right + 12 - .5) {
          // Stepped right of the Sell: horizontally separated at any height.
          expect(panel.left, greaterThanOrEqualTo(sell.right + 12 - .5));
        } else {
          // Centered: the clearance guard's 8px margin must hold against the
          // real rendered Sell column.
          expect(
            panel.bottom,
            lessThanOrEqualTo(sell.top - 8 + .5),
            reason: 'panel $panel vs sell top ${sell.top}',
          );
        }
      },
    );
  }

  for (final textScale in const [1.0, 1.3]) {
    testWidgets(
      'recovery notice panel stays on-screen and clears chrome at 568x320 '
      'text $textScale',
      (tester) async {
        const viewport = Size(568, 320);
        await pumpMineSiteWithRecoveryNotice(
          tester,
          viewport: viewport,
          textScale: textScale,
        );
        expect(find.text(recoveryMessage), findsOneWidget);

        final panel = tester.getRect(
          find.byKey(const Key('mining-result-panel')),
        );
        expect(panel.left, greaterThanOrEqualTo(0), reason: '$panel');
        expect(panel.top, greaterThanOrEqualTo(0), reason: '$panel');
        expect(
          panel.right,
          lessThanOrEqualTo(viewport.width),
          reason: '$panel',
        );
        expect(
          panel.bottom,
          lessThanOrEqualTo(viewport.height),
          reason: '$panel',
        );
        for (final key in const [
          'mining-cash-chip',
          'mine-site-cargo',
          'mine-site-right-rail',
          'mine-site-sell',
          'mining-bottom-navigation',
        ]) {
          expectPanelClearOf(tester, find.byKey(Key(key)));
        }
      },
    );
  }

  testWidgets(
    'recovery notice text stays fully on-screen at 568x320 text 1.0',
    (tester) async {
      const viewport = Size(568, 320);
      await pumpMineSiteWithRecoveryNotice(tester, viewport: viewport);
      expect(find.text(recoveryMessage), findsOneWidget);

      final text = tester.getRect(find.text(recoveryMessage));
      expect(text.top, greaterThanOrEqualTo(0), reason: '$text');
      expect(text.bottom, lessThanOrEqualTo(viewport.height), reason: '$text');
    },
  );

  for (final textScale in const [1.0, 1.3]) {
    testWidgets(
      'recovery notice panel stays on-screen at 640x360 text $textScale',
      (tester) async {
        const viewport = Size(640, 360);
        await pumpMineSiteWithRecoveryNotice(
          tester,
          viewport: viewport,
          textScale: textScale,
        );
        expect(find.text(recoveryMessage), findsOneWidget);

        final panel = tester.getRect(
          find.byKey(const Key('mining-result-panel')),
        );
        expect(panel.left, greaterThanOrEqualTo(0), reason: '$panel');
        expect(panel.top, greaterThanOrEqualTo(0), reason: '$panel');
        expect(
          panel.right,
          lessThanOrEqualTo(viewport.width),
          reason: '$panel',
        );
        expect(
          panel.bottom,
          lessThanOrEqualTo(viewport.height),
          reason: '$panel',
        );
        final text = tester.getRect(find.text(recoveryMessage));
        expect(text.top, greaterThanOrEqualTo(0), reason: '$text');
        expect(
          text.bottom,
          lessThanOrEqualTo(viewport.height),
          reason: '$text',
        );
      },
    );
  }

  for (final textScale in const [1.0, 1.3]) {
    testWidgets('landscape Sell top estimate matches real geometry at 640x360 '
        'text $textScale with a bottom inset', (tester) async {
      const viewport = Size(640, 360);
      await pumpMineSiteWithSaleNotice(
        tester,
        viewport: viewport,
        textScale: textScale,
        safeArea: const EdgeInsets.only(left: 44, right: 44, bottom: 21),
      );

      final sellTop = tester
          .getRect(find.byKey(const Key('mine-site-sell')))
          .top;
      final screenContext = tester.element(
        find.byKey(const Key('mine-site-screen')),
      );
      // The landscape Sell anchors to the viewport bottom without a bottom
      // safe-area inset, so its top estimate takes no inset at all.
      final estimated = landscapeMineSellTop(
        viewport.height,
        MediaQuery.textScalerOf(screenContext),
        DefaultTextStyle.of(screenContext).style,
      );
      // The clearance guard may overestimate the Sell top by at most its
      // 8px margin; more means a centered panel could overlap the control.
      expect(
        estimated,
        lessThanOrEqualTo(sellTop + 8 + .5),
        reason: 'estimated top $estimated vs rendered sell top $sellTop',
      );
    });
  }

  testWidgets('clearance measurement equals the rendered Text geometry', (
    tester,
  ) async {
    const viewport = Size(640, 360);
    await pumpMineSiteWithRecoveryNotice(
      tester,
      viewport: viewport,
      textScale: 1.3,
    );
    expect(find.text(recoveryMessage), findsOneWidget);

    final panel = tester.getRect(find.byKey(const Key('mining-result-panel')));
    final rendered = tester.getSize(find.text(recoveryMessage));
    final shellContext = tester.element(find.text(recoveryMessage));
    final measured = MiningShell.measureMessageHeight(
      recoveryMessage,
      panelWidth: panel.width,
      textScaler: MediaQuery.textScalerOf(shellContext),
    );
    expect(
      measured,
      closeTo(rendered.height, .5),
      reason:
          'clearance measurement $measured must match the rendered Text '
          '${rendered.height} at panel width ${panel.width}',
    );
    // The frame is 14px vertical padding plus a 1px border per side.
    expect(
      panel.height,
      closeTo(measured + 30, .5),
      reason: 'panel height ${panel.height} vs measured $measured + frame 30',
    );
  });

  testWidgets('clearance measurement mirrors the rendered bold-text merge', (
    tester,
  ) async {
    const viewport = Size(640, 360);
    await pumpMineSiteWithRecoveryNotice(
      tester,
      viewport: viewport,
      boldText: true,
    );
    expect(find.text(recoveryMessage), findsOneWidget);

    final panel = tester.getRect(find.byKey(const Key('mining-result-panel')));
    final rendered = tester.getSize(find.text(recoveryMessage));
    final shellContext = tester.element(find.text(recoveryMessage));
    final measured = MiningShell.measureMessageHeight(
      recoveryMessage,
      panelWidth: panel.width,
      textScaler: MediaQuery.textScalerOf(shellContext),
      boldText: true,
    );
    expect(
      measured,
      closeTo(rendered.height, .5),
      reason:
          'bold clearance measurement $measured must match the rendered '
          'bold Text ${rendered.height} at panel width ${panel.width}',
    );
  });

  testWidgets('measurement guard keeps very small usable widths finite', (
    tester,
  ) async {
    // A degenerate usable width must not drive negative TextPainter
    // constraints; the measurement clamps it to zero and stays finite.
    for (final panelWidth in [0.0, 10.0, 34.0]) {
      final height = MiningShell.measureMessageHeight(
        recoveryMessage,
        panelWidth: panelWidth,
      );
      expect(height.isFinite, isTrue, reason: 'panelWidth $panelWidth');
      expect(height, greaterThanOrEqualTo(0), reason: 'panelWidth $panelWidth');
    }
  });

  testWidgets('short notice keeps the centered landscape geometry at 640x360', (
    tester,
  ) async {
    final repository = CountingMiningSaveRepository();
    final base = MiningSave.initial(nowUtc: miningShellTestStart);
    final deployCell = deployableMiningCells(
      MiningContentRegistry.stellarMining().site(MiningSiteId.landingBasin),
    ).first;
    await repository.save(
      base.copyWith(
        sites: {
          ...base.sites,
          MiningSiteId.landingBasin: base.sites[MiningSiteId.landingBasin]!
              .copyWith(
                commissioned: true,
                storedAmount: 10,
                rigPlacements: [
                  MiningRigPlacement(tier: RigTier.t1, cell: deployCell),
                ],
              ),
        },
      ),
    );
    await pumpShell(
      tester,
      repository: repository,
      viewport: const Size(640, 360),
      safeArea: const EdgeInsets.only(left: 44, right: 44),
      useViewSafeArea: true,
    );

    final enter = find.byKey(const Key('site-card-landingBasin-enter'));
    await tester.ensureVisible(enter);
    await tester.pump();
    await tester.tap(enter);
    await tester.pump();
    await tester.tap(find.byKey(const Key('mine-site-sell')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Sold'), findsOneWidget);
    // Safe-area top +144, centered in the 44px-inset safe area left of the
    // dock rail. The rail's 16px gap shrinks the centered panel to 416px:
    // left = 44+16 + (416-416)/2 = 60.
    final panel = tester.getRect(find.byKey(const Key('mining-result-panel')));
    expect(panel.top, closeTo(144, .5));
    expect(panel.left, closeTo(60, .5));
    expectPanelClearOf(tester, find.byKey(const Key('mine-site-sell')));
  });

  testWidgets(
    'recovery notice clears landscape Mine Site chrome at 874x402 text 2.0',
    (tester) async {
      // The app's fixed-size HUD and dock chrome overflow at 2.0 text scale
      // (pre-existing, outside this ticket); swallow only exceptions whose
      // error-causing element sits under keyed chrome so a result-panel
      // layout failure still fails this test.
      swallowOnlyChromeOverflows();
      await pumpMineSiteWithRecoveryNotice(
        tester,
        viewport: const Size(874, 402),
        textScale: 2.0,
      );
      expect(tester.takeException(), isNull);
      expect(find.text(recoveryMessage), findsOneWidget);
      // A collapsed (zero-height) panel clears every chrome rect below, so
      // assert it renders with real height too.
      final panel = tester.getRect(
        find.byKey(const Key('mining-result-panel')),
      );
      expect(panel.height, greaterThan(30), reason: '$panel');
      for (final key in const [
        'mining-cash-chip',
        'mine-site-cargo',
        'mine-site-right-rail',
        'mine-site-sell',
        'mining-bottom-navigation',
      ]) {
        expectPanelClearOf(tester, find.byKey(Key(key)));
      }
    },
  );

  testWidgets(
    'recovery notice stays above portrait Mine Site controls at 360x640 '
    'text 2.0',
    (tester) async {
      // Fixed-size HUD and dock chrome overflow at 2.0 (pre-existing);
      // swallow only exceptions sourced under keyed chrome so a panel
      // layout failure still fails.
      swallowOnlyChromeOverflows();
      await pumpMineSiteWithRecoveryNotice(
        tester,
        viewport: const Size(360, 640),
        textScale: 2.0,
        safeArea: EdgeInsets.zero,
      );
      expect(tester.takeException(), isNull);
      expect(find.text(recoveryMessage), findsOneWidget);
      for (final key in const [
        'mine-site-sell',
        'fleet-dock',
        'mining-bottom-navigation',
      ]) {
        expectPanelClearOf(tester, find.byKey(Key(key)));
      }
      final sell = tester.getRect(find.byKey(const Key('mine-site-sell')));
      final panel = tester.getRect(
        find.byKey(const Key('mining-result-panel')),
      );
      expect(panel.height, greaterThan(30), reason: '$panel');
      expect(panel.bottom, lessThanOrEqualTo(sell.top - 8 + .5));
      // The free run is shorter than the notice, so the panel must show a
      // visible truncation cue instead of silently clipping the last lines.
      final text = tester.widget<Text>(find.text(recoveryMessage));
      expect(text.maxLines, isNotNull);
      expect(text.overflow, TextOverflow.ellipsis);
    },
  );

  testWidgets(
    'recovery notice keeps a visible text line at 320x480 portrait with a '
    '20px top inset',
    (tester) async {
      // At this height the fixed chrome overflows (pre-existing); swallow
      // only exceptions sourced under keyed chrome.
      swallowOnlyChromeOverflows();
      await pumpMineSiteWithRecoveryNotice(
        tester,
        viewport: const Size(320, 480),
        safeArea: const EdgeInsets.only(top: 20),
      );
      expect(tester.takeException(), isNull);
      expect(find.text(recoveryMessage), findsOneWidget);

      // The run above the Sell cannot hold the frame, so the panel must fall
      // back left of the Sell (below the back button, above the dock) and
      // still render a full text line instead of collapsing to zero height.
      final panel = tester.getRect(
        find.byKey(const Key('mining-result-panel')),
      );
      final text = tester.getRect(find.text(recoveryMessage));
      expect(text.height, greaterThanOrEqualTo(13), reason: '$text');
      expect(
        text.bottom,
        lessThanOrEqualTo(panel.bottom + .5),
        reason: '$text vs $panel',
      );
      final sell = tester.getRect(find.byKey(const Key('mine-site-sell')));
      expect(
        panel.right,
        lessThanOrEqualTo(sell.left - 12 + .5),
        reason: 'panel $panel must end left of sell $sell',
      );
      for (final key in const [
        'mining-cash-chip',
        'mine-site-back',
        'mine-site-sell',
        'fleet-dock',
        'mining-bottom-navigation',
      ]) {
        expectPanelClearOf(tester, find.byKey(Key(key)));
      }
    },
  );

  testWidgets('recovery notice clears landscape Site Deck chrome at 640x360 '
      'text 2.0', (tester) async {
    await pumpRecoveryNotice(
      tester,
      viewport: const Size(640, 360),
      textScale: 2.0,
      safeArea: EdgeInsets.zero,
    );
    expect(find.byKey(const Key('site-deck-scroll')), findsOneWidget);
    expectPanelClearOf(tester, find.byKey(const Key('site-deck-next-goal')));
    expectPanelClearOf(
      tester,
      find.byKey(const Key('mining-bottom-navigation')),
    );
  });

  testWidgets(
    'recovery notice clears Stellar Map navigation at 568x320 text 1.3',
    (tester) async {
      await pumpRecoveryNotice(
        tester,
        viewport: const Size(568, 320),
        textScale: 1.3,
        safeArea: EdgeInsets.zero,
      );
      await tester.tap(find.byKey(const Key('mining-nav-stellarMap')));
      await tester.pump();
      expect(find.byKey(const Key('stellar-map-screen')), findsOneWidget);
      expectPanelClearOf(
        tester,
        find.byKey(const Key('mining-bottom-navigation')),
      );
    },
  );
}
