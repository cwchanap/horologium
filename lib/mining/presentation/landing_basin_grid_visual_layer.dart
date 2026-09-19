import 'dart:async';

import 'package:flutter/material.dart';
import 'package:horologium/mining/mine_site_view.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_grid.dart';
import 'package:horologium/mining/presentation/mining_grid_map.dart';
import 'package:horologium/mining/presentation/mining_theme.dart';
import 'package:horologium/mining/presentation/mining_visuals.dart';

/// Stable deposit key derived from authored geometry, matching the grid
/// map's `x-y-size` contract for dense-field resources.
String _depositKey(MiningDepositDefinition definition) =>
    '${definition.x}-${definition.y}-${definition.size}';

/// Maximum HP of a Landing Basin resource body of [size] cells per side:
/// 40 HP per cell row (40 / 80 / 120 for 1x1 / 2x2 / 3x3).
int landingBasinMaxHp(int size) => size * 40;

/// Damage one robot strike deals to its resource, by rig tier: 10 per tier.
int landingBasinStrikeDamage(RigTier tier) => (tier.index + 1) * 10;

/// Strike damage summed per distinct target resource, keyed by the authored
/// deposit geometry (which has value equality).
Map<MiningDepositDefinition, int> landingBasinGroupedDamage(
  Iterable<MineSiteRigView> rigs,
) {
  final groups = <MiningDepositDefinition, int>{};
  for (final rig in rigs) {
    final damage = landingBasinStrikeDamage(rig.placement.tier);
    groups[rig.target] = (groups[rig.target] ?? 0) + damage;
  }
  return groups;
}

/// HP remaining after one strike, clamped at zero: overkill is discarded.
int landingBasinRemainingHpAfterStrike(int remainingHp, int damage) =>
    remainingHp > damage ? remainingHp - damage : 0;

/// HPA-451 authored art/animation for the Landing Basin mine site grid.
/// Owns only visuals: one impact controller, one S1 idle controller, finite
/// frame precache, the stalled-first-impact drop, and transient per-resource
/// strike HP (never persisted, never replayed from cold-load/resume). The
/// grid map renders no generic deposit/rig art for Landing Basin; this layer
/// is the object layer.
class LandingBasinGridVisualLayer extends StatefulWidget {
  const LandingBasinGridVisualLayer({
    super.key,
    required this.view,
    required this.impactSequence,
    required this.reducedMotion,
    required this.cellSize,
    this.onMiningImpact,
  });

  final MineSiteView view;
  final int impactSequence;
  final bool reducedMotion;
  final double cellSize;
  final VoidCallback? onMiningImpact;

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

  /// Single contact latch for the current impact timeline: opened by a real
  /// impact, closed by the first valid strike tick. Gates both the visible HP
  /// application and the SFX callback so one strike resolves exactly once.
  bool _impactContactHandled = true;

  /// Transient remaining HP per currently mined resource. Seeded from
  /// [initState]/[didUpdateWidget], mutated only by the contact latch, never
  /// persisted and never initialized from build.
  final Map<MiningDepositDefinition, int> _remainingHp = {};

  /// Resources broken by the current impact contact. Forces visible zero HP
  /// until the impact timeline completes, then the already-stored fresh max
  /// shows for the next cycle. Cleared when a real impact fires.
  final Set<MiningDepositDefinition> _brokeOnContact = {};

  /// The safety-cap timer for the deferred first impact. Tracked so it can be
  /// cancelled in [dispose]; otherwise a cold-cache deferral that outlives the
  /// widget (e.g. headless web tests where the asset channel never pumps)
  /// leaves a pending timer after the tree is torn down.
  Timer? _deferTimer;

  double get _progress => _progressOf(widget.view);

  static double _progressOf(MineSiteView view) => view.capacity <= 0
      ? 0.0
      : (view.cargo / view.capacity).clamp(0.0, 1.0).toDouble();

