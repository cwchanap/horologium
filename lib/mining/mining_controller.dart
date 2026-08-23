import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_save_repository.dart';
import 'package:horologium/mining/mining_simulation.dart';
import 'package:horologium/mining/mining_state.dart';

class MiningActionResult {
  const MiningActionResult.success() : isSuccess = true, message = null;
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

  static const int _maxMineLevel = 5;

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

  MiningActionResult? _activePlanetSectorFailure(
    MiningSectorId id,
    MiningSave state,
  ) {
    if (content.planetForSector(id) != state.activePlanetId) {
      return const MiningActionResult.failure(
        'Sector is not on the active planet.',
      );
    }
    return null;
  }

  Future<MiningActionResult> revealSector(MiningSectorId id) =>
      _enqueueMutation(() async {
        final candidate = simulation.accrue(_state, _nowUtc().toUtc());
        final activePlanetFailure = _activePlanetSectorFailure(
          id,
          candidate.state,
        );
        if (activePlanetFailure != null) return activePlanetFailure;

        final definition = content.sector(id);
        final progress = candidate.state.sectors[id]!;

        if (progress.revealed) {
          return const MiningActionResult.failure('Sector already revealed.');
        }
        final requiredSector = definition.requiredSector;
        if (requiredSector != null &&
            !candidate.state.sectors[requiredSector]!.revealed) {
          return const MiningActionResult.failure(
            'Reveal the previous sector first.',
          );
        }
        if (candidate.state.technology.surveying <
            definition.requiredSurveyingLevel) {
          return MiningActionResult.failure(
            'Requires Surveying ${definition.requiredSurveyingLevel}.',
          );
        }
        if (candidate.state.cash < definition.revealCost) {
          return const MiningActionResult.failure('Not enough cash.');
        }

        final sectors = <MiningSectorId, SectorProgress>{
          ...candidate.state.sectors,
        };
        sectors[id] = progress.copyWith(revealed: true);
        final next = candidate.state.copyWith(
          cash: candidate.state.cash - definition.revealCost,
          sectors: sectors,
        );
        await repository.save(next);
        _state = next;
        return const MiningActionResult.success();
      });

  Future<MiningActionResult> buildMine(
    MiningSectorId id,
  ) => _enqueueMutation(() async {
    final candidate = simulation.accrue(_state, _nowUtc().toUtc());
    final activePlanetFailure = _activePlanetSectorFailure(id, candidate.state);
    if (activePlanetFailure != null) return activePlanetFailure;

    final definition = content.sector(id);
    final progress = candidate.state.sectors[id]!;

    if (!progress.revealed) {
      return const MiningActionResult.failure('Sector is not revealed.');
    }
    if (progress.mine != null) {
      return const MiningActionResult.failure('Mine already built.');
    }
    if (candidate.state.cash < definition.buildCost) {
      return const MiningActionResult.failure('Not enough cash.');
    }

    final sectors = <MiningSectorId, SectorProgress>{
      ...candidate.state.sectors,
    };
    sectors[id] = progress.copyWith(mine: MineState(level: 1, storedAmount: 0));
    final next = candidate.state.copyWith(
      cash: candidate.state.cash - definition.buildCost,
      sectors: sectors,
    );
    await repository.save(next);
    _state = next;
    return const MiningActionResult.success();
  });

  Future<MiningActionResult> upgradeMine(
    MiningSectorId id,
  ) => _enqueueMutation(() async {
    final candidate = simulation.accrue(_state, _nowUtc().toUtc());
    final activePlanetFailure = _activePlanetSectorFailure(id, candidate.state);
    if (activePlanetFailure != null) return activePlanetFailure;

    final definition = content.sector(id);
    final progress = candidate.state.sectors[id]!;
    final mine = progress.mine;

    if (mine == null) {
      return const MiningActionResult.failure('Build the mine first.');
    }
    if (mine.level >= _maxMineLevel) {
      return const MiningActionResult.failure('Mine is at max level.');
    }
    final cost = definition.upgradeCosts[mine.level - 1];
    if (candidate.state.cash < cost) {
      return const MiningActionResult.failure('Not enough cash.');
    }

    final sectors = <MiningSectorId, SectorProgress>{
      ...candidate.state.sectors,
    };
    sectors[id] = progress.copyWith(mine: mine.copyWith(level: mine.level + 1));
    final next = candidate.state.copyWith(
      cash: candidate.state.cash - cost,
      sectors: sectors,
    );
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
    final gateSector = MiningContentRegistry.technologyMineGates[currentLevel];
    if (candidate.state.sectors[gateSector]!.mine == null) {
      return MiningActionResult.failure(
        'Build the ${content.sector(gateSector).name} mine first.',
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

        if (id != MiningPlanetId.lunarFrontier) {
          return const MiningActionResult.failure(
            'Only Lunar Frontier can be unlocked.',
          );
        }
        if (candidate.state.unlockedPlanetIds.contains(id)) {
          return const MiningActionResult.failure('Planet already unlocked.');
        }
        final minedSectorIds = candidate.state.sectors.entries
            .where((entry) => entry.value.mine != null)
            .map((entry) => entry.key);
        if (!content.isHomeworldMastered(minedSectorIds)) {
          return const MiningActionResult.failure(
            'Build every Homeworld mine first.',
          );
        }
        if (candidate.state.technology.surveying <
            MiningContentRegistry.lunarUnlockSurveyingLevel) {
          return MiningActionResult.failure(
            'Requires Surveying '
            '${MiningContentRegistry.lunarUnlockSurveyingLevel}.',
          );
        }
        if (candidate.state.cash < MiningContentRegistry.lunarUnlockCashCost) {
          return const MiningActionResult.failure('Not enough cash.');
        }

        final next = candidate.state.copyWith(
          cash:
              candidate.state.cash - MiningContentRegistry.lunarUnlockCashCost,
          unlockedPlanetIds: {...candidate.state.unlockedPlanetIds, id},
          activePlanetId: id,
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
    final sectors = <MiningSectorId, SectorProgress>{
      ...candidate.state.sectors,
    };

    for (final definition
        in content.planet(candidate.state.activePlanetId).sectors) {
      final progress = sectors[definition.id]!;
      final mine = progress.mine;
      if (mine == null || mine.storedAmount <= 0) continue;

      totalCargo += mine.storedAmount;
      grossValue += mine.storedAmount * definition.saleValuePerUnit;
      sold.update(
        definition.resource,
        (value) => value + mine.storedAmount,
        ifAbsent: () => mine.storedAmount,
      );
      sectors[definition.id] = progress.copyWith(
        mine: mine.copyWith(storedAmount: 0),
      );
    }

    if (totalCargo <= 0) {
      return const MiningSaleResult.failure('No cargo to sell.');
    }

    final revenue = grossValue.floor();
    final next = candidate.state.copyWith(
      cash: candidate.state.cash + revenue,
      sectors: sectors,
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
