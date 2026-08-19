import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart' as flame_events;

import '../mining_content.dart';
import '../mining_state.dart';

class OperationLightComponent extends PositionComponent {}

class AdvancedPlatformComponent extends PositionComponent {}

class SecondaryMachineryComponent extends PositionComponent {}

class EliteRingComponent extends PositionComponent {}

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

  void _rebuildStructure(int tier) {
    removeWhere(
      (child) =>
          child is OperationLightComponent ||
          child is AdvancedPlatformComponent ||
          child is SecondaryMachineryComponent ||
          child is EliteRingComponent,
    );

    switch (tier) {
      case 1:
        add(OperationLightComponent());
      case 3:
        add(OperationLightComponent());
        add(AdvancedPlatformComponent());
        add(SecondaryMachineryComponent());
      case 5:
        add(OperationLightComponent());
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
