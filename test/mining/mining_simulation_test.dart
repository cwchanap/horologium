import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_simulation.dart';
import 'package:horologium/mining/mining_state.dart';

MiningSave goldState(DateTime now, {double stored = 0, int level = 1}) {
  final base = MiningSave.initial(nowUtc: now);
  return base.copyWith(
    sectors: {
      ...base.sectors,
      MiningSectorId.landingBasin: SectorProgress(
        revealed: true,
        mine: MineState(level: level, storedAmount: stored),
      ),
    },
  );
}

void main() {
  final content = MiningContentRegistry.stellarMining();
  final simulation = MiningSimulation(content);
  final start = DateTime.utc(2026, 8, 18, 12);

  test('level one gold produces five units in ten seconds', () {
    final result = simulation.accrue(
      goldState(start),
      start.add(const Duration(seconds: 10)),
    );
    expect(
      result.state.sectors[MiningSectorId.landingBasin]!.mine!.storedAmount,
      closeTo(5, 0.0001),
    );
  });

  test('storage caps production', () {
    final result = simulation.accrue(
      goldState(start, stored: 89),
      start.add(const Duration(minutes: 1)),
    );
    expect(
      result.state.sectors[MiningSectorId.landingBasin]!.mine!.storedAmount,
      90,
    );
  });

  test('clock rollback produces zero and does not move time backward', () {
    final state = goldState(start, stored: 10);
    final result = simulation.accrue(
      state,
      start.subtract(const Duration(minutes: 1)),
    );
    expect(result.state.toJson(), state.toJson());
    expect(result.summary.totalProduced, 0);
  });

  test('twelve hours uses at most the eight hour cap', () {
    final result = simulation.accrue(
      goldState(start),
      start.add(const Duration(hours: 12)),
    );
    expect(result.summary.elapsedUsed, const Duration(hours: 8));
    expect(result.summary.wasOfflineCapped, isTrue);
  });

  test('identical inputs and clock produce identical results', () {
    final state = goldState(start, stored: 10);
    final now = start.add(const Duration(hours: 1));
    final first = simulation.accrue(state, now);
    final second = simulation.accrue(state, now);
    expect(first.state.toJson(), second.state.toJson());
    expect(first.summary.elapsedUsed, second.summary.elapsedUsed);
    expect(first.summary.totalProduced, second.summary.totalProduced);
    expect(first.summary.fullSectors, second.summary.fullSectors);
    expect(first.summary.wasOfflineCapped, second.summary.wasOfflineCapped);
    expect(first.summary.produced, second.summary.produced);
  });
}
