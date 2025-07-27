import 'package:flutter/material.dart';

import '../../game/main_game.dart';

class GameOverlay extends StatelessWidget {
  final MainGame game;
  final VoidCallback onBackPressed;

  const GameOverlay({
    super.key,
    required this.game,
    required this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: onBackPressed,
              icon: Icon(
                  game.buildingToPlace != null ? Icons.close : Icons.arrow_back,
                  color: Colors.white),
              tooltip: game.buildingToPlace != null 
                  ? 'Cancel (ESC or click outside)'
                  : 'Back',
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withAlpha((255 * 0.5).round()),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}