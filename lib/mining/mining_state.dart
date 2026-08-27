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

class SiteProgress {
  const SiteProgress({
    required this.unlocked,
    required this.commissioned,
    required this.storedAmount,
    required this.rigByNode,
  });

  final bool unlocked;
  final bool commissioned;
  final double storedAmount;
  final Map<MiningNodeId, RigTier?> rigByNode;

  SiteProgress copyWith({
    bool? unlocked,
    bool? commissioned,
    double? storedAmount,
    Map<MiningNodeId, RigTier?>? rigByNode,
  }) => SiteProgress(
    unlocked: unlocked ?? this.unlocked,
    commissioned: commissioned ?? this.commissioned,
    storedAmount: storedAmount ?? this.storedAmount,
    rigByNode: Map<MiningNodeId, RigTier?>.unmodifiable(
      rigByNode ?? this.rigByNode,
    ),
  );

  Map<String, Object?> toJson() => {
    'unlocked': unlocked,
    'commissioned': commissioned,
    'storedAmount': storedAmount,
    'rigByNode': rigByNode.map((id, tier) => MapEntry(id.name, tier?.name)),
  };

  @override
  bool operator ==(Object other) =>
      other is SiteProgress &&
      unlocked == other.unlocked &&
      commissioned == other.commissioned &&
      storedAmount == other.storedAmount &&
      _mapsEqual(rigByNode, other.rigByNode);

  @override
  int get hashCode => Object.hash(
    unlocked,
    commissioned,
    storedAmount,
    Object.hashAllUnordered(
      rigByNode.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
  );
}

class MiningSave {
  MiningSave({
    required this.cash,
    required this.lastAccruedAtUtc,
    required this.technology,
    required Set<MiningPlanetId> unlockedPlanetIds,
    required this.activePlanetId,
    required Map<MiningPlanetId, Map<DockBayId, RigTier?>> docks,
    required Map<MiningSiteId, SiteProgress> sites,
  }) : unlockedPlanetIds = Set.unmodifiable(unlockedPlanetIds),
       docks = _copyDocks(docks),
       sites = _copySites(sites);

  final int cash;
  final DateTime lastAccruedAtUtc;
  final TechnologyLevels technology;
  final Set<MiningPlanetId> unlockedPlanetIds;
  final MiningPlanetId activePlanetId;
  final Map<MiningPlanetId, Map<DockBayId, RigTier?>> docks;
  final Map<MiningSiteId, SiteProgress> sites;

  factory MiningSave.initial({required DateTime nowUtc}) => MiningSave(
    cash: 100,
    lastAccruedAtUtc: nowUtc.toUtc(),
    technology: const TechnologyLevels(),
    unlockedPlanetIds: const {MiningPlanetId.homeworld},
    activePlanetId: MiningPlanetId.homeworld,
    docks: {
      for (final planet in MiningPlanetId.values)
        planet: {
          for (final bay in DockBayId.values)
            bay:
                planet == MiningPlanetId.homeworld &&
                    (bay == DockBayId.b1 || bay == DockBayId.b2)
                ? RigTier.t1
                : null,
        },
    },
    sites: {
      for (final id in MiningSiteId.values)
        id: SiteProgress(
          unlocked: id == MiningSiteId.landingBasin,
          commissioned: false,
          storedAmount: 0,
          rigByNode: {for (final node in MiningNodeId.values) node: null},
        ),
    },
  );

  MiningSave copyWith({
    int? cash,
    DateTime? lastAccruedAtUtc,
    TechnologyLevels? technology,
    Set<MiningPlanetId>? unlockedPlanetIds,
    MiningPlanetId? activePlanetId,
    Map<MiningPlanetId, Map<DockBayId, RigTier?>>? docks,
    Map<MiningSiteId, SiteProgress>? sites,
  }) => MiningSave(
    cash: cash ?? this.cash,
    lastAccruedAtUtc: lastAccruedAtUtc ?? this.lastAccruedAtUtc,
    technology: technology ?? this.technology,
    unlockedPlanetIds: unlockedPlanetIds ?? this.unlockedPlanetIds,
    activePlanetId: activePlanetId ?? this.activePlanetId,
    docks: docks ?? this.docks,
    sites: sites ?? this.sites,
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
    'docks': docks.map(
      (planetId, bays) => MapEntry(
        planetId.name,
        bays.map((bayId, tier) => MapEntry(bayId.name, tier?.name)),
      ),
    ),
    'sites': sites.map(
      (siteId, progress) => MapEntry(siteId.name, progress.toJson()),
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
        docks.length != other.docks.length ||
        sites.length != other.sites.length) {
      return false;
    }
    if (!unlockedPlanetIds.containsAll(other.unlockedPlanetIds) ||
        !_nestedMapsEqual(docks, other.docks) ||
        !_mapsEqual(sites, other.sites)) {
      return false;
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
      docks.entries.map(
        (entry) => Object.hash(
          entry.key,
          Object.hashAllUnordered(
            entry.value.entries.map((bay) => Object.hash(bay.key, bay.value)),
          ),
        ),
      ),
    ),
    Object.hashAllUnordered(
      sites.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
  );
}

Map<MiningPlanetId, Map<DockBayId, RigTier?>> _copyDocks(
  Map<MiningPlanetId, Map<DockBayId, RigTier?>> source,
) => Map<MiningPlanetId, Map<DockBayId, RigTier?>>.unmodifiable({
  for (final entry in source.entries)
    entry.key: Map<DockBayId, RigTier?>.unmodifiable(entry.value),
});

Map<MiningSiteId, SiteProgress> _copySites(
  Map<MiningSiteId, SiteProgress> source,
) => Map<MiningSiteId, SiteProgress>.unmodifiable({
  for (final entry in source.entries)
    entry.key: SiteProgress(
      unlocked: entry.value.unlocked,
      commissioned: entry.value.commissioned,
      storedAmount: entry.value.storedAmount,
      rigByNode: Map<MiningNodeId, RigTier?>.unmodifiable(
        entry.value.rigByNode,
      ),
    ),
});

bool _mapsEqual<K, V>(Map<K, V> first, Map<K, V> second) {
  if (first.length != second.length) return false;
  for (final entry in first.entries) {
    if (!second.containsKey(entry.key) || second[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}

bool _nestedMapsEqual<K, L, V>(
  Map<K, Map<L, V>> first,
  Map<K, Map<L, V>> second,
) {
  if (first.length != second.length) return false;
  for (final entry in first.entries) {
    final other = second[entry.key];
    if (other == null || !_mapsEqual(entry.value, other)) return false;
  }
  return true;
}
