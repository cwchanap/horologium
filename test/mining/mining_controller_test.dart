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
    if (saveCount == 1) throw StateError('disk full');
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

class CountingMiningSaveRepository extends MiningSaveRepository {
  var saveCount = 0;

  @override
  Future<void> save(MiningSave state) async {
    saveCount++;
    await super.save(state);
  }
}

Map<DockBayId, RigTier?> dock({
  RigTier? b1,
  RigTier? b2,
  RigTier? b3,
  RigTier? b4,
}) => {DockBayId.b1: b1, DockBayId.b2: b2, DockBayId.b3: b3, DockBayId.b4: b4};

Map<MiningNodeId, RigTier?> nodes({
  RigTier? n1,
  RigTier? n2,
  RigTier? n3,
  RigTier? n4,
}) => {
  MiningNodeId.n1: n1,
  MiningNodeId.n2: n2,
  MiningNodeId.n3: n3,
  MiningNodeId.n4: n4,
};

SiteProgress site({
  bool unlocked = false,
  bool commissioned = false,
  double storedAmount = 0,
  Map<MiningNodeId, RigTier?>? rigByNode,
}) => SiteProgress(
  unlocked: unlocked,
  commissioned: commissioned,
  storedAmount: storedAmount,
  rigByNode: rigByNode ?? nodes(),
);

MiningSave seededSave(
  DateTime now, {
  int cash = 100,
  Map<MiningPlanetId, Map<DockBayId, RigTier?>>? docks,
  Map<MiningSiteId, SiteProgress>? sites,
  TechnologyLevels technology = const TechnologyLevels(),
  Set<MiningPlanetId> unlockedPlanets = const {MiningPlanetId.homeworld},
  MiningPlanetId activePlanet = MiningPlanetId.homeworld,
}) {
  final base = MiningSave.initial(nowUtc: now);
  return base.copyWith(
    cash: cash,
    technology: technology,
    unlockedPlanetIds: unlockedPlanets,
    activePlanetId: activePlanet,
    docks: docks ?? base.docks,
    sites: sites ?? base.sites,
  );
}

Map<MiningPlanetId, Map<DockBayId, RigTier?>> docksFor({
  Map<DockBayId, RigTier?>? homeworld,
  Map<DockBayId, RigTier?>? lunar,
  Map<DockBayId, RigTier?>? mars,
}) => {
  MiningPlanetId.homeworld: homeworld ?? dock(),
  MiningPlanetId.lunarFrontier: lunar ?? dock(),
  MiningPlanetId.marsFrontier: mars ?? dock(),
};

Map<MiningSiteId, SiteProgress> sitesFor({
  SiteProgress? landing,
  SiteProgress? carbon,
  SiteProgress? granite,
  SiteProgress? frozen,
  SiteProgress? titanium,
  SiteProgress? helium,
  SiteProgress? ochre,
  SiteProgress? silica,
  SiteProgress? cobalt,
}) {
  final base = MiningSave.initial(nowUtc: DateTime.utc(2026, 8, 18, 12)).sites;
  return {
    ...base,
    if (landing != null) MiningSiteId.landingBasin: landing,
    if (carbon != null) MiningSiteId.carbonRidge: carbon,
    if (granite != null) MiningSiteId.graniteCrater: granite,
    if (frozen != null) MiningSiteId.frozenBasin: frozen,
    if (titanium != null) MiningSiteId.titaniumHighlands: titanium,
    if (helium != null) MiningSiteId.heliumMare: helium,
    if (ochre != null) MiningSiteId.ochreBasin: ochre,
    if (silica != null) MiningSiteId.silicaDunes: silica,
    if (cobalt != null) MiningSiteId.cobaltChasm: cobalt,
  };
}

MiningSave deployedLandingBasinState(
  DateTime now, {
  double storedAmount = 0,
  Map<MiningNodeId, RigTier?>? rigByNode,
}) => seededSave(
  now,
  docks: docksFor(homeworld: dock()),
  sites: sitesFor(
    landing: site(
      unlocked: true,
      commissioned: true,
      storedAmount: storedAmount,
      rigByNode: rigByNode ?? nodes(n1: RigTier.t1),
    ),
  ),
);