  @override
  void initState() {
    super.initState();
    _syncHp();
    _impactController.addListener(_notifyMiningImpact);
    _syncIdleController();
  }

  void _notifyMiningImpact() {
    if (_impactContactHandled || _impactController.value < .46) return;
    // A frame delayed past the strike (including background/resume) is a late
    // miss: it stays quiet and never marks handled, so it never mutates HP.
    if (_impactController.value >= .62) return;
    _impactContactHandled = true;
    for (final entry in landingBasinGroupedDamage(widget.view.rigs).entries) {
      final definition = entry.key;
      final remaining = landingBasinRemainingHpAfterStrike(
        _remainingHp[definition] ?? landingBasinMaxHp(definition.size),
        entry.value,
      );
      if (remaining > 0) {
        _remainingHp[definition] = remaining;
      } else {
        // Broken: back the next cycle immediately; the chrome reads zero for
        // the rest of this impact via [_brokeOnContact].
        _remainingHp[definition] = landingBasinMaxHp(definition.size);
        _brokeOnContact.add(definition);
      }
    }
    if (!widget.reducedMotion && widget.view.rigs.isNotEmpty) {
      widget.onMiningImpact?.call();
    }
  }

  /// Seeds newly mined resources at max HP and prunes resources that are no
  /// longer mined, preserving backing HP of already-tracked resources.
  void _syncHp() {
    final mined = {
      for (final deposit in widget.view.deposits)
        if (deposit.minerCount > 0) deposit.definition,
    };
    for (final definition in mined) {
      _remainingHp.putIfAbsent(
        definition,
        () => landingBasinMaxHp(definition.size),
      );
    }
    _remainingHp.removeWhere((definition, _) => !mined.contains(definition));
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
    _impactContactHandled = false;
    _brokeOnContact.clear();
    _impactController.forward(from: 0);
    _exhaustImpactSequence = shouldExhaust ? widget.impactSequence : null;
  }

  void _deferImpact(int sequence, bool shouldExhaust) {
    _impactContactHandled = true;
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
    _syncHp();
    if (widget.view.rigs.isEmpty) {
      _impactContactHandled = true;
      _impactController.stop();
      _impactController.value = 1;
      _exhaustImpactSequence = null;
      _pendingImpactSequence = null;
      _deferTimer?.cancel();
      _deferTimer = null;
    } else if (widget.impactSequence != oldWidget.impactSequence) {
      final oldProgress = _progressOf(oldWidget.view);
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

  /// One positioned deposit body. Unmined deposits render the current stage
  /// plate dimmed; mined deposits render the animated frame for tick [t].
  Positioned _depositNode(MineSiteDepositView deposit, double cell, double t) =>
      Positioned(
        key: Key('landing-basin-deposit-${_depositKey(deposit.definition)}'),
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
            // Mined art stays full; surveyed-but-unmined dims; unsurveyed
            // dims further so locked resources read differently from
            // surveyed peers without floating lock badges.
            opacity: deposit.minerCount > 0
                ? null
                : AlwaysStoppedAnimation(deposit.isSurveyed ? .62 : .35),
          ),
        ),
      );

  /// Visible HP: backing remaining normally; zero through the rest of the
  /// impact for a resource broken at contact; the already-stored fresh max
  /// once the impact timeline completes.
  int _displayedHp(MiningDepositDefinition definition) {
    final backing =
        _remainingHp[definition] ?? landingBasinMaxHp(definition.size);
    final t = _t;
    if (_brokeOnContact.contains(definition) && t >= .46 && t < 1.0) return 0;
    return backing;
  }

