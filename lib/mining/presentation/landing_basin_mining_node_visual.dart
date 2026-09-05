import 'dart:async';

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
    required this.progress,
    required this.impactSequence,
    required this.reducedMotion,
  });

  final MiningNodeId nodeId;
  final RigTier? rig;
  final double nodeSize;
  final double rigSize;
  final double progress;
  final int impactSequence;
  final bool reducedMotion;

  @override
  State<LandingBasinMiningNodeVisual> createState() =>
      _LandingBasinMiningNodeVisualState();
}

class _LandingBasinMiningNodeVisualState
    extends State<LandingBasinMiningNodeVisual>
    with TickerProviderStateMixin {
  late final AnimationController _impactController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
    animationBehavior: AnimationBehavior.preserve,
    value: 1,
  );

  late final AnimationController _idleController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
    animationBehavior: AnimationBehavior.preserve,
  );

  int? _exhaustImpactSequence;
  bool _framesPrecached = false;

  @override
  void initState() {
    super.initState();
    _syncIdleController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_framesPrecached) {
      _framesPrecached = true;
      _precacheFrames();
    }
  }

  void _precacheFrames() {
    final paths = <String>[
      for (var stage = 1; stage <= 4; stage++)
        MiningVisuals.goldNodeStageAsset(stage),
      for (var frame = 1; frame <= 4; frame++)
        MiningVisuals.goldNodeIdleAsset(frame),
      for (var frame = 1; frame <= 3; frame++)
        MiningVisuals.goldNodeHitAsset(frame),
      for (var frame = 1; frame <= 4; frame++)
        MiningVisuals.goldNodeExhaustAsset(frame),
    ];
    for (final path in paths) {
      unawaited(precacheImage(AssetImage(path), context));
    }
  }

  @override
  void didUpdateWidget(LandingBasinMiningNodeVisual oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rig == null) {
      _impactController.stop();
      _impactController.value = 1;
      _exhaustImpactSequence = null;
    } else if (widget.impactSequence != oldWidget.impactSequence) {
      _impactController.forward(from: 0);
      _exhaustImpactSequence =
          oldWidget.progress < .90 && widget.progress >= .90
          ? widget.impactSequence
          : null;
    } else if (widget.progress < .90 &&
        _exhaustImpactSequence == widget.impactSequence) {
      _exhaustImpactSequence = null;
    }
    _syncIdleController();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([_impactController, _idleController]),
    builder: (context, child) {
      final t = _impactController.value.clamp(0.0, 1.0).toDouble();
      final rig = widget.rig;

      return Stack(
        clipBehavior: Clip.none,
        children: [
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
                  offset: Offset.zero,
                  child: Transform.rotate(
                    key: Key(
                      'landing-basin-deposit-rotation-${widget.nodeId.name}',
                    ),
                    angle: 0,
                    child: Transform.scale(
                      key: Key('landing-basin-deposit-${widget.nodeId.name}'),
                      scale: 1,
                      child: Image.asset(
                        _nodeAsset(t),
                        width: widget.nodeSize,
                        height: widget.nodeSize,
                        gaplessPlayback: true,
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
                        offset: Offset.zero,
                        child: Transform.rotate(
                          key: Key(
                            'landing-basin-robot-response-${widget.nodeId.name}',
                          ),
                          angle: 0,
                          child: Transform.scale(
                            key: Key(
                              'landing-basin-robot-scale-${widget.nodeId.name}',
                            ),
                            scale: 1,
                            child: _articulatedRobot(
                              rig,
                              t,
                              widget.reducedMotion,
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

  String _nodeAsset(double t) {
    final stage = _stageForProgress(widget.progress);
    if (widget.rig == null || widget.reducedMotion) {
      return MiningVisuals.goldNodeStageAsset(stage);
    }
    if (_exhaustImpactSequence == widget.impactSequence) {
      if (t < .24) return MiningVisuals.goldNodeStageAsset(3);
      if (t < .64) {
        final frame = ((t - .24) * 10).floor().clamp(0, 3).toInt() + 1;
        return MiningVisuals.goldNodeExhaustAsset(frame);
      }
      return MiningVisuals.goldNodeStageAsset(4);
    }
    if (stage == 1 && t >= .24 && t < .49) {
      final frame = ((t - .24) * 12).floor().clamp(0, 2).toInt() + 1;
      return MiningVisuals.goldNodeHitAsset(frame);
    }
    if (stage == 1) {
      final frame = (_idleController.value * 4).floor() % 4 + 1;
      return MiningVisuals.goldNodeIdleAsset(frame);
    }
    return MiningVisuals.goldNodeStageAsset(stage);
  }

  int _stageForProgress(double progress) {
    if (progress < .25) return 1;
    if (progress < .60) return 2;
    if (progress < .90) return 3;
    return 4;
  }

  void _syncIdleController() {
    final shouldAnimate =
        widget.rig != null &&
        !widget.reducedMotion &&
        _stageForProgress(widget.progress) == 1;
    if (shouldAnimate) {
      if (!_idleController.isAnimating) {
        _idleController.value = 0;
        _idleController.repeat();
      }
    } else {
      _idleController.stop();
      _idleController.value = 0;
    }
  }

  Widget _articulatedRobot(RigTier tier, double t, bool reducedMotion) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Transform(
          key: Key('landing-basin-robot-body-transform-${widget.nodeId.name}'),
          transform: Matrix4.identity(),
          child: Image.asset(
            MiningVisuals.landingBasinRobotBodyAsset(tier),
            width: widget.rigSize,
            height: widget.rigSize,
          ),
        ),
        Transform.rotate(
          key: Key('landing-basin-robot-arm-transform-${widget.nodeId.name}'),
          alignment: const Alignment(.33, -.24),
          angle: reducedMotion ? 0 : _armAngle(t),
          child: Image.asset(
            MiningVisuals.landingBasinRobotArmAsset(tier),
            width: widget.rigSize,
            height: widget.rigSize,
          ),
        ),
      ],
    );
  }

  double _armAngle(double t) {
    if (t <= .24) return _lerp(0, -.36, _easeOut(t / .24));
    if (t <= .46) {
      return _lerp(-.36, .45, _easeOut((t - .24) / .22));
    }
    if (t <= .62) return _lerp(.45, -.16, _easeOut((t - .46) / .16));
    if (t <= .78) return _lerp(-.16, 0, _easeOut((t - .62) / .16));
    return 0;
  }

  double _easeOut(double amount) {
    final inverse = 1 - amount;
    return 1 - inverse * inverse;
  }

  double _lerp(double start, double end, double amount) =>
      start + (end - start) * amount.clamp(0.0, 1.0);

  @override
  void dispose() {
    _impactController.dispose();
    _idleController.dispose();
    super.dispose();
  }
}
