import 'dart:convert';
import 'dart:math' as math;

import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MiningLoadResult {
  const MiningLoadResult({
    required this.state,
    required this.recoveredFromInvalidSave,
    required this.wasMissing,
  });
  final MiningSave state;
  final bool recoveredFromInvalidSave;

  /// True when no mining save key existed in preferences. The controller uses
  /// this to persist the freshly constructed initial state during
  /// initialization so a quick enter-and-back does not race the menu's
  /// save-presence check against the unawaited dispose checkpoint.
  final bool wasMissing;
}

bool hasExactKeys(Map<String, Object?> map, Set<String> expected) =>
    map.keys.toSet().length == expected.length &&
    map.keys.toSet().containsAll(expected);

class MiningSaveRepository {
  static const saveKey = 'horologium.mergeMining.save';

  MiningSaveRepository({MiningContentRegistry? content})
    : content = content ?? MiningContentRegistry.stellarMining();

  final MiningContentRegistry content;

  Future<bool> hasSave() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(saveKey);
  }

  Future<MiningLoadResult> load({required DateTime nowUtc}) async {
    final prefs = await SharedPreferences.getInstance();
    // Read the raw preference generically. SharedPreferences.getString casts
    // the cached value to String? and throws when a non-String (e.g. an int
    // left by a corrupted or migrated preference) is stored under the key.
    // hasSave() reports presence for any value type, so load() must route a
    // type mismatch through the recovery boundary rather than letting the cast
    // escape and brick initialization.
    final raw = prefs.get(saveKey);
    if (raw == null) {
      return MiningLoadResult(
        state: MiningSave.initial(nowUtc: nowUtc),
        recoveredFromInvalidSave: false,
        wasMissing: true,
      );
    }

    try {
      if (raw is! String) {
        throw const FormatException('mining save must be a JSON string');
      }
      return MiningLoadResult(
        state: _decode(jsonDecode(raw)),
        recoveredFromInvalidSave: false,
        wasMissing: false,
      );
    } catch (_) {
      return MiningLoadResult(
        state: MiningSave.initial(nowUtc: nowUtc),
        recoveredFromInvalidSave: true,
        wasMissing: false,
      );
    }
  }

  Future<void> save(MiningSave state) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(saveKey, jsonEncode(state.toJson()));
    if (!saved) {
      throw StateError('Mining save was rejected by SharedPreferences.');
    }
  }

  MiningSave _decode(Object? raw) {
    if (raw is! Map<String, Object?>) {
      throw const FormatException('root must be an object');
    }
    if (!hasExactKeys(raw, const {
      'cash',
      'lastAccruedAtUtc',
      'technology',
      'unlockedPlanetIds',
      'activePlanetId',
      'docks',
      'sites',
    })) {
      throw const FormatException(
        'root keys must be exactly '
        'cash, lastAccruedAtUtc, technology, unlockedPlanetIds, '
        'activePlanetId, docks, sites',
      );
    }

    final cash = raw['cash'];
    if (cash is! int || cash < 0) {
      throw const FormatException('cash must be a non-negative integer');
    }

    final timestampRaw = raw['lastAccruedAtUtc'];
    if (timestampRaw is! String) {
      throw const FormatException('lastAccruedAtUtc must be a string');
    }
    final timestamp = DateTime.tryParse(timestampRaw);
    if (timestamp == null || !timestamp.isUtc) {
      throw const FormatException('lastAccruedAtUtc must be a UTC timestamp');
    }

    final technology = _decodeTechnology(raw['technology']);
    final unlockedPlanetIds = Set.unmodifiable(
      _decodeUnlockedPlanets(raw['unlockedPlanetIds']),
    );
    final activePlanetId = _decodePlanetId(raw['activePlanetId']);
    final logistics = technology.levelFor(TechnologyTrack.logistics);
    final docks = _decodeDocks(raw['docks']);
    final sites = _decodeSites(raw['sites'], logistics);
    _validateInvariants(
      activePlanetId: activePlanetId,
      unlockedPlanetIds: unlockedPlanetIds,
      technology: technology,
      docks: docks,
      sites: sites,
    );

    return MiningSave(
      cash: cash,
      lastAccruedAtUtc: timestamp,
      technology: technology,
      unlockedPlanetIds: unlockedPlanetIds,
      activePlanetId: activePlanetId,
      docks: docks,
      sites: sites,
    );
  }

  TechnologyLevels _decodeTechnology(Object? raw) {
    if (raw is! Map<String, Object?>) {
      throw const FormatException('technology must be an object');
    }
    if (!hasExactKeys(raw, const {'extraction', 'logistics', 'surveying'})) {
      throw const FormatException(
        'technology keys must be exactly extraction, logistics, surveying',
      );
    }
    var extraction = 0;
    var logistics = 0;
    var surveying = 0;
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is! int ||
          value < 0 ||
          value > MiningContentRegistry.maxTechnologyLevel) {
        throw FormatException(
          'technology ${entry.key} must be an integer in '
          '0..${MiningContentRegistry.maxTechnologyLevel}',
        );
      }
      switch (entry.key) {
        case 'extraction':
          extraction = value;
        case 'logistics':
          logistics = value;
        case 'surveying':
          surveying = value;
      }
    }
    return TechnologyLevels(
      extraction: extraction,
      logistics: logistics,
      surveying: surveying,
    );
  }

  Set<MiningPlanetId> _decodeUnlockedPlanets(Object? raw) {
    if (raw is! List<Object?> || raw.isEmpty) {
      throw const FormatException('unlockedPlanetIds must be a non-empty list');
    }
    final ids = <MiningPlanetId>{};
    for (final item in raw) {
      final id = _decodePlanetId(item);
      if (!ids.add(id)) {
        throw const FormatException(
          'unlockedPlanetIds must not contain duplicates',
        );
      }
    }
    return ids;
  }

  MiningPlanetId _decodePlanetId(Object? raw) {
    if (raw is! String) {
      throw const FormatException('planet id must be a string');
    }
    final id = MiningPlanetId.values.asNameMap()[raw];
    if (id == null) {
      throw FormatException('unknown planet id $raw');
    }
    return id;
  }

  Map<MiningPlanetId, Map<DockBayId, RigTier?>> _decodeDocks(Object? raw) {
    if (raw is! Map<String, Object?>) {
      throw const FormatException('docks must be an object');
    }
    final expectedPlanetKeys = MiningPlanetId.values
        .map((id) => id.name)
        .toSet();
    if (!hasExactKeys(raw, expectedPlanetKeys)) {
      throw const FormatException(
        'dock keys must be exactly the authored planet set',
      );
    }

    final expectedBayKeys = DockBayId.values.map((id) => id.name).toSet();
    final docks = <MiningPlanetId, Map<DockBayId, RigTier?>>{};
    for (final planetId in MiningPlanetId.values) {
      final planetRaw = raw[planetId.name];
      if (planetRaw is! Map<String, Object?>) {
        throw FormatException('docks ${planetId.name} must be an object');
      }
      if (!hasExactKeys(planetRaw, expectedBayKeys)) {
        throw FormatException(
          'docks ${planetId.name} keys must be exactly b1, b2, b3, b4',
        );
      }
      docks[planetId] = Map.unmodifiable({
        for (final bayId in DockBayId.values)
          bayId: _decodeRigTier(planetRaw[bayId.name]),
      });
    }
    return docks;
  }

  Map<MiningSiteId, SiteProgress> _decodeSites(Object? raw, int logistics) {
    if (raw is! Map<String, Object?>) {
      throw const FormatException('sites must be an object');
    }
    final expectedSiteKeys = MiningSiteId.values.map((id) => id.name).toSet();
    if (!hasExactKeys(raw, expectedSiteKeys)) {
      throw const FormatException(
        'site keys must be exactly the authored site set',
      );
    }

    final sites = <MiningSiteId, SiteProgress>{};
    for (final id in MiningSiteId.values) {
      final siteRaw = raw[id.name];
      if (siteRaw is! Map<String, Object?>) {
        throw FormatException('site ${id.name} must be an object');
      }
      if (!hasExactKeys(siteRaw, const {
        'unlocked',
        'commissioned',
        'storedAmount',
        'rigByNode',
      })) {
        throw FormatException(
          'site ${id.name} keys must be exactly unlocked, commissioned, '
          'storedAmount, rigByNode',
        );
      }
      final unlocked = siteRaw['unlocked'];
      if (unlocked is! bool) {
        throw FormatException('site ${id.name} unlocked must be a bool');
      }
      final commissioned = siteRaw['commissioned'];
      if (commissioned is! bool) {
        throw FormatException('site ${id.name} commissioned must be a bool');
      }
      final storedAmount = siteRaw['storedAmount'];
      if (storedAmount is! num || !storedAmount.isFinite || storedAmount < 0) {
        throw FormatException(
          'site ${id.name} storedAmount must be a non-negative number',
        );
      }
      final rigByNode = _decodeRigByNode(siteRaw['rigByNode'], id);
      if (!unlocked &&
          (commissioned ||
              storedAmount != 0 ||
              rigByNode.values.any((tier) => tier != null))) {
        throw FormatException('locked site ${id.name} must be pristine');
      }

      final deployedRigs = rigByNode.values.whereType<RigTier>();
      final capacity = content.effectiveSiteCapacity(
        id,
        deployedRigs,
        logistics,
      );
      final normalizedStored = math.min(storedAmount.toDouble(), capacity);
      sites[id] = SiteProgress(
        unlocked: unlocked,
        commissioned: commissioned,
        storedAmount: normalizedStored,
        rigByNode: rigByNode,
      );
    }
    return sites;
  }

  Map<MiningNodeId, RigTier?> _decodeRigByNode(
    Object? raw,
    MiningSiteId siteId,
  ) {
    if (raw is! Map<String, Object?>) {
      throw FormatException('site ${siteId.name} rigByNode must be an object');
    }
    final expectedNodeKeys = MiningNodeId.values.map((id) => id.name).toSet();
    if (!hasExactKeys(raw, expectedNodeKeys)) {
      throw FormatException(
        'site ${siteId.name} node keys must be exactly n1, n2, n3, n4',
      );
    }
    return Map.unmodifiable({
      for (final nodeId in MiningNodeId.values)
        nodeId: _decodeRigTier(raw[nodeId.name]),
    });
  }

  RigTier? _decodeRigTier(Object? raw) {
    if (raw == null) {
      return null;
    }
    if (raw is! String) {
      throw const FormatException('rig tier must be null or a string');
    }
    final tier = RigTier.values.asNameMap()[raw];
    if (tier == null) {
      throw FormatException('unknown rig tier $raw');
    }
    return tier;
  }

  void _validateInvariants({
    required MiningPlanetId activePlanetId,
    required Set<MiningPlanetId> unlockedPlanetIds,
    required TechnologyLevels technology,
    required Map<MiningPlanetId, Map<DockBayId, RigTier?>> docks,
    required Map<MiningSiteId, SiteProgress> sites,
  }) {
    if (!unlockedPlanetIds.contains(activePlanetId)) {
      throw const FormatException(
        'activePlanetId must be one of unlockedPlanetIds',
      );
    }
    if (!unlockedPlanetIds.contains(MiningPlanetId.homeworld)) {
      throw const FormatException('Homeworld must always be unlocked');
    }

    for (final planet in content.planets.values) {
      final planetUnlocked = unlockedPlanetIds.contains(planet.id);
      final planetDocks = docks[planet.id]!;
      if (!planetUnlocked && planetDocks.values.any((tier) => tier != null)) {
        throw FormatException(
          '${planet.name} docks must be empty while the planet is locked',
        );
      }
      final firstSite = planet.sites.first;
      if (planetUnlocked && !sites[firstSite.id]!.unlocked) {
        throw FormatException(
          '${firstSite.name} must be unlocked with ${planet.name}',
        );
      }
      final requiredPlanet = planet.unlockRequiredMasteryPlanetId;
      if (planetUnlocked &&
          requiredPlanet != null &&
          !unlockedPlanetIds.contains(requiredPlanet)) {
        throw FormatException(
          '${planet.name} requires ${content.planet(requiredPlanet).name}',
        );
      }

      for (final definition in planet.sites) {
        final progress = sites[definition.id]!;
        if (!planetUnlocked &&
            (progress.unlocked ||
                progress.commissioned ||
                progress.storedAmount != 0 ||
                progress.rigByNode.values.any((tier) => tier != null))) {
          throw FormatException(
            '${planet.name} sites must be pristine while the planet is locked',
          );
        }
        if (progress.commissioned && !progress.unlocked) {
          throw FormatException(
            '${definition.name} cannot be commissioned while locked',
          );
        }
        final requiredSite = definition.requiredSite;
        if (progress.unlocked &&
            requiredSite != null &&
            !sites[requiredSite]!.unlocked) {
          throw FormatException(
            '${definition.name} requires ${content.site(requiredSite).name}',
          );
        }
        for (final node in definition.nodes) {
          final tier = progress.rigByNode[node.id];
          if (tier != null &&
              technology.surveying < node.requiredSurveyingLevel) {
            throw FormatException(
              '${definition.name} ${node.id.name} requires Surveying '
              '${node.requiredSurveyingLevel}',
            );
          }
        }
      }
    }
  }
}
