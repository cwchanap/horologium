import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/mining/mining_content.dart';
import 'package:horologium/mining/mining_sheet_view.dart';
import 'package:horologium/mining/mining_state.dart';

MiningSave stateWith({
  required DateTime now,
  int? cash,
  Map<MiningSectorId, SectorProgress>? sectors,
}) {
  final base = MiningSave.initial(nowUtc: now);
  return base.copyWith(cash: cash, sectors: sectors);
}

SectorProgress mined({int level = 1, double stored = 0}) => SectorProgress(
  revealed: true,
  mine: MineState(level: level, storedAmount: stored),
);

void main() {
  final content = MiningContentRegistry.stellarMining();
  final now = DateTime.utc(2026, 8, 18, 12);

  test('no cargo disables Sell All', () {
    final view = MiningSheetView.from(
      state: MiningSave.initial(nowUtc: now),
      content: content,
      selectedSectorId: null,
      isBusy: false,
    );
    expect(view.action, MiningSheetAction.sell);
    expect(view.primaryEnabled, isFalse);
    expect(view.disabledReason, contains('No cargo'));
  });

  test('busy controller disables otherwise available action', () {
    final view = MiningSheetView.from(
      state: MiningSave.initial(nowUtc: now),
      content: content,
      selectedSectorId: MiningSectorId.landingBasin,
      isBusy: true,
    );
    expect(view.action, MiningSheetAction.build);
    expect(view.primaryEnabled, isFalse);
    expect(view.disabledReason, 'Finishing previous action…');
  });

  test('tiny non-zero cargo explains why sale waits', () {
    final view = MiningSheetView.from(
      state: stateWith(
        now: now,
        sectors: {MiningSectorId.landingBasin: mined(stored: 0.2)},
      ),
      content: content,
      selectedSectorId: null,
      isBusy: false,
    );
    expect(view.primaryEnabled, isFalse);
    expect(view.disabledReason, contains('worth at least 1 cash'));
  });

  test('busy keeps sell action and label, only disables the button', () {
    final view = MiningSheetView.from(
      state: stateWith(
        now: now,
        sectors: {MiningSectorId.landingBasin: mined(stored: 10)},
      ),
      content: content,
      selectedSectorId: null,
      isBusy: true,
    );
    expect(view.action, MiningSheetAction.sell);
    expect(view.primaryLabel, 'Sell All for 40 cash');
    expect(view.primaryEnabled, isFalse);
    expect(view.disabledReason, 'Finishing previous action…');
  });

  test('revealed empty sector offers build', () {
    final view = MiningSheetView.from(
      state: MiningSave.initial(nowUtc: now),
      content: content,
      selectedSectorId: MiningSectorId.landingBasin,
      isBusy: false,
    );
    expect(view.action, MiningSheetAction.build);
    expect(view.primaryLabel, 'Build for 50 cash');
    expect(view.primaryEnabled, isTrue);
    expect(view.disabledReason, isNull);
    expect(view.body, contains('Build cost 50 cash'));
  });

  test('build disabled without enough cash', () {
    final view = MiningSheetView.from(
      state: stateWith(now: now, cash: 40),
      content: content,
      selectedSectorId: MiningSectorId.landingBasin,
      isBusy: false,
    );
    expect(view.action, MiningSheetAction.build);
    expect(view.primaryEnabled, isFalse);
    expect(view.disabledReason, 'Need 50 cash to build.');
  });

  test('unrevealed sector waits for its prerequisite', () {
    final view = MiningSheetView.from(
      state: MiningSave.initial(nowUtc: now),
      content: content,
      selectedSectorId: MiningSectorId.graniteCrater,
      isBusy: false,
    );
    expect(view.action, MiningSheetAction.reveal);
    expect(view.primaryLabel, 'Reveal for 700 cash');
    expect(view.primaryEnabled, isFalse);
    expect(view.disabledReason, 'Reveal Carbon Ridge first.');
  });

  test('reveal disabled without enough cash', () {
    final view = MiningSheetView.from(
      state: MiningSave.initial(nowUtc: now),
      content: content,
      selectedSectorId: MiningSectorId.carbonRidge,
      isBusy: false,
    );
    expect(view.action, MiningSheetAction.reveal);
    expect(view.primaryEnabled, isFalse);
    expect(view.disabledReason, 'Need 250 cash to reveal.');
  });

  test('reveal enabled when prerequisite met and affordable', () {
    final view = MiningSheetView.from(
      state: stateWith(now: now, cash: 300),
      content: content,
      selectedSectorId: MiningSectorId.carbonRidge,
      isBusy: false,
    );
    expect(view.action, MiningSheetAction.reveal);
    expect(view.primaryEnabled, isTrue);
    expect(view.disabledReason, isNull);
  });

  test('existing mine offers upgrade', () {
    final view = MiningSheetView.from(
      state: stateWith(
        now: now,
        sectors: {MiningSectorId.landingBasin: mined()},
      ),
      content: content,
      selectedSectorId: MiningSectorId.landingBasin,
      isBusy: false,
    );
    expect(view.action, MiningSheetAction.upgrade);
    expect(view.primaryLabel, 'Upgrade for 80 cash');
    expect(view.primaryEnabled, isTrue);
    expect(view.disabledReason, isNull);
  });

  test('upgrade disabled without enough cash', () {
    final view = MiningSheetView.from(
      state: stateWith(
        now: now,
        cash: 50,
        sectors: {MiningSectorId.landingBasin: mined()},
      ),
      content: content,
      selectedSectorId: MiningSectorId.landingBasin,
      isBusy: false,
    );
    expect(view.action, MiningSheetAction.upgrade);
    expect(view.primaryEnabled, isFalse);
    expect(view.disabledReason, 'Need 80 cash to upgrade.');
  });

  test('max level mine shows explanatory none action', () {
    final view = MiningSheetView.from(
      state: stateWith(
        now: now,
        sectors: {MiningSectorId.landingBasin: mined(level: 5)},
      ),
      content: content,
      selectedSectorId: MiningSectorId.landingBasin,
      isBusy: false,
    );
    expect(view.action, MiningSheetAction.none);
    expect(view.primaryLabel, 'Max Level');
    expect(view.primaryEnabled, isFalse);
    expect(view.disabledReason, 'Mine is at max level.');
  });

  test('mixed cargo sells total with floored revenue', () {
    final view = MiningSheetView.from(
      state: stateWith(
        now: now,
        sectors: {
          MiningSectorId.landingBasin: mined(stored: 10),
          MiningSectorId.carbonRidge: mined(stored: 5),
        },
      ),
      content: content,
      selectedSectorId: null,
      isBusy: false,
    );
    expect(view.action, MiningSheetAction.sell);
    expect(view.primaryEnabled, isTrue);
    expect(view.disabledReason, isNull);
    expect(view.primaryLabel, 'Sell All for 55 cash');
    expect(view.body, '15.0 units of cargo, worth 55 cash.');
  });

  test('sellable cargo enables Sell All', () {
    final view = MiningSheetView.from(
      state: stateWith(
        now: now,
        sectors: {MiningSectorId.landingBasin: mined(stored: 1)},
      ),
      content: content,
      selectedSectorId: null,
      isBusy: false,
    );
    expect(view.action, MiningSheetAction.sell);
    expect(view.primaryEnabled, isTrue);
    expect(view.disabledReason, isNull);
    expect(view.primaryLabel, 'Sell All for 4 cash');
  });
}
