import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flame/game.dart';
import 'game_scene.dart';

class MainMenu extends StatefulWidget {
  const MainMenu({super.key});

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu>
    with TickerProviderStateMixin {
  late AnimationController _starsController;
  late AnimationController _titleController;
  late AnimationController _buttonController;
  late Animation<double> _titleAnimation;
  late Animation<double> _buttonAnimation;

  @override
  void initState() {
    super.initState();

    _starsController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _titleController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _titleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _titleController, curve: Curves.easeOutBack),
    );

    _buttonAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeOutCubic),
    );

    // Start animations
    _titleController.forward().then((_) {
      _buttonController.forward();
    });
  }

  @override
  void dispose() {
    _starsController.dispose();
    _titleController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f0f1e)],
          ),
        ),
        child: Stack(
          children: [
            // Animated Starfield Background
            AnimatedBuilder(
              animation: _starsController,
              builder: (context, child) {
                return CustomPaint(
                  painter: StarfieldPainter(_starsController.value),
                  size: MediaQuery.of(context).size,
                );
              },
            ),

            // Main Content
            Center(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Spacer(flex: 2),

                      // Title Section
                      AnimatedBuilder(
                        animation: _titleAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _titleAnimation.value,
                            child: Opacity(
                              opacity: _titleAnimation.value.clamp(0.0, 1.0),
                              child: Column(
                                children: [
                                  Text(
                                    'HOROLOGIUM',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .displayLarge
                                        ?.copyWith(
                                          fontSize: 36,
                                          letterSpacing: 6.0,
                                        ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'STELLAR EXPLORER',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          fontSize: 14,
                                          color: Colors.cyanAccent.withOpacity(
                                            0.8,
                                          ),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      const Spacer(flex: 3),

                      // Menu Buttons
                      AnimatedBuilder(
                        animation: _buttonAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, 50 * (1 - _buttonAnimation.value)),
                            child: Opacity(
                              opacity: _buttonAnimation.value.clamp(0.0, 1.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _buildMenuButton(
                                    'START EXPEDITION',
                                    Icons.rocket_launch,
                                    () => _startGame(),
                                  ),
                                  const SizedBox(height: 20),
                                  _buildMenuButton(
                                    'STELLAR MAP',
                                    Icons.public,
                                    () => _openStellarMap(),
                                  ),
                                  const SizedBox(height: 20),
                                  _buildMenuButton(
                                    'RESEARCH LAB',
                                    Icons.science,
                                    () => _openResearchLab(),
                                  ),
                                  const SizedBox(height: 20),
                                  _buildMenuButton(
                                    'SETTINGS',
                                    Icons.settings,
                                    () => _openSettings(),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      const Spacer(flex: 2),

                      // Footer
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Text(
                          'v1.0.0 | Explore • Discover • Evolve',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 12,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Floating Particles
            ...List.generate(
              3,
              (index) => FloatingParticle(delay: index * 2.0),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton(String text, IconData icon, VoidCallback onPressed) {
    return Center(
      child: SizedBox(
        width: 280,
        height: 55,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.cyanAccent,
            side: const BorderSide(color: Colors.cyanAccent, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startGame() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GameWidget(game: GameScene()),
      ),
    );
  }

  void _openStellarMap() {
    // TODO: Navigate to stellar map
    print('Opening stellar map...');
  }

  void _openResearchLab() {
    // TODO: Navigate to research lab
    print('Opening research lab...');
  }

  void _openSettings() {
    // TODO: Navigate to settings
    print('Opening settings...');
  }
}

class StarfieldPainter extends CustomPainter {
  final double animationValue;

  StarfieldPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final random = math.Random(42); // Fixed seed for consistent stars

    for (int i = 0; i < 150; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final opacity = (math.sin(animationValue * 2 * math.pi + i) + 1) / 2;
      final starSize = random.nextDouble() * 2 + 0.5;

      paint.color = Colors.white.withOpacity(opacity * 0.8);
      canvas.drawCircle(Offset(x, y), starSize, paint);
    }

    // Add some larger, more prominent stars
    for (int i = 0; i < 20; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final twinkle = (math.sin(animationValue * 3 * math.pi + i * 2) + 1) / 2;

      paint.color = Colors.cyanAccent.withOpacity(twinkle * 0.6);
      canvas.drawCircle(Offset(x, y), 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class FloatingParticle extends StatefulWidget {
  final double delay;

  const FloatingParticle({super.key, required this.delay});

  @override
  State<FloatingParticle> createState() => _FloatingParticleState();
}

class _FloatingParticleState extends State<FloatingParticle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(seconds: 8 + _random.nextInt(4)),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);

    if (!kDebugMode) {
      Future.delayed(Duration(milliseconds: (widget.delay * 1000).round()), () {
        if (mounted) {
          _controller.repeat();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final screenSize = MediaQuery.of(context).size;
        final x = _random.nextDouble() * screenSize.width;
        final y = screenSize.height * _animation.value;

        return Positioned(
          left: x,
          top: y - screenSize.height,
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.cyanAccent.withOpacity(0.6),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.cyanAccent.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
