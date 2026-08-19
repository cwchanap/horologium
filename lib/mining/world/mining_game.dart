import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart' as flame_events;
import 'package:flame/game.dart';

import '../../game/terrain/parallax_terrain_component.dart';
import '../mining_content.dart';
import '../mining_state.dart';
import 'mining_components.dart';

class MiningGame extends FlameGame
    with flame_events.TapCallbacks, flame_events.ScaleDetector {
  MiningGame({required this.content});

  final MiningContentRegistry content;
  final Map<MiningSectorId, MiningSectorComponent> _sectors = {};

  void Function(MiningSectorId?)? onSelectionChanged;
  bool reducedMotion = false;
  bool hasLoaded = false;

  late double _fitZoom;
  late double _minZoom;
  late double _maxZoom;
  late double _scaleStartZoom;

  Vector2 get worldSize => Vector2.all(MiningContentRegistry.worldExtent);

  MiningSectorComponent sector(MiningSectorId id) => _sectors[id]!;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder.anchor = Anchor.center;

    final terrain =
        ParallaxTerrainComponent(
            gridSize: MiningContentRegistry.terrainGridSize,
            seed: 631,
          )
          ..parallaxEnabled = false
          ..size = Vector2.all(MiningContentRegistry.worldExtent)
          ..anchor = Anchor.center
          ..position = Vector2.zero();
    world.add(terrain);

    for (final definition in content.sectors) {
      final component = MiningSectorComponent(definition: definition)
        ..position = Vector2(definition.anchor.x, definition.anchor.y)
        ..onSelected = _handleSectorSelected;
      _sectors[definition.id] = component;
      world.add(component);
    }

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

  void applyState(MiningSave state) {
    for (final definition in content.sectors) {
      final progress =
          state.sectors[definition.id] ?? const SectorProgress(revealed: false);
      _sectors[definition.id]?.updateState(progress);
    }
  }

  void focusOnSelection({
    required MiningSectorId sectorId,
    required double bottomObscuredFraction,
  }) {
    final definition = content.sector(sectorId);
    final zoom = camera.viewfinder.zoom;
    final obscuredWorldHeight =
        camera.viewport.size.y / zoom * bottomObscuredFraction.clamp(0.0, 1.0);
    final target = Vector2(
      definition.anchor.x,
      definition.anchor.y - obscuredWorldHeight,
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
      final delta = (info.delta.global..negate()) / zoom;
      camera.moveBy(delta);
    }
    _clampCameraToWorld();
  }

  void _handleSectorSelected(MiningSectorId sectorId) {
    onSelectionChanged?.call(sectorId);
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
