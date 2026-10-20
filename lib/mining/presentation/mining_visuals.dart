import 'package:horologium/mining/mining_content.dart';

abstract final class MiningVisuals {
  static String rigAsset(RigTier tier) =>
      'assets/images/mining/rigs/${tier.name}.png';

  static String miningRobotBodyAsset(RigTier tier) =>
      'assets/images/mining/robots/robot_${tier.name}_body.png';

  static String miningRobotArmAsset(RigTier tier) =>
      'assets/images/mining/robots/robot_${tier.name}_arm.png';

  /// Widget-key prefix for a site: its ID in kebab case
  /// (`landingBasin` -> `landing-basin`).
  static String siteKeyPrefix(MiningSiteId id) => id.name.replaceAllMapped(
    RegExp('[A-Z]'),
    (match) => '-${match[0]!.toLowerCase()}',
  );

  /// The animated deposit frame family for [id], or `null` when the site
  /// uses the static grid layer. Closed on purpose: adding an animated site
  /// means adding an approved frame family and a case here.
  static MiningDepositFrames? depositFramesFor(MiningSiteId id) => switch (id) {
    MiningSiteId.landingBasin => MiningDepositFrames.gold,
    MiningSiteId.frozenBasin => MiningDepositFrames.waterIce,
    MiningSiteId.carbonRidge ||
    MiningSiteId.graniteCrater ||
    MiningSiteId.titaniumHighlands ||
    MiningSiteId.heliumMare ||
    MiningSiteId.ochreBasin ||
    MiningSiteId.silicaDunes ||
    MiningSiteId.cobaltChasm ||
    MiningSiteId.nickelShoals ||
    MiningSiteId.platinumRift ||
    MiningSiteId.iridiumSpire => null,
  };

  static const cashIcon = 'assets/images/mining/icons/cash.png';
  static const cargoIcon = 'assets/images/mining/icons/cargo.png';
  static const mergeIcon = 'assets/images/mining/icons/merge.png';
  static const extractionIcon = 'assets/images/mining/icons/extraction.png';
  static const logisticsIcon = 'assets/images/mining/icons/logistics.png';
  static const surveyingIcon = 'assets/images/mining/icons/surveying.png';
  static const mergeBurst = 'assets/images/mining/effects/merge_burst.png';
  static const offlineHero = 'assets/images/mining/offline/hero.png';
}

/// One animated deposit's frame family: four fill stages, a four-frame idle
/// loop, a three-frame hit, and a four-frame exhaust beat.
enum MiningDepositFrames {
  gold('gold'),
  waterIce('water-ice');

  const MiningDepositFrames(this.slug);

  final String slug;

  String stage(int stage) => switch (stage) {
    1 || 2 || 3 || 4 => 'assets/images/mining/nodes/node-$slug-s$stage.png',
    _ => throw RangeError.range(stage, 1, 4, 'stage'),
  };

  String idle(int frame) => switch (frame) {
    1 || 2 || 3 || 4 => _framePath('idle', frame),
    _ => throw RangeError.range(frame, 1, 4, 'frame'),
  };

  String hit(int frame) => switch (frame) {
    1 || 2 || 3 => _framePath('hit', frame),
    _ => throw RangeError.range(frame, 1, 3, 'frame'),
  };

  String exhaust(int frame) => switch (frame) {
    1 || 2 || 3 || 4 => _framePath('exhaust', frame),
    _ => throw RangeError.range(frame, 1, 4, 'frame'),
  };

  /// Every frame path, in precache order.
  List<String> get all => [
    for (var i = 1; i <= 4; i++) stage(i),
    for (var i = 1; i <= 4; i++) idle(i),
    for (var i = 1; i <= 3; i++) hit(i),
    for (var i = 1; i <= 4; i++) exhaust(i),
  ];

  String _framePath(String beat, int frame) =>
      'assets/images/mining/nodes/node-$slug-$beat-${frame.toString().padLeft(2, '0')}.png';
}
