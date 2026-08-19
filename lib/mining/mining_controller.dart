import 'dart:async';

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

  Future<MiningActionResult> revealSector(MiningSectorId id) =>
      _enqueueMutation(() async {
        final definition = content.sector(id);
        final candidate = simulation.accrue(_state, _nowUtc().toUtc());
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

  Future<MiningActionResult> buildMine(MiningSectorId id) =>
      _enqueueMutation(() async {
        final definition = content.sector(id);
        final candidate = simulation.accrue(_state, _nowUtc().toUtc());
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
        sectors[id] = progress.copyWith(
          mine: MineState(level: 1, storedAmount: 0),
        );
        final next = candidate.state.copyWith(
          cash: candidate.state.cash - definition.buildCost,
          sectors: sectors,
        );
        await repository.save(next);
        _state = next;
        return const MiningActionResult.success();
      });

  Future<MiningActionResult> upgradeMine(MiningSectorId id) =>
      _enqueueMutation(() async {
        final definition = content.sector(id);
        final candidate = simulation.accrue(_state, _nowUtc().toUtc());
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
        sectors[id] = progress.copyWith(
          mine: mine.copyWith(level: mine.level + 1),
        );
        final next = candidate.state.copyWith(
          cash: candidate.state.cash - cost,
          sectors: sectors,
        );
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

    for (final definition in content.sectors) {
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

  Future<void> checkpoint() => _enqueueMutation(() async {
    final accrued = simulation.accrue(_state, _nowUtc().toUtc());
    await repository.save(accrued.state);
    _state = accrued.state;
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
