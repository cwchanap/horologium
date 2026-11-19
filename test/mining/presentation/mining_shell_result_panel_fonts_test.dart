import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_save_repository.dart';
import 'package:horologium/mining/mining_state.dart';
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
