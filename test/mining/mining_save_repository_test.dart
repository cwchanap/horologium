import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_grid.dart';
import 'package:horologium/mining/mining_save_repository.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

MiningSave _progressedState(DateTime now) {
  final initial = MiningSave.initial(nowUtc: now);
  final docks = <MiningPlanetId, Map<DockBayId, RigTier?>>{
    for (final entry in initial.docks.entries)
      entry.key: Map<DockBayId, RigTier?>.from(entry.value),
  };
  final sites = <MiningSiteId, SiteProgress>{
    for (final entry in initial.sites.entries)
      entry.key: entry.value.copyWith(
        rigPlacements: entry.value.rigPlacements.toList(),
      ),
  };

  docks[MiningPlanetId.homeworld]![DockBayId.b1] = RigTier.t3;
  docks[MiningPlanetId.homeworld]![DockBayId.b2] = null;
  docks[MiningPlanetId.lunarFrontier]![DockBayId.b1] = RigTier.t1;
  docks[MiningPlanetId.lunarFrontier]![DockBayId.b2] = RigTier.t2;

  sites[MiningSiteId.landingBasin] = sites[MiningSiteId.landingBasin]!.copyWith(
    commissioned: true,
    storedAmount: 80,
    rigPlacements: [
      MiningRigPlacement(tier: RigTier.t1, cell: const MiningGridCell(3, 2)),
    ],
  );
  sites[MiningSiteId.carbonRidge] = sites[MiningSiteId.carbonRidge]!.copyWith(
    unlocked: true,
    commissioned: true,
    storedAmount: 40,
    rigPlacements: [
      MiningRigPlacement(tier: RigTier.t1, cell: const MiningGridCell(5, 1)),
    ],
  );
  sites[MiningSiteId.frozenBasin] = sites[MiningSiteId.frozenBasin]!.copyWith(
    unlocked: true,
    commissioned: true,
    storedAmount: 60,
    rigPlacements: [
      MiningRigPlacement(tier: RigTier.t2, cell: const MiningGridCell(4, 2)),
    ],
  );

  return initial.copyWith(
    cash: 4321,
    lastAccruedAtUtc: now,
    technology: const TechnologyLevels(
      extraction: 2,
      logistics: 1,
      surveying: 3,
    ),
    unlockedPlanetIds: const {
      MiningPlanetId.homeworld,
      MiningPlanetId.lunarFrontier,
    },
    activePlanetId: MiningPlanetId.lunarFrontier,
    docks: docks,
    sites: sites,
  );
}

Map<String, Object?> _rawDocument({MiningSave? state, DateTime? nowUtc}) =>
    Map<String, Object?>.from(
      (state ?? MiningSave.initial(nowUtc: nowUtc ?? DateTime.utc(2026, 8, 27)))
          .toJson(),
    );

