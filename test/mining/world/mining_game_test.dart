import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart' as flame_events;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
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
  testWidgets('all authored anchors are visible at initial 360x640 fit', (
    tester,
  ) async {
    final content = MiningContentRegistry.phaseOne();
    final game = MiningGame(content: content);
    await pumpMiningGame(tester, game);

    expect(game.worldSize.x, 1800);
    expect(game.worldSize.y, 1800);
    expect(game.camera.viewfinder.zoom, closeTo(0.2, 0.0001));

    for (final definition in content.sectors) {
      final screenX = 180 + definition.anchor.x * game.camera.viewfinder.zoom;
      final screenY = 320 + definition.anchor.y * game.camera.viewfinder.zoom;
      expect(screenX, inInclusiveRange(0, 360));
      expect(screenY, inInclusiveRange(0, 640));
    }
  });

  testWidgets('levels one three and five add distinct mounted structure', (
    tester,
  ) async {
    final content = MiningContentRegistry.phaseOne();
    final game = MiningGame(content: content);
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

  for (final viewport in const [Size(360, 640), Size(430, 932)]) {
    testWidgets(
      'selection focus places the sector above the sheet at $viewport',
      (tester) async {
        final content = MiningContentRegistry.phaseOne();
        final game = MiningGame(content: content)..reducedMotion = true;
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
