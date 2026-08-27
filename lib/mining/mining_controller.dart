import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_save_repository.dart';
import 'package:horologium/mining/mining_simulation.dart';
import 'package:horologium/mining/mining_state.dart';

String _formatCash(int amount) => amount.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => ',',
);

class MiningActionResult {
  const MiningActionResult.success({this.message}) : isSuccess = true;
  const MiningActionResult.failure(this.message) : isSuccess = false;

  final bool isSuccess;
  final String? message;
}

class MiningSaleResult {
  const MiningSaleResult.success({required this.revenue, required this.sold})
    : isSuccess = true,
      message = null;
  const MiningSaleResult.failure(this.message)
    : isSuccess = false,
      revenue = null,
      sold = null;

  final bool isSuccess;
  final int? revenue;
  final Map<ResourceType, double>? sold;
  final String? message;
}

class MiningController {
  MiningController({
    required this.content,
    required this.repository,
    required DateTime Function() nowUtc,
  }) : _nowUtc = nowUtc,
       simulation = MiningSimulation(content);

  final MiningContentRegistry content;
  final MiningSaveRepository repository;
  final MiningSimulation simulation;
  final DateTime Function() _nowUtc;

  late MiningSave _state;
  MiningSave get state => _state;

  Future<void> _mutationChain = Future<void>.value();
  int _pendingMutations = 0;
  bool get isBusy => _pendingMutations > 0;

  bool recoveredFromInvalidSave = false;
  OfflineProductionSummary? _pendingReturnSummary;

  Future<void> initialize() async {
    final loaded = await repository.load(nowUtc: _nowUtc().toUtc());
    recoveredFromInvalidSave = loaded.recoveredFromInvalidSave;
    final accrued = simulation.accrue(loaded.state, _nowUtc().toUtc());
    _state = accrued.state;
    if (accrued.summary.totalProduced > 0) {
      _pendingReturnSummary = accrued.summary;
    }
    // Persist the freshly constructed initial or recovered state so a quick
    // enter-and-back does not race the menu's save-presence check against the
    // unawaited dispose checkpoint. Existing valid saves are not rewritten
    // here; they persist through gameplay mutations and lifecycle checkpoints.
    // This convenience write is best-effort: the in-memory state is already
    // constructed and playable, so a transient storage failure must not brick
    // the screen. The next mutation or lifecycle checkpoint retries the save.
    if (loaded.wasMissing || loaded.recoveredFromInvalidSave) {
      try {
        await repository.save(_state);
      } catch (e, stackTrace) {
        if (kDebugMode) {
          debugPrint('Initial mining save persistence failed: $e\n$stackTrace');
        }
      }
    }
  }

  AccrualResult refresh() {
    if (isBusy) {
      return simulation.accrue(_state, _state.lastAccruedAtUtc);
    }
    final accrued = simulation.accrue(_state, _nowUtc().toUtc());
    _state = accrued.state;
    return accrued;
  }

  OfflineProductionSummary? takePendingReturnSummary() {
    final summary = _pendingReturnSummary;
    _pendingReturnSummary = null;
    return summary;
  }

