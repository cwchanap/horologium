import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../game/main_game.dart';

class GameControls extends StatelessWidget {
  final MainGame game;
  final Widget child;
  final VoidCallback? onEscapePressed;

  const GameControls({
    super.key,
    required this.game,
    required this.child,
    this.onEscapePressed,
  });

  void _handlePointerEvent(Offset globalPosition, BuildContext context) {
    if (game.buildingToPlace != null) {
      try {
        final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          final localPosition = renderBox.globalToLocal(globalPosition);
          final worldPosition = game.camera.globalToLocal(Vector2(localPosition.dx, localPosition.dy));
          game.showPlacementPreview(game.buildingToPlace!, worldPosition);
        }
      } catch (e) {
        // Silently handle errors
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          onEscapePressed?.call();
        }
      },
      child: MouseRegion(
        onHover: (event) {
          _handlePointerEvent(event.position, context);
        },
        child: child,
      ),
    );
  }
}