MiningSave landingWithTwoT1RigsAndCargo(
  DateTime now, {
  double storedAmount = 150,
}) => deployedLandingBasinState(
  now,
  storedAmount: storedAmount,
  rigByNode: nodes(n1: RigTier.t1, n2: RigTier.t1),
);

MiningSave homeworldMasteredState(
  DateTime now, {
  int cash = 5000,
  TechnologyLevels technology = const TechnologyLevels(surveying: 3),
  Set<MiningPlanetId> unlockedPlanets = const {MiningPlanetId.homeworld},
  MiningPlanetId activePlanet = MiningPlanetId.homeworld,
}) => seededSave(
  now,
  cash: cash,
  technology: technology,
  unlockedPlanets: unlockedPlanets,
  activePlanet: activePlanet,
  docks: docksFor(homeworld: dock()),
  sites: sitesFor(
    landing: site(unlocked: true, commissioned: true),
    carbon: site(unlocked: true, commissioned: true),
    granite: site(unlocked: true, commissioned: true),
  ),
);

MiningSave lunarMasteredState(
  DateTime now, {
  int cash = 20000,
  TechnologyLevels technology = const TechnologyLevels(surveying: 5),
  Set<MiningPlanetId> unlockedPlanets = const {
    MiningPlanetId.homeworld,
    MiningPlanetId.lunarFrontier,
  },
  MiningPlanetId activePlanet = MiningPlanetId.lunarFrontier,
}) => seededSave(
  now,
  cash: cash,
  technology: technology,
  unlockedPlanets: unlockedPlanets,
  activePlanet: activePlanet,
  docks: docksFor(homeworld: dock(), lunar: dock()),
  sites: sitesFor(
    landing: site(unlocked: true, commissioned: true),
    carbon: site(unlocked: true, commissioned: true),
    granite: site(unlocked: true, commissioned: true),
    frozen: site(unlocked: true, commissioned: true),
    titanium: site(unlocked: true, commissioned: true),
    helium: site(unlocked: true, commissioned: true),
  ),
);

