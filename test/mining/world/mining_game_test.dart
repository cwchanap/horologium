import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart' as flame_events;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/terrain/parallax_terrain_component.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:horologium/mining/world/mining_components.dart';
import 'package:horologium/mining/world/mining_game.dart';

Future<void> pumpMiningGame(
  WidgetTester tester,
  MiningGame game, {
  Size size = const Size(360, 640),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: GameWidget(game: game)),
    ),
  );
  for (var i = 0; i < 80 && !game.hasLoaded; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(game.hasLoaded, isTrue);
}

void main() {
  testWidgets('constructor initial progress is applied once sectors exist', (
    tester,
  ) async {
    final content = MiningContentRegistry.stellarMining();
    final game = MiningGame(
      planet: content.planet(MiningPlanetId.lunarFrontier),
      initialProgress: const {
        MiningSectorId.frozenBasin: SectorProgress(
          revealed: true,
          mine: MineState(level: 3, storedAmount: 5),
        ),
        MiningSectorId.titaniumHighlands: SectorProgress(revealed: false),
        MiningSectorId.heliumMare: SectorProgress(revealed: true),
      },
    );
    await pumpMiningGame(tester, game);
    await tester.pump(const Duration(milliseconds: 100));
    game.updateTree(0);

    final frozen = game.sector(MiningSectorId.frozenBasin);
    expect(frozen.revealed, isTrue);
    expect(frozen.mine, const MineState(level: 3, storedAmount: 5));
    expect(frozen.children.whereType<OperationLightComponent>(), hasLength(1));
    expect(
      frozen.children.whereType<AdvancedPlatformComponent>(),
      hasLength(1),
    );
    expect(
      frozen.children.whereType<SecondaryMachineryComponent>(),
      hasLength(1),
    );

    final titanium = game.sector(MiningSectorId.titaniumHighlands);
    expect(titanium.revealed, isFalse);
    expect(titanium.mine, isNull);

    final helium = game.sector(MiningSectorId.heliumMare);
    expect(helium.revealed, isTrue);
    expect(helium.mine, isNull);
  });

  testWidgets('all authored anchors are visible at initial 360x640 fit', (
    tester,
  ) async {
    final content = MiningContentRegistry.stellarMining();
    final game = MiningGame(
      planet: content.planet(MiningPlanetId.homeworld),
      initialProgress: const {},
    );
    await pumpMiningGame(tester, game);

    expect(game.worldSize.x, 1800);
    expect(game.worldSize.y, 1800);
    expect(game.camera.viewfinder.zoom, closeTo(0.2, 0.0001));

    for (final definition in content.planet(MiningPlanetId.homeworld).sectors) {
      final screenX = 180 + definition.anchor.x * game.camera.viewfinder.zoom;
      final screenY = 320 + definition.anchor.y * game.camera.viewfinder.zoom;
      expect(screenX, inInclusiveRange(0, 360));
      expect(screenY, inInclusiveRange(0, 640));
    }
  });

  testWidgets('mounted terrain uses the mining world extent contract', (
    tester,
  ) async {
    final game = MiningGame(
      planet: MiningContentRegistry.stellarMining().planet(
        MiningPlanetId.homeworld,
      ),
      initialProgress: const {},
    );
    await pumpMiningGame(tester, game);
    await tester.pump(const Duration(milliseconds: 100));
    game.updateTree(0);

    final terrain = game.world.children
        .whereType<ParallaxTerrainComponent>()
        .single;
    final expectedExtent =
        MiningContentRegistry.terrainGridSize *
        MiningContentRegistry.terrainCellSize;

    expect(terrain.cellSize, MiningContentRegistry.terrainCellSize);
    expect(terrain.size, Vector2.all(expectedExtent));
    expect(terrain.size.x, MiningContentRegistry.worldExtent);
    expect(terrain.size.y, MiningContentRegistry.worldExtent);
  });

  testWidgets('levels one three and five add distinct mounted structure', (
    tester,
  ) async {
    final content = MiningContentRegistry.stellarMining();
    final game = MiningGame(
      planet: content.planet(MiningPlanetId.homeworld),
      initialProgress: const {},
    );
    await pumpMiningGame(tester, game);
    final base = MiningSave.initial(nowUtc: DateTime.utc(2026, 8, 18, 12));

    MiningSave withGoldLevel(int level) => base.copyWith(
      sectors: {
        ...base.sectors,
        MiningSectorId.landingBasin: SectorProgress(
          revealed: true,
          mine: MineState(level: level, storedAmount: 0),
        ),
      },
    );

    final sector = game.sector(MiningSectorId.landingBasin);
    game.selectSector(MiningSectorId.landingBasin);

    game.applyState(withGoldLevel(1));
    await tester.pump();
    expect(sector.children.whereType<OperationLightComponent>(), hasLength(1));
    expect(sector.children.whereType<AdvancedPlatformComponent>(), isEmpty);
    expect(sector.children.whereType<SecondaryMachineryComponent>(), isEmpty);
    expect(sector.children.whereType<EliteRingComponent>(), isEmpty);
    expect(
      sector.children.whereType<OperationLightComponent>().single.size.x,
      greaterThan(0),
    );
    expect(
      sector.children.whereType<OperationLightComponent>().single.size.y,
      greaterThan(0),
    );
    game.playReward(MiningRewardEffect.reveal);
    game.playReward(MiningRewardEffect.construction);
    game.playReward(MiningRewardEffect.tierUpgrade);
    game.playReward(MiningRewardEffect.sale);
    await tester.pump(const Duration(milliseconds: 50));
    expect(sector.children.whereType<OperationLightComponent>(), hasLength(1));
    expect(sector.children.whereType<AdvancedPlatformComponent>(), isEmpty);
    expect(sector.children.whereType<EliteRingComponent>(), isEmpty);

    game.applyState(withGoldLevel(3));
    await tester.pump();
    expect(
      sector.children.whereType<AdvancedPlatformComponent>(),
      hasLength(1),
    );
    expect(
      sector.children.whereType<SecondaryMachineryComponent>(),
      hasLength(1),
    );
    expect(sector.children.whereType<EliteRingComponent>(), isEmpty);
    game.playReward(MiningRewardEffect.tierUpgrade);
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      sector.children.whereType<AdvancedPlatformComponent>(),
      hasLength(1),
    );
    expect(
      sector.children.whereType<SecondaryMachineryComponent>(),
      hasLength(1),
    );
    expect(sector.children.whereType<EliteRingComponent>(), isEmpty);

    game.applyState(withGoldLevel(5));
    await tester.pump();
    expect(sector.children.whereType<OperationLightComponent>(), hasLength(1));
    expect(
      sector.children.whereType<AdvancedPlatformComponent>(),
      hasLength(1),
    );
    expect(
      sector.children.whereType<SecondaryMachineryComponent>(),
      hasLength(1),
    );
    expect(sector.children.whereType<EliteRingComponent>(), hasLength(1));
    for (final marker in <PositionComponent>[
      sector.children.whereType<OperationLightComponent>().single,
      sector.children.whereType<AdvancedPlatformComponent>().single,
      sector.children.whereType<SecondaryMachineryComponent>().single,
      sector.children.whereType<EliteRingComponent>().single,
    ]) {
      expect(marker.size.x, greaterThan(0));
      expect(marker.size.y, greaterThan(0));
    }
    game.reducedMotion = true;
    game.playReward(MiningRewardEffect.reveal);
    game.playReward(MiningRewardEffect.construction);
    game.playReward(MiningRewardEffect.tierUpgrade);
    game.playReward(MiningRewardEffect.sale);
    await tester.pump(const Duration(milliseconds: 50));
    expect(sector.children.whereType<OperationLightComponent>(), hasLength(1));
    expect(
      sector.children.whereType<AdvancedPlatformComponent>(),
      hasLength(1),
    );
    expect(
      sector.children.whereType<SecondaryMachineryComponent>(),
      hasLength(1),
    );
    expect(sector.children.whereType<EliteRingComponent>(), hasLength(1));
  });

  testWidgets('the world background uses the planet mining-world tint', (
    tester,
  ) async {
    final content = MiningContentRegistry.stellarMining();
    final homeworld = MiningGame(
      planet: content.planet(MiningPlanetId.homeworld),
      initialProgress: const {},
    );
    final lunar = MiningGame(
      planet: content.planet(MiningPlanetId.lunarFrontier),
      initialProgress: const {},
    );

    expect(
      homeworld.backgroundColor(),
      content.planet(MiningPlanetId.homeworld).tint,
    );
    expect(
      lunar.backgroundColor(),
      content.planet(MiningPlanetId.lunarFrontier).tint,
    );
    expect(homeworld.backgroundColor(), isNot(equals(lunar.backgroundColor())));
  });

  for (final viewport in const [Size(360, 640), Size(430, 932)]) {
    testWidgets(
      'selection focus places the sector above the sheet at $viewport',
      (tester) async {
        final content = MiningContentRegistry.stellarMining();
        final game = MiningGame(
          planet: content.planet(MiningPlanetId.homeworld),
          initialProgress: const {},
        )..reducedMotion = true;
        await pumpMiningGame(tester, game, size: viewport);

        final selections = <MiningSectorId>[];
        game.onSelectionChanged = (id) {
          if (id != null) selections.add(id);
        };
        game
            .sector(MiningSectorId.landingBasin)
            .onTapUp(
              flame_events.TapUpEvent(
                0,
                game,
                TapUpDetails(
                  globalPosition: Offset.zero,
                  kind: PointerDeviceKind.touch,
                ),
              ),
            );
        expect(selections, [MiningSectorId.landingBasin]);

        final initialZoom = game.camera.viewfinder.zoom;
        const obscuredFraction = 0.44;
        game.focusOnSelection(
          sectorId: MiningSectorId.landingBasin,
          bottomObscuredFraction: obscuredFraction,
        );
        await tester.pump();

        final landingY = content.sector(MiningSectorId.landingBasin).anchor.y;
        final zoom = game.camera.viewfinder.zoom;
        final halfViewWidth = viewport.width / zoom / 2;
        final halfViewHeight = viewport.height / zoom / 2;
        final minX = -MiningContentRegistry.worldHalfExtent + halfViewWidth;
        final maxX = MiningContentRegistry.worldHalfExtent - halfViewWidth;
        final minY = -MiningContentRegistry.worldHalfExtent + halfViewHeight;
        final maxY = MiningContentRegistry.worldHalfExtent - halfViewHeight;
        final projectedY =
            viewport.height / 2 +
            (landingY - game.camera.viewfinder.position.y) * zoom;
        final sheetTop = viewport.height * (1 - obscuredFraction);

        expect(zoom, greaterThan(initialZoom));
        expect(game.camera.viewfinder.position.y, greaterThan(landingY));
        expect(game.camera.viewfinder.position.x, inInclusiveRange(minX, maxX));
        expect(
          game.camera.viewfinder.position.y,
          greaterThanOrEqualTo(minY - 0.1),
        );
        expect(
          game.camera.viewfinder.position.y,
          lessThanOrEqualTo(maxY + 0.1),
        );
        expect(projectedY, lessThanOrEqualTo(sheetTop + 0.5));

        // An extreme obstruction still exercises the world-bounds clamp.
        game.focusOnSelection(
          sectorId: MiningSectorId.landingBasin,
          bottomObscuredFraction: 0.9,
        );
        await tester.pump();
        final clampedZoom = game.camera.viewfinder.zoom;
        final clampedHalfHeight = viewport.height / clampedZoom / 2;
        final clampedMaxY =
            MiningContentRegistry.worldHalfExtent - clampedHalfHeight;
        expect(game.camera.viewfinder.position.y, closeTo(clampedMaxY, 0.5));
        expect(
          game.camera.viewfinder.position.y,
          greaterThanOrEqualTo(
            -MiningContentRegistry.worldHalfExtent + clampedHalfHeight - 0.1,
          ),
        );
        expect(
          game.camera.viewfinder.position.y,
          lessThanOrEqualTo(clampedMaxY + 0.1),
        );
      },
    );
  }
}
