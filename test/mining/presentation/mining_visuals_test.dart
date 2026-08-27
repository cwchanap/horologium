import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/presentation/mining_theme.dart';
import 'package:horologium/mining/presentation/mining_visuals.dart';

void main() {
  final content = MiningContentRegistry.stellarMining();

  test('keeps authored site and planet asset paths structural', () {
    for (final planet in content.planets.values) {
      expect(planet.planetAsset, isNotEmpty);
      for (final site in planet.sites) {
        expect(site.cavernAsset, isNotEmpty);
        expect(site.nodeAsset, isNotEmpty);
        expect(site.cardAsset, isNotEmpty);
      }
    }
  });

  test('exposes the shared anchors and common asset paths', () {
    expect(MiningVisuals.portraitNodeAnchors, [
      const Alignment(-0.55, -0.30),
      const Alignment(0.50, -0.24),
      const Alignment(-0.42, 0.36),
      const Alignment(0.48, 0.40),
    ]);
    expect(MiningVisuals.landscapeNodeAnchors, [
      const Alignment(-0.56, -0.38),
      const Alignment(0.34, -0.34),
      const Alignment(-0.40, 0.35),
      const Alignment(0.40, 0.36),
    ]);
    expect(
      MiningVisuals.rigAsset(RigTier.t3),
      'assets/images/mining/rigs/t3.png',
    );
    expect(MiningVisuals.cashIcon, 'assets/images/mining/icons/cash.png');
    expect(MiningVisuals.cargoIcon, 'assets/images/mining/icons/cargo.png');
    expect(MiningVisuals.mergeIcon, 'assets/images/mining/icons/merge.png');
    expect(
      MiningVisuals.mergeBurst,
      'assets/images/mining/effects/merge_burst.png',
    );
    expect(MiningVisuals.offlineHero, 'assets/images/mining/offline/hero.png');
    expect(MiningTheme.accent, Colors.cyanAccent);
    expect(MiningTheme.hudPanel, const Color(0xE6162133));
    expect(MiningTheme.panel, const Color(0xF20E1828));
    expect(MiningTheme.warning, Colors.orangeAccent);
  });

  // The Chrome test runner stalls on the first rootBundle byte load; retain
  // the complete bundle proof for the host, coverage, and full test suites.
  testWidgets('every site cavern node and card resolves', (tester) async {
    for (final site in content.planets.values.expand(
      (planet) => planet.sites,
    )) {
      await rootBundle.load(site.cavernAsset);
      await rootBundle.load(site.nodeAsset);
      await rootBundle.load(site.cardAsset);
    }
    for (final tier in RigTier.values) {
      await rootBundle.load(MiningVisuals.rigAsset(tier));
    }
    for (final planet in content.planets.values) {
      await rootBundle.load(planet.planetAsset);
    }
    for (final path in [
      MiningVisuals.cashIcon,
      MiningVisuals.cargoIcon,
      MiningVisuals.mergeIcon,
      MiningVisuals.extractionIcon,
      MiningVisuals.logisticsIcon,
      MiningVisuals.surveyingIcon,
      MiningVisuals.mergeBurst,
      MiningVisuals.offlineHero,
    ]) {
      await rootBundle.load(path);
    }
  }, skip: kIsWeb);
}
