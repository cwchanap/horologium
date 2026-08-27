import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_state.dart';

class OfflineProductionSummary {
  const OfflineProductionSummary({
    required this.elapsedUsed,
    required this.produced,
    required this.productionByPlanet,
    required this.fullSites,
    required this.wasOfflineCapped,
  });

  final Duration elapsedUsed;
  final Map<ResourceType, double> produced;
  final Map<MiningPlanetId, Map<ResourceType, double>> productionByPlanet;
  final Set<MiningSiteId> fullSites;
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
          productionByPlanet: {},
          fullSites: {},
          wasOfflineCapped: false,
        ),
      );
    }

    final offlineCap = content.offlineCapFor(state.technology.logistics);
    final elapsed = rawElapsed > offlineCap ? offlineCap : rawElapsed;
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final produced = <ResourceType, double>{};
    final producedByPlanet = <MiningPlanetId, Map<ResourceType, double>>{};
    final full = <MiningSiteId>{};
    final sites = <MiningSiteId, SiteProgress>{...state.sites};

    for (final entry in content.planets.entries) {
      if (!state.unlockedPlanetIds.contains(entry.key)) continue;
      final planetId = entry.key;
      for (final definition in content.planet(planetId).sites) {
        final progress = sites[definition.id]!;
        final deployedRigs = progress.rigByNode.values
            .whereType<RigTier>()
            .toList();
        if (!progress.unlocked || deployedRigs.isEmpty) continue;

        final rate = content.effectiveSiteRate(
          definition.id,
          deployedRigs,
          state.technology.extraction,
        );
        final capacity = content.effectiveSiteCapacity(
          definition.id,
          deployedRigs,
          state.technology.logistics,
        );
        final remaining = (capacity - progress.storedAmount)
            .clamp(0.0, capacity)
            .toDouble();
        final amount = (rate * seconds).clamp(0.0, remaining).toDouble();
        final stored = progress.storedAmount + amount;
        sites[definition.id] = progress.copyWith(storedAmount: stored);
        produced.update(
          definition.resource,
          (value) => value + amount,
          ifAbsent: () => amount,
        );
        producedByPlanet
            .putIfAbsent(planetId, () => <ResourceType, double>{})
            .update(
              definition.resource,
              (value) => value + amount,
              ifAbsent: () => amount,
            );
        if (stored >= capacity) full.add(definition.id);
      }
    }

    return AccrualResult(
      state: state.copyWith(lastAccruedAtUtc: now, sites: sites),
      summary: OfflineProductionSummary(
        elapsedUsed: elapsed,
        produced: Map.unmodifiable(produced),
        productionByPlanet:
            Map.unmodifiable(<MiningPlanetId, Map<ResourceType, double>>{
              for (final entry in producedByPlanet.entries)
                entry.key: Map.unmodifiable(entry.value),
            }),
        fullSites: Set.unmodifiable(full),
        wasOfflineCapped: rawElapsed > offlineCap,
      ),
    );
  }
}
