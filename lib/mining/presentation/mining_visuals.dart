import 'package:flutter/material.dart';
import 'package:horologium/mining/mining_content.dart';

abstract final class MiningVisuals {
  static const portraitNodeAnchors = <Alignment>[
    Alignment(-0.55, -0.30),
    Alignment(0.50, -0.24),
    Alignment(-0.42, 0.36),
    Alignment(0.48, 0.40),
  ];

  static const landscapeNodeAnchors = <Alignment>[
    Alignment(-0.56, -0.38),
    Alignment(0.34, -0.34),
    Alignment(-0.40, 0.35),
    Alignment(0.40, 0.36),
  ];

  static String rigAsset(RigTier tier) =>
      'assets/images/mining/rigs/${tier.name}.png';

  static String landingBasinRobotBodyAsset(RigTier tier) =>
      'assets/images/mining/landing_basin/robot_${tier.name}_body.png';

  static String landingBasinRobotArmAsset(RigTier tier) =>
      'assets/images/mining/landing_basin/robot_${tier.name}_arm.png';

  static String goldNodeStageAsset(int stage) => switch (stage) {
    1 || 2 || 3 || 4 => 'assets/images/mining/nodes/node-gold-s$stage.png',
    _ => throw RangeError.range(stage, 1, 4, 'stage'),
  };

  static String goldNodeIdleAsset(int frame) => switch (frame) {
    1 || 2 || 3 || 4 =>
      'assets/images/mining/nodes/node-gold-idle-${frame.toString().padLeft(2, '0')}.png',
    _ => throw RangeError.range(frame, 1, 4, 'frame'),
  };

  static String goldNodeHitAsset(int frame) => switch (frame) {
    1 || 2 || 3 =>
      'assets/images/mining/nodes/node-gold-hit-${frame.toString().padLeft(2, '0')}.png',
    _ => throw RangeError.range(frame, 1, 3, 'frame'),
  };

  static String goldNodeExhaustAsset(int frame) => switch (frame) {
    1 || 2 || 3 || 4 =>
      'assets/images/mining/nodes/node-gold-exhaust-${frame.toString().padLeft(2, '0')}.png',
    _ => throw RangeError.range(frame, 1, 4, 'frame'),
  };

  static const cashIcon = 'assets/images/mining/icons/cash.png';
  static const cargoIcon = 'assets/images/mining/icons/cargo.png';
  static const mergeIcon = 'assets/images/mining/icons/merge.png';
  static const extractionIcon = 'assets/images/mining/icons/extraction.png';
  static const logisticsIcon = 'assets/images/mining/icons/logistics.png';
  static const surveyingIcon = 'assets/images/mining/icons/surveying.png';
  static const mergeBurst = 'assets/images/mining/effects/merge_burst.png';
  static const goldNodeIdleStrip =
      'assets/images/mining/nodes/node-gold-idle-strip.png';
  static const goldNodeHitStrip =
      'assets/images/mining/nodes/node-gold-hit-strip.png';
  static const goldNodeExhaustStrip =
      'assets/images/mining/nodes/node-gold-exhaust-strip.png';
  static const offlineHero = 'assets/images/mining/offline/hero.png';
}
