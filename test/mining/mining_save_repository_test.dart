import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_save_repository.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const key = 'horologium.mining.save';
  final now = DateTime.utc(2026, 8, 18, 12);
  const validMiningSave =
      '{"cash":100,"lastAccruedAtUtc":"2026-08-18T12:00:00.000Z",'
      '"technology":{"extraction":0,"logistics":0,"surveying":0},'
      '"unlockedPlanetIds":["homeworld"],"activePlanetId":"homeworld",'
      '"sectors":{"landingBasin":{"revealed":true,"mine":null},'
      '"carbonRidge":{"revealed":false,"mine":null},'
      '"graniteCrater":{"revealed":false,"mine":null},'
      '"frozenBasin":{"revealed":false,"mine":null},'
      '"titaniumHighlands":{"revealed":false,"mine":null},'
      '"heliumMare":{"revealed":false,"mine":null}}}';

  setUp(() => SharedPreferences.setMockInitialValues({}));

  const pristineSector = <String, Object?>{'revealed': false, 'mine': null};

  Map<String, Object?> sixSectors({
    Map<String, Object?>? landingBasin,
    Map<String, Object?>? carbonRidge,
    Map<String, Object?>? graniteCrater,
    Map<String, Object?>? frozenBasin,
    Map<String, Object?>? titaniumHighlands,
    Map<String, Object?>? heliumMare,
  }) => <String, Object?>{
    'landingBasin': landingBasin ?? pristineSector,
    'carbonRidge': carbonRidge ?? pristineSector,
    'graniteCrater': graniteCrater ?? pristineSector,
    'frozenBasin': frozenBasin ?? pristineSector,
    'titaniumHighlands': titaniumHighlands ?? pristineSector,
    'heliumMare': heliumMare ?? pristineSector,
  };

  Map<String, Object?> currentDoc({
    int cash = 100,
    String? lastAccruedAtUtc,
    Map<String, Object?>? technology,
    List<String>? unlockedPlanetIds,
    String? activePlanetId,
    Map<String, Object?>? sectors,
  }) => <String, Object?>{
    'cash': cash,
    'lastAccruedAtUtc': lastAccruedAtUtc ?? now.toIso8601String(),
    'technology':
        technology ?? {'extraction': 0, 'logistics': 0, 'surveying': 0},
    'unlockedPlanetIds': unlockedPlanetIds ?? ['homeworld'],
    'activePlanetId': activePlanetId ?? 'homeworld',
    'sectors': sectors ?? sixSectors(),
  };

  group('hasSave presence', () {
    test('empty preferences report no mining save', () async {
      expect(await MiningSaveRepository().hasSave(), isFalse);
    });

    test('legacy city keys do not count as a mining save', () async {
      SharedPreferences.setMockInitialValues({
        'cash': 999999.0,
        'planet.earth.resources.cash': 888888.0,
        'buildings': <String>['1,1,Gold Mine'],
      });

      expect(await MiningSaveRepository().hasSave(), isFalse);
    });

    test('presence of a valid mining document reports a save', () async {
      SharedPreferences.setMockInitialValues({key: validMiningSave});

      expect(await MiningSaveRepository().hasSave(), isTrue);
    });

    test(
      'presence of a malformed mining document still reports a save',
      () async {
        SharedPreferences.setMockInitialValues({
          key: '{ malformed mining json',
        });

        expect(await MiningSaveRepository().hasSave(), isTrue);
      },
    );
  });

  group('load', () {
    test('missing save returns clean state without recovery warning', () async {
      final result = await MiningSaveRepository().load(nowUtc: now);
      expect(result.state.cash, 100);
      expect(result.recoveredFromInvalidSave, isFalse);
      expect(result.wasMissing, isTrue);
    });

    test('round trips the exact first-planet document', () async {
      final repository = MiningSaveRepository();
      final state = MiningSave.initial(nowUtc: now).copyWith(cash: 321);
      await repository.save(state);
      final loaded = await repository.load(nowUtc: now);
      expect(loaded.state.toJson(), state.toJson());
      expect(loaded.wasMissing, isFalse);
    });

    test('current save root has exactly the six current keys', () async {
      final repository = MiningSaveRepository();
      await repository.save(MiningSave.initial(nowUtc: now));

      final prefs = await SharedPreferences.getInstance();
      final decoded = jsonDecode(prefs.getString(key)!) as Map<String, Object?>;

      expect(decoded.keys.toSet(), {
        'cash',
        'lastAccruedAtUtc',
        'technology',
        'unlockedPlanetIds',
        'activePlanetId',
        'sectors',
      });
    });

    test(
      'old three-key development document resets through recovery',
      () async {
        SharedPreferences.setMockInitialValues({
          key:
              '{"cash":100,"lastAccruedAtUtc":"2026-08-18T12:00:00.000Z",'
              '"sectors":{"landingBasin":{"revealed":true,"mine":null},'
              '"carbonRidge":{"revealed":false,"mine":null},'
              '"graniteCrater":{"revealed":false,"mine":null}}}',
        });

        final result = await MiningSaveRepository().load(nowUtc: now);

        expect(result.recoveredFromInvalidSave, isTrue);
        expect(result.wasMissing, isFalse);
        expect(result.state, MiningSave.initial(nowUtc: now));
      },
    );

    test('malformed JSON resets and reports recovery', () async {
      SharedPreferences.setMockInitialValues({key: '{not-json'});
      final result = await MiningSaveRepository().load(nowUtc: now);
      expect(result.state.cash, 100);
      expect(result.recoveredFromInvalidSave, isTrue);
      expect(result.wasMissing, isFalse);
    });

    test('non-String preference value resets and reports recovery', () async {
      // SharedPreferences.getString throws a runtime cast error when the
      // stored value is not a String. hasSave() still reports presence, so
      // load() must route this case through the recovery boundary instead of
      // letting the cast escape and brick the screen.
      SharedPreferences.setMockInitialValues({key: 123});
      expect(await MiningSaveRepository().hasSave(), isTrue);
      final result = await MiningSaveRepository().load(nowUtc: now);
      expect(result.state.cash, 100);
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
      expect(result.state.cash, 100);
      expect(result.state.sectors[MiningSectorId.landingBasin]!.mine, isNull);
      expect(result.wasMissing, isTrue);
    });

    test(
      'positive cargo above newly tuned capacity clamps without recovery',
      () async {
        final raw = currentDoc(
          sectors: sixSectors(
            landingBasin: {
              'revealed': true,
              'mine': {'level': 1, 'storedAmount': 120.0},
            },
          ),
        );
        SharedPreferences.setMockInitialValues({key: jsonEncode(raw)});

        final result = await MiningSaveRepository().load(nowUtc: now);

        expect(result.recoveredFromInvalidSave, isFalse);
        expect(
          result.state.sectors[MiningSectorId.landingBasin]!.mine!.storedAmount,
          90,
        );
      },
    );

    test(
      'logistics raises the decode clamp through effective capacity',
      () async {
        final raw = currentDoc(
          technology: {'extraction': 0, 'logistics': 1, 'surveying': 0},
          sectors: sixSectors(
            landingBasin: {
              'revealed': true,
              'mine': {'level': 1, 'storedAmount': 120.0},
            },
          ),
        );
        SharedPreferences.setMockInitialValues({key: jsonEncode(raw)});

        final result = await MiningSaveRepository().load(nowUtc: now);

        expect(result.recoveredFromInvalidSave, isFalse);
        expect(
          result.state.sectors[MiningSectorId.landingBasin]!.mine!.storedAmount,
          closeTo(103.5, 0.0001),
        );
        expect(result.state.technology.logistics, 1);
      },
    );
  });

  group('invalid saves reset to initial with recovery flag', () {
    final cases = <String, Map<String, Object?>>{
      'negative cash': currentDoc(cash: -5),
      'non-int cash': currentDoc()..['cash'] = 100.5,
      'missing root field lastAccruedAtUtc': currentDoc()
        ..remove('lastAccruedAtUtc'),
      'missing root field sectors': currentDoc()..remove('sectors'),
      'missing root field technology': currentDoc()..remove('technology'),
      'negative technology level': currentDoc(
        technology: {'extraction': -1, 'logistics': 0, 'surveying': 0},
      ),
      'non-int technology level': currentDoc(
        technology: {'extraction': 'one', 'logistics': 0, 'surveying': 0},
      ),
      'unknown planet id in unlocked list': currentDoc(
        unlockedPlanetIds: ['homeworld', 'bogus'],
      ),
      'empty unlocked planet list': currentDoc(unlockedPlanetIds: []),
      'active planet not unlocked': currentDoc(
        unlockedPlanetIds: ['lunarFrontier'],
        activePlanetId: 'homeworld',
      ),
      'unknown active planet': currentDoc(activePlanetId: 'mars'),
      'unknown sector key': currentDoc(
        sectors: sixSectors()..['bogus'] = {'revealed': false, 'mine': null},
      ),
      'missing sector key': currentDoc(
        sectors: sixSectors()..remove('graniteCrater'),
      ),
      'malformed timestamp': currentDoc(lastAccruedAtUtc: 'not-a-date'),
      'non-UTC timestamp': currentDoc(lastAccruedAtUtc: '2026-08-18T12:00:00'),
      'non-bool revealed': currentDoc(
        sectors: sixSectors(landingBasin: {'revealed': 'yes', 'mine': null}),
      ),
      'mine on an unrevealed sector': currentDoc(
        sectors: sixSectors(
          carbonRidge: {
            'revealed': false,
            'mine': {'level': 1, 'storedAmount': 10.0},
          },
        ),
      ),
      'mine level below 1': currentDoc(
        sectors: sixSectors(
          landingBasin: {
            'revealed': true,
            'mine': {'level': 0, 'storedAmount': 10.0},
          },
        ),
      ),
      'mine level above 5': currentDoc(
        sectors: sixSectors(
          landingBasin: {
            'revealed': true,
            'mine': {'level': 6, 'storedAmount': 10.0},
          },
        ),
      ),
      'negative cargo': currentDoc(
        sectors: sixSectors(
          landingBasin: {
            'revealed': true,
            'mine': {'level': 1, 'storedAmount': -10.0},
          },
        ),
      ),
      'non-numeric cargo': currentDoc(
        sectors: sixSectors(
          landingBasin: {
            'revealed': true,
            'mine': {'level': 1, 'storedAmount': 'abc'},
          },
        ),
      ),
      'extra root key': currentDoc()..['zzz'] = 1,
      'extra sector key': currentDoc(
        sectors: sixSectors(
          landingBasin: {'revealed': true, 'mine': null, 'note': 'hi'},
        ),
      ),
    };

    cases.forEach((name, raw) {
      test(name, () async {
        SharedPreferences.setMockInitialValues({key: jsonEncode(raw)});
        final result = await MiningSaveRepository().load(nowUtc: now);
        expect(result.state.cash, 100);
        expect(result.recoveredFromInvalidSave, isTrue);
      });
    });
  });

  test(
    'save writes only the mining key and leaves city keys untouched',
    () async {
      SharedPreferences.setMockInitialValues({
        'cash': 999999.0,
        'buildings': <String>['1,1,Gold Mine'],
      });
      final repository = MiningSaveRepository();
      await repository.save(MiningSave.initial(nowUtc: now));

      final prefs = await SharedPreferences.getInstance();
      final miningKeys = prefs
          .getKeys()
          .where((k) => k.startsWith('horologium.mining'))
          .toSet();
      expect(miningKeys, <String>{key});
      expect(prefs.getDouble('cash'), 999999.0);
      expect(prefs.getStringList('buildings'), <String>['1,1,Gold Mine']);
    },
  );
}
