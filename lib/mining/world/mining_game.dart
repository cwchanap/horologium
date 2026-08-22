import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flame/components.dart';
import 'package:flame/events.dart' as flame_events;
import 'package:flame/game.dart';

import '../../game/terrain/parallax_terrain_component.dart';
import '../mining_content.dart';
import '../mining_state.dart';
import 'mining_components.dart';

enum MiningRewardEffect { reveal, construction, tierUpgrade, sale }

class MiningGame extends FlameGame
    with flame_events.TapCallbacks, flame_events.ScaleDetector {
  MiningGame({required this.planet, required this.initialProgress});

  /// The single projected planet for this world instance. The screen
  /// replaces this whole game when the active planet changes; the game is
  /// never re-pointed at another planet.
  final MiningPlanetDefinition planet;

  /// Sector state supplied at construction and applied once the sector
  /// components exist in [onLoad]. The screen passes the cold-start display
  /// sectors at initialization and the controller state on replacement.
  final Map<MiningSectorId, SectorProgress> initialProgress;

  final Map<MiningSectorId, MiningSectorComponent> _sectors = {};
  MiningSectorId? _selectedSectorId;

  void Function(MiningSectorId?)? onSelectionChanged;
  bool reducedMotion = false;
  bool hasLoaded = false;

  late double _fitZoom;
  late double _minZoom;
  late double _maxZoom;
  late double _scaleStartZoom;

  Vector2 get worldSize => Vector2.all(MiningContentRegistry.worldExtent);

  /// Planet atmosphere: each projected world carries its planet's tint so
  /// Homeworld and Lunar Frontier keep distinct visual identities.
  @override
  Color backgroundColor() => planet.tint;

  MiningSectorComponent sector(MiningSectorId id) => _sectors[id]!;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder.anchor = Anchor.center;

    final terrain =
        ParallaxTerrainComponent(
            gridSize: MiningContentRegistry.terrainGridSize,
            cellSize: MiningContentRegistry.terrainCellSize,
            seed: planet.terrainSeed,
          )
          ..parallaxEnabled = false
          ..anchor = Anchor.center
          ..position = Vector2.zero();
    world.add(terrain);

    for (final definition in planet.sectors) {
      final component = MiningSectorComponent(definition: definition)
        ..position = Vector2(definition.anchor.x, definition.anchor.y)
        ..onSelected = _handleSectorSelected;
      _sectors[definition.id] = component;
      world.add(component);
    }

    _applyProgress(initialProgress);

    final viewport = camera.viewport.size;
    _fitZoom = math.min(
      viewport.x / MiningContentRegistry.worldExtent,
      viewport.y / MiningContentRegistry.worldExtent,
    );
    _minZoom = _fitZoom * 0.5;
    _maxZoom = math.max(_fitZoom * 4, _fitZoom);
    camera.viewfinder.zoom = _fitZoom.clamp(_minZoom, _maxZoom);
    camera.viewfinder.position = Vector2.zero();
    hasLoaded = true;
  }

  void applyState(MiningSave state) => _applyProgress(state.sectors);

  void _applyProgress(Map<MiningSectorId, SectorProgress> sectors) {
    for (final definition in planet.sectors) {
      final progress =
          sectors[definition.id] ?? const SectorProgress(revealed: false);
      _sectors[definition.id]?.updateState(progress);
    }
  }

  void selectSector(MiningSectorId? id) {
    _selectedSectorId = id;
  }

  void playReward(
    MiningRewardEffect effect, {
    MiningSectorId? sectorId,
    bool fallbackToCurrentSelection = true,
  }) {
    if (!hasLoaded) return;

    // Resolve the reward target from the explicit sectorId when provided
    // (the sector that was selected when the action started). For most
    // actions a null sectorId means "no override supplied," so we fall back
    // to the current selection. Sale actions started from the sell tab
    // intentionally pass null as an explicit "no sector" target (the reward
    // originates from the camera/global position), so callers pass
    // fallbackToCurrentSelection: false to keep that null distinct from a
    // missing override. This keeps the reward tied to the action that
    // triggered it even if the player changes tabs while the save is in
    // flight.
    final resolvedId = fallbackToCurrentSelection
        ? (sectorId ?? _selectedSectorId)
        : sectorId;
    final selected = resolvedId == null ? null : _sectors[resolvedId];
    switch (effect) {
      case MiningRewardEffect.reveal:
        selected?.playRevealReward(reducedMotion: reducedMotion);
      case MiningRewardEffect.construction:
        selected?.playConstructionReward(reducedMotion: reducedMotion);
      case MiningRewardEffect.tierUpgrade:
        selected?.playTierUpgradeReward(reducedMotion: reducedMotion);
      case MiningRewardEffect.sale:
        _playSaleReward(selected);
    }
  }

  void focusOnSelection({
    required MiningSectorId sectorId,
    required double bottomObscuredFraction,
  }) {
    if (!hasLoaded) return;
    final definition = planet.sectors.singleWhere(
      (sector) => sector.id == sectorId,
    );
    final fraction = bottomObscuredFraction.clamp(0.0, 1.0).toDouble();
    final viewportHeight = camera.viewport.size.y;
    final sheetTop = viewportHeight * (1 - fraction);
    final currentZoom = camera.viewfinder.zoom;

    double targetYAt(double zoom) =>
        definition.anchor.y + viewportHeight * fraction / (2 * zoom);

    bool targetFitsAt(double zoom) {
      final halfViewHeight = viewportHeight / zoom / 2;
      if (halfViewHeight >= MiningContentRegistry.worldHalfExtent) {
        return false;
      }
      final minY = -MiningContentRegistry.worldHalfExtent + halfViewHeight;
      final maxY = MiningContentRegistry.worldHalfExtent - halfViewHeight;
      final targetY = targetYAt(zoom);
      return targetY >= minY && targetY <= maxY;
    }

    final currentTarget = Vector2(definition.anchor.x, targetYAt(currentZoom));
    final currentCamera = _clampCameraPosition(currentTarget);
    final currentProjectedY =
        viewportHeight / 2 +
        (definition.anchor.y - currentCamera.y) * currentZoom;

    if (currentProjectedY > sheetTop && currentZoom < _maxZoom) {
      double focusZoom;
      if (!targetFitsAt(_maxZoom)) {
        focusZoom = _maxZoom;
      } else {
        var low = currentZoom;
        var high = _maxZoom;
        for (var i = 0; i < 30; i++) {
          final mid = (low + high) / 2;
          if (targetFitsAt(mid)) {
            high = mid;
          } else {
            low = mid;
          }
        }
        focusZoom = high;
      }
      camera.viewfinder.zoom = focusZoom;
    }

    final target = Vector2(
      definition.anchor.x,
      targetYAt(camera.viewfinder.zoom),
    );
    camera.viewfinder.position = _clampCameraPosition(target);
  }

  @override
  void onScaleStart(flame_events.ScaleStartInfo info) {
    _scaleStartZoom = camera.viewfinder.zoom;
  }

  @override
  void onScaleUpdate(flame_events.ScaleUpdateInfo info) {
    final currentScale = info.scale.global;
    if (!currentScale.isIdentity()) {
      final scaleFactor = 1 + (currentScale.y - 1) * 3;
      camera.viewfinder.zoom = _scaleStartZoom * scaleFactor;
      _clampZoom();
    } else {
      final zoom = camera.viewfinder.zoom;
      final delta = -info.delta.global / zoom;
      camera.moveBy(delta);
    }
    _clampCameraToWorld();
  }

  void _handleSectorSelected(MiningSectorId sectorId) {
    selectSector(sectorId);
    onSelectionChanged?.call(sectorId);
  }

  /// The world-space source position of the most recent sale reward, or
  /// null if no sale reward has played. Exposed for testing — the sale
  /// particle is added directly to the world, whose pending additions
  /// are not always visible through world.children in the test
  /// environment.
  Vector2? lastSaleRewardSource;

  void _playSaleReward(MiningSectorComponent? selected) {
    final source =
        selected?.position.clone() ?? camera.viewfinder.position.clone();
    lastSaleRewardSource = source.clone();
    final target = camera.viewfinder.position.clone()
      ..add(
        Vector2(0, -camera.viewport.size.y / camera.viewfinder.zoom * 0.45),
      );
    final particle = MiningSaleRewardComponent(position: source);
    world.add(particle);
    particle.animateTo(target, reducedMotion: reducedMotion);
  }

  void _clampZoom() {
    if (!hasLoaded) return;
    camera.viewfinder.zoom = camera.viewfinder.zoom.clamp(_minZoom, _maxZoom);
  }

  void _clampCameraToWorld() {
    if (!hasLoaded) return;
    camera.viewfinder.position = _clampCameraPosition(
      camera.viewfinder.position,
    );
  }

  Vector2 _clampCameraPosition(Vector2 position) {
    final zoom = camera.viewfinder.zoom;
    final halfViewWidth = camera.viewport.size.x / zoom / 2;
    final halfViewHeight = camera.viewport.size.y / zoom / 2;
    final halfWorld = MiningContentRegistry.worldHalfExtent;

    final minX = -halfWorld + halfViewWidth;
    final maxX = halfWorld - halfViewWidth;
    final minY = -halfWorld + halfViewHeight;
    final maxY = halfWorld - halfViewHeight;

    return Vector2(
      halfViewWidth >= halfWorld ? 0 : position.x.clamp(minX, maxX),
      halfViewHeight >= halfWorld ? 0 : position.y.clamp(minY, maxY),
    );
  }
}
