import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart' as flame_events;

import '../mining_content.dart';
import '../mining_state.dart';

/// Mixin that lets a mining structure component participate in [OpacityEffect]
/// animations (e.g. the reduced-motion tier-upgrade dim flash) by exposing the
/// [OpacityProvider] interface and scaling paint alphas by [opacity].
mixin MiningStructureOpacity on Component implements OpacityProvider {
  @override
  double opacity = 1;

  /// Returns [color] with its alpha multiplied by the current [opacity], so
  /// opacity effects visibly dim the structure without changing its hue.
  Color dimmed(Color color) =>
      color.withAlpha((color.a * 255 * opacity).round().clamp(0, 255));
}

class OperationLightComponent extends PositionComponent
    with MiningStructureOpacity {
  OperationLightComponent()
    : super(
        size: Vector2.all(16),
        position: Vector2(80, 20),
        anchor: Anchor.center,
      );

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    canvas.drawCircle(
      center,
      size.x * 0.48,
      Paint()..color = dimmed(const Color(0x6653D4E8)),
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: center,
        width: size.x * 0.5,
        height: size.y * 0.7,
      ),
      Paint()..color = dimmed(const Color(0xFFFFD54A)),
    );
  }
}

class AdvancedPlatformComponent extends PositionComponent
    with MiningStructureOpacity {
  AdvancedPlatformComponent()
    : super(
        size: Vector2(124, 18),
        position: Vector2(80, 148),
        anchor: Anchor.center,
      );

  @override
  void render(Canvas canvas) {
    final platform = Paint()..color = dimmed(const Color(0xFF53D4E8));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & Size(size.x, size.y * 0.58),
        const Radius.circular(3),
      ),
      platform,
    );
    final support = Paint()..color = dimmed(const Color(0xFF2B7E94));
    canvas.drawRect(
      Rect.fromLTWH(size.x * 0.12, size.y * 0.52, size.x * 0.1, size.y * 0.48),
      support,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.x * 0.78, size.y * 0.52, size.x * 0.1, size.y * 0.48),
      support,
    );
  }
}

class SecondaryMachineryComponent extends PositionComponent
    with MiningStructureOpacity {
  SecondaryMachineryComponent()
    : super(
        size: Vector2(30, 44),
        position: Vector2(15, 102),
        anchor: Anchor.center,
      );

  @override
  void render(Canvas canvas) {
    final body = Paint()..color = dimmed(const Color(0xFF9B7EDE));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & Size(size.x * 0.72, size.y * 0.72),
        const Radius.circular(3),
      ),
      body,
    );
    final pipe = Paint()
      ..color = dimmed(const Color(0xFFE0D4FF))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(size.x * 0.72, size.y * 0.28),
      Offset(size.x, size.y * 0.28),
      pipe,
    );
    canvas.drawLine(
      Offset(size.x * 0.72, size.y * 0.55),
      Offset(size.x, size.y * 0.55),
      pipe,
    );
  }
}

class EliteRingComponent extends PositionComponent with MiningStructureOpacity {
  EliteRingComponent()
    : super(
        size: Vector2.all(152),
        position: Vector2(80, 80),
        anchor: Anchor.center,
      );

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final ring = Paint()
      ..color = dimmed(const Color(0xFFFF6B8A))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, size.x * 0.45, ring);
    canvas.drawCircle(center, size.x * 0.39, ring..strokeWidth = 2);
  }
}

enum MiningRewardVisualKind { reveal, construction, upgrade, sale }

