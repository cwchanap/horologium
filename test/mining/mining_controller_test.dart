import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_controller.dart';
import 'package:horologium/mining/mining_save_repository.dart';
import 'package:horologium/mining/mining_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestClock {
  TestClock(this.now);
  DateTime now;
  DateTime call() => now;
}

class DelayedMiningSaveRepository extends MiningSaveRepository {
  final saveStarted = Completer<void>();
  final allowFirstSave = Completer<void>();
  var saveCount = 0;

  @override
  Future<void> save(MiningSave state) async {
    saveCount++;
    if (saveCount == 1) {
      if (!saveStarted.isCompleted) saveStarted.complete();
      await allowFirstSave.future;
    }
    await super.save(state);
  }
}

class ThrowingFirstSaveRepository extends MiningSaveRepository {
  final secondSaveStarted = Completer<void>();
  final allowSecondSave = Completer<void>();
  var saveCount = 0;

  @override
  Future<void> save(MiningSave state) async {
    saveCount++;
    if (saveCount == 1) {
      throw StateError('disk full');
    }
    if (saveCount == 2) {
      secondSaveStarted.complete();
      await allowSecondSave.future;
    }
    await super.save(state);
  }
}

class AlwaysFailingSaveRepository extends MiningSaveRepository {
  var saveCount = 0;

  @override
  Future<void> save(MiningSave state) async {
    saveCount++;
    throw StateError('Mining save was rejected by SharedPreferences.');
  }
}

MiningSave seededSave(
  DateTime now, {
  int cash = 100,
  Map<MiningSectorId, MineState> mines = const {},
}) {
  final base = MiningSave.initial(nowUtc: now);
  return base.copyWith(
    cash: cash,
    sectors: {
      for (final entry in base.sectors.entries)
        entry.key: entry.value.copyWith(
          revealed: entry.value.revealed || mines[entry.key] != null,
          mine: mines[entry.key],
        ),
    },
  );
}

