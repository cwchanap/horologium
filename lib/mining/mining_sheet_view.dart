import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_state.dart';

enum MiningSheetAction { sell, reveal, build, upgrade, none }

class MiningSheetView {
  const MiningSheetView({
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.action,
    required this.primaryEnabled,
    this.disabledReason,
  });

  final String title;
  final String body;
  final String primaryLabel;
  final MiningSheetAction action;
  final bool primaryEnabled;
  final String? disabledReason;

  static MiningSheetView from({
    required MiningSave state,
    required MiningContentRegistry content,
    required MiningSectorId? selectedSectorId,
    required bool isBusy,
  }) {
    final base = selectedSectorId == null
        ? _sellView(state, content)
        : _sectorView(state, content, selectedSectorId);

    if (!isBusy) return base;
    return base.copyWith(
      primaryEnabled: false,
      disabledReason: 'Finishing previous action…',
    );
  }

  MiningSheetView copyWith({
    String? title,
    String? body,
    String? primaryLabel,
    MiningSheetAction? action,
    bool? primaryEnabled,
    String? disabledReason,
  }) => MiningSheetView(
    title: title ?? this.title,
    body: body ?? this.body,
    primaryLabel: primaryLabel ?? this.primaryLabel,
    action: action ?? this.action,
    primaryEnabled: primaryEnabled ?? this.primaryEnabled,
    disabledReason: disabledReason ?? this.disabledReason,
  );

  static MiningSheetView _sellView(
    MiningSave state,
    MiningContentRegistry content,
  ) {
    var totalCargo = 0.0;
    var grossValue = 0.0;
    for (final definition in content.sectors) {
      final mine = state.sectors[definition.id]?.mine;
      if (mine == null) continue;
      totalCargo += mine.storedAmount;
      grossValue += mine.storedAmount * definition.saleValuePerUnit;
    }

    if (totalCargo <= 0) {
      return MiningSheetView(
        title: 'Sell Cargo',
        body: 'No cargo in any mine.',
        primaryLabel: 'Sell All',
        action: MiningSheetAction.sell,
        primaryEnabled: false,
        disabledReason: 'No cargo to sell yet.',
      );
    }
    if (grossValue.floor() == 0) {
      return MiningSheetView(
        title: 'Sell Cargo',
        body:
            '${totalCargo.toStringAsFixed(1)} units of cargo, not yet worth '
            '1 cash.',
        primaryLabel: 'Sell All',
        action: MiningSheetAction.sell,
        primaryEnabled: false,
        disabledReason: 'Keep mining until cargo is worth at least 1 cash.',
      );
    }
    final revenue = grossValue.floor();
    return MiningSheetView(
      title: 'Sell Cargo',
      body:
          '${totalCargo.toStringAsFixed(1)} units of cargo, worth '
          '$revenue cash.',
      primaryLabel: 'Sell All for $revenue cash',
      action: MiningSheetAction.sell,
      primaryEnabled: true,
    );
  }

  static MiningSheetView _sectorView(
    MiningSave state,
    MiningContentRegistry content,
    MiningSectorId id,
  ) {
    final definition = content.sector(id);
    final progress = state.sectors[id] ?? const SectorProgress(revealed: false);
    final mine = progress.mine;

    if (!progress.revealed) {
      final prereq = definition.requiredSector;
      var enabled = true;
      var reason = '';
      if (prereq != null && !(state.sectors[prereq]?.revealed ?? false)) {
        enabled = false;
        reason = 'Reveal ${content.sector(prereq).name} first.';
      } else if (state.cash < definition.revealCost) {
        enabled = false;
        reason = 'Need ${definition.revealCost} cash to reveal.';
      }
      return MiningSheetView(
        title: definition.name,
        body:
            'Reveal cost ${definition.revealCost} cash, build cost '
            '${definition.buildCost} cash. Produces '
            '${_rate(content, id, 1)}/s.',
        primaryLabel: 'Reveal for ${definition.revealCost} cash',
        action: MiningSheetAction.reveal,
        primaryEnabled: enabled,
        disabledReason: enabled ? null : reason,
      );
    }

    if (mine == null) {
      final enabled = state.cash >= definition.buildCost;
      return MiningSheetView(
        title: definition.name,
        body:
            'Build cost ${definition.buildCost} cash. Produces '
            '${_rate(content, id, 1)}/s, capacity '
            '${_capacity(content, id, 1)}.',
        primaryLabel: 'Build for ${definition.buildCost} cash',
        action: MiningSheetAction.build,
        primaryEnabled: enabled,
        disabledReason: enabled
            ? null
            : 'Need ${definition.buildCost} cash to build.',
      );
    }

    if (mine.level >= 5) {
      return MiningSheetView(
        title: definition.name,
        body:
            'Level 5 mine. Produces ${_rate(content, id, 5)}/s, capacity '
            '${_capacity(content, id, 5)}, stored '
            '${mine.storedAmount.toStringAsFixed(1)}.',
        primaryLabel: 'Max Level',
        action: MiningSheetAction.none,
        primaryEnabled: false,
        disabledReason: 'Mine is at max level.',
      );
    }

    final cost = definition.upgradeCosts[mine.level - 1];
    final enabled = state.cash >= cost;
    return MiningSheetView(
      title: definition.name,
      body:
          'Level ${mine.level} mine. Produces '
          '${_rate(content, id, mine.level)}/s, capacity '
          '${_capacity(content, id, mine.level)}, stored '
          '${mine.storedAmount.toStringAsFixed(1)}.',
      primaryLabel: 'Upgrade for $cost cash',
      action: MiningSheetAction.upgrade,
      primaryEnabled: enabled,
      disabledReason: enabled ? null : 'Need $cost cash to upgrade.',
    );
  }

  static String _rate(
    MiningContentRegistry content,
    MiningSectorId id,
    int level,
  ) => content.rateFor(id, level).toStringAsFixed(1);

  static String _capacity(
    MiningContentRegistry content,
    MiningSectorId id,
    int level,
  ) => content.capacityFor(id, level).toStringAsFixed(1);
}
