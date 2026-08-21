import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:horologium/mining/mining_save_repository.dart';
import 'package:horologium/mining/presentation/mining_screen.dart';

class MainMenu extends StatefulWidget {
  const MainMenu({super.key});

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> with TickerProviderStateMixin {
  late final AnimationController _starsController;
  late final AnimationController _titleController;
  late final AnimationController _buttonController;
  late final Animation<double> _titleAnimation;
  late final Animation<double> _buttonAnimation;
  late final Future<bool> _hasSaveFuture;
  bool _reducedMotion = false;
  bool _animationsStarted = false;

  @override
  void initState() {
    super.initState();
    _hasSaveFuture = MiningSaveRepository().hasSave();

    _starsController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );
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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    if (_animationsStarted && reducedMotion == _reducedMotion) return;

    _reducedMotion = reducedMotion;
    if (reducedMotion) {
      _starsController
        ..stop()
        ..value = 0;
      _titleController
        ..stop()
        ..value = 1;
      _buttonController
        ..stop()
        ..value = 1;
    } else {
      _starsController.repeat();
      if (!_animationsStarted) {
        _titleController.forward().then((_) {
          if (mounted && !_reducedMotion) {
            _buttonController.forward();
          }
        });
      }
    }
    _animationsStarted = true;
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
            AnimatedBuilder(
              animation: _starsController,
              builder: (context, child) {
                return CustomPaint(
                  key: const ValueKey('main-menu-starfield'),
                  painter: StarfieldPainter(_starsController.value),
                  size: MediaQuery.of(context).size,
                );
              },
            ),
            Center(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Spacer(flex: 2),
                      AnimatedBuilder(
                        animation: _titleAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            key: const ValueKey('main-menu-title-transform'),
                            scale: _titleAnimation.value,
                            child: Opacity(
                              key: const ValueKey('main-menu-title-opacity'),
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
                                    'MINING FRONTIER',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          fontSize: 14,
                                          color: Colors.cyanAccent.withAlpha(
                                            (255 * 0.8).round(),
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
                      AnimatedBuilder(
                        animation: _buttonAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            key: const ValueKey('main-menu-button-transform'),
                            offset: Offset(
                              0,
                              50 * (1 - _buttonAnimation.value),
                            ),
                            child: Opacity(
                              key: const ValueKey('main-menu-button-opacity'),
                              opacity: _buttonAnimation.value.clamp(0.0, 1.0),
                              child: FutureBuilder<bool>(
                                future: _hasSaveFuture,
                                builder: (context, snapshot) {
                                  final label = snapshot.data == true
                                      ? 'CONTINUE MINING'
                                      : 'START MINING';
                                  return _buildMenuButton(
                                    label,
                                    Icons.precision_manufacturing,
                                    _openMiningScreen,
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                      const Spacer(flex: 2),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Text(
                          'v1.0.0 | Mine • Upgrade • Prosper',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withAlpha((255 * 0.3).round()),
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
            if (!_reducedMotion)
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

  void _openMiningScreen() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const MiningScreen()));
  }
}

class StarfieldPainter extends CustomPainter {
  final double animationValue;

  StarfieldPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final random = math.Random(42);

    for (int i = 0; i < 150; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final opacity = (math.sin(animationValue * 2 * math.pi + i) + 1) / 2;
      final starSize = random.nextDouble() * 2 + 0.5;

      paint.color = Colors.white.withAlpha((255 * (opacity * 0.8)).round());
      canvas.drawCircle(Offset(x, y), starSize, paint);
    }

    for (int i = 0; i < 20; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final twinkle = (math.sin(animationValue * 3 * math.pi + i * 2) + 1) / 2;

      paint.color = Colors.cyanAccent.withAlpha(
        (255 * (twinkle * 0.6)).round(),
      );
      canvas.drawCircle(Offset(x, y), 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant StarfieldPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
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
              color: Colors.cyanAccent.withAlpha((255 * 0.6).round()),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.cyanAccent.withAlpha((255 * 0.3).round()),
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