void main() {
  final now = DateTime.utc(2026, 8, 27, 12);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('hasSave presence', () {
    test('empty preferences report no mining save', () async {
      expect(await MiningSaveRepository().hasSave(), isFalse);
    });

    test('presence ignores retired mining key', () async {
      SharedPreferences.setMockInitialValues({'horologium.mining.save': '{}'});
      final repository = MiningSaveRepository();

      expect(MiningSaveRepository.saveKey, 'horologium.mergeMining.save');
      expect(await repository.hasSave(), isFalse);
    });

    test('presence of a valid merge-mining document reports a save', () async {
      SharedPreferences.setMockInitialValues({
        MiningSaveRepository.saveKey: jsonEncode(_rawDocument(nowUtc: now)),
      });

      expect(await MiningSaveRepository().hasSave(), isTrue);
    });

    test(
      'presence of a malformed merge-mining document still reports a save',
      () async {
        SharedPreferences.setMockInitialValues({
          MiningSaveRepository.saveKey: '{ malformed mining json',
        });

        expect(await MiningSaveRepository().hasSave(), isTrue);
      },
    );

    test('legacy city keys do not count as a mining save', () async {
      SharedPreferences.setMockInitialValues({
        'cash': 999999.0,
        'planet.earth.resources.cash': 888888.0,
        'buildings': <String>['1,1,Gold Mine'],
      });

      expect(await MiningSaveRepository().hasSave(), isFalse);
    });
  });

  group('load', () {
    test('missing save returns clean state without recovery warning', () async {
      final result = await MiningSaveRepository().load(nowUtc: now);

      expect(result.state, MiningSave.initial(nowUtc: now));
      expect(result.recoveredFromInvalidSave, isFalse);
      expect(result.wasMissing, isTrue);
    });

    test('round-trips enum-keyed docks and flat sites', () async {
      final repository = MiningSaveRepository();
      final expected = _progressedState(now);

      await repository.save(expected);
      final loaded = await repository.load(nowUtc: now);

      expect(loaded.state, expected);
      expect(loaded.recoveredFromInvalidSave, isFalse);
      expect(loaded.wasMissing, isFalse);
    });

    test('current save root has exactly the current keys', () async {
      final repository = MiningSaveRepository();
      await repository.save(MiningSave.initial(nowUtc: now));

      final prefs = await SharedPreferences.getInstance();
      final decoded =
          jsonDecode(prefs.getString(MiningSaveRepository.saveKey)!)
              as Map<String, Object?>;

      expect(decoded.keys.toSet(), {
        'cash',
        'lastAccruedAtUtc',
        'technology',
        'unlockedPlanetIds',
        'activePlanetId',
        'docks',
        'sites',
      });
    });

    test('retired sector schema resets through recovery', () async {
      final raw = _rawDocument(nowUtc: now)
        ..remove('docks')
        ..remove('sites')
        ..['sectors'] = <String, Object?>{};
      SharedPreferences.setMockInitialValues({
        MiningSaveRepository.saveKey: jsonEncode(raw),
      });

      final result = await MiningSaveRepository().load(nowUtc: now);

      expect(result.recoveredFromInvalidSave, isTrue);
      expect(result.wasMissing, isFalse);
      expect(result.state, MiningSave.initial(nowUtc: now));
    });

    test('malformed JSON resets and reports recovery', () async {
      SharedPreferences.setMockInitialValues({
        MiningSaveRepository.saveKey: '{not-json',
      });

      final result = await MiningSaveRepository().load(nowUtc: now);

      expect(result.state, MiningSave.initial(nowUtc: now));
      expect(result.recoveredFromInvalidSave, isTrue);
      expect(result.wasMissing, isFalse);
    });

    test('non-String preference value resets and reports recovery', () async {
      SharedPreferences.setMockInitialValues({
        MiningSaveRepository.saveKey: 123,
      });
      final repository = MiningSaveRepository();

      expect(await repository.hasSave(), isTrue);
      final result = await repository.load(nowUtc: now);

      expect(result.state, MiningSave.initial(nowUtc: now));
      expect(result.recoveredFromInvalidSave, isTrue);
      expect(result.wasMissing, isFalse);
    });

    test('legacy city keys are ignored', () async {
      SharedPreferences.setMockInitialValues({
        'cash': 999999.0,
        'planet.earth.resources.cash': 888888.0,
        'buildings': <String>['1,1,Gold Mine'],
      });

      final result = await MiningSaveRepository().load(nowUtc: now);

      expect(result.state, MiningSave.initial(nowUtc: now));
      expect(result.wasMissing, isTrue);
    });

    test('decoded nested maps are unmodifiable', () async {
      SharedPreferences.setMockInitialValues({
        MiningSaveRepository.saveKey: jsonEncode(_rawDocument(nowUtc: now)),
      });

      final result = await MiningSaveRepository().load(nowUtc: now);

      expect(
        () => result.state.unlockedPlanetIds.add(MiningPlanetId.lunarFrontier),
        throwsUnsupportedError,
      );
      expect(
        () =>
            result.state.docks[MiningPlanetId.homeworld]![DockBayId.b1] = null,
        throwsUnsupportedError,
      );
      expect(
        () => result.state.sites[MiningSiteId.landingBasin]!.rigPlacements.add(
          MiningRigPlacement(
            tier: RigTier.t1,
            cell: const MiningGridCell(3, 2),
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });

  group('capacity normalization', () {
    test('one deployed T1 cargo above 90 clamps without recovery', () async {
      final initial = MiningSave.initial(nowUtc: now);
      final state = initial.copyWith(
        technology: const TechnologyLevels(surveying: 3),
        sites: {
          ...initial.sites,
          MiningSiteId.landingBasin: initial.sites[MiningSiteId.landingBasin]!
              .copyWith(
                commissioned: true,
                storedAmount: 120,
                rigPlacements: [
                  MiningRigPlacement(
                    tier: RigTier.t1,
                    cell: const MiningGridCell(3, 2),
                  ),
                ],
              ),
        },
      );
      SharedPreferences.setMockInitialValues({
        MiningSaveRepository.saveKey: jsonEncode(state.toJson()),
      });

      final result = await MiningSaveRepository().load(nowUtc: now);

      expect(result.recoveredFromInvalidSave, isFalse);
      expect(result.state.sites[MiningSiteId.landingBasin]!.storedAmount, 90);
    });

    test('four deployed T1 rigs preserve cargo below 360', () async {
      final initial = MiningSave.initial(nowUtc: now);
      final state = initial.copyWith(
        technology: const TechnologyLevels(surveying: 3),
        sites: {
          ...initial.sites,
          MiningSiteId.landingBasin: initial.sites[MiningSiteId.landingBasin]!
              .copyWith(
                commissioned: true,
                storedAmount: 359,
                rigPlacements: [
                  const MiningRigPlacement(
                    tier: RigTier.t1,
                    cell: MiningGridCell(3, 2),
                  ),
                  MiningRigPlacement(
                    tier: RigTier.t1,
                    cell: const MiningGridCell(16, 2),
                  ),
                  MiningRigPlacement(
                    tier: RigTier.t1,
                    cell: const MiningGridCell(5, 10),
                  ),
                  MiningRigPlacement(
                    tier: RigTier.t1,
                    cell: const MiningGridCell(16, 9),
                  ),
                ],
              ),
        },
      );
      SharedPreferences.setMockInitialValues({
        MiningSaveRepository.saveKey: jsonEncode(state.toJson()),
      });

      final result = await MiningSaveRepository().load(nowUtc: now);

      expect(result.recoveredFromInvalidSave, isFalse);
      expect(result.state.sites[MiningSiteId.landingBasin]!.storedAmount, 359);
    });
  });

  group('invalid saves reset to initial with recovery flag', () {
    Future<void> expectRecovered(Map<String, Object?> raw) async {
      SharedPreferences.setMockInitialValues({
        MiningSaveRepository.saveKey: jsonEncode(raw),
      });

      final result = await MiningSaveRepository().load(nowUtc: now);

      expect(result.state, MiningSave.initial(nowUtc: now));
      expect(result.recoveredFromInvalidSave, isTrue);
      expect(result.wasMissing, isFalse);
    }

    test('root keys must be exact', () async {
      final missing = _rawDocument(nowUtc: now)..remove('sites');
      await expectRecovered(missing);

      final extra = _rawDocument(nowUtc: now)..['extra'] = true;
      await expectRecovered(extra);
    });

    test('docks must use exact planet and bay enum names', () async {
      final missingPlanet = _rawDocument(nowUtc: now);
      (missingPlanet['docks']! as Map<String, Object?>).remove('marsFrontier');
      await expectRecovered(missingPlanet);

      final extraPlanet = _rawDocument(nowUtc: now);
      final extraPlanetDocks = Map<String, Object?>.from(
        extraPlanet['docks']! as Map<String, Object?>,
      );
      extraPlanetDocks['venus'] = <String, Object?>{};
      extraPlanet['docks'] = extraPlanetDocks;
      await expectRecovered(extraPlanet);

      final missingBay = _rawDocument(nowUtc: now);
      final missingBayHomeworld =
          (missingBay['docks']! as Map<String, Object?>)['homeworld']!
              as Map<String, Object?>;
      missingBayHomeworld.remove('b4');
      await expectRecovered(missingBay);

      final extraBay = _rawDocument(nowUtc: now);
      ((extraBay['docks']! as Map<String, Object?>)['homeworld']!
              as Map<String, Object?>)['b5'] =
          null;
      await expectRecovered(extraBay);

      final invalidDockTier = _rawDocument(nowUtc: now);
      ((invalidDockTier['docks']! as Map<String, Object?>)['homeworld']!
              as Map<String, Object?>)['b1'] =
          't6';
      await expectRecovered(invalidDockTier);
    });

    test(
      'sites use exact site enum names and strict placement entries',
      () async {
        final missingSite = _rawDocument(nowUtc: now);
        (missingSite['sites']! as Map<String, Object?>).remove('cobaltChasm');
        await expectRecovered(missingSite);

        final extraSite = _rawDocument(nowUtc: now);
        (extraSite['sites']! as Map<String, Object?>)['venus'] =
            <String, Object?>{};
        await expectRecovered(extraSite);

        final missingField = _rawDocument(nowUtc: now);
        ((missingField['sites']! as Map<String, Object?>)['landingBasin']!
                as Map<String, Object?>)
            .remove('commissioned');
        await expectRecovered(missingField);

        final extraField = _rawDocument(nowUtc: now);
        ((extraField['sites']! as Map<String, Object?>)['landingBasin']!
                as Map<String, Object?>)['extra'] =
            true;
        await expectRecovered(extraField);

        final missingPlacements = _rawDocument(nowUtc: now);
        ((missingPlacements['sites']! as Map<String, Object?>)['landingBasin']!
                as Map<String, Object?>)
            .remove('rigPlacements');
        await expectRecovered(missingPlacements);

        final nonListPlacements = _rawDocument(nowUtc: now);
        ((nonListPlacements['sites']! as Map<String, Object?>)['landingBasin']!
                as Map<String, Object?>)['rigPlacements'] =
            {};
        await expectRecovered(nonListPlacements);

        final extraPlacementField = _rawDocument(nowUtc: now);
        ((extraPlacementField['sites']!
                as Map<String, Object?>)['landingBasin']!
            as Map<String, Object?>)['rigPlacements'] = [
          {'tier': 't1', 'x': 3, 'y': 2, 'extra': true},
        ];
        await expectRecovered(extraPlacementField);
      },
    );

    final cases = <String, Map<String, Object?>>{
      'negative cash': _rawDocument(nowUtc: now)..['cash'] = -5,
      'non-int cash': _rawDocument(nowUtc: now)..['cash'] = 100.5,
      'missing root field lastAccruedAtUtc': _rawDocument(nowUtc: now)
        ..remove('lastAccruedAtUtc'),
      'malformed timestamp': _rawDocument(nowUtc: now)
        ..['lastAccruedAtUtc'] = 'not-a-date',
      'non-UTC timestamp': _rawDocument(nowUtc: now)
        ..['lastAccruedAtUtc'] = '2026-08-27T12:00:00',
      'missing technology field': _rawDocument(nowUtc: now)
        ..remove('technology'),
      'technology with unknown field': _rawDocument(nowUtc: now)
        ..['technology'] = {
          'extraction': 0,
          'logistics': 0,
          'surveying': 0,
          'unknown': 0,
        },
      'negative technology level': _rawDocument(nowUtc: now)
        ..['technology'] = {'extraction': -1, 'logistics': 0, 'surveying': 0},
      'non-int technology level': _rawDocument(
        nowUtc: now,
      )..['technology'] = {'extraction': 'one', 'logistics': 0, 'surveying': 0},
      'technology level above 5': _rawDocument(nowUtc: now)
        ..['technology'] = {'extraction': 6, 'logistics': 0, 'surveying': 0},
      'empty unlocked planet list': _rawDocument(nowUtc: now)
        ..['unlockedPlanetIds'] = <String>[],
      'duplicate unlocked planet': _rawDocument(nowUtc: now)
        ..['unlockedPlanetIds'] = ['homeworld', 'homeworld'],
      'unknown unlocked planet': _rawDocument(nowUtc: now)
        ..['unlockedPlanetIds'] = ['homeworld', 'bogus'],
      'unknown active planet': _rawDocument(nowUtc: now)
        ..['activePlanetId'] = 'bogus',
      'active planet not unlocked': _rawDocument(nowUtc: now)
        ..['activePlanetId'] = 'lunarFrontier',
      'Homeworld is not unlocked': _rawDocument(nowUtc: now)
        ..['unlockedPlanetIds'] = ['lunarFrontier']
        ..['activePlanetId'] = 'lunarFrontier',
      'unlocked planet prerequisite missing': _rawDocument(nowUtc: now)
        ..['unlockedPlanetIds'] = ['homeworld', 'marsFrontier']
        ..['activePlanetId'] = 'homeworld',
      'locked planet has a rig': _rawDocument(nowUtc: now)
        ..['docks'] = {
          ...(_rawDocument(nowUtc: now)['docks']! as Map<String, Object?>),
          'lunarFrontier': {'b1': 't1', 'b2': null, 'b3': null, 'b4': null},
        },
      'locked planet has non-pristine site': _rawDocument(nowUtc: now)
        ..['sites'] = {
          ...(_rawDocument(nowUtc: now)['sites']! as Map<String, Object?>),
          'frozenBasin': {
            'unlocked': false,
            'commissioned': false,
            'storedAmount': 1,
            'rigPlacements': <Object?>[],
          },
        },
      'locked site is commissioned': _rawDocument(nowUtc: now)
        ..['sites'] = {
          ...(_rawDocument(nowUtc: now)['sites']! as Map<String, Object?>),
          'carbonRidge': {
            'unlocked': false,
            'commissioned': true,
            'storedAmount': 0,
            'rigPlacements': <Object?>[],
          },
        },
      'commissioned site is locked': _rawDocument(nowUtc: now)
        ..['sites'] = {
          ...(_rawDocument(nowUtc: now)['sites']! as Map<String, Object?>),
          'landingBasin': {
            'unlocked': false,
            'commissioned': true,
            'storedAmount': 0,
            'rigPlacements': <Object?>[],
          },
        },
      'later site unlocked before prerequisite': _rawDocument(nowUtc: now)
        ..['sites'] = {
          ...(_rawDocument(nowUtc: now)['sites']! as Map<String, Object?>),
          'graniteCrater': {
            'unlocked': true,
            'commissioned': false,
            'storedAmount': 0,
            'rigPlacements': <Object?>[],
          },
        },
      'unlocked planet first site is locked': _rawDocument(nowUtc: now)
        ..['unlockedPlanetIds'] = ['homeworld', 'lunarFrontier']
        ..['activePlanetId'] = 'lunarFrontier',
      'deployed rig above Surveying availability': _rawDocument(nowUtc: now)
        ..['sites'] = {
          ...(_rawDocument(nowUtc: now)['sites']! as Map<String, Object?>),
          'landingBasin': {
            'unlocked': true,
            'commissioned': true,
            'storedAmount': 0,
            'rigPlacements': [
              {'tier': 't1', 'x': 5, 'y': 10},
            ],
          },
        },
      'negative cargo': _rawDocument(nowUtc: now)
        ..['sites'] = {
          ...(_rawDocument(nowUtc: now)['sites']! as Map<String, Object?>),
          'landingBasin': {
            'unlocked': true,
            'commissioned': false,
            'storedAmount': -1,
            'rigPlacements': <Object?>[],
          },
        },
      'non-numeric cargo': _rawDocument(nowUtc: now)
        ..['sites'] = {
          ...(_rawDocument(nowUtc: now)['sites']! as Map<String, Object?>),
          'landingBasin': {
            'unlocked': true,
            'commissioned': false,
            'storedAmount': 'abc',
            'rigPlacements': <Object?>[],
          },
        },
    };

    cases.forEach((name, raw) {
      test(name, () => expectRecovered(raw));
    });
  });

  group('rig placement decoding', () {
    Map<String, Object?> rawWithLandingPlacements(
      List<Object?> placements, {
      int surveying = 5,
    }) {
      final raw = _rawDocument(nowUtc: now);
      final technology = Map<String, Object?>.from(
        raw['technology']! as Map<String, Object?>,
      )..['surveying'] = surveying;
      final sites = Map<String, Object?>.from(
        raw['sites']! as Map<String, Object?>,
      );
      final landing =
          Map<String, Object?>.from(
              sites[MiningSiteId.landingBasin.name]! as Map<String, Object?>,
            )
            ..['unlocked'] = true
            ..['commissioned'] = true
            ..['rigPlacements'] = placements;
      sites[MiningSiteId.landingBasin.name] = landing;
      raw['technology'] = technology;
      raw['sites'] = sites;
      return raw;
    }

    Future<void> expectRecovered(Map<String, Object?> raw) async {
      SharedPreferences.setMockInitialValues({
        MiningSaveRepository.saveKey: jsonEncode(raw),
      });
      final result = await MiningSaveRepository().load(nowUtc: now);
      expect(result.recoveredFromInvalidSave, isTrue);
      expect(result.state, MiningSave.initial(nowUtc: now));
    }

    test(
      'invalid rig placements recover through the strict boundary',
      () async {
        final invalid = <Map<String, Object?>>[
          rawWithLandingPlacements([
            {'tier': 't1', 'x': 3, 'y': 2},
            {'tier': 't2', 'x': 3, 'y': 2},
          ]),
          rawWithLandingPlacements([
            {'tier': 't1', 'x': 3, 'y': 3},
          ]),
          rawWithLandingPlacements([
            {'tier': 't1', 'x': 5, 'y': 10},
          ], surveying: 0),
          rawWithLandingPlacements([
            {'tier': 't1', 'x': 16, 'y': 9},
            {'tier': 't1', 'x': 17, 'y': 9},
            {'tier': 't1', 'x': 18, 'y': 9},
            {'tier': 't1', 'x': 15, 'y': 10},
          ], surveying: 2),
          rawWithLandingPlacements([
            {'tier': 't1', 'x': 3, 'y': 2},
            {'tier': 't1', 'x': 16, 'y': 2},
            {'tier': 't1', 'x': 5, 'y': 10},
            {'tier': 't1', 'x': 16, 'y': 9},
            {'tier': 't1', 'x': 17, 'y': 9},
          ], surveying: 2),
          rawWithLandingPlacements([
            {'tier': 't9', 'x': 3, 'y': 2},
          ]),
          rawWithLandingPlacements([
            {'tier': 't1', 'x': 3.5, 'y': 2},
          ]),
        ];

        for (final raw in invalid) {
          await expectRecovered(raw);
        }
      },
    );

    test('legacy rigByNode site shape recovers as incompatible', () async {
      final raw = _rawDocument(nowUtc: now);
      final sites = Map<String, Object?>.from(
        raw['sites']! as Map<String, Object?>,
      );
      final landing =
          Map<String, Object?>.from(
              sites[MiningSiteId.landingBasin.name]! as Map<String, Object?>,
            )
            ..remove('rigPlacements')
            ..['rigByNode'] = {'n1': 't1', 'n2': null, 'n3': null, 'n4': null};
      sites[MiningSiteId.landingBasin.name] = landing;
      raw['sites'] = sites;

      await expectRecovered(raw);
    });

    test('valid placements decode in order into an immutable list', () async {
      final raw = rawWithLandingPlacements([
        {'tier': 't1', 'x': 3, 'y': 2},
        {'tier': 't2', 'x': 16, 'y': 2},
      ]);
      SharedPreferences.setMockInitialValues({
        MiningSaveRepository.saveKey: jsonEncode(raw),
      });

      final result = await MiningSaveRepository().load(nowUtc: now);

      expect(result.recoveredFromInvalidSave, isFalse);
      final landing = result.state.sites[MiningSiteId.landingBasin]!;
      expect(landing.rigPlacements, [
        MiningRigPlacement(tier: RigTier.t1, cell: const MiningGridCell(3, 2)),
        MiningRigPlacement(tier: RigTier.t2, cell: const MiningGridCell(16, 2)),
      ]);
      expect(
        () => landing.rigPlacements.add(
          MiningRigPlacement(
            tier: RigTier.t1,
            cell: const MiningGridCell(5, 10),
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });

  test(
    'save writes only the new mining key and leaves retired keys untouched',
    () async {
      SharedPreferences.setMockInitialValues({
        'horologium.mining.save': 'retired',
        'cash': 999999.0,
        'buildings': <String>['1,1,Gold Mine'],
      });
      await MiningSaveRepository().save(MiningSave.initial(nowUtc: now));

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().where((k) => k.startsWith('horologium.')).toSet(),
        <String>{MiningSaveRepository.saveKey, 'horologium.mining.save'},
      );
      expect(prefs.getString('horologium.mining.save'), 'retired');
      expect(prefs.getDouble('cash'), 999999.0);
      expect(prefs.getStringList('buildings'), <String>['1,1,Gold Mine']);
    },
  );
}
