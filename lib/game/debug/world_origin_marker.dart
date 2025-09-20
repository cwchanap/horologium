import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Draws a crosshair and rings at world origin (0,0), regardless of camera.
class WorldOriginMarker extends PositionComponent {
  WorldOriginMarker() {
    anchor = Anchor.center;
    position = Vector2.zero();
    size = Vector2.all(1); // size not used
    priority = 1000; // draw on top
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final axisPaint = Paint()
      ..color = Colors.deepOrange
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final ringPaint = Paint()
      ..color = Colors.cyan
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Crosshair axes
    canvas.drawLine(const Offset(-2000, 0), const Offset(2000, 0), axisPaint);
    canvas.drawLine(const Offset(0, -2000), const Offset(0, 2000), axisPaint);

    // Concentric rings
    for (final r in [25.0, 50.0, 100.0, 200.0, 400.0]) {
      canvas.drawCircle(Offset.zero, r, ringPaint);
    }

    // Center dot
    final centerPaint = Paint()..color = Colors.orange;
    canvas.drawRect(const Rect.fromLTWH(-6, -6, 12, 12), centerPaint);
  }
}
