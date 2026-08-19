import 'package:horologium/mining/mining_content.dart';

class MineState {
  const MineState({required this.level, required this.storedAmount});
  final int level;
  final double storedAmount;

  MineState copyWith({int? level, double? storedAmount}) => MineState(
    level: level ?? this.level,
    storedAmount: storedAmount ?? this.storedAmount,
  );

  Map<String, Object?> toJson() => {
    'level': level,
    'storedAmount': storedAmount,
  };
}

class SectorProgress {
  const SectorProgress({required this.revealed, this.mine});
  final bool revealed;
  final MineState? mine;

  SectorProgress copyWith({
    bool? revealed,
    MineState? mine,
    bool clearMine = false,
  }) => SectorProgress(
    revealed: revealed ?? this.revealed,
    mine: clearMine ? null : mine ?? this.mine,
  );

  Map<String, Object?> toJson() => {
    'revealed': revealed,
    'mine': mine?.toJson(),
  };
}

class MiningSave {
  const MiningSave({
    required this.cash,
    required this.lastAccruedAtUtc,
    required this.sectors,
  });

  final int cash;
  final DateTime lastAccruedAtUtc;
  final Map<MiningSectorId, SectorProgress> sectors;

  factory MiningSave.initial({required DateTime nowUtc}) => MiningSave(
    cash: 100,
    lastAccruedAtUtc: nowUtc.toUtc(),
    sectors: const {
      MiningSectorId.landingBasin: SectorProgress(revealed: true),
      MiningSectorId.carbonRidge: SectorProgress(revealed: false),
      MiningSectorId.graniteCrater: SectorProgress(revealed: false),
    },
  );

  MiningSave copyWith({
    int? cash,
    DateTime? lastAccruedAtUtc,
    Map<MiningSectorId, SectorProgress>? sectors,
  }) => MiningSave(
    cash: cash ?? this.cash,
    lastAccruedAtUtc: lastAccruedAtUtc ?? this.lastAccruedAtUtc,
    sectors: Map.unmodifiable(sectors ?? this.sectors),
  );

  Map<String, Object?> toJson() => {
    'cash': cash,
    'lastAccruedAtUtc': lastAccruedAtUtc.toUtc().toIso8601String(),
    'sectors': sectors.map(
      (id, progress) => MapEntry(id.name, progress.toJson()),
    ),
  };
}
