import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/presentation/mining_theme.dart';
import 'package:horologium/mining/presentation/mining_visuals.dart';

class LandingBasinMiningNodeVisual extends StatefulWidget {
  const LandingBasinMiningNodeVisual({
    super.key,
    required this.nodeId,
    required this.rig,
    required this.nodeSize,
    required this.rigSize,
    required this.impactSequence,
    required this.reducedMotion,
  });

  final MiningNodeId nodeId;
  final RigTier? rig;
  final double nodeSize;
  final double rigSize;
  final int impactSequence;
  final bool reducedMotion;

  @override
  State<LandingBasinMiningNodeVisual> createState() =>
      _LandingBasinMiningNodeVisualState();
}

class _LandingBasinMiningNodeVisualState
    extends State<LandingBasinMiningNodeVisual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
    animationBehavior: AnimationBehavior.preserve,
    value: 1,
  );

  @override
  void didUpdateWidget(LandingBasinMiningNodeVisual oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rig == null) {
      _controller.stop();
      _controller.value = 1;
      return;
    }
    if (widget.impactSequence != oldWidget.impactSequence) {
      _controller.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      final t = _controller.value.clamp(0.0, 1.0).toDouble();
      final rig = widget.rig;
      final impactActive = rig != null && t >= .24 && t < 1;
      final robotOffset = rig == null || widget.reducedMotion
          ? Offset.zero
          : _robotOffset(t, widget.rigSize);
      final robotAngle = rig == null || widget.reducedMotion
          ? 0.0
          : _robotAngle(t);
      final robotScale = rig == null || widget.reducedMotion
          ? 1.0
          : _robotScale(t);
      final depositScale = widget.reducedMotion ? 1.0 : _depositScale(t);
      final depositOffset = rig == null || widget.reducedMotion
          ? Offset.zero
          : _depositOffset(t, widget.nodeSize);
      final depositAngle = rig == null || widget.reducedMotion
          ? 0.0
          : _depositAngle(t);

      return Stack(
        clipBehavior: Clip.none,
        children: [
          if (impactActive) ..._effectWidgets(t),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: widget.nodeSize,
                height: widget.nodeSize,
                child: Transform.translate(
                  key: Key(
                    'landing-basin-deposit-response-${widget.nodeId.name}',
                  ),
                  offset: depositOffset,
                  child: Transform.rotate(
                    key: Key(
                      'landing-basin-deposit-rotation-${widget.nodeId.name}',
                    ),
                    angle: depositAngle,
                    child: Transform.scale(
                      key: Key('landing-basin-deposit-${widget.nodeId.name}'),
                      scale: depositScale,
                      child: Image.asset(
                        MiningVisuals.landingBasinDepositAsset(widget.nodeId),
                        width: widget.nodeSize,
                        height: widget.nodeSize,
                        opacity: rig == null
                            ? const AlwaysStoppedAnimation(.62)
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
              if (rig != null) ...[
                const SizedBox(width: 2),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: widget.rigSize,
                      height: widget.rigSize,
                      child: Transform.translate(
                        key: Key('landing-basin-robot-${widget.nodeId.name}'),
                        offset: robotOffset,
                        child: Transform.rotate(
                          key: Key(
                            'landing-basin-robot-response-${widget.nodeId.name}',
                          ),
                          angle: robotAngle,
                          child: Transform.scale(
                            key: Key(
                              'landing-basin-robot-scale-${widget.nodeId.name}',
                            ),
                            scale: robotScale,
                            child: Image.asset(
                              MiningVisuals.landingBasinRobotAsset(rig),
                              width: widget.rigSize,
                              height: widget.rigSize,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: MiningTheme.accent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        rig.name.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF04121A),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      );
    },
  );

  List<Widget> _effectWidgets(double t) {
    final size = widget.nodeSize * .92;
    final left = widget.nodeSize * .48;
    final top = widget.nodeSize * .18;
    final reducedMotion = widget.reducedMotion;
    return [
      Positioned(
        left: left,
        top: top,
        width: size,
        height: size,
        child: _paintedEffect(
          key: 'landing-basin-gold-glow-${widget.nodeId.name}',
          opacity: _goldGlowOpacity(t),
          painter: const _LandingBasinEffectPainter(
            kind: _LandingBasinEffectKind.goldGlow,
          ),
          reducedMotion: reducedMotion,
          scale: _goldGlowScale(t),
        ),
      ),
      Positioned(
        left: left - widget.nodeSize * .08,
        top: top + widget.nodeSize * .10,
        width: size,
        height: size,
        child: _paintedEffect(
          key: 'landing-basin-dust-${widget.nodeId.name}',
          opacity: _dustOpacity(t),
          painter: const _LandingBasinEffectPainter(
            kind: _LandingBasinEffectKind.dust,
          ),
          reducedMotion: reducedMotion,
          scale: _dustScale(t),
          rotation: -.10,
        ),
      ),
      Positioned(
        left: left,
        top: top,
        width: size,
        height: size,
        child: _paintedEffect(
          key: 'landing-basin-rock-chips-${widget.nodeId.name}',
          opacity: _rockChipOpacity(t),
          painter: const _LandingBasinEffectPainter(
            kind: _LandingBasinEffectKind.rockChips,
          ),
          reducedMotion: reducedMotion,
          scale: _rockChipScale(t),
          rotation: .20,
        ),
      ),
      Positioned(
        left: left - widget.nodeSize * .02,
        top: top - widget.nodeSize * .02,
        width: size,
        height: size,
        child: Opacity(
          key: Key('landing-basin-impact-${widget.nodeId.name}'),
          opacity: _impactOpacity(t),
          child: Transform.scale(
            key: Key('landing-basin-impact-transform-${widget.nodeId.name}'),
            scale: reducedMotion ? 1 : _impactScale(t),
            child: Image.asset(MiningVisuals.landingBasinImpact),
          ),
        ),
      ),
      Positioned(
        left: left - widget.nodeSize * .10,
        top: top - widget.nodeSize * .10,
        width: size * 1.2,
        height: size * 1.2,
        child: _paintedEffect(
          key: 'landing-basin-sparks-${widget.nodeId.name}',
          opacity: _sparkOpacity(t),
          painter: const _LandingBasinEffectPainter(
            kind: _LandingBasinEffectKind.sparks,
          ),
          reducedMotion: reducedMotion,
          scale: _sparkScale(t),
          rotation: _sparkRotation(t),
        ),
      ),
    ];
  }

  Widget _paintedEffect({
    required String key,
    required double opacity,
    required CustomPainter painter,
    required bool reducedMotion,
    double scale = 1,
    double rotation = 0,
  }) {
    Widget child = CustomPaint(painter: painter, size: Size.infinite);
    child = Transform.rotate(
      key: Key('$key-transform'),
      angle: reducedMotion ? 0 : rotation,
      child: Transform.scale(
        key: Key('$key-scale'),
        scale: reducedMotion ? 1 : scale,
        child: child,
      ),
    );
    return Opacity(key: Key(key), opacity: opacity, child: child);
  }

  Offset _robotOffset(double t, double rigSize) {
    final dx = _robotDx(t, rigSize);
    final dy = _robotDy(t, rigSize);
    return Offset(dx, dy);
  }

  double _robotDx(double t, double rigSize) {
    if (t <= .24) return _lerp(0, .30 * rigSize, _easeOut(t / .24));
    if (t <= .46) {
      return _lerp(.30 * rigSize, -.18 * rigSize, _easeOut((t - .24) / .22));
    }
    if (t <= .62) {
      return _lerp(-.18 * rigSize, .10 * rigSize, _easeOut((t - .46) / .16));
    }
    if (t <= .78) return _lerp(.10 * rigSize, 0, _easeOut((t - .62) / .16));
    return 0;
  }

  double _robotDy(double t, double rigSize) {
    if (t <= .24) return _lerp(0, -.06 * rigSize, t / .24);
    if (t <= .46) return _lerp(-.06 * rigSize, .08 * rigSize, (t - .24) / .22);
    if (t <= .62) return _lerp(.08 * rigSize, -.03 * rigSize, (t - .46) / .16);
    if (t <= .78) return _lerp(-.03 * rigSize, 0, (t - .62) / .16);
    return 0;
  }

  double _robotAngle(double t) {
    if (t <= .24) return _lerp(0, -.06, t / .24);
    if (t <= .46) return _lerp(-.06, .10, (t - .24) / .22);
    if (t <= .62) return _lerp(.10, -.04, (t - .46) / .16);
    if (t <= .78) return _lerp(-.04, 0, (t - .62) / .16);
    return 0;
  }

  double _robotScale(double t) {
    if (t <= .24) return _lerp(1, .96, t / .24);
    if (t <= .46) return _lerp(.96, 1.04, (t - .24) / .22);
    if (t <= .62) return _lerp(1.04, .98, (t - .46) / .16);
    if (t <= .78) return _lerp(.98, 1, (t - .62) / .16);
    return 1;
  }

  double _depositScale(double t) {
    if (t <= .24) return _lerp(1, .92, _easeIn(t / .24));
    if (t <= .46) return _lerp(.92, 1.08, _easeOut((t - .24) / .22));
    if (t <= .62) return _lerp(1.08, 1.03, _easeOut((t - .46) / .16));
    if (t <= .78) return _lerp(1.03, 1, _easeOut((t - .62) / .16));
    return 1;
  }

  Offset _depositOffset(double t, double nodeSize) {
    if (t <= .24) return Offset(0, _lerp(0, nodeSize * .025, t / .24));
    if (t <= .46) {
      return Offset(
        _lerp(0, -nodeSize * .045, (t - .24) / .22),
        _lerp(nodeSize * .025, -nodeSize * .035, (t - .24) / .22),
      );
    }
    if (t <= .62) {
      return Offset(
        _lerp(-nodeSize * .045, nodeSize * .035, (t - .46) / .16),
        _lerp(-nodeSize * .035, nodeSize * .015, (t - .46) / .16),
      );
    }
    if (t <= .78) {
      return Offset(
        _lerp(nodeSize * .035, 0, (t - .62) / .16),
        _lerp(nodeSize * .015, 0, (t - .62) / .16),
      );
    }
    return Offset.zero;
  }

  double _depositAngle(double t) {
    if (t <= .24) return _lerp(0, -.04, t / .24);
    if (t <= .46) return _lerp(-.04, .08, (t - .24) / .22);
    if (t <= .62) return _lerp(.08, -.03, (t - .46) / .16);
    if (t <= .78) return _lerp(-.03, 0, (t - .62) / .16);
    return 0;
  }

  double _impactOpacity(double t) {
    if (t <= .30) return _lerp(0, 1, (t - .24) / .06);
    if (t <= .52) return 1;
    return _lerp(1, 0, (t - .52) / .48);
  }

  double _impactScale(double t) {
    if (t <= .32) return _lerp(.45, 1.20, (t - .24) / .08);
    if (t <= .52) return _lerp(1.20, 1.02, (t - .32) / .20);
    return _lerp(1.02, 1, (t - .52) / .48);
  }

  double _sparkOpacity(double t) {
    if (t <= .30) return _lerp(0, 1, (t - .24) / .06);
    if (t <= .62) return 1;
    return _lerp(1, 0, (t - .62) / .30);
  }

  double _sparkScale(double t) {
    if (t <= .40) return _lerp(.30, 1.20, (t - .24) / .16);
    return _lerp(1.20, 1.65, (t - .40) / .60);
  }

  double _sparkRotation(double t) =>
      _lerp(-.35, .55, ((t - .24) / .76).clamp(0.0, 1.0).toDouble());

  double _rockChipOpacity(double t) {
    if (t <= .32) return 0;
    if (t <= .42) return _lerp(0, 1, (t - .32) / .10);
    return _lerp(1, 0, (t - .42) / .46);
  }

  double _rockChipScale(double t) {
    if (t <= .42) return _lerp(.35, 1, (t - .32) / .10);
    return _lerp(1, 1.35, (t - .42) / .46);
  }

  double _dustOpacity(double t) {
    if (t <= .36) return 0;
    if (t <= .54) return _lerp(0, .78, (t - .36) / .18);
    return _lerp(.78, 0, (t - .54) / .46);
  }

  double _dustScale(double t) {
    if (t <= .36) return .50;
    return _lerp(.50, 1.55, (t - .36) / .64);
  }

  double _goldGlowOpacity(double t) {
    if (t <= .32) return _lerp(0, .70, (t - .24) / .08);
    return _lerp(.70, 0, (t - .32) / .68);
  }

  double _goldGlowScale(double t) {
    if (t <= .42) return _lerp(.45, 1.15, (t - .24) / .18);
    return _lerp(1.15, 1.65, (t - .42) / .58);
  }

  double _easeIn(double amount) => amount * amount;

  double _easeOut(double amount) {
    final inverse = 1 - amount;
    return 1 - inverse * inverse;
  }

  double _lerp(double start, double end, double amount) =>
      start + (end - start) * amount.clamp(0.0, 1.0);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

enum _LandingBasinEffectKind { goldGlow, dust, rockChips, sparks }

class _LandingBasinEffectPainter extends CustomPainter {
  const _LandingBasinEffectPainter({required this.kind});

  final _LandingBasinEffectKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    switch (kind) {
      case _LandingBasinEffectKind.goldGlow:
        final glow = Paint()
          ..shader = RadialGradient(
            colors: [
              const Color.fromRGBO(255, 217, 74, .62),
              const Color.fromRGBO(255, 166, 32, .24),
              const Color.fromRGBO(255, 166, 32, 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius));
        canvas.drawCircle(center, radius * .82, glow);
      case _LandingBasinEffectKind.dust:
        final dust = Paint()..color = const Color.fromRGBO(166, 125, 83, .68);
        for (final particle in const [
          (dx: -.33, dy: .22, scale: .15),
          (dx: -.12, dy: .36, scale: .12),
          (dx: .18, dy: .31, scale: .17),
          (dx: .37, dy: .12, scale: .11),
          (dx: .28, dy: -.22, scale: .10),
          (dx: -.30, dy: -.18, scale: .13),
        ]) {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(
                center.dx + radius * particle.dx,
                center.dy + radius * particle.dy,
              ),
              width: radius * particle.scale * 2.1,
              height: radius * particle.scale * 1.45,
            ),
            dust,
          );
        }
      case _LandingBasinEffectKind.rockChips:
        final chip = Paint()
          ..color = const Color(0xFF7A5B43)
          ..style = PaintingStyle.fill;
        final edge = Paint()
          ..color = const Color(0xFFD79B45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
        for (final shard in const [
          (dx: -.42, dy: -.16, scale: .13, angle: -.3),
          (dx: -.12, dy: -.43, scale: .10, angle: .8),
          (dx: .27, dy: -.30, scale: .15, angle: -.7),
          (dx: .43, dy: .06, scale: .11, angle: .5),
          (dx: .18, dy: .40, scale: .14, angle: .2),
          (dx: -.30, dy: .31, scale: .09, angle: -.8),
        ]) {
          final shardCenter = Offset(
            center.dx + radius * shard.dx,
            center.dy + radius * shard.dy,
          );
          final shardRadius = radius * shard.scale;
          final path = Path();
          for (var index = 0; index < 5; index++) {
            final angle = shard.angle + index * math.pi * 2 / 5;
            final point = Offset(
              shardCenter.dx + math.cos(angle) * shardRadius,
              shardCenter.dy + math.sin(angle) * shardRadius,
            );
            if (index == 0) {
              path.moveTo(point.dx, point.dy);
            } else {
              path.lineTo(point.dx, point.dy);
            }
          }
          path.close();
          canvas.drawPath(path, chip);
          canvas.drawPath(path, edge);
        }
      case _LandingBasinEffectKind.sparks:
        final spark = Paint()
          ..color = const Color(0xFFFFD65A)
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2.4;
        final hot = Paint()..color = const Color(0xFFFFF4B0);
        for (final ray in const [
          (angle: -.10, length: .88, width: .18),
          (angle: .36, length: .66, width: .13),
          (angle: .82, length: .82, width: .16),
          (angle: 1.40, length: .62, width: .12),
          (angle: 2.10, length: .78, width: .14),
          (angle: 2.78, length: .63, width: .12),
          (angle: 3.36, length: .76, width: .14),
          (angle: 4.14, length: .58, width: .11),
          (angle: 4.82, length: .84, width: .15),
          (angle: 5.42, length: .65, width: .12),
        ]) {
          final direction = Offset(math.cos(ray.angle), math.sin(ray.angle));
          canvas.drawLine(
            center + direction * radius * .18,
            center + direction * radius * ray.length,
            spark,
          );
          canvas.drawCircle(
            center + direction * radius * (ray.length + ray.width),
            radius * .035,
            hot,
          );
        }
        canvas.drawCircle(center, radius * .13, hot);
    }
  }

  @override
  bool shouldRepaint(_LandingBasinEffectPainter oldDelegate) =>
      oldDelegate.kind != kind;
}
