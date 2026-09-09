import 'dart:async';

import 'package:flutter/material.dart';
import 'package:horologium/mining/mine_site_view.dart';
import 'package:horologium/mining/presentation/mining_grid_map.dart';
import 'package:horologium/mining/presentation/mining_visuals.dart';

/// HPA-451 authored art/animation for the Landing Basin mine site grid.
/// Owns only visuals: one impact controller, one S1 idle controller, finite
/// frame precache, and the stalled-first-impact drop. The grid map renders no
/// generic deposit/rig art for Landing Basin; this layer is the object layer.
class LandingBasinGridVisualLayer extends StatefulWidget {
  const LandingBasinGridVisualLayer({
    super.key,
    required this.view,
    required this.impactSequence,
    required this.reducedMotion,
    required this.cellSize,
  });

  final MineSiteView view;
  final int impactSequence;
  final bool reducedMotion;
  final double cellSize;

  @override
  State<LandingBasinGridVisualLayer> createState() =>
      _LandingBasinGridVisualLayerState();
}

class _LandingBasinGridVisualLayerState
    extends State<LandingBasinGridVisualLayer>
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

  /// Maximum wait for the finite gold frames to decode before dropping the
  /// first one-shot impact. Production decode for these small PNGs normally
  /// completes well under this budget, so the authored hit/exhaust frames are
  /// ready before the first impact. The cap only triggers when decode stalls
  /// (cold web, or headless tests where the platform asset channel does not
  /// pump); in that case the pending impact is dropped (kept static) rather
  /// than fired against unresolved frames. Readiness stays tied to actual
  /// [Future.wait] completion, so later impacts animate once the frames really
  /// decode. The visual never hangs waiting on images.
  static const Duration _firstImpactDeferBudget = Duration(milliseconds: 200);

  int? _exhaustImpactSequence;
  bool _framesPrecached = false;
  bool _framesReady = false;
  int? _pendingImpactSequence;
  bool _pendingExhaust = false;

  /// The safety-cap timer for the deferred first impact. Tracked so it can be
  /// cancelled in [dispose]; otherwise a cold-cache deferral that outlives the
  /// widget (e.g. headless web tests where the asset channel never pumps)
  /// leaves a pending timer after the tree is torn down.
  Timer? _deferTimer;

  double get _progress => widget.view.capacity <= 0
      ? 0.0
      : (widget.view.cargo / widget.view.capacity).clamp(0.0, 1.0).toDouble();

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
    final configuration = createLocalImageConfiguration(context);
    final providers = [for (final path in paths) AssetImage(path)];
    // If every frame is already cached and decoded (e.g. warmed by a prior
    // precache or another visual), mark ready synchronously. This avoids
    // relying on [Future.wait] completion in fake-async test environments where
    // [precacheImage] may not resolve during [tester.pump]; in production it
    // skips a redundant async round-trip when the cache is already warm.
    if (providers.every((p) => _isImageReady(p, configuration))) {
      _framesReady = true;
      _flushPendingImpact();
      return;
    }
    final future = Future.wait([
      for (final p in providers) precacheImage(p, context),
    ]);
    unawaited(
      future.then((_) {
        if (!mounted || _framesReady) return;
        _framesReady = true;
        _flushPendingImpact();
      }),
    );
  }

  /// Synchronously checks whether [provider] has a decoded image available in
  /// the [ImageCache]. The [ImageStreamListener] fires with
  /// `synchronousCall = true` when the completer already holds an [ImageInfo],
  /// which only happens for cache hits that have finished decoding.
  bool _isImageReady(ImageProvider provider, ImageConfiguration configuration) {
    final stream = provider.resolve(configuration);
    var ready = false;
    late ImageStreamListener listener;
    listener = ImageStreamListener((_, synchronousCall) {
      if (synchronousCall) ready = true;
    });
    stream.addListener(listener);
    stream.removeListener(listener);
    return ready;
  }

  void _fireImpact(bool shouldExhaust) {
    _impactController.forward(from: 0);
    _exhaustImpactSequence = shouldExhaust ? widget.impactSequence : null;
  }

  void _deferImpact(int sequence, bool shouldExhaust) {
    _pendingImpactSequence = sequence;
    _pendingExhaust = shouldExhaust;
    // Park the controller at the start of the timeline so the authored
    // wind-up (exhaust S3 hold) or the resting idle frame shows immediately
    // while the finite hit/exhaust frames finish decoding. Only the forward
    // that drives through those frames waits for decode.
    _exhaustImpactSequence = shouldExhaust ? sequence : null;
    _impactController.value = 0;
    _deferTimer?.cancel();
    _deferTimer = Timer(_firstImpactDeferBudget, () {
      if (!mounted || _framesReady) return;
      // Decode stalled past the safety budget. Drop this one impact and keep
      // the grid static instead of firing the one-shot against unresolved
      // frames. Readiness stays owned by the precache [Future.wait] completion
      // above, so later impacts animate correctly once the frames really
      // decode. No historical replay: the pending sequence is discarded.
      _deferTimer = null;
      _pendingImpactSequence = null;
      _pendingExhaust = false;
      _exhaustImpactSequence = null;
      _impactController.value = 1;
    });
  }

  void _flushPendingImpact() {
    final pending = _pendingImpactSequence;
    if (pending == null) return;
    _pendingImpactSequence = null;
    if (widget.impactSequence == pending && widget.view.rigs.isNotEmpty) {
      _fireImpact(_pendingExhaust);
    }
  }

  @override
  void didUpdateWidget(LandingBasinGridVisualLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.view.rigs.isEmpty) {
      _impactController.stop();
      _impactController.value = 1;
      _exhaustImpactSequence = null;
      _pendingImpactSequence = null;
      _deferTimer?.cancel();
      _deferTimer = null;
    } else if (widget.impactSequence != oldWidget.impactSequence) {
      final oldProgress = oldWidget.view.capacity <= 0
          ? 0.0
          : (oldWidget.view.cargo / oldWidget.view.capacity)
                .clamp(0.0, 1.0)
                .toDouble();
      final shouldExhaust = oldProgress < .90 && _progress >= .90;
      if (_framesReady) {
        _fireImpact(shouldExhaust);
      } else {
        _deferImpact(widget.impactSequence, shouldExhaust);
      }
    } else if (_progress < .90 &&
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
      final cell = widget.cellSize;

      return Stack(
        clipBehavior: Clip.none,
        children: [
          for (final deposit in widget.view.deposits)
            Positioned(
              key: Key('landing-basin-deposit-${deposit.definition.id.name}'),
              left: deposit.definition.x * cell,
              top: deposit.definition.y * cell,
              width: deposit.definition.size * cell,
              height: deposit.definition.size * cell,
              child: OverflowBox(
                maxWidth: depositVisualSize(deposit.definition.size),
                maxHeight: depositVisualSize(deposit.definition.size),
                alignment: Alignment.center,
                child: Image.asset(
                  _depositAsset(deposit, t),
                  width: depositVisualSize(deposit.definition.size),
                  height: depositVisualSize(deposit.definition.size),
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  opacity: deposit.minerCount > 0
                      ? null
                      : const AlwaysStoppedAnimation(.62),
                ),
              ),
            ),
          for (final rig in widget.view.rigs)
            Positioned(
              left: rig.placement.cell.x * cell,
              top: rig.placement.cell.y * cell,
              width: cell,
              height: cell,
              child: OverflowBox(
                maxWidth: cell + 12,
                maxHeight: cell + 12,
                alignment: Alignment.center,
                child: _rigRobot(rig, t, cell),
              ),
            ),
        ],
      );
    },
  );

  /// The robot mirrors horizontally only when its deposit sits to its right,
  /// so the articulated arm always strikes toward the resource. The chassis is
  /// never rotated vertically for deposits above or below.
  Widget _rigRobot(MineSiteRigView rig, double t, double cell) {
    final rigCenterX = rig.placement.cell.x + .5;
    final targetCenterX = rig.target.x + rig.target.size / 2;
    final mirror = targetCenterX > rigCenterX;
    final cellKey = '${rig.placement.cell.x}-${rig.placement.cell.y}';
    return Transform(
      key: Key('landing-basin-robot-flip-$cellKey'),
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(mirror ? -1 : 1, 1, 1),
      child: SizedBox(
        key: Key('landing-basin-robot-$cellKey'),
        width: cell + 12,
        height: cell + 12,
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            Transform(
              key: Key('landing-basin-robot-body-transform-$cellKey'),
              transform: Matrix4.identity(),
              child: Image.asset(
                MiningVisuals.landingBasinRobotBodyAsset(rig.placement.tier),
                width: cell + 12,
                height: cell + 12,
              ),
            ),
            Transform.rotate(
              key: Key('landing-basin-robot-arm-transform-$cellKey'),
              alignment: const Alignment(.33, -.24),
              angle: widget.reducedMotion ? 0 : _armAngle(t),
              child: Image.asset(
                MiningVisuals.landingBasinRobotArmAsset(rig.placement.tier),
                width: cell + 12,
                height: cell + 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _depositAsset(MineSiteDepositView deposit, double t) {
    final stage = _stageForProgress(_progress);
    if (deposit.minerCount == 0 || widget.reducedMotion) {
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
        widget.view.rigs.isNotEmpty &&
        !widget.reducedMotion &&
        _stageForProgress(_progress) == 1;
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
    _deferTimer?.cancel();
    _deferTimer = null;
    _impactController.dispose();
    _idleController.dispose();
    super.dispose();
  }
}
