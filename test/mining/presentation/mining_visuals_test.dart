import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
        expect(site.depositAsset, isNotEmpty);
        expect(site.cardAsset, isNotEmpty);
      }
    }
  });

  test('exposes the common asset paths', () {
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
      expect(MiningDepositFrames.gold.stage(entry.key), entry.value);
    }
    for (final entry in {
      1: 'assets/images/mining/nodes/node-gold-idle-01.png',
      2: 'assets/images/mining/nodes/node-gold-idle-02.png',
      3: 'assets/images/mining/nodes/node-gold-idle-03.png',
      4: 'assets/images/mining/nodes/node-gold-idle-04.png',
    }.entries) {
      expect(MiningDepositFrames.gold.idle(entry.key), entry.value);
    }
    for (final entry in {
      1: 'assets/images/mining/nodes/node-gold-hit-01.png',
      2: 'assets/images/mining/nodes/node-gold-hit-02.png',
      3: 'assets/images/mining/nodes/node-gold-hit-03.png',
    }.entries) {
      expect(MiningDepositFrames.gold.hit(entry.key), entry.value);
    }
    for (final entry in {
      1: 'assets/images/mining/nodes/node-gold-exhaust-01.png',
      2: 'assets/images/mining/nodes/node-gold-exhaust-02.png',
      3: 'assets/images/mining/nodes/node-gold-exhaust-03.png',
      4: 'assets/images/mining/nodes/node-gold-exhaust-04.png',
    }.entries) {
      expect(MiningDepositFrames.gold.exhaust(entry.key), entry.value);
    }
    expect(() => MiningDepositFrames.gold.idle(0), throwsRangeError);
    expect(() => MiningDepositFrames.gold.hit(4), throwsRangeError);
    expect(() => MiningDepositFrames.gold.exhaust(5), throwsRangeError);
  });

  test('lists every frame of a family in precache order', () {
    expect(MiningDepositFrames.gold.all, [
      for (var i = 1; i <= 4; i++) MiningDepositFrames.gold.stage(i),
      for (var i = 1; i <= 4; i++) MiningDepositFrames.gold.idle(i),
      for (var i = 1; i <= 3; i++) MiningDepositFrames.gold.hit(i),
      for (var i = 1; i <= 4; i++) MiningDepositFrames.gold.exhaust(i),
    ]);
    expect(MiningDepositFrames.gold.all.toSet(), hasLength(15));
    expect(
      MiningDepositFrames.waterIce.stage(2),
      'assets/images/mining/nodes/node-water-ice-s2.png',
    );
    expect(
      MiningDepositFrames.waterIce.hit(1),
      'assets/images/mining/nodes/node-water-ice-hit-01.png',
    );
    expect(() => MiningDepositFrames.waterIce.stage(0), throwsRangeError);
  });

  test('animates only Landing Basin through the closed frame switch', () {
    for (final id in MiningSiteId.values) {
      expect(
        MiningVisuals.depositFramesFor(id),
        id == MiningSiteId.landingBasin ? MiningDepositFrames.gold : isNull,
        reason: id.name,
      );
    }
  });

  test('derives kebab-case widget key prefixes from site IDs', () {
    expect(
      MiningVisuals.siteKeyPrefix(MiningSiteId.landingBasin),
      'landing-basin',
    );
    expect(
      MiningVisuals.siteKeyPrefix(MiningSiteId.frozenBasin),
      'frozen-basin',
    );
    expect(
      MiningVisuals.siteKeyPrefix(MiningSiteId.titaniumHighlands),
      'titanium-highlands',
    );
  });

  test('maps every shared robot layer by closed identity', () {
    for (final tier in RigTier.values) {
      expect(
        MiningVisuals.miningRobotBodyAsset(tier),
        'assets/images/mining/robots/robot_${tier.name}_body.png',
      );
      expect(
        MiningVisuals.miningRobotArmAsset(tier),
        'assets/images/mining/robots/robot_${tier.name}_arm.png',
      );
    }
  });

  // The Chrome test runner stalls on the first rootBundle byte load; retain
  // the complete bundle proof for the host, coverage, and full test suites.
  testWidgets('every mining visual resolves with its authored dimensions', (
    tester,
  ) async {
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json'))
            as List<dynamic>;
    for (final family in ['Orbitron', 'IBM Plex Mono']) {
      final entries = fonts.where((entry) => entry['family'] == family);
      expect(entries, hasLength(1), reason: '$family must be registered once');
      final files = entries.single['fonts'] as List<dynamic>;
      expect(files, isNotEmpty);
      for (final file in files) {
        expect(
          file['asset'],
          startsWith('assets/fonts/${family.replaceAll(' ', '')}'),
        );
        await rootBundle.load(file['asset'] as String);
      }
    }
    final framePaths = [
      for (var frame = 1; frame <= 4; frame++)
        MiningDepositFrames.gold.idle(frame),
      for (var frame = 1; frame <= 3; frame++)
        MiningDepositFrames.gold.hit(frame),
      for (var frame = 1; frame <= 4; frame++)
        MiningDepositFrames.gold.exhaust(frame),
    ];
    for (final planet in content.planets.values) {
      await rootBundle.load(planet.planetAsset);
    }
    for (final site in content.planets.values.expand(
      (planet) => planet.sites,
    )) {
      await rootBundle.load(site.cavernAsset);
      await rootBundle.load(site.depositAsset);
      await rootBundle.load(site.cardAsset);
    }
    for (final tier in RigTier.values) {
      await rootBundle.load(MiningVisuals.rigAsset(tier));
      await rootBundle.load(MiningVisuals.miningRobotBodyAsset(tier));
      await rootBundle.load(MiningVisuals.miningRobotArmAsset(tier));
    }
    for (var stage = 1; stage <= 4; stage++) {
      await rootBundle.load(MiningDepositFrames.gold.stage(stage));
    }
    for (final path in framePaths) {
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
  }, skip: kIsWeb);
}
