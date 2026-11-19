import 'package:flutter/material.dart';
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

  /// Boots a recovered (malformed) save so the shell's longest authored
  /// message is visible, then enters Landing Basin so the landscape Mine Site
  /// chrome is on screen beneath the still-visible notice.
  Future<void> pumpMineSiteWithRecoveryNotice(
    WidgetTester tester, {
    required Size viewport,
    double textScale = 1.0,
  }) async {
    SharedPreferences.setMockInitialValues({
      MiningSaveRepository.saveKey: '{ malformed mining json',
    });
    await pumpShell(
      tester,
      repository: CountingMiningSaveRepository(),
      viewport: viewport,
      safeArea: const EdgeInsets.only(left: 44, right: 44),
      useViewSafeArea: true,
      textScale: textScale,
      pumpCycles: 12,
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
      // The landscape Sell anchors to the viewport bottom without a bottom
      // safe-area inset, so its top estimate takes no inset at all.
      final estimated = landscapeMineSellTop(viewport.height);
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
    // dock rail: left = 44+16 + (640-44-104 - (44+16) - 420) / 2 = 66.
    final panel = tester.getRect(find.byKey(const Key('mining-result-panel')));
    expect(panel.top, closeTo(144, .5));
    expect(panel.left, closeTo(66, .5));
    expectPanelClearOf(tester, find.byKey(const Key('mine-site-sell')));
  });
}