class MiningRewardVisualComponent extends PositionComponent
    implements OpacityProvider {
  MiningRewardVisualComponent({
    required MiningRewardVisualKind kind,
    required Vector2 size,
    required Vector2 position,
    Anchor anchor = Anchor.center,
  }) : _kind = kind,
       super(size: size, position: position, anchor: anchor);

  final MiningRewardVisualKind _kind;

  @override
  double opacity = 1;

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final alpha = (opacity * 255).round().clamp(0, 255);
    final accent = Paint()
      ..color = _accentColor.withAlpha(alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    switch (_kind) {
      case MiningRewardVisualKind.reveal:
        canvas.drawCircle(center, size.x * 0.38, accent);
        canvas.drawLine(
          Offset(size.x * 0.12, size.y * 0.82),
          Offset(size.x * 0.86, size.y * 0.18),
          accent,
        );
        final fog = Paint()
          ..color = const Color(0xFF101722).withAlpha((alpha * 0.65).round());
        canvas.drawCircle(center, size.x * 0.28, fog);
      case MiningRewardVisualKind.construction:
        final glow = Paint()
          ..color = const Color(0xFF53D4E8).withAlpha((alpha * 0.25).round());
        canvas.drawCircle(center, size.x * 0.42, glow);
        canvas.drawCircle(
          center,
          size.x * 0.2,
          Paint.from(accent)..style = PaintingStyle.fill,
        );
        for (final offset in const [
          Offset(0.18, 0.22),
          Offset(0.78, 0.3),
          Offset(0.3, 0.78),
          Offset(0.8, 0.76),
        ]) {
          canvas.drawCircle(
            Offset(size.x * offset.dx, size.y * offset.dy),
            size.x * 0.045,
            accent,
          );
        }
      case MiningRewardVisualKind.upgrade:
        canvas.drawCircle(center, size.x * 0.28, accent);
        canvas.drawCircle(center, size.x * 0.42, accent..strokeWidth = 2);
      case MiningRewardVisualKind.sale:
        final fill = Paint()
          ..color = const Color(0xFFFFD54A).withAlpha(alpha)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, size.x * 0.18, fill);
        canvas.drawLine(
          Offset(size.x * 0.18, center.dy),
          Offset(size.x * 0.82, center.dy),
          accent,
        );
        canvas.drawLine(
          Offset(size.x * 0.62, size.y * 0.3),
          Offset(size.x * 0.82, center.dy),
          accent,
        );
        canvas.drawLine(
          Offset(size.x * 0.62, size.y * 0.7),
          Offset(size.x * 0.82, center.dy),
          accent,
        );
    }
  }

  Color get _accentColor {
    switch (_kind) {
      case MiningRewardVisualKind.sale:
        return const Color(0xFFFFD54A);
      case MiningRewardVisualKind.reveal:
      case MiningRewardVisualKind.construction:
      case MiningRewardVisualKind.upgrade:
        return const Color(0xFF53D4E8);
    }
  }
}

class MiningSaleRewardComponent extends MiningRewardVisualComponent {
  MiningSaleRewardComponent({required super.position})
    : super(kind: MiningRewardVisualKind.sale, size: Vector2.all(34));

  void animateTo(Vector2 target, {required bool reducedMotion}) {
    final duration = reducedMotion ? 0.2 : 0.45;
    add(
      OpacityEffect.fadeOut(
        EffectController(duration: duration),
        onComplete: removeFromParent,
      ),
    );
    if (!reducedMotion) {
      add(MoveEffect.to(target, EffectController(duration: duration)));
    }
  }
}

