import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_state.dart';

void main() {
  test('technology levels access and replace one exhaustive track', () {
    const levels = TechnologyLevels(extraction: 1, logistics: 2, surveying: 3);

    expect(levels.levelFor(TechnologyTrack.extraction), 1);
    expect(levels.levelFor(TechnologyTrack.logistics), 2);
    expect(levels.levelFor(TechnologyTrack.surveying), 3);
    expect(
      levels.withLevel(TechnologyTrack.extraction, 4),
      const TechnologyLevels(extraction: 4, logistics: 2, surveying: 3),
    );
  });

  test('initial save contains the flat nine-sector current state', () {
    final now = DateTime.utc(2026, 8, 18, 12);
    final state = MiningSave.initial(nowUtc: now);

    expect(state.sectors.keys.toSet(), MiningSectorId.values.toSet());
    expect(state.sectors.length, 9);
    expect(state.technology, const TechnologyLevels());
    expect(state.unlockedPlanetIds, {MiningPlanetId.homeworld});
    expect(state.activePlanetId, MiningPlanetId.homeworld);
    expect(
      state.sectors[MiningSectorId.landingBasin],
      const SectorProgress(revealed: true),
    );
    expect(
      state.sectors.entries
          .where((entry) => entry.key != MiningSectorId.landingBasin)
          .every((entry) => !entry.value.revealed && entry.value.mine == null),
      isTrue,
    );
    expect(state.toJson().keys.toSet(), {
      'cash',
      'lastAccruedAtUtc',
      'technology',
      'unlockedPlanetIds',
      'activePlanetId',
      'sectors',
    });
  });

  test('initial save sectors cannot be mutated', () {
    final state = MiningSave.initial(nowUtc: DateTime.utc(2026, 8, 18, 12));

    expect(
      () => state.sectors[MiningSectorId.landingBasin] = const SectorProgress(
        revealed: false,
      ),
      throwsUnsupportedError,
    );
  });
}
