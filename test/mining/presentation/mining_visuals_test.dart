import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/presentation/mining_theme.dart';
import 'package:horologium/mining/presentation/mining_visuals.dart';

Future<ui.Image> _decodeAsset(String path) async {
  final bytes = await rootBundle.load(path);
  final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
  final frame = await codec.getNextFrame();
  final image = frame.image;
  codec.dispose();
  return image;
}

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
    expect(
      MiningVisuals.goldNodeIdleStrip,
      'assets/images/mining/nodes/node-gold-idle-strip.png',
    );
    expect(
      MiningVisuals.goldNodeHitStrip,
      'assets/images/mining/nodes/node-gold-hit-strip.png',
    );
    expect(
      MiningVisuals.goldNodeExhaustStrip,
      'assets/images/mining/nodes/node-gold-exhaust-strip.png',
    );
    expect(MiningVisuals.offlineHero, 'assets/images/mining/offline/hero.png');
    expect(MiningTheme.accent, const Color(0xFF53D4E8));
    expect(MiningTheme.hudPanel, const Color(0xE6162133));
    expect(MiningTheme.panel, const Color(0xF20E1828));
    expect(MiningTheme.warning, const Color(0xFFFFD54A));
  });

  test('maps staged gold plates and frame paths by closed identity', () {
    for (final entry in {
      1: 'assets/images/mining/nodes/node-gold-s1.png',
      2: 'assets/images/mining/nodes/node-gold-s2.png',
      3: 'assets/images/mining/nodes/node-gold-s3.png',
      4: 'assets/images/mining/nodes/node-gold-s4.png',
    }.entries) {
      expect(MiningVisuals.goldNodeStageAsset(entry.key), entry.value);
    }
    for (final entry in {
      1: 'assets/images/mining/nodes/node-gold-idle-01.png',
      2: 'assets/images/mining/nodes/node-gold-idle-02.png',
      3: 'assets/images/mining/nodes/node-gold-idle-03.png',
      4: 'assets/images/mining/nodes/node-gold-idle-04.png',
    }.entries) {
      expect(MiningVisuals.goldNodeIdleAsset(entry.key), entry.value);
    }
    for (final entry in {
      1: 'assets/images/mining/nodes/node-gold-hit-01.png',
      2: 'assets/images/mining/nodes/node-gold-hit-02.png',
      3: 'assets/images/mining/nodes/node-gold-hit-03.png',
    }.entries) {
      expect(MiningVisuals.goldNodeHitAsset(entry.key), entry.value);
    }
    for (final entry in {
      1: 'assets/images/mining/nodes/node-gold-exhaust-01.png',
      2: 'assets/images/mining/nodes/node-gold-exhaust-02.png',
      3: 'assets/images/mining/nodes/node-gold-exhaust-03.png',
      4: 'assets/images/mining/nodes/node-gold-exhaust-04.png',
    }.entries) {
      expect(MiningVisuals.goldNodeExhaustAsset(entry.key), entry.value);
    }
    expect(() => MiningVisuals.goldNodeIdleAsset(0), throwsRangeError);
    expect(() => MiningVisuals.goldNodeHitAsset(4), throwsRangeError);
    expect(() => MiningVisuals.goldNodeExhaustAsset(5), throwsRangeError);
  });

  test('maps every articulated Landing Basin layer by closed identity', () {
    for (final tier in RigTier.values) {
      expect(
        MiningVisuals.landingBasinRobotBodyAsset(tier),
        'assets/images/mining/landing_basin/robot_${tier.name}_body.png',
      );
      expect(
        MiningVisuals.landingBasinRobotArmAsset(tier),
        'assets/images/mining/landing_basin/robot_${tier.name}_arm.png',
      );
    }
  });

  // The Chrome test runner stalls on the first rootBundle byte load; retain
  // the complete bundle proof for the host, coverage, and full test suites.
  testWidgets('every mining visual resolves with its authored dimensions', (
    tester,
  ) async {
    final framePaths = [
      for (var frame = 1; frame <= 4; frame++)
        MiningVisuals.goldNodeIdleAsset(frame),
      for (var frame = 1; frame <= 3; frame++)
        MiningVisuals.goldNodeHitAsset(frame),
      for (var frame = 1; frame <= 4; frame++)
        MiningVisuals.goldNodeExhaustAsset(frame),
    ];
    for (final site in content.planets.values.expand(
      (planet) => planet.sites,
    )) {
      await rootBundle.load(site.cavernAsset);
      await rootBundle.load(site.nodeAsset);
      await rootBundle.load(site.cardAsset);
    }
    for (final tier in RigTier.values) {
      await rootBundle.load(MiningVisuals.rigAsset(tier));
      await rootBundle.load(MiningVisuals.landingBasinRobotBodyAsset(tier));
      await rootBundle.load(MiningVisuals.landingBasinRobotArmAsset(tier));
    }
    for (var stage = 1; stage <= 4; stage++) {
      await rootBundle.load(MiningVisuals.goldNodeStageAsset(stage));
    }
    for (final path in framePaths) {
      await rootBundle.load(path);
    }
    for (final path in [
      MiningVisuals.goldNodeIdleStrip,
      MiningVisuals.goldNodeHitStrip,
      MiningVisuals.goldNodeExhaustStrip,
    ]) {
      await rootBundle.load(path);
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

    for (final path in framePaths) {
      final image = await tester.runAsync(() => _decodeAsset(path));
      expect(image, isNotNull);
      expect(image!.width, 512, reason: path);
      expect(image.height, 512, reason: path);
    }
    for (final entry in {
      MiningVisuals.goldNodeIdleStrip: const (2048, 512),
      MiningVisuals.goldNodeHitStrip: const (1536, 512),
      MiningVisuals.goldNodeExhaustStrip: const (2048, 512),
    }.entries) {
      final image = await tester.runAsync(() => _decodeAsset(entry.key));
      expect(image, isNotNull);
      expect(image!.width, entry.value.$1, reason: entry.key);
      expect(image.height, entry.value.$2, reason: entry.key);
    }
  }, skip: kIsWeb);
}
