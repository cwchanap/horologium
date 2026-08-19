import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_state.dart';

class OfflineProductionSummary {
  const OfflineProductionSummary({
    required this.elapsedUsed,
    required this.produced,
    required this.fullSectors,
    required this.wasOfflineCapped,
  });

  final Duration elapsedUsed;
  final Map<ResourceType, double> produced;
  final Set<MiningSectorId> fullSectors;
  final bool wasOfflineCapped;

  double get totalProduced =>
      produced.values.fold(0, (sum, value) => sum + value);
}

class AccrualResult {
  const AccrualResult({required this.state, required this.summary});
  final MiningSave state;
  final OfflineProductionSummary summary;
}

class MiningSimulation {
  const MiningSimulation(this.content);
  final MiningContentRegistry content;

  AccrualResult accrue(MiningSave state, DateTime nowUtc) {
    final now = nowUtc.toUtc();
    final rawElapsed = now.difference(state.lastAccruedAtUtc);
    if (rawElapsed <= Duration.zero) {
      return AccrualResult(
        state: state,
        summary: const OfflineProductionSummary(
          elapsedUsed: Duration.zero,
          produced: {},
          fullSectors: {},
          wasOfflineCapped: false,
        ),
      );
    }

    final elapsed = rawElapsed > MiningContentRegistry.offlineCap
        ? MiningContentRegistry.offlineCap
        : rawElapsed;
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final produced = <ResourceType, double>{};
    final full = <MiningSectorId>{};
    final sectors = <MiningSectorId, SectorProgress>{...state.sectors};

    for (final definition in content.sectors) {
      final progress = sectors[definition.id]!;
      final mine = progress.mine;
      if (!progress.revealed || mine == null) continue;

      final capacity = content.capacityFor(definition.id, mine.level);
      final remaining = (capacity - mine.storedAmount).clamp(0.0, capacity);
      final amount = (content.rateFor(definition.id, mine.level) * seconds)
          .clamp(0.0, remaining);
      final stored = mine.storedAmount + amount;
      sectors[definition.id] = progress.copyWith(
        mine: mine.copyWith(storedAmount: stored),
      );
      produced.update(
        definition.resource,
        (value) => value + amount,
        ifAbsent: () => amount,
      );
      if (stored >= capacity) full.add(definition.id);
    }

    return AccrualResult(
      state: state.copyWith(lastAccruedAtUtc: now, sectors: sectors),
      summary: OfflineProductionSummary(
        elapsedUsed: elapsed,
        produced: Map.unmodifiable(produced),
        fullSectors: Set.unmodifiable(full),
        wasOfflineCapped: rawElapsed > MiningContentRegistry.offlineCap,
      ),
    );
  }
}
