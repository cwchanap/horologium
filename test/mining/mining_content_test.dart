import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/constants/assets_path.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_state.dart';

void main() {
  test('phase one reuses existing resource and mine identities', () {
    final content = MiningContentRegistry.phaseOne();

    expect(content.sectors.map((s) => s.id), MiningSectorId.values);
    expect(
      content.sector(MiningSectorId.landingBasin).resource,
      ResourceType.gold,
    );
    expect(
      content.sector(MiningSectorId.landingBasin).mineAsset,
      Assets.goldMine,
    );
    expect(
      content.sector(MiningSectorId.carbonRidge).resource,
      ResourceType.coal,
    );
    expect(
      content.sector(MiningSectorId.carbonRidge).mineAsset,
      Assets.coalMine,
    );
    expect(
      content.sector(MiningSectorId.graniteCrater).resource,
      ResourceType.stone,
    );
    expect(
      content.sector(MiningSectorId.graniteCrater).mineAsset,
      Assets.quarry,
    );
  });

  test('world units are explicit and every authored anchor is in bounds', () {
    final content = MiningContentRegistry.phaseOne();
    expect(MiningContentRegistry.terrainGridSize, 36);
    expect(MiningContentRegistry.terrainCellSize, 50);
    expect(MiningContentRegistry.worldExtent, 1800);
    expect(MiningContentRegistry.worldHalfExtent, 900);

    for (final sector in content.sectors) {
      expect(sector.anchor.x, inInclusiveRange(-900, 900));
      expect(sector.anchor.y, inInclusiveRange(-900, 900));
    }
  });

  test('clean mining state reveals only Landing Basin', () {
    final now = DateTime.utc(2026, 8, 18, 12);
    final state = MiningSave.initial(nowUtc: now);

    expect(state.cash, 100);
    expect(state.lastAccruedAtUtc, now);
    expect(state.sectors.keys.toSet(), MiningSectorId.values.toSet());
    expect(state.sectors[MiningSectorId.landingBasin]!.revealed, isTrue);
    expect(state.sectors[MiningSectorId.carbonRidge]!.revealed, isFalse);
    expect(state.sectors[MiningSectorId.graniteCrater]!.revealed, isFalse);
    expect(state.sectors.values.every((p) => p.mine == null), isTrue);
  });
}
