import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'dart:math' as math;

// Game Screen with Flame GameWidget
class Scene extends StatefulWidget {
  const Scene({super.key});

  @override
  State<Scene> createState() => _SceneState();
}

class _SceneState extends State<Scene> {
  late HorologiumGame game;

  @override
  void initState() {
    super.initState();
    game = HorologiumGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTapDown: (details) {
          final renderBox = context.findRenderObject() as RenderBox;
          final localPosition = renderBox.globalToLocal(details.globalPosition);
          game.onTapDown(Vector2(localPosition.dx, localPosition.dy));
        },
        child: GameWidget<HorologiumGame>(
          game: game,
          overlayBuilderMap: {
            'GameUI': (context, game) => GameUI(game: game),
          },
          initialActiveOverlays: const ['GameUI'],
        ),
      ),
    );
  }
}

// Main Flame Game Class
class HorologiumGame extends FlameGame {
  late PositionComponent spaceship;
  
  double score = 0;
  double energy = 100;
  double energyRegenRate = 5; // Energy per second
  
  @override
  Future<void> onLoad() async {
    // Add starfield background
    add(StarfieldBackground());
    
    // Create spaceship as a composite component
    spaceship = _createSpaceship();
    add(spaceship);
    
    // Add planets to explore
    for (int i = 0; i < 5; i++) {
      add(Planet(
        position: Vector2(
          math.Random().nextDouble() * size.x,
          math.Random().nextDouble() * size.y,
        ),
        planetType: i % 3,
        game: this,
      ));
    }
    
    // Add floating asteroids
    for (int i = 0; i < 10; i++) {
      add(Asteroid(
        position: Vector2(
          math.Random().nextDouble() * size.x,
          math.Random().nextDouble() * size.y,
        ),
        game: this,
      ));
    }
  }
  
  PositionComponent _createSpaceship() {
    final spaceshipGroup = PositionComponent()
      ..position = Vector2(size.x / 2, size.y / 2)
      ..anchor = Anchor.center;
    
    // Create a simple spaceship sprite using RectangleComponent
    final spaceshipBody = RectangleComponent(
      size: Vector2(40, 60),
      paint: Paint()..color = Colors.cyanAccent,
      anchor: Anchor.center,
    );
    spaceshipGroup.add(spaceshipBody);
    
    // Add thruster effects
    final thruster1 = CircleComponent(
      radius: 8,
      position: Vector2(-12, 25),
      paint: Paint()..color = Colors.orange,
      anchor: Anchor.center,
    );
    final thruster2 = CircleComponent(
      radius: 8,
      position: Vector2(12, 25),
      paint: Paint()..color = Colors.orange,
      anchor: Anchor.center,
    );
    spaceshipGroup.add(thruster1);
    spaceshipGroup.add(thruster2);
    
    return spaceshipGroup;
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    
    // Regenerate energy over time
    energy = math.min(100, energy + energyRegenRate * dt);
    
    // Auto-collect nearby resources (idle game mechanic)
    autoCollectResources();
  }
  
  void moveSpaceshipTo(Vector2 target) {
    spaceship.add(
      MoveToEffect(
        target,
        EffectController(duration: 2.0, curve: Curves.easeInOut),
      ),
    );
  }
  
  void autoCollectResources() {
    // Simple idle game mechanic - automatically collect resources
    score += 1 * (1 / 60); // 1 point per second
  }
  
  void addScore(double points) {
    score += points;
  }
  
  void onTapDown(Vector2 position) {
    // Move spaceship to tapped location if we have energy
    if (energy >= 10) {
      moveSpaceshipTo(position);
      energy -= 10;
    }
  }
}

// Starfield Background Component
class StarfieldBackground extends Component {
  final List<Vector2> stars = [];
  final List<double> starSizes = [];
  final List<Color> starColors = [];
  
  @override
  Future<void> onLoad() async {
    final random = math.Random();
    final gameSize = (parent as FlameGame).size;
    
    // Generate random stars
    for (int i = 0; i < 200; i++) {
      stars.add(Vector2(
        random.nextDouble() * gameSize.x,
        random.nextDouble() * gameSize.y,
      ));
      starSizes.add(random.nextDouble() * 3 + 1);
      starColors.add(random.nextBool() ? Colors.white : Colors.cyanAccent);
    }
  }
  
  @override
  void render(Canvas canvas) {
    for (int i = 0; i < stars.length; i++) {
      final paint = Paint()..color = starColors[i].withOpacity(0.8);
      canvas.drawCircle(
        stars[i].toOffset(),
        starSizes[i],
        paint,
      );
    }
  }
}

// Planet Component
class Planet extends CircleComponent {
  final int planetType;
  final HorologiumGame game;
  
  Planet({required Vector2 position, required this.planetType, required this.game})
      : super(
          position: position,
          radius: 30 + planetType * 10,
          anchor: Anchor.center,
        );
  
  @override
  Future<void> onLoad() async {
    super.onLoad();
    final colors = [Colors.brown, Colors.blue, Colors.red];
    paint = Paint()..color = colors[planetType % colors.length];
    
    // Add atmosphere effect
    add(CircleComponent(
      radius: radius + 5,
      paint: Paint()..color = Colors.white.withOpacity(0.2),
      anchor: Anchor.center,
    ));
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    
    // Check collision with spaceship
    final spaceshipPos = game.spaceship.position;
    final distance = position.distanceTo(spaceshipPos);
    
    if (distance < radius + 30) { // 30 is spaceship radius
      // Player discovered a planet
      game.addScore(100);
      // Add visual effect
      add(ScaleEffect.to(
        Vector2.all(1.2),
        EffectController(duration: 0.3, reverseDuration: 0.3),
      ));
    }
  }
}

// Asteroid Component  
class Asteroid extends RectangleComponent {
  final HorologiumGame game;
  
  Asteroid({required Vector2 position, required this.game})
      : super(
          position: position,
          size: Vector2.all(20),
          anchor: Anchor.center,
        );
  
  @override
  Future<void> onLoad() async {
    super.onLoad();
    paint = Paint()..color = Colors.grey;
    
    // Add rotation
    add(RotateEffect.by(
      2 * math.pi,
      EffectController(duration: 10, infinite: true),
    ));
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    
    // Check collision with spaceship
    final spaceshipPos = game.spaceship.position;
    final distance = position.distanceTo(spaceshipPos);
    
    if (distance < 40) { // Collision distance
      // Player mined an asteroid
      game.addScore(50);
      // Remove asteroid after mining
      removeFromParent();
    }
  }
}

// Game UI Overlay
class GameUI extends StatelessWidget {
  final HorologiumGame game;
  
  const GameUI({super.key, required this.game});
  
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Top UI
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.cyanAccent),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                
                // Score and energy display
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: StreamBuilder(
                    stream: Stream.periodic(const Duration(milliseconds: 100)),
                    builder: (context, snapshot) {
                      return Column(
                        children: [
                          Text(
                            'Score: ${game.score.toInt()}',
                            style: const TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Energy: ${game.energy.toInt()}%',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
            
            const Spacer(),
            
            // Bottom instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Tap to move your spaceship and explore!\n• Discover planets for big rewards\n• Mine asteroids for resources\n• Energy regenerates over time',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