class MiningSectorComponent extends PositionComponent
    with flame_events.TapCallbacks {
  MiningSectorComponent({required this.definition})
    : super(anchor: Anchor.center, size: Vector2.all(_sectorSize));

  static const double _sectorSize = 160;
  static const double _mineSize = 112;

  final MiningSectorDefinition definition;

  void Function(MiningSectorId id)? onSelected;

  bool _revealed = false;
  MineState? _mine;
  int? _structuralTier;
  bool _spriteReady = false;
  late final SpriteComponent _mineSprite;

  bool get revealed => _revealed;
  MineState? get mine => _mine;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final image = await findGame()!.images.load(definition.mineAsset);
    _mineSprite = SpriteComponent.fromImage(
      image,
      anchor: Anchor.center,
      position: size / 2,
      size: Vector2.all(_mineSize),
    );
    _spriteReady = true;
    _syncPresentation();
  }

  void updateState(SectorProgress progress) {
    _revealed = progress.revealed;
    _mine = progress.mine;
    _syncPresentation();
  }

  void playRevealReward({required bool reducedMotion}) {
    _showReward(MiningRewardVisualKind.reveal, reducedMotion: reducedMotion);
  }

  void playConstructionReward({required bool reducedMotion}) {
    _showReward(
      MiningRewardVisualKind.construction,
      reducedMotion: reducedMotion,
    );
  }

  void playTierUpgradeReward({required bool reducedMotion}) {
    final structures = children
        .where(
          (child) =>
              child is OperationLightComponent ||
              child is AdvancedPlatformComponent ||
              child is SecondaryMachineryComponent ||
              child is EliteRingComponent,
        )
        .toList();
    if (structures.isEmpty) return;

    final visual = MiningRewardVisualComponent(
      kind: MiningRewardVisualKind.upgrade,
      size: Vector2.all(_sectorSize * 0.9),
      position: size / 2,
    );
    add(visual);
    visual.add(
      OpacityEffect.fadeOut(
        EffectController(duration: reducedMotion ? 0.2 : 0.45),
        onComplete: visual.removeFromParent,
      ),
    );

    for (final structure in structures) {
      if (reducedMotion) {
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
      } else {
        structure.add(
          ScaleEffect.by(
            Vector2.all(1.18),
            EffectController(
              duration: 0.12,
              reverseDuration: 0.12,
              alternate: true,
            ),
          ),
        );
      }
    }
  }

  @override
  void onTapUp(flame_events.TapUpEvent event) {
    onSelected?.call(definition.id);
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final radius = size.x * 0.34;
    final padPaint = Paint()
      ..color = _revealed ? const Color(0xFF294A5A) : const Color(0xFF26313D);
    canvas.drawCircle(center, radius, padPaint);

    final ringPaint = Paint()
      ..color = _revealed ? const Color(0xFF53D4E8) : const Color(0xFF6E7B8A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius, ringPaint);

    if (!_revealed) {
      final fogPaint = Paint()..color = const Color(0xAA101722);
      canvas.drawCircle(center, radius * 0.76, fogPaint);
    } else if (_mine == null) {
      final emptyPaint = Paint()
        ..color = const Color(0xFF8CAAB4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRect(
        Rect.fromCenter(center: center, width: radius, height: radius),
        emptyPaint,
      );
    }
  }

  void _syncPresentation() {
    final tier = _tierFor(_mine);
    if (_structuralTier != tier) {
      _rebuildStructure(tier);
    }

    if (!_spriteReady) return;

    if (_revealed && _mine != null) {
      if (!children.contains(_mineSprite)) {
        add(_mineSprite);
      }
    } else if (children.contains(_mineSprite)) {
      remove(_mineSprite);
    }
  }

  void _showReward(MiningRewardVisualKind kind, {required bool reducedMotion}) {
    final visual = MiningRewardVisualComponent(
      kind: kind,
      size: Vector2.all(_sectorSize * 0.9),
      position: size / 2,
    );
    add(visual);
    final duration = reducedMotion ? 0.22 : 0.55;
    visual.add(
      OpacityEffect.fadeOut(
        EffectController(duration: duration),
        onComplete: visual.removeFromParent,
      ),
    );
    if (!reducedMotion && kind == MiningRewardVisualKind.construction) {
      visual.add(
        ScaleEffect.by(Vector2.all(1.2), EffectController(duration: duration)),
      );
    }
  }

  void _rebuildStructure(int tier) {
    removeWhere(
      (child) =>
          child is OperationLightComponent ||
          child is AdvancedPlatformComponent ||
          child is SecondaryMachineryComponent ||
          child is EliteRingComponent,
    );

    // Tier ladder: L1 → light; L3 → +platform +machinery; L5 → +elite ring.
    // L2 and L4 keep the set from the preceding bracket.
    switch (tier) {
      case 1:
        add(OperationLightComponent());
      case 3:
        add(OperationLightComponent());
        add(AdvancedPlatformComponent());
        add(SecondaryMachineryComponent());
      case 5:
        add(OperationLightComponent());
        add(AdvancedPlatformComponent());
        add(SecondaryMachineryComponent());
        add(EliteRingComponent());
    }
    _structuralTier = tier;
  }

  int _tierFor(MineState? mine) {
    if (mine == null) return 0;
    if (mine.level >= 5) return 5;
    if (mine.level >= 3) return 3;
    return 1;
  }
}
