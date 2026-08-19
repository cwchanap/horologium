import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_save_repository.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const key = 'horologium.mining.save';
  final now = DateTime.utc(2026, 8, 18, 12);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('load', () {
    test('missing save returns clean state without recovery warning', () async {
      final result = await MiningSaveRepository().load(nowUtc: now);
      expect(result.state.cash, 100);
      expect(result.recoveredFromInvalidSave, isFalse);
    });

    test('round trips the exact first-planet document', () async {
      final repository = MiningSaveRepository();
      final state = MiningSave.initial(nowUtc: now).copyWith(cash: 321);
      await repository.save(state);
      final loaded = await repository.load(nowUtc: now);
      expect(loaded.state.toJson(), state.toJson());
    });

    test('malformed JSON resets and reports recovery', () async {
      SharedPreferences.setMockInitialValues({key: '{not-json'});
      final result = await MiningSaveRepository().load(nowUtc: now);
      expect(result.state.cash, 100);
      expect(result.recoveredFromInvalidSave, isTrue);
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
    });

    test(
      'positive cargo above newly tuned capacity clamps without recovery',
      () async {
        final raw = <String, Object?>{
          'cash': 100,
          'lastAccruedAtUtc': now.toIso8601String(),
          'sectors': {
            'landingBasin': {
              'revealed': true,
              'mine': {'level': 1, 'storedAmount': 120.0},
            },
            'carbonRidge': {'revealed': false, 'mine': null},
            'graniteCrater': {'revealed': false, 'mine': null},
          },
        };
        SharedPreferences.setMockInitialValues({key: jsonEncode(raw)});

        final result = await MiningSaveRepository().load(nowUtc: now);

        expect(result.recoveredFromInvalidSave, isFalse);
        expect(
          result.state.sectors[MiningSectorId.landingBasin]!.mine!.storedAmount,
          90,
        );
      },
    );
  });

  group('invalid saves reset to initial with recovery flag', () {
    Map<String, Object?> validDoc() => {
      'cash': 100,
      'lastAccruedAtUtc': now.toIso8601String(),
      'sectors': {
        'landingBasin': {'revealed': true, 'mine': null},
        'carbonRidge': {'revealed': false, 'mine': null},
        'graniteCrater': {'revealed': false, 'mine': null},
      },
    };

    Map<String, Object?> mineDoc() => {
      'cash': 100,
      'lastAccruedAtUtc': now.toIso8601String(),
      'sectors': {
        'landingBasin': {
          'revealed': true,
          'mine': {'level': 1, 'storedAmount': 10.0},
        },
        'carbonRidge': {'revealed': false, 'mine': null},
        'graniteCrater': {'revealed': false, 'mine': null},
      },
    };

    final cases = <String, Map<String, Object?>>{
      'negative cash': {...validDoc(), 'cash': -5},
      'non-int cash': {...validDoc(), 'cash': 100.5},
      'missing root field lastAccruedAtUtc': {
        'cash': 100,
        'sectors': validDoc()['sectors'],
      },
      'missing root field sectors': {
        'cash': 100,
        'lastAccruedAtUtc': now.toIso8601String(),
      },
      'unknown sector key': {
        'cash': 100,
        'lastAccruedAtUtc': now.toIso8601String(),
        'sectors': {
          'landingBasin': {'revealed': true, 'mine': null},
          'carbonRidge': {'revealed': false, 'mine': null},
          'graniteCrater': {'revealed': false, 'mine': null},
          'bogus': {'revealed': false, 'mine': null},
        },
      },
      'missing sector key': {
        'cash': 100,
        'lastAccruedAtUtc': now.toIso8601String(),
        'sectors': {
          'landingBasin': {'revealed': true, 'mine': null},
          'carbonRidge': {'revealed': false, 'mine': null},
        },
      },
      'malformed timestamp': {...validDoc(), 'lastAccruedAtUtc': 'not-a-date'},
      'non-UTC timestamp': {
        ...validDoc(),
        'lastAccruedAtUtc': '2026-08-18T12:00:00',
      },
      'non-bool revealed': {
        ...validDoc(),
        'sectors': {
          'landingBasin': {'revealed': 'yes', 'mine': null},
          'carbonRidge': {'revealed': false, 'mine': null},
          'graniteCrater': {'revealed': false, 'mine': null},
        },
      },
      'mine level below 1': {
        ...mineDoc(),
        'sectors': {
          'landingBasin': {
            'revealed': true,
            'mine': {'level': 0, 'storedAmount': 10.0},
          },
          'carbonRidge': {'revealed': false, 'mine': null},
          'graniteCrater': {'revealed': false, 'mine': null},
        },
      },
      'mine level above 5': {
        ...mineDoc(),
        'sectors': {
          'landingBasin': {
            'revealed': true,
            'mine': {'level': 6, 'storedAmount': 10.0},
          },
          'carbonRidge': {'revealed': false, 'mine': null},
          'graniteCrater': {'revealed': false, 'mine': null},
        },
      },
      'negative cargo': {
        ...mineDoc(),
        'sectors': {
          'landingBasin': {
            'revealed': true,
            'mine': {'level': 1, 'storedAmount': -10.0},
          },
          'carbonRidge': {'revealed': false, 'mine': null},
          'graniteCrater': {'revealed': false, 'mine': null},
        },
      },
      'non-numeric cargo': {
        ...mineDoc(),
        'sectors': {
          'landingBasin': {
            'revealed': true,
            'mine': {'level': 1, 'storedAmount': 'abc'},
          },
          'carbonRidge': {'revealed': false, 'mine': null},
          'graniteCrater': {'revealed': false, 'mine': null},
        },
      },
      'extra root key': {...validDoc(), 'zzz': 1},
      'extra sector key': {
        ...validDoc(),
        'sectors': {
          'landingBasin': {'revealed': true, 'mine': null, 'note': 'hi'},
          'carbonRidge': {'revealed': false, 'mine': null},
          'graniteCrater': {'revealed': false, 'mine': null},
        },
      },
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