void main() {
  late TestClock clock;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    clock = TestClock(DateTime.utc(2026, 8, 18, 12));
  });

  Future<MiningController> controllerOver(
    MiningSaveRepository repository, {
    MiningSave? seed,
  }) async {
    await MiningSaveRepository().save(
      seed ?? MiningSave.initial(nowUtc: clock.now),
    );
    final controller = MiningController(
      content: MiningContentRegistry.stellarMining(),
      repository: repository,
      nowUtc: clock.call,
    );
    await controller.initialize();
    return controller;
  }

  group('initialization and refresh', () {
    test('failed initial persistence does not lose a fresh state', () async {
      final repository = AlwaysFailingSaveRepository();
      final controller = MiningController(
        content: MiningContentRegistry.stellarMining(),
        repository: repository,
        nowUtc: clock.call,
      );

      await controller.initialize();

      expect(controller.state.cash, 100);
      expect(controller.recoveredFromInvalidSave, isFalse);
      expect(repository.saveCount, 1);
    });

    test(
      'failed initial persistence does not lose a recovered state',
      () async {
        SharedPreferences.setMockInitialValues({
          MiningSaveRepository.saveKey: '{invalid',
        });
        final repository = AlwaysFailingSaveRepository();
        final controller = MiningController(
          content: MiningContentRegistry.stellarMining(),
          repository: repository,
          nowUtc: clock.call,
        );

        await controller.initialize();

        expect(controller.state.cash, 100);
        expect(controller.recoveredFromInvalidSave, isTrue);
        expect(repository.saveCount, 1);
      },
    );

    test('refresh accrues in memory without persisting', () async {
      final repository = CountingMiningSaveRepository();
      final controller = await controllerOver(
        repository,
        seed: deployedLandingBasinState(clock.now),
      );
      final savesBefore = repository.saveCount;
      clock.now = clock.now.add(const Duration(seconds: 10));

      controller.refresh();

      expect(
        controller.state.sites[MiningSiteId.landingBasin]!.storedAmount,
        5.0,
      );
      expect(repository.saveCount, savesBefore);
    });

    test('refresh does not publish while a save is in flight', () async {
      final repository = DelayedMiningSaveRepository();
      final controller = await controllerOver(repository);
      final spawn = controller.spawnRig();
      await repository.saveStarted.future;
      clock.now = clock.now.add(const Duration(seconds: 10));

      final accrual = controller.refresh();

      expect(controller.isBusy, isTrue);
      expect(accrual.summary.totalProduced, 0);
      expect(controller.state.cash, 100);
      repository.allowFirstSave.complete();
      expect((await spawn).isSuccess, isTrue);
    });
  });

  group('spawn and merge', () {
    test(
      'spawn uses the first empty active-planet bay and charges its planet cost',
      () async {
        final controller = await controllerOver(
          MiningSaveRepository(),
          seed: seededSave(
            clock.now,
            cash: 30,
            docks: docksFor(
              homeworld: dock(b1: RigTier.t1, b2: RigTier.t1),
            ),
          ),
        );

        final result = await controller.spawnRig();

        expect(result.isSuccess, isTrue);
        expect(controller.state.cash, 5);
        expect(controller.state.docks[MiningPlanetId.homeworld], {
          DockBayId.b1: RigTier.t1,
          DockBayId.b2: RigTier.t1,
          DockBayId.b3: RigTier.t1,
          DockBayId.b4: null,
        });
      },
    );

    test('spawn uses Lunar cost and respects insufficient cash', () async {
      final controller = await controllerOver(
        MiningSaveRepository(),
        seed: seededSave(
          clock.now,
          cash: 499,
          unlockedPlanets: {
            MiningPlanetId.homeworld,
            MiningPlanetId.lunarFrontier,
          },
          activePlanet: MiningPlanetId.lunarFrontier,
          docks: docksFor(
            homeworld: dock(b1: RigTier.t1, b2: RigTier.t1),
            lunar: dock(b1: RigTier.t1, b2: RigTier.t1),
          ),
          sites: sitesFor(frozen: site(unlocked: true)),
        ),
      );
      final before = controller.state.toJson();

      final result = await controller.spawnRig();

      expect(result.isSuccess, isFalse);
      expect(result.message, 'Not enough cash.');
      expect(controller.state.toJson(), before);
    });

    test('spawn rejects a full dock', () async {
      final controller = await controllerOver(
        MiningSaveRepository(),
        seed: seededSave(
          clock.now,
          cash: 1000,
          docks: docksFor(
            homeworld: dock(
              b1: RigTier.t1,
              b2: RigTier.t1,
              b3: RigTier.t2,
              b4: RigTier.t3,
            ),
          ),
        ),
      );

      final result = await controller.spawnRig();

      expect(result.isSuccess, isFalse);
      expect(result.message, 'Dock is full.');
    });

    test(
      'merge moves the next tier to the target and empties the source',
      () async {
        final controller = await controllerOver(
          MiningSaveRepository(),
          seed: seededSave(
            clock.now,
            docks: docksFor(
              homeworld: dock(b1: RigTier.t1, b2: RigTier.t1),
            ),
          ),
        );

        final result = await controller.mergeDockRigs(
          DockBayId.b1,
          DockBayId.b2,
        );

        expect(result.isSuccess, isTrue);
        expect(controller.state.docks[MiningPlanetId.homeworld], {
          DockBayId.b1: null,
          DockBayId.b2: RigTier.t2,
          DockBayId.b3: null,
          DockBayId.b4: null,
        });
      },
    );

    test('merge rejects same bay, empty, and mismatched rigs', () async {
      final controller = await controllerOver(
        MiningSaveRepository(),
        seed: seededSave(
          clock.now,
          docks: docksFor(
            homeworld: dock(b1: RigTier.t1, b2: RigTier.t2, b3: RigTier.t5),
          ),
        ),
      );

      expect(
        (await controller.mergeDockRigs(DockBayId.b1, DockBayId.b1)).message,
        'Choose two different dock bays.',
      );
      expect(
        (await controller.mergeDockRigs(DockBayId.b4, DockBayId.b1)).message,
        'Source dock bay is empty.',
      );
      expect(
        (await controller.mergeDockRigs(DockBayId.b1, DockBayId.b2)).message,
        'Rigs must be the same tier.',
      );
    });

    test('merge rejects T5 rigs', () async {
      final controller = await controllerOver(
        MiningSaveRepository(),
        seed: seededSave(
          clock.now,
          docks: docksFor(
            homeworld: dock(b1: RigTier.t5, b2: RigTier.t5),
          ),
        ),
      );

      final result = await controller.mergeDockRigs(DockBayId.b1, DockBayId.b2);

      expect(result.isSuccess, isFalse);
      expect(result.message, 'T5 rigs cannot merge.');
    });

    test(
      'queued duplicate merges settle against the committed state',
      () async {
        final repository = DelayedMiningSaveRepository();
        final controller = await controllerOver(
          repository,
          seed: seededSave(
            clock.now,
            docks: docksFor(
              homeworld: dock(b1: RigTier.t1, b2: RigTier.t1, b3: RigTier.t1),
            ),
          ),
        );
        final first = controller.mergeDockRigs(DockBayId.b1, DockBayId.b2);
        await repository.saveStarted.future;
        final second = controller.mergeDockRigs(DockBayId.b1, DockBayId.b2);
        repository.allowFirstSave.complete();

        expect((await first).isSuccess, isTrue);
        expect((await second).isSuccess, isFalse);
        expect(
          controller.state.docks[MiningPlanetId.homeworld]![DockBayId.b2],
          RigTier.t2,
        );
      },
    );
  });

  group('site unlock, deployment, and recall', () {
    test(
      'unlockSite enforces active planet, prerequisite, Surveying, and cash',
      () async {
        final controller = await controllerOver(
          MiningSaveRepository(),
          seed: seededSave(clock.now, cash: 900),
        );

        final prerequisite = await controller.unlockSite(
          MiningSiteId.graniteCrater,
        );
        expect(prerequisite.message, 'Unlock the previous site first.');

        final carbon = await controller.unlockSite(MiningSiteId.carbonRidge);
        expect(carbon.isSuccess, isTrue);
        expect(controller.state.cash, 650);

        final poor = await controller.unlockSite(MiningSiteId.graniteCrater);
        expect(poor.message, 'Not enough cash.');
      },
    );

    test(
      'deploy moves a docked rig and commissions the first deployment',
      () async {
        final controller = await controllerOver(
          MiningSaveRepository(),
          seed: seededSave(
            clock.now,
            docks: docksFor(
              homeworld: dock(b1: RigTier.t1, b2: RigTier.t1),
            ),
            sites: sitesFor(landing: site(unlocked: true)),
          ),
        );

        final result = await controller.deployRig(
          DockBayId.b1,
          MiningSiteId.landingBasin,
          MiningNodeId.n1,
        );

        expect(result.isSuccess, isTrue);
        expect(
          controller.state.docks[MiningPlanetId.homeworld]![DockBayId.b1],
          isNull,
        );
        final landing = controller.state.sites[MiningSiteId.landingBasin]!;
        expect(landing.commissioned, isTrue);
        expect(landing.rigByNode[MiningNodeId.n1], RigTier.t1);
      },
    );

    test(
      'deploy rejects inactive sites, occupied nodes, and unavailable nodes',
      () async {
        final controller = await controllerOver(
          MiningSaveRepository(),
          seed: seededSave(
            clock.now,
            technology: const TechnologyLevels(),
            unlockedPlanets: {
              MiningPlanetId.homeworld,
              MiningPlanetId.lunarFrontier,
            },
            activePlanet: MiningPlanetId.homeworld,
            docks: docksFor(
              homeworld: dock(b1: RigTier.t1, b2: RigTier.t1),
              lunar: dock(b1: RigTier.t1, b2: RigTier.t1),
            ),
            sites: sitesFor(
              frozen: site(unlocked: true),
              landing: site(
                unlocked: true,
                commissioned: true,
                rigByNode: nodes(n1: RigTier.t1),
              ),
            ),
          ),
        );

        expect(
          (await controller.deployRig(
            DockBayId.b1,
            MiningSiteId.frozenBasin,
            MiningNodeId.n1,
          )).message,
          'Site is not on the active planet.',
        );
        expect(
          (await controller.deployRig(
            DockBayId.b1,
            MiningSiteId.landingBasin,
            MiningNodeId.n1,
          )).message,
          'Node is already occupied.',
        );
        expect(
          (await controller.deployRig(
            DockBayId.b1,
            MiningSiteId.landingBasin,
            MiningNodeId.n3,
          )).message,
          'Requires Surveying 1.',
        );
      },
    );

    test('deploy rejects an empty bay and an unavailable site', () async {
      final controller = await controllerOver(
        MiningSaveRepository(),
        seed: seededSave(clock.now),
      );

      expect(
        (await controller.deployRig(
          DockBayId.b4,
          MiningSiteId.landingBasin,
          MiningNodeId.n1,
        )).message,
        'Dock bay is empty.',
      );
      expect(
        (await controller.deployRig(
          DockBayId.b1,
          MiningSiteId.carbonRidge,
          MiningNodeId.n1,
        )).message,
        'Unlock this site first.',
      );
    });

    test(
      'recall rejects cargo above post-recall capacity, then succeeds after sale',
      () async {
        final controller = await controllerOver(
          MiningSaveRepository(),
          seed: landingWithTwoT1RigsAndCargo(clock.now),
        );

        final blocked = await controller.recallRig(
          MiningSiteId.landingBasin,
          MiningNodeId.n2,
        );

        expect(blocked.isSuccess, isFalse);
        expect(blocked.message, 'Sell cargo before recalling this rig.');
        expect(
          controller
              .state
              .sites[MiningSiteId.landingBasin]!
              .rigByNode[MiningNodeId.n2],
          RigTier.t1,
        );

        final sale = await controller.sellAllCargo();
        expect(sale.isSuccess, isTrue);
        final recalled = await controller.recallRig(
          MiningSiteId.landingBasin,
          MiningNodeId.n2,
        );
        expect(recalled.isSuccess, isTrue);
        expect(
          controller.state.docks[MiningPlanetId.homeworld]![DockBayId.b1],
          RigTier.t1,
        );
      },
    );

    test('recall uses an empty bay and rejects a full dock', () async {
      final full = await controllerOver(
        MiningSaveRepository(),
        seed: seededSave(
          clock.now,
          docks: docksFor(
            homeworld: dock(
              b1: null,
              b2: RigTier.t1,
              b3: RigTier.t2,
              b4: RigTier.t3,
            ),
          ),
          sites: sitesFor(
            landing: site(
              unlocked: true,
              commissioned: true,
              rigByNode: nodes(n1: RigTier.t1),
            ),
          ),
        ),
      );
      final result = await full.recallRig(
        MiningSiteId.landingBasin,
        MiningNodeId.n1,
      );
      expect(result.isSuccess, isTrue);
      expect(
        full.state.docks[MiningPlanetId.homeworld]![DockBayId.b1],
        RigTier.t1,
      );

      final noBay = await controllerOver(
        MiningSaveRepository(),
        seed: seededSave(
          clock.now,
          docks: docksFor(
            homeworld: dock(
              b1: RigTier.t1,
              b2: RigTier.t2,
              b3: RigTier.t3,
              b4: RigTier.t4,
            ),
          ),
          sites: sitesFor(
            landing: site(
              unlocked: true,
              commissioned: true,
              rigByNode: nodes(n1: RigTier.t1),
            ),
          ),
        ),
      );
      final blocked = await noBay.recallRig(
        MiningSiteId.landingBasin,
        MiningNodeId.n1,
      );
      expect(blocked.isSuccess, isFalse);
      expect(blocked.message, 'Dock is full.');
    });
  });

  group('technology, travel, and sale', () {
    test('technology gates use commissioned sites', () async {
      final controller = await controllerOver(
        MiningSaveRepository(),
        seed: seededSave(clock.now, cash: 500),
      );

      final blocked = await controller.purchaseTechnology(
        TechnologyTrack.extraction,
      );
      expect(blocked.message, 'Commission the Landing Basin site first.');

      final commissioned = await controllerOver(
        MiningSaveRepository(),
        seed: deployedLandingBasinState(clock.now).copyWith(cash: 500),
      );
      final purchased = await commissioned.purchaseTechnology(
        TechnologyTrack.extraction,
      );
      expect(purchased.isSuccess, isTrue);
      expect(commissioned.state.technology.extraction, 1);
      expect(commissioned.state.cash, 200);
    });

    test(
      'planet unlock seeds two rigs, first site, and active planet',
      () async {
        final controller = await controllerOver(
          MiningSaveRepository(),
          seed: homeworldMasteredState(clock.now),
        );

        final result = await controller.unlockPlanet(
          MiningPlanetId.lunarFrontier,
        );

        expect(result.isSuccess, isTrue);
        expect(controller.state.cash, 2500);
        expect(controller.state.activePlanetId, MiningPlanetId.lunarFrontier);
        expect(controller.state.docks[MiningPlanetId.lunarFrontier], {
          DockBayId.b1: RigTier.t1,
          DockBayId.b2: RigTier.t1,
          DockBayId.b3: null,
          DockBayId.b4: null,
        });
        expect(
          controller.state.sites[MiningSiteId.frozenBasin]!.unlocked,
          isTrue,
        );
      },
    );

    test(
      'travel accrues all unlocked planets before changing active planet',
      () async {
        final controller = await controllerOver(
          MiningSaveRepository(),
          seed: seededSave(
            clock.now,
            cash: 1000,
            technology: const TechnologyLevels(surveying: 3),
            unlockedPlanets: {
              MiningPlanetId.homeworld,
              MiningPlanetId.lunarFrontier,
            },
            activePlanet: MiningPlanetId.lunarFrontier,
            docks: docksFor(
              homeworld: dock(),
              lunar: dock(b1: RigTier.t1, b2: RigTier.t1),
            ),
            sites: sitesFor(
              landing: site(
                unlocked: true,
                commissioned: true,
                rigByNode: nodes(n1: RigTier.t1),
              ),
              frozen: site(
                unlocked: true,
                commissioned: true,
                rigByNode: nodes(n1: RigTier.t1),
              ),
            ),
          ),
        );
        clock.now = clock.now.add(const Duration(seconds: 10));

        final result = await controller.switchPlanet(MiningPlanetId.homeworld);

        expect(result.isSuccess, isTrue);
        expect(controller.state.activePlanetId, MiningPlanetId.homeworld);
        expect(
          controller.state.sites[MiningSiteId.landingBasin]!.storedAmount,
          5,
        );
        expect(
          controller.state.sites[MiningSiteId.frozenBasin]!.storedAmount,
          10,
        );
        expect(controller.state.lastAccruedAtUtc, clock.now);
      },
    );

    test('sale clears active planet cargo and floors aggregate once', () async {
      final controller = await controllerOver(
        MiningSaveRepository(),
        seed: seededSave(
          clock.now,
          cash: 1000,
          technology: const TechnologyLevels(surveying: 3),
          unlockedPlanets: {
            MiningPlanetId.homeworld,
            MiningPlanetId.lunarFrontier,
          },
          activePlanet: MiningPlanetId.homeworld,
          sites: sitesFor(
            landing: site(
              unlocked: true,
              commissioned: true,
              storedAmount: 0.9,
              rigByNode: nodes(n1: RigTier.t1),
            ),
            carbon: site(
              unlocked: true,
              commissioned: true,
              storedAmount: 0.9,
              rigByNode: nodes(n1: RigTier.t1),
            ),
            granite: site(
              unlocked: true,
              commissioned: true,
              storedAmount: 0.9,
              rigByNode: nodes(n1: RigTier.t1),
            ),
            frozen: site(
              unlocked: true,
              commissioned: true,
              storedAmount: 10,
              rigByNode: nodes(n1: RigTier.t1),
            ),
          ),
        ),
      );

      final result = await controller.sellAllCargo();

      expect(result.revenue, 10);
      expect(result.sold, {
        ResourceType.gold: 0.9,
        ResourceType.coal: 0.9,
        ResourceType.stone: 0.9,
      });
      expect(controller.state.cash, 1010);
      expect(
        controller.state.sites[MiningSiteId.frozenBasin]!.storedAmount,
        10,
      );
    });
  });

  group('mastery and save ordering', () {
    test(
      'final first Mars commission pays exactly once across recall and redeploy',
      () async {
        final controller = await controllerOver(
          MiningSaveRepository(),
          seed: seededSave(
            clock.now,
            cash: 50000,
            technology: const TechnologyLevels(surveying: 5),
            unlockedPlanets: {
              MiningPlanetId.homeworld,
              MiningPlanetId.lunarFrontier,
              MiningPlanetId.marsFrontier,
            },
            activePlanet: MiningPlanetId.marsFrontier,
            docks: docksFor(
              mars: dock(b1: RigTier.t1, b2: RigTier.t1),
            ),
            sites: sitesFor(
              landing: site(unlocked: true),
              frozen: site(unlocked: true),
              ochre: site(unlocked: true, commissioned: true),
              silica: site(unlocked: true, commissioned: true),
              cobalt: site(unlocked: true),
            ),
          ),
        );

        final first = await controller.deployRig(
          DockBayId.b1,
          MiningSiteId.cobaltChasm,
          MiningNodeId.n1,
        );
        expect(first.message, 'Mars mastered — +25,000 cash.');
        expect(controller.state.cash, 75000);

        final recall = await controller.recallRig(
          MiningSiteId.cobaltChasm,
          MiningNodeId.n1,
        );
        expect(recall.isSuccess, isTrue);
        final redeploy = await controller.deployRig(
          DockBayId.b1,
          MiningSiteId.cobaltChasm,
          MiningNodeId.n1,
        );
        expect(redeploy.isSuccess, isTrue);
        expect(redeploy.message, isNull);
        expect(controller.state.cash, 75000);
      },
    );

    test(
      'failed save leaves rig movement unpublished and later action can proceed',
      () async {
        final repository = ThrowingFirstSaveRepository();
        final controller = await controllerOver(
          repository,
          seed: seededSave(clock.now),
        );
        final before = controller.state.toJson();
        final first = controller.spawnRig();
        final second = controller.spawnRig();

        await expectLater(first, throwsStateError);
        await repository.secondSaveStarted.future;
        expect(controller.state.toJson(), before);
        repository.allowSecondSave.complete();
        expect((await second).isSuccess, isTrue);
        expect(
          controller.state.docks[MiningPlanetId.homeworld]![DockBayId.b3],
          RigTier.t1,
        );
      },
    );

    test('checkpoint persists flat docks and sites after accrual', () async {
      final controller = await controllerOver(
        MiningSaveRepository(),
        seed: deployedLandingBasinState(clock.now),
      );
      clock.now = clock.now.add(const Duration(seconds: 10));

      await controller.checkpoint();

      final prefs = await SharedPreferences.getInstance();
      final raw =
          jsonDecode(prefs.getString(MiningSaveRepository.saveKey)!)
              as Map<String, Object?>;
      expect(raw['cash'], 100);
      expect(raw['lastAccruedAtUtc'], clock.now.toIso8601String());
      final landing = (raw['sites']! as Map<String, Object?>)['landingBasin'];
      expect((landing! as Map<String, Object?>)['storedAmount'], 5.0);
    });

    test('resume returns the pending summary only once', () async {
      final controller = await controllerOver(
        MiningSaveRepository(),
        seed: deployedLandingBasinState(clock.now),
      );
      clock.now = clock.now.add(const Duration(seconds: 10));

      final summary = await controller.resume();

      expect(summary!.produced[ResourceType.gold], 5.0);
      expect(await controller.resume(), isNull);
    });
  });
}
