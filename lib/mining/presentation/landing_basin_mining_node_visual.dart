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
      final impactActive = rig != null && t < 1;
      final robotDx = rig == null || widget.reducedMotion
          ? 0.0
          : _robotDx(t, widget.rigSize);
      final depositScale = widget.reducedMotion ? 1.0 : _depositScale(t);

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
                        offset: Offset(robotDx, 0),
                        child: Image.asset(
                          MiningVisuals.landingBasinRobotAsset(rig),
                          width: widget.rigSize,
                          height: widget.rigSize,
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
          if (impactActive)
            Positioned(
              left: widget.nodeSize * .62,
              top: widget.nodeSize * .48,
              width: widget.nodeSize * .3,
              height: widget.nodeSize * .3,
              child: Opacity(
                key: Key('landing-basin-impact-${widget.nodeId.name}'),
                opacity: _contactOpacity(t),
                child: Image.asset(MiningVisuals.landingBasinImpact),
              ),
            ),
        ],
      );
    },
  );

  double _robotDx(double t, double rigSize) {
    if (t <= .14) return _lerp(0, .12 * rigSize, t / .14);
    if (t <= .70) return _lerp(.12 * rigSize, .08 * rigSize, (t - .14) / .56);
    return _lerp(.08 * rigSize, 0, (t - .70) / .30);
  }

  double _depositScale(double t) => t <= .14 ? _lerp(.94, 1, t / .14) : 1;

  double _contactOpacity(double t) => t <= .18 ? 1 - t / .18 : 0;

  double _lerp(double start, double end, double amount) =>
      start + (end - start) * amount;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
