import 'package:flame/game.dart';
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

    game.applyState(withGoldLevel(1));
    await tester.pump();
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

    game.applyState(withGoldLevel(5));
    await tester.pump();
    expect(sector.children.whereType<EliteRingComponent>(), hasLength(1));
  });

  testWidgets(
    'selection focus shifts upward and stays clamped inside world bounds',
    (tester) async {
      final content = MiningContentRegistry.phaseOne();
      final game = MiningGame(content: content)..reducedMotion = true;
      await pumpMiningGame(tester, game);

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

      game.camera.viewfinder.zoom = 0.5;
      final viewportHeight = game.camera.viewport.size.y;
      final halfViewHeight = viewportHeight / game.camera.viewfinder.zoom / 2;
      final minY = -MiningContentRegistry.worldHalfExtent + halfViewHeight;
      final maxY = MiningContentRegistry.worldHalfExtent - halfViewHeight;

      game.focusOnSelection(
        sectorId: MiningSectorId.landingBasin,
        bottomObscuredFraction: 0.25,
      );
      await tester.pump();

      final landingY = content.sector(MiningSectorId.landingBasin).anchor.y;
      expect(game.camera.viewfinder.position.y, lessThan(landingY));
      expect(game.camera.viewfinder.position.y, inInclusiveRange(minY, maxY));

      game.focusOnSelection(
        sectorId: MiningSectorId.graniteCrater,
        bottomObscuredFraction: 0.9,
      );
      await tester.pump();

      expect(game.camera.viewfinder.position.y, minY);
      expect(game.camera.viewfinder.position.y, inInclusiveRange(minY, maxY));
    },
  );
}
