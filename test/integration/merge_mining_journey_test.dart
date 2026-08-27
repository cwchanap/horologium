import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_controller.dart';
import 'package:horologium/mining/mining_save_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestClock {
  TestClock(this.now);

  DateTime now;

  DateTime call() => now;

  void advance(Duration duration) {
    now = now.add(duration);
  }
}

Future<void> expectAction(
  String label,
  Future<MiningActionResult> action,
) async {
  final result = await action;
  expect(result.isSuccess, isTrue, reason: '$label failed: ${result.message}');
}

Future<void> earnUntil(
  MiningController controller,
  TestClock clock, {
  required int cashAtLeast,
  required String phase,
}) async {
  final startedAt = clock.now;
  final revenues = <int>[];
  while (controller.state.cash < cashAtLeast) {
    clock.advance(const Duration(minutes: 5));
    final sale = await controller.sellAllCargo();
    expect(
      sale.isSuccess,
      isTrue,
      reason: '$phase produced no sellable active-planet cargo',
    );
    revenues.add(sale.revenue!);
  }
  debugPrint(
    'CADENCE phase=$phase elapsed=${clock.now.difference(startedAt).inSeconds}s '
    'sales=${revenues.join('/')} cash=${controller.state.cash}',
  );
}

void main() {
  test(
    'fresh public actions commission every site through Mars and reload the save',
    () async {
      SharedPreferences.setMockInitialValues({});
      final clock = TestClock(DateTime.utc(2026, 8, 27, 12));
      final content = MiningContentRegistry.stellarMining();
      final repository = MiningSaveRepository(content: content);
      final controller = MiningController(
        content: content,
        repository: repository,
        nowUtc: clock.call,
      );

      await controller.initialize();
      expect(controller.state.cash, 100);
      expect(controller.state.unlockedPlanetIds, {MiningPlanetId.homeworld});
      expect(controller.state.activePlanetId, MiningPlanetId.homeworld);
      expect(controller.state.docks[MiningPlanetId.homeworld], {
        DockBayId.b1: RigTier.t1,
        DockBayId.b2: RigTier.t1,
        DockBayId.b3: null,
        DockBayId.b4: null,
      });
      expect(
        controller.state.sites[MiningSiteId.landingBasin]!.unlocked,
        isTrue,
      );

      await expectAction(
        'merge the fresh Homeworld rigs',
        controller.mergeDockRigs(DockBayId.b1, DockBayId.b2),
      );
      expect(
        controller.state.docks[MiningPlanetId.homeworld]![DockBayId.b2],
        RigTier.t2,
      );
      await expectAction(
        'commission Landing Basin',
        controller.deployRig(
          DockBayId.b2,
          MiningSiteId.landingBasin,
          MiningNodeId.n1,
        ),
      );
      expect(
        controller.state.sites[MiningSiteId.landingBasin]!.commissioned,
        isTrue,
      );
      debugPrint('SEQUENCE Homeworld merge t1+t1->t2; deploy Landing Basin');

      await earnUntil(
        controller,
        clock,
        cashAtLeast: 250,
        phase: 'Homeworld before Carbon Ridge',
      );
      await expectAction(
        'unlock Carbon Ridge',
        controller.unlockSite(MiningSiteId.carbonRidge),
      );
      await expectAction('spawn Carbon Ridge rig', controller.spawnRig());
      await expectAction(
        'commission Carbon Ridge',
        controller.deployRig(
          DockBayId.b1,
          MiningSiteId.carbonRidge,
          MiningNodeId.n1,
        ),
      );
      expect(
        controller.state.sites[MiningSiteId.carbonRidge]!.commissioned,
        isTrue,
      );

      await earnUntil(
        controller,
        clock,
        cashAtLeast: 700,
        phase: 'Homeworld before Granite Crater',
      );
      await expectAction(
        'unlock Granite Crater',
        controller.unlockSite(MiningSiteId.graniteCrater),
      );
      await expectAction('spawn Granite Crater rig', controller.spawnRig());
      await expectAction(
        'commission Granite Crater',
        controller.deployRig(
          DockBayId.b1,
          MiningSiteId.graniteCrater,
          MiningNodeId.n1,
        ),
      );
      expect(
        controller.state.sites[MiningSiteId.graniteCrater]!.commissioned,
        isTrue,
      );
      expect(
        content.isPlanetMastered(
          MiningPlanetId.homeworld,
          MiningSiteId.values.where(
            (id) => controller.state.sites[id]!.commissioned,
          ),
        ),
        isTrue,
      );

      await earnUntil(
        controller,
        clock,
        cashAtLeast: 8000,
        phase: 'Homeworld mastery and Surveying 3',
      );
      await expectAction(
        'raise Surveying to 1',
        controller.purchaseTechnology(TechnologyTrack.surveying),
      );
      await expectAction(
        'raise Surveying to 2',
        controller.purchaseTechnology(TechnologyTrack.surveying),
      );
      await expectAction(
        'raise Surveying to 3',
        controller.purchaseTechnology(TechnologyTrack.surveying),
      );
      expect(controller.state.technology.surveying, 3);

      await expectAction(
        'unlock Lunar Frontier',
        controller.unlockPlanet(MiningPlanetId.lunarFrontier),
      );
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

      final homeworldCargoBeforeLunarRefresh =
          controller.state.sites[MiningSiteId.landingBasin]!.storedAmount;
      clock.advance(const Duration(seconds: 30));
      controller.refresh();
      final homeworldCargoAfterLunarRefresh =
          controller.state.sites[MiningSiteId.landingBasin]!.storedAmount;
      expect(controller.state.activePlanetId, MiningPlanetId.lunarFrontier);
      expect(
        homeworldCargoAfterLunarRefresh,
        greaterThan(homeworldCargoBeforeLunarRefresh),
      );
      debugPrint(
        'INACTIVE_HOMEWORLD active=Lunar Frontier elapsed=30s '
        'cargo=$homeworldCargoBeforeLunarRefresh->$homeworldCargoAfterLunarRefresh',
      );

      await expectAction(
        'merge the fresh Lunar rigs',
        controller.mergeDockRigs(DockBayId.b1, DockBayId.b2),
      );
      await expectAction(
        'commission Frozen Basin',
        controller.deployRig(
          DockBayId.b2,
          MiningSiteId.frozenBasin,
          MiningNodeId.n1,
        ),
      );
      debugPrint('SEQUENCE Lunar merge t1+t1->t2; deploy Frozen Basin');

      await earnUntil(
        controller,
        clock,
        cashAtLeast: 7500,
        phase: 'Lunar before Surveying 4 and Titanium Highlands',
      );
      await expectAction(
        'raise Surveying to 4',
        controller.purchaseTechnology(TechnologyTrack.surveying),
      );
      await expectAction(
        'unlock Titanium Highlands',
        controller.unlockSite(MiningSiteId.titaniumHighlands),
      );
      await expectAction('spawn Titanium Highlands rig', controller.spawnRig());
      await expectAction(
        'commission Titanium Highlands',
        controller.deployRig(
          DockBayId.b1,
          MiningSiteId.titaniumHighlands,
          MiningNodeId.n1,
        ),
      );

      await earnUntil(
        controller,
        clock,
        cashAtLeast: 18000,
        phase: 'Lunar before Surveying 5 and Helium Mare',
      );
      await expectAction(
        'raise Surveying to 5',
        controller.purchaseTechnology(TechnologyTrack.surveying),
      );
      await expectAction(
        'unlock Helium Mare',
        controller.unlockSite(MiningSiteId.heliumMare),
      );
      await expectAction('spawn Helium Mare rig', controller.spawnRig());
      await expectAction(
        'commission Helium Mare',
        controller.deployRig(
          DockBayId.b1,
          MiningSiteId.heliumMare,
          MiningNodeId.n1,
        ),
      );
      expect(
        content.isPlanetMastered(
          MiningPlanetId.lunarFrontier,
          MiningSiteId.values.where(
            (id) => controller.state.sites[id]!.commissioned,
          ),
        ),
        isTrue,
      );

      await earnUntil(
        controller,
        clock,
        cashAtLeast: 25000,
        phase: 'Lunar mastery before Mars unlock',
      );
      await expectAction(
        'unlock Mars Frontier',
        controller.unlockPlanet(MiningPlanetId.marsFrontier),
      );
      expect(controller.state.activePlanetId, MiningPlanetId.marsFrontier);
      expect(controller.state.docks[MiningPlanetId.marsFrontier], {
        DockBayId.b1: RigTier.t1,
        DockBayId.b2: RigTier.t1,
        DockBayId.b3: null,
        DockBayId.b4: null,
      });
      expect(controller.state.sites[MiningSiteId.ochreBasin]!.unlocked, isTrue);

      await expectAction(
        'merge the fresh Mars rigs',
        controller.mergeDockRigs(DockBayId.b1, DockBayId.b2),
      );
      await expectAction(
        'commission Ochre Basin',
        controller.deployRig(
          DockBayId.b2,
          MiningSiteId.ochreBasin,
          MiningNodeId.n1,
        ),
      );
      debugPrint('SEQUENCE Mars merge t1+t1->t2; deploy Ochre Basin');

      await earnUntil(
        controller,
        clock,
        cashAtLeast: 18000,
        phase: 'Mars before Silica Dunes',
      );
      await expectAction(
        'unlock Silica Dunes',
        controller.unlockSite(MiningSiteId.silicaDunes),
      );
      await expectAction('spawn Silica Dunes rig', controller.spawnRig());
      await expectAction(
        'commission Silica Dunes',
        controller.deployRig(
          DockBayId.b1,
          MiningSiteId.silicaDunes,
          MiningNodeId.n1,
        ),
      );

      await earnUntil(
        controller,
        clock,
        cashAtLeast: 40000,
        phase: 'Mars before Cobalt Chasm',
      );
      await expectAction(
        'unlock Cobalt Chasm',
        controller.unlockSite(MiningSiteId.cobaltChasm),
      );
      await expectAction('spawn Cobalt Chasm rig', controller.spawnRig());
      final cashBeforeMarsMastery = controller.state.cash;
      final mastery = await controller.deployRig(
        DockBayId.b1,
        MiningSiteId.cobaltChasm,
        MiningNodeId.n1,
      );
      expect(mastery.isSuccess, isTrue);
      expect(mastery.message, 'Mars mastered — +25,000 cash.');
      expect(controller.state.cash, cashBeforeMarsMastery + 25000);
      debugPrint(
        'MASTERY reward=25000 cash=$cashBeforeMarsMastery->${controller.state.cash}',
      );
      for (final siteId in const [
        MiningSiteId.ochreBasin,
        MiningSiteId.silicaDunes,
        MiningSiteId.cobaltChasm,
      ]) {
        expect(controller.state.sites[siteId]!.commissioned, isTrue);
      }

      final cashAfterFirstMastery = controller.state.cash;
      await expectAction(
        'recall the mastered Cobalt Chasm rig',
        controller.recallRig(MiningSiteId.cobaltChasm, MiningNodeId.n1),
      );
      final redeploy = await controller.deployRig(
        DockBayId.b1,
        MiningSiteId.cobaltChasm,
        MiningNodeId.n1,
      );
      expect(redeploy.isSuccess, isTrue);
      expect(redeploy.message, isNull);
      expect(controller.state.cash, cashAfterFirstMastery);

      final beforeReload = controller.state;
      final reloaded = MiningController(
        content: content,
        repository: repository,
        nowUtc: clock.call,
      );
      await reloaded.initialize();
      expect(reloaded.recoveredFromInvalidSave, isFalse);
      expect(reloaded.state.cash, beforeReload.cash);
      expect(reloaded.state.technology, beforeReload.technology);
      expect(reloaded.state.unlockedPlanetIds, beforeReload.unlockedPlanetIds);
      expect(reloaded.state.activePlanetId, MiningPlanetId.marsFrontier);
      for (final planetId in MiningPlanetId.values) {
        expect(reloaded.state.docks[planetId], beforeReload.docks[planetId]);
      }
      for (final siteId in MiningSiteId.values) {
        expect(reloaded.state.sites[siteId], beforeReload.sites[siteId]);
      }
      expect(
        reloaded.state.sites[MiningSiteId.cobaltChasm]!.storedAmount,
        beforeReload.sites[MiningSiteId.cobaltChasm]!.storedAmount,
      );
      debugPrint(
        'RELOAD active=${reloaded.state.activePlanetId.name} '
        'surveying=${reloaded.state.technology.surveying} '
        'marsCash=${reloaded.state.cash} '
        'marsSites=3/3 cargo=${reloaded.state.sites[MiningSiteId.cobaltChasm]!.storedAmount}',
      );
    },
  );
}