  Future<T> _enqueueMutation<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _pendingMutations++;
    _mutationChain = _mutationChain.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } finally {
        _pendingMutations--;
      }
    });
    return completer.future;
  }

  MiningActionResult? _activePlanetSiteFailure(
    MiningSiteId id,
    MiningSave state,
  ) {
    if (content.planetForSite(id) != state.activePlanetId) {
      return const MiningActionResult.failure(
        'Site is not on the active planet.',
      );
    }
    return null;
  }

  Set<MiningSiteId> _commissionedSiteIds(MiningSave state) => state
      .sites
      .entries
      .where((entry) => entry.value.commissioned)
      .map((entry) => entry.key)
      .toSet();

  Future<MiningActionResult> unlockSite(MiningSiteId id) => _enqueueMutation(
    () async {
      final candidate = simulation.accrue(_state, _nowUtc().toUtc());
      final activePlanetFailure = _activePlanetSiteFailure(id, candidate.state);
      if (activePlanetFailure != null) return activePlanetFailure;

      final definition = content.site(id);
      final progress = candidate.state.sites[id]!;
      if (progress.unlocked) {
        return const MiningActionResult.failure('Site already unlocked.');
      }
      final requiredSite = definition.requiredSite;
      if (requiredSite != null &&
          !candidate.state.sites[requiredSite]!.unlocked) {
        return const MiningActionResult.failure(
          'Unlock the previous site first.',
        );
      }
      if (candidate.state.technology.surveying <
          definition.requiredSurveyingLevel) {
        return MiningActionResult.failure(
          'Requires Surveying ${definition.requiredSurveyingLevel}.',
        );
      }
      if (candidate.state.cash < definition.unlockCost) {
        return const MiningActionResult.failure('Not enough cash.');
      }

      final sites = <MiningSiteId, SiteProgress>{...candidate.state.sites};
      sites[id] = progress.copyWith(unlocked: true);
      final next = candidate.state.copyWith(
        cash: candidate.state.cash - definition.unlockCost,
        sites: sites,
      );
      await repository.save(next);
      _state = next;
      return const MiningActionResult.success();
    },
  );

  Future<MiningActionResult> spawnRig() => _enqueueMutation(() async {
    final candidate = simulation.accrue(_state, _nowUtc().toUtc());
    final planetId = candidate.state.activePlanetId;
    final planetDocks = candidate.state.docks[planetId]!;
    DockBayId? emptyBay;
    for (final bayId in DockBayId.values) {
      if (planetDocks[bayId] == null) {
        emptyBay = bayId;
        break;
      }
    }
    if (emptyBay == null) {
      return const MiningActionResult.failure('Dock is full.');
    }

    final cost = content.planet(planetId).rigSpawnCost;
    if (candidate.state.cash < cost) {
      return const MiningActionResult.failure('Not enough cash.');
    }

    final docks = <MiningPlanetId, Map<DockBayId, RigTier?>>{
      for (final entry in candidate.state.docks.entries)
        entry.key: <DockBayId, RigTier?>{...entry.value},
    };
    docks[planetId]![emptyBay] = RigTier.t1;
    final next = candidate.state.copyWith(
      cash: candidate.state.cash - cost,
      docks: docks,
    );
    await repository.save(next);
    _state = next;
    return const MiningActionResult.success();
  });

  Future<MiningActionResult> mergeDockRigs(
    DockBayId sourceBay,
    DockBayId targetBay,
  ) => _enqueueMutation(() async {
    final candidate = simulation.accrue(_state, _nowUtc().toUtc());
    if (sourceBay == targetBay) {
      return const MiningActionResult.failure(
        'Choose two different dock bays.',
      );
    }
    final planetId = candidate.state.activePlanetId;
    final planetDocks = candidate.state.docks[planetId]!;
    final sourceTier = planetDocks[sourceBay];
    final targetTier = planetDocks[targetBay];
    if (sourceTier == null) {
      return const MiningActionResult.failure('Source dock bay is empty.');
    }
    if (targetTier == null) {
      return const MiningActionResult.failure('Target dock bay is empty.');
    }
    if (sourceTier != targetTier) {
      return const MiningActionResult.failure('Rigs must be the same tier.');
    }
    if (sourceTier == RigTier.t5) {
      return const MiningActionResult.failure('T5 rigs cannot merge.');
    }

    final docks = <MiningPlanetId, Map<DockBayId, RigTier?>>{
      for (final entry in candidate.state.docks.entries)
        entry.key: <DockBayId, RigTier?>{...entry.value},
    };
    docks[planetId]![sourceBay] = null;
    docks[planetId]![targetBay] = RigTier.values[sourceTier.index + 1];
    final next = candidate.state.copyWith(docks: docks);
    await repository.save(next);
    _state = next;
    return const MiningActionResult.success();
  });

  Future<MiningActionResult> deployRig(
    DockBayId sourceBay,
    MiningSiteId siteId,
    MiningNodeId nodeId,
  ) => _enqueueMutation(() async {
    final candidate = simulation.accrue(_state, _nowUtc().toUtc());
    final activePlanetFailure = _activePlanetSiteFailure(
      siteId,
      candidate.state,
    );
    if (activePlanetFailure != null) return activePlanetFailure;

    final planetId = candidate.state.activePlanetId;
    final planetDocks = candidate.state.docks[planetId]!;
    final sourceTier = planetDocks[sourceBay];
    if (sourceTier == null) {
      return const MiningActionResult.failure('Dock bay is empty.');
    }
    final definition = content.site(siteId);
    final progress = candidate.state.sites[siteId]!;
    if (!progress.unlocked) {
      return const MiningActionResult.failure('Unlock this site first.');
    }
    final node = definition.nodes.singleWhere((node) => node.id == nodeId);
    if (candidate.state.technology.surveying < node.requiredSurveyingLevel) {
      return MiningActionResult.failure(
        'Requires Surveying ${node.requiredSurveyingLevel}.',
      );
    }
    if (progress.rigByNode[nodeId] != null) {
      return const MiningActionResult.failure('Node is already occupied.');
    }

    final docks = <MiningPlanetId, Map<DockBayId, RigTier?>>{
      for (final entry in candidate.state.docks.entries)
        entry.key: <DockBayId, RigTier?>{...entry.value},
    };
    docks[planetId]![sourceBay] = null;
    final rigByNode = <MiningNodeId, RigTier?>{...progress.rigByNode};
    rigByNode[nodeId] = sourceTier;
    final sites = <MiningSiteId, SiteProgress>{...candidate.state.sites};
    sites[siteId] = progress.copyWith(commissioned: true, rigByNode: rigByNode);
    final wasMastered = content.isPlanetMastered(
      planetId,
      _commissionedSiteIds(candidate.state),
    );
    final isMastered = content.isPlanetMastered(
      planetId,
      sites.entries
          .where((entry) => entry.value.commissioned)
          .map((entry) => entry.key),
    );
    final planet = content.planet(planetId);
    final masteryReward =
        !wasMastered && isMastered && planet.masteryRewardCash > 0;
    final next = candidate.state.copyWith(
      cash:
          candidate.state.cash + (masteryReward ? planet.masteryRewardCash : 0),
      docks: docks,
      sites: sites,
    );
    await repository.save(next);
    _state = next;
    return MiningActionResult.success(
      message: masteryReward
          ? '${planet.name.split(' ').first} mastered — '
                '+${_formatCash(planet.masteryRewardCash)} cash.'
          : null,
    );
  });

  Future<MiningActionResult> recallRig(
    MiningSiteId siteId,
    MiningNodeId nodeId,
  ) => _enqueueMutation(() async {
    final candidate = simulation.accrue(_state, _nowUtc().toUtc());
    final activePlanetFailure = _activePlanetSiteFailure(
      siteId,
      candidate.state,
    );
    if (activePlanetFailure != null) return activePlanetFailure;

    final planetId = candidate.state.activePlanetId;
    final planetDocks = candidate.state.docks[planetId]!;
    DockBayId? emptyBay;
    for (final bayId in DockBayId.values) {
      if (planetDocks[bayId] == null) {
        emptyBay = bayId;
        break;
      }
    }
    if (emptyBay == null) {
      return const MiningActionResult.failure('Dock is full.');
    }

    final progress = candidate.state.sites[siteId]!;
    final tier = progress.rigByNode[nodeId];
    if (tier == null) {
      return const MiningActionResult.failure('Node is empty.');
    }
    final remainingRigs = progress.rigByNode.entries
        .where((entry) => entry.key != nodeId)
        .map((entry) => entry.value)
        .whereType<RigTier>();
    final postRecallCapacity = content.effectiveSiteCapacity(
      siteId,
      remainingRigs,
      candidate.state.technology.logistics,
    );
    if (progress.storedAmount > postRecallCapacity) {
      return const MiningActionResult.failure(
        'Sell cargo before recalling this rig.',
      );
    }

    final docks = <MiningPlanetId, Map<DockBayId, RigTier?>>{
      for (final entry in candidate.state.docks.entries)
        entry.key: <DockBayId, RigTier?>{...entry.value},
    };
    docks[planetId]![emptyBay] = tier;
    final rigByNode = <MiningNodeId, RigTier?>{...progress.rigByNode};
    rigByNode[nodeId] = null;
    final sites = <MiningSiteId, SiteProgress>{...candidate.state.sites};
    sites[siteId] = progress.copyWith(rigByNode: rigByNode);
    final next = candidate.state.copyWith(docks: docks, sites: sites);
    await repository.save(next);
    _state = next;
    return const MiningActionResult.success();
  });

  Future<MiningActionResult> purchaseTechnology(
    TechnologyTrack track,
  ) => _enqueueMutation(() async {
    final candidate = simulation.accrue(_state, _nowUtc().toUtc());
    final currentLevel = candidate.state.technology.levelFor(track);

    if (currentLevel >= MiningContentRegistry.maxTechnologyLevel) {
      return const MiningActionResult.failure('Technology is at max level.');
    }
    final gateSite = MiningContentRegistry.technologySiteGates[currentLevel];
    if (!candidate.state.sites[gateSite]!.commissioned) {
      return MiningActionResult.failure(
        'Commission the ${content.site(gateSite).name} site first.',
      );
    }
    final cost = MiningContentRegistry.technologyCosts[currentLevel];
    if (candidate.state.cash < cost) {
      return const MiningActionResult.failure('Not enough cash.');
    }

    final next = candidate.state.copyWith(
      cash: candidate.state.cash - cost,
      technology: candidate.state.technology.withLevel(track, currentLevel + 1),
    );
    await repository.save(next);
    _state = next;
    return const MiningActionResult.success();
  });

  Future<MiningActionResult> unlockPlanet(MiningPlanetId id) =>
      _enqueueMutation(() async {
        final candidate = simulation.accrue(_state, _nowUtc().toUtc());
        final definition = content.planet(id);

        if (candidate.state.unlockedPlanetIds.contains(id)) {
          return const MiningActionResult.failure('Planet already unlocked.');
        }
        final requiredMasteryPlanetId =
            definition.unlockRequiredMasteryPlanetId;
        if (requiredMasteryPlanetId == null) {
          return const MiningActionResult.failure('Planet cannot be unlocked.');
        }
        if (!content.isPlanetMastered(
          requiredMasteryPlanetId,
          _commissionedSiteIds(candidate.state),
        )) {
          return MiningActionResult.failure(
            'Commission every ${content.planet(requiredMasteryPlanetId).name} '
            'site first.',
          );
        }
        if (candidate.state.technology.surveying <
            definition.unlockRequiredSurveyingLevel) {
          return MiningActionResult.failure(
            'Requires Surveying ${definition.unlockRequiredSurveyingLevel}.',
          );
        }
        if (candidate.state.cash < definition.unlockCashCost) {
          return const MiningActionResult.failure('Not enough cash.');
        }

        final docks = <MiningPlanetId, Map<DockBayId, RigTier?>>{
          for (final entry in candidate.state.docks.entries)
            entry.key: <DockBayId, RigTier?>{...entry.value},
        };
        docks[id] = {
          DockBayId.b1: RigTier.t1,
          DockBayId.b2: RigTier.t1,
          DockBayId.b3: null,
          DockBayId.b4: null,
        };
        final sites = <MiningSiteId, SiteProgress>{...candidate.state.sites};
        final firstSite = definition.sites.first;
        sites[firstSite.id] = sites[firstSite.id]!.copyWith(unlocked: true);
        final next = candidate.state.copyWith(
          cash: candidate.state.cash - definition.unlockCashCost,
          unlockedPlanetIds: {...candidate.state.unlockedPlanetIds, id},
          activePlanetId: id,
          docks: docks,
          sites: sites,
        );
        await repository.save(next);
        _state = next;
        return const MiningActionResult.success();
      });

  Future<MiningActionResult> switchPlanet(MiningPlanetId id) =>
      _enqueueMutation(() async {
        if (!_state.unlockedPlanetIds.contains(id)) {
          return const MiningActionResult.failure('Planet is locked.');
        }
        final candidate = simulation.accrue(_state, _nowUtc().toUtc());
        if (candidate.state.activePlanetId == id) {
          return const MiningActionResult.failure('Planet is already active.');
        }

        final next = candidate.state.copyWith(activePlanetId: id);
        await repository.save(next);
        _state = next;
        return const MiningActionResult.success();
      });

  Future<MiningSaleResult> sellAllCargo() => _enqueueMutation(() async {
    final candidate = simulation.accrue(_state, _nowUtc().toUtc());

    var totalCargo = 0.0;
    var grossValue = 0.0;
    final sold = <ResourceType, double>{};
    final sites = <MiningSiteId, SiteProgress>{...candidate.state.sites};

    for (final definition
        in content.planet(candidate.state.activePlanetId).sites) {
      final progress = sites[definition.id]!;
      if (progress.storedAmount <= 0) continue;

      totalCargo += progress.storedAmount;
      grossValue += progress.storedAmount * definition.saleValuePerUnit;
      sold.update(
        definition.resource,
        (value) => value + progress.storedAmount,
        ifAbsent: () => progress.storedAmount,
      );
      sites[definition.id] = progress.copyWith(storedAmount: 0);
    }

    if (totalCargo <= 0) {
      return const MiningSaleResult.failure('No cargo to sell.');
    }

    final revenue = grossValue.floor();
    final next = candidate.state.copyWith(
      cash: candidate.state.cash + revenue,
      sites: sites,
    );
    await repository.save(next);
    _state = next;
    return MiningSaleResult.success(revenue: revenue, sold: sold);
  });

  Future<void> checkpoint({bool accrue = true}) => _enqueueMutation(() async {
    final next = accrue
        ? simulation.accrue(_state, _nowUtc().toUtc()).state
        : _state;
    await repository.save(next);
    _state = next;
  });

  Future<OfflineProductionSummary?> resume() => _enqueueMutation(() async {
    final accrued = simulation.accrue(_state, _nowUtc().toUtc());
    _state = accrued.state;
    if (accrued.summary.totalProduced > 0) {
      _pendingReturnSummary = accrued.summary;
    }
    return takePendingReturnSummary();
  });
}
