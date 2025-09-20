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
      child: child,
    );
  }
}