void main() {
  late TestClock clock;
  late MiningController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    clock = TestClock(DateTime.utc(2026, 8, 18, 12));
    controller = MiningController(
      content: MiningContentRegistry.stellarMining(),
      repository: MiningSaveRepository(),
      nowUtc: clock.call,
    );
    await controller.initialize();
  });

  Future<MiningController> controllerOver(
    MiningSaveRepository repository, {
    MiningSave? seed,
  }) async {
    // Always seed so initialize() loads an existing key and does not persist.
    // Tests that use delayed/failing repos rely on the first repository.save()
    // being the first mutation, not the init persistence.
    await MiningSaveRepository().save(
      seed ?? MiningSave.initial(nowUtc: clock.now),
    );
    final seededController = MiningController(
      content: MiningContentRegistry.stellarMining(),
      repository: repository,
      nowUtc: clock.call,
    );
    await seededController.initialize();
    return seededController;
  }

  group('initialization persistence', () {
    test(
      'survives a failed initial-save on a missing save and retains state',
      () async {
        SharedPreferences.setMockInitialValues({});
        final repository = AlwaysFailingSaveRepository();
        final fresh = MiningController(
          content: MiningContentRegistry.stellarMining(),
          repository: repository,
          nowUtc: clock.call,
        );

        await fresh.initialize();

        expect(fresh.state.cash, 100);
        expect(fresh.recoveredFromInvalidSave, isFalse);
        expect(repository.saveCount, 1);
      },
    );

    test(
      'survives a failed initial-save on a recovered save and retains state',
      () async {
        // Seed a malformed save so load() recovers with a fresh initial state
        // and initialize() attempts the best-effort persistence.
        SharedPreferences.setMockInitialValues({
          MiningSaveRepository.saveKey: '{not valid json',
        });
        final repository = AlwaysFailingSaveRepository();
        final recovered = MiningController(
          content: MiningContentRegistry.stellarMining(),
          repository: repository,
          nowUtc: clock.call,
        );

        await recovered.initialize();

        expect(recovered.state.cash, 100);
        expect(recovered.recoveredFromInvalidSave, isTrue);
        expect(repository.saveCount, 1);
      },
    );
  });

  group('actions', () {
    test('build validates before changing state', () async {
      final before = controller.state.toJson();
      final result = await controller.buildMine(MiningSectorId.carbonRidge);
      expect(result.isSuccess, isFalse);
      expect(controller.state.toJson(), before);
    });

    test('gold build deducts once and creates level one mine', () async {
      final result = await controller.buildMine(MiningSectorId.landingBasin);
      expect(result.isSuccess, isTrue);
      expect(controller.state.cash, 50);
      expect(
        controller.state.sectors[MiningSectorId.landingBasin]!.mine!.level,
        1,
      );
    });

    test('reveal fails when cash is insufficient', () async {
      final before = controller.state.toJson();
      final result = await controller.revealSector(MiningSectorId.carbonRidge);
      expect(result.isSuccess, isFalse);
      expect(controller.state.toJson(), before);
    });

    test('reveal deducts the reveal cost and marks the sector', () async {
      final rich = await controllerOver(
        MiningSaveRepository(),
        seed: seededSave(clock.now, cash: 1000),
      );
      final result = await rich.revealSector(MiningSectorId.carbonRidge);
      expect(result.isSuccess, isTrue);
      expect(rich.state.cash, 750);
      expect(rich.state.sectors[MiningSectorId.carbonRidge]!.revealed, isTrue);
    });

    test('reveal respects the required sector chain', () async {
      final rich = await controllerOver(
        MiningSaveRepository(),
        seed: seededSave(clock.now, cash: 2000),
      );
      final result = await rich.revealSector(MiningSectorId.graniteCrater);
      expect(result.isSuccess, isFalse);
      expect(
        rich.state.sectors[MiningSectorId.graniteCrater]!.revealed,
        isFalse,
      );
      expect(rich.state.cash, 2000);
    });

    test('reveal of an already revealed sector fails', () async {
      final result = await controller.revealSector(MiningSectorId.landingBasin);
      expect(result.isSuccess, isFalse);
      expect(controller.state.cash, 100);
    });

    test('duplicate build fails without a second deduction', () async {
      final first = await controller.buildMine(MiningSectorId.landingBasin);
      final second = await controller.buildMine(MiningSectorId.landingBasin);
      expect(first.isSuccess, isTrue);
      expect(second.isSuccess, isFalse);
      expect(controller.state.cash, 50);
    });

    test('upgrade fails without a mine', () async {
      final before = controller.state.toJson();
      final result = await controller.upgradeMine(MiningSectorId.landingBasin);
      expect(result.isSuccess, isFalse);
      expect(controller.state.toJson(), before);
    });

    test('upgrade fails when cash is insufficient', () async {
      await controller.buildMine(MiningSectorId.landingBasin);
      final result = await controller.upgradeMine(MiningSectorId.landingBasin);
      expect(result.isSuccess, isFalse);
      expect(controller.state.cash, 50);
    });

    test('upgrade deducts the tier cost and raises the level', () async {
      final rich = await controllerOver(
        MiningSaveRepository(),
        seed: seededSave(clock.now, cash: 1000),
      );
      await rich.buildMine(MiningSectorId.landingBasin);
      final result = await rich.upgradeMine(MiningSectorId.landingBasin);
      expect(result.isSuccess, isTrue);
      expect(rich.state.cash, 870);
      expect(rich.state.sectors[MiningSectorId.landingBasin]!.mine!.level, 2);
    });

    test('upgrade fails at max level', () async {
      final maxed = await controllerOver(
        MiningSaveRepository(),
        seed: seededSave(
          clock.now,
          cash: 5000,
          mines: {
            MiningSectorId.landingBasin: MineState(level: 5, storedAmount: 0),
          },
        ),
      );
      final result = await maxed.upgradeMine(MiningSectorId.landingBasin);
      expect(result.isSuccess, isFalse);
      expect(maxed.state.cash, 5000);
      expect(maxed.state.sectors[MiningSectorId.landingBasin]!.mine!.level, 5);
    });

    test('sell with zero cargo fails without changing state', () async {
      final before = controller.state.toJson();
      final result = await controller.sellAllCargo();
      expect(result.isSuccess, isFalse);
      expect(result.message, 'No cargo to sell.');
      expect(controller.state.toJson(), before);
    });

    test('sell adds revenue and zeroes cargo', () async {
      await controller.buildMine(MiningSectorId.landingBasin);
      clock.now = clock.now.add(const Duration(seconds: 10));
      final result = await controller.sellAllCargo();
      expect(result.isSuccess, isTrue);
      expect(result.revenue, 20);
      expect(result.sold, {ResourceType.gold: 5.0});
      expect(controller.state.cash, 70);
      expect(
        controller
            .state
            .sectors[MiningSectorId.landingBasin]!
            .mine!
            .storedAmount,
        0,
      );
    });

    test('sell floors the total once, not per sector', () async {
      final seller = await controllerOver(
        MiningSaveRepository(),
        seed: seededSave(
          clock.now,
          cash: 1000,
          mines: {
            MiningSectorId.landingBasin: MineState(level: 1, storedAmount: 0.9),
            MiningSectorId.carbonRidge: MineState(level: 1, storedAmount: 0.9),
            MiningSectorId.graniteCrater: MineState(
              level: 1,
              storedAmount: 0.9,
            ),
          },
        ),
      );
      final result = await seller.sellAllCargo();
      expect(result.isSuccess, isTrue);
      // floor(0.9 * 4 + 0.9 * 3 + 0.9 * 5) == floor(10.8) == 10, not 9.
      expect(result.revenue, 10);
      expect(result.sold, {
        ResourceType.gold: 0.9,
        ResourceType.coal: 0.9,
        ResourceType.stone: 0.9,
      });
      expect(seller.state.cash, 1010);
    });

    test('checkpoint persists the accrued state', () async {
      await controller.buildMine(MiningSectorId.landingBasin);
      clock.now = clock.now.add(const Duration(seconds: 30));
      await controller.checkpoint();

      final prefs = await SharedPreferences.getInstance();
      final raw =
          jsonDecode(prefs.getString(MiningSaveRepository.saveKey)!)
              as Map<String, Object?>;
      expect(raw['cash'], 50);
      expect(raw['lastAccruedAtUtc'], clock.now.toIso8601String());
      expect((raw['sectors']! as Map<String, Object?>)['landingBasin'], {
        'revealed': true,
        'mine': {'level': 1, 'storedAmount': 15.0},
      });
    });

    test('resume returns the offline summary exactly once', () async {
      await controller.buildMine(MiningSectorId.landingBasin);
      clock.now = clock.now.add(const Duration(seconds: 100));
      final summary = await controller.resume();
      expect(summary, isNotNull);
      expect(summary!.produced[ResourceType.gold], 50);
      expect(
        controller
            .state
            .sectors[MiningSectorId.landingBasin]!
            .mine!
            .storedAmount,
        50,
      );
      expect(await controller.resume(), isNull);
    });
  });

  group('passive refresh', () {
    test('accrues in memory without persisting', () async {
      await controller.buildMine(MiningSectorId.landingBasin);
      final prefs = await SharedPreferences.getInstance();
      final payloadBefore = prefs.getString(MiningSaveRepository.saveKey);

      clock.now = clock.now.add(const Duration(seconds: 10));
      final result = controller.refresh();

      expect(result.summary.produced[ResourceType.gold], 5.0);
      expect(
        controller
            .state
            .sectors[MiningSectorId.landingBasin]!
            .mine!
            .storedAmount,
        5.0,
      );
      expect(prefs.getString(MiningSaveRepository.saveKey), payloadBefore);
    });

    test('while a blocked save is in flight does not change state', () async {
      final repository = DelayedMiningSaveRepository();
      final busyController = await controllerOver(repository);

      final buildFuture = busyController.buildMine(MiningSectorId.landingBasin);
      await repository.saveStarted.future;
      clock.now = clock.now.add(const Duration(seconds: 10));

      final result = busyController.refresh();

      expect(busyController.isBusy, isTrue);
      expect(busyController.state.cash, 100);
      expect(result.summary.totalProduced, 0);

      repository.allowFirstSave.complete();
      await buildFuture;
      expect(busyController.state.cash, 50);
    });
  });

  group('serialization', () {
    test(
      'build then sell issued without awaiting cannot erase the build',
      () async {
        SharedPreferences.setMockInitialValues({});
        final repository = DelayedMiningSaveRepository();
        // Seed so initialize() loads an existing key and does not persist;
        // the first repository.save() must be the build mutation, which
        // gates on allowFirstSave.
        await MiningSaveRepository().save(
          MiningSave.initial(nowUtc: clock.now),
        );
        final controller = MiningController(
          content: MiningContentRegistry.stellarMining(),
          repository: repository,
          nowUtc: clock.call,
        );
        await controller.initialize();

        final buildFuture = controller.buildMine(MiningSectorId.landingBasin);
        await repository.saveStarted.future;
        final sellFuture = controller.sellAllCargo();

        expect(controller.isBusy, isTrue);
        repository.allowFirstSave.complete();

        expect((await buildFuture).isSuccess, isTrue);
        expect(
          (await sellFuture).isSuccess,
          isFalse,
        ); // built mine has zero cargo
        expect(
          controller.state.sectors[MiningSectorId.landingBasin]!.mine,
          isNotNull,
        );
        expect(controller.state.cash, 50);
      },
    );

    test('double reveal queues and deducts exactly once', () async {
      final seeded = MiningSave.initial(nowUtc: clock.now).copyWith(cash: 1000);
      await MiningSaveRepository().save(seeded);
      final repository = DelayedMiningSaveRepository();
      final controller = MiningController(
        content: MiningContentRegistry.stellarMining(),
        repository: repository,
        nowUtc: clock.call,
      );
      await controller.initialize();

      final first = controller.revealSector(MiningSectorId.carbonRidge);
      await repository.saveStarted.future;
      final second = controller.revealSector(MiningSectorId.carbonRidge);
      repository.allowFirstSave.complete();

      expect((await first).isSuccess, isTrue);
      expect((await second).isSuccess, isFalse);
      expect(controller.state.cash, 750);
      expect(
        controller.state.sectors[MiningSectorId.carbonRidge]!.revealed,
        isTrue,
      );
    });

    test('isBusy flips synchronously when a mutation is enqueued', () async {
      final repository = DelayedMiningSaveRepository();
      final busyController = await controllerOver(repository);

      final future = busyController.buildMine(MiningSectorId.landingBasin);
      expect(busyController.isBusy, isTrue); // before the first save completes

      repository.allowFirstSave.complete();
      await future;
      expect(busyController.isBusy, isFalse);
    });

    test(
      'a failed save does not publish state or poison later queued actions',
      () async {
        final repository = ThrowingFirstSaveRepository();
        final stubborn = await controllerOver(repository);
        final before = stubborn.state.toJson();

        final first = stubborn.buildMine(MiningSectorId.landingBasin);
        final second = stubborn.buildMine(MiningSectorId.landingBasin);
        await expectLater(first, throwsStateError);
        await repository.secondSaveStarted.future;
        expect(stubborn.state.toJson(), before);
        expect(stubborn.isBusy, isTrue);

        repository.allowSecondSave.complete();
        expect((await second).isSuccess, isTrue);
        expect(stubborn.isBusy, isFalse);
        expect(stubborn.state.cash, 50);
        expect(
          stubborn.state.sectors[MiningSectorId.landingBasin]!.mine,
          isNotNull,
        );
      },
    );
  });
}
