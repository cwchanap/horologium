import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/world/mining_components.dart';

/// Regression guard for the reduced-motion tier-upgrade feedback.
///
/// `MiningSectorComponent.playTierUpgradeReward` applies an [OpacityEffect.by]
/// to each mounted structure when `reducedMotion` is enabled. The structure
/// components must therefore implement [OpacityProvider]; otherwise Flame
/// throws `Unsupported operation: Can only apply this effect to OpacityProvider`
/// when the effect mounts. See
/// https://github.com/cwchanap/horologium/pull/14 (android tests job failure).
void main() {
  for (final structure in <MiningStructureOpacity>[
    OperationLightComponent(),
    AdvancedPlatformComponent(),
    SecondaryMachineryComponent(),
    EliteRingComponent(),
  ]) {
    final label = structure.runtimeType.toString();
    testWidgets('$label accepts OpacityEffect in reduced-motion mode', (
      tester,
    ) async {
      final game = FlameGame();
      game.add(structure);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GameWidget(game: game)),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(structure.isMounted, isTrue);
      expect(structure.opacity, 1);

      structure.add(
        OpacityEffect.by(
          -0.35,
          EffectController(
            duration: 0.12,
            reverseDuration: 0.12,
            alternate: true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(structure.opacity, lessThan(1));
      expect(tester.takeException(), isNull);
    });
  }
}