  /// One damage label per rig for a valid contact's post-contact tail
  /// (0.46 <= t < 1.0), anchored at the rig→target midpoint. Normal motion
  /// drifts upward and fades toward timeline end; reduced motion fades in
  /// place. Gated on the contact latch, so cold-drop and late-miss paths
  /// render nothing and no label history is kept.
  Widget? _damageLabel(MineSiteRigView rig, double cell) {
    if (!_impactContactHandled) return null;
    final t = _t;
    if (t < .46 || t >= 1.0) return null;
    final tail = (t - .46) / .54;
    final anchor = Offset(
      (rig.placement.cell.x + .5 + rig.target.x + rig.target.size / 2) /
          2 *
          cell,
      (rig.placement.cell.y + .5 + rig.target.y + rig.target.size / 2) /
          2 *
          cell,
    );
    final drift = widget.reducedMotion ? 0.0 : tail * 18;
    return Positioned(
      key: Key(
        'landing-basin-damage-'
        '${rig.placement.cell.x}-${rig.placement.cell.y}',
      ),
      left: anchor.dx - 24,
      top: anchor.dy - drift,
      width: 48,
      child: ExcludeSemantics(
        child: Opacity(
          opacity: (1 - tail).clamp(0.0, 1.0),
          child: Text(
            '-${landingBasinStrikeDamage(rig.placement.tier)}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MiningTheme.primaryText,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(color: Colors.black, blurRadius: 3)],
            ),
          ),
        ),
      ),
    );
  }

  /// Transient HP chrome above a mined resource's oversized art, centered on
  /// its visual bounds. A sibling of the deposit node, so frame tests still
  /// find exactly one Image below each deposit key.
  Positioned _hpChrome(MineSiteDepositView deposit, double cell) {
    final definition = deposit.definition;
    final visual = depositVisualSize(definition.size);
    final max = landingBasinMaxHp(definition.size);
    final remaining = _displayedHp(definition);
    // [_displayedHp] reads zero only while the resource is broken by the
    // current contact and the impact timeline has not yet completed.
    final brokeNow = remaining == 0;
    final tail = ((_t - .46) / .54).clamp(0.0, 1.0);
    final emphasis = brokeNow && !widget.reducedMotion
        ? 1 + .2 * (1 - tail)
        : 1.0;
    return Positioned(
      key: Key('landing-basin-hp-${_depositKey(definition)}'),
      left: (definition.x + definition.size / 2) * cell - visual / 2,
      top: (definition.y + definition.size / 2) * cell - visual / 2 - 18,
      width: visual,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: remaining / max,
                color: MiningTheme.warning,
                backgroundColor: Colors.black54,
              ),
            ),
            Transform.scale(
              scale: emphasis,
              child: Text(
                '$remaining/$max',
                style: TextStyle(
                  color: brokeNow
                      ? MiningTheme.warning
                      : MiningTheme.primaryText,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cell = widget.cellSize;
    // Unmined resources never depend on the animation tick: they live in
    // AnimatedBuilder.child so a per-frame rebuild recomposes only the at
    // most four mined resources and the rigs. The RepaintBoundary moves the
    // static subtree into its own composited layer, so per-frame repaints of
    // the parent Stack composite the retained layer instead of re-painting
    // every unmined resource. Parent rebuilds caused by gameplay state
    // naturally reconstruct static vs animated membership.
    final staticResources = RepaintBoundary(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final deposit in widget.view.deposits)
            if (deposit.minerCount == 0) _depositNode(deposit, cell, 1),
        ],
      ),
    );
    return AnimatedBuilder(
      animation: Listenable.merge([_impactController, _idleController]),
      child: staticResources,
      builder: (context, staticLayer) => Stack(
        clipBehavior: Clip.none,
        children: [
          staticLayer!,
          for (final deposit in widget.view.deposits)
            if (deposit.minerCount > 0) _depositNode(deposit, cell, _t),
          for (final deposit in widget.view.deposits)
            if (deposit.minerCount > 0) _hpChrome(deposit, cell),
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
                child: _rigRobot(rig, _t, cell),
              ),
            ),
          for (final rig in widget.view.rigs)
            if (_damageLabel(rig, cell) case final label?) label,
        ],
      ),
    );
  }

  double get _t => _impactController.value.clamp(0.0, 1.0).toDouble();

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
