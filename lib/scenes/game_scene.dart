import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class GameScene extends FlameGame {
  final int gridSize;
  double _zoom = 1.0;

  GameScene({this.gridSize = 10});

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final camera = CameraComponent.withFixedResolution(width: 800, height: 600);
    camera.viewfinder.anchor = Anchor.center;
    world.add(camera);
    world.add(Grid(gridSize: gridSize)..size = size);
  }

  void onScaleUpdate(ScaleUpdateDetails details) {
    final newZoom = _zoom * details.scale;
    _zoom = newZoom.clamp(1.0, 4.0);
    camera.viewfinder.zoom = _zoom;
  }
}

class Grid extends PositionComponent {
  final int gridSize;

  Grid({this.gridSize = 10});

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final paint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke;

    final cellSize = size.x / gridSize;

    for (var i = 0; i <= gridSize; i++) {
      final double x = i * cellSize;
      canvas.drawLine(Offset(x, 0), Offset(x, size.y), paint);
    }

    for (var i = 0; i <= gridSize; i++) {
      final double y = i * cellSize;
      canvas.drawLine(Offset(0, y), Offset(size.x, y), paint);
    }
  }
}
