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
  static const saveKey = 'horologium.mining.save';

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
      'sectors',
    })) {
      throw const FormatException(
        'root keys must be exactly '
        'cash, lastAccruedAtUtc, technology, unlockedPlanetIds, '
        'activePlanetId, sectors',
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
    final sectors = _decodeSectors(raw['sectors'], logistics);

    if (!unlockedPlanetIds.contains(activePlanetId)) {
      throw const FormatException(
        'activePlanetId must be one of unlockedPlanetIds',
      );
    }
    if (!unlockedPlanetIds.contains(MiningPlanetId.homeworld)) {
      throw const FormatException('Homeworld must always be unlocked');
    }
    for (final planet in content.planets.values) {
      if (!unlockedPlanetIds.contains(planet.id) &&
          planet.sectors.any((definition) {
            final progress = sectors[definition.id]!;
            return progress.revealed || progress.mine != null;
          })) {
        throw FormatException(
          '${planet.name} sectors must be pristine while the planet is locked',
        );
      }
    }

    return MiningSave(
      cash: cash,
      lastAccruedAtUtc: timestamp,
      technology: technology,
      unlockedPlanetIds: unlockedPlanetIds,
      activePlanetId: activePlanetId,
      sectors: Map.unmodifiable(sectors),
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

  Map<MiningSectorId, SectorProgress> _decodeSectors(
    Object? raw,
    int logistics,
  ) {
    if (raw is! Map<String, Object?>) {
      throw const FormatException('sectors must be an object');
    }
    final expectedSectorKeys = MiningSectorId.values
        .map((id) => id.name)
        .toSet();
    if (!hasExactKeys(raw, expectedSectorKeys)) {
      throw const FormatException(
        'sector keys must be exactly the authored sector set',
      );
    }

    final sectors = <MiningSectorId, SectorProgress>{};
    for (final id in MiningSectorId.values) {
      final sectorRaw = raw[id.name];
      if (sectorRaw is! Map<String, Object?>) {
        throw FormatException('sector ${id.name} must be an object');
      }
      if (!hasExactKeys(sectorRaw, const {'revealed', 'mine'})) {
        throw FormatException(
          'sector ${id.name} keys must be exactly revealed, mine',
        );
      }
      final revealed = sectorRaw['revealed'];
      if (revealed is! bool) {
        throw FormatException('sector ${id.name} revealed must be a bool');
      }
      final mineRaw = sectorRaw['mine'];
      if (!revealed && mineRaw != null) {
        throw FormatException(
          'sector ${id.name} mine must be null while not revealed',
        );
      }
      sectors[id] = SectorProgress(
        revealed: revealed,
        mine: _decodeMine(id, mineRaw, logistics),
      );
    }
    return sectors;
  }

  MineState? _decodeMine(MiningSectorId sectorId, Object? raw, int logistics) {
    if (raw == null) {
      return null;
    }
    if (raw is! Map<String, Object?>) {
      throw const FormatException('mine must be null or an object');
    }
    if (!hasExactKeys(raw, const {'level', 'storedAmount'})) {
      throw const FormatException(
        'mine keys must be exactly level, storedAmount',
      );
    }

    final level = raw['level'];
    if (level is! int || level < 1 || level > 5) {
      throw const FormatException('mine level must be between 1 and 5');
    }

    final storedAmount = raw['storedAmount'];
    if (storedAmount is! num || storedAmount < 0) {
      throw const FormatException('storedAmount must be a non-negative number');
    }

    final capacity = content.effectiveCapacity(sectorId, level, logistics);
    return MineState(
      level: level,
      storedAmount: math.min(storedAmount.toDouble(), capacity),
    );
  }
}
