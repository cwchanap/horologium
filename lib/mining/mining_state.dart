import 'package:horologium/mining/mining_content.dart';

class TechnologyLevels {
  const TechnologyLevels({
    this.extraction = 0,
    this.logistics = 0,
    this.surveying = 0,
  });

  final int extraction;
  final int logistics;
  final int surveying;

  int levelFor(TechnologyTrack track) {
    switch (track) {
      case TechnologyTrack.extraction:
        return extraction;
      case TechnologyTrack.logistics:
        return logistics;
      case TechnologyTrack.surveying:
        return surveying;
    }
  }

  TechnologyLevels withLevel(TechnologyTrack track, int level) {
    switch (track) {
      case TechnologyTrack.extraction:
        return TechnologyLevels(
          extraction: level,
          logistics: logistics,
          surveying: surveying,
        );
      case TechnologyTrack.logistics:
        return TechnologyLevels(
          extraction: extraction,
          logistics: level,
          surveying: surveying,
        );
      case TechnologyTrack.surveying:
        return TechnologyLevels(
          extraction: extraction,
          logistics: logistics,
          surveying: level,
        );
    }
  }

  Map<String, Object?> toJson() => {
    'extraction': extraction,
    'logistics': logistics,
    'surveying': surveying,
  };

  @override
  bool operator ==(Object other) =>
      other is TechnologyLevels &&
      extraction == other.extraction &&
      logistics == other.logistics &&
      surveying == other.surveying;

  @override
  int get hashCode => Object.hash(extraction, logistics, surveying);
}

class MineState {
  const MineState({required this.level, required this.storedAmount});
  final int level;
  final double storedAmount;

  MineState copyWith({int? level, double? storedAmount}) => MineState(
    level: level ?? this.level,
    storedAmount: storedAmount ?? this.storedAmount,
  );

  Map<String, Object?> toJson() => {
    'level': level,
    'storedAmount': storedAmount,
  };

  @override
  bool operator ==(Object other) =>
      other is MineState &&
      level == other.level &&
      storedAmount == other.storedAmount;

  @override
  int get hashCode => Object.hash(level, storedAmount);
}

class SectorProgress {
  const SectorProgress({required this.revealed, this.mine});
  final bool revealed;
  final MineState? mine;

  SectorProgress copyWith({
    bool? revealed,
    MineState? mine,
    bool clearMine = false,
  }) => SectorProgress(
    revealed: revealed ?? this.revealed,
    mine: clearMine ? null : mine ?? this.mine,
  );

  Map<String, Object?> toJson() => {
    'revealed': revealed,
    'mine': mine?.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is SectorProgress &&
      revealed == other.revealed &&
      mine == other.mine;

  @override
  int get hashCode => Object.hash(revealed, mine);
}

class MiningSave {
  const MiningSave({
    required this.cash,
    required this.lastAccruedAtUtc,
    required this.technology,
    required this.unlockedPlanetIds,
    required this.activePlanetId,
    required this.sectors,
  });

  final int cash;
  final DateTime lastAccruedAtUtc;
  final TechnologyLevels technology;
  final Set<MiningPlanetId> unlockedPlanetIds;
  final MiningPlanetId activePlanetId;
  final Map<MiningSectorId, SectorProgress> sectors;

  factory MiningSave.initial({required DateTime nowUtc}) => MiningSave(
    cash: 100,
    lastAccruedAtUtc: nowUtc.toUtc(),
    technology: const TechnologyLevels(),
    unlockedPlanetIds: const {MiningPlanetId.homeworld},
    activePlanetId: MiningPlanetId.homeworld,
    sectors: Map.unmodifiable({
      for (final id in MiningSectorId.values)
        id: SectorProgress(revealed: id == MiningSectorId.landingBasin),
    }),
  );

  MiningSave copyWith({
    int? cash,
    DateTime? lastAccruedAtUtc,
    TechnologyLevels? technology,
    Set<MiningPlanetId>? unlockedPlanetIds,
    MiningPlanetId? activePlanetId,
    Map<MiningSectorId, SectorProgress>? sectors,
  }) => MiningSave(
    cash: cash ?? this.cash,
    lastAccruedAtUtc: lastAccruedAtUtc ?? this.lastAccruedAtUtc,
    technology: technology ?? this.technology,
    unlockedPlanetIds: Set.unmodifiable(
      unlockedPlanetIds ?? this.unlockedPlanetIds,
    ),
    activePlanetId: activePlanetId ?? this.activePlanetId,
    sectors: Map.unmodifiable(sectors ?? this.sectors),
  );

  Map<String, Object?> toJson() => {
    'cash': cash,
    'lastAccruedAtUtc': lastAccruedAtUtc.toUtc().toIso8601String(),
    'technology': technology.toJson(),
    'unlockedPlanetIds': MiningPlanetId.values
        .where(unlockedPlanetIds.contains)
        .map((id) => id.name)
        .toList(),
    'activePlanetId': activePlanetId.name,
    'sectors': sectors.map(
      (id, progress) => MapEntry(id.name, progress.toJson()),
    ),
  };

  @override
  bool operator ==(Object other) {
    if (other is! MiningSave ||
        cash != other.cash ||
        lastAccruedAtUtc != other.lastAccruedAtUtc ||
        technology != other.technology ||
        activePlanetId != other.activePlanetId ||
        unlockedPlanetIds.length != other.unlockedPlanetIds.length ||
        sectors.length != other.sectors.length) {
      return false;
    }
    if (!unlockedPlanetIds.containsAll(other.unlockedPlanetIds)) return false;
    for (final entry in sectors.entries) {
      if (other.sectors[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    cash,
    lastAccruedAtUtc,
    technology,
    activePlanetId,
    Object.hashAllUnordered(unlockedPlanetIds),
    Object.hashAllUnordered(
      sectors.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
  );
}
