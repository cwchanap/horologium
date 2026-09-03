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

  static String landingBasinRobotAsset(RigTier tier) =>
      'assets/images/mining/landing_basin/robot_${tier.name}.png';

  static String landingBasinDepositAsset(MiningNodeId nodeId) =>
      'assets/images/mining/landing_basin/deposit_${nodeId.name}.png';

  static const cashIcon = 'assets/images/mining/icons/cash.png';
  static const cargoIcon = 'assets/images/mining/icons/cargo.png';
  static const mergeIcon = 'assets/images/mining/icons/merge.png';
  static const extractionIcon = 'assets/images/mining/icons/extraction.png';
  static const logisticsIcon = 'assets/images/mining/icons/logistics.png';
  static const surveyingIcon = 'assets/images/mining/icons/surveying.png';
  static const mergeBurst = 'assets/images/mining/effects/merge_burst.png';
  static const landingBasinImpact =
      'assets/images/mining/landing_basin/impact.png';
  static const offlineHero = 'assets/images/mining/offline/hero.png';
}
